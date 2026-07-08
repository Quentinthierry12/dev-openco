-- server/adapters/redstone_in.lua
-- Lecture des entrées redstone (capteurs, repli radar). Supporte le redstone simple et le
-- redstone *bundled* (Project Red : jusqu'à 16 canaux par face).
-- Dépend d'OpenComputers -> vérifié en jeu (les tests de logique n'en dépendent pas).

local component = require("component")

local redin = {}

-- Faces Minecraft (valeurs OpenComputers).
redin.SIDES = { down = 0, up = 1, north = 2, south = 3, west = 4, east = 5 }

local function rs()
  if component.isAvailable("redstone") then return component.redstone end
  return nil
end

local function sideNum(side)
  if type(side) == "number" then return side end
  return redin.SIDES[side] or 3
end

-- Entrée simple d'une face : 0..15 (0 si pas de carte redstone).
function redin.get(side)
  local r = rs()
  if not r then return 0 end
  local ok, v = pcall(r.getInput, sideNum(side))
  return ok and v or 0
end

-- Entrée bundled (canal/couleur 0..15) : 0..15.
function redin.getBundled(side, channel)
  local r = rs()
  if not r then return 0 end
  local ok, v = pcall(r.getBundledInput, sideNum(side), channel)
  return ok and v or 0
end

function redin.available()
  return rs() ~= nil
end

return redin
