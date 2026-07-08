-- server/main.lua
-- Daemon serveur (OpenOS headless). Boucle : reçoit un message modem, vérifie la liste
-- blanche + la signature, route via server/router, renvoie la réponse signée.
-- Déployer le projet sous SECSITE_ROOT (défaut /home/secsite) puis lancer : secsite-server.

local ROOT = (os.getenv and os.getenv("SECSITE_ROOT")) or "/home/secsite"
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path

local component = require("component")
local event = require("event")

local netsec = require("shared.netsec")
local protocol = require("shared.protocol")
local router = require("server.router")
local logsSvc = require("server.services.logs")
local accountsSvc = require("server.services.accounts")
local authSvc = require("server.services.auth")
local doorsSvc = require("server.services.doors")
local radarSvc = require("server.services.radar")
local nodesSvc = require("server.services.nodes")
local messagingSvc = require("server.services.messaging")
local situationSvc = require("server.services.situation")
local protocolsSvc = require("server.services.protocols")
local powerSvc = require("server.services.power")
local defenseSvc = require("server.services.defense")
local settingsSvc = require("server.services.settings")
local hbmMachine = require("server.adapters.hbm_machine")
local defenseOut = require("server.adapters.defense_out")
local doorDriver = require("server.adapters.door_driver")
local radarSource = require("server.adapters.radar_source")
local alarmAdapter = require("server.adapters.alarm")

local DATA = ROOT .. "/server/data"

local function readFile(p)
  local f = io.open(p, "r")
  if not f then return nil end
  local d = f:read("*a"); f:close()
  return d
end

-- Secret du réseau privé (déployé uniquement sur les machines admises).
local secret = readFile(DATA .. "/secret")
if secret and #secret:gsub("%s+", "") >= 8 then
  netsec.setSecret((secret:gsub("%s+$", "")))
else
  io.stderr:write("[secsite] ATTENTION: secret par défaut. Créez " .. DATA .. "/secret\n")
end

-- Liste blanche optionnelle : un adresse de composant par ligne.
local wl = readFile(DATA .. "/whitelist")
if wl then
  for addr in wl:gmatch("[%w%-]+") do netsec.allow(addr) end
end

local logs = logsSvc.new({ path = DATA .. "/logs.tbl" }); logs:load()
local accounts = accountsSvc.new({ path = DATA .. "/accounts.tbl" }); accounts:load()
local auth = authSvc.new(accounts, logs)
local doors = doorsSvc.new(doorDriver.new(), logs, {
  schedule = function(seconds, fn) event.timer(seconds, fn) end, -- cycle temporisé des sas
})

local modem = component.modem

-- Diffusion d'un événement (alerte/lockdown) à tous les nœuds du réseau privé.
local function broadcast(evt)
  local msg = { t = protocol.EVT.ALERT }
  for k, v in pairs(evt) do msg[k] = v end
  modem.broadcast(protocol.PORT, netsec.encode(msg))
end

-- Contre-mesures + supervision réacteur.
local defense = defenseSvc.new({ actuate = defenseOut.actuate, logs = logs })
local power = powerSvc.new({
  logs = logs,
  alarm = function(on, message) alarmAdapter.set(on, message) end,
  onCritical = function(r) if r.autoScram then hbmMachine.scram(r.address) end end,
})

local radar = radarSvc.new({
  doors = doors,
  logs = logs,
  broadcast = broadcast,
  alarm = function(on, message) alarmAdapter.set(on, message) end,
  onEscalate = function(defcon, contacts) defense:engage({ defcon = defcon, contacts = contacts }) end,
  onStandDown = function() defense:standDown() end,
})

local nodes = nodesSvc.new({
  send = function(addr, m) modem.send(addr, protocol.PORT, netsec.encode(m)) end,
  logs = logs,
})

local messaging = messagingSvc.new({
  logs = logs,
  onAnnounce = function(a)
    modem.broadcast(protocol.PORT, netsec.encode({ t = protocol.EVT.ANNOUNCE, text = a.text, actor = a.actor }))
    alarmAdapter.chat("[ANNONCE] " .. a.actor .. ": " .. a.text)
  end,
})

local situation = situationSvc.new({ radar = radar, doors = doors })
local protocols = protocolsSvc.new({
  doors = doors, nodes = nodes, messaging = messaging, logs = logs,
  sleep = function(seconds) os.sleep(seconds) end, -- step "wait" des protocoles
  alarm = function(on, message) alarmAdapter.set(on, message) end,
  broadcast = function(evt)
    modem.broadcast(protocol.PORT, netsec.encode({ t = protocol.EVT.ANNOUNCE, text = "[PROTOCOLE] " .. (evt.name or "") }))
  end,
})

-- Réglages runtime (édités par Config.app), appliqués à chaud aux services.
local settings = settingsSvc.new({
  path = DATA .. "/settings.tbl",
  apply = function(key, value)
    if key == "site.name" then situation.site.name = value
    elseif key == "site.radius" then situation.site.radius = value
    elseif key == "radar.alertLevel" then radar.alertLevel = value
    elseif key == "defense.mode" then defense:setMode(value, "config")
    elseif key == "defense.engageLevel" then defense.engageLevel = value end
  end,
})
settings:load(); settings:applyAll()

local ctx = {
  accounts = accounts, auth = auth, logs = logs,
  doors = doors, radar = radar, nodes = nodes, messaging = messaging,
  situation = situation, protocols = protocols,
  power = power, defense = defense, settings = settings,
  scram = function(id)
    local r = require("shared.reactors").get(id)
    return r and hbmMachine.scram(r.address) or false
  end,
}

-- Amorçage : premier lancement -> compte admin. Mot de passe lu depuis server/data/admin_pw
-- (écrit par l'installateur) ; à défaut, "admin" par défaut (À CHANGER).
if accounts:count() == 0 then
  local pw = readFile(DATA .. "/admin_pw")
  pw = pw and pw:gsub("%s+$", "") or ""
  local isDefault = (pw == "")
  if isDefault then pw = "admin" end
  accounts:create({ name = "admin", role = "admin", password = pw })
  logs:add("system", "system", "compte admin initial créé" .. (isDefault and " (mdp: admin) — À CHANGER" or ""))
end

modem.open(protocol.PORT)
logs:add("system", "system", "serveur démarré")
print("[secsite] serveur en écoute sur le port " .. protocol.PORT)

-- Boucle principale : traite les messages ET scrute le radar (~1 Hz).
while true do
  local name, _, from, port, _, msg = event.pull(1, "modem_message")
  if name and port == protocol.PORT and netsec.isAllowed(from) then
    local req = netsec.decode(msg)
    if req then
      local resp = router.handle(ctx, req, { from = from })
      modem.send(from, protocol.PORT, netsec.encode(resp))
    end
  end
  -- Scrutation radar : l'escalade DEFCON déclenche alarme + lockdown + broadcast (+ contre-mesures).
  pcall(function() radar:update(radarSource.read()) end)
  -- Scrutation réacteurs/énergie : le seuil critique déclenche alarme + SCRAM auto.
  pcall(function() power:update(hbmMachine.read()) end)
end
