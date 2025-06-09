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

local UPDATE_PERIOD = 5

-- consts

local AUTH_SERVER_NAME = "auth"
local MAIN_SERVER_NAME = "main"

local CLIENT_API_NAME = "client"

local GET_AUTH_SERVER_TASK_NAME = "auth_connect"
local REGISTER_TASK_NAME = "register"
local LOGIN_TASK_NAME = "login"
local INTRODUCE_TASK_NAME = "introduce"
local SEARCH_CONTACT_TASK_NAME = "search contact"
local GET_USER_TASK_NAME = "get user"
local ADD_FRIEND_TASK_NAME = "add friend"
local SEND_MESSAGE_TASK_NAME = "send message"

-- host commands

--- Redefined handler for server connect events in KosmoHost
local function host_connect_server(self, serverName, serverIndex)
    if serverName == AUTH_SERVER_NAME then
        if self.parent.events:resolveNickname(GET_AUTH_SERVER_TASK_NAME) then
            self.parent.events:finishTask(self.parent.events:resolveNickname(GET_AUTH_SERVER_TASK_NAME), true)
        end
    end

    if serverName == MAIN_SERVER_NAME then
        if self.parent.session:getToken() then
            self.parent:introduceToken()
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
        --NOTIF:error(msg)
    else
        print(msg)
    end

    return true
end

-- classes

---@class KosmoClient : KosmoSocket
---@field serverAddress string?
---@field public session KosmoSession Session object to manipulate user data
---@field cache KosmoCache client cache
local KosmoClient = { }
local KosmoClient_meta = { __index = KosmoClient }
setmetatable(KosmoClient, { __index = socket.class })

--#region api

function KosmoClient:api_receiveAuthServer(_, response, err)
    if checkError(response, err, "Ошибка при получении адреса сервера аутентификации, код %d.\n\"%s\"") then
        self:finishIfRunning(GET_AUTH_SERVER_TASK_NAME, nil, err) -- здесь завершается только при ошибке, потому что успехом завершится только после подключения
        return
    end

    local data = response:getParams()

    local server_address = data.address

    self.hostObject:addServer(AUTH_SERVER_NAME, server_address)

    print("Success obtaining auth server address")
end

function KosmoClient:api_receiveRegister(_, response, err)
    self:finishIfRunning(REGISTER_TASK_NAME, response, err)

    if checkError(response, err, "Ошибка при регистрации, код %d.\n\"%s\"") then
        return
    end

    print("success registring")
end

function KosmoClient:api_receiveLogin(_, response, err)
    if checkError(response, err, "Ошибка при входе, код %d.\n\"%s\"") then
        self:finishIfRunning(LOGIN_TASK_NAME, response, err)
        return
    end

    local data = response:getParams()

    self.session.addSession(data.login, data.token, data.scope)
    self:changeUser(data.login)

    self:disconnectAuthServer()

    self:finishIfRunning(LOGIN_TASK_NAME, response, err)
end

function KosmoClient:api_receiveIntroduce(_, response, err)
    self:finishIfRunning(INTRODUCE_TASK_NAME, response, err)

    if checkError(response, err, "Ошибка при подтверждении сессии, код %d.\n\"%s\"") then
        return
    end

    self:getUser(response:getParams().clid)
end

function KosmoClient:api_receiveSearch(_, response, err)
    if checkError(response, err, "Ошибка при поиске контакта, код %d.\n\"%s\"") then
        self:finishIfRunning(SEARCH_CONTACT_TASK_NAME, response, err)
        return
    end

    if not response:getParams().id then
        self:finishIfRunning(SEARCH_CONTACT_TASK_NAME, response, err)
        return
    end

    self.cache:setProfile(response:getParams().id, response:getParams())

    self:finishIfRunning(SEARCH_CONTACT_TASK_NAME, response, err)
end

function KosmoClient:api_receiveUser(initial, response, err)
    if checkError(response, err, "Ошибка при получении информации о пользователе, код %d.\n\"%s\"") then
        self:finishIfRunning(GET_USER_TASK_NAME, response, err)
        return
    end

    self.cache:setProfile(initial:getParams().user, response:getParams())

    self:finishIfRunning(GET_USER_TASK_NAME, response, err)
end

function KosmoClient:api_receiveFriend(initial, response, err)
    if checkError(response, err, "Ошибка при добавлении контакта, код %d.\n\"%s\"") then
        self:finishIfRunning(ADD_FRIEND_TASK_NAME, response, err)
        return
    end

    self.cache:setProfile(self.session:getUser(), response:getParams())

    self:finishIfRunning(ADD_FRIEND_TASK_NAME, response, err)
end

function KosmoClient:api_receiveMessage(initial, response, err)
    if checkError(response, err, "Ошибка при отправке сообщения, код %d.\n\"%s\"") then
        self:finishIfRunning(SEND_MESSAGE_TASK_NAME, response, err)
        return
    end

    self.cache:setProfile(self.session:getUser(), response:getParams())

    self:finishIfRunning(SEND_MESSAGE_TASK_NAME, response, err)
end

--#endregion

function KosmoClient:update(dt)
    socket.class.update(self, dt)

    self.updateTimer = self.updateTimer + dt
    if self.updateTimer >= UPDATE_PERIOD then
        if self.session:getUser() then
            self:getUser(self.session:getUser())
        end

        self.updateTimer = self.updateTimer - UPDATE_PERIOD
    end
end

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
        self:connectAuthServer()
        callback(self, nil, "Auth server is unreachable")
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
    if not login or not password then
        return nil, "Введите логин и пароль"
    end

    if #login == 0 or #password == 0 then
        return nil, "Введите логин и пароль"
    end

    password = packPassword(password)

    self.events:launchTask(LOGIN_TASK_NAME, nop, LOGIN_TASK_NAME)
    self:requestAuth("login", {login = login, password = password, scope = OFFICIAL_CLIENT_SCOPE}, self.api_receiveLogin)

    return LOGIN_TASK_NAME
end

function KosmoClient:register(email, login, password)
    password = packPassword(password)

    self.events:launchTask(REGISTER_TASK_NAME, nop, REGISTER_TASK_NAME)
    self:requestAuth("register", {email = email, login = login, password = password}, self.api_receiveRegister)

    return REGISTER_TASK_NAME
end

function KosmoClient:introduceToken()
    local token = self.session:getTokenString()
    local login = self.session:getUser()

    if not login then
        return nil, "Invalid session"
    end

    if #token == 0 then
        return nil, "No token to introduce"
    end

    self.events:launchTask(INTRODUCE_TASK_NAME, nop, INTRODUCE_TASK_NAME)
    self:requestMain("introduceToken", {token = token}, self.api_receiveIntroduce)

    return INTRODUCE_TASK_NAME
end

function KosmoClient:searchContact(email_or_login)
    if #email_or_login == 0 then
        return nil, "no query"
    end

    self.events:launchTask(SEARCH_CONTACT_TASK_NAME, nop, SEARCH_CONTACT_TASK_NAME)
    self:requestMain("searchContact", {query = email_or_login}, self.api_receiveSearch)

    return SEARCH_CONTACT_TASK_NAME
end

function KosmoClient:getUser(user_id)
    if not user_id then
        return nil, "no user id"
    end

    self.events:launchTask(GET_USER_TASK_NAME, nop, GET_USER_TASK_NAME)
    self:requestMain("getUser", {user = user_id}, self.api_receiveUser)

    return GET_USER_TASK_NAME
end

function KosmoClient:addFriend(user_id)
    if not user_id then
        return nil, "no user id"
    end

    self.events:launchTask(ADD_FRIEND_TASK_NAME, nop, ADD_FRIEND_TASK_NAME)
    self:requestMain("addFriend", {user = user_id}, self.api_receiveFriend)
    return ADD_FRIEND_TASK_NAME
end

function KosmoClient:sendMessage(user_id, message)
    if not user_id then
        return nil, "no user id"
    end

    self.events:launchTask(SEND_MESSAGE_TASK_NAME, nop, SEND_MESSAGE_TASK_NAME)
    self:requestMain("sendMessage", {friend = user_id, message = message}, self.api_receiveMessage)
    return SEND_MESSAGE_TASK_NAME
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