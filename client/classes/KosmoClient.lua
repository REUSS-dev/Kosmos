-- client
local client = {}

local krequest = require("classes.KosmoRequest")
local session = require("classes.KosmoSession")
local socket = require("classes.KosmoSocket")

-- documentation



-- config



-- consts

local AUTH_SERVER_NAME = "auth"
local MAIN_SERVER_NAME = "main"

local CLIENT_API_NAME = "client"

local GET_AUTH_SERVER_TASK_NAME = "auth_connect"
local REGISTER_TASK_NAME = "register"

-- host commands



-- vars

local api_version = API_VERSION

-- init



-- fnc



-- classes

---@class KosmoClient : KosmoSocket
---@field serverAddress string?
---@field public session KosmoSession Session object to manipulate user data
local KosmoClient = { }
local KosmoClient_meta = { __index = KosmoClient }
setmetatable(KosmoClient, { __index = socket.class })

--#region api

function KosmoClient:api_receiveAuthServer(_, response, err)
    if not response then
        -- client error during getting auth server address
        print("client error during getting auth server address: ", err)

        if NOTIF then
            NOTIF:error("Ошибка при получении адреса сервера аутентификации.\n" .. "\"" .. tostring(err) .. "\"")
        end
        return
    end

    local data = response:getParams()

    if response:isError() then
        -- server error during getting auth server address
        print("server error during getting auth server address: ", data.code, data.message)

        if NOTIF then
            NOTIF:error("Ошибка при получении адреса сервера аутентификации, код " .. tostring(data.code) .. ".\n" .. "\"" .. tostring(data.message) .. "\"")
        end
        return
    end

    local server_address = data.address

    self.hostObject:addServer(AUTH_SERVER_NAME, server_address)

    print("Success obtaining auth server address")
end

function KosmoClient:api_receiveRegister(original, response, err)
    if not response then
        -- client error during getting auth server address
        print("client error during register: ", err)

        if NOTIF then
            NOTIF:error("Ошибка при регистрации.\n" .. "\"" .. tostring(err) .. "\"")
        end
        return
    end

    local data = response:getParams()

    if response:isError() then
        -- server error during getting auth server address
        print("server error during getting auth server address: ", data.code, data.message)

        if NOTIF then
            NOTIF:error("Ошибка при регистрации, код " .. tostring(data.code) .. ".\n" .. "\"" .. tostring(data.message) .. "\"")
        end
        return
    end

    print("success registring")
end

--#endregion

function KosmoClient:getClientAddress()
    return self.hostObject.hostInfo.address
end

function KosmoClient:getAuthServerStatus()
    return self.hostObject:getServerStatus(AUTH_SERVER_NAME)
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

function KosmoClient:requestAuth(method, params, callback, nickname)
    if not self:getAuthServerStatus() then
        callback(self, nil, "Main server is unreachable")
        return nil
    end

    local request = krequest.new(method, params, self.session:getTokenString(), api_version)

    request:setPeer(self.hostObject:getServer(AUTH_SERVER_NAME).peer)

    return self:request(request, callback, nickname)
end

function KosmoClient:requestMain(method, params, callback, nickname)
    if not self:getMainServerStatus() then
        callback(self, nil, "Main server is unreachable")
        return nil
    end

    local request = krequest.new(method, params, self.session:getTokenString(), api_version)

    request:setPeer(self.hostObject:getServer(MAIN_SERVER_NAME).peer)

    return self:request(request, callback, nickname)
end

--#region client functions

function KosmoClient:connectAuthServer()
    if not self:getMainServerStatus() then
        return nil, "No connection to main server"
    end

    if self:getAuthServerStatus() then
        return nil, "Auth server is already connected"
    end

    if self.sentRequests:resolveNickname(GET_AUTH_SERVER_TASK_NAME) then
        return nil, "Still connecting to auth server..."
    end

    self:requestMain("getAuthorizationServer", {}, self.api_receiveAuthServer, GET_AUTH_SERVER_TASK_NAME)

    return GET_AUTH_SERVER_TASK_NAME
end

function KosmoClient:register(email, login, password)
    if not self:getAuthServerStatus() then
        self:connectAuthServer()
        return nil, "No connection to auth server, try again later."
    end

    self:requestAuth("register", {email = email, login = login, password = love.data.hash("sha256", password)}, self.api_receiveRegister, REGISTER_TASK_NAME)

    return REGISTER_TASK_NAME
end

--#endregion

-- client fnc

function client.new(serverAddress)
    local obj = socket.new("*:*", KOSMO_DEBUG and ("client/api/" .. CLIENT_API_NAME) or ("api/" .. CLIENT_API_NAME), "client")

    setmetatable(obj, KosmoClient_meta) ---@cast obj KosmoClient

    obj.serverAddress = serverAddress
    obj.session = session.new()

    return obj
end

return client