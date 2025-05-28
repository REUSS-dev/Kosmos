-- session
local session = {}

local sbon = require("libs.stellardb.sbon")

-- documentation



-- config

local session_info_file = "session.sbon"
local sessions_folder = "sessions"

-- consts



-- vars

local sessions_info

-- fnc

local function loadSessionsInfo()
    local session_info_status = love.filesystem.getInfo(session_info_file)

    if not session_info_status or session_info_status.type ~= "file" then
        sessions_info = { sessions = {}, default = nil }
        love.filesystem.write(session_info_file, sbon.encode(sessions_info))
        return
    end

    local sessions_data = love.filesystem.read(session_info_file) --[[@as string]]

    sessions_info = sbon.decode(sessions_data)
end

-- init

-- create session folder
local session_folder_status = love.filesystem.getInfo(sessions_folder)

if not session_folder_status then
    love.filesystem.createDirectory(sessions_folder)
elseif session_folder_status.type ~= "directory" then
    os.rename(sessions_folder, sessions_folder .. ".old")

    love.filesystem.createDirectory(sessions_folder)
end

-- load sessions info
loadSessionsInfo()

-- classes

---@class KosmoSession
---@field user integer ID of a user of this session
---@field sessionToken KosmoToken Token of a user of this session
local KosmoSession = {}
local KosmoSession_meta = { __index = KosmoSession }

function KosmoSession.getDefault()
    return sessions_info.default
end

function KosmoSession:getToken()
    return self.sessionToken
end

function KosmoSession:getTokenString()
    return not self.sessionToken and "" or self.sessionToken:getToken()
end

-- session fnc

function session.new(user_id)
    local obj = setmetatable({
        user = user_id or sessions_info.default
    }, KosmoSession_meta)

    return obj
end

return session