-- shared/protocol.lua
-- Contrat de communication terminal/agent/tablette <-> serveur.
-- Les messages sont des tables sérialisées (util.serialize) puis emballées (netsec.wrap).

local protocol = {}

protocol.VERSION = 1
protocol.PORT = 2412 -- port modem dédié à l'intranet de sécurité

-- Types de requêtes (client -> serveur).
protocol.REQ = {
  PING            = "ping",
  AUTH_CARD       = "auth.card",       -- { cardId }         -> résout un compte via badge
  AUTH_PASSWORD   = "auth.password",   -- { name, password } -> login classique
  SESSION_CHECK   = "session.check",   -- { token }
  LOGOUT          = "auth.logout",     -- { token }
  ACCOUNT_LIST    = "account.list",    -- { token }
  ACCOUNT_CREATE  = "account.create",  -- { token, name, role, cardId?, password? }
  ACCOUNT_DELETE  = "account.delete",  -- { token, id }
  LOG_QUERY       = "log.query",       -- { token, limit? }
  -- Réservés aux lots suivants (radar, portes, flotte) :
  DOOR_CMD        = "door.cmd",
  RADAR_STATE     = "radar.state",
  NODE_REGISTER   = "node.register",
  NODE_CMD        = "node.cmd",
  NODE_LIST       = "node.list",
}

-- Types d'événements diffusés (serveur -> clients).
protocol.EVT = {
  ALERT     = "evt.alert",     -- montée DEFCON / missile
  LOCKDOWN  = "evt.lockdown",
  ANNOUNCE  = "evt.announce",
}

-- Construit une requête.
function protocol.request(rtype, payload)
  local req = payload or {}
  req.v = protocol.VERSION
  req.t = rtype
  return req
end

-- Réponses normalisées.
function protocol.ok(data)
  return { ok = true, data = data }
end

function protocol.err(reason)
  return { ok = false, error = reason }
end

return protocol
