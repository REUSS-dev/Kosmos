---@diagnostic disable: duplicate-set-field

---@type KosmoServer
local server

function love.load()
    local gui = require("libs.stellargui").hook(true)

    local morda = require("classes.KosmoServer")

    server = morda.new()

    server:start("*:6789")
end

function love.update(dt)
    server:update(dt)
    server:pingClients(server:getClients())
end

function love.draw()
    love.graphics.print("Server " .. (server:getAddress() or ""), 0, 0)

    love.graphics.print("Peers:", 0, 50)
    for i, peerI in ipairs(server:getClients()) do
        local info = server:getClientInfo(peerI)
        love.graphics.print(i .. ". PID-" .. peerI .. " " .. info[1] .. " (Ping: " .. info[3] .. ")", 0, 50 + i * love.graphics.getFont():getHeight())
    end
end

function love.keypressed()
end