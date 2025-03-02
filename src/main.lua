io.stdout:setvbuf("no")

function love.load()
    love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";src/?.lua")

    love.keyboard.setKeyRepeat(true)
    local gui = require("libs.stellargui").hook()
    gui.loadExternalObjects()

    local angeliclove = require("libs.angeliclove")
    font = love.graphics.newFont("font.ttf", 24)

    local loading = gui.KosmosLoading{ y = 100, w = 100, text = "loadingloxloadinglox", font = angeliclove.new("automata", 10):getFont(), textColor = {1, 0.9, 0.75, 1}}

    gui.register(loading)
end

function love.update(dt)
    
end

function love.draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)
    love.graphics.print(love.timer.getFPS(), 0, 0)
end