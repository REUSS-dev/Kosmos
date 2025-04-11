local commands

local function nop()
end

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
        callback = nop
    },
    connectServer = {
        delay = 0,
        timeout = 5,
        callback = nop
    },
    disconnect = {
        delay = 0,
        timeout = 5,
        callback = nop
    },
    disconnectServer = {
        delay = 0,
        timeout = 5,
        callback = nop
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
    },
    send = {
        delay = 0,
        timeout = 5,
        callback = nop
    }
}

return commands