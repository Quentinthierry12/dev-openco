-- server/adapters/alarm.lua
-- Sortie « alerte » : sirène OpenSecurity (os_alarm) + diffusion chat via Computronics (chat_box)
-- + éventuel son. Dégradation gracieuse : chaque canal est optionnel.
-- Noms de méthodes À CONFIRMER en jeu (isolés ici volontairement).

local component = require("component")

local alarm = {}

local function safe(kind, fn)
  if component.isAvailable(kind) then
    pcall(fn, component[kind])
  end
end

-- Diffuse un message dans le chat du serveur (Computronics chatbox).
function alarm.chat(message)
  safe("chat_box", function(box)
    if box.say then box.say(message) else box.send(message) end
  end)
end

-- Active/désactive la sirène et annonce l'état.
function alarm.set(on, message)
  safe("os_alarm", function(a)
    if on then
      if a.activate then a.activate() elseif a.setActive then a.setActive(true) end
    else
      if a.deactivate then a.deactivate() elseif a.setActive then a.setActive(false) end
    end
  end)
  if message then alarm.chat((on and "[ALERTE] " or "[INFO] ") .. message) end
end

return alarm
