---@diagnostic disable: duplicate-set-field

---@type KosmoServerAuth, KosmoServerMain
local serverAuth, serverMain

function love.load()
    local gui = require("libs.stellargui").hook(true)

    if KOSMO_DEBUG then
        require("server.conf")
    end

    --#region gui

    local font = love.graphics.newFont("resources/font.ttf", 18)

    local auth_key_textfield = gui.TextField{
        x = -150,
        y = 25,
        w = 150,
        h = 30,
        font = font
    }
    gui.register(auth_key_textfield)

    local main_server_start = gui.Button{
        x = 200,
        y = 25,
        w = 80,
        h = 30,
        text = "Start",
        font = font,
        action = function ()
            serverMain:start()
        end
    }
    gui.register(main_server_start)

    local auth_server_start = gui.Button{
        x = -50,
        y = 25,
        w = 80,
        h = 30,
        text = "Start",
        font = font,
        action = function ()
            serverAuth:setDatabaseKeys(auth_key_textfield:getText())
            serverAuth:start()
        end
    }
    gui.register(auth_server_start)

    --#endregion

    local auth = require("classes.KosmoServer.Auth")
    local main = require("classes.KosmoServer.Main")

    serverAuth = auth.new(AUTH_ADDRESS, "auth_central")
    serverMain = main.new(MAIN_ADDRESS, "main")

    serverMain:addAuthServer(AUTH_ADDRESS, love.filesystem.read("server_auth_auth_central.tok"))
end

function love.update(dt)
    serverMain:update(dt)
    serverAuth:update(dt)

    serverAuth:pingClients(serverAuth:getClients())
    serverMain:pingClients(serverMain:getClients())
end

function love.draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Server " .. (serverMain:getAddress() or "") .. " - " .. serverMain:getName() .. "\nAuth server status: " .. (serverMain:getAuthServerStatus() and "YES" or "NO"), 0, 0)

    love.graphics.print("Peers:", 0, 50)
    for i, peerI in ipairs(serverMain:getClients()) do
        local info = serverMain:getClientInfo(peerI)
        love.graphics.print(i .. ". PID-" .. peerI .. " " .. info[1] .. " (Ping: " .. info[3] .. ")", 0, 50 + i * love.graphics.getFont():getHeight())
    end

    love.graphics.print("Server " .. (serverAuth:getAddress() or "") .. " - " .. serverAuth:getName(), 400, 0)

    love.graphics.print("Peers:", 400, 60)
    for i, peerI in ipairs(serverAuth:getClients()) do
        local info = serverAuth:getClientInfo(peerI)
        love.graphics.print(i .. ". PID-" .. peerI .. " " .. info[1] .. " (Ping: " .. info[3] .. ")", 400, 60 + i * love.graphics.getFont():getHeight())
    end
end

function love.quit()
    serverAuth:stop()
    serverMain:stop()
end