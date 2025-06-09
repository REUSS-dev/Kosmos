-- cache
local cache = {}

local bdb = require("libs.stellardb.btreedb")
local sbon = require("libs.stellardb.sbon")

-- documentation



-- config

local PROFILE_CACHE_FILENAME = "profilecache"

-- consts



-- vars

local profile_cache_filepath = love.filesystem.getSaveDirectory() .. "/" .. PROFILE_CACHE_FILENAME

-- init



-- fnc



-- classes

---@class KosmoCache
---@field session KosmoSession Session of this cache
---@field cache_profiles_db BTreeDB
---@field cache_profiles table<integer, table>
local KosmoCache = {}
local KosmoCache_meta = { __index = KosmoCache }

function KosmoCache:getProfile(profile_id)
    if self.cache_profiles[profile_id] then
        return self.cache_profiles[profile_id]
    end

    local entry = self.cache_profiles_db:get(sbon.encodeInteger(profile_id))

    if not entry then
        return
    end

    local profile_data = sbon.decode(entry)

    self.cache_profiles[profile_id] = profile_data

    return profile_data
end

function KosmoCache:setProfile(profile_id, profile_data)
    self.cache_profiles[profile_id] = profile_data
    self.cache_profiles_db:set(sbon.encodeInteger(profile_id), sbon.encode(profile_data))
end

--#region databases

function KosmoCache:stop()
    self.cache_profiles_db:close()
end

function KosmoCache:initializeCache()
    self.keys = {}

    local cache_path = self.session:getSessionFolder() .. "/"

    self:initializeCache_profiles(cache_path .. PROFILE_CACHE_FILENAME)
end

function KosmoCache:initializeCache_profiles(path)
    local openned = bdb.load(path)

    if not openned then
        openned = bdb.new(4)

        openned:open(path)
    end

    self.cache_profiles_db = openned
end

--#endregion

-- cache fnc

---Create new cache object of provided session
---@param session KosmoSession
---@return KosmoCache
function cache.new(session)
    local new_cache = {session = session}
    setmetatable(new_cache, KosmoCache_meta) ---@cast new_cache KosmoCache

    new_cache.cache_profiles = {}

    new_cache:initializeCache()

    return new_cache
end

return cache