--!strict
--[[
	Preferences: applies the player's saved settings (the "settings" section) the
	moment they change: mixer volumes (Sfx groups) and camera shake. The UI size is
	read by UI/App.
]]

local Camera = require("./Camera")
local Sfx = require("../Sfx")
local State = require("../State")

local Preferences = {}

local function apply()
	local settings = State.get("settings")
	if type(settings) ~= "table" then
		return
	end
	Sfx.setVolume("master", settings.master)
	Sfx.setVolume("music", settings.music)
	Sfx.setVolume("ambience", settings.ambience)
	Sfx.setVolume("sfx", settings.sfx)
	Sfx.setVolume("ui", settings.ui)
	Camera.setShakeEnabled(settings.shake)
end

function Preferences.start()
	State.changed:Connect(function(key: any)
		if key == "settings" then
			apply()
		end
	end)
	apply()
end

return Preferences
