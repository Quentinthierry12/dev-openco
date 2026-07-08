-- server/services/protocols.lua
-- Exécute les protocoles (shared/protocols.lua) : drill (simulation non destructive) ou réel.
-- Dépendances injectées (testable) : doors, nodes, messaging, alarm(fn), logs, broadcast(fn).

local cfg = require("shared.protocols")

local protocols = {}
protocols.__index = protocols

function protocols.new(deps)
  return setmetatable({ d = deps or {} }, protocols)
end

function protocols:list()
  local out = {}
  for _, p in ipairs(cfg.LIST) do
    out[#out + 1] = { id = p.id, name = p.name, code = p.code, role = p.role, drillable = p.drillable }
  end
  return out
end

-- Applique une step RÉELLE via les services.
function protocols:_apply(step, actor)
  local d = self.d
  local t = step.type
  if t == "lockdown" and d.doors then d.doors:lockdown(actor)
  elseif t == "release" and d.doors then d.doors:release(actor)
  elseif t == "alarm" and d.alarm then pcall(d.alarm, step.on, "protocole")
  elseif t == "announce" and d.messaging then d.messaging:announce(actor, step.text)
  elseif t == "disable_nodes" and d.nodes then d.nodes:commandAll("blackout", step.exclude, actor)
  elseif t == "restore_nodes" and d.nodes then d.nodes:commandAll("release", step.exclude, actor)
  elseif t == "wait" and d.sleep then pcall(d.sleep, step.s or 1) end
end

-- run(codeOrId, { drill=bool }, actor) -> résultat ou (nil, raison)
function protocols:run(codeOrId, opts, actor)
  opts = opts or {}
  local p = cfg.get(codeOrId)
  if not p then return nil, "unknown_protocol" end
  local drill = opts.drill and p.drillable and true or false
  if opts.drill and not p.drillable then return nil, "not_drillable" end

  local executed = {}
  for _, step in ipairs(p.steps) do
    executed[#executed + 1] = step.type
    if drill then
      -- Simulation : on annonce chaque étape, aucune action destructrice.
      if self.d.messaging then self.d.messaging:announce("DRILL", "[" .. p.name .. "] " .. step.type) end
    else
      self:_apply(step, actor)
    end
  end

  if self.d.logs then self.d.logs:add("protocol", actor, (drill and "DRILL: " or "") .. p.name) end
  if self.d.broadcast then
    pcall(self.d.broadcast, { evt = drill and "drill" or "protocol", name = p.name })
  end
  return { id = p.id, name = p.name, drill = drill, steps = executed }
end

return protocols
