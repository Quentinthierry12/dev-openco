-- agent/main.lua
-- Daemon léger déployé sur CHAQUE machine gérée (terminaux, machines diverses).
-- Au boot : s'enregistre auprès du serveur. Ensuite : écoute les commandes distantes signées
-- (reboot/shutdown/lock/status) et les exécute. Ne réagit qu'aux messages du réseau privé (HMAC).

local ROOT = (os.getenv and os.getenv("SECSITE_ROOT")) or "/home/secsite"
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path

local component = require("component")
local computer = require("computer")
local event = require("event")

local netsec = require("shared/netsec")
local protocol = require("shared/protocol")
local commands = require("agent/commands")

-- Secret du réseau privé (même fichier que le serveur, déployé sur la machine).
local function readFile(p)
  local f = io.open(p, "r"); if not f then return nil end
  local d = f:read("*a"); f:close(); return d
end
local secret = readFile(ROOT .. "/agent/secret") or readFile(ROOT .. "/server/data/secret")
if secret and #secret:gsub("%s+", "") >= 8 then netsec.setSecret((secret:gsub("%s+$", ""))) end

local modem = component.modem
modem.open(protocol.PORT)

-- Type de nœud : variable d'env, sinon secsite.cfg (écrit par l'installateur), sinon "terminal".
local function nodeKind()
  local env = os.getenv and os.getenv("SECSITE_NODE_KIND")
  if env then return env end
  local cfg = readFile(ROOT .. "/secsite.cfg")
  if cfg then
    local t = load("return " .. cfg, "=cfg", "t", {})
    if t then local ok, v = pcall(t); if ok and type(v) == "table" and v.kind then return v.kind end end
  end
  return "terminal"
end
local KIND = nodeKind()

-- Bannière SecSite.
pcall(function()
  local branding = require("shared/branding")
  for _, line in ipairs(branding.BANNER) do print(line) end
end)

-- Enregistrement auprès du serveur.
modem.broadcast(protocol.PORT, netsec.encode(protocol.request(protocol.REQ.NODE_REGISTER,
  { address = computer.address(), kind = KIND })))
print("[secsite-agent] enregistré (" .. KIND .. "), en écoute.")

while true do
  local name, _, from, port, _, msg = event.pull(30, "modem_message")
  if name and port == protocol.PORT and netsec.isAllowed(from) then
    local m = netsec.decode(msg)
    if m and m.t == protocol.AGENT.EXEC then
      local res = { commands.exec(m.command) }
      -- status : répondre ; reboot/shutdown : la machine coupe avant.
      if m.command == "status" and res[1] then
        modem.send(from, protocol.PORT, netsec.encode({ t = "agent.status", id = m.id, data = res[1] }))
      end
    end
  else
    -- Battement : ré-enregistrement périodique (garde le nœud "up" côté serveur).
    modem.broadcast(protocol.PORT, netsec.encode(protocol.request(protocol.REQ.NODE_REGISTER,
      { address = computer.address(), kind = KIND })))
  end
end
