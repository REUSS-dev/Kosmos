-- kosmos host thread

local HostEventType = {
    RESPONSE = "response",
    RECEIVE = "receive",
    ERROR = "error",
    CONNECT = "connect",
    DISCONNECT = "disconnect",
    AUTO_CONNECT = "autoconnect",
    AUTO_DISCONNECT = "autodisconnect"
}

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

-- commands processing
local auto_reconnect = {}

local commands = {
    getAddress = function(rid)
        event:push{HostEventType.RESPONSE, rid, host:get_socket_address()}
    end,

    connect = function (rid, args)
        local address, data = args[1], args[2]
        host:connect(address, nil, data)

        event:push{HostEventType.RESPONSE, rid, true}
    end,

    connectServer = function (rid, args)
        local address, name = args[1], args[2]
        auto_reconnect[address] = name
        
        host:connect(address)
        
        event:push{HostEventType.RESPONSE, rid, true}
    end,

    disconnect = function (rid, args)
        local cid, data = args[1], args[2]
        host:get_peer(cid):disconnect(data)

        event:push{HostEventType.RESPONSE, rid, true}
    end,

    disconnectServer = function (rid, args)
        local address, cid = args[1], args[2]
        auto_reconnect[address] = false
        host:get_peer(cid):disconnect()

        event:push{HostEventType.RESPONSE, rid, true}
    end,

    getRoundTripTime = function (rid, args)
        local cid = args[1]

        local response

        if type(cid) == "number" then
            local peer = host:get_peer(cid)

            if not peer then
                event:push{HostEventType.ERROR, rid, "No peer with such id: " .. cid}
            end

            response = peer:round_trip_time()
        elseif type(cid) == "table" then
            response = {}

            for i, peerI in ipairs(cid) do
                local peer = host:get_peer(peerI)

                if not peer then
                    event:push{HostEventType.ERROR, rid, "No peer with such id: " .. cid}
                end

                response[i] = peer:round_trip_time()
            end
        else
            event:push{HostEventType.ERROR, rid, "Invalid peer id provided: " .. tostring(cid)}
        end
        
        event:push{HostEventType.RESPONSE, rid, {cid, response}}
    end
}
-- COMMAND SCRIPT STARTS HERE %s

-- events processing
local function connect(connectEvent)
    event:push{HostEventType.CONNECT, connectEvent.peer:index(), tostring(connectEvent.peer), connectEvent.data}
end

local function disconnect(disconnectEvent)
    event:push{HostEventType.DISCONNECT, disconnectEvent.peer:index(), tostring(disconnectEvent.peer), disconnectEvent.data}
end

local function receive(receiveEvent)
    event:push{HostEventType.RECEIVE, receiveEvent.peer:index(), tostring(receiveEvent.data)}
end

-- CUSTOM EVENT PROCESSING SCRIPT STARTS HERE %s

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