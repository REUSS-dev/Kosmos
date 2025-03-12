---@diagnostic disable: duplicate-set-field

---@type KosmoClient
local client

function love.load()
    local gui = require("libs.stellargui").hook(true)

    local morda = require("classes.KosmoClient")

    client = morda.new()

    client:start()
    client:setServerAddress("192.168.0.11:6789")
end

function love.update(dt)
    client:update(dt)
end

function love.draw()
    love.graphics.print({"Client " .. (client:getClientAddress() or "") .. "\nServer status: ", client:getServerStatus() and {0, 1, 0, 1} or {1, 0, 0, 1}, client:getServerStatus() and "CONNECTED" or "DISCONNECTED. ATTEMPT RECONNECTING"})
end