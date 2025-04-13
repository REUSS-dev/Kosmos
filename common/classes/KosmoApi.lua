-- kosmoapi
local kosmoapi = {}



-- documentation



-- config

local AUTO_CACHE_LAST = true    -- Whether the last version of API should always be cached upon loading

-- consts

local VERSION_PATTERN = "(%d+)"

-- vars



-- init



-- fnc



-- classes

---@class KosmoApi Versioned API object
---@field private path string Path to folder with API realizations
---@field private defaultVersion integer Fallback version if unknown API version is given
---@field public v table<integer, table<string, function>> Table with all version realizations
---@field private fallback table<integer, integer>
local KosmoApi = {}
local KosmoApi_meta = { __index = KosmoApi }

function KosmoApi:getDefaultVersion()
    return self.defaultVersion
end

function KosmoApi:setDefaultVersion(new_default)
    self.defaultVersion = new_default

    setmetatable(self.v, { __index = self.v[new_default] })
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

function KosmoApi:init()
    local items = love.filesystem.getDirectoryItems(self.path)

    local last

    for _, version_filename in ipairs(items) do
        local parsed_version = string.match(version_filename, VERSION_PATTERN)

        if parsed_version then
            local version = tonumber(parsed_version) --[[@as integer]]
            local realization_chunk = love.filesystem.load(self.path .. "/" .. version_filename)

            local realization, fallback_version = realization_chunk()

            self.v[version] = realization
            self.fallback[version] = fallback_version

            last = math.max(version, last or -1)
        end
    end

    self.defaultVersion = self.defaultVersion or last

    for version, realization in pairs(self.v) do
        self.fallback[version] = self.fallback[version] or rawget(self.v, version - 1) and (version - 1)

        if self.fallback[version] then
            setmetatable(realization, { __index = self.v[self.fallback[version]] })
        end
    end

    if AUTO_CACHE_LAST then
        self:cacheVersion(last)
    end

    self:setDefaultVersion(self.defaultVersion)
end

-- kosmoapi fnc

function kosmoapi.new(api_path)
    assert(api_path, "API path not provided!")

    local obj = setmetatable({ path = api_path, v = {}, fallback = {} }, KosmoApi_meta)

    obj:init()

    return obj
end

return kosmoapi