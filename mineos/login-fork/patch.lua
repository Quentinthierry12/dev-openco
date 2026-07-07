-- mineos/login-fork/patch.lua
-- Voie d'authentification « carte » ajoutée à l'écran de connexion MineOS.
-- Conçu pour être appelé DEPUIS le login MineOS forké (voir install.lua) : il écoute un swipe,
-- résout la carte auprès du serveur, et si un compte correspond, autorise l'ouverture de session.
--
-- La voie « login + mot de passe » native de MineOS reste inchangée : ce module ajoute la carte
-- À CÔTÉ, il ne remplace rien.

local ROOT = (os.getenv and os.getenv("SECSITE_ROOT")) or "/home/secsite"
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path

local net = require("mineos.lib.net")
local card = require("mineos.lib.card")

local patch = {}

-- Tente une connexion par carte (bloquant jusqu'au swipe ou timeout).
-- Renvoie une session serveur { token, name, role } ou (nil, raison).
function patch.tryCardLogin(timeout)
  if not card.available() then return nil, "no_reader" end
  local cardId = card.await(timeout)
  if not cardId then return nil, "timeout" end
  local resp, err = net.loginCard(cardId)
  if not resp then return nil, err or "no_server" end
  if not resp.ok then return nil, resp.error end
  return resp.data
end

-- Boucle d'écoute non bloquante à brancher dans le workspace du login MineOS.
-- `onSuccess(session)` est appelé quand une carte valide est présentée.
-- Le login MineOS choisit ensuite le profil (même nom) et ouvre la session.
function patch.attach(onSuccess, onReject)
  return function()
    local session, reason = patch.tryCardLogin(0.5)
    if session then
      if onSuccess then onSuccess(session) end
    elseif reason and reason ~= "timeout" and reason ~= "no_reader" then
      if onReject then onReject(reason) end
    end
  end
end

return patch
