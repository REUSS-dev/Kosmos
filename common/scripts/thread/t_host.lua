-- kosmos host thread

-- init

---@type string, string
local bind_address, commandChannelName, eventChannelName = ...

local enet = require("enet")

local command, event = love.thread.getChannel(commandChannelName), love.thread.getChannel(eventChannelName)

local host = enet.host_create(bind_address)

if not host then
    event:push{"error", 0, string.format("Cannot create host on address %s", bind_address)}
end

event:push{"response", 0}

-- commands processing
local commands = {
    getAddress = function(rid)
        event:push{"response", rid, host:get_socket_address()}
    end,
    connect = function (rid, args)
        local address = args[1]
        host:connect(address)

        event:push{"response", rid, true}
    end,
    disconnect = function (rid, args)
        local cid = args[1]
        host:get_peer(cid):disconnect()

        event:push{"response", rid, true}
    end,
    getRoundTripTime = function (rid, args)
        local cid = args[1]
        
        local peer = host:get_peer(cid)

        if not peer then
            event:push{"error", rid, "No peer with such id: " .. cid}
        end

        event:push{"response", rid, {cid, peer:round_trip_time()}}
    end
}
--(PLEASE START COMMANDS SCRPIT WITH NEWLINE) %s

-- events processing
local function connect(connectEvent)
    event:push{"connect", connectEvent.peer:index(), tostring(connectEvent.peer)}
end

local function disconnect(disconnectEvent)
    event:push{"disconnect", disconnectEvent.peer:index(), tostring(disconnectEvent.peer)}
end

local function receive(receiveEvent)
    event:push{"receive", receiveEvent.peer:index(), tostring(receiveEvent.data)}
end

--(PLEASE START CUSTOM EVENTS PROCESSING SCRPIT WITH NEWLINE) %s

-- update loop

while true do
    local newCommand = command:pop()
    while newCommand do
        local name, id, args = newCommand[1], newCommand[2], newCommand[3]

        if commands[name] then
            commands[name](id, args)
        else
            event:push{"error", id, "Command unrecognized by host thread"}
        end
        
        newCommand = command:pop()
    end

    local newEvent = host:service(0)
    while newEvent do
        if newEvent.type == "connect" then
            connect(newEvent)
        elseif newEvent.type == "disconnect" then
            disconnect(newEvent)
        elseif newEvent.type =="receive" then
            receive(newEvent)
        end
        
        newEvent = host:service(0)
    end
end