---@diagnostic disable: unknown-cast-variable, lowercase-global, undefined-global
---@module "enet"
---@module "etc.host_thread_context"

---Override disconned handler to reconnect to server automatically
---@param disconnectEvent ENetEvent
function disconnect(disconnectEvent)
    if disconnectEvent.peer:index() ~= dropServerPeerIndex then
        event:push{"disconnect", disconnectEvent.peer:index(), tostring(disconnectEvent.peer), disconnectEvent.data}
        host:connect(tostring(disconnectEvent.peer))
    else
        event:push{"response", dropServerReturnId, true}
    end
end