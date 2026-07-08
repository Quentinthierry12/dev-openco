-- server/services/logs.lua
-- Journal d'audit horodaté. Persistance optionnelle (fichier) pour rester testable hors-jeu :
-- sans `path`, tout reste en mémoire.

local util = require("shared.util")

local logs = {}
logs.__index = logs

function logs.new(opts)
  opts = opts or {}
  return setmetatable({
    entries = {},
    path = opts.path,     -- fichier de persistance (optionnel)
    max = opts.max or 500, -- taille max en mémoire
  }, logs)
end

function logs:add(kind, actor, message, meta)
  local entry = {
    ts = util.now(),
    stamp = util.stamp(),
    kind = kind,
    actor = actor,
    message = message,
    meta = meta,
  }
  self.entries[#self.entries + 1] = entry
  -- Fenêtre glissante en mémoire.
  while #self.entries > self.max do
    table.remove(self.entries, 1)
  end
  self:save()
  return entry
end

-- Renvoie les `limit` dernières entrées (copie, plus récentes en dernier).
function logs:query(limit)
  limit = limit or 50
  local n = #self.entries
  local out = {}
  local start = math.max(1, n - limit + 1)
  for i = start, n do
    out[#out + 1] = util.shallow(self.entries[i])
  end
  return out
end

function logs:save()
  if not self.path then return end
  local f = io.open(self.path, "w")
  if not f then return end
  f:write(util.serialize(self.entries))
  f:close()
end

function logs:load()
  if not self.path then return end
  local f = io.open(self.path, "r")
  if not f then return end
  local data = f:read("*a")
  f:close()
  local t = util.deserialize(data)
  if type(t) == "table" then self.entries = t end
end

return logs
