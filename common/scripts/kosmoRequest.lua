local kosmorequest = {}

local ffi  = require("ffi")

local sbon = require("libs.stellardb.sbon")

-- docs

---@alias KosmoRequest string String, containing valid kosmorequest data

-- consts

local REQUEST_SIGNATURE = "KOSMOREQUEST"
local TOKEN_PLACEHOLDER = ""

local ERROR_METHOD = "error"
local ERROR_VER = 0

-- vars

local request_uid

local default_version = 1

-- init

request_uid = 0

-- fnc

---Set default api version that is used when API version is not provided
---@param version integer
function kosmorequest.setAPIversion(version)
    default_version = version
end

---Generate KosmoRequest string from method name, parameters, token and version
---@param method string Method name of the request
---@param params table<string, any>? Method parameters map
---@param token string? Authentication token
---@param version integer? API version used
---@param given_uid integer? Custom uid for the request. Please leave this nil if not absolutely necessary
---@return KosmoRequest request_str Compiled KosmoRequest string
---@return integer request_uid Unique identificator of request. Useful when catching response
function kosmorequest.generate(method, params, token, version, given_uid)
    assert(type(method) == "string", "Invalid parameter 1 for generate: method must be a string value. Method type: " .. type(method))
    params = params or {}
    token = token or TOKEN_PLACEHOLDER
    version = version or default_version

    request_uid = request_uid + 1

    -- Encode signature
    local request_string = REQUEST_SIGNATURE

    -- Encode version
    request_string = sbon.encodeUnsignedInteger(version)

    -- Encode request uid
    request_string = sbon.encodeUnsignedInteger(given_uid or request_uid)

    -- Encode request method
    request_string = request_string .. sbon.encodeString(method)

    -- Encode token
    request_string = request_string .. sbon.encodeString(token)

    -- Encode parameters
    request_string = request_string .. sbon.encodeMap(params)

    return request_string, given_uid or request_uid
end

---Parse kosmo request string
---@param request KosmoRequest
---@return string? method
---@return table<string, any>? params
---@return string? token
---@return integer? version
---@return integer? uid
function kosmorequest.parse(request)
    local requestPtr = ffi.cast("const uint8_t*", request)
    local endPtr = requestPtr + #request

    if not sbon.validateString(requestPtr, endPtr, #REQUEST_SIGNATURE) then
        return
    end

    if not (sbon.decodeString(requestPtr, #REQUEST_SIGNATURE) == REQUEST_SIGNATURE) then
        return
    end

    local version, uid, method, token, params

    if not sbon.validateUnsignedInteger(requestPtr, endPtr) then
        return
    end

    version, requestPtr = sbon.decodeUnsignedInteger(requestPtr)

    if not sbon.validateUnsignedInteger(requestPtr, endPtr) then
        return
    end

    uid, requestPtr = sbon.decodeUnsignedInteger(requestPtr)

    if not sbon.validateString(requestPtr, endPtr) then
        return
    end

    method, requestPtr = sbon.decodeString(requestPtr)

    if not sbon.validateString(requestPtr, endPtr) then
        return
    end

    token, requestPtr = sbon.decodeString(requestPtr)

    if not sbon.validateMap(requestPtr, endPtr) then
        return
    end

    params = sbon.decodeMap(requestPtr)

    return method, params, token, version, uid
end

function kosmorequest.generateResponse(method, params, token, uid)
    return kosmorequest.generate(method, params, token, default_version, uid)
end

function kosmorequest.generateError(errorObject, token, uid)
    return kosmorequest.generate(ERROR_METHOD, errorObject, token, 0, uid)
end

return kosmorequest