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
local Analytics = require("./Analytics")
local Energy = require("./Energy")
local Inventory = require("./Inventory")
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
		local rewards = def.rewards or {}
		local given, leftover = Inventory.give(player, rewards, "LevelUp")
		local stashed = Inventory.stash(player, leftover)
		Energy.restore(player, Content.Tuning.energy.levelUpRestore, "grant")
		Survival.healFull(player)
		Sync.fx(player, "levelUp", {
			level = def.level,
			rewards = given,
			stashed = #leftover > #stashed,
			energy = Content.Tuning.energy.levelUpRestore,
		})
		Analytics.progression(player, "PlayerLevel", "complete", def.level, nil, { source })
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
