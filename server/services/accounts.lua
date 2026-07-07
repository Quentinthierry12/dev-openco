-- server/services/accounts.lua
-- Comptes utilisateurs : rôle, badge (carte) et/ou mot de passe.
-- Les secrets ne sont jamais stockés en clair : carte et mot de passe sont hachés (SHA-256 salé).
-- Persistance optionnelle via `path` (sans, tout reste en mémoire -> testable).

local util = require("shared.util")
local sha2 = require("shared.sha2")
local roles = require("shared.roles")

local accounts = {}
accounts.__index = accounts

function accounts.new(opts)
  opts = opts or {}
  local self = setmetatable({
    byId = {},
    byName = {},
    byCard = {},   -- hash(cardId) -> id
    path = opts.path,
  }, accounts)
  return self
end

local function hashCard(cardId)
  return sha2.sha256("card:" .. cardId)
end

local function hashPassword(salt, password)
  return sha2.sha256("pw:" .. salt .. ":" .. password)
end

-- Vue publique : jamais de hash ni de sel.
local function view(acc)
  return {
    id = acc.id,
    name = acc.name,
    role = acc.role,
    hasCard = acc.cardHash ~= nil,
    hasPassword = acc.passwordHash ~= nil,
    createdAt = acc.createdAt,
  }
end
accounts.view = view

-- create{ name, role, cardId?, password? } -> (view, nil) ou (nil, raison)
function accounts:create(spec)
  if type(spec) ~= "table" or type(spec.name) ~= "string" or spec.name == "" then
    return nil, "name_required"
  end
  if not roles.isRole(spec.role) then
    return nil, "bad_role"
  end
  if self.byName[spec.name] then
    return nil, "name_taken"
  end
  if not spec.cardId and not spec.password then
    return nil, "need_card_or_password"
  end

  local acc = {
    id = util.uuid(12),
    name = spec.name,
    role = spec.role,
    createdAt = util.now(),
  }
  if spec.cardId then
    local h = hashCard(spec.cardId)
    if self.byCard[h] then return nil, "card_taken" end
    acc.cardHash = h
  end
  if spec.password then
    acc.salt = util.uuid(16)
    acc.passwordHash = hashPassword(acc.salt, spec.password)
  end

  self.byId[acc.id] = acc
  self.byName[acc.name] = acc
  if acc.cardHash then self.byCard[acc.cardHash] = acc.id end
  self:save()
  return view(acc)
end

function accounts:delete(id)
  local acc = self.byId[id]
  if not acc then return nil, "not_found" end
  self.byId[id] = nil
  self.byName[acc.name] = nil
  if acc.cardHash then self.byCard[acc.cardHash] = nil end
  self:save()
  return true
end

function accounts:get(id)
  return self.byId[id]
end

function accounts:byCardId(cardId)
  local id = self.byCard[hashCard(cardId)]
  return id and self.byId[id] or nil
end

function accounts:byUserName(name)
  return self.byName[name]
end

-- Vérifie un couple identifiant/mot de passe. Renvoie le compte ou nil.
function accounts:verifyPassword(name, password)
  local acc = self.byName[name]
  if not acc or not acc.passwordHash then return nil end
  if hashPassword(acc.salt, password or "") == acc.passwordHash then
    return acc
  end
  return nil
end

-- Émission/révocation de badge (utilisé par Badges.app + os_cardwriter).
function accounts:setCard(id, cardId)
  local acc = self.byId[id]
  if not acc then return nil, "not_found" end
  if acc.cardHash then self.byCard[acc.cardHash] = nil end
  if cardId then
    local h = hashCard(cardId)
    if self.byCard[h] and self.byCard[h] ~= id then return nil, "card_taken" end
    acc.cardHash = h
    self.byCard[h] = id
  else
    acc.cardHash = nil
  end
  self:save()
  return view(acc)
end

function accounts:setRole(id, role)
  local acc = self.byId[id]
  if not acc then return nil, "not_found" end
  if not roles.isRole(role) then return nil, "bad_role" end
  acc.role = role
  self:save()
  return view(acc)
end

function accounts:list()
  local out = {}
  for _, acc in pairs(self.byId) do
    out[#out + 1] = view(acc)
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function accounts:count()
  local n = 0
  for _ in pairs(self.byId) do n = n + 1 end
  return n
end

-- Persistance -----------------------------------------------------------------
function accounts:save()
  if not self.path then return end
  local f = io.open(self.path, "w")
  if not f then return end
  f:write(util.serialize({ byId = self.byId }))
  f:close()
end

function accounts:load()
  if not self.path then return end
  local f = io.open(self.path, "r")
  if not f then return end
  local data = util.deserialize(f:read("*a"))
  f:close()
  if type(data) ~= "table" or type(data.byId) ~= "table" then return end
  self.byId, self.byName, self.byCard = {}, {}, {}
  for id, acc in pairs(data.byId) do
    self.byId[id] = acc
    self.byName[acc.name] = acc
    if acc.cardHash then self.byCard[acc.cardHash] = id end
  end
end

return accounts
