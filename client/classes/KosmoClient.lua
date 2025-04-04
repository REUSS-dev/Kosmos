-- client
local client = {}

local host = require("classes.KosmoHost")

-- documentation



-- config



-- consts



-- host commands



-- vars



-- init



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
local KosmoClient = {}
local KosmoClient_meta = { __index = KosmoClient }

function KosmoClient:start()
    self.hostObject:start("*:*")

    self.started = true

    if self.serverAddress then
        self.hostObject:addServer("main", self.serverAddress)
    end
end

function KosmoClient:update(dt)
    self.hostObject:update(dt)
end

function KosmoClient:getClientAddress()
    return self.hostObject.hostInfo.address
end

function KosmoClient:getServerStatus()
    return self.hostObject:getServerStatus("main")
end

function KosmoClient:setServerAddress(address)
    if self.started then
        if self.hostObject:getServerStatus("main") ~= nil then
            self.hostObject:removeServer("main")
        end

        self.serverAddress = address

        self.hostObject:addServer("main", address)
    end
end

-- client fnc

function client.new(serverAddress)
    local obj = setmetatable({}, KosmoClient_meta)

    obj.started = false

    obj.hostObject = host.new()
    obj.hostObject.parent = obj
    obj.hostObject.onConnect = onConnect
    obj.hostObject.onDisconnect = onDisconnect

    obj.serverAddress = serverAddress

    return obj
end

return client