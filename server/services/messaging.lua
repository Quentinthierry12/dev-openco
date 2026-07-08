-- server/services/messaging.lua
-- Collaboration : tableau d'annonces (bulletin) + messagerie interne entre comptes.
-- Logique PURE ; la diffusion réseau/chatbox est un callback `onAnnounce` injecté.

local util = require("shared/util")

local messaging = {}
messaging.__index = messaging

function messaging.new(opts)
  opts = opts or {}
  return setmetatable({
    logs = opts.logs,
    onAnnounce = opts.onAnnounce, -- fn(annonce) : broadcast + chatbox
    board = {},
    inbox = {},                   -- name -> { messages }
    maxBoard = opts.maxBoard or 50,
  }, messaging)
end

function messaging:announce(actor, text)
  if type(text) ~= "string" or text == "" then return nil, "empty" end
  local a = { ts = util.now(), stamp = util.stamp(), actor = actor, text = text }
  self.board[#self.board + 1] = a
  while #self.board > self.maxBoard do table.remove(self.board, 1) end
  if self.logs then self.logs:add("announce", actor, text) end
  if self.onAnnounce then pcall(self.onAnnounce, a) end
  return util.shallow(a)
end

function messaging:getBoard(limit)
  limit = limit or 20
  local out, n = {}, #self.board
  for i = math.max(1, n - limit + 1), n do out[#out + 1] = util.shallow(self.board[i]) end
  return out
end

function messaging:send(from, to, text)
  if type(to) ~= "string" or to == "" or type(text) ~= "string" or text == "" then
    return nil, "bad_message"
  end
  self.inbox[to] = self.inbox[to] or {}
  local m = { ts = util.now(), stamp = util.stamp(), from = from, text = text }
  self.inbox[to][#self.inbox[to] + 1] = m
  return util.shallow(m)
end

function messaging:getInbox(name)
  local out = {}
  for _, m in ipairs(self.inbox[name] or {}) do out[#out + 1] = util.shallow(m) end
  return out
end

return messaging
