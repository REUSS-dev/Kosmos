-- scene "startup"

-- libs
local gui = require("libs.stellargui")
local angelic = require("libs.angeliclove")

local scene = require("scripts.scene_master")

local first_time = ...

-- consts

local CONNECTING_TEXT = {
    [0] = "Установка соединения с сервером",
    "Установка соединения с сервером.",
    "Установка соединения с сервером..",
    "Установка соединения с сервером...",
}

local TEXT_CONNECTION_SUCCESS = "Соединение с сервером установлено!"

-- config

local FADEOUT_TIME = 1

-- vars

local fade_time = FADEOUT_TIME

local CLIENT = CLIENT

-- first time init

if first_time then
    -- colors
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)
    KOSMOCOLOR = {0.3, 0.3, 0.8, 1}
    KOSMOCOLOR_A = {0.3, 0.3, 0.8, 0.6}

    ADDITIONALCOLOR = {0.6, 0.6, 0.2, 1}
    ADDITIONALCOLOR_A = {0.6, 0.6, 0.2, 0.6}

    ERRORCOLOR = {0.8, 0.3, 0.3, 1}
    ERRORCOLOR_A = {0.8, 0.3, 0.3, 0.6}

    KOSMOFONT_SMALL = love.graphics.newFont("resources/font.ttf", 18)
    KOSMOFONT_SMALL_PLUS = love.graphics.newFont("resources/font.ttf", 20)
    KOSMOFONT = love.graphics.newFont("resources/font.ttf", 22)
    KOSMOFONT_MEDIUM = love.graphics.newFont("resources/font.ttf", 50)
    KOSMOFONT_BIG = love.graphics.newFont("resources/font.ttf", 82)
    CELESTIALFONT = angelic.new("automata", 20):getFont()

    -- общее гуи

    -- оповещения
    NOTIF = gui.KosmosNotification{
        font = KOSMOFONT
    }

    -- Знак загрузки
    LOADING = gui.KosmosLoading{
        width = 100,
        font = CELESTIALFONT,
        pos = {-30, -125},
        text = "Loadingload"
    }
    LOADING:hide()
end

-- init

gui.unregisterAll()

-- Знак загрузки
local loading = gui.KosmosLoading{
    width = 150,
    font = CELESTIALFONT,
    pos = {-50, 200},
    text = "Loadingloading"
}
gui.register(loading)

-- Текст "KOSMOS"
local logo = gui.Label{
    pos = {25, 0},
    size = {love.graphics.getWidth() - 25, 100},
    font = KOSMOFONT_BIG,
    text = "Kosmos",
    textColor = KOSMOCOLOR_A,
    align = "left"
}
gui.register(logo)

-- Текст "Установка соединения"
local connecting = gui.Label{
    pos = {25, 100},
    size = {love.graphics.getWidth() - 25, 100},
    font = KOSMOFONT,
    text = CONNECTING_TEXT[0],
    textColor = {1, 1, 1, 1},
    align = "left"
}

connecting.totaldt = 0
connecting.currentText = 0

function connecting:tick(dt)
    if not loading.finish and loading.draw then
        local new_total = self.totaldt + dt

        if math.floor(self.totaldt) ~= math.floor(new_total) then
            self.currentText = self.currentText + 1
            if self.currentText > 3 then
                self.currentText = 1
            end

            self.text = CONNECTING_TEXT[self.currentText]
            self:generateTextCache()
        end

        self.totaldt = new_total

        if CLIENT:getMainServerStatus() and self.totaldt >= MIN_LOAD_TIME then
            self.text = TEXT_CONNECTION_SUCCESS
            self:generateTextCache()
            loading:finishLoading()
        end
    else
        if loading.finishTimer == 0 then
            if fade_time > 0 then
                fade_time = fade_time - dt
                if fade_time < 0 then
                    fade_time = 0
                end


                logo.palette:setColorAlpha("text", fade_time / FADEOUT_TIME)
                connecting.palette:setColorAlpha("text", fade_time / FADEOUT_TIME)
            else
                if CLIENT.session:getUser() then
                    scene.load("main")
                else
                    scene.load("login")
                end
            end
        end
    end
end

gui.register(connecting)

-- Должен быть последним
gui.register(NOTIF)