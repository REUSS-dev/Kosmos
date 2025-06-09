---@class KosmoApiMain : KosmoServerMain
local main_api = {}
local fallback

--#region Service communication

---Register new user
---@param request KosmoRequest
function main_api:registerNew(request)
    local params = request:getParams()

    local user, name, login = params.user, params.name, params.login

    self:registerNewUser(user, name, login)
end

--#endregion

--#region Guest access - auth dependend

---Introduce your token to server (lock it to your peer)
---@param request KosmoRequest
function main_api:introduceToken(request)
    if self:getAuthServerStatus() then
        self:resolveToken(request)
    else
        self:responseError(request, {message = "Authorization server is currently down or unreachable.", code = 200})
    end
end

---Get auth server address
---@param request KosmoRequest
function main_api:getAuthorizationServer(request)
    local auth_server = self:getAuthServerAddress()

    if auth_server then
        self:response(request, {address = auth_server})
    else
        self:responseError(request, {message = "Authorization server is currently down or unreachable.", code = 503})
    end
end

--#endregion

--#region contacts

---@param request KosmoRequest
function main_api:searchContact(request)
    if self:getAuthServerStatus() then
        self:searchContact(request)
    else
        self:responseError(request, {message = "Authorization server is currently down or unreachable.", code = 200})
    end
end

---@param request KosmoRequest
function main_api:getUser(request)
    local user_id = request:getParams().user

    local user_data = self:getUserData(user_id)

    if not user_data then
        self:responseError(request, {message = "No user with provided ID.", code = 200})
    end

    self:response(request, user_data)
end

---@param request KosmoRequest
function main_api:addFriend(request)
    local friend_id = request:getParams().user
    local user_id = request:getClientID()

    local user_data = self:getUserData(user_id)
    user_data.friends[#user_data.friends+1] = friend_id

    local friend_data = self:getUserData(friend_id)
    friend_data.friends[#friend_data.friends+1] = user_id

    self:setUserData(user_id, user_data)
    self:setUserData(friend_id, friend_data)

    self:response(request, user_data)
end

---@param request KosmoRequest
function main_api:sendMessage(request)
    local params = request:getParams()

    local friend_id, message = params.friend, params.message
    local user_id = request:getClientID()

    local user_data = self:getUserData(user_id)
    local friend_data = self:getUserData(friend_id)

    local time = os.date("%H:%M", os.time())
    local message_fin = user_data.name .. " (" .. time .. ") : " .. message .. "\n"

    user_data.chats[tostring(friend_id)] = user_data.chats[tostring(friend_id)] or ""
    user_data.chats[tostring(friend_id)] = user_data.chats[tostring(friend_id)] .. message_fin

    friend_data.chats[tostring(user_id)] = friend_data.chats[tostring(user_id)] or ""
    friend_data.chats[tostring(user_id)] = friend_data.chats[tostring(user_id)] .. message_fin

    self:setUserData(user_id, user_data)
    self:setUserData(friend_id, friend_data)

    self:response(request, user_data)
end

--#endregion

return main_api, fallback