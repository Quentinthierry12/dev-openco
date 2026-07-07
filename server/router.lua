-- server/router.lua
-- Routeur PUR (aucun accès modem/composant) : transforme une requête en réponse.
-- Isolé volontairement pour être testable hors-jeu (voir tools/test/run.lua).
-- ctx = { accounts = <accounts>, auth = <auth>, logs = <logs> }
-- meta = { from = <adresse composant expéditeur> }

local protocol = require("shared.protocol")

local router = {}

-- Helper : exige une session valide + permission. Renvoie session ou (nil, réponse d'erreur).
local function need(ctx, token, permission)
  local s, reason = ctx.auth:authorize(token, permission)
  if not s then return nil, protocol.err(reason) end
  return s
end

local handlers = {}

handlers[protocol.REQ.PING] = function()
  return protocol.ok({ pong = true, v = protocol.VERSION })
end

handlers[protocol.REQ.AUTH_CARD] = function(ctx, req, meta)
  local s, reason = ctx.auth:loginCard(req.cardId, meta and meta.from)
  if not s then return protocol.err(reason) end
  return protocol.ok(s)
end

handlers[protocol.REQ.AUTH_PASSWORD] = function(ctx, req, meta)
  local s, reason = ctx.auth:loginPassword(req.name, req.password, meta and meta.from)
  if not s then return protocol.err(reason) end
  return protocol.ok(s)
end

handlers[protocol.REQ.SESSION_CHECK] = function(ctx, req)
  local s = ctx.auth:check(req.token)
  if not s then return protocol.err("unauthorized") end
  return protocol.ok({ name = s.name, role = s.role })
end

handlers[protocol.REQ.LOGOUT] = function(ctx, req)
  ctx.auth:logout(req.token)
  return protocol.ok({ done = true })
end

handlers[protocol.REQ.ACCOUNT_LIST] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "manage_accounts")
  if errResp then return errResp end
  return protocol.ok({ accounts = ctx.accounts:list() })
end

handlers[protocol.REQ.ACCOUNT_CREATE] = function(ctx, req)
  local s, errResp = need(ctx, req.token, "manage_accounts")
  if errResp then return errResp end
  local acc, reason = ctx.accounts:create({
    name = req.name, role = req.role, cardId = req.cardId, password = req.password,
  })
  if not acc then return protocol.err(reason) end
  ctx.logs:add("account", s.name, "création compte " .. acc.name, { role = acc.role })
  return protocol.ok({ account = acc })
end

handlers[protocol.REQ.ACCOUNT_DELETE] = function(ctx, req)
  local s, errResp = need(ctx, req.token, "manage_accounts")
  if errResp then return errResp end
  local ok, reason = ctx.accounts:delete(req.id)
  if not ok then return protocol.err(reason) end
  ctx.logs:add("account", s.name, "suppression compte " .. tostring(req.id))
  return protocol.ok({ done = true })
end

handlers[protocol.REQ.LOG_QUERY] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "view_logs")
  if errResp then return errResp end
  return protocol.ok({ entries = ctx.logs:query(req.limit) })
end

-- Point d'entrée.
function router.handle(ctx, req, meta)
  local resp
  if type(req) ~= "table" or type(req.t) ~= "string" then
    resp = protocol.err("bad_request")
  else
    local h = handlers[req.t]
    if not h then
      resp = protocol.err("unknown_type")
    else
      local ok, result = pcall(h, ctx, req, meta)
      resp = ok and result or protocol.err("server_error")
    end
  end
  if type(req) == "table" and req.id then resp.id = req.id end
  return resp
end

return router
