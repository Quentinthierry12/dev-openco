-- server/services/doors.lua
-- Moteur de portes typées. Logique PURE (état, interlock, lockdown) : l'effet physique passe par
-- un `driver` injecté (server/adapters/door_driver ou un mock en test) -> testable hors-jeu.
--
-- Types (shared/doors.lua) : simple | bunker | shelter | airlock | silo.
-- L'interlock du sas (airlock) garantit qu'un seul battant est ouvert à la fois.

local cfg = require("shared.doors")

local doors = {}
doors.__index = doors

function doors.new(driver, logs)
  local self = setmetatable({ driver = driver, logs = logs, state = {}, locked = false }, doors)
  for _, d in ipairs(cfg.CONFIG) do
    self.state[d.id] = { open = false, inner = false, outer = false }
  end
  return self
end

local function apply(self, door, key, on)
  if self.driver then
    pcall(function() self.driver:write(door, key, on) end)
  end
end

local function log(self, actor, msg, meta)
  if self.logs then self.logs:add("door", actor or "system", msg, meta) end
end

-- Portes non-sas : ouvrir/fermer.
function doors:set(id, open, actor)
  local door = cfg.get(id)
  if not door then return nil, "unknown_door" end
  if door.type == "airlock" then return nil, "use_airlock" end
  if self.locked and open then return nil, "locked" end
  self.state[id].open = open and true or false
  apply(self, door, "main", open)
  log(self, actor, (open and "ouverture " or "fermeture ") .. door.name)
  return { id = id, open = self.state[id].open }
end

-- Sas : which = "inner" | "outer". Interlock strict.
function doors:airlock(id, which, open, actor)
  local door = cfg.get(id)
  if not door or door.type ~= "airlock" then return nil, "not_airlock" end
  if which ~= "inner" and which ~= "outer" then return nil, "bad_battant" end
  if self.locked and open then return nil, "locked" end
  local st = self.state[id]
  local other = (which == "inner") and st.outer or st.inner
  if open and other then return nil, "interlock" end
  st[which] = open and true or false
  apply(self, door, which, open)
  log(self, actor, door.name .. " battant " .. which .. (open and " ouvert" or " fermé"))
  return { id = id, which = which, open = st[which] }
end

-- Verrouillage global : ferme tout et bloque les ouvertures.
function doors:lockdown(actor)
  self.locked = true
  for _, d in ipairs(cfg.CONFIG) do
    local st = self.state[d.id]
    if d.type == "airlock" then
      st.inner, st.outer = false, false
      apply(self, d, "inner", false)
      apply(self, d, "outer", false)
    else
      st.open = false
      apply(self, d, "main", false)
    end
  end
  if self.logs then self.logs:add("security", actor or "system", "LOCKDOWN activé") end
  return { locked = true }
end

function doors:release(actor)
  self.locked = false
  if self.logs then self.logs:add("security", actor or "system", "LOCKDOWN levé") end
  return { locked = false }
end

function doors:isLocked()
  return self.locked
end

function doors:status(id)
  return self.state[id]
end

-- Vue de toutes les portes (pour Access.app).
function doors:all()
  local out = {}
  for _, d in ipairs(cfg.CONFIG) do
    out[#out + 1] = {
      id = d.id, name = d.name, type = d.type, zone = d.zone,
      state = self.state[d.id], locked = self.locked,
    }
  end
  return out
end

return doors
