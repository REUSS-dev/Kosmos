-- scene "login"

-- libs
local gui = require("libs.stellargui")

local scene = require("scripts.scene_master")

local first_time = ...

-- consts



-- config



-- vars



local CLIENT = CLIENT

-- first time init

local function receive_introduce_callback(_, _, response)
    if not response then
        return
    end

    LOADING:finishLoading()
end

if first_time then
    local result, err = CLIENT:introduceToken()

    if not result then
        scene.load("login")
        NOTIF:error("Не удаётся подтвердить сессию. Войдите повторно.\n\"" .. tostring(err) .. "\"")

        return
    end

    CLIENT:attachCallback(result, receive_introduce_callback)

    LOADING:show()
end

love.window.setMode(1000, 600, {msaa = 5})
LOADING:move(love.graphics.getWidth() - 150, love.graphics.getHeight() - 150)

-- init

gui.unregisterAll()

-- Должен быть последним
gui.register(LOADING)
gui.register(NOTIF)