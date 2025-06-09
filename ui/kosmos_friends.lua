-- friends
local friends = {}

local gui = require("libs.stellargui")

local palette = require("classes.Palette")
local complex = require("classes.CompositeObject")

local scene = require("scripts.scene_master")

-- documentation



-- consts



-- config

friends.name = "KosmosFriends"
friends.aliases = {}
friends.rules = {
    {{"font"}, "font", love.graphics.getFont()},

    {"sizeRectangular", {-10, -50, 300, 430}},

    {"position", {-10, -50, 300, 430}},

    {"palette", {color = {0.3, 0.3, 0.3}, textColor = {1, 1, 1, 1}}},
    {{"r", "radius", "rounding", "round"}, "r", 10},
    {{"client"}, "client"}
}

local search_height = 30
local search_spacing = 10
local search_palette = {{1, 1, 1, 1}, {0, 0, 0, 1}, {0.5, 0.5, 0.5, 1}}

local add_height = 30
local add_spacing = 10
local add_palette = {{0.3, 0.3, 0.8, 0.6}, {1, 1, 1, 1}}

local profile_height = 50

-- vars



-- init



-- fnc



-- classes

---@class KosmosFriendList : CompositeObject
local KosmosFriendList = {}
local KosmosFriendList_meta = {__index = KosmosFriendList}
setmetatable(KosmosFriendList, {__index = complex.class}) -- Set parenthesis

function KosmosFriendList:tick(dt)
    local my_profile = self.client.cache:getProfile(self.client.session:getUser())

    if not my_profile then
        return
    end

    if not my_profile.friends then
        return
    end

    for index, friend in ipairs(my_profile.friends) do
        if not self.mapped[index] then
            local new_profile = gui.KosmosProfile{
                x = self.x,
                y = self.y + (index-1)*(search_spacing + profile_height),
                w = self.w,
                h = profile_height,
                r = self.r,
                font = self.font,
                client = self.client,
                profile = friend,
                no_panel = true
            }

            new_profile.avatar.click = function (self)
                CONVERSATION:setProfile(friend)
            end

            self:add(new_profile)

            CLIENT:getUser(friend)

            self.mapped[index] = true
        end
    end

    complex.class.tick(self, dt)
end

local function newFriendList(prototype)
    local obj = complex.new{x = prototype.x, y = prototype.y, w = prototype.w, h = prototype.h, client = prototype.client}
    setmetatable(obj, KosmosFriendList_meta)---@cast obj KosmosFriends

    obj.mapped = {}

    return obj
end

---@class KosmosFriends : CompositeObject
---@field panel Panel profile panel object
---@field search TextField Search textfield object
---@field add_button KosmosButton Add contacts button
---@field add_contact KosmosAddContact add contact object. hidden by default
---@field add_active boolean Is add contact screen currently active
local KosmosFriends = {}
local KosmosFriends_meta = {__index = KosmosFriends}
setmetatable(KosmosFriends, {__index = complex.class}) -- Set parenthesis

function KosmosFriends:showAddContact()
    self.add_active = true
    self:add(self.add_contact)
end

function KosmosFriends:hideAddContact()
    self.add_active = false
    self:remove(self.add_contact)
end

function KosmosFriends:switchAddContact()
    self.add_active = not self.add_active

    if self.add_active then
        self:add(self.add_contact)
    else
        self:remove(self.add_contact)
    end
end


-- profile fnc

---Create new KosmosFriends object from object prototype
---@param prototype ObjectPrototype
---@return KosmosFriends
function friends.new(prototype)
    local obj = complex.new{x = prototype.x, y = prototype.y, w = prototype.w, h = prototype.h, client = prototype.client}
    setmetatable(obj, KosmosFriends_meta)---@cast obj KosmosFriends

    obj.panel = gui.Panel{
        x = prototype.x,
        y = prototype.y + search_height + search_spacing,
        w = prototype.w,
        h = prototype.h - search_height - search_spacing - add_height - add_spacing,
        r = prototype.r,
        palette = prototype.palette,
    }
    obj:add(obj.panel)

    obj.search = gui.TextField{
        x = prototype.x,
        y = prototype.y,
        w = prototype.w,
        h = search_height,
        r = prototype.r / 2,
        palette = palette.new(search_palette),
        font = prototype.font,
        placeholder = "Поиск контактов"
    }
    obj:add(obj.search)

    obj.add_active = false
    obj.add_button = gui.KosmosButton{
        x = prototype.x,
        y = prototype.y + prototype.h - add_height,
        w = prototype.w,
        h = add_height,
        text = "+ Добавить контакт",
        font = prototype.font,
        r = prototype.r,
        palette = palette.new(add_palette),
        action = function ()
            obj:switchAddContact()
        end
    }
    obj:add(obj.add_button)

    obj.add_contact = gui.KosmosAddContact{
        x = prototype.x,
        y = prototype.y + search_height + search_spacing,
        w = prototype.w,
        h = prototype.h - search_height - search_spacing - add_height - add_spacing,
        font = prototype.font,
        r = prototype.r,
        client = prototype.client
    }

    obj.friends = newFriendList{
        x = prototype.x + search_spacing,
        y = prototype.y + search_height + search_spacing + search_spacing,
        w = prototype.w - search_spacing * 2,
        h = prototype.h,
        font = prototype.font,
        r = prototype.r,
        client = prototype.client
    }
    obj:add(obj.friends)

    return obj
end

return friends