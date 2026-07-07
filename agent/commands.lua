-- agent/commands.lua
-- Exécution locale des commandes de gestion à distance sur la machine hôte.
-- reboot/shutdown coupent la machine (pas de réponse) ; status renvoie un état.

local computer = require("computer")

local commands = {}

function commands.exec(command)
  if command == "reboot" then
    computer.shutdown(true)  -- redémarre
    return { done = true }
  elseif command == "shutdown" then
    computer.shutdown(false) -- éteint
    return { done = true }
  elseif command == "lock" then
    -- Verrou logique : positionne un drapeau lu par le login/kiosque du terminal.
    _G.SECSITE_LOCKED = true
    return { locked = true }
  elseif command == "status" then
    return {
      address = computer.address and computer.address() or "?",
      uptime = computer.uptime(),
      energy = computer.energy and computer.energy() or nil,
      maxEnergy = computer.maxEnergy and computer.maxEnergy() or nil,
      locked = _G.SECSITE_LOCKED == true,
    }
  end
  return nil, "bad_command"
end

return commands
