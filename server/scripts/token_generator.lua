local gen = {}

-- cfg

local CLIENT_TOKEN_LENGTH = 128
local SERVER_TOKEN_LENGTH = 2048

-- gen fnc

math.randomseed(os.time())

---Generate random string of characters of provided length
---@param length any
function gen.generate(length)
    local str = ""

    for _ = 1, length do
        str = str .. string.char(math.random(0, 255))
    end

    return str
end

function gen.generateClientToken()
    return gen.generate(gen.getClientTokenLength())
end

function gen.getClientTokenLength()
    return math.ceil(CLIENT_TOKEN_LENGTH / 8)
end

function gen.generateServerToken()
    return love.data.encode("string", "hex", gen.generate(math.ceil(SERVER_TOKEN_LENGTH / 8))) --[[@as string]]
end

return gen