-- notificator
local notif = {}

local uiobj = require("classes.ObjectUI")

local utf = require("utf8")

-- documentation



-- config

notif.name = "KosmosNotification"
notif.aliases = {}
notif.rules = {
    {"sizeRectangular", {0, 0, love.graphics.getWidth() - 100, 100}},
    {"position", {position = {"center", -50}}},

    { "palette", { colors = {{0.3, 0.3, 0.3, 0.8}, {1, 1, 1, 1}, {0.3, 0.3, 0.8, 0.8}, {0.8, 0.3, 0.3, 0.8}} } },

    {{"text", "label"}, "text", "Оповещение"},
    {{"font"}, "font", love.graphics.getFont()}
}

local accent_speed = 0.5
local fade_speed = 0.5
local disappear_speed = 2

-- consts

local ROUNDING_RADIUS = 20

local TEXT_OFFSET_LEFT = 10
local TEXT_OFFSET_TOP = 10

---@class KosmoNotifPhase
local KosmoNotifPhase = {
    ACCENT = "accent",
    FADE = "fade",
    DISAPPEAR = "dis"
}

-- vars



-- init



-- fnc



-- classes

---@class KosmosNotification : ObjectUI
---@field text string loading text
---@field font love.Font loading text font
---@field accentTimer number Number from 0 to 1, timer of attention phase
---@field fadeTimer number Number from 0 to 1, timer of accent color fading to main color
---@field disappearTimer number Number from 1 to 0, timer of object disappearance into fadeout
---@field accentColor ColorTable Accent color to use
local KosmosNotification = { }
local KosmosNotification_meta = {__index = KosmosNotification}
setmetatable(KosmosNotification, {__index = uiobj.class}) -- Set parenthesis

function KosmosNotification:checkHover()
    return false
end

function KosmosNotification:unregister()
    self:hide()
end

function KosmosNotification:paint()
    -- panel
    love.graphics.setColor(
        self.accentColor[1] * (1 - self.fadeTimer) + self.palette[1][1] * self.fadeTimer,
        self.accentColor[2] * (1 - self.fadeTimer) + self.palette[1][2] * self.fadeTimer,
        self.accentColor[3] * (1 - self.fadeTimer) + self.palette[1][3] * self.fadeTimer,
        ((self.accentColor[4] * self.accentTimer + (1 - self.accentTimer)) * (1 - self.fadeTimer) + self.palette[1][3] * self.fadeTimer) * self.disappearTimer
    )

    love.graphics.rectangle("fill", 0, 0, self.w, self.h, ROUNDING_RADIUS)

    -- Text
    love.graphics.setColor(self.palette[2][1], self.palette[2][2], self.palette[2][3], self.palette[2][4] * self.disappearTimer)
    love.graphics.setFont(self.font)
    love.graphics.printf(self.text, TEXT_OFFSET_LEFT, 0 + TEXT_OFFSET_TOP, self.w - 2*TEXT_OFFSET_LEFT, "center")
end

function KosmosNotification:tick(dt)
    if self.accentTimer < 1 then
        self.accentTimer = self.accentTimer + dt * accent_speed

        if self.accentTimer > 1 then
            self.accentTimer = 1
        end

        return
    end

    if self.fadeTimer < 1 then
        self.fadeTimer = self.fadeTimer + dt * fade_speed

        if self.fadeTimer > 1 then
            self.fadeTimer = 1
        end

        return
    end

    if self.disappearTimer > 0 then
        self.disappearTimer = self.disappearTimer - dt * disappear_speed

        if self.disappearTimer < 0 then
            self.disappearTimer = 0

            self:hide()
        end

        return
    end
end

function KosmosNotification:reset()
    self.accentTimer = 0
    self.fadeTimer = 0
    self.disappearTimer = 1

    self:show()
end

function KosmosNotification:error(text)
    self.text = text

    self:reset()
    self.accentColor = self.palette:getColorByIndex(4)
end

function KosmosNotification:info(text)
    self.text = text

    self:reset()
    self.accentColor = self.palette:getColorByIndex(3)
end

--#region private



--#endregion

-- loading fnc

function notif.new(prototype)
    local obj = uiobj.new(prototype)

    setmetatable(obj, KosmosNotification_meta)   ---@cast obj KosmosNotification

    obj:reset()
    obj:hide()

    return obj
end

return notif