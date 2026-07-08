-- display/wall.lua
-- Écran de la salle de contrôle (mur d'écrans). Programme léger OpenOS (pas MineOS).
-- Rôle par écran : "center" (bascule plein écran en alerte) ou "left"/"right"/"info" (dashboard).
-- Rôle lu depuis l'argument de lancement, sinon depuis secsite.cfg (clé role_display).
--
-- Lancement : display/wall.lua center

local ROOT = (os.getenv and os.getenv("SECSITE_ROOT")) or "/home/secsite"
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path

local component = require("component")
local computer = require("computer")
local event = require("event")
local net = require("mineos/lib/net")
local session = require("mineos/lib/session")
local protocol = require("shared/protocol")

local args = { ... }
local role = args[1] or "info"

local gpu = component.gpu
local DEFCON_BG = { [5] = 0x1B5E20, [4] = 0x827717, [3] = 0xF57F17, [2] = 0xE65100, [1] = 0xB71C1C }

local function center(y, text, fg)
  local w = select(1, gpu.getResolution())
  gpu.setForeground(fg or 0xFFFFFF)
  gpu.set(math.max(1, math.floor((w - #text) / 2)), y, text)
end

local function fmtETA(s)
  if not s then return "—" end
  return string.format("%dm%02ds", math.floor(s / 60), math.floor(s % 60))
end

local function drawAlert(sit)
  local w, h = gpu.getResolution()
  gpu.setBackground(0xB71C1C); gpu.fill(1, 1, w, h, " ")
  center(math.floor(h / 2) - 3, "!!! ALERTE MISSILE !!!")
  center(math.floor(h / 2) - 1, "DEFCON " .. tostring(sit.defcon))
  center(math.floor(h / 2) + 1, "Impact estime: " .. fmtETA(sit.impactETA) .. "   Risque: " .. tostring(sit.impactRisk))
  center(math.floor(h / 2) + 3, "Contacts: " .. tostring(sit.contacts) .. "   Lockdown: " .. (sit.locked and "ACTIF" or "—"))
end

local function drawDashboard(sit)
  local w, h = gpu.getResolution()
  gpu.setBackground(DEFCON_BG[sit.defcon] or 0x111111); gpu.fill(1, 1, w, 3, " ")
  center(2, (sit.site or "SITE") .. "  —  DEFCON " .. tostring(sit.defcon))
  gpu.setBackground(0x0A0A0A); gpu.fill(1, 4, w, h - 3, " ")
  local y = 6
  local function line(label, val)
    gpu.setForeground(0x9E9E9E); gpu.set(4, y, label)
    gpu.setForeground(0xFFFFFF); gpu.set(28, y, tostring(val)); y = y + 2
  end
  line("Alerte", sit.alert and "OUI" or "non")
  line("Alarme", sit.alarm and "ON" or "off")
  line("Lockdown", sit.locked and "ACTIF" or "levé")
  line("Lockdown complet en", (sit.lockdownFullSeconds or 0) .. "s")
  line("Impact estime", fmtETA(sit.impactETA))
  line("Risque impact", sit.impactRisk or "—")
  line("Contacts", sit.contacts or 0)
  y = y + 1
  gpu.setForeground(0x9E9E9E); gpu.set(4, y, "Portes importantes:"); y = y + 1
  for _, d in ipairs(sit.importantDoors or {}) do
    local st = d.state or {}
    local open = st.open or st.inner or st.outer
    gpu.setForeground(open and 0xEF5350 or 0x66BB6A)
    gpu.set(6, y, "- " .. d.name .. " [" .. d.type .. "] " .. (open and "OUVERT" or "fermé")); y = y + 1
  end
end

while true do
  local resp = net.request(protocol.request(protocol.REQ.SITUATION_GET, { token = session.token() }), 2)
  local sit = (resp and resp.ok) and resp.data or { defcon = 5, alert = false, impactRisk = "—" }
  gpu.setBackground(0x000000); gpu.setForeground(0xFFFFFF)
  gpu.fill(1, 1, select(1, gpu.getResolution()), select(2, gpu.getResolution()), " ")
  if role == "center" and sit.alert then
    drawAlert(sit)
  else
    drawDashboard(sit)
  end
  if event.pull(2, "interrupted") then break end
end
