io.stdout:setvbuf("no")

function love.load()
    love.keyboard.setKeyRepeat(true)
    local gui = require("libs.stellargui").hook()
    gui.loadExternalObjects()
    gui.loadExternalObjects("ui")

    KOSMO_DEBUG = true

    local font = love.graphics.newFont("resources/font.ttf", 18)

    local lookfor_folder = ""
    local oldRead = love.filesystem.read
    ---@diagnostic disable-next-line: duplicate-set-field
    function love.filesystem.read(container, name, size)
        local actual_name
        local callVariant

        if type(name) == "number" or type(name) == "nil" then
            actual_name = container
            callVariant = 1
        else
            actual_name = name
            callVariant = 2
        end

        if love.filesystem.getInfo("common/" .. actual_name) then
            actual_name = "common/" .. actual_name
        elseif love.filesystem.getInfo(lookfor_folder .. "/" .. actual_name) then
            actual_name = lookfor_folder .. "/" .. actual_name
        end

        if callVariant == 1 then
            return oldRead(actual_name, name)
        else
            return oldRead(container, actual_name, size)
        end
    end

    gui.register(
        gui.Button{
            y = 100,
            w = 300,
            color = {0.75, 0.75, 0, 0.5},
            text = "Сервер",
            font = font,
            action = function ()
                KOSMO_DEBUG = "server"

                love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";common/?.lua;server/?.lua;common/?/init.lua;server/?/init.lua")
                lookfor_folder = "server"
                require("server")
                gui:unregisterAll()
                love.load()
            end
        }
    )

    gui.register(
        gui.Button{
            y = 200,
            w = 300,
            color = {0.25, 0.25, 0.75, 0.5},
            text = "Клиент",
            font = font,
            action = function ()
                KOSMO_DEBUG = "client"

                love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";common/?.lua;client/?.lua;common/?/init.lua;client/?/init.lua")
                lookfor_folder = "client"
                require("client")
                gui:unregisterAll()
                love.load()
            end
        }
    )
end

function love.update(dt)
end

function love.draw()
end