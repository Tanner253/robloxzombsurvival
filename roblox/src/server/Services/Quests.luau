--!strict
--[[
	Quests: the Ember Trail (Domain/Quests, LDOE_PARITY #48-50).

	Listens to Events.played (gather, craft, build, consume...) and Events.factsChanged
	(equip, level), records progress in PlayerData.quests and settles: a quest completes by
	itself on its last objective, its rewards go to the inbox (XP and Energy straight to the
	player), and the next quests open. Completing a quest is also what unlocks blueprints:
	recipe and piece gates read `quests.completed` (Domain/Unlocks).

	The client gets the "quests" section and builds the tracker from it with the same
	Domain/Quests and Shared/Flags; the "questDone" effect drives the reward pop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Flags = require(ReplicatedStorage.Shared.Flags)
local QuestsMath = require(ReplicatedStorage.Shared.Domain.Quests)
local Unlocks = require(ReplicatedStorage.Shared.Domain.Unlocks)
local Events = require("../Events")
local Analytics = require("./Analytics")
local Energy = require("./Energy")
local Inbox = require("./Inbox")
local PlayerData = require("./PlayerData")
local Progression = require("./Progression")
local Sync = require("./Sync")

local Quests = {}

local settling: { [Player]: boolean } = {}

local function facts(data: any): QuestsMath.Facts
	local equipped: { [string]: boolean } = {}
	for _, slot in data.inventory.equipment do
		if slot.count > 0 then
			equipped[slot.itemId] = true
		end
	end
	return { level = data.progression.level, equipped = equipped }
end

local function pay(player: Player, questId: string)
	local def = Content.Quests[questId]
	local rewards = def.rewards
	local items = rewards.items or {}
	Inbox.grant(player, items :: any, "Quest", true)
	if rewards.energy then
		Energy.restore(player, rewards.energy, "grant")
	end
	local recipes, pieces = Unlocks.byQuest(questId, Content.Recipes :: any, Content.BuildPieces :: any)
	Sync.fx(player, "questDone", {
		questId = questId,
		xp = rewards.xp,
		items = items,
		energy = rewards.energy,
		recipes = recipes,
		pieces = pieces,
	})
	Analytics.progression(player, questId, "complete", def.order)
	-- XP last: a level-up it causes re-checks reachLevel objectives through factsChanged.
	if rewards.xp > 0 then
		Progression.grantXp(player, rewards.xp, "Quest")
	end
end

-- Records progress and completes whatever is done. Safe to call re-entrantly.
local function settle(player: Player, event: QuestsMath.Event?)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	local flags = Flags.snapshot()
	local state: QuestsMath.State = data.quests :: any
	if event then
		state = QuestsMath.record(state, Content.Quests, flags, event)
	end
	local done
	state, done = QuestsMath.settle(state, Content.Quests, flags, facts(data), os.time())
	data.quests = state :: any
	Sync.mark(player, "quests")
	if settling[player] then
		return -- a reward's level-up settles again once this pass returns
	end
	settling[player] = true
	for _, questId in done do
		pay(player, questId)
	end
	settling[player] = nil
	if #done > 0 then
		-- Rewards may have changed the facts (XP -> level); settle what that completes.
		local settled, again = QuestsMath.settle(data.quests :: any, Content.Quests, flags, facts(data), os.time())
		data.quests = settled :: any
		for _, questId in again do
			pay(player, questId)
		end
		Sync.mark(player, "quests")
	end
end

-- Reports something counted toward quest objectives (same as Events.played).
function Quests.record(player: Player, event: QuestsMath.Event)
	settle(player, event)
end

-- The parts of PlayerData that meet unlock gates (Domain/Unlocks), for other services.
function Quests.progress(data: any): Unlocks.Progress
	return { level = data.progression.level, unlocks = data.unlocks, quests = data.quests }
end

function Quests.init()
	Sync.provide("quests", function(player: Player)
		local data = PlayerData.get(player)
		return if data then data.quests else false
	end)
end

function Quests.start()
	Events.played:Connect(function(player: any, event: any)
		settle(player, event)
	end)
	Events.factsChanged:Connect(function(player: any)
		settle(player, nil)
	end)
	PlayerData.loaded:Connect(function(player: Player)
		settle(player, nil)
	end)
	for _, player in game:GetService("Players"):GetPlayers() do
		if PlayerData.get(player) then
			task.spawn(settle, player, nil)
		end
	end
end

return Quests
