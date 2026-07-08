-- tools/mock/component.lua
-- Stub minimal de l'API `component` d'OpenComputers, pour charger/tester hors-jeu
-- des modules qui font require("component"). N'émule que ce dont on a besoin.
-- (Les tests de logique n'en dépendent pas ; ce stub sert aux essais manuels.)

local mock = { _list = {} }

function mock.isAvailable(kind)
  return mock._list[kind] ~= nil
end

function mock.list(filter)
  local out = {}
  for kind, proxy in pairs(mock._list) do
    if not filter or kind == filter then out[proxy.address or kind] = kind end
  end
  return function()
    local k, v = next(out)
    if k then out[k] = nil return k, v end
  end
end

-- Enregistre un faux composant : mock.register("os_magreader", { swipe = fn })
function mock.register(kind, proxy)
  proxy = proxy or {}
  proxy.address = proxy.address or (kind .. "-0000")
  mock._list[kind] = proxy
  mock[kind] = proxy
  return proxy
end

setmetatable(mock, {
  __index = function(_, k)
    return rawget(mock._list, k)
  end,
})

return mock
