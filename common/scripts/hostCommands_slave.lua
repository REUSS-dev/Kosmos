-- Context region. Code below is not functional nor reachable

---@diagnostic disable: unused-local

local HostEventType = {
    RESPONSE = "response",
    RECEIVE = "receive",
    ERROR = "error",
    CONNECT = "connect",
    DISCONNECT = "disconnect",
    AUTO_CONNECT = "autoconnect",
    AUTO_DISCONNECT = "autodisconnect"
}

---@type ENetHost
local host

---@type love.Channel, love.Channel
local command, event

local auto_reconnect = {}
local commands

-- Below is a mandatory marker, do not delete or change! Executable code begins after a marker
--[[ SLAVE SCRIPT BEG ]]

commands = {
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

        local success, peer = pcall(host.get_peer, host, cid)
        if success then
            peer:disconnect(data or 0)
        end

        event:push{HostEventType.RESPONSE, rid, true}
    end,

    disconnectServer = function (rid, args)
        local address, cid = args[1], args[2]
        auto_reconnect[address] = false

        local success, peer = pcall(host.get_peer, host, cid)
        if success then
            peer:disconnect(0)
        end

        event:push{HostEventType.RESPONSE, rid, true}
    end,

    getRoundTripTime = function (rid, args)
        local cid = args[1]

        local response

        if type(cid) == "number" then
            local success, peer = pcall(host.get_peer, host, cid)

            if not success then
                event:push{HostEventType.ERROR, rid, "No peer with such id: " .. cid}
                return
            end

            response = peer:round_trip_time()
        elseif type(cid) == "table" then
            response = {}

            for i, peerI in ipairs(cid) do
                local success, peer = pcall(host.get_peer, host, peerI)

                if not success then
                    event:push{HostEventType.ERROR, rid, "No peer with such id: " .. cid}
                    return
                end

                response[i] = peer:round_trip_time()
            end
        else
            event:push{HostEventType.ERROR, rid, "Invalid peer id provided: " .. tostring(cid)}
        end

        event:push{HostEventType.RESPONSE, rid, {cid, response}}
    end,

    send = function (rid, args)
        local cid, data = args[1], args[2]

        local success, peer = pcall(host.get_peer, host, cid)

        if not success then
            event:push{HostEventType.ERROR, rid, "No peer with such id: " .. cid}
            return
        end

        peer:send(data)

        event:push{HostEventType.RESPONSE, rid, true}
    end
}