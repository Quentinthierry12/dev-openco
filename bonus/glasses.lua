-- bonus/glasses.lua
-- HUD DEFCON pour les agents via OpenGlasses 2 (composant os_glasses / glasses terminal).
-- Squelette : affiche le niveau DEFCON courant en réalité augmentée. Les noms d'API OpenGlasses
-- sont À CONFIRMER en jeu (widgets addText / addRect selon la version).

local ROOT = (os.getenv and os.getenv("SECSITE_ROOT")) or "/home/secsite"
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path

local component = require("component")
local event = require("event")
local net = require("mineos/lib/net")
local session = require("mineos/lib/session")
local protocol = require("shared/protocol")

local glasses = {}

local COLORS = { [5] = 0x2E7D32, [4] = 0x9E9D24, [3] = 0xF9A825, [2] = 0xEF6C00, [1] = 0xB71C1C }

function glasses.available()
  return component.isAvailable("glasses") or component.isAvailable("os_glasses")
end

function glasses.run()
  if not glasses.available() then print("Aucune OpenGlasses détectée."); return end
  local g = component.isAvailable("glasses") and component.glasses or component.os_glasses
  pcall(function() g.removeAll() end)
  local label = pcall(function() return g.addTextLabel and g.addTextLabel() end) and g.addTextLabel() or nil

  while true do
    local rs = net.request(protocol.request(protocol.REQ.RADAR_STATE, { token = session.token() }))
    if rs and rs.ok then
      local d = rs.data.defcon or 5
      pcall(function()
        if label then
          label.setText("DEFCON " .. d .. (rs.data.alert and "  ALERTE" or ""))
          if label.setColor then label.setColor(COLORS[d] or 0xFFFFFF) end
        end
      end)
    end
    if event.pull(2, "interrupted") then break end
  end
end

return glasses
