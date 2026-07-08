-- server/services/auth.lua
-- Sessions et contrôle d'accès. Deux voies d'authentification :
--   * carte OpenSecurity (cardId lu par le lecteur, résolu vers un compte)
--   * identifiant + mot de passe (login MineOS classique)
-- Le rôle est attaché à la session ; les permissions sont vérifiées ICI (côté serveur).

local util = require("shared.util")
local roles = require("shared.roles")

local auth = {}
auth.__index = auth

function auth.new(accounts, logs, opts)
  opts = opts or {}
  return setmetatable({
    accounts = accounts,
    logs = logs,
    sessions = {},          -- token -> session
    ttl = opts.ttl or 3600, -- durée de vie d'une session (s)
  }, auth)
end

local function sessionView(s)
  return { token = s.token, name = s.name, role = s.role, node = s.node }
end

function auth:_open(acc, node, method)
  local s = {
    token = util.token(),
    accountId = acc.id,
    name = acc.name,
    role = acc.role,
    node = node,
    createdAt = util.now(),
  }
  self.sessions[s.token] = s
  if self.logs then
    self.logs:add("auth", acc.name, "login (" .. method .. ")", { node = node })
  end
  return sessionView(s)
end

-- loginCard(cardId, node) -> (session, nil) ou (nil, raison)
function auth:loginCard(cardId, node)
  if type(cardId) ~= "string" or cardId == "" then return nil, "bad_card" end
  local acc = self.accounts:byCardId(cardId)
  if not acc then
    if self.logs then self.logs:add("auth", "?", "carte inconnue refusée", { node = node }) end
    return nil, "unknown_card"
  end
  return self:_open(acc, node, "carte")
end

-- loginPassword(name, password, node) -> (session, nil) ou (nil, raison)
function auth:loginPassword(name, password, node)
  local acc = self.accounts:verifyPassword(name, password)
  if not acc then
    if self.logs then self.logs:add("auth", name or "?", "mot de passe refusé", { node = node }) end
    return nil, "bad_credentials"
  end
  return self:_open(acc, node, "mot de passe")
end

function auth:check(token)
  local s = self.sessions[token]
  if not s then return nil end
  if self.ttl and (util.now() - s.createdAt) > self.ttl then
    self.sessions[token] = nil
    return nil
  end
  return s
end

-- Renvoie la session si le token est valide ET a la permission ; sinon nil, raison.
function auth:authorize(token, permission)
  local s = self:check(token)
  if not s then return nil, "unauthorized" end
  if permission and not roles.can(s.role, permission) then
    return nil, "forbidden"
  end
  return s
end

function auth:logout(token)
  local s = self.sessions[token]
  self.sessions[token] = nil
  if s and self.logs then
    self.logs:add("auth", s.name, "logout", { node = s.node })
  end
  return true
end

function auth:list()
  local out = {}
  for _, s in pairs(self.sessions) do
    out[#out + 1] = sessionView(s)
  end
  return out
end

return auth
