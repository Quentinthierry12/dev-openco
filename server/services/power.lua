-- server/services/power.lua
-- Supervision réacteurs / énergie. Logique PURE : reçoit un « readings » (adaptateur hbm_machine)
-- et calcule un statut par machine (ok/warn/crit) + déclenche alarme/SCRAM sur seuil critique.
-- Callbacks injectés -> testable hors-jeu.

local cfg = require("shared.reactors")

local power = {}
power.__index = power

function power.new(opts)
  opts = opts or {}
  return setmetatable({
    logs = opts.logs,
    alarm = opts.alarm,        -- fn(on, message)
    onCritical = opts.onCritical, -- fn(reactor, reading) : ex. déclencher un SCRAM
    readings = {},             -- id -> { name, temp, fuel, power, energy, status }
    crit = {},                 -- id -> true si déjà en critique (anti-spam)
  }, power)
end

local function statusOf(r, reading)
  if r.energyOnly then return "ok" end
  local t = reading.temp
  if not t then return "unknown" end
  if r.tempCrit and t >= r.tempCrit then return "crit" end
  if r.tempWarn and t >= r.tempWarn then return "warn" end
  return "ok"
end

-- update(readings) : readings = { [id] = { temp, fuel, power, energy } }
function power:update(readings)
  readings = readings or {}
  for _, r in ipairs(cfg.CONFIG) do
    local reading = readings[r.id] or {}
    local status = statusOf(r, reading)
    self.readings[r.id] = {
      id = r.id, name = r.name,
      temp = reading.temp, fuel = reading.fuel, power = reading.power, energy = reading.energy,
      status = status,
    }
    -- Front montant vers l'état critique.
    if status == "crit" and not self.crit[r.id] then
      self.crit[r.id] = true
      if self.logs then self.logs:add("reactor", "system", "CRITIQUE: " .. r.name .. " temp=" .. tostring(reading.temp)) end
      if self.alarm then pcall(self.alarm, true, "Réacteur " .. r.name .. " CRITIQUE") end
      if self.onCritical then pcall(self.onCritical, r, reading) end
    elseif status ~= "crit" then
      self.crit[r.id] = nil
    end
  end
  return self:state()
end

function power:state()
  local out = {}
  for _, r in ipairs(cfg.CONFIG) do
    out[#out + 1] = self.readings[r.id] or { id = r.id, name = r.name, status = "unknown" }
  end
  return out
end

return power
