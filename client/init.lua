---@diagnostic disable: duplicate-set-field

function love.load()
    -- Modules
    require("libs.stellargui").hook(true)

    local scene = require("scripts.scene_master")
    local morda = require("classes.KosmoClient")

    if KOSMO_DEBUG then
        require("client.conf")
    end

    -- Client socket 
    CLIENT = morda.new()

    CLIENT:start()
    CLIENT:setMainServerAddress(SERVER_ADDRESS)

    -- transition
    scene.load("startup")
end

function love.update(dt)
    CLIENT:update(dt)
end