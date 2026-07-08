-- install/manifest.lua
-- Liste des fichiers à déployer par rôle. Utilisé par l'installateur (téléchargement) et
-- par les tests (vérifie que chaque fichier listé existe bien dans le dépôt).

local SHARED = {
  "shared/protocol.lua", "shared/netsec.lua", "shared/sha2.lua", "shared/util.lua",
  "shared/roles.lua", "shared/doors.lua", "shared/site.lua", "shared/protocols.lua",
  "shared/reactors.lua", "shared/defense.lua",
}

local APPS = {
  "mineos/apps/SecurityConsole.app/Main.lua",
  "mineos/apps/Access.app/Main.lua",
  "mineos/apps/Accounts.app/Main.lua",
  "mineos/apps/Badges.app/Main.lua",
  "mineos/apps/Logs.app/Main.lua",
  "mineos/apps/Messages.app/Main.lua",
  "mineos/apps/Fleet.app/Main.lua",
  "mineos/apps/Protocols.app/Main.lua",
  "mineos/apps/Reactor.app/Main.lua",
  "mineos/apps/Defense.app/Main.lua",
}

local function concat(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    for _, v in ipairs(list) do out[#out + 1] = v end
  end
  return out
end

local manifest = {}

manifest.ROLES = {
  server = concat(SHARED, {
    "server/main.lua", "server/router.lua",
    "server/services/accounts.lua", "server/services/auth.lua", "server/services/logs.lua",
    "server/services/radar.lua", "server/services/doors.lua", "server/services/nodes.lua",
    "server/services/messaging.lua", "server/services/situation.lua", "server/services/protocols.lua",
    "server/services/power.lua", "server/services/defense.lua",
    "server/adapters/radar_source.lua", "server/adapters/redstone_in.lua",
    "server/adapters/redstone_out.lua", "server/adapters/door_driver.lua", "server/adapters/alarm.lua",
    "server/adapters/hbm_machine.lua", "server/adapters/defense_out.lua",
  }),
  terminal = concat(SHARED, {
    "mineos/lib/net.lua", "mineos/lib/card.lua", "mineos/lib/session.lua",
    "mineos/lib/writer.lua", "mineos/lib/blackout.lua",
    "mineos/login-fork/patch.lua", "mineos/login-fork/install.lua",
  }, APPS),
  agent = concat(SHARED, {
    "agent/main.lua", "agent/commands.lua",
  }),
  display = concat(SHARED, {
    "mineos/lib/net.lua", "mineos/lib/session.lua", "display/wall.lua",
  }),
  tablet = concat(SHARED, {
    "mineos/lib/net.lua", "mineos/lib/card.lua", "mineos/lib/session.lua", "remote/tablet.lua",
  }),
}

manifest.ROLE_LIST = { "server", "terminal", "agent", "display", "tablet" }

return manifest
