-- mineos/login-fork/install.lua
-- Prépare le fork du login MineOS (auth par carte OpenSecurity) et affiche l'insertion précise.
--
-- Structure réelle du login (MineOS `Libraries/System.lua`, fonction `system.authorize()`) :
--   * les profils = dossiers listés par filesystem.list(paths.system.users)
--   * le mot de passe est vérifié dans une fonction imbriquée :
--       local hash = require("SHA-256").hash(input.text)
--       if hash == userSettings.securityPassword then
--           container:remove()
--           updateUser(userName)      -- <- ouvre le bureau (local à authorize)
--   * `updateUser` étant LOCAL, on injecte NOTRE écouteur À L'INTÉRIEUR de system.authorize,
--     juste après que `container` et `updateUser` existent.

local fs = require("filesystem")

-- Emplacements plausibles de System.lua selon l'installation MineOS.
local TARGET_HINTS = {
  "/Libraries/System.lua",
  "/MineOS/Libraries/System.lua",
  "/mnt/*/Libraries/System.lua",
}

local function exists(p) return fs and fs.exists and fs.exists(p) end

local function backup(p)
  local bak = p .. ".secsite.bak"
  if exists(p) and not exists(bak) then fs.copy(p, bak); print("[secsite] sauvegarde: " .. bak) end
end

local SNIPPET = [[
-- === SecSite: auth par carte (à coller DANS system.authorize, après la création de
--     `container` et la définition de `updateUser`) ===
local secStop
secStop = require("mineos.login-fork.patch").cardListener(function(userName)
    -- N'accepte la carte que si un profil MineOS du même nom existe.
    if filesystem.exists(paths.system.users .. userName .. "/") then
        if secStop then secStop() end
        container:remove()
        updateUser(userName)
        workspace:draw()
    end
end)
-- Et : appeler secStop() sur la voie mot de passe juste avant/après container:remove().
]]

print("[secsite] Fork du login MineOS — préparation")
local target
for _, hint in ipairs(TARGET_HINTS) do
  if not hint:find("%*") and exists(hint) then target = hint break end
end

if target then
  backup(target)
  print("[secsite] System.lua détecté: " .. target .. " (sauvegardé)")
else
  print("[secsite] System.lua non trouvé automatiquement — repérez Libraries/System.lua.")
end

print("[secsite] 1) Ouvrez system.authorize() dans System.lua.")
print("[secsite] 2) Repérez la vérification du mot de passe :")
print("           local hash = require('SHA-256').hash(input.text)")
print("           if hash == userSettings.securityPassword then container:remove(); updateUser(userName)")
print("[secsite] 3) Juste après la création de `container` et de `updateUser`, insérez :")
print(SNIPPET)
print("[secsite] La voie mot de passe MineOS reste inchangée. patch.tryCardLogin() permet aussi")
print("           un test manuel immédiat sans toucher au login.")
