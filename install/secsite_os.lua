-- install/secsite_os.lua
-- « SecSite OS » : transforme une installation MineOS en terminal de sécurité prêt à l'emploi.
--   1) déploie nos apps dans le dossier Applications de MineOS
--   2) enregistre le secret réseau
--   3) installe l'enrobage de login (auth carte) en autorun (non invasif)
--   4) branding + mode kiosque optionnel
-- À lancer sur la machine MineOS (carte Internet requise).

local component = require("component")
local fs = require("filesystem")
local term = require("term")

local DEFAULT_BASE = "https://raw.githubusercontent.com/Quentinthierry12/dev-openco/claude/opencomputer-security-site-jw7rga"
local DEFAULT_ROOT = "/home/secsite"
local DEFAULT_APPS = "/Applications"

local function ask(label, default)
  io.write(label .. (default and (" [" .. default .. "]") or "") .. ": ")
  local a = term.read()
  if not a then return default end
  a = a:gsub("%s+$", "")
  if a == "" then return default end
  return a
end

if not component.isAvailable("internet") then print("ERREUR: carte Internet requise."); return end
local internet = require("internet")

local function ensureDir(p) if p and p ~= "" and not fs.exists(p) then fs.makeDirectory(p) end return fs.exists(p) end
local function download(url)
  local ok, h = pcall(internet.request, url); if not ok then return nil, tostring(h) end
  local buf = {}; for c in h do buf[#buf + 1] = c end; return table.concat(buf)
end
local function writeFile(path, data)
  ensureDir(path:match("^(.*)/[^/]+$")); local f = io.open(path, "w")
  if not f then return false end; f:write(data); f:close(); return true
end

print("=== Installation SecSite OS (terminal MineOS) ===")
local base = ask("URL de base (GitHub raw)", DEFAULT_BASE)
local root = ask("Dossier SecSite", DEFAULT_ROOT)
local appsDir = ask("Dossier Applications MineOS", DEFAULT_APPS)
local kiosk = ask("Mode kiosque verrouillé ? (o/n)", "n") == "o"
ensureDir(root); ensureDir(appsDir); ensureDir(root .. "/server/data")

-- 1) Déploiement des fichiers + copie des apps.
local manText = download(base .. "/install/manifest.lua")
if not manText then print("Échec manifeste."); return end
local chunk = load(manText, "=manifest", "t", _G); if not chunk then print("Manifeste illisible."); return end
local files = chunk().ROLES.terminal
-- l'autorun n'est pas forcément dans le manifeste : on l'ajoute explicitement
local extra = { "mineos/login-fork/autorun.lua", "shared/branding.lua" }
for _, e in ipairs(extra) do files[#files + 1] = e end

print("Téléchargement de " .. #files .. " fichiers…")
local apps = 0
for _, rel in ipairs(files) do
  local data = download(base .. "/" .. rel)
  if data then
    writeFile(root .. "/" .. rel, data)
    local appRel = rel:match("^mineos/apps/(.+)$")
    if appRel then writeFile(appsDir .. "/" .. appRel, data); if appRel:match("/Main%.lua$") then apps = apps + 1 end end
  else
    print("  ! échec " .. rel)
  end
end
print("  " .. apps .. " apps copiées dans " .. appsDir)

-- 2) Secret réseau.
local secret = ask("Secret réseau (>=8 car., identique au serveur)", "")
if #secret >= 8 then writeFile(root .. "/server/data/secret", secret); print("Secret enregistré.")
else print("Secret ignoré (trop court) — à reporter avant usage.") end

-- 3) Config locale (rôle + kiosque).
writeFile(root .. "/secsite.cfg", ("{role=%q,kind=%q,root=%q,kiosk=%s}"):format("terminal", "terminal", root, tostring(kiosk)))

-- 4) Enregistrement de l'autorun (enrobage de login) — non invasif, avec repli manuel.
local AUTORUN_LINE = 'dofile("' .. root .. '/mineos/login-fork/autorun.lua")'
local STARTUP_CANDIDATES = { "/Autoruns.lua", "/OS.lua" }
local registered = false
for _, cand in ipairs(STARTUP_CANDIDATES) do
  if fs.exists(cand) then
    local rf = io.open(cand, "r"); local content = rf and rf:read("*a") or ""; if rf then rf:close() end
    if not content:find(AUTORUN_LINE, 1, true) then
      if not fs.exists(cand .. ".secsite.bak") then fs.copy(cand, cand .. ".secsite.bak") end
      local wf = io.open(cand, "a")
      if wf then wf:write("\n-- SecSite OS autorun\n" .. AUTORUN_LINE .. "\n"); wf:close(); registered = true
        print("Autorun enregistré dans " .. cand .. " (sauvegarde .secsite.bak)") end
    else registered = true end
    break
  end
end

print("")
print("=== SecSite OS installé ===")
print("Kiosque: " .. (kiosk and "ACTIVÉ" or "désactivé"))
if not registered then
  print("Autorun NON enregistré automatiquement. Ajoutez cette ligne au démarrage de MineOS :")
  print("  " .. AUTORUN_LINE)
end
print("Login carte : le module patch.tryCardLogin() est aussi utilisable pour un test manuel.")
print("Reboot pour appliquer.")
