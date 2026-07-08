-- server/adapters/radar_source.lua
-- Source unifiée du radar : privilégie le COMPOSANT OpenComputers exposé par notre fork HBM
-- (component.hbm_radar), sinon REPLI sur un signal redstone. Le service radar ne connaît que
-- la forme du « reading » renvoyé ici, jamais la manière de l'obtenir.

local component = require("component")
local redin = require("server.adapters.redstone_in")

local radar_source = {}

-- Config du repli redstone (face + éventuel canal bundled du radar HBM).
radar_source.CONFIG = { side = "north", channel = nil }

-- Renvoie un « reading » : { source, missiles, contacts?, signal? }
function radar_source.read()
  if component.isAvailable("hbm_radar") then
    local r = component.hbm_radar
    local ok, contacts = pcall(function()
      return r.getContacts() -- méthode définie par notre fork HBM (hbm-fork/)
    end)
    contacts = (ok and type(contacts) == "table") and contacts or {}
    return { source = "oc", contacts = contacts, missiles = #contacts }
  end

  -- Repli redstone : un signal > 0 = missile(s) détecté(s).
  local cfg = radar_source.CONFIG
  local signal
  if cfg.channel then
    signal = redin.getBundled(cfg.side, cfg.channel)
  else
    signal = redin.get(cfg.side)
  end
  return { source = "redstone", signal = signal, missiles = signal > 0 and 1 or 0, contacts = {} }
end

return radar_source
