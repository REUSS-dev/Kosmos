-- scene "register"

-- libs
local gui = require("libs.stellargui")

local scene = require("scripts.scene_master")
local email_validate = require("scripts.validemail")

local first_time = ...

-- consts



-- config



-- vars

local CLIENT = CLIENT

-- fnc

local function validateRegisterInfo(email, login, pass, pass_repeat)
    if #email == 0 then
        NOTIF:error("Введите адрес электронной почты.")
        return false
    end

    if #email > 254 then
        NOTIF:error("Введите другой адрес электронной почты.")
        return false
    end

    local success, reason = email_validate(email)
    if not success then
        NOTIF:error("Введён некорректный адрес электронной почты.\n" .. reason)
        return false
    end

    if #login == 0 then
        NOTIF:error("Введите ваш логин для регистрации.\nДлина логина - от 4 до 16 символов.")
        return false
    end

    if #login < 4 or 16 < #login then
        NOTIF:error("Длина логина - от 4 до 16 символов.")
        return false
    end

    if #pass == 0 then
        NOTIF:error("Введите пароль для вашего аккаунта.\nДлина пароля - от 6 до 32 символов.")
        return false
    end

    if #pass < 6 or 32 < #pass then
        NOTIF:error("Длина пароля - от 6 до 32 символов.")
        return false
    end

    if #pass_repeat == 0 then
        NOTIF:error("Повторите ваш пароль в специальном поле.")
        return false
    end

    if pass ~= pass_repeat then
        NOTIF:error("Введённые пароли не совпадают.")
        return false
    end

    return true
end

-- first time init

if first_time then
    
end

-- init

gui.unregisterAll()

-- Лого
local logo = gui.Label{
    text = "Регистрация",
    font = KOSMOFONT_BIG,
    textColor = {1, 1, 1, 1},
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

-- Группа текстовых полей

-- надпись "email"
local email_textfield_label = gui.Label{
    text = "Электронная почта",
    font = KOSMOFONT,
    textColor = {1, 1, 1, 1},
    x = 180,
    y = panel:getY() + 10,
    w = 400,
    h = 30,
    align = "left"
}
gui.register(email_textfield_label)

-- Текстовое поле email
local email_textfield = gui.TextField{
    font = KOSMOFONT,
    color = {0.8, 0.8, 0.8, 1},
    x = "center",
    y = email_textfield_label:getY() + 35,
    w = 340,
    h = 40,
    r = 10
}
gui.register(email_textfield)

-- надпись "login"
local login_textfield_label = gui.Label{
    text = "Логин (от 4 до 16 символов)",
    font = KOSMOFONT,
    textColor = {1, 1, 1, 1},
    x = 180,
    y = email_textfield:getY() + 50,
    w = 400,
    h = 30,
    align = "left"
}
gui.register(login_textfield_label)

-- Текстовое поле login
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

-- надпись "password"
local password_textfield_label = gui.Label{
    text = "Пароль (от 6 до 32 символов)",
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

-- надпись "password povtor"
local password_repeat_textfield_label = gui.Label{
    text = "Повторите пароль",
    font = KOSMOFONT,
    textColor = {1, 1, 1, 1},
    x = 180,
    y = password_textfield:getY() + 50,
    w = 400,
    h = 30,
    align = "left"
}
gui.register(password_repeat_textfield_label)

-- Текстовое поле Пароль povtor
local password_repeat_textfield = gui.TextField{
    font = KOSMOFONT,
    color = {0.8, 0.8, 0.8, 1},
    x = "center",
    y = password_repeat_textfield_label:getY() + 35,
    w = 340,
    h = 40,
    r = 10,
    password = true
}
gui.register(password_repeat_textfield)

-- Кнопка Регистрация
local function hideLoad_callback(_, _, result)
    LOADING:finishLoading()

    if not result then
        return
    end

    if result:isError() then
        return
    end

    scene.load("login")
    NOTIF:info("Поздравляем с успешной регистрацией, " .. tostring(result:getParams().login) .. "!")
end

local button_register = gui.KosmosButton{
    font = KOSMOFONT,
    color = ADDITIONALCOLOR_A,
    x = "center",
    y = 490,
    w = 340,
    h = 50,
    text = "Зарегистрироваться",
    action = function ()
        local email, login, password, password_repeat = email_textfield:getText(), login_textfield:getText(), password_textfield:getText(), password_repeat_textfield:getText()

        if not validateRegisterInfo(email, login, password, password_repeat) then
            return
        end

        local task_name, err = CLIENT:register(email, login, password)

        if not task_name then
            NOTIF:error("Не удаётся выполнить регистрацию.\n" .. err)
            return
        end

        LOADING:show()
        CLIENT.sentRequests:attachCallback(task_name, hideLoad_callback)
    end
}
gui.register(button_register)

-- Кнопка "назад"
local button_back = gui.KosmosButton{
    font = KOSMOFONT,
    color = ERRORCOLOR_A,
    x = -25,
    y = panel:getY(),
    w = 100,
    h = 50,
    text = "Назад",
    action = function ()
        scene.load("login")
    end
}
gui.register(button_back)


-- Должен быть последним
gui.register(LOADING)
gui.register(NOTIF)