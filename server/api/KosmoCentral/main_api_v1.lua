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
        self:responseError(request, {message = "Authorization server is currently down or unreachable.", code = 200})
    end
end

--#endregion

return main_api, fallback