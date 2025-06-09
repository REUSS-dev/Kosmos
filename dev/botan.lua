local colorText = {1,1,1, 1}
local colorBaseline = {0.5, 0.5, 1, 0.8}
local colorBaseline = {0, 0.5, 0, 0.5}
--local colorBaseline = {1, 1, 0.5, 0.8}

local RADIUS = 20
local cstencilx, cstencily, cstencilw, cstencilh

local function circleStencil()
    love.graphics.circle("fill", cstencilx, cstencily, RADIUS)
    love.graphics.circle("fill", cstencilx + cstencilw, cstencily, RADIUS)
    love.graphics.circle("fill", cstencilx + cstencilw, cstencily + cstencilh, RADIUS)
    love.graphics.circle("fill", cstencilx, cstencily + cstencilh, RADIUS)
end

local function buttonStencil()
    love.graphics.rectangle("fill", 100, 100, 200, 50)
end

local function style1(x, y)
    love.graphics.setColor(colorBaseline[1] * 0.8, colorBaseline[2] * 0.8, colorBaseline[3] * 0.8, colorBaseline[4])
    love.graphics.rectangle("fill", x + 5, y + 5, 200, 50, 20)
    love.graphics.setColor(colorBaseline)
    love.graphics.rectangle("fill", x, y, 200, 50, 20)

    love.graphics.setColor(colorText)
    love.graphics.printf("Sample text", x, y + 25 - love.graphics.getFont():getHeight()/2, 200, "center")
end

local function style2(x, y)
    cstencilx, cstencily, cstencilw, cstencilh = x, y, 200, 50
    RADIUS = 20

    love.graphics.stencil(circleStencil, "increment", 1)
    love.graphics.setStencilTest("equal", 0)
    love.graphics.setColor(colorBaseline[1], colorBaseline[2], colorBaseline[3], 1)
    love.graphics.rectangle("fill", x, y, 200, 50, 20)

    love.graphics.setColor(colorText)
    love.graphics.printf("Sample text", x, y + 25 - love.graphics.getFont():getHeight()/2, 200, "center")
end

local function style3(x, y)
    cstencilx, cstencily, cstencilw, cstencilh = x, y, 200, 50
    RADIUS = 30

    love.graphics.stencil(circleStencil, "increment", 1)
    love.graphics.setStencilTest("equal", 0)
    love.graphics.setColor(colorBaseline[1], colorBaseline[2], colorBaseline[3], 1)
    love.graphics.rectangle("fill", x, y, 200, 50, 20)

    love.graphics.setColor(colorText)
    love.graphics.printf("Sample text", x, y + 25 - love.graphics.getFont():getHeight()/2, 200, "center")
end

local function style4(x, y)
    love.graphics.setColor(colorBaseline[1] * 0.8, colorBaseline[2] * 0.8, colorBaseline[3] * 0.8, colorBaseline[4])
    love.graphics.rectangle("fill", x, y, 200, 50, 15)
    love.graphics.setColor(colorBaseline)
    love.graphics.rectangle("fill", x + 5, y + 5, 200 - 10, 50 - 10, 13)

    love.graphics.setColor(colorText)
    love.graphics.printf("Sample text", x, y + 25 - love.graphics.getFont():getHeight()/2, 200, "center")
end

local function style5(x, y)
    love.graphics.setColor(colorBaseline[1] * 0.8, colorBaseline[2] * 0.8, colorBaseline[3] * 0.8, colorBaseline[4])
    love.graphics.rectangle("fill", x, y, 200, 50)
    love.graphics.setColor(colorBaseline)
    love.graphics.rectangle("fill", x + 3, y + 3, 200 - 6, 50 - 6)

    love.graphics.setColor(colorText)
    love.graphics.printf("Sample text", x, y + 25 - love.graphics.getFont():getHeight()/2, 200, "center")
end

local function style6(x, y)
    love.graphics.setColor(colorBaseline)
    love.graphics.rectangle("fill", x, y, 200, 50, 40, 40, 8)
    love.graphics.setColor(colorBaseline)
    love.graphics.ellipse("fill", x + 100, y + 25, 90, 25, 8)

    love.graphics.setColor(colorText)
    love.graphics.printf("Sample text", x, y + 25 - love.graphics.getFont():getHeight()/2, 200, "center")
end

local function style7(x, y)
    love.graphics.setColor(colorBaseline)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, 200, 50, 20)

    love.graphics.setColor(colorText)
    love.graphics.printf("Sample text", x, y + 25 - love.graphics.getFont():getHeight()/2, 200, "center")
end

local function style8(x, y)
    love.graphics.setColor(colorBaseline)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, 200, 50)

    love.graphics.setColor(colorText)
    love.graphics.printf("Sample text", x, y + 25 - love.graphics.getFont():getHeight()/2, 200, "center")
end