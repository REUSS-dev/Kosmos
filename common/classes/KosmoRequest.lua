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
local RESPONSE_METHOD = "response"
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
---@field params KosmoRequestParams Map of method parameters
---@field token string Auth token request will use
---@field version integer API version this request will ask for
---@field uid integer Unique inidividual indentifier of this request
---@field peer HostPeerIndex? Index of a peer whom this request originates from. Must be set manually
---@field clid integer? Client ID associated with token of the request (must be assigned after successful authorization and validation)
---@field payload string? Generated ready-to-send KosmoRequest encoded binary payload. Can be nil, if not generated yet
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
    self.clid = new_clid

    return self
end

--#region Payload generation

---Invalidates cached payload string (must be called on change of any KosmoRequest variables)
---@protected
function KosmoRequest:invalidatePayload()
    self.payload = nil
end

---Returns KosmoRequest reqdy-to-sends payload binary string
---@return string payloadBytes Payload binary string
---@public
function KosmoRequest:getPayload()
    if self.payload then
        return self.payload
    end

    return self:generatePayload()
end

---Generates and caches payload containing this KosmoRequest
---@return string payloadBytes Payload binary string
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

--#endregion Payload generation

--#region Child requests

---Generate response to this request.
---@param params KosmoRequestParams Map of params response KosmoRequest will have
---@return KosmoRequest Response KosmoRequest object
---@public
function KosmoRequest:createResponse(params)
    return kosmorequest.new(RESPONSE_METHOD, params, self.token, self.version, self.uid)
end

---Generate error response to this request
---@param error_header ApiError Structure, containing message and code of the error
---@return KosmoRequest new_KosmoRequest Error response KosmoRequest object
---@public
function KosmoRequest:createError(error_header)
    local error_object = {
        message = error_header.message,
        code = error_header.code,
        method = self.method,
        params = self.params,
        version = self.version
    }

    return kosmorequest.new(ERROR_METHOD, error_object, self.token, ERROR_VER, self.uid)
end

---Returns whether this KosmoRequest is a response to another request.
---@return integer|false responseUid UID of request this response is meant for, if success; false otherwise
function KosmoRequest:isResponse()
    return (self.method == RESPONSE_METHOD or self.method == ERROR_METHOD) and self.uid
end

---Returns whether this KosmoRequest is an error response to another request.
---@return integer|false responseUid UID of request this error is meant for, if success; false otherwise
function KosmoRequest:isError()
    return self.method == ERROR_METHOD and self.uid
end

--#endregion Child requests

-- kosmorequest fnc

---Create new KosmoRequest object with its contents.
---@param method string Method new request will request access to.
---@param params KosmoRequestParams Map of parameters of new KosmoRequest.
---@param token string? KosmoToken bytes.
---@param version integer? API version new request asks for.
---@param uid integer? Optional given unique identifier
---@return KosmoRequest new_KosmoRequest New KosmoRequest object
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
---@param version integer New default API version
function kosmorequest.setAPIversion(version)
    default_version = version
end

---Parse kosmo request string
---@param bytes KosmoRequestBytes Compiled KosmoRequest string
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