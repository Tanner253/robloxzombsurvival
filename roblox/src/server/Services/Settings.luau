--!strict
--[[
	Settings: the player's saved settings (volumes, camera shake, UI scale), synced
	as the "settings" section and changed with the SaveSettings remote. The client
	applies them (Controllers/Preferences).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSchema = require(ReplicatedStorage.Shared.Domain.PlayerSchema)
local Net = require("../Net")
local PlayerData = require("./PlayerData")
local Sync = require("./Sync")

local Settings = {}

local function save(
	player: Player,
	master: number,
	music: number,
	ambience: number,
	sfx: number,
	ui: number,
	shake: boolean,
	uiScale: number
)
	local data = PlayerData.get(player)
	local clean = PlayerSchema.cleanSettings({
		master = master,
		music = music,
		ambience = ambience,
		sfx = sfx,
		ui = ui,
		shake = shake,
		uiScale = uiScale,
	})
	if data and clean then
		data.settings = clean
		Sync.mark(player, "settings")
	end
end

function Settings.init()
	Net.onEvent("SaveSettings", save)
end

function Settings.start()
	Sync.provide("settings", function(player: Player)
		local data = PlayerData.get(player)
		return if data then data.settings else false
	end)
end

return Settings
