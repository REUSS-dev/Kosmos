---@diagnostic disable: duplicate-set-field

---@type KosmoServerAuth, KosmoServerMain
local serverAuth, serverMain

function love.load()
    local gui = require("libs.stellargui").hook(true)

    local auth = require("classes.KosmoServer.Auth")
    local main = require("classes.KosmoServer.Main")

    serverAuth = auth.new("*:6788", "auth_central")
    serverMain = main.new("*:6789", "main")


    serverAuth:start()
    serverMain:start()

    serverMain:addAuthServer("192.168.0.12:6788", love.filesystem.read("server_auth_auth_central.tok"))
end

function love.update(dt)
    serverMain:update(dt)
    serverAuth:update(dt)

    serverAuth:pingClients(serverAuth:getClients())
    serverMain:pingClients(serverMain:getClients())
end

function love.draw()
    love.graphics.print("Server " .. (serverMain:getAddress() or "") .. " - " .. serverMain:getName() .. "\nAuth server status: " .. (serverMain:getAuthServerStatus() and "YES" or "NO"), 0, 0)

    love.graphics.print("Peers:", 0, 50)
    for i, peerI in ipairs(serverMain:getClients()) do
        local info = serverMain:getClientInfo(peerI)
        love.graphics.print(i .. ". PID-" .. peerI .. " " .. info[1] .. " (Ping: " .. info[3] .. ")", 0, 50 + i * love.graphics.getFont():getHeight())
    end

    love.graphics.print("Server " .. (serverAuth:getAddress() or "") .. " - " .. serverAuth:getName(), 400, 0)

    love.graphics.print("Peers:", 400, 50)
    for i, peerI in ipairs(serverAuth:getClients()) do
        local info = serverAuth:getClientInfo(peerI)
        love.graphics.print(i .. ". PID-" .. peerI .. " " .. info[1] .. " (Ping: " .. info[3] .. ")", 400, 50 + i * love.graphics.getFont():getHeight())
    end
end