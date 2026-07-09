-- bonus/hologram.lua
-- Carte 3D holographique des menaces via le projecteur d'hologramme OpenComputers (Tier 2).
-- Squelette : place un point par contact radar (coordonnées relatives). Nécessite que la source
-- radar fournisse des contacts avec x/y/z (cas du fork HBM OC ; en repli redstone, pas de position).

local ROOT = (os.getenv and os.getenv("SECSITE_ROOT")) or "/home/secsite"
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. (package.path or "")

local component = require("component")
local event = require("event")
local net = require("mineos/lib/net")
local session = require("mineos/lib/session")
local protocol = require("shared/protocol")

local holo = {}

function holo.available()
  return component.isAvailable("hologram")
end

function holo.run()
  if not holo.available() then print("Aucun projecteur d'hologramme."); return end
  local h = component.hologram
  while true do
    local rs = net.request(protocol.request(protocol.REQ.RADAR_STATE, { token = session.token() }))
    pcall(function() h.clear() end)
    if rs and rs.ok and rs.data.contacts then
      for _, c in ipairs(rs.data.contacts) do
        if c.x and c.y and c.z then
          -- Recentre sur la grille 48x32x48 du projecteur.
          local x = math.max(1, math.min(48, math.floor(24 + (c.x or 0))))
          local y = math.max(1, math.min(32, math.floor(1 + (c.y or 0))))
          local z = math.max(1, math.min(48, math.floor(24 + (c.z or 0))))
          pcall(function() h.set(x, y, z, 1) end)
        end
      end
    end
    if event.pull(1, "interrupted") then break end
  end
end

return holo
