-- panel
local panel = {}

local uiobj = require("classes.ObjectUI")

-- documentation



-- config

panel.name = "Panel"
panel.aliases = {}
panel.rules = {
    {"sizeRectangular", {0, 0, love.graphics.getWidth(), love.graphics.getHeight()}},
    {"position", {position = {0, 0}}},

    {"palette", {color = {1, 1, 1, 1}}},
    {{"r", "radius", "rounding", "round"}, "r", nil}
}

-- consts



-- vars



-- init



-- fnc



-- classes

---@class Panel: ObjectUI
---@field r number Radius of round corner
local Panel = {}
local Panel_meta = {__index = Panel}
setmetatable(Panel, {__index = uiobj.class}) -- Set parenthesis

function Panel:paint()
    love.graphics.setColor(self.palette[1])
    love.graphics.rectangle("fill", 0, 0, self.w, self.h, self.r)
end

-- panel fnc

function panel.new(prototype)
    local obj = uiobj.new(prototype)
    setmetatable(obj, Panel_meta)   ---@cast obj Panel

    return obj
end

return panel