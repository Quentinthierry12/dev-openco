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

-- Crée un dossier (et ses parents) s'il n'existe pas.
local function ensureDir(path)
  if path and path ~= "" and not fs.exists(path) then
    fs.makeDirectory(path)
  end
  return fs.exists(path)
end

local function writeFile(path, data)
  ensureDir(path:match("^(.*)/[^/]+$"))
  local f = io.open(path, "w")
  if not f then return false end
  f:write(data); f:close()
  return true
end

print("=== Installation SecSite (intranet de sécurité OpenComputers) ===")
local base = ask("URL de base (GitHub raw)", DEFAULT_BASE)
local root = ask("Dossier d'installation", DEFAULT_ROOT)

-- Crée la racine d'installation dès le départ.
if not ensureDir(root) then
  print("Impossible de créer le dossier " .. root .. " (espace disque ? droits ?)")
  return
end

-- 1) Manifeste
print("Téléchargement du manifeste…")
local manText, mErr = download(base .. "/install/manifest.lua")
if not manText then print("Échec manifeste: " .. tostring(mErr)); return end
-- Le manifeste est notre propre code de confiance -> environnement global (accès à ipairs/table).
local chunk, lErr = load(manText, "=manifest", "t", _G)
if not chunk then print("Manifeste illisible: " .. tostring(lErr)); return end
local manifest = chunk()
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

-- 2b) Dossiers runtime nécessaires (secret, données persistées, config agent).
ensureDir(root .. "/server/data") -- logs.tbl, accounts.tbl, secret, admin_pw, settings.tbl
ensureDir(root .. "/agent")

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

-- 6) Autostart : écrit la commande de lancement dans /home/.shrc (idempotent).
-- Syntaxe OpenOS : juste le chemin du programme (pas de "VAR=val cmd", pas de "&").
-- SECSITE_ROOT n'est nécessaire que si le dossier n'est pas le défaut /home/secsite
-- (le code retombe sur /home/secsite si la variable est absente).
local prog = {
  server = root .. "/server/main.lua",
  agent = root .. "/agent/main.lua",
  display = root .. "/display/wall.lua center",
  terminal = root .. "/agent/main.lua",
}
local function ensureAutostart(programLine)
  if not programLine then return end
  local block = programLine
  if root ~= "/home/secsite" then
    block = "set SECSITE_ROOT=" .. root .. "\n" .. programLine
  end
  local existing = ""
  local rf = io.open("/home/.shrc", "r")
  if rf then existing = rf:read("*a") or ""; rf:close() end
  if existing:find(programLine, 1, true) then
    print("Autostart déjà présent.")
    return
  end
  local wf = io.open("/home/.shrc", "a")
  if wf then
    wf:write("\n# SecSite autostart\n" .. block .. "\n"); wf:close()
    print("Autostart ajouté à /home/.shrc :")
    print("  " .. programLine)
  else
    print("Impossible d'écrire /home/.shrc ; ajoutez manuellement : " .. programLine)
  end
end

print("")
print("=== Installation terminée (rôle: " .. role .. ") ===")
if ask("Configurer le démarrage automatique ? (o/n)", "o") == "o" then
  ensureAutostart(prog[role])
end
if role == "terminal" then
  print("Copiez les *.app dans les Applications MineOS, puis lancez:")
  print("  " .. root .. "/mineos/login-fork/install.lua")
end
print("Réseau: reportez le MÊME secret sur chaque machine de l'intranet.")
