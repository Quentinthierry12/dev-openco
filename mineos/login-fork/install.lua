-- mineos/login-fork/install.lua
-- Applique (ou ré-applique après une mise à jour de MineOS) le patch d'auth par carte.
--
-- STRATÉGIE (minimale et ré-appliable) :
--   1. On NE modifie PAS en profondeur le cœur de MineOS. On ajoute un hook léger.
--   2. Le point d'injection exact du login MineOS est À CONFIRMER dans les sources
--      (typiquement la fenêtre de connexion gérée par le System API). Ce script marque
--      clairement l'endroit à câbler et sauvegarde toute cible avant de la toucher.
--
-- ⚠️ Ce squelette est volontairement défensif : il ne réécrit rien tant que la cible réelle
--    n'a pas été confirmée en jeu. Il prépare le terrain (dépôt du patch, sauvegarde, marqueur).

local fs = require("filesystem")

local TARGET_HINTS = {
  "/Fventuresecondary", -- placeholder
  "/lib/System.lua",
  "/Libraries/System.lua",
  "/MineOS/Libraries/System.lua",
}

local function exists(p) return fs and fs.exists and fs.exists(p) end

local function backup(p)
  if not exists(p) then return end
  local bak = p .. ".secsite.bak"
  if not exists(bak) then
    fs.copy(p, bak)
    print("[secsite] sauvegarde: " .. bak)
  end
end

print("[secsite] Installation du patch de login (carte OpenSecurity)")
print("[secsite] Le module patch.lua est prêt: mineos/login-fork/patch.lua")

-- Localise une cible plausible du login MineOS.
local target
for _, hint in ipairs(TARGET_HINTS) do
  if exists(hint) then target = hint break end
end

if not target then
  print("[secsite] Cible du login MineOS non trouvée automatiquement.")
  print("[secsite] À FAIRE (en jeu) : repérer la fenêtre de connexion dans les sources MineOS,")
  print("           puis y appeler patch.attach(onSuccess) pour brancher le swipe de carte.")
  print("           patch.tryCardLogin() est utilisable tel quel pour un test manuel.")
  return
end

backup(target)
print("[secsite] Cible détectée: " .. target)
print("[secsite] Injectez l'appel à require('mineos.lib... patch').attach(...) au point de login.")
print("[secsite] (ré-exécuter ce script après chaque update de MineOS)")
