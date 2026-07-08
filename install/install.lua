-- install/install.lua
-- Assistant d'installation « une commande » pour l'intranet de sécurité.
-- Télécharge les fichiers du rôle choisi depuis GitHub raw, configure le secret réseau,
-- le mot de passe admin (serveur) et l'autostart.
--
-- Amorçage :
--   wget -f https://raw.githubusercontent.com/Quentinthierry12/dev-openco/<branche>/install/install.lua /tmp/i.lua && /tmp/i.lua

local component = require("component")
local fs = require("filesystem")
local term = require("term")

local DEFAULT_BASE = "https://raw.githubusercontent.com/Quentinthierry12/dev-openco/claude/opencomputer-security-site-jw7rga"
local DEFAULT_ROOT = "/home/secsite"

local function ask(label, default)
  io.write(label .. (default and (" [" .. default .. "]") or "") .. ": ")
  local a = term.read()
  if not a then return default end
  a = a:gsub("%s+$", "")
  if a == "" then return default end
  return a
end

if not component.isAvailable("internet") then
  print("ERREUR: une carte Internet est requise pour l'installation.")
  return
end
local internet = require("internet")

local function download(url)
  local ok, handle = pcall(internet.request, url)
  if not ok then return nil, tostring(handle) end
  local buf = {}
  for chunk in handle do buf[#buf + 1] = chunk end
  return table.concat(buf)
end

local function writeFile(path, data)
  local dir = path:match("^(.*)/[^/]+$")
  if dir and not fs.exists(dir) then fs.makeDirectory(dir) end
  local f = io.open(path, "w")
  if not f then return false end
  f:write(data); f:close()
  return true
end

print("=== Installation SecSite (intranet de sécurité OpenComputers) ===")
local base = ask("URL de base (GitHub raw)", DEFAULT_BASE)
local root = ask("Dossier d'installation", DEFAULT_ROOT)

-- 1) Manifeste
print("Téléchargement du manifeste…")
local manText, mErr = download(base .. "/install/manifest.lua")
if not manText then print("Échec manifeste: " .. tostring(mErr)); return end
local manifest = load(manText, "=manifest", "t", {})()
print("Rôles disponibles: " .. table.concat(manifest.ROLE_LIST, ", "))
local role = ask("Rôle de cette machine", "terminal")
local files = manifest.ROLES[role]
if not files then print("Rôle inconnu: " .. role); return end

-- 2) Téléchargement des fichiers
print("Téléchargement de " .. #files .. " fichiers…")
for _, rel in ipairs(files) do
  local data, e = download(base .. "/" .. rel)
  if not data then print("  ! échec " .. rel .. " (" .. tostring(e) .. ")")
  else writeFile(root .. "/" .. rel, data); print("  ok " .. rel) end
end

-- 3) Secret réseau (identique sur toutes les machines admises)
local secret = ask("Secret réseau partagé (vide = générer)", "")
if secret == "" then
  secret = ""
  for _ = 1, 40 do secret = secret .. string.format("%x", math.random(0, 15)) end
  print("Secret généré: " .. secret .. "  (à reporter sur les autres machines)")
end
if role == "agent" then writeFile(root .. "/agent/secret", secret)
else writeFile(root .. "/server/data/secret", secret) end

-- 4) Mot de passe admin (serveur uniquement) — règle le mdp par défaut
if role == "server" then
  local pw = ask("Mot de passe admin initial", "admin")
  writeFile(root .. "/server/data/admin_pw", pw)
end

-- 5) Config locale + type de nœud
local kind = role
if role == "display" then kind = "display" end
writeFile(root .. "/secsite.cfg",
  ("{role=%q,kind=%q,root=%q}"):format(role, kind, root))

-- 6) Autostart (best effort) : ligne à ajouter au démarrage
local launch = {
  server = "SECSITE_ROOT=" .. root .. " " .. root .. "/server/main.lua",
  agent = "SECSITE_ROOT=" .. root .. " " .. root .. "/agent/main.lua",
  display = "SECSITE_ROOT=" .. root .. " " .. root .. "/display/wall.lua center",
}
print("")
print("=== Installation terminée (rôle: " .. role .. ") ===")
if launch[role] then
  print("Pour démarrer automatiquement, ajoutez à /home/.shrc :")
  print("  " .. launch[role])
end
if role == "terminal" then
  print("Copiez les *.app dans les Applications MineOS, puis lancez:")
  print("  " .. root .. "/mineos/login-fork/install.lua")
end
print("Réseau: reportez le MÊME secret sur chaque machine de l'intranet.")
