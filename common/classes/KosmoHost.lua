-- thost
local thost = {}

-- documentation

---@alias HostInfoTable {address: string, connections: {[HostPeerIndex]: HostConnectionInfo}, peerIndices: {[integer]: HostPeerIndex}, _peerIndices: table<HostPeerIndex, integer>}
---@alias HostConnectionInfo {[1]: string, [2]: integer, [3]: integer} 1 - IP:Port, 2 - connection data, 3 - round trip time

---@alias HostPeerIndex number
---@alias HostEvent {[1]: HostEventType, [2]: HostPeerIndex, [3]: string}

---@alias HostCommandName string
---@alias HostCommandPrototype {delay: number, timeout: number, callback: QueuedCommandCallback}

---@alias QueuedCommandID integer
---@alias QueuedCommandCallback fun(self: KosmoHost, response: any)

-- config



-- consts

---@enum HostEventType
local HostEventType = {
    RESPONSE = "response",
    ERROR = "error",
    CONNECT = "connect",
    RECEIVE = "receive",
    DISCONNECT = "disconnect"
}

local CHANNEL_COMMAND_PREFIX = "KosmohostDo%d"
local CHANNEL_EVENT_PREFIX = "KosmohostStatus%d"

local HOST_CREATE_TIMEOUT = 3
local COMMAND_DEFAULT_TIMEOUT = 10
local DUMMY_ROUND_TRIP = 500

local HOST_THREAD_FILE = "scripts/thread/t_host.lua"

-- vars

local uniqueCounter = 0

local thread_code

local commands

---@enum KosmoHostError
local Error = {
    HOST_TIMEOUT = "Creating host on address %s timeout. Try binding another address.",
    HOST_FAILED = "Error creating host: %s",
    UNKNOWN_COMMAND = "Command %s is not recognized by this host."
}

-- init

thread_code = love.filesystem.read(HOST_THREAD_FILE) --[[@as string]]

-- fnc

commands = {
    getAddress = {
        delay = 10,
        callback = function(self, address)
            self.hostInfo.address = address
        end
    },
    connect = {
        delay = 0,
        timeout = 5,
        callback = function()end
    },
    disconnect = {
        delay = 0,
        timeout = 5,
        callback = function()end
    },
    getRoundTripTime = {
        delay = 1,
        callback = function (self, roundTripInfo)
            local peer, time = roundTripInfo[1], roundTripInfo[2]
            if type(peer) == "number" then
                self.hostInfo.connections[peer][3] = time
            else
                for i, peerI in ipairs(peer) do
                    self.hostInfo.connections[peerI][3] = time[i]
                end
            end
        end
    }
}

-- classes

---@class KosmoHost
---@field public parent table? Optional parenting object set directly. Useful to address via self.parent when setting custom methods
---@field hostInfo HostInfoTable
---@field threadCode string
---@field thread love.Thread
---@field commandChannelName string
---@field eventChannelName string
---@field commandChannel love.Channel
---@field eventChannel love.Channel
---@field commands {[HostCommandName]: HostCommandPrototype} Host command set
---@field commandUnique QueuedCommandID Next issued command ID
---@field commandsQueued {[QueuedCommandID]: {timeout: number, callback: QueuedCommandCallback}}
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
    for commandName, delay in pairs(self.commandsDelay) do
        self.commandsDelay[commandName] = delay - dt

        if self.commandsDelay[commandName] <= 0 then
            self.commandsDelay[commandName] = nil
        end
    end
    
    --- fetch events
    ---@type HostEvent
    local newEvent = self.eventChannel:pop()
    while newEvent do
        if newEvent[1] == HostEventType.RESPONSE then
            if self.commandsQueued[newEvent[2]] then
                self.commandsQueued[newEvent[2]].callback(self, newEvent[3])
                self.commandsQueued[newEvent[2]] = nil
            end
        elseif newEvent[1] == HostEventType.RECEIVE then
            self:onReceive(newEvent[2], newEvent[3])
        elseif newEvent[1] == HostEventType.CONNECT then
            self.hostInfo.peerIndices[#self.hostInfo.peerIndices+1] = newEvent[2]
            self.hostInfo._peerIndices[newEvent[2]] = #self.hostInfo.peerIndices
            self.hostInfo.connections[newEvent[2]] = {newEvent[3], newEvent[4], DUMMY_ROUND_TRIP}

            self:command("getRoundTripTime", newEvent[2])
            self:onConnect(newEvent[2], newEvent[3], newEvent[4])
        elseif newEvent[1] == HostEventType.DISCONNECT then
            self.hostInfo.connections[newEvent[2]] = nil
            table.remove(self.hostInfo.peerIndices, self.hostInfo._peerIndices[newEvent[2]])
            self.hostInfo._peerIndices[newEvent[2]] = nil

            self:onDisconnect(newEvent[2], newEvent[3], newEvent[4])
        elseif newEvent[1] == HostEventType.ERROR then
            if self.commandsQueued[newEvent[2]] then
                print("Command", newEvent[2], "error", newEvent[3])
                self.commandsQueued[newEvent[2]] = nil
            end
        end

        newEvent = self.eventChannel:pop()
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
---@return boolean dispatched True if command has been dispatched successfuly, false if not (e.g. due to delay)
---@return string? error Possible error
---@protected
function KosmoHost:dispatchCommand(commandName, callback, ...)
    local command = self.commands[commandName]

    if not command then
        return false, Error.UNKNOWN_COMMAND:format(commandName)
    end

    if command.delay > 0 then
        if self.commandsDelay[commandName] then
            return false
        else
            self.commandsDelay[commandName] = command.delay
        end
    end

    local commandId = self.commandUnique

    self.commandsQueued[commandId] = {timeout = command.timeout or COMMAND_DEFAULT_TIMEOUT, callback = callback or command.callback}

    self.commandChannel:push({commandName, commandId, {...}})

    self.commandUnique = self.commandUnique + 1

    return true
end

---Issue a command to a host thread
---@param commandName HostCommandName Name of the command to be issued
---@param ... any Parameters passed to the host thread together with command
---@return boolean success True if command has been dispatched successfuly, false if not (e.g. due to delay)
---@public
function KosmoHost:command(commandName, ...)
    return self:dispatchCommand(commandName, nil, ...)
end

---Issue a command to a host thread with self-provided callback
---@param commandName HostCommandName Name of the command to be issued
---@param callback fun(self, ...) Callback that catches the command result
---@param ... any Parameters passed to the host thread together with command
---@return boolean success True if command has been dispatched successfuly, false if not (e.g. due to delay)
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

--#region virtuals

---Virtual function, triggers on new peer connected to the host
---@param peerIndex integer
---@param peerAddress string
---@param data integer
---@diagnostic disable-next-line: unused-local
function KosmoHost:onConnect(peerIndex, peerAddress, data)
    print("Connected new peer", peerIndex, "address", peerAddress, "data", data)
end

---Virtual function, triggers on new peer disconnected from the host
---@param peerIndex integer
---@param peerAddress string
---@param data integer
---@diagnostic disable-next-line: unused-local
function KosmoHost:onDisconnect(peerIndex, peerAddress, data)
    print("Disconnected peer", peerIndex, "address", peerAddress, "data", data)
end

---Virtual function, triggers on data received from the peer
---@param peerIndex integer
---@param data string
---@diagnostic disable-next-line: unused-local
function KosmoHost:onReceive(peerIndex, data)
    print("Received data from peer", peerIndex, "data", data)
end

--#endregion

-- thosst fnc

function thost.new(customCommands, threadCommandsScriptString, threadEventScriptString)
    local obj = setmetatable({
        unique = uniqueCounter,
        hostInfo = {
            connections = {},
            peerIndices = {},
            _peerIndices = {}
        },

        commandUnique = 0,
        commandsDelay = {},
        commandsQueued = {}
    }, KosmoHost_meta)

    obj.commands = setmetatable(customCommands or {}, {__index = commands})

    -- Initialize KosmoHost channels
    obj.commandChannelName = CHANNEL_COMMAND_PREFIX:format(uniqueCounter)
    obj.eventChannelName = CHANNEL_EVENT_PREFIX:format(uniqueCounter)

    obj.commandChannel = love.thread.getChannel(obj.commandChannelName)
    obj.eventChannel = love.thread.getChannel(obj.eventChannelName)

    -- Create thread (does not start the thread)
    obj.thread = love.thread.newThread(obj.threadCode:format("\n" .. (threadCommandsScriptString or ""), "\n" .. (threadEventScriptString or "")))

    uniqueCounter = uniqueCounter + 1

    return obj
end

thost.err = Error

return thost