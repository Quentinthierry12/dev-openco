-- install/mineos_deploy.lua
-- Déploie les fichiers du terminal SecSite ET copie les applications dans le dossier
-- Applications de MineOS. À lancer sur la machine MineOS (carte Internet requise).
--
-- Amorçage :
--   wget -f https://raw.githubusercontent.com/Quentinthierry12/dev-openco/claude/opencomputer-security-site-jw7rga/install/mineos_deploy.lua /tmp/deploy.lua && /tmp/deploy.lua

local component = require("component")
local fs = require("filesystem")
local term = require("term")

local DEFAULT_BASE = "https://raw.githubusercontent.com/Quentinthierry12/dev-openco/claude/opencomputer-security-site-jw7rga"
local DEFAULT_ROOT = "/home/secsite"
local DEFAULT_APPS = "/Applications" -- dossier des applications MineOS (ajuster si besoin)

local function ask(label, default)
  io.write(label .. (default and (" [" .. default .. "]") or "") .. ": ")
  local a = term.read()
  if not a then return default end
  a = a:gsub("%s+$", "")
  if a == "" then return default end
  return a
end

if not component.isAvailable("internet") then
  print("ERREUR: carte Internet requise."); return
end
local internet = require("internet")

local function ensureDir(p)
  if p and p ~= "" and not fs.exists(p) then fs.makeDirectory(p) end
  return fs.exists(p)
end

local function download(url)
  local ok, handle = pcall(internet.request, url)
  if not ok then return nil, tostring(handle) end
  local buf = {}
  for chunk in handle do buf[#buf + 1] = chunk end
  return table.concat(buf)
end

local function writeFile(path, data)
  ensureDir(path:match("^(.*)/[^/]+$"))
  local f = io.open(path, "w"); if not f then return false end
  f:write(data); f:close(); return true
end

print("=== Déploiement SecSite pour MineOS ===")
local base = ask("URL de base (GitHub raw)", DEFAULT_BASE)
local root = ask("Dossier SecSite", DEFAULT_ROOT)
local appsDir = ask("Dossier Applications MineOS", DEFAULT_APPS)
ensureDir(root); ensureDir(appsDir)

-- Manifeste (rôle terminal).
local manText, mErr = download(base .. "/install/manifest.lua")
if not manText then print("Échec manifeste: " .. tostring(mErr)); return end
local chunk, lErr = load(manText, "=manifest", "t", _G)
if not chunk then print("Manifeste illisible: " .. tostring(lErr)); return end
local files = chunk().ROLES.terminal

print("Téléchargement de " .. #files .. " fichiers…")
local copiedApps = 0
for _, rel in ipairs(files) do
  local data, e = download(base .. "/" .. rel)
  if not data then
    print("  ! échec " .. rel .. " (" .. tostring(e) .. ")")
  else
    writeFile(root .. "/" .. rel, data)
    -- Si c'est une app MineOS (mineos/apps/X.app/…), copie aussi dans le dossier Applications.
    local appRel = rel:match("^mineos/apps/(.+)$")
    if appRel then
      writeFile(appsDir .. "/" .. appRel, data)
      if appRel:match("/Main%.lua$") then copiedApps = copiedApps + 1 end
    end
    print("  ok " .. rel)
  end
end

-- Secret réseau (même valeur que le serveur, >= 8 caractères).
local secret = ask("Secret réseau partagé (>=8 car., identique au serveur)", "")
if #secret >= 8 then
  writeFile(root .. "/server/data/secret", secret) -- lu par netsec via SECSITE_ROOT
  print("Secret enregistré.")
else
  print("Secret ignoré (trop court). Reportez le MÊME secret que le serveur avant usage.")
end

print("")
print("=== Terminé : " .. copiedApps .. " apps copiées dans " .. appsDir .. " ===")
print("Apps visibles au prochain lancement de MineOS.")
print("Login par carte : insérez ce bloc dans Libraries/System.lua > system.authorize :")
print([[
  local secStop
  secStop = require("mineos/login-fork/patch").cardListener(function(userName)
      if filesystem.exists(paths.system.users .. userName .. "/") then
          if secStop then secStop() end
          container:remove(); updateUser(userName); workspace:draw()
      end
  end)
]])
print("(le nom du profil MineOS doit = nom du compte SecSite)")
