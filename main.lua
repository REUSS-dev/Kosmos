io.stdout:setvbuf("no")

function love.load()
    love.keyboard.setKeyRepeat(true)
    local gui = require("libs.stellargui").hook()
    gui.loadExternalObjects()
    gui.loadExternalObjects("ui")

    local font = love.graphics.newFont("resources/font.ttf", 18)

    gui.register(
        gui.Button{
            y = 100,
            color = {0.75, 0.75, 0, 0.5},
            text = "Сервер",
            font = font
        }
    )
end

function love.update(dt)
end

function love.draw()
end