---@class KosmoApiAuth : KosmoServerAuth
local auth_api = {}
local fallback

local sbon = require("stellardb.sbon")

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

--#region login

local failed_login_error = {
    message = "Login credentials are invalid.",
    code = 200,
}

local login_rejected_error = {
    message = "Login failed due to unknown error.",
    code = 200,
}

function auth_api:login(request)
    local creds = request:getParams()

    local login, password = creds.login, creds.password
    local scope = creds.scope

    if not scope or #scope == 0 then
        self:responseError(request, login_rejected_error)
        return
    end

    if type(login) ~= "string" or type(password) ~= "string" then
        self:responseError(request, failed_login_error)
        return
    end

    local success, err = self:loginUser(login, password, scope)

    if not success then
        self:responseError(request, {message = err --[[@as string]], code = 202})
        return
    end

    self:response(request, {login = err, user = login, scope = scope, token = success})
end

--#endregion

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

    if type(email) ~= "string" or type(login) ~= "string" or type(password) ~= "string" then
        self:responseError(request, failed_register_error)
        return
    end

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

--#region server access

local bad_token = {
    message = "Provided token is invalid.",
    code = 202,
}

local bad_login = {
    msessage = "Provided logins do not match",
    code = 204
}

function auth_api:resolveToken(request)
    local params = request:getParams()

    local token = params.token

    local token_resolved = self.db_tokens:get(token)

    if not token_resolved then
        self:responseError(request, bad_token)
        return
    end

    local token_info = sbon.decode(token_resolved) --[[@as table]]
    local user_id, scope = token_info.user, token_info.scope

    local token_account = self.db_accounts:get(user_id)
    if not token_account then
        self:responseError(request, bad_token)
        return
    end

    self:response(request, {scope = scope, clid = user_id})
end

function auth_api:searchLoginEmail(request)
    local params = request:getParams()

    local login_or_email = string.lower(params.query)

    local login_found = self.db_accounts:getByKey("login", login_or_email)

    if login_found then
        self:response(request, {user = login_found})
    end

    local email_found = self.db_accounts:getByKey("email", login_or_email)

    if email_found then
        self:response(request, {user = email_found})
    end

    self:response(request, {user = nil})
end

--#endregion

return auth_api, fallback