-- add contact
local add_contact = {}

local gui = require("libs.stellargui")

local palette = require("classes.Palette")
local complex = require("classes.CompositeObject")

-- documentation



-- consts



-- config

add_contact.name = "KosmosAddContact"
add_contact.aliases = {}
add_contact.rules = {
    {{"font"}, "font", love.graphics.getFont()},

    {"sizeRectangular", {-10, -50, 300, 430}},

    {"position", {-10, -50, 300, 430}},

    {"palette", {colors = {{0.3, 0.3, 0.3, 1}, {1, 1, 1, 1}, {0.6, 0.6, 0.2, 0.8}, {0.8, 0.3, 0.3, 0.8}, {0.3, 0.3, 0.8, 0.6}}}},
    {{"r", "radius", "rounding", "round"}, "r", 10},
    {{"client"}, "client"}
}

local label_spacing = 10
local label_offset = 20
local label_height = 70

local text_offset = 100
local text_height = 30
local search_palette = {{1, 1, 1, 1}, {0, 0, 0, 1}, {0.5, 0.5, 0.5, 1}}

local profile_height = 50

-- vars



-- init



-- fnc



-- classes

---@class KosmosAddContact : CompositeObject
---@field parent KosmosFriends
---@field panel Panel add contact panel
---@field label Label add contact message label
---@field search_text TextField add contact search textfield
---@field search_button KosmosButton add contact search button
---@field found_profile KosmosProfile profile object of found profile
---@field add_button KosmosButton
---@field cancel KosmosButton add contact cancel button
local KosmosAddContact = {}
local KosmosAddContact_meta = {__index = KosmosAddContact}
setmetatable(KosmosAddContact, {__index = complex.class}) -- Set parenthesis

function KosmosAddContact:found(profile_id)
    self.found_profile:setProfile(profile_id)
    self.found_profile:show()
    self.add_button:show()

    self.found_id = profile_id
end

-- profile fnc

---Create new KosmosAddContact object from object prototype
---@param prototype ObjectPrototype
---@return KosmosAddContact
function add_contact.new(prototype)
    local obj = complex.new{x = prototype.x, y = prototype.y, w = prototype.w, h = prototype.h, client = prototype.client}
    setmetatable(obj, KosmosAddContact_meta)---@cast obj KosmosAddContact

    obj.panel = gui.Panel{
        x = prototype.x,
        y = prototype.y,
        w = prototype.w,
        h = prototype.h,
        r = prototype.r,
        palette = prototype.palette,
    }
    obj:add(obj.panel)

    obj.label = gui.Label{
        x = prototype.x + label_spacing,
        y = prototype.y + label_offset,
        w = prototype.w - label_spacing * 2,
        h = label_height,
        align = "left",
        text = "Введите логин или электронную почту своего знакомого, чтобы найти его в Kosmos!",
        font = prototype.font
    }
    obj:add(obj.label)

    obj.search_text = gui.TextField{
        x = prototype.x + label_spacing,
        y = prototype.y + text_offset,
        w = prototype.w - label_spacing * 2,
        h = text_height,
        r = prototype.r / 2,
        palette = search_palette,
        font = prototype.font,
        placeholder = "Поиск"
    }
    obj:add(obj.search_text)

    local function found(_, _, response)
        LOADING:finishLoading()

        if not response then
            return
        end

        local params = response:getParams()

        if not params.id then
            NOTIF:info("Не удаётся найти аккаунт с таким логином/электронной почтой.")
            return
        end

        obj:found(params.id)
    end
    obj.search_button = gui.KosmosButton{
        x = prototype.x + label_spacing,
        y = prototype.y + text_offset + text_height + label_spacing,
        w = prototype.w - label_spacing * 2,
        h = text_height,
        r = prototype.r,
        color = prototype.palette[3],
        font = prototype.font,
        text = "Найти!",
        action = function ()
            local query = obj.search_text:getText()

            if #query == 0 then
                NOTIF:error("Введите логин или адрес электронной почты!")
                return
            end

            local result, err = CLIENT:searchContact(obj.search_text:getText())

            if not result then
                NOTIF:error("Не удаётся найти контакт.\n\"" .. tostring(err) .. "\"")
                return
            end

            LOADING:show()
            CLIENT:attachCallback(result, found)
        end
    }
    obj:add(obj.search_button)

    obj.found_profile = gui.KosmosProfile{
        x = prototype.x + label_spacing,
        y = prototype.y + text_offset + text_height + label_spacing + text_height + label_spacing,
        w = prototype.w - label_spacing * 2,
        h = profile_height,
        r = prototype.r,
        font = prototype.font,
        client = prototype.client,
        profile = 0,
        no_panel = true
    }
    obj.found_profile:hide()
    obj:add(obj.found_profile)

    local function added()
        obj.parent:hideAddContact()
    end
    obj.add_button = gui.KosmosButton{
        x = prototype.x + label_spacing,
        y = obj.found_profile:getY() + obj.found_profile:getHeight() + label_spacing,
        w = prototype.w - label_spacing * 2,
        h = text_height,
        r = prototype.r,
        color = prototype.palette:getColorByIndex(5),
        font = prototype.font,
        text = "Добавить",
        action = function ()
            local result, err = obj.client:addFriend(obj.found_id)

            if not result then
                NOTIF:error("Не удаётся добавить контакт.\n\"" .. tostring(err) .. "\"")
                return
            end

            obj.client:attachCallback(result, added)
        end
    }
    obj.add_button:hide()
    obj:add(obj.add_button)


    obj.cancel = gui.KosmosButton{
        x = prototype.x + label_spacing,
        y = prototype.y + prototype.h - text_height - label_spacing,
        w = prototype.w - label_spacing * 2,
        h = text_height,
        r = prototype.r,
        color = prototype.palette:getColorByIndex(4),
        font = prototype.font,
        text = "Отмена",
        action = function ()
            obj.parent:hideAddContact()
        end
    }
    obj:add(obj.cancel)

    return obj
end

return add_contact