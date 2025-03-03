-- panel
local panel = {}

local uiobj = require("classes.ObjectUI")

-- documentation



-- config

panel.name = "Panel"
panel.aliases = {}
panel.rules = {
    {"sizeRectangular", {0, 0, 100, 50}},
    {"position", {position = {"center", "center"}}},

    {"palette", {color = {0, 0, 0, 0}}},
}

-- consts



-- vars



-- init



-- fnc



-- classes

---@class Panel: ObjectUI
local Panel = {}
local Panel_meta = {__index = Panel}

setmetatable(Panel, {__index = uiobj.class}) -- Set parenthesis

-- panel fnc

function panel.new(prototype)
    local obj = uiobj.new(prototype)
    ---@cast obj Panel

    setmetatable(obj, Panel_meta)

    return obj
end

return panel