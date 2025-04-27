local auth_api = {}
local fallback

local server_hello_failed_error = {
    message = "Provided method is unknown.",
    code = 405,
}

--#region Service communication - Authorization

---Handle main server server hello. Check provided token and send server_ack
---@param self KosmoServerAuth
---@param request KosmoRequest
function auth_api.server_hello(self, request)
    local provided_token = request:getParams().token

    if provided_token ~= self.token then
        self:responseError(request, server_hello_failed_error)
        self.hostObject:command("disconnect", request:getPeer())

        return
    end

    self:addMainServerToken(request)

    self:response(request, { name = self:getName() }, "server_ack")
end

--#endregion

return auth_api, fallback