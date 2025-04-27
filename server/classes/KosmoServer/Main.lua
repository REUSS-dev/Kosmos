-- mainserver
local mainserver = {}

local kosmoserver = require("classes.KosmoServer")
local token = require("classes.KosmoToken")
local request = require("classes.KosmoRequest")

local tokengen = require("scripts.token_generator")

-- documentation



-- config

local MAIN_API_NAME = "KosmoCentral"

local AUTH_SERVER_NAME = "auth"

-- consts



-- vars



-- init



-- fnc

---Redefined handler for server connect events in KosmoHost
---@param self KosmoHost
---@param serverName string
---@param serverIndex HostPeerIndex
local function host_connect_server(self, serverName, serverIndex)
    local new_token = tokengen.generateClientToken()

    local new_server_token = token.new(new_token, { service = true }, serverIndex, 0)
    local applied_server_token = self.parent.serverTokens[serverName]

    local server_hello_request = request.new("server_hello", { token = applied_server_token }, new_server_token:getToken(), 0):setPeer(serverIndex)

    self.parent.connectedServers[server_hello_request:getUid()] = serverName -- Little memory leak

    self.parent.tokens:add(new_server_token)
    self.parent:request(server_hello_request)
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
local KosmoServerMain = setmetatable({}, { __index = kosmoserver.class })
local KosmoServerMain_meta = { __index = KosmoServerMain }

function KosmoServerMain:addAuthServer(address, auth_server_token)
    self.serverTokens[AUTH_SERVER_NAME] = auth_server_token

    self.hostObject:addServer(AUTH_SERVER_NAME, address)
end

function KosmoServerMain:getAuthServerStatus()
    return self.connectedServers[AUTH_SERVER_NAME] and true or false
end

-- mainserver fnc

function mainserver.new(address, server_name)
    local new_server = kosmoserver.new(address, MAIN_API_NAME, server_name)

    setmetatable(new_server, KosmoServerMain_meta) ---@cast new_server KosmoServerMain

    new_server.serverTokens = {}
    new_server.connectedServers = {}

    new_server.hostObject.onServerConnect = host_connect_server
    new_server.hostObject.onServerDisconnect = host_disconnect_server

    return new_server
end

return mainserver