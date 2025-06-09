-- session
local session = {}

local sbon = require("libs.stellardb.sbon")

local tok = require("classes.KosmoToken")

-- documentation



-- config

local session_info_file = "session.sbon"
local sessions_folder = "sessions"

-- consts



-- vars

local sessions_info

-- fnc

local function writeSessionInfo()
    love.filesystem.write(session_info_file, sbon.encode(sessions_info))
end

local function loadSessionsInfo()
    local session_info_status = love.filesystem.getInfo(session_info_file)

    if not session_info_status or session_info_status.type ~= "file" then
        sessions_info = { sessions = {}, default = nil }
        writeSessionInfo()
        return
    end

    local sessions_data = love.filesystem.read(session_info_file) --[[@as string]]

    sessions_info = sbon.decode(sessions_data)
end

local function getSessionFolder(session_name)
    return sessions_folder .. "/" .. session_name
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
---@field user string login of a user of this session
---@field sessionToken KosmoToken Token of a user of this session
local KosmoSession = {}
local KosmoSession_meta = { __index = KosmoSession }

function KosmoSession:getToken()
    return self.sessionToken
end

function KosmoSession:getTokenString()
    return not self.sessionToken and "" or self.sessionToken:getToken()
end

function KosmoSession:getUser()
    return self.user
end

function KosmoSession:setUser(session_login)
    if not session_login then
        return false
    end

    local session_object = sessions_info.sessions[session_login]

    if not session_object then
        return false
    end

    self.user = session_login
    self.sessionToken = tok.new(session_object.token, tok.scopeArrayToMap(session_object.scope), 1, 0)

    return true
end

function KosmoSession:getSessionFolder()
    return getSessionFolder(self.user)
end

-- session fnc

function session.new(user)
    local obj = setmetatable({}, KosmoSession_meta)

    obj:setUser(user or sessions_info.default)

    return obj
end

function session.getDefault()
    return sessions_info.default
end
KosmoSession.getDefault = session.getDefault

function session.setDefault(username)
    sessions_info.default = username
end
KosmoSession.setDefault = session.setDefault

function session.addSession(login, token, token_scope)
    sessions_info.sessions[login] = {token = token, scope = token_scope}
    --session.setDefault(login)

    local new_session_folder = getSessionFolder(login)
    local new_session_folder_status = love.filesystem.getInfo(new_session_folder)

    if not new_session_folder_status then
        love.filesystem.createDirectory(new_session_folder)
    elseif new_session_folder_status.type ~= "directory" then
        os.rename(new_session_folder, new_session_folder .. ".old")

        love.filesystem.createDirectory(new_session_folder)
    end

    writeSessionInfo()
end
KosmoSession.addSession = session.addSession

return session