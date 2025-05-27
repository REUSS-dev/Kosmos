-- client
local client = {}

local socket = require("classes.KosmoSocket")
local session = require("classes.KosmoSession")

-- documentation



-- config



-- consts

local MAIN_SERVER_NAME = "main"

local CLIENT_API_NAME = "client"

-- host commands



-- vars



-- init



-- fnc



-- classes

---@class KosmoClient : KosmoSocket
---@field serverAddress string?
---@field public session KosmoSession Session object to manipulate user data
local KosmoClient = { }
local KosmoClient_meta = { __index = KosmoClient }
setmetatable(KosmoClient, { __index = socket.class })

function KosmoClient:getClientAddress()
    return self.hostObject.hostInfo.address
end

function KosmoClient:getMainServerStatus()
    return self.hostObject:getServerStatus(MAIN_SERVER_NAME)
end

function KosmoClient:setMainServerAddress(address)
    if self.started then
        if self:getMainServerStatus() ~= nil then
            self.hostObject:removeServer(MAIN_SERVER_NAME)
        end

        self.serverAddress = address

        self.hostObject:addServer(MAIN_SERVER_NAME, address)
    end
end

-- client fnc

function client.new(serverAddress)
    local obj = socket.new("*:*", KOSMO_DEBUG and ("client/api/" .. CLIENT_API_NAME) or ("api/" .. CLIENT_API_NAME), "client")

    setmetatable(obj, KosmoClient_meta) ---@cast obj KosmoClient

    obj.serverAddress = serverAddress
    obj.session = session.new()

    return obj
end

return client