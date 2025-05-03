local commands

commands = {
    getAddress = {
        delay = 10,
        callback = function(task, address)
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
        callback = function (task, roundTripInfo)
            local self = task.self
            
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
    }
}

return commands