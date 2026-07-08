-- server/adapters/door_driver.lua
-- Driver unifié de portes : traduit un ordre logique (ouvrir/fermer un battant) en action
-- physique, que la porte soit pilotée en redstone (HBM/blast/silo) ou par un composant
-- OpenSecurity (os_secdoor). Utilisé par server/services/doors.lua via l'interface :write().

local component = require("component")
local redout = require("server/adapters/redstone_out")

local driver = {}
driver.__index = driver

function driver.new()
  return setmetatable({}, driver)
end

-- door = entrée de config (shared/doors.lua) ; key = "main" | "inner" | "outer" ; on = booléen.
function driver:write(door, key, on)
  local d = door.driver
  if not d then return false end

  if d.kind == "redstone" then
    local channel
    if key == "inner" then channel = d.channelInner
    elseif key == "outer" then channel = d.channelOuter
    else channel = d.channel end
    local value = on and 15 or 0
    if channel then
      return redout.setBundled(d.side, channel, value)
    end
    return redout.set(d.side, value)

  elseif d.kind == "os_secdoor" then
    -- OpenSecurity Door Controller : open(password) / close(password) / isOpen().
    -- Le mot de passe (optionnel) vient de la config de la porte.
    if not d.address then return false end
    local ok, proxy = pcall(component.proxy, d.address)
    if not ok or not proxy then return false end
    local pw = d.password
    if on then
      return (pcall(proxy.open, pw))
    else
      return (pcall(proxy.close, pw))
    end

  elseif d.kind == "hbm_oc" then
    -- Porte HBM exposée par l'addon OpenComputers (hbm-oc-addon/) : composant hbm_door.
    if not d.address then return false end
    local ok, proxy = pcall(component.proxy, d.address)
    if not ok or not proxy then return false end
    if on then
      return (pcall(proxy.open))
    else
      return (pcall(proxy.close))
    end
  end

  return false
end

return driver
