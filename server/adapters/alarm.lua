-- server/adapters/alarm.lua
-- Sortie « alerte » : sirène OpenSecurity (os_alarm) + diffusion chat via Computronics (chat_box).
-- API confirmées :
--   os_alarm : activate(), deactivate(), setAlarm(sound), setRange(0-15), listSounds()
--   chat_box : say(message[, distance])

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
    box.say(message)
  end)
end

-- Active/désactive la sirène et annonce l'état.
function alarm.set(on, message)
  safe("os_alarm", function(a)
    if on then a.activate() else a.deactivate() end
  end)
  if message then alarm.chat((on and "[ALERTE] " or "[INFO] ") .. message) end
end

return alarm
