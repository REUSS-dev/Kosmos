---@class KosmoApiAuth : KosmoServerAuth
local auth_api = {}
local fallback

--#region Service communication - Authorization

local server_hello_failed_error = {
    message = "Provided method is unknown.",
    code = 405,
}

---Handle main server server hello. Check provided token and send server_ack
---@param self KosmoServerAuth
---@param request KosmoRequest
function auth_api:server_hello(request)
    local provided_token = request:getParams().token

    if provided_token ~= self.token then
        self:responseError(request, server_hello_failed_error)
        self.hostObject:command("disconnect", request:getPeer())

        return
    end

    self:addMainServerToken(request)

    self:response(request, { name = self:getName() })
end

--#endregion

--#region guest access

--#region register

local email_validate = require("scripts.validemail")

local function validateRegisterInfo(email, login)
    if #email == 0 then
        return false
    end

    if #email > 254 then
        return false
    end

    if not email_validate(email) then
        return false
    end

    if #login == 0 then
        return false
    end

    if #login < 4 or 16 < #login then
        return false
    end

    return true
end

local failed_register_error = {
    message = "Register credentials are invalid.",
    code = 200,
}

local register_rejected_error = {
    message = "Register failed due to unknown error.",
    code = 200,
}

function auth_api:register(request)
    local creds = request:getParams()

    local email, login, password = creds.email, creds.login, creds.password

    if not validateRegisterInfo(email, login) then
        self:responseError(request, failed_register_error)
        return
    end

    local success, err = self:registerUser(email, login, password)

    if not success then
        self:responseError(request, {message = err --[[@as string]], code = 202})
        return
    end

    self:response(request, {login = login})
end

--#endregion

--#endregion

return auth_api, fallback