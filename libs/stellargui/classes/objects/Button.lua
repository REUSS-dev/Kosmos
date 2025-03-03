-- button
local button = {}

local uiobj = require("classes.ObjectUI")

local utf = require("utf8")

-- documentation



-- config

button.name = "Button"
button.aliases = {}
button.rules = {
    {"sizeRectangular", {0, 0, 100, 50}},
    {"position", {position = {"center", "center"}}},

    {"palette", {color = {0, 0.5, 0, 0.4}, textColor = {1, 1, 1}}},

    {{"action", "push", "press"}, "action", function() end},
    {{"text", "label"}, "text", "Button"},
    {{"font"}, "font", love.graphics.getFont()}
}

-- consts



-- vars



-- init



-- fnc



-- classes

---@class Button : ObjectUI
---@field held boolean Flag if button is currently held (Left mouse button) by user
---@field action fun() Button action callback. Triggers ONLY when user presses and releases LMB on button object
---@field textCache table Set of data for printing button text. WARNING: This should be nullified on button size/text change.
---@field text string Button text
---@field font love.Font Button text font
local Button = { defaultCursor = "hand" }
local Button_meta = {__index = Button}
setmetatable(Button, {__index = uiobj.class}) -- Set parenthesis

function Button:paint()
    -- Inside fill
    if self.held then
        love.graphics.setColor(self.palette[1].darker)
    elseif self.hl then
        love.graphics.setColor(self.palette[1].brighter)
    else
        love.graphics.setColor(self.palette[1])
    end
    
    love.graphics.rectangle("fill", 0, 0, self.w, self.h)

    -- Border
    love.graphics.setColor(self.palette[3])
    love.graphics.rectangle("line", 0, 0, self.w, self.h)

    -- Text
    love.graphics.setColor(self.palette[2])
    love.graphics.setFont(self.font)
    love.graphics.printf(self.textCache.textVisual, 0, self.textCache.y, self.w, "center")
end

function Button:click(_, _, but)
    if but == 1 then
        self.held = true
    end
end

function Button:clickRelease(x, y, but)
    if but == 1 then
        self.held = false

        if self:checkHover(x, y) then
            self.action()
        end
    end
end

function Button:keyPress(key)
    -- Also trigger button action when button has focus and Return hit
    if key == "return" then
        self.action()
    end
end

---Regenerate crucial data for button text printing
---@private
function Button:generateTextCache()
    self.textCache = {}

    local fontHeight = self.font:getHeight()
    local allowedLines = math.floor(self.h/fontHeight)

    local _, wrapped_lines = self.font:getWrap(self.text, self.w)

    self.textCache.y = math.floor((self.h - fontHeight * math.min(#wrapped_lines, allowedLines)) / 2)

    if allowedLines == 0 then
        self.textCache.textVisual = "?"
    elseif #wrapped_lines <= allowedLines then
        self.textCache.textVisual = self.text
    else -- text has more lines than allowed
        local tocut = self.text

        -- cut text progressively from end until it is possible to fit it 
        repeat
            tocut = string.sub(tocut, 1, utf.offset(tocut, -1) - 1)

            local _, cutlines = self.font:getWrap(tocut .. "..", self.w)
        until #cutlines <= allowedLines
    
        self.textCache.textVisual = tocut .. ".."
    end
end

button.class = Button

-- button fnc

function button.new(prototype)
    local obj = uiobj.new(prototype)
    ---@cast obj Button

    setmetatable(obj, Button_meta)

    ---@diagnostic disable-next-line: invisible
    obj:generateTextCache()

    return obj
end

return button