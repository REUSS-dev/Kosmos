local kosmorequest = {}

local ffi  = require("ffi")

local sbon = require("libs.stellardb.sbon")

-- docs

---@alias KosmoRequestParams table<string, any> Map of parameters of request
---@alias KosmoRequestBytes string String, containing valid kosmorequest data

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



-- classes

---@class KosmoRequest Unified KosmoRequest object
---@field method string Name of the method of the request
---@field params table<string, any> Map of given method parameters
---@field token string Auth token request will use
---@field version integer API version this request asks
---@field uid integer Unique inidividual indentifier of this request
---@field peer HostPeerIndex? Index of a peer whom this request originates from. Must be set manually
---@field clid integer? Client ID associated with token of the request (must be assigned after successful authorization and validation)
---@field payload string? Generated ready-to-send KosmoRequest encoded payload. Can be nil, if not generated yet
local KosmoRequest = {}
local KosmoRequest_meta = { __index = KosmoRequest }

---Returns currently set method in this request
---@return string method Method string
function KosmoRequest:getMethod()
    return self.method
end

---Sets new method for this request
---@param new_method string New method value
---@return KosmoRequest self This KosmoRequest object
function KosmoRequest:setMethod(new_method)
    self.method = new_method

    self:invalidatePayload()

    return self
end

---Returns currently set params table in this request
---@return KosmoRequestParams params Params map
function KosmoRequest:getParams()
    return self.params
end

---Sets new params for this request
---@param new_params KosmoRequestParams New params map
---@return KosmoRequest self This KosmoRequest object
function KosmoRequest:setParams(new_params)
    self.params = new_params

    self:invalidatePayload()

    return self
end

---Returns currently set token in this request
---@return string token Token string
function KosmoRequest:getToken()
    return self.token
end

---Sets new token for this request
---@param new_token string New token value
---@return KosmoRequest self This KosmoRequest object
function KosmoRequest:setToken(new_token)
    self.token = new_token

    self:invalidatePayload()

    return self
end

---Returns currently set version in this request
---@return integer version Version integer
function KosmoRequest:getVersion()
    return self.version
end

---Sets new version for this request
---@param new_version integer New version value
---@return KosmoRequest self This KosmoRequest object
function KosmoRequest:setVersion(new_version)
    self.version = new_version

    self:invalidatePayload()

    return self
end

---Returns currently set uid in this request
---@return integer uid uid integer
function KosmoRequest:getUid()
    return self.uid
end

---Sets new uid for this request
---@param new_uid integer New uid value
---@return KosmoRequest self This KosmoRequest object
function KosmoRequest:setUid(new_uid)
    self.uid = new_uid

    self:invalidatePayload()

    return self
end

---Returns currently set peer in this request
---@return HostPeerIndex? peer uid integer
function KosmoRequest:getPeer()
    return self.peer
end

---Sets new peer for this request
---@param new_peer HostPeerIndex New peer index value
---@return KosmoRequest self This KosmoRequest object
function KosmoRequest:setPeer(new_peer)
    self.peer = new_peer

    return self
end

--Returns currently set client id of this request
---@return integer? clid client id integer
function KosmoRequest:getClientID()
    return self.clid
end

---Sets client id for this request
---@param new_clid integer New client id value
---@return KosmoRequest self This KosmoRequest object
function KosmoRequest:setClientID(new_clid)
    self.peer = new_clid

    return self
end

---Invalidates cached payload string (must be called on change of any KosmoRequest variables)
---@protected
function KosmoRequest:invalidatePayload()
    self.payload = nil
end

---Returns KosmoRequest reqdy-to-send request payload
---@return string payloadBytes
function KosmoRequest:getPayload()
    if self.payload then
        return self.payload
    end

    return self:generatePayload()
end

---Generates and caches this KosmoRequest's payload
---@return string payloadBytes
---@protected
function KosmoRequest:generatePayload()
    assert(type(self.method) == "string", "Invalid parameter 1 for generating request payload: method must be a string value. Method type: " .. type(self.method))

    -- Encode signature
    local request_string = REQUEST_SIGNATURE

    -- Encode version
    request_string = request_string .. sbon.encodeUnsignedInteger(self.version)

    -- Encode request uid
    request_string = request_string .. sbon.encodeUnsignedInteger(self.uid)

    -- Encode request method
    request_string = request_string .. sbon.encodeString(self.method)

    -- Encode token
    request_string = request_string .. sbon.encodeString(self.token)

    -- Encode parameters
    request_string = request_string .. sbon.encodeMap(self.params)

    -- Cache payload
    self.payload = request_string

    return request_string
end

function KosmoRequest:generateResponse(params, method)
    return kosmorequest.new(method or self.method, params, self.token, self.version, self.uid)
end

function KosmoRequest:generateError(error_header)
    local error_object = {
        message = error_header.message,
        code = error_header.code,
        method = self.method,
        params = self.params,
        version = self.version
    }

    return kosmorequest.new(ERROR_METHOD, error_object, self.token, ERROR_VER, self.uid)
end

-- kosmorequest fnc

function kosmorequest.new(method, params, token, version, uid)
    local new_request = setmetatable({
        method = method,
        params = params or {},
        token = token or TOKEN_PLACEHOLDER,
        version = version or default_version,
        uid = uid or request_uid
    }, KosmoRequest_meta)

    request_uid = request_uid + 1

    return new_request
end

---Set default api version that is used when API version is not provided
---@param version integer
function kosmorequest.setAPIversion(version)
    default_version = version
end

---Parse kosmo request string
---@param bytes KosmoRequestBytes
---@return KosmoRequest? kosmorequest A parsed kosmorequest object if success, nil otherwise
function kosmorequest.parse(bytes)
    local requestPtr = ffi.cast("const uint8_t*", bytes)
    local endPtr = requestPtr + #bytes

    -- Validate and parse signature
    if not sbon.validateString(requestPtr, endPtr, #REQUEST_SIGNATURE) then
        return
    end

    local decoded_signature
    decoded_signature, requestPtr = sbon.decodeString(requestPtr, #REQUEST_SIGNATURE) 
    if not (decoded_signature == REQUEST_SIGNATURE) then
        return
    end

    -- Parse KosmoRequest
    local version, uid, method, token, params

    -- Validate and parse version
    if not sbon.validateUnsignedInteger(requestPtr, endPtr) then
        return
    end

    version, requestPtr = sbon.decodeUnsignedInteger(requestPtr)

    -- Validate and parse request uid
    if not sbon.validateUnsignedInteger(requestPtr, endPtr) then
        return
    end

    uid, requestPtr = sbon.decodeUnsignedInteger(requestPtr)

    -- Validate and parse request method
    if not sbon.validateString(requestPtr, endPtr) then
        return
    end

    method, requestPtr = sbon.decodeString(requestPtr)

    -- Validate and parse request token
    if not sbon.validateString(requestPtr, endPtr) then
        return
    end

    token, requestPtr = sbon.decodeString(requestPtr)

    -- Validate and parse request parameters
    if not sbon.validateMap(requestPtr, endPtr) then
        return
    end

    params = sbon.decodeMap(requestPtr)

    return kosmorequest.new(method, params, token, version, uid)
end

return kosmorequest