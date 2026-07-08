-- server/services/settings.lua
-- Réglages runtime éditables en jeu (Config.app), persistés et appliqués à chaud aux services.
-- Seules les clés du SCHEMA sont acceptées (type contrôlé) -> pas d'édition de fichiers de code.

local util = require("shared.util")

local settings = {}
settings.__index = settings

-- Clés autorisées et leur type.
settings.SCHEMA = {
  ["site.name"] = "string",
  ["site.radius"] = "number",
  ["radar.alertLevel"] = "number",
  ["defense.mode"] = "string",
  ["defense.engageLevel"] = "number",
}

-- opts.apply = function(key, value) : applique le réglage aux services vivants.
function settings.new(opts)
  opts = opts or {}
  return setmetatable({ path = opts.path, values = {}, apply = opts.apply }, settings)
end

local function coerce(t, value)
  if t == "number" then return tonumber(value)
  elseif t == "boolean" then return value == true or value == "true"
  elseif t == "string" then return tostring(value) end
  return nil
end

function settings:set(key, value, actor)
  local t = settings.SCHEMA[key]
  if not t then return nil, "unknown_key" end
  local v = coerce(t, value)
  if v == nil then return nil, "bad_value" end
  self.values[key] = v
  self:save()
  if self.apply then pcall(self.apply, key, v) end
  return { key = key, value = v }
end

function settings:list()
  local out = {}
  for key, t in pairs(settings.SCHEMA) do
    out[#out + 1] = { key = key, type = t, value = self.values[key] }
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

-- Applique tous les réglages chargés (au démarrage).
function settings:applyAll()
  if not self.apply then return end
  for key, v in pairs(self.values) do pcall(self.apply, key, v) end
end

function settings:save()
  if not self.path then return end
  local f = io.open(self.path, "w"); if not f then return end
  f:write(util.serialize(self.values)); f:close()
end

function settings:load()
  if not self.path then return end
  local f = io.open(self.path, "r"); if not f then return end
  local t = util.deserialize(f:read("*a")); f:close()
  if type(t) == "table" then self.values = t end
end

return settings
