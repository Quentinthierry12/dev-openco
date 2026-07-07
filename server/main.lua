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
local ctx = { accounts = accounts, auth = auth, logs = logs }

-- Amorçage : premier lancement -> compte admin par défaut (à changer !).
if accounts:count() == 0 then
  accounts:create({ name = "admin", role = "admin", password = "admin" })
  logs:add("system", "system", "compte admin initial créé (mdp: admin) — À CHANGER")
end

local modem = component.modem
modem.open(protocol.PORT)
logs:add("system", "system", "serveur démarré")
print("[secsite] serveur en écoute sur le port " .. protocol.PORT)

while true do
  local _, _, from, port, _, msg = event.pull("modem_message")
  if port == protocol.PORT and netsec.isAllowed(from) then
    local req = netsec.decode(msg)
    if req then
      local resp = router.handle(ctx, req, { from = from })
      modem.send(from, protocol.PORT, netsec.encode(resp))
    end
  end
end
