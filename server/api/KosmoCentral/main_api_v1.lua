local main_api = {}
local fallback

--#region Service communication - Authorization



--#endregion

--#region Guest access

---Introduce your token to server (lock it to your peer)
---@param self KosmoServer
---@param request KosmoRequest
function main_api.introduceToken(self, request)
    
end

--#endregion

return main_api, fallback