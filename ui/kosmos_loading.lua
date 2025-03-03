-- button
local button = {}

local uiobj = require("classes.ObjectUI")

local utf = require("utf8")

-- documentation

---@alias radians number Number value in radians

-- config

button.name = "KosmosLoading"
button.aliases = {}
button.rules = {
    {"sizeRectangular", {0, 0, 50, 50}},
    {"position", {position = {"center", "center"}}},

    {"palette", {color = {0, 0.5, 0, 0.4}, textColor = {1, 1, 1}}},

    {{"text", "label"}, "text", "LoadingLoading"},
    {{"font"}, "font", love.graphics.getFont()}
}

-- consts

local JUMPING_INTERVAL = 1

-- vars



-- init



-- fnc



-- classes

---@class KosmosLoading : ObjectUI
---@field text string Button text
---@field font love.Font Button text font
---@field udt number
---@field r number
---@field symbols string[]
---@field symbolsCount integer
---@field symbolsRadianOffset radians[]
---@field previousJumping integer
local KosmosLoading = { }
local KosmosLoading_meta = {__index = KosmosLoading}
setmetatable(KosmosLoading, {__index = uiobj.class}) -- Set parenthesis

function KosmosLoading:paint()
    love.graphics.translate(self.r, self.r)
    love.graphics.setFont(self.font)

    local jumping = math.floor(self.udt / JUMPING_INTERVAL) % self.symbolsCount + 1

    if jumping ~= self.previousJumping then
        self.previousJumping = jumping
        self.particleSystem:emit(30)
    end

    for i = 1, self.symbolsCount do
        local letterRadian = self.symbolsRadianOffset[i] + self.udt
        local rotation = letterRadian + math.pi / 2

        local charWidth = self.font:getWidth(self.symbols[i]) / 2

        --love.graphics.circle("line", 0, 0, self.r)

        if self.previousJumping - 1 == (i % self.symbolsCount) then
            local charHeight = self.font:getHeight() / 2
            local charCenterX = charWidth / self.r
            
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.particleSystem, (self.r - charHeight) * math.cos(letterRadian + charCenterX) + charWidth * math.cos(rotation - math.pi), (self.r - charHeight) * math.sin(letterRadian + charCenterX) + charWidth * math.sin(rotation - math.pi) + charHeight)
            love.graphics.setColor(self.palette[2])
            love.graphics.print(self.symbols[i], self.r * math.cos(letterRadian) + charWidth * math.cos(rotation - math.pi), self.r * math.sin(letterRadian) + charWidth * math.sin(rotation - math.pi), rotation)
        elseif jumping ~= i then
            love.graphics.setColor(self.palette[2])
            love.graphics.print(self.symbols[i], self.r * math.cos(letterRadian) + charWidth * math.cos(rotation - math.pi), self.r * math.sin(letterRadian) + charWidth * math.sin(rotation - math.pi), rotation)
        else
            local jumpingProgress = ((JUMPING_INTERVAL * (math.floor(self.udt / JUMPING_INTERVAL) + 1) - self.udt)/JUMPING_INTERVAL - 1)^2

            local radiusMultiplier = 1/3 + (1/2 - 1/3) * (math.abs((jumpingProgress - 0.5)) - 0.5)^2

            local jumpingX = self.r * radiusMultiplier * math.cos(letterRadian + 2*math.pi*jumpingProgress - math.pi)
            local jumpingY = self.r * radiusMultiplier * math.sin(letterRadian + 2*math.pi*jumpingProgress - math.pi)

            love.graphics.setColor(0.8, 0.8, 0.5, 0.25)
            for x = -1, 1 do
                for y = -1, 1 do
                    love.graphics.print(self.symbols[i], 2.5*x + (1 + radiusMultiplier)*self.r * math.cos(letterRadian) + charWidth * math.cos(rotation - math.pi) + jumpingX, 2*y + (1 + radiusMultiplier)*self.r * math.sin(letterRadian) + charWidth * math.sin(rotation - math.pi) + jumpingY, rotation)
                end
            end

            love.graphics.setColor(self.palette[2])
            love.graphics.print(self.symbols[i], (1 + radiusMultiplier)*self.r * math.cos(letterRadian) + charWidth * math.cos(rotation - math.pi) + jumpingX, (1 + radiusMultiplier)*self.r * math.sin(letterRadian) + charWidth * math.sin(rotation - math.pi) + jumpingY, rotation)
        end

    end
end

function KosmosLoading:tick(dt)
    self.udt = self.udt + dt

    self.particleSystem:update(dt)
end

--#region private

function KosmosLoading:cutText()
    self.symbolsCount = utf.len(self.text)
    self.symbols = { [0] = ""}
    self.symbolsRadianOffset = { [0] = 0 }

    local perimeter = 2*math.pi * self.r
    local textWidth = self.font:getWidth(self.text)

    local freeSpace = 2*math.pi * (perimeter - textWidth) / perimeter / self.symbolsCount

    for i = 1, self.symbolsCount do
        self.symbols[i] = string.sub(self.text, utf.offset(self.text, i), utf.offset(self.text, i + 1) - 1)
        self.symbolsRadianOffset[i] = self.symbolsRadianOffset[i - 1] + freeSpace + 2*math.pi * self.font:getWidth(self.symbols[i - 1])/perimeter
    end
end

function KosmosLoading:createParticleSystem()
    local imagedata = love.image.newImageData(2, 2)
    imagedata:mapPixel(function() return 1, 1, 1, 1 end)
    local particleImage = love.graphics.newImage(imagedata)

    self.particleSystem = love.graphics.newParticleSystem(particleImage, 50)

    self.particleSystem:setParticleLifetime(0.1, JUMPING_INTERVAL)
    self.particleSystem:setColors(1, 1, 0.5, 1, 1, 1, 1, 0)
	self.particleSystem:setLinearAcceleration(-20, 0, 20, 300)
    self.particleSystem:setEmissionArea("uniform", self.font:getHeight()/2, self.font:getHeight()/2)
end

--#endregion

-- button fnc

function button.new(prototype)
    local obj = uiobj.new(prototype)
    ---@cast obj KosmosLoading

    setmetatable(obj, KosmosLoading_meta)

    obj.udt = 0
    obj.r = obj.w / 2

    obj.previousJumping = 1

    obj:cutText()
    obj:createParticleSystem()

    return obj
end

return button