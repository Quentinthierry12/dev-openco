-- server/services/situation.lua
-- Agrège l'« état de situation » du site pour la salle de contrôle : DEFCON, alerte/alarme,
-- lockdown, ETA avant impact, risque d'impact, temps de lockdown complet, portes importantes.
-- Logique PURE : radar/doors sont injectés (ou passés en argument) -> testable hors-jeu.

local siteCfg = require("shared.site")

local situation = {}
situation.__index = situation

function situation.new(opts)
  opts = opts or {}
  return setmetatable({
    radar = opts.radar,
    doors = opts.doors,
    site = opts.site or siteCfg.CONFIG,
  }, situation)
end

local function dist3(a, b)
  local dx, dy, dz = (a.x or 0) - b.x, (a.y or 0) - b.y, (a.z or 0) - b.z
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Estime le temps de lockdown complet (fermeture de toutes les portes).
local function lockdownFullSeconds(doorsAll, site)
  local t = 0
  for _, d in ipairs(doorsAll or {}) do
    if d.type == "airlock" then t = t + site.lockdown.airlockSeconds
    else t = t + site.lockdown.perDoorSeconds end
  end
  return t
end

-- compute(radarState, doorsAll, locked) — arguments optionnels si services injectés.
function situation:compute(radarState, doorsAll, locked)
  if not radarState and self.radar then radarState = self.radar:state() end
  radarState = radarState or { defcon = 5, contacts = {}, alert = false }
  if self.doors then
    doorsAll = doorsAll or self.doors:all()
    if locked == nil then locked = self.doors:isLocked() end
  end
  doorsAll = doorsAll or {}

  local contacts = radarState.contacts or {}
  local c = self.site.center

  -- ETA minimal + présence de données positionnelles.
  local eta, positional = nil, false
  for _, k in ipairs(contacts) do
    if k.x and k.y and k.z then
      positional = true
      local speed = k.velocity or k.speed
      if speed and speed > 0 then
        local t = dist3(k, c) / speed
        if not eta or t < eta then eta = t end
      end
    end
  end

  -- Risque : selon l'alerte + ETA (heuristique). Sans données positionnelles -> inconnu.
  local risk
  if not radarState.alert then
    risk = "aucun"
  elseif not positional then
    risk = "inconnu"
  elseif eta and eta <= 10 then
    risk = "élevé"
  elseif eta and eta <= 30 then
    risk = "moyen"
  else
    risk = "faible"
  end

  -- Portes importantes (sas, silo, bunker).
  local important = {}
  for _, d in ipairs(doorsAll) do
    if d.type == "airlock" or d.type == "silo" or d.type == "bunker" then
      important[#important + 1] = { id = d.id, name = d.name, type = d.type, state = d.state }
    end
  end

  return {
    site = self.site.name,
    defcon = radarState.defcon,
    alert = radarState.alert == true,
    alarm = radarState.alert == true, -- la sirène suit l'alerte
    locked = locked == true,
    contacts = #contacts,
    impactETA = eta,                                    -- secondes, ou nil si inconnu
    impactRisk = risk,                                  -- aucun/inconnu/faible/moyen/élevé
    lockdownFullSeconds = lockdownFullSeconds(doorsAll, self.site),
    lockdownRemaining = (locked and 0) or nil,          -- 0 si déjà verrouillé
    importantDoors = important,
  }
end

return situation
