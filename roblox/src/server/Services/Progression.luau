--!strict
--[[
	Progression: player XP and levels (Domain/Progression, Data/Levels).

	Services grant XP with `grantXp`. Each level reached grants its rewards
	(into the inventory, overflowing into the locked stash), restores
	Tuning.energy.levelUpRestore Energy, heals fully, and fires a "levelUp" effect
	for the client's celebration.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local ProgressionMath = require(ReplicatedStorage.Shared.Domain.Progression)
local Events = require("../Events")
local Analytics = require("./Analytics")
local Energy = require("./Energy")
local Inbox = require("./Inbox")
local PlayerData = require("./PlayerData")
local Survival = require("./Survival")
local Sync = require("./Sync")

local Progression = {}

-- Adds XP from `source` ("Gathering", ...) and handles any level-ups.
function Progression.grantXp(player: Player, amount: number, source: string)
	local data = PlayerData.get(player)
	if data == nil or amount <= 0 then
		return
	end
	local state, reached = ProgressionMath.addXp(data.progression, math.floor(amount), Content.Levels)
	data.progression.level = state.level
	data.progression.xp = state.xp
	Sync.mark(player, "progression")

	for _, def in reached do
		-- Level-up rewards always wait in the inbox (checklist 4.15): never lost, never
		-- dropped, taken when the player wants them.
		local rewards = def.rewards or {}
		Inbox.grant(player, rewards :: any, "LevelUp", true)
		Energy.restore(player, Content.Tuning.energy.levelUpRestore, "grant")
		Survival.healFull(player)
		Sync.fx(player, "levelUp", {
			level = def.level,
			rewards = rewards,
			inbox = #rewards > 0,
			energy = Content.Tuning.energy.levelUpRestore,
		})
		Analytics.progression(player, "PlayerLevel", "complete", def.level, nil, { source })
	end
	if #reached > 0 then
		Events.factsChanged:Fire(player) -- reachLevel quest objectives
	end
end

-- The player's level (1 until their data loads).
function Progression.level(player: Player): number
	local data = PlayerData.get(player)
	return if data then data.progression.level else 1
end

function Progression.start()
	Sync.provide("progression", function(player: Player)
		local data = PlayerData.get(player)
		if data == nil then
			return false
		end
		return { level = data.progression.level, xp = data.progression.xp }
	end)
end

return Progression
