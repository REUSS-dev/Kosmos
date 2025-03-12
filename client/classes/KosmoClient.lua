-- client
local client = {}

local host = require("classes.KosmoHost")

-- documentation



-- config



-- consts

local FILE_CLIENT_HOST_COMMANDS = "scripts/network/clientCommands.lua"
local FILE_CLIENT_HOST_EVENTS = "scripts/network/clientEvents.lua"

-- host commands

---@type {[string]:{delay: number, timeout: number?, callback: fun(self: {parent: KosmoClient}, ...)}}
local client_commands = {
    disconnectServer = {
        delay = 1,
        callback = function (self)
            self.parent.serverStatus = false
        end
    }
}

-- vars

local clientCommandScript, clientEventScript

-- init

clientCommandScript = love.filesystem.read(FILE_CLIENT_HOST_COMMANDS)
clientEventScript = love.filesystem.read(FILE_CLIENT_HOST_EVENTS)

-- fnc

local function onConnect(self)
    self.parent.serverStatus = true
end

local function onDisconnect(self)
    self.parent.serverStatus = false
end

-- classes

---@class KosmoClient
---@field hostObject KosmoHost
---@field started boolean
---@field serverAddress string?
---@field serverConnectionIndex integer?
---@field serverStatus boolean
local KosmoClient = {}
local KosmoClient_meta = { __index = KosmoClient }

function KosmoClient:start()
    self.hostObject:start("*:*")

    self.started = true

    if self.serverAddress then
        self.hostObject:command("connect", self.serverAddress)
    end
end

function KosmoClient:update(dt)
    self.hostObject:update(dt)
end

function KosmoClient:getClientAddress()
    return self.hostObject.hostInfo.address
end

function KosmoClient:getServerStatus()
    return self.serverStatus
end

function KosmoClient:setServerAddress(address)
    self.serverAddress = address

    if self.started then
        if self.serverStatus then
            self.hostObject:command("disconnectServer", self.serverConnectionIndex)
        end

        self.hostObject:command("connect", self.serverAddress)
    end
end

-- client fnc

function client.new(serverAddress)
    local obj = setmetatable({}, KosmoClient_meta)

    obj.started = false

    obj.hostObject = host.new(client_commands, clientCommandScript, clientEventScript)
    obj.hostObject.parent = obj
    obj.hostObject.onConnect = onConnect
    obj.hostObject.onDisconnect = onDisconnect

    obj.serverAddress = serverAddress
    obj.serverStatus = false

    return obj
end

return client