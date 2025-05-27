-- scene
local scene = {}



-- documentation



-- config

local scene_folder = "scene"

local auto_destroy_scenes = false

-- consts



-- vars

local loaded_scenes = {}

local current = "none"

-- init

if KOSMO_DEBUG then
    scene_folder = KOSMO_DEBUG .. "/" .. scene_folder
end

-- fnc



-- classes



-- scene fnc

function scene.load(sceneName, overlayer)
	sceneName = tostring(sceneName)

    if loaded_scenes[sceneName] then
        if type(loaded_scenes[sceneName]) == "function" then
			if not overlayer then
				print("Reloading scene \"" .. sceneName .. "\"")
				current = sceneName
			else
				print("Reloading overlayer \""..sceneName.."\"")
			end

			loaded_scenes[sceneName](false)
		else
			print("Loading scene/overlayer \""..sceneName.."\"")

            local scene_fileName = sceneName:gsub("[.]","/")
			local scenePath = scene_folder .. "/" .. scene_fileName .. ".lua"

			loaded_scenes[sceneName] = love.filesystem.load(scenePath)

			if auto_destroy_scenes then
				loaded_scenes[current] = true
				collectgarbage()
			end

			loaded_scenes[sceneName](false)
			if not overlayer then
				current = sceneName
			end
		end

        return
    end

    local scene_fileName = sceneName:gsub("[.]","/")
	local scenePath = scene_folder .. "/" .. scene_fileName .. ".lua"

    if love.filesystem.getInfo(scenePath) then
        if not overlayer then
            print("First time loading scene \"" .. sceneName .. "\"")

            if auto_destroy_scenes then
                loaded_scenes[current] = true
                collectgarbage()
            end

            current = sceneName
        else
            print("First time loading overlayer \"" .. sceneName .. "\"")
        end

        loaded_scenes[sceneName] = love.filesystem.load(scenePath)
        loaded_scenes[sceneName](true)
    else
        print("Scene \"" .. sceneName .. "\" does not exists. Failed to load.")
    end
end

return scene