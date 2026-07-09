-- server/services/defense.lua
-- Contre-mesures anti-missile. Modes : off / manual / auto.
--   auto   : engage automatiquement quand la menace atteint le niveau (DEFCON <= engageLevel)
--   manual : ne tire que sur ordre explicite (fire)
--   off    : ne tire jamais
-- Logique PURE : l'actionnement physique est une fonction `actuate(emplacement, threat)` injectée.

local cfg = require("shared/defense")

local defense = {}
defense.__index = defense

function defense.new(opts)
  opts = opts or {}
  return setmetatable({
    actuate = opts.actuate,       -- fn(emplacement, threat) : impulsion redstone / launch composant
    logs = opts.logs,
    mode = opts.mode or cfg.DEFAULT_MODE,
    engageLevel = opts.engageLevel or cfg.ENGAGE_LEVEL,
    lastFire = nil,
    engaging = false, -- évite les tirs répétés tant que l'alerte dure (auto)
  }, defense)
end

function defense:setMode(mode, actor)
  if mode ~= "off" and mode ~= "manual" and mode ~= "auto" then return nil, "bad_mode" end
  self.mode = mode
  if self.logs then self.logs:add("defense", actor or "system", "mode -> " .. mode) end
  return { mode = mode }
end

local function fireAll(self, threat, actor, reason)
  local fired = 0
  for _, e in ipairs(cfg.EMPLACEMENTS) do
    if self.actuate then
      local ok = pcall(self.actuate, e, threat)
      if ok then fired = fired + 1 end
    end
  end
  self.lastFire = { count = fired, reason = reason }
  if self.logs then self.logs:add("defense", actor or "system", "TIR contre-mesures (" .. reason .. ") x" .. fired) end
  return fired
end

-- Appelé sur escalade radar. threat = { defcon, contacts }.
function defense:engage(threat)
  threat = threat or {}
  if self.mode ~= "auto" then return { fired = 0, mode = self.mode } end
  local defcon = threat.defcon or 5
  if defcon > self.engageLevel then
    self.engaging = false
    return { fired = 0 }
  end
  if self.engaging then return { fired = 0 } end -- déjà engagé pour cette alerte
  self.engaging = true
  return { fired = fireAll(self, threat, "auto", "auto"), auto = true }
end

-- Réarme l'engagement auto quand la menace retombe (appelé par le radar en fin d'alerte).
function defense:standDown()
  self.engaging = false
end

-- Tir manuel (ordre explicite).
function defense:fire(actor)
  if self.mode == "off" then return nil, "mode_off" end
  return { fired = fireAll(self, { manual = true }, actor, "manuel") }
end

function defense:status()
  return { mode = self.mode, engageLevel = self.engageLevel, lastFire = self.lastFire }
end

return defense
