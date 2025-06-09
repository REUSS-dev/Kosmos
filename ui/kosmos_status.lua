-- kosmostatus
local status = {}

local palette = require("classes.Palette")

local uiobj = require("classes.ObjectUI")

-- documentation



-- config

local defaultSize = 20

local function calculateSize(_, sink)
    sink.w = defaultSize * sink.size
    sink.h = defaultSize * sink.size
end

status.name = "KosmosStatus"
status.aliases = {}
status.rules = {
    {{"size"}, "size", 1},
    calculateSize,
    {"position", {position = {"center", "center"}}},

    {{"font"}, "font", love.graphics.getFont()},
    {{"text", "showText", "name", "showName"}, "showName", false},
    {{"client"}, "client"},
    {{"chat"}, "chat"}
}

local colors = {{1, 1, 1, 1}}

-- consts



-- vars

local status_palette = palette.new(colors)

-- init



-- fnc



-- classes

---@class KosmosStatus : ObjectUI
---@field offset number offset of status circle center from top-left corner
---@field r number cirlce radius
local KosmosStatus = {  }
local KosmosStatus_meta = {__index = KosmosStatus}
setmetatable(KosmosStatus, {__index = uiobj.class}) -- Set parenthesis

function KosmosStatus:paint()
    love.graphics.translate(self.offset, self.offset)
    love.graphics.setColor(self.palette[1]) ---@todo
    love.graphics.circle("fill", 0, 0, self.r)
end

-- kosmostatus fnc

function status.new(prototype)
    local obj = uiobj.new(prototype)
    setmetatable(obj, KosmosStatus_meta) ---@cast obj KosmosStatus

    obj.offset = obj:getWidth() / 2
    obj.r = obj:getWidth() / 3
    obj.palette = status_palette

    return obj
end

return status