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
local doors = doorsSvc.new(doorDriver.new(), logs)

local modem = component.modem

-- Diffusion d'un événement (alerte/lockdown) à tous les nœuds du réseau privé.
local function broadcast(evt)
  local msg = { t = protocol.EVT.ALERT }
  for k, v in pairs(evt) do msg[k] = v end
  modem.broadcast(protocol.PORT, netsec.encode(msg))
end

local radar = radarSvc.new({
  doors = doors,
  logs = logs,
  broadcast = broadcast,
  alarm = function(on, message) alarmAdapter.set(on, message) end,
})

local ctx = { accounts = accounts, auth = auth, logs = logs, doors = doors, radar = radar }

-- Amorçage : premier lancement -> compte admin par défaut (à changer !).
if accounts:count() == 0 then
  accounts:create({ name = "admin", role = "admin", password = "admin" })
  logs:add("system", "system", "compte admin initial créé (mdp: admin) — À CHANGER")
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
  -- Scrutation radar : l'escalade DEFCON déclenche alarme + lockdown + broadcast.
  pcall(function() radar:update(radarSource.read()) end)
end
