-- client
local client = {}

local krequest = require("classes.KosmoRequest")
local session = require("classes.KosmoSession")
local socket = require("classes.KosmoSocket")
local cache = require("classes.KosmoCache")

-- documentation



-- config

local OFFICIAL_CLIENT_SCOPE = {
    "messages",
    "contacts",
    "profile"
}

-- consts

local AUTH_SERVER_NAME = "auth"
local MAIN_SERVER_NAME = "main"

local CLIENT_API_NAME = "client"

local GET_AUTH_SERVER_TASK_NAME = "auth_connect"
local REGISTER_TASK_NAME = "register"
local LOGIN_TASK_NAME = "login"

-- host commands

--- Redefined handler for server connect events in KosmoHost
local function host_connect_server(self, serverName, serverIndex)
    if serverName == AUTH_SERVER_NAME then
        if self.parent.events:resolveNickname(GET_AUTH_SERVER_TASK_NAME) then
            self.parent.events:finishTask(self.parent.events:resolveNickname(GET_AUTH_SERVER_TASK_NAME), true)
        end
    end
end

-- vars

local api_version = API_VERSION

local nop = function()end

-- init



-- fnc

local function packPassword(password)
    return love.data.hash("sha256", password)
end

local function checkError(response, err, message)
    local msg

    if not response then
        msg = message:format(-1, tostring(err))
    elseif response:isError() then
        local data = response:getParams()

        msg = message:format(tonumber(data.code) or -2, tostring(data.message))
    end

    if not msg then
        return false
    end

    if NOTIF then
        NOTIF:error(msg)
    else
        print(msg)
    end

    return true
end

-- classes

---@class KosmoClient : KosmoSocket
---@field serverAddress string?
---@field public session KosmoSession Session object to manipulate user data
local KosmoClient = { }
local KosmoClient_meta = { __index = KosmoClient }
setmetatable(KosmoClient, { __index = socket.class })

--#region api

function KosmoClient:api_receiveAuthServer(_, response, err)
    if checkError(response, err, "Ошибка при получении адреса сервера аутентификации, код %d.\n\"%s\"") then
        if self.events:resolveNickname(GET_AUTH_SERVER_TASK_NAME) then
            print(123)
            self.events:finishTask(self.events:resolveNickname(GET_AUTH_SERVER_TASK_NAME) --[[@as AsyncTaskIdentifier]], nil, err)
        end
        return
    end

    local data = response:getParams()

    local server_address = data.address

    self.hostObject:addServer(AUTH_SERVER_NAME, server_address)

    print("Success obtaining auth server address")
end

function KosmoClient:api_receiveRegister(_, response, err)
    if self.events:resolveNickname(REGISTER_TASK_NAME) then
        self.events:finishTask(self.events:resolveNickname(REGISTER_TASK_NAME) --[[@as AsyncTaskIdentifier]], response, err)
    end

    if checkError(response, err, "Ошибка при регистрации, код %d.\n\"%s\"") then
        return
    end

    print("success registring")
end

function KosmoClient:api_receiveLogin(_, response, err)
    if self.events:resolveNickname(LOGIN_TASK_NAME) then
        self.events:finishTask(self.events:resolveNickname(LOGIN_TASK_NAME) --[[@as AsyncTaskIdentifier]], response, err)
    end

    if checkError(response, err, "Ошибка при входе, код %d.\n\"%s\"") then
        return
    end

    local data = response:getParams()

    self.session.addSession(data.login, data.token, data.scope)
    self:changeUser(data.login)

    self:disconnectAuthServer()
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

function KosmoClient:changeUser(user)
    print("change user", user)
    self.session:setUser(user)
    self.cache = cache.new(self.session)

    print("now user", self.session:getUser())
end

--#region client functions

function KosmoClient:connectAuthServer()
    if not self:getMainServerStatus() then
        return nil, "No connection to main server"
    end

    if self:getAuthServerStatus() then
        return nil, "Auth server is already connected"
    end

    if self.events:resolveNickname(GET_AUTH_SERVER_TASK_NAME) then
        return nil, "Still connecting to auth server..."
    end

    self:requestMain("getAuthorizationServer", {}, self.api_receiveAuthServer)
    self.events:launchTask(GET_AUTH_SERVER_TASK_NAME, nop, GET_AUTH_SERVER_TASK_NAME)

    return GET_AUTH_SERVER_TASK_NAME
end

function KosmoClient:disconnectAuthServer()
    self.hostObject:removeServer(AUTH_SERVER_NAME)
end

function KosmoClient:login(login, password)
    if not self:getAuthServerStatus() then
        self:connectAuthServer()
        return nil, "No connection to auth server, try again later."
    end

    password = packPassword(password)

    self:requestAuth("login", {login = login, password = password, scope = OFFICIAL_CLIENT_SCOPE}, self.api_receiveLogin)
    self.events:launchTask(LOGIN_TASK_NAME, nop, LOGIN_TASK_NAME)

    return LOGIN_TASK_NAME
end

function KosmoClient:register(email, login, password)
    if not self:getAuthServerStatus() then
        self:connectAuthServer()
        return nil, "No connection to auth server, try again later."
    end

    password = packPassword(password)

    self:requestAuth("register", {email = email, login = login, password = password}, self.api_receiveRegister)
    self.events:launchTask(REGISTER_TASK_NAME, nop, REGISTER_TASK_NAME)

    return REGISTER_TASK_NAME
end

function KosmoClient:attachCallback(task_nickname, callback)
    self.events:attachCallback(task_nickname, callback)
end

--#endregion

-- client fnc

function client.new(serverAddress)
    local obj = socket.new("*:*", KOSMO_DEBUG and ("client/api/" .. CLIENT_API_NAME) or ("api/" .. CLIENT_API_NAME), "client")

    setmetatable(obj, KosmoClient_meta) ---@cast obj KosmoClient

    obj.serverAddress = serverAddress
    obj.session = session.new()

    if obj.session:getUser() then
        obj.cache = cache.new(obj.session)
    end

    obj.updateTimer = 0

    obj.hostObject.onServerConnect = host_connect_server

    return obj
end

return client