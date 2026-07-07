-- server/router.lua
-- Routeur PUR (aucun accès modem/composant) : transforme une requête en réponse.
-- Isolé volontairement pour être testable hors-jeu (voir tools/test/run.lua).
-- ctx = { accounts = <accounts>, auth = <auth>, logs = <logs> }
-- meta = { from = <adresse composant expéditeur> }

local protocol = require("shared.protocol")
local doorsCfg = require("shared.doors")

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

handlers[protocol.REQ.DOOR_LIST] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "view_dashboard")
  if errResp then return errResp end
  if not ctx.doors then return protocol.ok({ doors = {} }) end
  return protocol.ok({ doors = ctx.doors:all(), locked = ctx.doors:isLocked() })
end

handlers[protocol.REQ.DOOR_CMD] = function(ctx, req)
  if not ctx.doors then return protocol.err("no_doors") end
  local action = req.action
  if not protocol.DOOR_ACTIONS[action] then return protocol.err("bad_action") end

  -- Lockdown/release : permission globale "lockdown", pas liée à une porte précise.
  if action == "lockdown" or action == "release" then
    local s, errResp = need(ctx, req.token, "lockdown")
    if errResp then return errResp end
    local res = (action == "lockdown") and ctx.doors:lockdown(s.name) or ctx.doors:release(s.name)
    return protocol.ok(res)
  end

  local door = doorsCfg.get(req.id)
  if not door then return protocol.err("unknown_door") end
  local s, errResp = need(ctx, req.token, doorsCfg.permission(door))
  if errResp then return errResp end

  local res, reason
  if action == "open" then res, reason = ctx.doors:set(req.id, true, s.name)
  elseif action == "close" then res, reason = ctx.doors:set(req.id, false, s.name)
  elseif action == "inner_open" then res, reason = ctx.doors:airlock(req.id, "inner", true, s.name)
  elseif action == "inner_close" then res, reason = ctx.doors:airlock(req.id, "inner", false, s.name)
  elseif action == "outer_open" then res, reason = ctx.doors:airlock(req.id, "outer", true, s.name)
  elseif action == "outer_close" then res, reason = ctx.doors:airlock(req.id, "outer", false, s.name)
  end
  if not res then return protocol.err(reason or "failed") end
  return protocol.ok(res)
end

handlers[protocol.REQ.RADAR_STATE] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "view_dashboard")
  if errResp then return errResp end
  if not ctx.radar then return protocol.ok({ defcon = 5, contacts = {}, alert = false }) end
  return protocol.ok(ctx.radar:state())
end

handlers[protocol.REQ.SESSION_LIST] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "manage_accounts")
  if errResp then return errResp end
  return protocol.ok({ sessions = ctx.auth:list() })
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
