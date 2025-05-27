-- socket
local socket = {}

local api = require("classes.KosmoApi")
local host = require("classes.KosmoHost")
local token = require("classes.KosmoToken")

local async = require("scripts.kosmonaut")

-- documentation



-- config

local REQUEST_TIMEOUT = 10
local REQUEST_MAX_SUBSEQUENT = 3
local REQUEST_SEND_PERIOD = 1.1

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

---@class KosmoSocket Realization of socket using KosmoHost
---@field name string Name socket introduces himself to a peer
---@field hostObject KosmoHost Associated KosmoHost object
---@field started boolean Is socket open
---@field tokens KosmoTokenCollection Token collection of a socket
---@field api KosmoApi API socket uses to handle requests
---@field socketAddress HostAddress Address of a socket
---@field sentRequests AsyncAgent Async agent for sent requests and capturing responses
---@field queuedRequestsUpdateTimer number Timer accumulator of request send queue
local KosmoSocket = {}
local KosmoSocket_meta = { __index = KosmoSocket }

function KosmoSocket:start(address)
    self.socketAddress = address or self.socketAddress

    if not self.socketAddress then
        error("Provide socket address to open socket")
    end

    self.hostObject:start(self.socketAddress)

    self.started = true
end

function KosmoSocket:update(dt)
    self.hostObject:update(dt)
    self.sentRequests:update(dt)

    self.queuedRequestsUpdateTimer = self.queuedRequestsUpdateTimer + dt
    if self.queuedRequestsUpdateTimer >= REQUEST_SEND_PERIOD then
        local request_to_send = self.sentRequests:popTask()

        while request_to_send do
            self.hostObject:command("send", request_to_send:getPeer(), request_to_send:getPayload())

            request_to_send = self.sentRequests:popTask()
        end

        self.queuedRequestsUpdateTimer = self.queuedRequestsUpdateTimer - REQUEST_SEND_PERIOD
    end
end

function KosmoSocket:getAddress()
    return self.hostObject:getAddress() or self.socketAddress
end

function KosmoSocket:setAddress(address)
    if not self.started then
        self.socketAddress = address
    end

    return self
end

function KosmoSocket:getName()
    return self.name
end

function KosmoSocket:setName(new_name)
    if not self.started then
        self.name = new_name
    end

    return self
end

function KosmoSocket:getPeers()
    return self.hostObject.hostInfo.peerIndices
end

function KosmoSocket:getPeerInfo(clientId)
    return self.hostObject.hostInfo.connections[clientId]
end

function KosmoSocket:pingPeers(clientList)
    return self.hostObject:updateRoundTrip(clientList)
end

---Queue dispatch of given request from socket
---@param request KosmoRequest
---@param callback AsyncCallback
---@param nickname AsyncNickname
function KosmoSocket:request(request, callback, nickname)
    local request_peer = request:getPeer()

    if not request_peer then
        error("No peer set for request " .. request:getMethod())
    end

    local async_id = self.sentRequests:queueTask(request, callback, nickname)
    request:setUid(async_id) -- Override default request UID to match AsyncTaskIdentifier to identify response

    return async_id
end

---Send a response to a peer of provided request
---@param request KosmoRequest
---@param params table<string, any>
function KosmoSocket:response(request, params)
    local response_request = request:createResponse(params)

    self.hostObject:command("send", request:getPeer(), response_request:getPayload())
end

---Send an error to a peer of provided request
---@param request KosmoRequest
---@param error_header {message: string, code: integer}
function KosmoSocket:responseError(request, error_header)
    local response_request = request:createError(error_header)

    self.hostObject:command("send", request:getPeer(), response_request:getPayload())
end

---Define token validation
---@param request KosmoRequest
function KosmoSocket:validate(request)
    local providedToken = self.tokens:find(request:getToken())

    -- Received response
    if request:isResponse() then
        local response_task_id = request:getUid()

        local original_request = self.sentRequests:getTask(response_task_id)

        -- Response to unknown request
        if not original_request then
            return nil
        end

        -- Peer of request does not match the peer of response
        if request:getPeer() ~= original_request:getPeer() then
            return nil
        end

        -- Token of request does not match the token of response
        if request:getToken() ~= original_request:getToken() then
            return nil
        end

        if providedToken then
            request:setClientID(providedToken:getClientID())
        end

        self.sentRequests:finishTask(response_task_id, request)

        return nil
    end

    -- Received request

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

    return request:setClientID(providedToken:getClientID())
end

---Process received request
---@param received_request KosmoRequest
function KosmoSocket:handleRequest(received_request)
    self.api.v[received_request:getVersion()][received_request:getMethod()](self, received_request)
end

-- socket fnc

function socket.new(serverAddress, api_name, name)
    local obj = setmetatable({}, KosmoSocket_meta)

    obj.started = false
    obj.queuedRequestsUpdateTimer = 0

    obj.hostObject = host.new()
    obj.hostObject.parent = obj
    obj.hostObject.onDisconnect = host_disconnect
    obj.hostObject.onServerDisconnect = host_disconnect_server

    obj.socketAddress = serverAddress

    obj.tokens = token.newCollection()
    obj.api = api.new(api_name)

    obj.sentRequests = async.new(obj, REQUEST_TIMEOUT, REQUEST_MAX_SUBSEQUENT)

    obj.name = name or "KosmoSocket"

    return obj
end

socket.class = KosmoSocket

return socket