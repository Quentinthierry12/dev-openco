-- server/services/nodes.lua
-- Registre de la flotte (machines gérées) + dispatch des commandes distantes.
-- Logique PURE : l'envoi réseau réel est une fonction `send` injectée -> testable hors-jeu.

local protocol = require("shared.protocol")

local nodes = {}
nodes.__index = nodes

function nodes.new(opts)
  opts = opts or {}
  return setmetatable({
    send = opts.send,   -- fn(address, messageTable) : émission vers un agent (modem)
    logs = opts.logs,
    registry = {},      -- address -> { address, kind, lastSeen, status }
  }, nodes)
end

-- Un agent s'enregistre (au boot). `address` = adresse de composant de la machine.
function nodes:register(address, kind)
  if type(address) ~= "string" then return nil, "bad_address" end
  self.registry[address] = {
    address = address,
    kind = kind or "unknown",
    lastSeen = os.time(),
    status = "up",
  }
  if self.logs then self.logs:add("fleet", "system", "nœud enregistré: " .. address .. " (" .. (kind or "?") .. ")") end
  return { address = address }
end

function nodes:touch(address)
  local n = self.registry[address]
  if n then n.lastSeen = os.time() end
end

function nodes:list()
  local out = {}
  for _, n in pairs(self.registry) do out[#out + 1] = n end
  table.sort(out, function(a, b) return a.address < b.address end)
  return out
end

-- Envoie une commande à un nœud. Renvoie ok ou (nil, raison).
function nodes:command(address, command, actor)
  if not self.registry[address] then return nil, "unknown_node" end
  if not protocol.NODE_COMMANDS[command] then return nil, "bad_command" end
  if not self.send then return nil, "no_transport" end
  self.send(address, { t = protocol.AGENT.EXEC, command = command })
  if self.logs then self.logs:add("fleet", actor or "?", "commande '" .. command .. "' -> " .. address) end
  return { address = address, command = command, sent = true }
end

return nodes
