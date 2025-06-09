-- profile
local profile = {}

local gui = require("libs.stellargui")

local uiobj = require("classes.ObjectUI")
local complex = require("classes.CompositeObject")
local palette = require("classes.Palette")

-- documentation



-- consts



-- config

profile.name = "KosmosProfile"
profile.aliases = {}
profile.rules = {
    {{"font"}, "font", love.graphics.getFont()},

    {"sizeRectangular", {-10, 10, 300, 100}},

    {"position", {-10, 10, 300, 100}},

    {"palette", {color = {0.3, 0.3, 0.3}, textColor = {1, 1, 1, 1}}},
    {{"r", "radius", "rounding", "round"}, "r", 10},
    {{"client"}, "client"},
    {{"profile"}, "profile"},
    {{"no_panel"}, "no_panel", false}
}

local avatar_spacing = 10

-- vars



-- init



-- fnc



-- classes

---@class KosmosProfileName : ObjectUI
---@field client KosmoClient client object this avatar is bound to
---@field profile integer
---@field font love.Font
local KosmosProfileName = {}
local KosmosProfileName_meta = {__index = KosmosProfileName}
setmetatable(KosmosProfileName, {__index = uiobj.class}) -- Set parenthesis

function KosmosProfileName:setProfile(new_profile)
    self.profile = new_profile
end

function KosmosProfileName:paint()
    if not self.profile then
        return
    end

    local profile = self.client.cache:getProfile(self.profile)

    if not profile then
        return
    end

    -- Text
    love.graphics.setColor(self.palette[2])
    love.graphics.setFont(self.font)

    love.graphics.printf(profile.name or "", 0, 0, self.w, "left")
end

local function newName(prototype)
    local obj = uiobj.new(prototype)
    setmetatable(obj, KosmosProfileName_meta) ---@cast obj KosmosProfileName

    return obj
end

---@class KosmosProfile : CompositeObject
---@field panel Panel? profile panel object
---@field avatar KosmosAvatar profile avatar
---@field name KosmosProfileName
local KosmosProfile = {}
local KosmosProfile_meta = {__index = KosmosProfile}
setmetatable(KosmosProfile, {__index = complex.class}) -- Set parenthesis

function KosmosProfile:setProfile(new_profile)
    self.avatar:setProfile(new_profile)
    self.name:setProfile(new_profile)
end

-- profile fnc

---Create new KosmosProfile object from object prototype
---@param prototype ObjectPrototype
---@return KosmosProfile
function profile.new(prototype)
    local obj = complex.new{x = prototype.x, y = prototype.y, w = prototype.w, h = prototype.h}
    setmetatable(obj, KosmosProfile_meta)---@cast obj KosmosProfile

    local avatar_pos, avatar_size = {prototype.x, prototype.y}, {prototype.h, prototype.h}

    if not prototype.no_panel then
        obj.panel = gui.Panel(prototype)
        obj:add(obj.panel)

        avatar_pos = {prototype.x + avatar_spacing, prototype.y + avatar_spacing}
        avatar_size = {prototype.h - avatar_spacing * 2, prototype.h - avatar_spacing * 2}
    end

    obj.avatar = gui.KosmosAvatar{
        pos = avatar_pos,
        size = avatar_size,
        client = prototype.client,
        profile = prototype.profile
    }
    obj:add(obj.avatar)

    obj.name = newName{
        x = avatar_pos[1] + avatar_size[1] + avatar_spacing,
        y = avatar_pos[2],
        w = prototype.w - avatar_spacing*3 - avatar_size[1],
        h = 25,
        font = prototype.font,
        client = prototype.client,
        profile = prototype.profile,
        palette = palette.new{{0, 0, 0, 1}, {1, 1, 1, 1}}
    }
    obj:add(obj.name)


    return obj
end

return profile