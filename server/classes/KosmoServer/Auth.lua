-- auth
local auth = {}

local sdb = require("libs.stellardb.streladb")
require("libs.stellardb.strela_aes128")
local bdb = require("libs.stellardb.btreedb")
local sbon = require("libs.stellardb.sbon")

local kosmoserver = require("classes.KosmoServer")
local token = require("classes.KosmoToken")

local tokengen = require("scripts.token_generator")

-- documentation

---@alias KosmoServerAuth_dbName string
---@alias KosmoServerAuth_dbKey string

---@alias KosmoServerAuth_Account {[1]: string, [2]: string, [3]: string, [4]: string}

-- config

local AUTH_API_NAME = "KosmoAuth"
local AUTH_SERVER_TOKEN_PATH_PATTERN = "server_auth_%s.tok"

local DB_ACCOUNTS_FILENAME = "sauth_accounts"
local DB_TOKENS_FILENAME = "sauth_tokens"

-- consts

local PASSWORD_SALT_LENGTH = 16

local ADMIN_EMAIL = "admin@admin.com"

-- vars

local db_accounts_filepath = love.filesystem.getSaveDirectory() .. "/" .. DB_ACCOUNTS_FILENAME
local db_tokens_filepath = love.filesystem.getSaveDirectory() .. "/" .. DB_TOKENS_FILENAME

-- init



-- fnc

local function salt_password(password, salt)
    salt = salt or tokengen.generate(PASSWORD_SALT_LENGTH)

    password = love.data.hash("sha256", love.data.hash("sha256", password .. salt) .. salt)

    return password, salt
end

-- classes

---@class KosmoServerAuth : KosmoServer
---@field token string Server token used by main server to authenticate with auth server
---@field keys table<KosmoServerAuth_dbName, KosmoServerAuth_dbKey>
---@field db_accounts StrelaDB Database of user accounts
---@field db_tokens BTreeDB Database of client tokens
local KosmoServerAuth = setmetatable({}, { __index = kosmoserver.class })
local KosmoServerAuth_meta = { __index = KosmoServerAuth }

function KosmoServerAuth:start(...)
    if not self.keys[db_accounts_filepath] then
        error("Cannot start Authorization server without database keys!")
    end

    kosmoserver.class.start(self, ...)
end

function KosmoServerAuth:stop()
    self.db_accounts:close()
    self.db_tokens:close()
end

---Adds main server token to its storage
---@param request KosmoRequest
function KosmoServerAuth:addMainServerToken(request)
    local token_object = token.new(request:getToken(), {main = true}, request:getPeer() --[[@as HostPeerIndex]], 0)

    self.tokens:add(token_object)
end

--#region auth server token management

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

--#endregion

--#region databases

function KosmoServerAuth:setDatabaseKeys(accounts)
    self.keys[db_accounts_filepath] = accounts

    self.db_accounts:modifyField("email", "key_aes128", accounts)

    if self.db_accounts.count == 0 then
        self.db_accounts:add{
            "Admin",
            "admin",
            ADMIN_EMAIL,
            "0",
            "0"
        }
    end

    if not self.db_accounts:getByKey("email", ADMIN_EMAIL) then
        error("Incorrect key for accounts database!")
    end
end

function KosmoServerAuth:initializeDatabases()
    self.keys = {}

    self:initializeDatabases_accounts()
    self:initializeDatabases_tokens()
end

function KosmoServerAuth:initializeDatabases_accounts()
    local openned = sdb.load(db_accounts_filepath)

    if not openned then
        openned = sdb.new{
            {name = "name", type = sdb.FieldType.STRING, size = 64},
            {name = "login", type = sdb.FieldType.STRING, size = 16, key = true},
            {name = "email", type = sdb.FieldType.AES_128, size = 254, key = true},
            {name = "password", type = sdb.FieldType.STRING, size = 32},
            {name = "salt", type = sdb.FieldType.STRING, size = PASSWORD_SALT_LENGTH}
        }

        openned:open(db_accounts_filepath)
    end

    self.db_accounts = openned
end

function KosmoServerAuth:initializeDatabases_tokens()
    local openned = bdb.load(db_tokens_filepath)

    if not openned then
        openned = bdb.new(tokengen.getClientTokenLength())

        openned:open(db_tokens_filepath)
    end

    self.db_tokens = openned
end

--#endregion

--#region auth server functions

---Log user into system
---@param login string
---@param password string
---@return string? token
---@return string? err
function KosmoServerAuth:loginUser(login, password, scope)
    login = string.lower(login)

    local entry_id, entry = self.db_accounts:getByKey("login", login)

    if not entry_id then
        return nil, "Неверное имя пользователя или пароль!"--"Invalid login credentials!"
    end
    ---@cast entry KosmoServerAuth_Account

    password = salt_password(password, entry[4])

    if password ~= entry[3] then
        return nil, "Неверное имя пользователя или пароль!"--"Invalid login credentials!"
    end

    local new_token
    repeat
        new_token = tokengen.generateClientToken()
    until not self.db_tokens:get(new_token)

    self.db_tokens:set(new_token, sbon.encode({user = entry_id, scope = scope}))

    return new_token
end

---Register user in a system
---@param email string
---@param login string
---@param password string
function KosmoServerAuth:registerUser(email, login, password)
    local salted_password, salt = salt_password(password)

    local email_lower = string.lower(email)

    if self.db_accounts:getByKey("email", email_lower) then
        return nil, "User with this email is already registered"
    end

    local login_lower = string.lower(login)

    if self.db_accounts:getByKey("login", login_lower) then
        return nil, "User with this login is already registered"
    end

    local db_success = self.db_accounts:add{
        login,
        login_lower,
        email_lower,
        salted_password,
        salt
    }

    return db_success
end

--#endregion

-- auth fnc

function auth.new(address, server_name)
    local new_server = kosmoserver.new(address, AUTH_API_NAME, server_name)
    setmetatable(new_server, KosmoServerAuth_meta) ---@cast new_server KosmoServerAuth

    new_server:loadToken()

    new_server:initializeDatabases()

    return new_server
end

return auth