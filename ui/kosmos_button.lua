-- kosmobutton
local kosmobutton = {}

local button = require("classes.objects.Button")

local utf = require("utf8")

-- documentation



-- config

kosmobutton.name = "KosmosButton"
kosmobutton.aliases = {}
kosmobutton.rules = {
    {"sizeRectangular", {0, 0, 100, 50}},
    {"position", {position = {"center", "center"}}},

    {"palette", {color = {0, 0.5, 0, 0.4}, textColor = {1, 1, 1}}},

    {{"action", "push", "press"}, "action", function() end},
    {{"text", "label"}, "text", "KosmoButton"},
    {{"font"}, "font", love.graphics.getFont()}
}

-- consts

local ROUNDING_RADIUS = 20

local SHADOW_DISPLACEMENT = 5
local SHADOW_ZOOMING = 4
local SHADOW_SPEED = 8
local SHADOW_ZOOMING_SPEED = 3

-- vars



-- init



-- fnc



-- classes

---@class KosmoButton : Button
---@field currentShadowDisplacement number Number ranging from 0 to 1. Shadow offset off a button
---@field currentShadowZooming number Number ranging from 0 to 1. Shadow size up on hold
local KosmoButton = {  }
local KosmoButton_meta = {__index = KosmoButton}
setmetatable(KosmoButton, {__index = button.class}) -- Set parenthesis

function KosmoButton:paint()
    -- Shadow
    local shadow_offset = self.currentShadowDisplacement * SHADOW_DISPLACEMENT - self.currentShadowZooming * SHADOW_ZOOMING
    local shadow_reolution_change = 2 * (self.currentShadowZooming * SHADOW_ZOOMING)

    love.graphics.setColor(self.palette[1].darker)
    love.graphics.rectangle("fill", 0 + shadow_offset, 0 + shadow_offset, self.w + shadow_reolution_change, self.h + shadow_reolution_change, ROUNDING_RADIUS)

    if self.held then
        love.graphics.setColor(self.palette[1].brighter)
    else
        love.graphics.setColor(self.palette[1])
    end
    
    love.graphics.rectangle("fill", 0, 0, self.w, self.h, ROUNDING_RADIUS)

    -- Text
    love.graphics.setColor(self.palette[2])
    love.graphics.setFont(self.font)
    love.graphics.printf(self.textCache.textVisual, 0, self.textCache.y, self.w, "center")
end

---Update shadow position depending on hl
---@param dt number
---@private
function KosmoButton:updateShadow(dt)
    if self.held then
        if self.currentShadowZooming < 1 then
            self.currentShadowZooming = self.currentShadowZooming + dt * SHADOW_ZOOMING_SPEED

            if self.currentShadowZooming > 1 then
                self.currentShadowZooming = 1
            end
        end

        return
    else
        if self.currentShadowZooming > 0 then
            self.currentShadowZooming = self.currentShadowZooming - dt * SHADOW_SPEED

            if self.currentShadowZooming < 0 then
                self.currentShadowZooming = 0
            end
        end
    end

    if self.hl then
        if self.currentShadowDisplacement > 0 then
            self.currentShadowDisplacement = self.currentShadowDisplacement - dt * SHADOW_SPEED

            if self.currentShadowDisplacement < 0 then
                self.currentShadowDisplacement = 0
            end
        end
    else
        if self.currentShadowDisplacement < 1 then
            self.currentShadowDisplacement = self.currentShadowDisplacement + dt * SHADOW_SPEED
        end

        if self.currentShadowDisplacement > 1 then
            self.currentShadowDisplacement = 1
        end
    end
end

function KosmoButton:tick(dt)
    self:updateShadow(dt)
end

-- kosmobutton fnc

function kosmobutton.new(prototype)
    local obj = button.new(prototype)
    setmetatable(obj, KosmoButton_meta) ---@cast obj KosmoButton

    obj.currentShadowDisplacement = 1
    obj.currentShadowZooming = 0

    return obj
end

return kosmobutton