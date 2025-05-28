local main_api = {}
local fallback

--#region Service communication - Authorization



--#endregion

--#region Guest access

---Introduce your token to server (lock it to your peer)
---@param self KosmoServer
---@param request KosmoRequest
function main_api.introduceToken(self, request)
    
end

---Get auth server address
---@param self KosmoServerMain
---@param request KosmoRequest
function main_api.getAuthorizationServer(self, request)
    local auth_server = self:getAuthServerAddress()

    if auth_server then
        self:response(request, {address = auth_server})
    else
        self:responseError(request, {message = "Authorization server is currently down or unreachable.", code = 200})
    end
end

--#endregion

return main_api, fallback