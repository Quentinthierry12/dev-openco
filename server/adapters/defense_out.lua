-- server/adapters/defense_out.lua
-- Actionne une contre-mesure : impulsion redstone (tourelle/CIWS) ou composant (silo intercepteur).
-- Dépend d'OpenComputers -> vérifié en jeu.

local component = require("component")
local redout = require("server/adapters/redstone_out")

local defense_out = {}

-- actuate(emplacement, threat) -> true/false
function defense_out.actuate(e, threat)
  if e.kind == "redstone" then
    -- Impulsion d'activation (le câblage/monostable gère la retombée).
    if e.channel then
      return redout.setBundled(e.side, e.channel, 15)
    end
    return redout.set(e.side, 15)

  elseif e.kind == "component" then
    if not e.address then return false end
    local ok, proxy = pcall(component.proxy, e.address)
    if not ok or not proxy then return false end
    -- Silo intercepteur : viser le premier contact si des coordonnées sont connues.
    local c = threat and threat.contacts and threat.contacts[1]
    if c and c.x and c.z then
      return (pcall(proxy.launch, c.x, c.z))
    end
    return (pcall(proxy.arm))
  end

  return false
end

return defense_out
