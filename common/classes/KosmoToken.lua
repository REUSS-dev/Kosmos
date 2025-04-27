-- token
local token = {}



-- documentation

---@alias TokenString string
---@alias TokenScope ApiScopeGroup

-- config



-- consts



-- vars



-- init



-- fnc



-- classes

--#region KosmoToken

---@class KosmoToken
---@field token_bytes TokenString Raw token bytes string
---@field scope table<TokenScope, boolean> Token scope map
---@field owner HostPeerIndex IP address owning the token
---@field clid integer ID of a user who owns this token
local KosmoToken = {}
local KosmoToken_meta = { __index = KosmoToken }

function KosmoToken:getToken()
    return self.token_bytes
end

---Checks if provided scope group within this token's scope
---@param group TokenScope
---@return boolean
function KosmoToken:checkScope(group)
    return self.scope[group] or false
end

---Checks if provided IP is a token's owner
---@param peer_index HostPeerIndex
---@return boolean
function KosmoToken:checkOwner(peer_index)
    return self.owner == peer_index
end

---Returns owner of a token
---@return HostPeerIndex
function KosmoToken:getOwner()
    return self.owner
end

---Returns client id of a token
---@return integer
function KosmoToken:getClientID()
    return self.clid
end

--#endregion

--#region KosmoTokenCollection

---@class KosmoTokenCollection
---@field tokens table<TokenString, KosmoToken>
local KosmoTokenCollection = {}
local KosmoTokenCollection_meta = { __index = KosmoTokenCollection }

---Add a token to a token collection
---@param new_token KosmoToken
function KosmoTokenCollection:add(new_token)
    self.tokens[new_token:getToken()] = new_token
end

function KosmoTokenCollection:find(token_string)
    return self.tokens[token_string]
end

---Delete token from collection
---@param token_or_string KosmoToken|TokenString
function KosmoTokenCollection:delete(token_or_string)
    if type(token_or_string) == "string" then
        self.tokens[token_or_string] = nil
    elseif type(token_or_string) == "table" then
        if token_or_string.token_bytes then
            self.tokens[token_or_string.token_bytes] = nil
        end
    else
        error("Arg 1 to KosmoTokenCollection:delete() string or KosmoToken expected, got " .. type(token_or_string))
    end
end

---Deletes all tokens associated with given peer
---@param peer HostPeerIndex
function KosmoTokenCollection:deletePeerTokens(peer)
    for token_bytes, t in pairs(self.tokens) do
        if t:checkOwner(peer) then
            self:delete(token_bytes)
        end
    end
end

--#endregion

-- token fnc

---Create new token object
---@param tokenStr string Token bytes
---@param scope table<TokenScope, boolean>
---@param owner HostPeerIndex
---@param clid integer
---@return KosmoToken
function token.new(tokenStr, scope, owner, clid)
    local new_token = setmetatable({
        token_bytes = tokenStr,
        scope = scope,
        owner = owner,
        clid = clid
    }, KosmoToken_meta)

    return new_token
end

function token.newCollection()
    local new_collection = setmetatable({
        tokens = {}
    }, KosmoTokenCollection_meta)

    return new_collection
end

return token