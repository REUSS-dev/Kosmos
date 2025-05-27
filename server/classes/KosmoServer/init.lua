-- server
local server = {}

local socket = require("classes.KosmoSocket")

-- documentation



-- config



-- consts



-- vars



-- init



-- fnc



-- classes

---@class KosmoServer : KosmoSocket
---@field name string Name server introduces himself to a peer
---@field hostObject KosmoHost
---@field started boolean
---@field tokens KosmoTokenCollection
---@field api KosmoApi
local KosmoServer = {}
local KosmoServer_meta = { __index = KosmoServer }
setmetatable(KosmoServer, { __index = socket.class })

KosmoServer.getClients = KosmoServer.getPeers

KosmoServer.getClientInfo = KosmoServer.getPeerInfo

KosmoServer.pingClients = KosmoServer.pingPeers

-- server fnc

function server.new(serverAddress, api_name, name)
    local obj = socket.new(serverAddress, KOSMO_DEBUG and ("server/api/" .. api_name) or ("api/" .. api_name), name)

    setmetatable(obj, KosmoServer_meta)

    return obj
end

-- Allow inheritance
server.class = KosmoServer

return server