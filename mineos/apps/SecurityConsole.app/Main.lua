-- SecurityConsole.app/Main.lua
-- Application MineOS — coquille du tableau de bord de sécurité (lot 1).
-- Utilise le framework GUI de MineOS (workspaces / conteneurs / widgets).
-- Les widgets DEFCON / portes / alertes seront ajoutés au lot 2.

local ROOT = (os.getenv and os.getenv("SECSITE_ROOT")) or "/home/secsite"
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path

local GUI = require("GUI")
local system = require("System")
local net = require("mineos.lib.net")
local session = require("mineos.lib.session")
local protocol = require("shared.protocol")

-- Couleur d'affichage selon le niveau DEFCON (5 calme -> 1 imminent).
local DEFCON_COLOR = { [5] = 0x2E7D32, [4] = 0x9E9D24, [3] = 0xF9A825, [2] = 0xEF6C00, [1] = 0xB71C1C }

-- Fenêtre principale.
local workspace, window = system.addWindow(GUI.filledWindow(1, 1, 88, 26, 0x1E1E1E))

window:addChild(GUI.panel(1, 1, window.width, 3, 0x2D2D2D))
window:addChild(GUI.text(3, 2, 0xFFFFFF, "SECURITY CONSOLE — Intranet"))

local statusLabel = window:addChild(GUI.text(3, 5, 0xAAAAAA, "Serveur : vérification…"))
local defconPanel = window:addChild(GUI.panel(3, 7, 40, 3, 0x333333))
local defconLabel = window:addChild(GUI.text(5, 8, 0xFFFFFF, "DEFCON : —"))

-- Interroge serveur (ping) + état radar (DEFCON).
local function refresh()
  local resp = net.ping()
  if resp and resp.ok then
    statusLabel.text = "Serveur : EN LIGNE (protocole v" .. tostring(resp.data.v) .. ")"
    statusLabel.color = 0x44DD44
  else
    statusLabel.text = "Serveur : INJOIGNABLE"
    statusLabel.color = 0xDD4444
  end

  local rs = net.request(protocol.request(protocol.REQ.RADAR_STATE, { token = session.token() }))
  if rs and rs.ok then
    local d = rs.data.defcon or 5
    defconLabel.text = "DEFCON : " .. d .. (rs.data.alert and "  ⚠ ALERTE" or "")
    defconPanel.color = DEFCON_COLOR[d] or 0x333333
  end
  workspace:draw()
end

window:addChild(GUI.button(3, 7, 24, 3, 0x3C3C3C, 0xFFFFFF, 0x2D2D2D, 0xFFFFFF, "Rafraîchir")).onTouch = function()
  refresh()
end

window:addChild(GUI.text(3, 12, 0x888888, "Modules à venir (lot 2) : DEFCON • Portes • Alarmes • Journal"))

refresh()
workspace:draw()
