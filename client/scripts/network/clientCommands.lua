---@module "enet"
---@module "etc.host_thread_context"

---@diagnostic disable-next-line: unused-local
local dropServerPeerIndex, dropServerReturnId

function commands.disconnectServer(rid, args)
    local cid, data = args[1], args[2]

    ---@diagnostic disable-next-line: unused-local
    dropServerPeerIndex = args[1]

    host:get_peer(cid):disconnect(data)
    ---@diagnostic disable-next-line: unused-local
    dropServerReturnId = rid
end