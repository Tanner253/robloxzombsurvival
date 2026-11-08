--!strict
--[[
	Diagnostics: answers the example Ping remote so clients can check Net end to end,
	and (Studio only) grants a test kit when the Workspace attribute `DevKit` is true,
	so playtests can reach any part of the loop quickly. Never active in live games.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = require("../Net")
local PlayerData = require("./PlayerData")
local Inventory = require("./Inventory")

local Diagnostics = {}

-- What the Studio test kit holds (tools and weapons first, so they land in pockets).
local DEV_KIT = {
	{ itemId = "item.stone_hatchet", count = 1 },
	{ itemId = "item.stone_pick", count = 1 },
	{ itemId = "item.spiked_club", count = 1 },
	{ itemId = "item.scrapblade", count = 1 },
	{ itemId = "item.timber", count = 60 },
	{ itemId = "item.stone", count = 30 },
	{ itemId = "item.rope", count = 12 },
	{ itemId = "item.fiber", count = 20 },
}

function Diagnostics.init()
	Net.onInvoke("Ping", function(_player: Player, nonce: number)
		return nonce, workspace:GetServerTimeNow()
	end)
end

function Diagnostics.start()
	if not RunService:IsStudio() then
		return
	end
	PlayerData.loaded:Connect(function(player: Player)
		if workspace:GetAttribute("DevKit") == true then
			task.wait(1)
			if player.Parent == Players then
				Inventory.give(player, DEV_KIT)
			end
		end
	end)
end

return Diagnostics
