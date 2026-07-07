-- server/services/radar.lua
-- Calcule le niveau DEFCON à partir d'un « reading » (radar_source), et déclenche les réponses
-- sur escalade : sirène (alarm), verrouillage (doors:lockdown), diffusion (broadcast), journal.
-- Logique PURE : toutes les sorties sont des callbacks/services injectés -> testable hors-jeu.
--
-- Échelle : DEFCON 5 = calme … DEFCON 1 = missile imminent.

local radar = {}
radar.__index = radar

function radar.new(opts)
  opts = opts or {}
  return setmetatable({
    doors = opts.doors,            -- service portes (optionnel)
    logs = opts.logs,              -- journal (optionnel)
    broadcast = opts.broadcast,    -- fn(evt) diffusion réseau (optionnel)
    alarm = opts.alarm,            -- fn(on, message) sirène/chat (optionnel)
    alertLevel = opts.alertLevel or 2, -- DEFCON <= alertLevel => réponse
    autoLockdown = opts.autoLockdown ~= false, -- verrouiller à l'alerte (défaut oui)
    defcon = 5,
    contacts = {},
  }, radar)
end

local function levelFromReading(r)
  local m = r.missiles or 0
  if m <= 0 then
    local s = r.signal or 0
    if s <= 0 then return 5 end
    if s < 8 then return 3 end
    return 2
  end
  if m == 1 then return 2 end
  return 1 -- plusieurs contacts = menace maximale
end

function radar:update(reading)
  reading = reading or {}
  local newLevel = levelFromReading(reading)
  local old = self.defcon
  self.defcon = newLevel
  self.contacts = reading.contacts or {}

  local changed = newLevel ~= old
  local nowAlert = newLevel <= self.alertLevel
  local wasAlert = old <= self.alertLevel

  if nowAlert and not wasAlert then
    -- Escalade vers l'alerte.
    if self.logs then self.logs:add("radar", "system", "ALERTE — DEFCON " .. newLevel, { contacts = #self.contacts }) end
    if self.alarm then pcall(self.alarm, true, "DEFCON " .. newLevel) end
    if self.doors and self.autoLockdown then self.doors:lockdown("radar") end
    if self.broadcast then pcall(self.broadcast, { evt = "alert", defcon = newLevel, contacts = self.contacts }) end
  elseif wasAlert and not nowAlert then
    -- Fin d'alerte.
    if self.logs then self.logs:add("radar", "system", "fin d'alerte — DEFCON " .. newLevel) end
    if self.alarm then pcall(self.alarm, false) end
    if self.doors and self.autoLockdown then self.doors:release("radar") end
    if self.broadcast then pcall(self.broadcast, { evt = "clear", defcon = newLevel }) end
  elseif changed and self.logs then
    self.logs:add("radar", "system", "DEFCON " .. newLevel)
  end

  return { defcon = self.defcon, changed = changed, alert = nowAlert }
end

function radar:state()
  return { defcon = self.defcon, contacts = self.contacts, alert = self.defcon <= self.alertLevel }
end

return radar
