-- composite
local composite = {}

local uiobj = require("classes.ObjectUI")

-- documentation



-- config

composite.name = "CompositeObject"
composite.aliases = {"Composite"}
composite.rules = {}

-- consts



-- vars



-- init



-- fnc



-- classes

---@class CompositeObject : ObjectUI
---@field objects ObjectUI[] List of UI objects inside the composite object
local CompositeObject = {}
local CompositeObject_meta = {__index = CompositeObject}

---Check, if coordinates provided are in boundaries of any of UI objects in the composite object
---@param x pixels Mouse X position in pixels
---@param y pixels Mouse Y position in pixels
---@return ObjectUI|false hover Returns object pointer if the mouse if hovering on the object, false otherwise
function CompositeObject:checkHover(x, y)
    if not uiobj.class.checkHover(self, x, y) then
        return false
    end

    local hlObject

    for _, uiobject in ipairs(self.objects) do
        hlObject = uiobject:isActive() and uiobject:checkHover(x, y) or hlObject
    end

    if not hlObject then
        return false
    end

    return hlObject
end

---CompositeObject must return (0, 0) as its transform to let its encapsulated objects transform correctly
---@return pixels
---@return pixels
function CompositeObject:getTranslation()
    return 0, 0
end

function CompositeObject:unregister(message)
    local halt

    for _, uiobject in ipairs(self.objects) do
        halt = halt or uiobject:unregister(message)
    end

    return halt
end

---Tick all UI objects in a composite object.
---@param dt seconds
function CompositeObject:tick(dt)
    for _, uiobject in ipairs(self.objects) do
        if uiobject:isActive() then
            uiobject:tick(dt)
        end
    end
end

---Paint all UI objects in a composite object.
function CompositeObject:paint()
    for _, uiobject in ipairs(self.objects) do
        if uiobject:isDrawn() then
            love.graphics.translate(uiobject:getTranslation())
            uiobject:paint()
            love.graphics.origin()
        end
    end
end

---Add new object to composite object
---@param obj ObjectUI
function CompositeObject:add(obj)
    obj.parent = self
    self.objects[#self.objects+1] = obj
end

--#region Passthrough static functions

---Volunteerly revoke focus from self and optionally give it to another object.
---@param origin ObjectUI
---@param successor ObjectUI?
function CompositeObject:revokeFocus(origin, successor)
    self.parent:revokeFocus(origin, successor)
end

---Change current system cursor type
---@param origin ObjectUI
---@param type love.CursorType?
function CompositeObject:setCursor(origin, type)
    self.parent:setCursor(origin, type)
end

--#endregion

setmetatable(CompositeObject, {__index = uiobj.class}) -- Set parenthesis

composite.class = CompositeObject

-- composite fnc

---Create new CompositeObject
---@param prototype ObjectPrototype
---@return CompositeObject
function composite.new(prototype)
    local obj = uiobj.new(prototype) ---@cast obj CompositeObject

    obj.objects = {}

    setmetatable(obj, CompositeObject_meta)

    return obj
end

return composite