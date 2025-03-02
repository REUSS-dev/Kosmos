io.stdout:setvbuf("no")

function love.load()
    love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";src/?.lua")

    love.keyboard.setKeyRepeat(true)
    local gui = require("libs.stellargui").hook()
    gui.loadExternalObjects()
end

function love.update(dt)
    
end

function love.draw()
    
end