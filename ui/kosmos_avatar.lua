-- kosmos avatar
local avatar = {}

local uiobj = require("classes.ObjectUI")

-- documentation



-- consts



-- config

avatar.name = "KosmosAvatar"
avatar.aliases = {}
avatar.rules = {
    {"sizeRectangular", {10, 10, 100, 100}},

    {"position", {x = "center", y = "center"}},

    {"palette", {colors = {{0.3, 0.3, 0.8, 0.8}, {0.6, 0.6, 0.2, 0.8}}}},
    {{"r", "radius", "rounding", "round"}, "r", 10},
    {{"client"}, "client"},
    {{"profile"}, "profile"}
}

-- vars



-- init



-- fnc



-- classes

---@class KosmosAvatar : ObjectUI
---@field client KosmoClient
---@field profile KosmoProfile
---@field logoSquareSize number size of square of the Kosmos logo
---@field logoSpacingSize number size of spacing between squares in Kosmos logo
---@field logoRounding number radius of rounding in Kosmos logo
local KosmosAvatar = {}
local KosmosAvatar_meta = {__index = KosmosAvatar}
setmetatable(KosmosAvatar, {__index = uiobj.class}) -- Set parenthesis

function KosmosAvatar:paint()
    if not self.profile or not self.client.cache:getProfile(self.profile) or not self.client.cache:getProfile(self.profile).avatar then
        love.graphics.setColor(self.palette[1])
        -- square 1
        love.graphics.rectangle("fill", 0, 0, self.logoSquareSize, self.logoSquareSize, self.logoRounding)
        -- square 2
        love.graphics.rectangle("fill", self.logoSpacingSize + self.logoSquareSize, 0, self.logoSquareSize, self.logoSquareSize, self.logoRounding)
        -- square 4
        love.graphics.rectangle("fill", self.logoSpacingSize + self.logoSquareSize, self.logoSpacingSize + self.logoSquareSize, self.logoSquareSize, self.logoSquareSize, self.logoRounding)

        -- square 3
        love.graphics.setColor(self.palette[2])
        love.graphics.rectangle("fill", 0, self.logoSpacingSize + self.logoSquareSize, self.logoSquareSize, self.logoSquareSize, self.logoRounding)
    end
end

function KosmosAvatar:setProfile(new_profile)
    self.profile = new_profile
end

-- profile fnc

---Create new KosmosAvatar object from object prototype
---@param prototype ObjectPrototype
---@return KosmosAvatar
function avatar.new(prototype)
    local obj = uiobj.new(prototype)
    setmetatable(obj, KosmosAvatar_meta) ---@cast obj KosmosAvatar

    obj.logoSquareSize = obj:getHeight() * 19/20 / 2
    obj.logoSpacingSize = obj:getHeight() * 1/20
    obj.logoRounding = obj:getHeight() * 1/10

    return obj
end

return avatar