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
---@field private defaultVersion ApiVersion Fallback version if unknown API version is queried
---@field public v {default: ApiVersion, [ApiVersion]: table<ApiMethodName, function>} Table with all version realizations
---@field private scope table<ApiMethodName, ApiScopeGroup> Method scopes.
---@field private fallback table<ApiVersion, ApiVersion?> Map of loaded versions (keys) to their fallback versions (values)
local KosmoApi = {}
local KosmoApi_meta = { __index = KosmoApi }

---Returns default API version.
---@return ApiVersion
function KosmoApi:getDefaultVersion()
    return self.defaultVersion
end

---Sets default API version
---@param new_default integer Version to set as default for this API
function KosmoApi:setDefaultVersion(new_default)
    self.defaultVersion = new_default
    self.v.default = new_default
end

---Caches version table to speed up lookups
---@param version integer
function KosmoApi:cacheVersion(version)
    local realization = self.v[version]
    assert(realization, "Attempt caching undefined version. API " .. self.path .. " does not have version " .. tostring(version))

    local previous_version = self.fallback[version]

    while previous_version do
        local previous_realization = self.v[previous_version]

        for method, fun in pairs(previous_realization) do
            realization[method] = realization[method] or fun
        end

        previous_version = self.fallback[previous_version]
    end
end

---Checks whether provided method satisfies scope limitations of provided token
---@param method ApiMethodName Method to check scope for
---@param token KosmoToken? Token object defining scopes. Can be nil, only guest access is permited in this case.
---@return boolean? scope_status true, if method is within provided token's scope; false, if it is outside of provided token's scope; nil, if such method does not exist
function KosmoApi:isMethodWithinScope(method, token)
    -- Guest scope does not depend on token
    if self.scope[method] == SCOPE_GUEST then
        return true
    end

    -- Token not provided to a non-guest method
    if not token then
        return false
    end

    -- Scope for method is not defined, method does not exist
    if not self.scope[method] then
        return nil
    end

    return token:checkScope(self.scope[method])
end

---Read API files from provided folder path
---@param folder string? Path to folder with API version files (defaults to self.path)
---@return integer
function KosmoApi:readAPIs(folder)
    folder = folder or self.path

    local last

    local items = love.filesystem.getDirectoryItems(self.path)

    for _, version_filename in ipairs(items) do
        local parsed_version = string.match(version_filename, VERSION_PATTERN)

        if parsed_version then -- another api version file
            local version = tonumber(parsed_version) --[[@as integer]]
            local realization_chunk = love.filesystem.load(folder .. "/" .. version_filename)

            local realization, fallback_version = realization_chunk()

            self.v[version] = realization or {}
            self.fallback[version] = fallback_version

            last = math.max(version, last or -1)
        elseif version_filename == SCOPE_FILE then -- scopes file
            local scopes_chunk = love.filesystem.load(self.path .. "/" .. version_filename)

            self.scope = scopes_chunk()
        end
    end

    return last
end

---Initialize newly created KosmoApi objects
---@package
function KosmoApi:init()
    -- Read APIs
    local last = self:readAPIs()

    assert(self.scope, "API methods scope file not found for api at " .. self.path)

    self:setDefaultVersion(last)

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
end

-- kosmoapi fnc

---Create new KosmoApi object using path to API versions directory
---@param api_path string Path to API realization files.
---@return KosmoApi
function kosmoapi.new(api_path)
    assert(api_path, "API path not provided!")

    local obj = setmetatable({ path = api_path, v = {}, fallback = {}}, KosmoApi_meta)
    obj:init()

    setmetatable(obj.v, { __index = version_defaulter })

    return obj
end

kosmoapi.SCOPE_GUEST = SCOPE_GUEST

return kosmoapi