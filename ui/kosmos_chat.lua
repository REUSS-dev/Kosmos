-- conversation chat
local conv_chat = {}

local gui = require("libs.stellargui")

local palette = require("classes.Palette")
local complex = require("classes.CompositeObject")
local uiobj = require("classes.ObjectUI")

-- documentation



-- consts



-- config

conv_chat.name = "KosmosChat"
conv_chat.aliases = {}
conv_chat.rules = {
    {{"font"}, "font", love.graphics.getFont()},
    {{"font_small", "small_font", "font_s"}, "font_small", love.graphics.getFont()},

    {"sizeRectangular", {10, 10, 400, 100}},

    {"position", {10, 10, 400, 100}},

    {"palette", {color = {0.3, 0.3, 0.3}, textColor = {1, 1, 1, 1}}},
    {{"r", "radius", "rounding", "round"}, "r", 10},
    {{"client"}, "client"},
    {{"profile"}, "profile"}
}

local text_window_height = 100

-- vars



-- init



-- fnc



-- classes

---@class KosmosChat : CompositeObject
local KosmosChat = {}
local KosmosChat_meta = {__index = KosmosChat}
setmetatable(KosmosChat, {__index = complex.class}) -- Set parenthesis

function KosmosChat:setProfile(user_id)
    self.profile = user_id

    self.panel:show()
    self.textfield:show()
end

-- profile fnc

---Create new KosmosConversationProfile object from object prototype
---@param prototype ObjectPrototype
---@return KosmosChat
function conv_chat.new(prototype)
    local obj = complex.new{x = prototype.x, y = prototype.y, w = prototype.w, h = prototype.h, client = prototype.client}
    setmetatable(obj, KosmosChat_meta)---@cast obj KosmosChat

    obj.panel = gui.Panel{ prototype.x, prototype.y, prototype.w, prototype.h,
        r = prototype.r,
        palette = prototype.palette,
    }
    obj.panel:hide()
    local oldPaint = obj.panel.paint
    obj.panel.paint = function (self)
        oldPaint(obj.panel)
        love.graphics.setColor(1, 1, 1, 1)
        if obj.profile then
            local profile_obj = obj.client.cache:getProfile(obj.client.session:getUser())

            local chatlog = profile_obj.chats[tostring(obj.profile)]

            love.graphics.printf(chatlog or "", 0 + 10, 0 + 10, self.w - 20, "left")
        end
    end
    obj:add(obj.panel)

    obj.textfield = gui.TextField{
        x = prototype.x,
        y = prototype.y + prototype.h - text_window_height,
        w = prototype.w,
        h = text_window_height,
        font = prototype.font,
        r = prototype.r,
        action = function (self)
            if #self:getText() == 0 then
                return
            end
            CLIENT:sendMessage(obj.profile, self:getText())
            self:setText("")
        end
    }
    obj.textfield:hide()
    obj:add(obj.textfield)

    return obj
end

return conv_chat