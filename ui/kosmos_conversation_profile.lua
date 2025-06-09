-- conversation profile
local conv_profile = {}

local gui = require("libs.stellargui")

local palette = require("classes.Palette")
local complex = require("classes.CompositeObject")
local uiobj = require("classes.ObjectUI")

-- documentation



-- consts



-- config

conv_profile.name = "KosmosConversationProfile"
conv_profile.aliases = {}
conv_profile.rules = {
    {{"font"}, "font", love.graphics.getFont()},
    {{"font_small", "small_font", "font_s"}, "font_small", love.graphics.getFont()},

    {"sizeRectangular", {10, 10, 400, 100}},

    {"position", {10, 10, 400, 100}},

    {"palette", {color = {0.3, 0.3, 0.3}, textColor = {1, 1, 1, 1}}},
    {{"r", "radius", "rounding", "round"}, "r", 10},
    {{"client"}, "client"},
    {{"chat"}, "chat"}
}

local avatar_spacing = 10
local avatar_palette = {{0.3, 0.3, 0.8, 0.8}, {0.6, 0.6, 0.2, 0.8}}

-- vars



-- init



-- fnc



-- classes

---@class KosmosConversationProfileName : ObjectUI
---@field chat KosmoChat chat object this avatar is bound to
---@field font love.Font
local KosmosConversationProfileName = {}
local KosmosConversationProfileName_meta = {__index = KosmosConversationProfileName}
setmetatable(KosmosConversationProfileName, {__index = uiobj.class}) -- Set parenthesis

function KosmosConversationProfileName:paint()
    -- Text
    love.graphics.setColor(self.palette[2])
    love.graphics.setFont(self.font)
    if self.chat then
        love.graphics.printf(self.chat:getName(), 0, 0, self.w, "left")
    else
        love.graphics.printf("Добро пожаловать в Kosmos!", 0, 0, self.w, "left")
    end
end

local function newName(prototype)
    local obj = uiobj.new(prototype)
    setmetatable(obj, KosmosConversationProfileName_meta) ---@cast obj KosmosConversationProfileName

    return obj
end

---@class KosmosConversationProfileBlog : ObjectUI
---@field chat KosmoChat chat object this avatar is bound to
---@field font love.Font
---@field r number corner rounding radius
---@field textX number horizontal offset of text of the cloud
local KosmosConversationProfileBlog = {}
local KosmosConversationProfileBlog_meta = {__index = KosmosConversationProfileBlog}
setmetatable(KosmosConversationProfileBlog, {__index = uiobj.class}) -- Set parenthesis

function KosmosConversationProfileBlog:paint()
    -- cloud
    love.graphics.setColor(self.palette[1].brighter)
    love.graphics.rectangle("fill", 0, 0, self.w, self.h, self.r)

    -- Text
    love.graphics.setColor(self.palette[2])
    love.graphics.setFont(self.font)
    if self.chat then
        love.graphics.printf(self.chat:getDesc(), self.textX, 3, self.w, "left")
    else
        love.graphics.printf("Нажмите по одному из контактов справа, чтобы открыть чат. Добавьте своих друзей в контакты, чтобы общаться с ними!", self.textX, 3, self.w, "left")
    end
end

local function newBlog(prototype)
    local obj = uiobj.new(prototype)
    setmetatable(obj, KosmosConversationProfileBlog_meta) ---@cast obj KosmosConversationProfileBlog

    obj.textX = avatar_spacing

    return obj
end

---@class KosmosConversationProfile : CompositeObject
---@field client KosmoClient
---@field chat KosmoChat
---@field panel Panel Conversation profile panel
---@field avatar KosmosConversationProfileAvatar Conversation avatar object
---@field status KosmosStatus Conversation status object
---@field name KosmosConversationProfileName Name of the conversation object
---@field blog KosmosConversationProfileBlog Blog of the conversation object
local KosmosConversationProfile = {}
local KosmosConversationProfile_meta = {__index = KosmosConversationProfile}
setmetatable(KosmosConversationProfile, {__index = complex.class}) -- Set parenthesis

-- profile fnc

---Create new KosmosConversationProfile object from object prototype
---@param prototype ObjectPrototype
---@return KosmosConversationProfile
function conv_profile.new(prototype)
    local obj = complex.new{x = prototype.x, y = prototype.y, w = prototype.w, h = prototype.h, client = prototype.client}
    setmetatable(obj, KosmosConversationProfile_meta)---@cast obj KosmosConversationProfile

    obj.panel = gui.Panel{ prototype.x, prototype.y, prototype.w, prototype.h,
        r = prototype.r,
        palette = prototype.palette,
    }
    obj:add(obj.panel)

    -- calculate next object origin for convenience
    local origin = {prototype.x + avatar_spacing, prototype.y + avatar_spacing}

    obj.avatar = gui.KosmosAvatar{
        x = origin[1],
        y = origin[2],
        w = prototype.h - avatar_spacing - avatar_spacing,
        h = prototype.h - avatar_spacing - avatar_spacing,
        profile = prototype.chat
    }
    obj:add(obj.avatar)

    -- calculate next object origin for convenience
    origin[1] = origin[1] + prototype.h - avatar_spacing

    obj.status = gui.KosmosStatus{
        x = origin[1],
        y = origin[2] + avatar_spacing/3,
        size = 1
    }
    obj:add(obj.status)

    obj.name = newName{
        x = origin[1] + obj.status:getWidth() + avatar_spacing/2,
        y = origin[2],
        w = math.huge, -- left-aligned, no need to wrap
        h = 25,
        font = prototype.font,
        chat = prototype.chat,
        palette = prototype.palette
    }
    obj:add(obj.name)

    origin[2] = origin[2] + obj.status:getHeight() + avatar_spacing

    obj.blog = newBlog{
        x = origin[1],
        y = origin[2],
        w = prototype.w - origin[1] + prototype.x - avatar_spacing,
        h = prototype.h - origin[2] + prototype.y - avatar_spacing,
        font = prototype.font_small,
        chat = prototype.chat,
        palette = prototype.palette,
        r = prototype.r
    }
    obj:add(obj.blog)

    return obj
end

return conv_profile