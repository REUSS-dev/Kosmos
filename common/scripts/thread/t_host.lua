-- kosmos host thread

-- init

---@type string, string
local bind_address, commandChannelName, eventChannelName = ...

local enet = require("enet")

local command, event = love.thread.getChannel(commandChannelName), love.thread.getChannel(eventChannelName)

local host = enet.host_create(bind_address)

if not host then
    event:push{"error", 0, string.format("Cannot create host on address " .. bind_address)}
end

event:push{"response", 0}

-- commands processing
local commands = {
    getAddress = function(rid)
        event:push{"response", rid, host:get_socket_address()}
    end,
    connect = function (rid, args)
        local address, data = args[1], args[2]
        host:connect(address, nil, data)

        event:push{"response", rid, true}
    end,
    disconnect = function (rid, args)
        local cid, data = args[1], args[2]
        host:get_peer(cid):disconnect(data)

        event:push{"response", rid, true}
    end,
    getRoundTripTime = function (rid, args)
        local cid = args[1]

        local response

        if type(cid) == "number" then
            local peer = host:get_peer(cid)

            if not peer then
                event:push{"error", rid, "No peer with such id: " .. cid}
            end

            response = peer:round_trip_time()
        elseif type(cid) == "table" then
            response = {}

            for i, peerI in ipairs(cid) do
                local peer = host:get_peer(peerI)

                if not peer then
                    event:push{"error", rid, "No peer with such id: " .. cid}
                end

                response[i] = peer:round_trip_time()
            end
        else
            event:push{"error", rid, "Invalid peer id provided: " .. tostring(cid)}
        end
        
        event:push{"response", rid, {cid, response}}
    end
}
-- COMMAND SCRIPT STARTS HERE %s

-- events processing
local function connect(connectEvent)
    event:push{"connect", connectEvent.peer:index(), tostring(connectEvent.peer), connectEvent.data}
end

local function disconnect(disconnectEvent)
    event:push{"disconnect", disconnectEvent.peer:index(), tostring(disconnectEvent.peer), disconnectEvent.data}
end

local function receive(receiveEvent)
    event:push{"receive", receiveEvent.peer:index(), tostring(receiveEvent.data)}
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