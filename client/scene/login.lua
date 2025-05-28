-- scene "login"

-- libs
local gui = require("libs.stellargui")

local scene = require("scripts.scene_master")

local first_time = ...

-- consts

local AUTH_SERVER_GET_TASK_NICKNAME = "auth_connect"

-- config

local FADEIN_TIME = 1

-- vars

local fade_time = 0

local CLIENT = CLIENT

-- first time init

if first_time then
    
end

-- init

gui.unregisterAll()

-- Лого
local logo = gui.Label{
    text = "Kosmos",
    font = KOSMOFONT_BIG,
    textColor = KOSMOCOLOR,
    x = 0,
    y = 0,
    w = love.graphics.getWidth(),
    h = 100,
}
gui.register(logo)

-- Полоска под лого
local stripe = gui.Panel{
    color = KOSMOCOLOR,
    x = 0,
    y = 100,
    w = love.graphics.getWidth(),
    h = 2,
}
gui.register(stripe)

-- Панель входа
local panel = gui.Panel{
    color = {0.2, 0.2, 0.2, 1},
    x = "center",
    y = 130,
    w = 400,
    h = 440,
    r = 50
}
gui.register(panel)

-- Надпись "Вход"
local login = gui.Label{
    text = "Вход в Kosmos",
    font = KOSMOFONT_MEDIUM,
    textColor = {1, 1, 1, 1},
    x = 0,
    y = panel:getY(),
    w = love.graphics.getWidth(),
    h = 100,
}
gui.register(login)

-- Группа текстовых полей

-- надпись "логин"
local login_textfield_label = gui.Label{
    text = "Логин",
    font = KOSMOFONT,
    textColor = {1, 1, 1, 1},
    x = 180,
    y = panel:getY() + 100,
    w = 400,
    h = 30,
    align = "left"
}
gui.register(login_textfield_label)

-- Текстовое поле логин
local login_textfield = gui.TextField{
    font = KOSMOFONT,
    color = {0.8, 0.8, 0.8, 1},
    x = "center",
    y = login_textfield_label:getY() + 35,
    w = 340,
    h = 40,
    r = 10
}
gui.register(login_textfield)

-- надпись "Пароль"
local password_textfield_label = gui.Label{
    text = "Пароль",
    font = KOSMOFONT,
    textColor = {1, 1, 1, 1},
    x = 180,
    y = login_textfield:getY() + 50,
    w = 400,
    h = 30,
    align = "left"
}
gui.register(password_textfield_label)

-- Текстовое поле Пароль
local password_textfield = gui.TextField{
    font = KOSMOFONT,
    color = {0.8, 0.8, 0.8, 1},
    x = "center",
    y = password_textfield_label:getY() + 35,
    w = 340,
    h = 40,
    r = 10,
    password = true
}
gui.register(password_textfield)

-- Кнопка Войти
local password_textfield = gui.KosmosButton{
    font = KOSMOFONT,
    color = KOSMOCOLOR_A,
    x = "center",
    y = password_textfield:getY() + 60,
    w = 340,
    h = 50,
    text = "Войти"
}
gui.register(password_textfield)

-- Кнопка Регистрация
local function hideLoad_callback_reg(client, _, result)
    LOADING:finishLoading()

    if not result then
        return
    end

    if result:isError() then
        return
    end

    scene.load("register")
end

local button_register = gui.KosmosButton{
    font = KOSMOFONT,
    color = ADDITIONALCOLOR_A,
    x = "center",
    y = 490,
    w = 340,
    h = 50,
    text = "Зарегистрироваться",
    action = function()
        if CLIENT:getAuthServerStatus() then
            scene.load("register")
        else
            if not CLIENT.sentRequests:resolveNickname(AUTH_SERVER_GET_TASK_NICKNAME) then
                local task_name, err = CLIENT:connectAuthServer()
                if not task_name then
                    NOTIF:error("Не удаётся подключиться к серверу аутентификации.\n" .. err)
                    return
                end

                LOADING:show()
                CLIENT.sentRequests:attachCallback(task_name, hideLoad_callback_reg)
            end
        end
    end
}
gui.register(button_register)

-- Должен быть последним
gui.register(LOADING)
gui.register(NOTIF)