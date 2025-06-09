-- mainserver
local mainserver = {}

local bdb = require("libs.stellardb.btreedb")
local sbon = require("libs.stellardb.sbon")

local kosmoserver = require("classes.KosmoServer")
local token = require("classes.KosmoToken")
local krequest = require("classes.KosmoRequest")

local tokengen = require("scripts.token_generator")

-- documentation



-- config

local MAIN_API_NAME = "KosmoCentral"

local AUTH_SERVER_NAME = "auth"



-- consts

local DB_PROFILES_FILENAME = "smain_profiles"

-- vars

local db_profiles_filepath = love.filesystem.getSaveDirectory() .. "/" .. DB_PROFILES_FILENAME

-- init



-- API responses



-- fnc

---Redefined handler for server connect events in KosmoHost
---@param self KosmoHost
---@param serverName string
---@param serverIndex HostPeerIndex
local function host_connect_server(self, serverName, serverIndex)
    local new_token = tokengen.generateClientToken()

    local new_server_token = token.new(new_token, { service = true }, serverIndex, 0)
    local applied_server_token = self.parent.serverTokens[serverName]

    local server_hello_request = krequest.new("server_hello", { token = applied_server_token }, new_server_token:getToken(), 0):setPeer(serverIndex)

    local request_uid = self.parent:request(server_hello_request, self.parent.api_serverAck)

    self.parent.connectedServers[request_uid] = serverName -- Little memory leak
    self.parent.tokens:add(new_server_token)
end

--- Redefined handler for server disconnect events in KosmoHost
local function host_disconnect_server(self, serverName, serverIndex)
    self.parent.tokens:deletePeerTokens(serverIndex)

    self.parent.connectedServers[serverName] = nil
end

-- classes

---@class KosmoServerMain : KosmoServer
---@field serverTokens table<string, string> Map of server names to server tokens (2048 bit) 
---@field connectedServers table<string, string> Map of server names to client tokens (256 bit). Serves as table of connected and authenticated servers
---@field db_profiles BTreeDB database of profile info
local KosmoServerMain = setmetatable({}, { __index = kosmoserver.class })
local KosmoServerMain_meta = { __index = KosmoServerMain }

--#region Server communication

function KosmoServerMain:api_serverAck(_, response)
    local server_name = self.connectedServers[response:getUid()]

    self.connectedServers[server_name] = response:getToken()
    self.connectedServers[response:getUid()] = nil
end

--#endregion

function KosmoServerMain:stop()
    self.db_profiles:close()
end

function KosmoServerMain:addAuthServer(address, auth_server_token)
    self.serverTokens[AUTH_SERVER_NAME] = auth_server_token

    self.hostObject:addServer(AUTH_SERVER_NAME, address)
end

function KosmoServerMain:getAuthServerStatus()
    return self.connectedServers[AUTH_SERVER_NAME] and true or false
end

function KosmoServerMain:getAuthServerAddress()
    return self.connectedServers[AUTH_SERVER_NAME] and self.hostObject:getServer(AUTH_SERVER_NAME).address or nil
end

--#region databases

function KosmoServerMain:initializeDatabases()
    self:initializeDatabases_profile()
end

function KosmoServerMain:initializeDatabases_profile()
    local openned = bdb.load(db_profiles_filepath)

    if not openned then
        openned = bdb.new(4)

        openned:open(db_profiles_filepath)
    end

    self.db_profiles = openned
end

--#endregion

--#region MAIN functions

---Register profile for new user
---@param user_id integer
function KosmoServerMain:registerNewUser(user_id, name, login)

    local key = sbon.encodeUnsignedInteger(user_id)

    local user_data = self.db_profiles:set(key, sbon.encode({name = name, login = login, friends = {}, chats = {}}))
    self.db_profiles:writeAll()

    return user_data
end

--#endregion

-- mainserver fnc

function mainserver.new(address, server_name)
    local new_server = kosmoserver.new(address, MAIN_API_NAME, server_name)

    setmetatable(new_server, KosmoServerMain_meta) ---@cast new_server KosmoServerMain

    new_server.serverTokens = {}
    new_server.connectedServers = {}

    new_server.hostObject.onServerConnect = host_connect_server
    new_server.hostObject.onServerDisconnect = host_disconnect_server

    new_server:initializeDatabases()

    return new_server
end

return mainserver