-- kosmos host thread

-- consts

local HostEventType = {
    RESPONSE = "response",
    RECEIVE = "receive",
    ERROR = "error",
    CONNECT = "connect",
    DISCONNECT = "disconnect",
    AUTO_CONNECT = "autoconnect",
    AUTO_DISCONNECT = "autodisconnect"
}

-- vars

local auto_reconnect = {}
local commands = {}

-- init

---@type string, string, string
local bind_address, commandChannelName, eventChannelName = ...

local enet = require("enet")

local command, event = love.thread.getChannel(commandChannelName), love.thread.getChannel(eventChannelName)

local host = enet.host_create(bind_address)

if not host then
    event:push{HostEventType.ERROR, 0, string.format("Cannot create host on address " .. bind_address)}
end

event:push{HostEventType.RESPONSE, 0}

-- COMMANDS SCRIPT STARTS HERE %s


-- events processing
local function connect(connectEvent)
    event:push{HostEventType.CONNECT, connectEvent.peer:index(), tostring(connectEvent.peer), connectEvent.data}
end

local function disconnect(disconnectEvent)
    event:push{HostEventType.DISCONNECT, disconnectEvent.peer:index(), tostring(disconnectEvent.peer), disconnectEvent.data}
end

local function receive(receiveEvent)
    event:push{HostEventType.RECEIVE, receiveEvent.peer:index(), tostring(receiveEvent.peer), tostring(receiveEvent.data)}
end

-- update loop

while true do
    local newCommand = command:pop()
    while newCommand do
        local name, id, args = newCommand[1], newCommand[2], newCommand[3]

        if commands[name] then
            commands[name](id, args)
        else
            event:push{HostEventType.ERROR, id, "Command unrecognized by host thread"}
        end
        
        newCommand = command:pop()
    end

    -- Effective TPS of host is 30 (PLEASE DO NOT LEAVE THE PARAMETER OF host:service() BLANK, it SERIOUSLY affects CPU load)
    local newEvent = host:service(33)
    while newEvent do
        if newEvent.type == "connect" then
            if auto_reconnect[tostring(newEvent.peer)] then
                event:push{HostEventType.AUTO_CONNECT, auto_reconnect[tostring(newEvent.peer)], newEvent.peer:index()}
            else
                connect(newEvent)
            end
        elseif newEvent.type == "disconnect" then
            if auto_reconnect[tostring(newEvent.peer)] then
                event:push{HostEventType.AUTO_DISCONNECT, auto_reconnect[tostring(newEvent.peer)]}
                host:connect(tostring(newEvent.peer))
            else
                disconnect(newEvent)
            end
        elseif newEvent.type == "receive" then
            receive(newEvent)
        end
        
        newEvent = host:service(0)
    end
end