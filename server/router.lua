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

handlers[protocol.REQ.ACCOUNT_SETROLE] = function(ctx, req)
  local s, errResp = need(ctx, req.token, "manage_accounts")
  if errResp then return errResp end
  local acc, reason = ctx.accounts:setRole(req.id, req.role)
  if not acc then return protocol.err(reason) end
  ctx.logs:add("account", s.name, "rôle de " .. acc.name .. " -> " .. acc.role)
  return protocol.ok({ account = acc })
end

handlers[protocol.REQ.ACCOUNT_SETCARD] = function(ctx, req)
  local s, errResp = need(ctx, req.token, "manage_accounts")
  if errResp then return errResp end
  local acc, reason = ctx.accounts:setCard(req.id, req.cardId)
  if not acc then return protocol.err(reason) end
  ctx.logs:add("badge", s.name, (req.cardId and "badge émis pour " or "badge révoqué pour ") .. acc.name)
  return protocol.ok({ account = acc })
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

handlers[protocol.REQ.NODE_REGISTER] = function(ctx, req, meta)
  if not ctx.nodes then return protocol.err("no_fleet") end
  -- Pas de token requis (l'agent boote avant toute session) mais message signé (réseau privé).
  local address = (meta and meta.from) or req.address
  local res, reason = ctx.nodes:register(address, req.kind)
  if not res then return protocol.err(reason) end
  return protocol.ok(res)
end

handlers[protocol.REQ.NODE_LIST] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "fleet_control")
  if errResp then return errResp end
  if not ctx.nodes then return protocol.ok({ nodes = {} }) end
  return protocol.ok({ nodes = ctx.nodes:list() })
end

handlers[protocol.REQ.NODE_CMD] = function(ctx, req)
  local s, errResp = need(ctx, req.token, "fleet_control")
  if errResp then return errResp end
  if not ctx.nodes then return protocol.err("no_fleet") end
  local res, reason = ctx.nodes:command(req.address, req.command, s.name)
  if not res then return protocol.err(reason) end
  return protocol.ok(res)
end

handlers[protocol.REQ.SESSION_LIST] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "manage_accounts")
  if errResp then return errResp end
  return protocol.ok({ sessions = ctx.auth:list() })
end

handlers[protocol.REQ.ANNOUNCE_POST] = function(ctx, req)
  local s, errResp = need(ctx, req.token, "announce")
  if errResp then return errResp end
  if not ctx.messaging then return protocol.err("no_messaging") end
  local a, reason = ctx.messaging:announce(s.name, req.text)
  if not a then return protocol.err(reason) end
  return protocol.ok({ announce = a })
end

handlers[protocol.REQ.BOARD_GET] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "view_dashboard")
  if errResp then return errResp end
  if not ctx.messaging then return protocol.ok({ board = {} }) end
  return protocol.ok({ board = ctx.messaging:getBoard(req.limit) })
end

handlers[protocol.REQ.MSG_SEND] = function(ctx, req)
  local s, errResp = need(ctx, req.token, "view_dashboard")
  if errResp then return errResp end
  if not ctx.messaging then return protocol.err("no_messaging") end
  local m, reason = ctx.messaging:send(s.name, req.to, req.text)
  if not m then return protocol.err(reason) end
  return protocol.ok({ message = m })
end

handlers[protocol.REQ.MSG_INBOX] = function(ctx, req)
  local s, errResp = need(ctx, req.token, "view_dashboard")
  if errResp then return errResp end
  if not ctx.messaging then return protocol.ok({ messages = {} }) end
  return protocol.ok({ messages = ctx.messaging:getInbox(s.name) })
end

handlers[protocol.REQ.SITUATION_GET] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "view_dashboard")
  if errResp then return errResp end
  if not ctx.situation then return protocol.ok({ defcon = 5, alert = false }) end
  return protocol.ok(ctx.situation:compute())
end

handlers[protocol.REQ.PROTOCOL_LIST] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "view_dashboard")
  if errResp then return errResp end
  if not ctx.protocols then return protocol.ok({ protocols = {} }) end
  return protocol.ok({ protocols = ctx.protocols:list() })
end

handlers[protocol.REQ.PROTOCOL_RUN] = function(ctx, req)
  -- Réel -> permission "protocol" (admin) ; drill -> permission "drill" (agent+admin).
  local perm = req.drill and "drill" or "protocol"
  local s, errResp = need(ctx, req.token, perm)
  if errResp then return errResp end
  if not ctx.protocols then return protocol.err("no_protocols") end
  local res, reason = ctx.protocols:run(req.code, { drill = req.drill }, s.name)
  if not res then return protocol.err(reason) end
  return protocol.ok(res)
end

handlers[protocol.REQ.POWER_STATE] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "view_dashboard")
  if errResp then return errResp end
  if not ctx.power then return protocol.ok({ reactors = {} }) end
  return protocol.ok({ reactors = ctx.power:state() })
end

handlers[protocol.REQ.REACTOR_SCRAM] = function(ctx, req)
  local s, errResp = need(ctx, req.token, "reactor_control")
  if errResp then return errResp end
  if not ctx.scram then return protocol.err("no_reactor") end
  local ok = ctx.scram(req.id)
  ctx.logs:add("reactor", s.name, "SCRAM " .. tostring(req.id))
  return protocol.ok({ scram = ok and true or false })
end

handlers[protocol.REQ.DEFENSE_STATE] = function(ctx, req)
  local _, errResp = need(ctx, req.token, "view_dashboard")
  if errResp then return errResp end
  if not ctx.defense then return protocol.ok({ mode = "off" }) end
  return protocol.ok(ctx.defense:status())
end

handlers[protocol.REQ.DEFENSE_MODE] = function(ctx, req)
  local s, errResp = need(ctx, req.token, "defense_control")
  if errResp then return errResp end
  if not ctx.defense then return protocol.err("no_defense") end
  local res, reason = ctx.defense:setMode(req.mode, s.name)
  if not res then return protocol.err(reason) end
  return protocol.ok(res)
end

handlers[protocol.REQ.DEFENSE_FIRE] = function(ctx, req)
  local s, errResp = need(ctx, req.token, "defense_control")
  if errResp then return errResp end
  if not ctx.defense then return protocol.err("no_defense") end
  local res, reason = ctx.defense:fire(s.name)
  if not res then return protocol.err(reason) end
  return protocol.ok(res)
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
