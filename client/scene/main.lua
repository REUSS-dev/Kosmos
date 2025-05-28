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

if first_time then
    
end

-- init

gui.unregisterAll()

-- Должен быть последним
gui.register(LOADING)
gui.register(NOTIF)