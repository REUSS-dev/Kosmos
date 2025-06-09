-- textfield
local textfield = {}

local uiobj = require("classes.ObjectUI")

local utf = require("utf8")

-- documentation

---@alias TextFieldDisplayTable {caretteX: integer, horizontalScroll: integer, verticalScroll: integer, beginLine: integer, lastLine: integer, lineYOffset: integer}
---@alias TextFieldCaretteParameters {line: integer, char: integer, nominalChar: integer}

-- config

textfield.name = "TextField"
textfield.aliases = {}
textfield.rules = {
    {"sizeRectangular", {0, 0, 100, 50}},
    {"position", {position = {"center", "center"}}},

    {"palette", {color = {1, 1, 1, 1}, textColor = {0, 0, 0, 1}, additionalColor = {0.5, 0.5, 0.5, 1}}},

    {{"action", "enter", "return"}, "action", function() end},
    {{"text"}, "text", ""},
    {{"placeholder", "default", "defaultText"}, "placeholder", ""},
    {{"font"}, "font", love.graphics.getFont()},
    {{"oneline", "forceOneline", "force_oneline"}, "oneline", nil},
    {{"r", "radius", "rounding", "round"}, "r", nil},
    {{"password"}, "password", false}
}

-- consts

local TEXT_OFFSET_LEFT = 5
local TEXT_OFFSET_TOP = 5

local TEXT_CARETTE_BLINK_PERIOD = 0.5

local PROTECT_NEWLINE_SYMBOL = "\x0C"

local PASSWORD_CHAR = "*"

-- vars



-- init



-- fnc

local function utf_len_exclude_newline(str)
    local length = utf.len(str)

    if str:sub(-1, -1) == "\n" then
        return length - 1
    end

    return length
end

local function protectNewline(textOrTable)
    if type(textOrTable) == "table" then
        for i = 1, #textOrTable do
            textOrTable[i] = protectNewline(textOrTable[i])
        end
    else
        return textOrTable:gsub("\r?\n", PROTECT_NEWLINE_SYMBOL .. "\n")
    end
end

local function convertNewlineMarker(textOrTable)
    if type(textOrTable) == "table" then
        for i = 1, #textOrTable do
            textOrTable[i] = convertNewlineMarker(textOrTable[i])
        end
    else
        return textOrTable:gsub(PROTECT_NEWLINE_SYMBOL, "\n")
    end
end

-- classes

---@class TextField : ObjectUI
---@field text string[]
---@field font love.Font
---@field action fun(self: TextField)
---@field stencil fun() 
---@field textX number X text offset from TextField origin
---@field textY number Y text offset from TextField origin
---@field textareaW number Width of actual text display area
---@field textareaH number Height of actual text display area
---@field private caretteVisibility boolean
---@field private caretteTimer number
---@field carettePosition TextFieldCaretteParameters Carette X and Y position (in characters, lines)
---@field lineHeight number To be PRIVATED
---@field oneline boolean To be PRIVATED
---@field display TextFieldDisplayTable Display parameters and cache
---@field r number Radius of round corner
---@field password boolean Flag. If set to true, all displayed characters should be PASSWORD_CHAR
---@field placeholder string Placeholder text. Printed with Palette.additionalColor if no text is present
local TextField = { defaultCursor = "ibeam" }
local TextField_meta = {__index = TextField}

---Update carette position
---@param noreset boolean? Do not reset carette timer
function TextField:updateCarette(noreset)
    if not noreset then
        self.caretteTimer = 0
        self.caretteVisibility = self.focus and true
    end

    if not self.password then
        self.display.caretteX = self.font:getWidth(string.sub(self.text[self.carettePosition.line], 1, utf.offset(self.text[self.carettePosition.line], self.carettePosition.char + 1) - 1))
    else
        self.display.caretteX = self.font:getWidth(string.rep(PASSWORD_CHAR, self.carettePosition.char))
    end
end


function TextField:setCarette(char, line, keep_nominal)
    local carette = self.carettePosition

    if not keep_nominal then
        carette.nominalChar = char
    end

    if line < 1 then
        return
    end

    if line > #self.text then
        carette.line = #self.text
        carette.char = utf_len_exclude_newline(self.text[#self.text])
        carette.nominalChar = carette.char

        self:updateCarette()
        return
    end

    if char > utf_len_exclude_newline(self.text[line]) then
        char = utf_len_exclude_newline(self.text[line])
    end

    carette.line = line
    carette.char = char

    self:updateCarette()

    ---@todo SCROLL UPDATE
end

---Move carette horizontally and vertically
---@param x integer Horizontal movement. -1 for left, 1 for right, 0 for unchanged
---@param y integer Vertical movement. -1 for up, 1 for down, 0 for unchanged
function TextField:moveCarette(x, y)
    x, y = x or 0, y or 0

    local char, line = self.carettePosition.char, self.carettePosition.line

    local keep_nominal

    if x > 0 then
        char = char + 1

        if char > utf_len_exclude_newline(self.text[line]) then
            char = 0
            line = line + 1
        end
    elseif x < 0 then
        char = char - 1

        if char < 0 then
            line = line - 1
            char = utf_len_exclude_newline(self.text[line] or "")
        end
    end

    if y > 0 then
        line = line + 1
        char = self.carettePosition.nominalChar
        keep_nominal = true
    elseif y < 0 then
        line = line - 1
        char = self.carettePosition.nominalChar
        keep_nominal = true
    end

    self:setCarette(char, line, keep_nominal)
end

---Updates display parameters beginLine, lineLast, lineYOffset according to scroll
function TextField:updateDisplay()
    local display = self.display

    display.lineYOffset = display.verticalScroll % self.lineHeight

    display.beginLine = math.floor(display.verticalScroll / self.lineHeight) + 1

    local free_height = self.textareaH - self.lineHeight + display.lineYOffset
    display.lastLine = display.beginLine + math.ceil(free_height / self.lineHeight)

    -- normalize last line
    if display.lastLine > #self.text then
        display.lastLine = #self.text
    end
end

function TextField:doWrap()
    local new_text = {}

    for i = 1, #self.text do
        -- Since LOVE 11.4 love.Font:getWrap() does not leave CR at the end of the line
        -- when wrapping CRLF newlines. This is very bad as now we do not currently have 
        -- an easy method of telling apart the CRLF wrap from the limit-reach wrap
        -- based on the resulting lines table. CR is a zero-width breaking symbol,
        -- that didn't mess up wrapping logic and was very convenient for that purpose.
        --
        -- Currently, we use a small, invisible symbol before every CRLF newline,
        -- that MESSES UP wrapping; behaviour of space-ending line and
        -- newline-ending line is different during wrapping. Very sad.
        local prepared_text = protectNewline(self.text[i])

        local _, wrapped = self.font:getWrap(prepared_text, self.textareaW - self.font:getWidth(" "))
    
        if #wrapped ~= 0 then
            for j = 1, #wrapped do
                new_text[#new_text+1] = convertNewlineMarker(wrapped[j])
            end
        else
            new_text[#new_text+1] = ""
        end
    end

    self.text = new_text
end

function TextField:updateWrap()
    -- Calcaulate and save carette absoute location (in bytes)
    local carette_absolute_location = 0

    for i = 1, self.carettePosition.line - 1 do
        carette_absolute_location = carette_absolute_location + utf.len(self.text[i])
    end

    carette_absolute_location = carette_absolute_location + self.carettePosition.char

    -- Recalculate wrap
    self:setText(self:getText())

    -- Carette set
    for i = 1, #self.text do
        local lineLength = utf.len(self.text[i])

        if carette_absolute_location >= lineLength then
            carette_absolute_location = carette_absolute_location - lineLength
        else
            self:setCarette(carette_absolute_location, i)
            return
        end
    end

end

function TextField:getText()
    return table.concat(self.text)
end

function TextField:setText(text)
    self.text = {tostring(text)}

    self:doWrap()
    self:updateDisplay()
    self:setCarette(0, math.huge)
end

function TextField:paint()
    love.graphics.setColor(self.palette[1])
    love.graphics.rectangle("fill", 0, 0, self.w, self.h, self.r)

    love.graphics.setColor(self.palette[3])
    love.graphics.rectangle("line", 0, 0, self.w, self.h, self.r)

    love.graphics.stencil(self.stencil, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    love.graphics.setColor(self.palette[2])
    love.graphics.setFont(self.font)
    for i = self.display.beginLine, self.display.lastLine do
        local lineI = i - self.display.beginLine

        if not self.password then
            love.graphics.print(self.text[i], self.textX, self.textY - self.display.lineYOffset + lineI * self.lineHeight)
        else
            love.graphics.print(string.rep(PASSWORD_CHAR, utf.len(self.text[i])), self.textX, self.textY - self.display.lineYOffset + lineI * self.lineHeight)
        end
    end

    if self.caretteVisibility then
        if self.display.beginLine <= self.carettePosition.line and self.carettePosition.line <= self.display.lastLine then
            love.graphics.rectangle("fill", self.textX + self.display.caretteX, self.textY - self.display.lineYOffset + self.lineHeight * (self.carettePosition.line - self.display.beginLine), 1, self.lineHeight)
        end
    end

    if #self.text == 1 and #self.text[1] == 0 and not self:hasFocus() then
        love.graphics.setColor(self.palette[3])
        love.graphics.print(self.placeholder, self.textX, self.textY - self.display.lineYOffset)
    end

    love.graphics.setStencilTest()
end

function TextField:textinput(text)
    local carette_char, carette_line = self.carettePosition.char, self.carettePosition.line

    local cur_line = self.text[carette_line]

    self.text[carette_line] = cur_line:sub(1, utf.offset(cur_line, carette_char + 1) - 1) .. text .. cur_line:sub(utf.offset(cur_line, carette_char + 1), -1)

    self:moveCarette(1, 0)
    self:updateWrap()
end

function TextField:newline()
    local carette_char, carette_line = self.carettePosition.char, self.carettePosition.line

    local cur_line = self.text[carette_line]

    self.text[carette_line] = cur_line:sub(1, utf.offset(cur_line, carette_char + 1) - 1) .. "\n"

    local new_line = cur_line:sub(utf.offset(cur_line, carette_char + 1), -1)
    table.insert(self.text, carette_line + 1, new_line)

    self:setCarette(0, carette_line + 1)
    self:updateWrap()
end

function TextField:backspace()
    local carette_char, carette_line = self.carettePosition.char, self.carettePosition.line

    if carette_char > 0 then -- Remove character from current line
        local cur_line = self.text[carette_line]

        self.text[carette_line] = cur_line:sub(1, utf.offset(cur_line, carette_char) - 1) .. cur_line:sub(utf.offset(cur_line, carette_char + 1), -1)
        self:moveCarette(-1, 0)
    elseif carette_line > 1 then -- Append lines (backspace at char 0)
        -- Cut last character of previous line
        self.text[carette_line - 1] = self.text[carette_line - 1]:sub(1, utf.offset(self.text[carette_line - 1], -1) - 1)

        -- Move cursor left
        self:moveCarette(-1, 0)
    end

    self:updateWrap()
end

function TextField:keyPress(key)
    if key == "return" then
        if self.oneline then
            self:action()
        else
            if love.keyboard.isDown("lctrl") then
                self:action()
            else
                self:newline()
            end
        end
    elseif key == "backspace" then
        self:backspace()
    elseif key == "left" then
        self:moveCarette(-1, 0)
    elseif key == "right" then
        self:moveCarette(1, 0)
    elseif key == "up" then
        self:moveCarette(0, -1)
    elseif key == "down" then
        self:moveCarette(0, 1)
    end
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

    obj.textX = TEXT_OFFSET_LEFT
    obj.textY = TEXT_OFFSET_TOP
    obj.textareaW = obj.w - obj.textX * 2
    obj.textareaH = obj.h - obj.textX * 2

    obj.lineHeight = obj.font:getHeight()

    function obj.stencil()
        love.graphics.rectangle("fill", obj.textX, obj.textY, obj.textareaW, obj.textareaH)
    end

    -- oneline check
    if type(obj.oneline) == "nil" then
        if (obj.h - TEXT_OFFSET_TOP * 2)/obj.lineHeight <= 2 then ---@todo use protected parameters instead of getters (scope issue)
            obj.oneline = true
        end
    end

    if obj.oneline then
        obj.textY = math.floor(obj:getHeight()/2 - obj.lineHeight/2)
    end

    obj.carettePosition = {}
    obj.display = {}

    obj.display.horizontalScroll = 0
    obj.display.verticalScroll = 0
    obj:updateDisplay()
    obj:setText(obj.text)

    obj:updateCarette()

    return obj
end

return textfield