-- auth
local auth = {}

local kosmoserver = require("classes.KosmoServer")
local token = require("classes.KosmoToken")

local tokengen = require("scripts.token_generator")

-- documentation



-- config

local AUTH_API_NAME = "KosmoAuth"
local AUTH_SERVER_TOKEN_PATH_PATTERN = "server_auth_%s.tok"

-- consts



-- vars



-- init



-- fnc



-- classes

---@class KosmoServerAuth : KosmoServer
---@field token string Server token used by main server to authenticate with auth server 
local KosmoServerAuth = setmetatable({}, { __index = kosmoserver.class })
local KosmoServerAuth_meta = { __index = KosmoServerAuth }

---Adds main server token to its storage
---@param request KosmoRequest
function KosmoServerAuth:addMainServerToken(request)
    local token_object = token.new(request:getToken(), {main = true}, request:getPeer() --[[@as HostPeerIndex]], 0)

    self.tokens:add(token_object)
end

function KosmoServerAuth:loadToken()
    local token_filepath = AUTH_SERVER_TOKEN_PATH_PATTERN:format(self.name)

    if not love.filesystem.getInfo(token_filepath) then
        return self:generateServerToken()
    end

    local read_token, err = love.filesystem.read(token_filepath) --[[@as string]]

    if not read_token then
        error("Unable to read existing token from storage. Error: " .. err)
    end

    self.token = read_token
end

function KosmoServerAuth:generateServerToken()
    local token = tokengen.generateServerToken()

    local success, err = love.filesystem.write(AUTH_SERVER_TOKEN_PATH_PATTERN:format(self.name), token)

    self.token = token

    if not success then
        error("Unable to set Auth server token. Error: " .. err)
    end
end

-- auth fnc

function auth.new(address, server_name)
    local new_server = kosmoserver.new(address, AUTH_API_NAME, server_name)

    setmetatable(new_server, KosmoServerAuth_meta) ---@cast new_server KosmoServerAuth

    new_server:loadToken()

    return new_server
end

return auth