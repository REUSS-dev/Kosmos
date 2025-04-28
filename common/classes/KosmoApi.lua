-- kosmoapi
local kosmoapi = {}



-- documentation

---@alias ApiVersion integer
---@alias ApiMethodName string
---@alias ApiScopeGroup string

-- config

local AUTO_CACHE_LAST = true    -- Whether the last version of API should always be cached upon loading

-- consts

local VERSION_PATTERN = "(%d+)"
local SCOPE_FILE = "scopes.lua"

local SCOPE_GUEST = "guest"

-- vars



-- init



-- fnc

local function version_defaulter(self, _)
    return self[self.default]
end

-- classes

---@class KosmoApi Versioned API object
---@field private path string Path to folder with API realizations
---@field private defaultVersion ApiVersion Fallback version if unknown API version is given
---@field public v {default: ApiVersion, [ApiVersion]: table<ApiMethodName, function>} Table with all version realizations
---@field private scope table<ApiMethodName, ApiScopeGroup> Method scopes.
---@field private fallback table<ApiVersion, ApiVersion> Map of loaded versions (keys) to their fallback versions (values)
local KosmoApi = {}
local KosmoApi_meta = { __index = KosmoApi }

function KosmoApi:getDefaultVersion()
    return self.defaultVersion
end

function KosmoApi:setDefaultVersion(new_default)
    self.defaultVersion = new_default
    self.v.default = new_default
end

---Caches version table to speed up lookups
---@param version integer
function KosmoApi:cacheVersion(version)
    local realization = self.v[version]

    local previous_version = self.fallback[version]

    while previous_version do
        local previous_realization = self.v[previous_version]

        for method, fun in pairs(previous_realization) do
            realization[method] = realization[method] or fun
        end

        previous_version = self.fallback[previous_version]
    end
end

---Checks whether provided method satisfies scope limitations of provided scope map
---@param method ApiMethodName
---@param token KosmoToken?
---@return boolean? scope_status true, if method is within provided token's scope; false, if it is outside of provided token's scope; nil, if such method does not exist
function KosmoApi:isMethodWithinScope(method, token)
    if self.scope[method] == SCOPE_GUEST then
        return true
    end

    if not token then
        return false
    end

    if not self.scope[method] then
        return nil
    end

    return token:checkScope(self.scope[method])
end

function KosmoApi:init()
    local items = love.filesystem.getDirectoryItems(self.path)

    local last

    for _, version_filename in ipairs(items) do
        local parsed_version = string.match(version_filename, VERSION_PATTERN)

        if parsed_version then -- another api version file
            local version = tonumber(parsed_version) --[[@as integer]]
            local realization_chunk = love.filesystem.load(self.path .. "/" .. version_filename)

            local realization, fallback_version = realization_chunk()

            self.v[version] = realization or {}
            self.fallback[version] = fallback_version

            last = math.max(version, last or -1)
        elseif version_filename == SCOPE_FILE then -- scopes file
            local scopes_chunk = love.filesystem.load(self.path .. "/" .. version_filename)

            self.scope = scopes_chunk()
        end
    end

    assert(self.scope, "API methods scope file not found for api at " .. self.path)

    self.defaultVersion = self.defaultVersion or last

    for version, realization in pairs(self.v) do
        if version ~= "default" then
            ---@cast realization table

            self.fallback[version] = self.fallback[version] or rawget(self.v, version - 1) and (version - 1)

            if self.fallback[version] then
                setmetatable(realization, { __index = self.v[self.fallback[version]] })
            end
        end
    end

    if AUTO_CACHE_LAST then
        self:cacheVersion(last)
    end

    self:setDefaultVersion(self.defaultVersion)

    setmetatable(self.v, { __index = version_defaulter })
end

-- kosmoapi fnc

function kosmoapi.new(api_path)
    assert(api_path, "API path not provided!")

    local obj = setmetatable({ path = api_path, v = {}, fallback = {}}, KosmoApi_meta)

    obj:init()

    return obj
end

kosmoapi.SCOPE_GUEST = SCOPE_GUEST

return kosmoapi