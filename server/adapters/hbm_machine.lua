-- server/adapters/hbm_machine.lua
-- Lecture des réacteurs / machines HBM via l'addon OC (composants hbm_reactor / hbm_machine).
-- Dépend d'OpenComputers -> vérifié en jeu. Renvoie un « readings » consommé par services/power.

local component = require("component")
local cfg = require("shared.reactors")

local hbm = {}

local function call(proxy, method)
  local ok, v = pcall(proxy[method])
  if ok and type(v) == "number" then return v end
  return nil
end

-- read() -> { [id] = { temp, fuel, power, energy } }
function hbm.read()
  local out = {}
  for _, r in ipairs(cfg.CONFIG) do
    local reading = {}
    if r.address then
      local ok, proxy = pcall(component.proxy, r.address)
      if ok and proxy then
        if r.energyOnly then
          reading.energy = call(proxy, "getEnergy")
        else
          reading.temp = call(proxy, "getTemp")
          reading.fuel = call(proxy, "getFuel")
          reading.power = call(proxy, "getPower")
        end
      end
    end
    out[r.id] = reading
  end
  return out
end

-- Arrêt d'urgence d'un réacteur (composant hbm_reactor.scram()).
function hbm.scram(address)
  if not address then return false end
  local ok, proxy = pcall(component.proxy, address)
  if ok and proxy then return (pcall(proxy.scram)) end
  return false
end

return hbm
