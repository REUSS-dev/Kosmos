-- server
local server = {}

local api = require("classes.KosmoApi")
local host = require("classes.KosmoHost")
local token = require("classes.KosmoToken")

-- documentation



-- config



-- consts

local ERROR_OUT_OF_SCOPE = {
    message = "Cannot access method with this token. This method is out of scope.",
    code = 403,
}

local ERROR_UNAUTHORIZED = {
    message = "Cannot access method without token. Guest access not permitted.",
    code = 401,
}

local ERROR_UNALLOWED = {
    message = "Provided method is unknown.",
    code = 405,
}

local ERROR_CONFLICT = {
    message = "This token is already authorized somewhere else. Security violation",
    code = 409,
}

-- vars



-- init



-- fnc

--- Redefined handler for disconnect events in KosmoHost
local function host_disconnect(self, peerIndex, _, _)
    self.parent.tokens:deletePeerTokens(peerIndex)
end

--- Redefined handler for server disconnect events in KosmoHost
local function host_disconnect_server(self, _, serverIndex)
    self.parent.tokens:deletePeerTokens(serverIndex)
end

-- classes

---@class KosmoServer
---@field name string Name server introduces himself to a peer
---@field hostObject KosmoHost
---@field started boolean
---@field tokens KosmoTokenCollection
---@field api KosmoApi
local KosmoServer = {}
local KosmoServer_meta = { __index = KosmoServer }

function KosmoServer:start(address)
    self.serverAddress = address or self.serverAddress

    if not self.serverAddress then
        error("Provide server address to start server")
    end

    self.hostObject:start(self.serverAddress)

    self.started = true
end

function KosmoServer:update(dt)
    self.hostObject:update(dt)
end

function KosmoServer:getAddress()
    return self.hostObject:getAddress() or self.serverAddress
end

function KosmoServer:setAddress(address)
    if not self.started then
        self.serverAddress = address
    end

    return self
end

function KosmoServer:getName()
    return self.name
end

function KosmoServer:setName(new_name)
    if not self.started then
        self.name = new_name
    end

    return self
end

function KosmoServer:getClients()
    return self.hostObject.hostInfo.peerIndices
end

function KosmoServer:getClientInfo(clientId)
    return self.hostObject.hostInfo.connections[clientId]
end

function KosmoServer:pingClients(clientList)
    return self.hostObject:updateRoundTrip(clientList)
end

function KosmoServer:request(request)
    local request_peer = request:getPeer()

    if not request_peer then
        error("No peer set for request " .. request:getMethod())
    end

    local request_payload = request:getPayload()

    self.hostObject:command("send", request_peer, request_payload)
end

---Send a response to a peer of provided request
---@param request KosmoRequest
---@param params table<string, any>
---@param method string? Oprional response method alter
function KosmoServer:response(request, params, method)
    local response_request = request:createResponse(params, method)

    self.hostObject:command("send", request:getPeer(), response_request:getPayload())
end

---Send an error to a peer of provided request
---@param request KosmoRequest
---@param error_header {message: string, code: integer}
function KosmoServer:responseError(request, error_header)
    local response_request = request:createError(error_header)

    self.hostObject:command("send", request:getPeer(), response_request:getPayload())
end

-- IKosmoHostEnabled

---Define token validation
---@param request KosmoRequest
function KosmoServer:validate(request)
    local providedToken = self.tokens:find(request:getToken())
    local scopeCheck = self.api:isMethodWithinScope(request:getMethod(), providedToken)

    if not scopeCheck then -- scope check failed
        if scopeCheck == false then -- scope check negative (provided method is out of token's scope)
            if providedToken then -- token IS provided
                return nil, ERROR_OUT_OF_SCOPE
            else -- token IS NOT provided (guest access)
                return nil, ERROR_UNAUTHORIZED
            end
        else -- scope check itself failed, unknown method (scopeCheck == nil)
            return nil, ERROR_UNALLOWED
        end
    end

    if not providedToken then
        print("Verified request ", request:getMethod(), "token", request:getToken(), "from peer", request:getPeer())
        return request:getPeer()
    end

    if not providedToken:checkOwner(request:getPeer() --[[@as integer]]) then
        return nil, ERROR_CONFLICT
    end

    print("Verified request ", request:getMethod(), "token", request:getToken(), "from peer", request:getPeer())

    return request:setClientID(providedToken:getClientID())
end

---Process received request
---@param received_request KosmoRequest
function KosmoServer:handleRequest(received_request)
    self.api.v[received_request:getVersion()][received_request:getMethod()](self, received_request)
end

-- server fnc

function server.new(serverAddress, api_name, name)
    local obj = setmetatable({}, KosmoServer_meta)

    obj.started = false

    obj.hostObject = host.new()
    obj.hostObject.parent = obj
    obj.hostObject.onDisconnect = host_disconnect
    obj.hostObject.onServerDisconnect = host_disconnect_server

    obj.serverAddress = serverAddress

    obj.tokens = token.newCollection()
    obj.api = api.new(KOSMO_DEBUG and ("server/api/" .. api_name) or ("api/" .. api_name))

    obj.name = name or "KosmoServer"

    return obj
end

-- Allow inheritance
server.class = KosmoServer

return server