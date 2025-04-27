-- thost
local thost = {}

local request = require("classes.KosmoRequest")

local commands = require("scripts.hostCommands_master")

-- documentation

---@alias HostPeerIndex number
---@alias HostAddress string

---@alias IHost_enabled_validate fun(received_request: KosmoRequest): string?, ApiError?
---@alias IHost_enabled_handle fun(received_request: KosmoRequest)
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
---@alias HostEventReceive {[1]: HostEventType.RECEIVE, [2]: HostPeerIndex, [3]: HostAddress, [4]: string}
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
local COMMAND_DEFAULT_TIMEOUT = 10
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
---@field commandUnique QueuedCommandID Next issued command ID
---@field commandsQueued {[QueuedCommandID]: HostQueuedCommand}
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

function KosmoHost:update(dt)
    --- tick delay
    for command_name, delay in pairs(self.commandsDelay) do
        self.commandsDelay[command_name] = delay - dt

        if self.commandsDelay[command_name] <= 0 then
            self.commandsDelay[command_name] = nil
        end
    end

    --- fetch events
    local new_event = self.eventChannel:pop()

    while new_event do
        -- Process command response event
        if new_event[1] == HostEventType.RESPONSE then   ---@cast new_event HostEventResponse
            local command = self.commandsQueued[new_event[2]]

            if command then
                command.callback(self, new_event[3], command)
                self.commandsQueued[new_event[2]] = nil
            end

        -- Process data receive event
        elseif new_event[1] == HostEventType.RECEIVE then    ---@cast new_event HostEventReceive
            local peer = new_event[2]
            local received_request = request.parse(new_event[4])

            if received_request then -- kosmorequest parsing success
                -- Assign peer
                received_request:setPeer(peer)

                -- Check token and request validity
                local verified, err = self.parent.validate(received_request)

                if verified then -- valid token
                    self.parent.handleRequest(received_request)

                else -- invalid token
                    ---@cast err ApiError
                    local errorObj = {
                        message = err.message,
                        code = err.code,
                        method = received_request:getMethod(),
                        params = received_request:getParams()
                    }

                    local errorResponse = request.newError(errorObj, received_request:getToken(), received_request:getUid())

                    self:command("send", peer, errorResponse)
                end
            else -- Non-kosmorequest
                self:onReceive(peer, new_event[3])
            end

        -- Process connect event
        elseif new_event[1] == HostEventType.CONNECT then    ---@cast new_event HostEventConnect
            self.hostInfo.peerIndices[#self.hostInfo.peerIndices+1] = new_event[2]
            self.hostInfo.connections[new_event[2]] = {new_event[3], new_event[4], DUMMY_ROUND_TRIP}

            self:command("getRoundTripTime", new_event[2])

            self:onConnect(new_event[2], new_event[3], new_event[4])

        -- Process disconnect event
        elseif new_event[1] == HostEventType.DISCONNECT then ---@cast new_event HostEventDisconnect
            for i = #self.hostInfo.peerIndices, 1, -1 do
                if self.hostInfo.peerIndices[i] == new_event[2] then
                    table.remove(self.hostInfo.peerIndices, i)
                end
            end

            self:onDisconnect(new_event[2], new_event[3], new_event[4])
            self.hostInfo.connections[new_event[2]] = nil

        -- Process server connect event
        elseif new_event[1] == HostEventType.AUTO_CONNECT then   ---@cast new_event HostEventAutoConnect
            local name, peer = new_event[2], new_event[3]

            self.servers[name].peer = peer
            self:onServerConnect(name, peer)

        -- Process server disconnect event
        elseif new_event[1] == HostEventType.AUTO_DISCONNECT then   ---@cast new_event HostEventAutoDisconnect
            local name, peer = new_event[2], new_event[3]

            self:onServerDisconnect(name, peer)
            self.servers[name].peer = nil

        -- Process command error event
        elseif new_event[1] == HostEventType.ERROR then  ---@cast new_event HostEventError
            if self.commandsQueued[new_event[2]] then
                print("Command", new_event[2], "error", new_event[3])
                self.commandsQueued[new_event[2]] = nil
            end
        end

        new_event = self.eventChannel:pop()

    end

    --- tick timeouts
    for commandId, queuedCommand in pairs(self.commandsQueued) do
        queuedCommand.timeout = queuedCommand.timeout - dt

        if queuedCommand.timeout <= 0 then
            self.commandsQueued[commandId] = nil
            print("Command", commandId, "timeout")
        end
    end
end

---Dispatch command to the thread
---@param commandName HostCommandName Name of the command to be dispatched
---@param callback fun(self, ...)? Callback that catches the command result
---@param ... any Parameters passed to the host thread together with command
---@return HostCommandReturnIndex? dispatched Return id if command has been dispatched successfuly, nil if not (e.g. due to delay)
---@return string? error Possible error
---@protected
function KosmoHost:dispatchCommand(commandName, callback, ...)
    local command = self.commands[commandName]

    if not command then
        return nil, Error.UNKNOWN_COMMAND:format(commandName)
    end

    if command.delay > 0 then
        if self.commandsDelay[commandName] then
            return nil
        else
            self.commandsDelay[commandName] = command.delay
        end
    end

    local commandId = self.commandUnique
    local args = {...}

    self.commandsQueued[commandId] = {command = commandName, args = args, timeout = command.timeout or COMMAND_DEFAULT_TIMEOUT, callback = callback or command.callback}

    self.commandChannel:push({commandName, commandId, args})

    self.commandUnique = self.commandUnique + 1

    return commandId
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

-- thost fnc

function thost.new()
    local obj = setmetatable({
        unique = uniqueCounter,
        hostInfo = {
            connections = {},
            peerIndices = {}
        },
        servers = {},

        commandUnique = 0,
        commandsDelay = {},
        commandsQueued = {}
    }, KosmoHost_meta)

    obj.commands = commands

    -- Initialize KosmoHost channels
    obj.commandChannelName = CHANNEL_COMMAND_PREFIX:format(uniqueCounter)
    obj.eventChannelName = CHANNEL_EVENT_PREFIX:format(uniqueCounter)

    obj.commandChannel = love.thread.getChannel(obj.commandChannelName)
    obj.eventChannel = love.thread.getChannel(obj.eventChannelName)

    -- Create thread (does not start the thread)
    obj.thread = love.thread.newThread(obj.threadCode)

    uniqueCounter = uniqueCounter + 1

    return obj
end

thost.err = Error

return thost