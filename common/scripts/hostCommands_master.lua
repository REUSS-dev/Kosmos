local commands

commands = {
    getAddress = {
        delay = 10,
        callback = function(self, task, address)
            task.self.hostInfo.address = address
        end
    },
    connect = {
        delay = 0,
    },
    connectServer = {
        delay = 0,
    },
    disconnect = {
        delay = 0,
    },
    disconnectServer = {
        delay = 0,
    },
    getRoundTripTime = {
        delay = 1,
        callback = function (self, _, roundTripInfo)
            local peer, time = roundTripInfo[1], roundTripInfo[2]
            if type(peer) == "number" then
                if self.hostInfo.connections[peer] then
                    self.hostInfo.connections[peer][3] = time
                end
            else
                for i, peerI in ipairs(peer) do
                    if self.hostInfo.connections[peerI] then
                        self.hostInfo.connections[peerI][3] = time[i]
                    end
                end
            end
        end
    },
    send = {
        delay = 0,
    }
}

return commands