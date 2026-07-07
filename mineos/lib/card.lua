-- mineos/lib/card.lua
-- Adaptateur lecteur de carte OpenSecurity (magnétique ou RFID).
-- ⚠️ Les noms d'événement/champs exacts d'OpenSecurity sont À CONFIRMER en jeu ; ce module
-- centralise cette incertitude pour que le reste du code n'ait jamais à la connaître.

local component = require("component")
local computer = require("computer")
local event = require("event")

local card = {}

-- Noms d'événements candidats poussés au swipe (à ajuster une fois testé en jeu).
card.EVENTS = { magData = true, rfidData = true, magstripe = true, card = true }

-- Détecte un lecteur disponible. Renvoie (proxy, type) ou nil.
function card.reader()
  if component.isAvailable("os_magreader") then return component.os_magreader, "mag" end
  if component.isAvailable("os_rfidreader") then return component.os_rfidreader, "rfid" end
  return nil
end

function card.available()
  return card.reader() ~= nil
end

-- Extrait l'identifiant de carte depuis les champs de l'événement.
-- On prend le premier champ string « données » (les premiers champs sont souvent l'adresse).
local function extract(ev)
  for i = 3, #ev do
    local v = ev[i]
    if type(v) == "string" and #v > 0 and not v:match("^%x%x%x%x%x%x%x%x%-") then
      return v
    end
  end
  -- repli : renvoie le dernier champ string disponible
  for i = #ev, 3, -1 do
    if type(ev[i]) == "string" then return ev[i] end
  end
  return nil
end

-- Attend un swipe. Renvoie le cardId (string) ou nil au timeout.
function card.await(timeout)
  local deadline = timeout and (computer.uptime() + timeout) or nil
  while true do
    local remaining = deadline and (deadline - computer.uptime()) or nil
    if remaining and remaining <= 0 then return nil end
    local ev = { event.pull(remaining) }
    local name = ev[1]
    if name == nil then return nil end
    if card.EVENTS[name] then
      local id = extract(ev)
      if id then return id end
    end
  end
end

return card
