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
local Plots = require("./Plots")
local Progression = require("./Progression")
local Sync = require("./Sync")

local Quests = {}

local settling: { [Player]: boolean } = {}

local holdingsContent: QuestsMath.HoldingsContent = {
	recipes = Content.Recipes :: any,
	items = Content.Items :: any,
	pieces = Content.BuildPieces :: any,
}

-- What is true now: level, what is worn, and what the player already has for craft and
-- build objectives (gear carried or worn, the pieces they placed; F-06).
local function facts(player: Player, data: any): QuestsMath.Facts
	local equipped: { [string]: boolean } = {}
	local slots: { any } = {}
	for _, slot in data.inventory.equipment do
		if slot.count > 0 then
			equipped[slot.itemId] = true
			table.insert(slots, slot)
		end
	end
	for _, container in { data.inventory.pockets, data.inventory.backpack } do
		for _, slot in container do
			table.insert(slots, slot)
		end
	end
	local plot = Plots.of(player)
	local pieces: { any } = {}
	for _, piece in (if plot then plot.layout.pieces else {}) :: { [string]: any } do
		table.insert(pieces, piece)
	end
	local made, placed = QuestsMath.holdings(slots, pieces, holdingsContent)
	return { level = data.progression.level, equipped = equipped, made = made, placed = placed }
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
	if event then
		data.quests = QuestsMath.record(data.quests :: any, Content.Quests, flags, event) :: any
	end
	Sync.mark(player, "quests")
	if settling[player] then
		-- Called back from a reward (its XP levelled the player up): the pass below
		-- settles again after paying, so nothing completes unpaid.
		return
	end
	settling[player] = true
	local ok, err = pcall(function()
		-- Completing a quest can complete the next (a reward's level-up meets reachLevel):
		-- settle and pay until nothing more completes.
		for _ = 1, 20 do
			local state, done =
				QuestsMath.settle(data.quests :: any, Content.Quests, flags, facts(player, data), os.time())
			data.quests = state :: any
			if #done == 0 then
				break
			end
			for _, questId in done do
				pay(player, questId)
			end
		end
	end)
	settling[player] = nil
	Sync.mark(player, "quests")
	if not ok then
		warn(`Quests: settling for {player.UserId} failed: {err}`)
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
	-- The plot loads after the profile: its placed pieces count once it is claimed (F-06).
	Plots.claimed:Connect(function(player: Player)
		settle(player, nil)
	end)
	for _, player in game:GetService("Players"):GetPlayers() do
		if PlayerData.get(player) then
			task.spawn(settle, player, nil)
		end
	end
end

return Quests
