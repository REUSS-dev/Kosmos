-- conversation
local conv = {}

local gui = require("libs.stellargui")

local palette = require("classes.Palette")
local complex = require("classes.CompositeObject")

-- documentation



-- consts



-- config

conv.name = "KosmosConversation"
conv.aliases = {}
conv.rules = {
    {{"font"}, "font", love.graphics.getFont()},
    {{"font_small", "small_font", "font_s"}, "font_small", love.graphics.getFont()},

    {"sizeRectangular", {-10, -50, 300, 430}},

    {"position", {-10, -50, 300, 430}},

    {"palette", {color = {0.3, 0.3, 0.3}, textColor = {1, 1, 1, 1}}},
    {{"r", "radius", "rounding", "round"}, "r", 10},
    {{"client"}, "client"},
    {{"chat"}, "chat"}
}

local profile_height = 100
local profile_spacing = 10

local button_width = 150
local button_height = 50
local button_call_color = {0.6, 0.6, 0.2, 0.6}
local button_file_color = {0.8, 0.3, 0.3, 0.6}
local button_conv_color = {0.3, 0.3, 0.8, 0.6}
local button_spacing = 20

-- vars



-- init



-- fnc



-- classes

---@class KosmosConversation : CompositeObject
---@field client KosmoClient
---@field profile KosmosConversationProfile friend profile object
---@field callButton KosmosButton Call contact button
---@field fileButton KosmosButton Send file to contact button
---@field convButton KosmosButton Start conversation button
local KosmosConversation = {}
local KosmosConversation_meta = {__index = KosmosConversation}
setmetatable(KosmosConversation, {__index = complex.class}) -- Set parenthesis

function KosmosConversation:setProfile(user_id)
    self.chat:setProfile(user_id)
end

-- profile fnc

---Create new KosmosConversation object from object prototype
---@param prototype ObjectPrototype
---@return KosmosConversation
function conv.new(prototype)
    local obj = complex.new{x = prototype.x, y = prototype.y, w = prototype.w, h = prototype.h, client = prototype.client}
    setmetatable(obj, KosmosConversation_meta)---@cast obj KosmosConversation

    obj.profile = gui.KosmosConversationProfile{
        x = prototype.x,
        y = prototype.y,
        w = prototype.w,
        h = profile_height,
        r = prototype.r,
        palette = prototype.palette,
        font = prototype.font,
        font_small = prototype.font_small,
        client = prototype.client,
        chat = prototype.chat
    }
    obj:add(obj.profile)

    obj.callButton = gui.KosmosButton{
        x = prototype.x,
        y = prototype.y + profile_height + profile_spacing,
        w = button_width,
        h = button_height,
        color = button_call_color,
        font = prototype.font,
        text = "Звонок"
    }
    obj:add(obj.callButton)

    obj.fileButton = gui.KosmosButton{
        x = prototype.x + obj.callButton:getWidth() + button_spacing,
        y = prototype.y + profile_height + profile_spacing,
        w = button_width,
        h = button_height,
        color = button_file_color,
        font = prototype.font,
        text = "Файл"
    }
    obj:add(obj.fileButton)

    obj.convButton = gui.KosmosButton{
        x = prototype.x + obj.callButton:getWidth() + obj.fileButton:getWidth() + button_spacing * 2,
        y = prototype.y + profile_height + profile_spacing,
        w = button_width,
        h = button_height,
        color = button_conv_color,
        font = prototype.font,
        text = "Конференция"
    }
    obj:add(obj.convButton)

    obj.chat = gui.KosmosChat{
        x = prototype.x,
        y = prototype.y + profile_height + profile_spacing + button_height + profile_spacing*1.5,
        w = prototype.w,
        h = prototype.h - profile_height - profile_spacing * 2 - button_height,
        colors = prototype.palette,
        font = prototype.font,
        client = prototype.client
    }
    obj:add(obj.chat)

    return obj
end

return conv