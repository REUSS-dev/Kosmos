-- textfield
local textfield = {}

local uiobj = require("classes.ObjectUI")

local utf = require("utf8")

-- documentation



-- config

textfield.name = "TextField"
textfield.aliases = {}
textfield.rules = {
    {"sizeRectangular", {0, 0, 100, 50}},
    {"position", {position = {"center", "center"}}},

    {"palette", {color = {1, 1, 1, 1}, textColor = {0, 0, 0, 1}}},

    {{"action", "enter", "return"}, "action", function() end},
    {{"text"}, "text", ""},
    {{"font"}, "font", love.graphics.getFont()},
    {{"oneline", "forceOneline", "force_oneline"}, "oneline", nil}
}

-- consts

local TEXT_OFFSET_LEFT = 5
local TEXT_OFFSET_TOP = 5

local TEXT_CARETTE_BLINK_PERIOD = 0.5

-- vars



-- init



-- fnc



-- classes

---@class TextField : ObjectUI
---@field text string
---@field font love.Font
---@field action fun(self: TextField)
---@field textX number X text offset from TextField origin
---@field textY number Y text offset from TextField origin
---@field private caretteVisibility boolean
---@field private caretteTimer number
---@field private carettePosition number Carette X position. Is counted from object origin, must be padded by TEXT_OFFSET_LEFT to be correctly set
---@field lineHeight number To be PRIVATED
---@field oneline boolean To be PRIVATED
local TextField = { defaultCursor = "ibeam" }
local TextField_meta = {__index = TextField}

---Update carette position
---@param noreset boolean? Do not reset carette timer
function TextField:updateCarette(noreset)
    if not noreset then
        self.caretteTimer = 0
        self.caretteVisibility = self.focus and true
    end

    self.carettePosition = TEXT_OFFSET_LEFT + self.font:getWidth(self.text)
end

function TextField:getText()
    return self.text
end

function TextField:setText(text)
    self.text = tostring(text)
    self:updateCarette()
end

function TextField:paint()
    love.graphics.setColor(self.palette[1])
    love.graphics.rectangle("fill", 0, 0, self.w, self.h)

    love.graphics.setColor(self.palette[3])
    love.graphics.rectangle("line", 0, 0, self.w, self.h)

    love.graphics.setColor(self.palette[2])
    love.graphics.setFont(self.font)
    love.graphics.print(self.text, self.textX, self.textY)

    if self.caretteVisibility then
        love.graphics.rectangle("fill", self.carettePosition, self.textY, 1, self.lineHeight)
    end
end

function TextField:keyPress(key)
    if key == "return" then
        self:action()
    elseif key == "backspace" then
        if #self.text ~= 0 then
            self.text = string.sub(self.text, 1, utf.offset(self.text, -1) - 1)
            self:updateCarette(true)
        end
    end
end

function TextField:textinput(text)
    self.text = self.text .. text

    self:updateCarette()
end

function TextField:tick(dt)
    if self.focus then
        self.caretteTimer = self.caretteTimer + dt

        if self.caretteTimer >= TEXT_CARETTE_BLINK_PERIOD then
            self.caretteTimer = self.caretteTimer - TEXT_CARETTE_BLINK_PERIOD
            self.caretteVisibility = not self.caretteVisibility
        end
    end
end

function TextField:gainFocus()
    uiobj.class.gainFocus(self)

    self.caretteVisibility = true
    self.caretteTimer = 0
end

function TextField:loseFocus()
    uiobj.class.loseFocus(self)

    self.caretteVisibility = false
end

setmetatable(TextField, {__index = uiobj.class}) -- Set parenthesis

textfield.class = TextField

-- textfield fnc

---Create new TextField object from object prototype
---@param prototype ObjectPrototype
---@return TextField
function textfield.new(prototype)
    local obj = uiobj.new(prototype)

    setmetatable(obj, TextField_meta)---@cast obj TextField

    obj.text = tostring(obj.text)

    obj.textX = TEXT_OFFSET_LEFT
    obj.textY = TEXT_OFFSET_TOP

    obj.lineHeight = obj.font:getHeight()
    obj:updateCarette()

    -- oneline check
    if type(obj.oneline) == "nil" then
        if (obj:getHeight() - TEXT_OFFSET_TOP * 2)/obj.lineHeight <= 2 then ---@todo use protected parameters instead of getters (scope issue)
            obj.oneline = true
        end
    end

    if obj.oneline then
        obj.textY = math.floor(obj:getHeight()/2 - obj.lineHeight/2)
    end

    return obj
end

return textfield