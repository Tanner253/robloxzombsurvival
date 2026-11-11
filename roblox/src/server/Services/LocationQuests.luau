--!strict
--[[
	LocationQuests: what a Fog Run reports, and the location's own quests.

	1. Run play events for the Ember Trail (Events.played): "travel" on arriving in a run
	   (with the location's fog tier, so `{ kind = "travel", fogTier = 3 }` matches any
	   Black location), "kill" for a Hollow the player killed, "loot" for a container they
	   opened, "lootBody" for a Hollow's drop they picked up (Domain/Quests.lootEvent). Without these the trail's Fog Run quests could never finish.
	2. Location quests (LDOE_PARITY #45, ECONOMY §6.2): each location's `run.quests`,
	   counted from those events and from gathering during a run there, and paid once per
	   Tuning.locationQuests period per player (Domain/Quests.locationQuestOpen,
	   PlayerData.locationQuests), never once per lobby. XP goes straight to the player,
	   items to the inbox. Progress is per run: a new lobby starts the count again.
	The run's quests and their progress reach the client in RunState ("locationQuests").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Features = require(ReplicatedStorage.Shared.Features)
local QuestsMath = require(ReplicatedStorage.Shared.Domain.Quests)
local Types = require(ReplicatedStorage.Shared.Types)
local Events = require("../Events")
local Containers = require("./Containers")
local Hollow = require("./Hollow")
local Inbox = require("./Inbox")
local Lobby = require("./Lobby")
local PlayerData = require("./PlayerData")
local Progression = require("./Progression")
local Sync = require("./Sync")

local LocationQuests = {}

local tuning = Content.Tuning

type Progress = {
	lobbyId: string,
	counts: { [string]: { number } }, -- questId -> each objective's count
	done: { [string]: boolean }, -- finished this run (paid, or already paid today)
}

local progress: { [Player]: Progress } = {}

local function progressOf(player: Player, lobbyId: string): Progress
	local current = progress[player]
	if current == nil or current.lobbyId ~= lobbyId then
		current = { lobbyId = lobbyId, counts = {}, done = {} }
		progress[player] = current
	end
	return current
end

local function needed(objective: Types.QuestObjective): number
	local count = (objective :: any).count
	return if type(count) == "number" then count else 1
end

local function matches(objective: Types.QuestObjective, event: QuestsMath.Event): boolean
	local o = objective :: any
	if o.kind ~= event.kind then
		return false
	end
	if o.itemId and o.itemId ~= event.itemId then
		return false
	end
	if o.enemyId and o.enemyId ~= event.enemyId then
		return false
	end
	if o.locationId and o.locationId ~= event.locationId then
		return false
	end
	return true
end

local function finish(player: Player, quest: Types.LocationQuest)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	local now = os.time()
	local log = (data :: any).locationQuests or {}
	if not QuestsMath.locationQuestOpen(log, quest.id, now, tuning.locationQuests) then
		Sync.notice(player, `{quest.name}: done for today. It pays again tomorrow.`)
		return
	end
	(data :: any).locationQuests = QuestsMath.markLocationQuest(log, quest.id, now, tuning.locationQuests)
	local rewards = quest.rewards
	if rewards.xp > 0 then
		Progression.grantXp(player, rewards.xp, "LocationQuest")
	end
	local slots: { Types.Slot } = {}
	local items: { Types.ItemStack } = rewards.items or {}
	for _, stack in items do
		table.insert(slots, { itemId = stack.itemId, count = stack.count })
	end
	if #slots > 0 then
		Inbox.grant(player, slots, "LocationQuest")
	end
	Sync.notice(player, `{quest.name} done: +{rewards.xp} XP`, "good")
	Sync.fx(player, "locationQuestDone", { questId = quest.id, xp = rewards.xp, items = items })
end

-- Counts a play event toward the quests of the run the player is in.
local function count(player: Player, event: QuestsMath.Event)
	local run = Lobby.runOf(player)
	if run == nil then
		return
	end
	local location = run.hosted.location
	local quests = if location.run then location.run.quests else nil
	if quests == nil or #quests == 0 then
		return
	end
	local mine = progressOf(player, run.hosted.id)
	for _, quest in quests do
		if mine.done[quest.id] then
			continue
		end
		local counts = mine.counts[quest.id] or {}
		mine.counts[quest.id] = counts
		local changed, complete = false, true
		for index, objective in quest.objectives do
			local need = needed(objective)
			if matches(objective, event) and (counts[index] or 0) < need then
				counts[index] = math.min(need, (counts[index] or 0) + (event.count or 1))
				changed = true
			end
			if (counts[index] or 0) < need then
				complete = false
			end
		end
		if changed and complete then
			mine.done[quest.id] = true
			finish(player, quest)
		end
	end
end

local function report(player: Player, event: QuestsMath.Event)
	Events.played:Fire(player, event)
end

function LocationQuests.init() end

function LocationQuests.start()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	-- Gathering, crafting and the rest already report through Events.played; the run's
	-- own events are reported here and counted with them.
	Events.played:Connect(function(player: any, event: any)
		count(player, event)
	end)
	Lobby.entered:Connect(function(player: Player, run: Lobby.Run)
		local location = run.hosted.location
		report(player, { kind = "travel", locationId = location.id, fogTier = location.fogTier })
	end)
	Hollow.killed:Connect(function(hosted: Lobby.Hosted, _position: Vector3, enemy: Types.EnemyDef, killer: Player?)
		if killer then
			report(killer, { kind = "kill", enemyId = enemy.id, locationId = hosted.location.id, count = 1 })
		end
	end)
	Containers.looted:Connect(function(player: Player, hosted: Lobby.Hosted, source: string?)
		local event = QuestsMath.lootEvent(source or "container", hosted.location.id)
		if event then
			report(player, event)
		end
	end)
	Lobby.addRunState("locationQuests", function(player: Player, run: Lobby.Run): any
		local location = run.hosted.location
		local quests = if location.run then location.run.quests else nil
		if quests == nil then
			return nil
		end
		local mine = progressOf(player, run.hosted.id)
		local data = PlayerData.get(player)
		local log = if data then (data :: any).locationQuests or {} else {}
		local now = os.time()
		local rows = {}
		for _, quest in quests do
			local counts = mine.counts[quest.id] or {}
			local objectives = {}
			for index, objective in quest.objectives do
				table.insert(objectives, { have = counts[index] or 0, need = needed(objective) })
			end
			table.insert(rows, {
				id = quest.id,
				name = quest.name,
				description = quest.description,
				objectives = objectives,
				done = mine.done[quest.id] == true,
				paidToday = not QuestsMath.locationQuestOpen(log, quest.id, now, tuning.locationQuests),
			})
		end
		return rows
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		progress[player] = nil
	end)
end

return LocationQuests
