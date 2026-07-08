-- remote/tablet.lua
-- Console de gestion à distance pour TABLETTE OpenComputers (OpenOS, sans MineOS : léger).
-- L'admin s'authentifie (carte si lecteur, sinon mot de passe), liste la flotte et envoie
-- reboot/shutdown/lock. Interface texte volontairement minimale.

local ROOT = (os.getenv and os.getenv("SECSITE_ROOT")) or "/home/secsite"
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path

local term = require("term")
local net = require("mineos.lib.net")
local card = require("mineos.lib.card")
local protocol = require("shared.protocol")

local function prompt(label)
  io.write(label)
  return term.read()
end

-- Authentification : carte si disponible, sinon identifiant/mot de passe.
local function login()
  if card.available() then
    print("Présentez votre badge (ou Entrée pour mot de passe)…")
    local id = card.await(5)
    if id then
      local r = net.loginCard(id)
      if r and r.ok then return r.data end
    end
  end
  local name = (prompt("Identifiant: ") or ""):gsub("%s+$", "")
  local pw = (prompt("Mot de passe: ") or ""):gsub("%s+$", "")
  local r = net.loginPassword(name, pw)
  if r and r.ok then return r.data end
  return nil
end

local session = login()
if not session then print("Échec d'authentification."); return end
print("Connecté: " .. session.name .. " (" .. session.role .. ")")

local function rpc(rtype, payload)
  payload = payload or {}; payload.token = session.token
  return net.request(protocol.request(rtype, payload))
end

while true do
  print("\n=== FLOTTE ===")
  local list = rpc(protocol.REQ.NODE_LIST)
  if not (list and list.ok) then print("Non autorisé (rôle Admin requis) ou serveur injoignable."); return end
  for i, n in ipairs(list.data.nodes) do
    print(string.format("  [%d] %s  %-10s %s", i, n.address:sub(1, 8), n.kind, n.status))
  end
  local sel = prompt("\nN° nœud (ou q pour quitter): ")
  if sel == "q\n" or sel == "q" then return end
  local idx = tonumber(sel)
  local node = idx and list.data.nodes[idx]
  if node then
    local cmd = (prompt("Commande (reboot/shutdown/lock/status): ") or ""):gsub("%s+", "")
    local r = rpc(protocol.REQ.NODE_CMD, { address = node.address, command = cmd })
    print((r and r.ok) and "-> envoyé" or ("-> échec: " .. tostring(r and r.error)))
  end
end
