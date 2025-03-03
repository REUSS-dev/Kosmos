-- stellar
local stellar = {}

print((...):match("^(.*%.?[^.]+)$"):gsub("%.", "/"))

local selfpath = (...):match("^(.*%.?[^.]+)$"):gsub("%.", "/")
love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";" .. love.filesystem.getRequirePath():gsub("(%?%.lua)", selfpath .. "/%1"))
print(love.filesystem.getRequirePath())

local ffi = require("ffi")

local paletteClass = require("classes.Palette")

-- documentation

---@meta
---@diagnostic disable

---@alias pixels number Amount of pixels.
---@alias seconds number Amount of seconds
---@alias DimensionsXYWH {[1]: pixels, [2]: pixels, [3]: pixels, [4]: pixels} Structure for some object's X position, Y position, width and height.

---@alias ObjectDescriptor {name: string, aliases: string[]?, new: (fun(prototype: ObjectPrototype):ObjectUI), rules: ObjectParsingRule[], cursors: table<string, love.Cursor>?, construct: fun(ObjectDefinition): ObjectUI}

---@alias ObjectDefinition table Table, which contains UI object definition fields, and is to be processed by UI object definition Parser
---@alias ObjectParser fun(definition: ObjectDefinition, sink: ObjectPrototype):boolean A function, that processes UI object definition and outputs prepared parameters into sink. If it fails to process given definition, it will return false.
---@alias ObjectParserName string
---@alias ObjectParsingRule ObjectParserName|function|{[1]: ObjectParserName, [2]: ObjectDefinition}|{[1]: string[], [2]: string, [3]: ObjectDefinition, [4]: ParsingRule[]?}
---@alias ObjectPrototype table Table, which contains valid object keys and parameters. Usually returned from parseDefinition

---@alias registeredIndex number Index of the registered UI object that it can be referenced by in lib functions

-- config

local externalTypesDir = selfpath .. "/classes/objects"

-- consts

local PATTERN_FILENAME = "[^\\/]+$"

local DEFAULT_CURSOR = "arrow"
local DEFAULT_DOUBLE_CLICK_TIME = 0.5

-- vars

local currentCursor = DEFAULT_CURSOR ---@type love.CursorType
local doubleClickTime = DEFAULT_DOUBLE_CLICK_TIME


local object_descriptors = {}       ---@type table<string, ObjectDescriptor>
local definition_parsers = {}       ---@type {[string]: ObjectParser} Collection of parsers for UI objects parameters
local cursorStorage = {}            ---@type {[love.CursorType|string]: love.Cursor}

local registeredObjects = {}        ---@type {[registeredIndex]: ObjectUI} Currently registered objects in the system that are eligible for update and draw.
local registeredAssociative = {}    ---@type {[ObjectUI]: registeredIndex} Associative array of registered objects used to get registration index by object reference

local currentHl                     ---@type ObjectUI UI object mouse cursor currently on
local heldObject = {}               ---@type ObjectUI UI object last mousepressed event was on (table element for every mouse button)
local focusedObject                 ---@type ObjectUI UI object that currently has keyboard focus

-- Double click detection
local lastClickTime, lastClickButton, lastClickPosition, lastClickedObject = 0, 0, {-1, -1}, nil

-- init

local love = love -- НЕ УДАЛЯТЬ. Предотвращает варнинги в других местах, где объявляются коллбеки love
local nopFunc = function() end
local love_update, love_draw, love_mousepressed, love_mousereleased, love_keypressed, love_keyreleased, love_textinput = love.update or nopFunc, love.draw or nopFunc, love.mousepressed or nopFunc, love.mousereleased or nopFunc, love.keypressed or nopFunc, love.keyreleased or nopFunc, love.textinput or nopFunc

setmetatable(registeredAssociative, {__mode = 'k'})

setmetatable(stellar, {
    __index = function (self, key)
        if object_descriptors[key] then
            return object_descriptors[key].construct
        end
    end
})

setmetatable(cursorStorage, {
    __index = function (self, key)
        self[key] = love.mouse.getSystemCursor(key)
        return self[key]
    end
})

--- Figuring out the doubleclick time in windows

if love.system.getOS() == "Windows" then
    ffi.cdef[[
        uint32_t GetDoubleClickTime();
    ]]
    
    doubleClickTime = ffi.C.GetDoubleClickTime() / 1000
end

-- fnc

---Standard update function for the functionality of StellarGUI
---@param dt seconds
local function stellar_update(dt)
    local hlObject

    local x, y = love.mouse.getX(), love.mouse.getY()

    for _, registered in pairs(registeredObjects) do
        hlObject = registered:isActive() and registered:checkHover(x, y) or hlObject
    end

    ---@cast hlObject ObjectUI?

    if hlObject ~= currentHl then
        local newCursor = DEFAULT_CURSOR

        if currentHl then
            currentHl:hoverOff(x, y)
        end

        if hlObject then
            newCursor = hlObject:hoverOn(x, y) or newCursor
        end

        if newCursor ~= currentCursor then
            currentCursor = newCursor
            love.mouse.setCursor(cursorStorage[newCursor])
        end

        currentHl = hlObject
    end

    for _, registered in pairs(registeredObjects) do
        if registered:isActive() then
            registered:tick(dt)
        end
    end
end

---Standard draw function for the functionality of StellarGUI
local function stellar_draw()
    love.graphics.push("transform")

    for _, registered in pairs(registeredObjects) do
        if registered:isDrawn() then
            love.graphics.translate(registered:getTranslation())
            registered:paint()
            love.graphics.origin()
        end
    end

    love.graphics.pop()
end

--#region Parsers collection

---Parser for object width and height.<br>Will parse size (ex. width = 200, height = 100) correctly if it is defined in the definition table as any of following:<br>{0, 0, 200, 100}<br>{"objectName", 0, 0, 200, 100}<br>{w = 200, h = 100}<br>{width = 200, height = 100}<br>{ size = {200, 100} }
---@type ObjectParser
function definition_parsers.sizeRectangular(def, sink)
    local width = sink.w or def.w or def.width or (def.size or {})[1] or (type(def[1]) == "number") and def[3] or (type(def[2]) == "number") and def[4]
    local height = sink.h or def.h or def.height or (def.size or {})[2] or (type(def[1]) == "number") and def[4] or (type(def[2]) == "number") and def[5]

    sink.w = width
    sink.h = height

    if not width or not height then
        return false
    end

    return true
end

---Parser for object position on the screen.<br>Will parse position (ex. x = 200, y = 100) correctly if it is defined in the definition table as any of following:<br>{200, 100}<br>{"objectName", 200, 100}<br>{x = 200, y = 100}<br>{horizontal = 200, vertical = 100}<br>{ position = {200, 100} }<br>{ pos = {200, 100} }<br>{ coordinates = {200, 100} }<br>**Also supports setting one of the dimensions to the string<br>"center"/"centered"/"middle"/"mid" (any of the following) to center object's position based on its size.<br>Also supports negative coordinates.<br>Position of the object will be counted from the other edge of screen in this case (respecting object's size)**
---@type ObjectParser
function definition_parsers.position(def, sink)
    local x = sink.x or def.x or def.horizontal or (def.position or {})[1] or (def.pos or {})[1] or (def.coordinates or {})[1] or (type(def[1]) == "number") and def[1] or (type(def[2]) == "number") and def[2]
    local y = sink.y or def.y or def.vertical or (def.position or {})[2] or (def.pos or {})[2] or (def.coordinates or {})[2] or (type(def[1]) == "number") and def[2] or (type(def[2]) == "number") and def[3]

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    if type(x) == "string" then
        if x == "center" or x == "centered" or x == "middle" or x == "mid" then
            x = math.floor(sw/2-sink.w/2)
        else
            x = nil
        end
    elseif x and x < 0 then
        x = sw - sink.w + x
    end

    if type(y) == "string" then
        if y == "center" or y == "centered" or y == "middle" or y == "mid" then
            y = math.floor(sh/2-sink.h/2)
        else
            y = nil
        end
    elseif y and y < 0 then
        y = sh - sink.h + y
    end

    sink.x = x
    sink.y = y

    if not x or not y then
        return false
    end

    return true
end

function definition_parsers.palette(def, sink)
    local palette = def.palette or def.palete or def.colors

    if palette then
        if type(palette) == "table" and palette.container then
            sink.palette = palette
            return true
        end

        sink.palette = paletteClass.new(palette)
        return true
    end

    local color = def.color or def.mainColor or def.colorMain or def.main_color
    local text = def.textColor or def.colorText or def.text_color
    local alt = def.frameColor or def.colorFrame or def.additionalColor or def.colorAdditional or def.bgColor or def.hlColor

    if sink.palette then
        if not sink.palette:getColorByIndex(1) then
            sink.palette:setColor(1, color)
        end
        if not sink.palette:getColorByIndex(2) then
            sink.palette:setColor(2, text)
        end
        if not sink.palette:getColorByIndex(3) then
            sink.palette:setColor(3, alt)
        end

        return true
    end

    sink.palette = paletteClass.new({color, text, alt})

    if not color or not text or not alt then
        return false        
    end

    return true
end

--#endregion

---Parse provided definition into object prototype
---@param definition ObjectDefinition
---@param rules ObjectParsingRule[]
---@return ObjectPrototype
local function parseDefinition(definition, rules)
    local objectPrototype = {}
    
    for _, parser in ipairs(rules) do
        if type(parser) == "string" then -- 1. Stupid parsing (not aware of failure)
            definition_parsers[parser](definition, objectPrototype)
        elseif type(parser) == "function" then -- 2. Custom object type-provided parser
            parser(definition, objectPrototype)
        elseif type(parser) == "table" then
            if type(parser[1]) == "string" then -- 3. Parsing with default value set
                if not definition_parsers[parser[1]](definition, objectPrototype) then
                    definition_parsers[parser[1]](parser[2], objectPrototype)
                end
            elseif type(parser[1]) == "table" then -- 4. Simple parsing
                local possibleInputNames, outputName, defaultValue, appliedRules = parser[1], parser[2], parser[3], parser[4]
                local value

                for _, name in ipairs(possibleInputNames) do
                    if type(definition[name]) ~= "nil" then
                        value = definition[name]
                        break
                    end
                end

                if type(value) == "nil" then
                    value = defaultValue
                end

                if not appliedRules then -- 4.1. Generalized passthrough
                    objectPrototype[outputName] = value
                else -- 4.2 Generalized recursive parsing
                    objectPrototype[outputName] = parseDefinition(value, appliedRules)
                end
            end
        end
    end

    return objectPrototype
end

---@debug parsing test print(parseDefinition({numb = false, aquarium = {12, 123}}, {{"position", {10, 20}}, {{"isWhale"}, "fish", "false"}, {{"numb"}, "n", 123}, {{"fishtank", "aquarium"}, "aqua", {}, {"position"}}}).aqua.x)

---Register UI object type descriptor
---@param typeDescriptor ObjectDescriptor
local function registerType(typeDescriptor)
    function typeDescriptor.construct(def)
        local prototype = parseDefinition(def, typeDescriptor.rules)
        return typeDescriptor.new(prototype)
    end

    object_descriptors[typeDescriptor.name] = typeDescriptor

    if typeDescriptor.aliases then
        for _, alias in ipairs(typeDescriptor.aliases) do
            object_descriptors[alias] = typeDescriptor
        end        
    end

    if typeDescriptor.cursors then
        for cursorName, cursor in pairs(typeDescriptor.cursors) do
            cursorStorage[cursorName] = cursor
        end
    end
end

-- classes

---UI objects meta-parent, UI state can be manipulated through this object. Meant to be singleton
---@class StateUI : ObjectUI
local StateUI = {}

--Volunteerly revoke focus from self and optionally give it to another object.
---@param origin ObjectUI
---@param successor ObjectUI?
function StateUI:revokeFocus(origin, successor)
    if focusedObject == origin then
        focusedObject:loseFocus()
        
        if successor and successor:isInteractible() then
            focusedObject = successor
            successor:gainFocus()
        end
    end
end

---Change current system cursor type
---@param origin ObjectUI
---@param type love.CursorType
function StateUI:setCursor(origin, type)
    if type ~= currentCursor then
        currentCursor = type
        love.mouse.setCursor(cursorStorage[type])
    end
end

-- stellar fnc

---Register the UI object descriptor in a system for update and draw
---@param uiobj ObjectUI A UI object to register
---@return registeredIndex index Index of a registered UI object that it can be referenced by in other functions
function stellar.register(uiobj)
    local newIndex = #registeredObjects+1

    uiobj.parent = StateUI

    registeredAssociative[uiobj] = newIndex
    registeredObjects[newIndex] = uiobj

    return newIndex
end

function stellar.unregister(uiobj)
    local registeredIndex

    if type(uiobj) == "table" then
        registeredIndex = registeredAssociative[uiobj]

        if not registeredIndex then
            return false
        end
    elseif type(uiobj) == "number" then
        if registeredObjects[uiobj] then
            registeredIndex = uiobj
        else
            return false
        end
    end

    registeredObjects[uiobj] = nil
    return true
end

function stellar.loadExternalObjects(path)
    local path = path or externalTypesDir

    if not love.filesystem.exists(path) then
        print(string.format("Failed loading object from %s. Path does not exist", path))
        return
    end

    if love.filesystem.isFile(path) then
        local objectFileChunk = love.filesystem.load(path)

        if not objectFileChunk then
            print(string.format("Failed loading object from %s. Compilation failed", path))
            return
        end

        local descriptor = objectFileChunk()

        if type(descriptor) ~= "table" or not descriptor.name then
            print(string.format("Failed loading object from %s. Bad returning or table is not an object descriptor", path))
            return
        end

        registerType(descriptor)

        print(string.format("Loaded object %s from %s, aliases: %s", descriptor.name, path, table.concat(descriptor.aliases or {}, ", ")))

        return true
    end

    local items = love.filesystem.getDirectoryItems(path)

    for _, item in ipairs(items) do
        print(string.format("Loading object from %s", path .. "/" .. item))
        stellar.loadExternalObjects(path .. "/" .. item)
    end
end

--#region Debug functions

function stellar.drawMousePosition()
    love.graphics.setColor(
        love.mouse.isDown(1) and {0.3, 0.3, 1, 1} or 
        love.mouse.isDown(2) and {1, 0.3, 0.3, 1} or 
        love.mouse.isDown(3) and {0.3, 1, 0.3, 1} or
        love.mouse.isDown(4, 5, 6) and {1, 1, 0, 1} or
        {1, 1, 1, 1}
    )

    love.graphics.print(love.mouse.getX() .. "; " .. love.mouse.getY(), 0, 0)
end

--#endregion

--- Stellar hook

function stellar.hook()
    love.update = function(dt)
        love_update(dt)
        stellar_update(dt)
    end

    love.draw = function()
        love_draw()
        stellar_draw()
    end

    love.mousepressed = function (x, y, but)
        if currentHl then
            if currentHl:isInteractible() then
                heldObject[but] = currentHl

                if focusedObject ~= currentHl then
                    if focusedObject then
                        focusedObject:loseFocus()
                    end

                    focusedObject = currentHl
                    focusedObject:gainFocus()
                end

                currentHl:click(x, y, but)

                -- Double click shenanigans
                if
                    love.timer.getTime() - lastClickTime <= doubleClickTime and 
                    but == lastClickButton and
                    lastClickedObject == currentHl and
                    x == lastClickPosition[1] and y == lastClickPosition[2]
                then
                    currentHl:doubleClick(x, y, but)
                    lastClickTime = 0 -- avoid counting possible third click as double click
                    return
                end

                lastClickButton, lastClickTime, lastClickPosition[1], lastClickPosition[2], lastClickedObject = but, love.timer.getTime(), x, y, currentHl
            end
        else
            if focusedObject then
                focusedObject:loseFocus()
                focusedObject = nil
            end

            love_mousepressed(x, y, but)
        end
    end

    love.mousereleased = function (x, y, but)
        if heldObject[but] then

            if heldObject[but]:isInteractible() then
                if not heldObject[but]:clickRelease(x, y, but) then
                    heldObject[but] = nil
                    return
                end
            end

            if currentHl and (heldObject[but] ~= currentHl) and currentHl:isInteractible() then
                currentHl:clickReleaseExterior(x, y, but, heldObject[but])

                heldObject[but] = nil
                return
            end
        else
            love_mousereleased(x, y, but)
        end
    end

    love.keypressed = function (key, scancode, isrepeat)
        if focusedObject and focusedObject:isInteractible() then
            if focusedObject:keyPress(key, scancode, isrepeat) then
                focusedObject:loseFocus()
                focusedObject = nil
            end
        else
            love_keypressed(key, scancode, isrepeat)
        end
    end

    love.keyreleased = function (key, scancode, isrepeat)
        if focusedObject and focusedObject:isInteractible() then
            if focusedObject:keyRelease(key, scancode, isrepeat) then
                focusedObject:loseFocus()
                focusedObject = nil
            end
        else
            love_keyreleased(key, scancode, isrepeat)
        end
    end

    love.textinput = function (text)
        if focusedObject and focusedObject:isInteractible() then
            focusedObject:textinput(text)
        else
            love_textinput(text)
        end
    end

    return stellar
end

return stellar