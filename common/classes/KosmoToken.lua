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
---@field token_bytes TokenString Raw token binary string
---@field scope table<TokenScope, boolean> Token scope map
---@field owner HostPeerIndex Index of a peer owning the token
---@field clid integer ID of a user who this token corresponds to
local KosmoToken = {}
local KosmoToken_meta = { __index = KosmoToken }

---Returns binary string representation of a token.
---@return TokenString
function KosmoToken:getToken()
    return self.token_bytes
end

---Checks if provided scope group within this token's scope
---@param group TokenScope API scope group string
---@return boolean check True, if this token covers this scope group, false otherwise
function KosmoToken:checkScope(group)
    return self.scope[group] or false
end

---Checks if provided peer index is a token's owner
---@param peer_index HostPeerIndex Index of a peer to check against ownership of this token
---@return boolean check True, if provided index is this token's owner, false otherwise
function KosmoToken:checkOwner(peer_index)
    return self.owner == peer_index
end

---Returns owner of this token
---@return HostPeerIndex peer_index Index of a peer owning this token
function KosmoToken:getOwner()
    return self.owner
end

---Returns client id of a token
---@return integer clid Internal system client ID this token corresponds to
function KosmoToken:getClientID()
    return self.clid
end

--#endregion

--#region KosmoTokenCollection

---@class KosmoTokenCollection Advanced KosmoToken container.
---@field tokens table<TokenString, KosmoToken> Collection of tokens in this KosmoTokenCollection
local KosmoTokenCollection = {}
local KosmoTokenCollection_meta = { __index = KosmoTokenCollection }

---Add a token to this token collection
---@param new_token KosmoToken
function KosmoTokenCollection:add(new_token)
    self.tokens[new_token:getToken()] = new_token
end

---Search token in this collection by binary string representation of the token.
---@param token_string string
---@return KosmoToken?
function KosmoTokenCollection:find(token_string)
    return self.tokens[token_string]
end

---Delete token from collection
---@param token_or_string KosmoToken|TokenString Binary representation or token object itself.
function KosmoTokenCollection:delete(token_or_string)
    -- Может быть легко упрощен до:
    -- token_or_string = token_or_string.token_byrtes or token_or_string
    -- Но это не очень интуитивно
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

---Deletes all tokens within this collection associated with given peer
---@param peer HostPeerIndex Index of a peer to filter tokens
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
---@param tokenStr string Binary string of a token
---@param scope table<TokenScope, boolean> Scope map of a token
---@param owner HostPeerIndex Index of a peer owning a token
---@param clid integer Client ID of a new token
---@return KosmoToken new_KosmoToken New KosmoToken object
function token.new(tokenStr, scope, owner, clid)
    local new_token = setmetatable({
        token_bytes = tokenStr,
        scope = scope,
        owner = owner,
        clid = clid
    }, KosmoToken_meta)

    return new_token
end

---Create new empty Token collection
---@return KosmoTokenCollection new_KosmoTokenCollection New KosmoTokenCollection object
function token.newCollection()
    local new_collection = setmetatable({
        tokens = {}
    }, KosmoTokenCollection_meta)

    return new_collection
end

return token