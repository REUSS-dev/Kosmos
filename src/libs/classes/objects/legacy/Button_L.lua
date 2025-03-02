-- button_legacy
local button_legacy = {}

local uiobj = require("classes.ObjectUI")

-- documentation



-- config

button_legacy.name = "Button_L"
button_legacy.aliases = {}
button_legacy.rules = {
    {"sizeRectangular", {0, 0, 100, 50}},
    {"position", {position = {"center", "center"}}},
    {"palette", {color = {0, 0.5, 0}, text = {1, 1, 1}}}
}

-- consts



-- vars



-- init



-- fnc



-- classes

---@class Button_L : ObjectUI
local Button_L = {}
local Button_L_meta = {__index = Button_L}

function Button_L:paint()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end

function Button_L:hoverOn()
    self.color = {1,0,0}

    return "hand"
end

function Button_L:hoverOff()
    self.color = self.palette[1]
end

function Button_L:click()
    self.color = {0,0,1}
end

function Button_L:clickRelease()
    self.color = {0,1,0}
end

function Button_L:gainFocus()
    print("gained focus", self)
end

function Button_L:loseFocus()
    print("lost focus", self)
end

function Button_L:keyPress(key)
    print("pressed key", key, self)
    if key == "escape" then
        return true
    end
end

function Button_L:keyRelease(key)
    print("released key", key, self)
end

function Button_L:textinput(key)
    print("text", key, self)
end

setmetatable(Button_L, {__index = uiobj.class}) -- Set parenthesis

button_legacy.class = Button_L

-- button_legacy fnc

function button_legacy.new(prototype)
    local obj = uiobj.new(prototype)
    ---@cast obj Button_L
    
    obj.color = {1,1,1}

    setmetatable(obj, Button_L_meta)

    return obj
end

return button_legacy