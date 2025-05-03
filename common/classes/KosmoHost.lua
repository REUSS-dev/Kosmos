-- thost
local thost = {}

local request = require("classes.KosmoRequest")
local async = require("scripts.kosmonaut")

local commands = require("scripts.hostCommands_master")

-- documentation

---@alias HostPeerIndex number
---@alias HostAddress string

---@alias IHost_enabled_validate fun(self: IHost_enabled, received_request: KosmoRequest): string?, ApiError?
---@alias IHost_enabled_handle fun(self: IHost_enabled, received_request: KosmoRequest)
---@alias IHost_enabled {handleRequest: IHost_enabled_handle, [any]: any, validate: IHost_enabled_validate}
---@alias ApiError {code: integer, message: string}

---@alias HostInfoTable {address: HostServer, connections: {[HostPeerIndex]: HostConnectionInfo}, peerIndices: {[integer]: HostPeerIndex}}
---@alias HostConnectionInfo {[1]: string, [2]: integer, [3]: integer} 1 - IP:Port, 2 - connection data, 3 - round trip time
---@alias HostServer {address: string, peer: HostPeerIndex}

---@alias HostEventConnect {[1]: HostEventType.CONNECT, [2]: HostPeerIndex, [3]: HostAddress, [4]: integer}
---@alias HostEventDisconnect {[1]: HostEventType.DISCONNECT, [2]: HostPeerIndex, [3]: HostAddress, [4]: integer}
---@alias HostEventAutoConnect {[1]: HostEventType.AUTO_CONNECT, [2]: string, [3]: HostPeerIndex}
---@alias HostEventAutoDisconnect {[1]: HostEventType.AUTO_DISCONNECT, [2]: string, [3]: HostPeerIndex}
---@alias HostEventResponse {[1]: HostEventType.RESPONSE, [2]: HostCommandReturnIndex, [3]: any}
---@alias HostEventReceive {[1]: HostEventType.RECEIVE, [2]: HostPeerIndex, [3]: string}
---@alias HostEventError {[1]: HostEventType.ERROR, [2]: HostCommandReturnIndex, [3]: string}

---@alias HostCommandName string
---@alias HostCommandReturnIndex integer
---@alias HostCommandPrototype {delay: number, timeout: number, callback: QueuedCommandCallback}
---@alias HostQueuedCommand {name: HostCommandName, args: any, timeout: number, callback: QueuedCommandCallback}}

---@alias QueuedCommandID integer
---@alias QueuedCommandCallback fun(self: KosmoHost, response: any, command_object: HostQueuedCommand)

-- config



-- consts

---@enum HostEventType
local HostEventType = {
    RESPONSE = "response",
    RECEIVE = "receive",
    ERROR = "error",
    CONNECT = "connect",
    DISCONNECT = "disconnect",
    AUTO_CONNECT = "autoconnect",
    AUTO_DISCONNECT = "autodisconnect"
}

local CHANNEL_COMMAND_PREFIX = "KosmohostDo%d"
local CHANNEL_EVENT_PREFIX = "KosmohostStatus%d"

local HOST_CREATE_TIMEOUT = 3
local COMMAND_DEFAULT_TIMEOUT = 5
local DUMMY_ROUND_TRIP = 500

local HOST_COMMAND_RESOLVER_FILE = "scripts/hostCommands_slave.lua"
local HOST_THREAD_FILE = "scripts/thread/t_host.lua"

local COMMAND_RESOLVER_PARSE_PATTERN = "%-%-%[%[ SLAVE SCRIPT BEG ]](.*)$"

-- vars

local uniqueCounter = 0

local thread_code

---@enum KosmoHostError
local Error = {
    HOST_TIMEOUT = "Creating host on address %s timeout. Try binding another address.",
    HOST_FAILED = "Error creating host: %s",
    UNKNOWN_COMMAND = "Command %s is not recognized by this host."
}

-- init

--- produce thread code
thread_code = love.filesystem.read(HOST_THREAD_FILE) --[[@as string]]

local command_resolver_file = love.filesystem.read(HOST_COMMAND_RESOLVER_FILE) --[[@as string]]
local command_resolvers = command_resolver_file:match(COMMAND_RESOLVER_PARSE_PATTERN)

thread_code = thread_code:format(command_resolvers)

-- fnc



-- classes

---@class KosmoHost
---@field public parent IHost_enabled Optional parenting object set directly. Useful to address via self.parent when setting custom methods
---@field hostInfo HostInfoTable
---@field threadCode string
---@field thread love.Thread
---@field commandChannelName string
---@field eventChannelName string
---@field commandChannel love.Channel
---@field eventChannel love.Channel
---@field servers table<string, HostServer> List of server hosts which KosmoHost will constantly try to auto-reconnect to.
---@field commands {[HostCommandName]: HostCommandPrototype} Host command set
---@field commandQueue AsyncAgent Async agent for commands to the child thread
---@field commandsDelay {[HostCommandName]: number}
local KosmoHost = { threadCode = thread_code}
local KosmoHost_meta = { __index = KosmoHost }

---Start host thread with given bind address in format <ip:port>
---@param bind_address string
---@return true?
---@return string?
function KosmoHost:start(bind_address)
    self.thread:start(bind_address, self.commandChannelName, self.eventChannelName)

    local response = self.eventChannel:demand(HOST_CREATE_TIMEOUT)

    if not response then
        return nil, Error.HOST_TIMEOUT:format(bind_address)
    end

    if response[1] == HostEventType.ERROR then
        return nil, Error.HOST_FAILED:format(response[3])
    end

    self:command("getAddress")

    return true
end

--#region Host update

function KosmoHost:update(dt)
    --- tick delay
    self:tickCommandDelay(dt)

    --- fetch events
    self:processEvents()

    --- tick async agent
    self.commandQueue:update(dt)
end

---Tick command cooldowns/delays with given delta time
---@param dt number
---@private
function KosmoHost:tickCommandDelay(dt)
    for command_name, delay in pairs(self.commandsDelay) do
        self.commandsDelay[command_name] = delay - dt

        if self.commandsDelay[command_name] <= 0 then
            self.commandsDelay[command_name] = nil
        end
    end
end

---Process events pulled from event channel of this host
---@protected
function KosmoHost:processEvents()
    local new_event = self.eventChannel:pop()

    while new_event do
        local event_type = new_event[1]

        if event_type == HostEventType.RESPONSE then
            self:processEventResponse(new_event)

        elseif event_type == HostEventType.RECEIVE then
            self:processEventReceive(new_event)

        elseif event_type == HostEventType.CONNECT then
            self:processEventConnect(new_event)

        elseif event_type == HostEventType.DISCONNECT then
            self:processEventDisconnect(new_event)

        elseif event_type == HostEventType.AUTO_CONNECT then
            self:processEventAutoConnect(new_event)

        elseif event_type == HostEventType.AUTO_DISCONNECT then
            self:processEventAutoDisconnect(new_event)

        elseif event_type == HostEventType.ERROR then
            self:processEventError(new_event)
        end

        new_event = self.eventChannel:pop()
    end
end

--#region Event processors

---Process event typed RESPONSE
---@param event HostEventResponse
---@protected
function KosmoHost:processEventResponse(event)
    local return_index, result = event[2], event[3]

    self.commandQueue:finishTask(return_index, result)
end

---Process event typed ERROR
---@param event HostEventError
---@protected
function KosmoHost:processEventError(event)
    local return_index, errmsg = event[2], event[3]

    self.commandQueue:finishTask(return_index, nil, errmsg)
end

---Process event typed CONNECT
---@param event HostEventConnect
---@protected
function KosmoHost:processEventConnect(event)
    local peer_index, peer_address, hello_int = event[2], event[3], event[4]

    self.hostInfo.peerIndices[#self.hostInfo.peerIndices+1] = peer_index
    self.hostInfo.connections[peer_index] = {peer_address, hello_int, DUMMY_ROUND_TRIP}

    self:command("getRoundTripTime", peer_index)

    self:onConnect(peer_index, peer_address, hello_int)
end

---Process event typed DISCONNECT
---@param event HostEventDisconnect
---@protected
function KosmoHost:processEventDisconnect(event)
    local peer_index, peer_address, goodbye_int = event[2], event[3], event[4]

    for i = #self.hostInfo.peerIndices, 1, -1 do
        if self.hostInfo.peerIndices[i] == peer_index then
            table.remove(self.hostInfo.peerIndices, i)
        end
    end

    self:onDisconnect(peer_index, peer_address, goodbye_int)
    self.hostInfo.connections[peer_index] = nil
end

---Process event typed AUTO_CONNECT
---@param event HostEventAutoConnect
---@protected
function KosmoHost:processEventAutoConnect(event)
    local name, peer = event[2], event[3]

    self.servers[name].peer = peer
    self:onServerConnect(name, peer)
end

---Process event typed AUTO_DISCONNECT
---@param event HostEventAutoDisconnect
---@protected
function KosmoHost:processEventAutoDisconnect(event)
    local name, peer = event[2], event[3]

    self:onServerDisconnect(name, peer)
    self.servers[name].peer = nil
end

---Process event typed RECEIVE
---@param event HostEventReceive
---@protected
function KosmoHost:processEventReceive(event)
    local peer, data = event[2], event[3]

    local received_request = request.parse(data)

    if received_request then -- kosmorequest parsing success
        -- Assign peer
        received_request:setPeer(peer)

        -- Check token and request validity
        local verified, err = self.parent:validate(received_request)

        if verified then -- valid token
            self.parent:handleRequest(received_request)

        else -- invalid token
            local errorResponse = received_request:createError(err)

            self:command("send", peer, errorResponse:getPayload())
        end
    else -- Non-kosmorequest
        self:onReceive(peer, data)
    end
end

--#endregion Event processors

--#endregion Host update

--#region Command dispatcher

---Dispatch command to the thread
---@param commandName HostCommandName Name of the command to be dispatched
---@param callback AsyncCallback? Callback that catches the command result
---@param ... any Parameters passed to the host thread together with command
---@return HostCommandReturnIndex? dispatched Return id if command has been dispatched successfuly, nil if not (e.g. due to delay)
---@return string? error Possible error
---@protected
function KosmoHost:dispatchCommand(commandName, callback, ...)
    local task = {self = self, command = commandName, params = {...}}

    local command = self.commands[commandName]

    if not command then -- unknown command
        local fail_callback = callback or self.receiveCommand
        fail_callback(task, nil, Error.UNKNOWN_COMMAND:format(commandName))
        return
    end

    callback = callback or command.callback or self.receiveCommand

    if command.delay > 0 then -- if command has delay
        if self.commandsDelay[commandName] then -- command is currently on cooldown
            return nil
        else -- no cooldown for the command
            self.commandsDelay[commandName] = command.delay
        end
    end

    local task_id = self.commandQueue:queueTask(task, callback)

    self.commandChannel:push({commandName, task_id, task.params})

    return task_id
end

---Issue a command to a host thread
---@param commandName HostCommandName Name of the command to be issued
---@param ... any Parameters passed to the host thread together with command
---@return HostCommandReturnIndex? dispatched Return id if command has been dispatched successfuly, nil if not (e.g. due to delay)
---@return string? error Possible error
---@public
function KosmoHost:command(commandName, ...)
    return self:dispatchCommand(commandName, nil, ...)
end

---Issue a command to a host thread with self-provided callback
---@param commandName HostCommandName Name of the command to be issued
---@param callback fun(self, ...) Callback that catches the command result
---@param ... any Parameters passed to the host thread together with command
---@return HostCommandReturnIndex? dispatched Return id if command has been dispatched successfuly, nil if not (e.g. due to delay)
---@return string? error Possible error
---@public
function KosmoHost:commandCallback(commandName, callback, ...)
    return self:dispatchCommand(commandName, callback, ...)
end

---@private
function KosmoHost.receiveCommand(task, result, err)
    if result then
        return
    end

    print("Failed to execute command " .. tostring(task.command) .. " on host " .. tostring(task.self:getAddress()) .. ". Error: " .. (err or "command timeout"))
end

--#endregion Command dispatcher

function KosmoHost:getAddress()
    return self.hostInfo.address
end

function KosmoHost:getPeers()
    return self.hostInfo.peerIndices
end

function KosmoHost:getPeerInfo(peerIndex)
    return self.hostInfo.connections[peerIndex]
end

---Gets associated peer's round trip time
---@param peerIndex HostPeerIndex
---@return integer?
function KosmoHost:getRoundTrip(peerIndex)
    if not self.hostInfo.connections[peerIndex] then
        return
    end

    self:command("getRoundTripTime", peerIndex)
    return self.hostInfo.connections[peerIndex][3]
end

function KosmoHost:updateRoundTrip(peerIndexList)
    return self:command("getRoundTripTime", peerIndexList)
end

--#region Servers management

---Add a server to the list of host's servers. Host will automatically keep connections to its servers
---@param name string
---@param address HostAddress
function KosmoHost:addServer(name, address)
    self.servers[name] = {address = address}

    self:command("connectServer", address, name)
end

---Get whether server is currently connected
---@return boolean? state nil, if no such server defined, false if server is not currently connected, true if server is connected
function KosmoHost:getServerStatus(name)
    if not self.servers[name] then
        return nil
    end

    return self.servers[name].peer and true or false
end

---Remove a server from the list of host's servers.
---@param name string
function KosmoHost:removeServer(name)
    self:command("disconnectServer", self.servers[name].address, self.servers[name].peer)

    self.servers[name] = nil
end

--#endregion Servers management

--#region virtuals

---Virtual function, triggers on new peer connected to the host
---@param peerIndex HostPeerIndex
---@param peerAddress HostAddress
---@param data integer
---@diagnostic disable-next-line: unused-local
function KosmoHost:onConnect(peerIndex, peerAddress, data)
    print("Connected new peer", peerIndex, "address", peerAddress, "data", data)
end

---Virtual function, triggers on new peer disconnected from the host
---@param peerIndex HostPeerIndex
---@param peerAddress HostAddress
---@param data integer
---@diagnostic disable-next-line: unused-local
function KosmoHost:onDisconnect(peerIndex, peerAddress, data)
    print("Disconnected peer", peerIndex, "address", peerAddress, "data", data)
end

---Virtual function, triggers on server connection estabilished
---@param serverName string
---@param serverIndex HostPeerIndex
---@diagnostic disable-next-line: unused-local
function KosmoHost:onServerConnect(serverName, serverIndex)
    print("Connected server", serverName, "peer", serverIndex)
end

---Virtual function, triggers on server connection lost
---@param serverName string
---@param serverIndex HostPeerIndex
---@diagnostic disable-next-line: unused-local
function KosmoHost:onServerDisconnect(serverName, serverIndex)
    print("Lost connection to server", serverName, serverIndex)
end

---Virtual function, triggers on data received from the peer
---@param peerIndex HostPeerIndex
---@param data string
---@diagnostic disable-next-line: unused-local
function KosmoHost:onReceive(peerIndex, data)
    print("Received data from peer", peerIndex, "data", data)
end

--#endregion

--#region Init

---Assigns and creates channels for the KosmoHost
---@package
function KosmoHost:initializeChannels()
    self.commandChannelName = CHANNEL_COMMAND_PREFIX:format(uniqueCounter)
    self.eventChannelName = CHANNEL_EVENT_PREFIX:format(uniqueCounter)

    self.commandChannel = love.thread.getChannel(self.commandChannelName)
    self.eventChannel = love.thread.getChannel(self.eventChannelName)
end

--#endregion

-- thost fnc

function thost.new()
    local obj = setmetatable({
        hostInfo = {
            connections = {},
            peerIndices = {}
        },
        servers = {},

        commandQueue = async.new(COMMAND_DEFAULT_TIMEOUT),
        commandsDelay = {}
    }, KosmoHost_meta)

    obj.commands = commands

    -- Initialize KosmoHost channels
    obj:initializeChannels()

    -- Create thread (does not start the thread)
    obj.thread = love.thread.newThread(obj.threadCode)

    uniqueCounter = uniqueCounter + 1

    return obj
end

thost.err = Error

return thost