-- display/kiosk.lua
-- Écran KIOSQUE public (sans login) : DEFCON, nom du site, annonces, horloge.
-- Récupère l'info publique via KIOSK_GET (aucun token — le réseau privé signé suffit à cloisonner).
-- Lancement : display/kiosk.lua

local ROOT = (os.getenv and os.getenv("SECSITE_ROOT")) or "/home/secsite"
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. (package.path or "")

local component = require("component")
local event = require("event")
local net = require("mineos/lib/net")
local protocol = require("shared/protocol")

local gpu = component.gpu
local DEFCON_BG = { [5] = 0x1B5E20, [4] = 0x827717, [3] = 0xF57F17, [2] = 0xE65100, [1] = 0xB71C1C }

local function center(y, text, fg)
  local w = select(1, gpu.getResolution())
  gpu.setForeground(fg or 0xFFFFFF)
  gpu.set(math.max(1, math.floor((w - #text) / 2)), y, text)
end

while true do
  local resp = net.request(protocol.request(protocol.REQ.KIOSK_GET), 2)
  local d = (resp and resp.ok) and resp.data or { defcon = 5, alert = false }
  local w, h = gpu.getResolution()

  gpu.setBackground(DEFCON_BG[d.defcon] or 0x111111)
  gpu.fill(1, 1, w, 5, " ")
  center(2, d.site or "INSTALLATION")
  center(4, "DEFCON " .. tostring(d.defcon) .. (d.alert and "   ⚠ ALERTE" or "") .. (d.locked and "   LOCKDOWN" or ""))

  gpu.setBackground(0x0A0A0A)
  gpu.fill(1, 6, w, h - 5, " ")
  gpu.setForeground(0x888888); gpu.set(3, 7, "Annonces :")
  local y = 9
  for _, a in ipairs((d.board) or {}) do
    if y > h - 2 then break end
    gpu.setForeground(0xCCCCCC)
    gpu.set(4, y, "• " .. (a.text or "")); y = y + 1
  end
  gpu.setForeground(0x666666)
  center(h - 1, os.date("!%H:%M:%S"))

  if event.pull(3, "interrupted") then break end
end
