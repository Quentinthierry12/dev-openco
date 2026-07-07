-- server/adapters/redstone_out.lua
-- Écriture des sorties redstone (commande des portes HBM/blast/silo). Simple ou bundled (Project Red).

local component = require("component")

local redout = {}

redout.SIDES = { down = 0, up = 1, north = 2, south = 3, west = 4, east = 5 }

local function rs()
  if component.isAvailable("redstone") then return component.redstone end
  return nil
end

local function sideNum(side)
  if type(side) == "number" then return side end
  return redout.SIDES[side] or 3
end

-- Sortie simple : value 0..15.
function redout.set(side, value)
  local r = rs()
  if not r then return false end
  return (pcall(r.setOutput, sideNum(side), value or 0))
end

-- Sortie bundled sur un canal (0..15).
function redout.setBundled(side, channel, value)
  local r = rs()
  if not r then return false end
  return (pcall(r.setBundledOutput, sideNum(side), channel, value or 0))
end

function redout.available()
  return rs() ~= nil
end

return redout
