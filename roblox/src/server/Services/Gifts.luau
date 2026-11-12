--!strict
--[[
	Gifts: the daily food and water gift until level 10 (Domain/Gifts, LDOE_PARITY #58).
	Checked when the profile loads and then every few minutes, so a session that runs past
	midnight UTC gets the next day's gift too. The gift waits in the inbox (checklist 4.15).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Features = require(ReplicatedStorage.Shared.Features)
local GiftsMath = require(ReplicatedStorage.Shared.Domain.Gifts)
local Analytics = require("./Analytics")
local Inbox = require("./Inbox")
local PlayerData = require("./PlayerData")
local Sync = require("./Sync")

local Gifts = {}

local CHECK_SECONDS = 5 * 60

local function check(player: Player)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	local config = Content.Tuning.dailyGift
	local due, today = GiftsMath.due(data.gifts.lastDay, data.progression.level, config.untilLevel, os.time())
	if not due then
		return
	end
	data.gifts.lastDay = today
	Inbox.grant(player, config.items :: any, "DailyGift", true)
	Sync.notice(player, "Today's food and water are in your inbox", "good")
	Sync.fx(player, "dailyGift", { items = config.items })
	Analytics.custom(player, "DailyGift", 1, { tostring(data.progression.level) })
end

function Gifts.start()
	if not Features.on(Content.Tuning, "dailyGift") then
		return -- switched off in Tuning.features (on for launch, F-33)
	end
	PlayerData.loaded:Connect(check)
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				check(player)
			end
		end
	end)
end

return Gifts
