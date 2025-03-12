-- server
local server = {}

local host = require("classes.KosmoHost")

-- documentation



-- config



-- consts

local FILE_SERVER_HOST_COMMANDS = "scripts/network/serverCommands.lua"
local FILE_SERVER_HOST_EVENTS = "scripts/network/serverEvents.lua"

-- host commands

---@type {[string]:{delay: number, timeout: number?, callback: fun(self: {parent: KosmoServer}, ...)}}
local server_commands = {
}

-- vars

local serverCommandScript, serverEventScript

-- init

serverCommandScript = love.filesystem.read(FILE_SERVER_HOST_COMMANDS)
serverEventScript = love.filesystem.read(FILE_SERVER_HOST_EVENTS)

-- fnc



-- classes

---@class KosmoServer
---@field hostObject KosmoHost
---@field started boolean
local KosmoServer = {}
local KosmoServer_meta = { __index = KosmoServer }

function KosmoServer:start(address)
    self.serverAddress = address or self.serverAddress

    if not self.serverAddress then
        error("Provide server address to start server")
    end

    self.hostObject:start(self.serverAddress)

    self.started = true
end

function KosmoServer:update(dt)
    self.hostObject:update(dt)
end

function KosmoServer:getAddress()
    return self.hostObject:getAddress() or self.serverAddress
end

function KosmoServer:setAddress(address)
    if not self.started then
        self.serverAddress = address
    end
end

function KosmoServer:getClients()
    return self.hostObject.hostInfo.peerIndices
end

function KosmoServer:getClientInfo(clientId)
    return self.hostObject.hostInfo.connections[clientId]
end

function KosmoServer:pingClients(clientList)
    return self.hostObject:updateRoundTrip(clientList)
end

-- client fnc

function server.new(serverAddress)
    local obj = setmetatable({}, KosmoServer_meta)

    obj.started = false

    obj.hostObject = host.new(server_commands, serverCommandScript, serverEventScript)
    obj.hostObject.parent = obj

    obj.serverAddress = serverAddress

    return obj
end

return server