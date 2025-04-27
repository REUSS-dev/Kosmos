local main_api = {}
local fallback

--#region Service communication - Authorization

---Acknowledge successful server authentication
---@param self KosmoServerMain
---@param request KosmoRequest
function main_api.server_ack(self, request)
    local server_name = self.connectedServers[request:getUid()]

    self.connectedServers[server_name] = request:getToken()
    self.connectedServers[request:getUid()] = nil
end

--#endregion

---Introduce your token to server (lock it to your peer)
---@param self KosmoServer
---@param request KosmoRequest
function main_api.introduceToken(self, request)
    
end

return main_api, fallback