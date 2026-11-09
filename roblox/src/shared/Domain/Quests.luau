--!strict
--[[
	Quests: the Ember Trail's progress (LDOE_PARITY #48-50). Pure; pass `now` and the flag
	snapshot (Shared/Flags) in.

	Saved as PlayerData.quests = { active = { [questId] = { progress = { ["<n>"] = count } } },
	completed = { [questId] = completedAt } }.

	- A quest opens (joins `active`) once its prerequisite is complete.
	- Gameplay reports events ("gather 2 item.sticks", "build build.wall_wood"); each adds to
	  the matching objectives of every active quest, capped at the objective's count. State
	  objectives (equip, reachLevel) are checked against `facts` instead, so a satchel worn
	  before the quest opened still counts.
	- A quest completes by itself on its last objective (#50): `settle` moves it to
	  `completed`, opens the next one and repeats, so a chain of already-met quests settles
	  in one call. The caller pays the rewards into the inbox.
	- Objectives with a flag that is off are left out. A quest with no objectives left is
	  dormant: it never completes, and the tracker skips it.

	Location quests (LDOE_PARITY #45) pay once per Tuning.locationQuests period per player
	(ECONOMY §6.2: once per UTC day), never once per lobby: a Rations reward that repeated
	every lobby would refund the Run's Energy. PlayerData.locationQuests remembers the period
	each one last paid (`locationQuestOpen`, `markLocationQuest`).

	On top of that, all location quests together pay at most Tuning.energy.locationQuestRations
	Trail Rations a UTC day per player, whatever their data says (the content parity audit's
	BR-9: four dailies paid up to 5, more Energy than a day's regen). `payLocationQuest` is
	the one call a payer makes: it marks the quest paid and returns its rewards with the
	Rations cut to what the day has left; the rest of the reward is paid in full. The day's
	tally needs no profile field: each quest the log marks for today paid its data Rations
	cut to the cap's remainder, so in any order the total is min(cap, their sum).
]]

local Types = require("../Types")

local Quests = {}

export type QuestState = { progress: { [string]: number } }
export type State = {
	active: { [string]: QuestState },
	completed: { [string]: number },
}

export type Defs = { [Types.QuestId]: Types.QuestDef }
export type Flags = { [string]: boolean }

-- Something that happened in play. `count` defaults to 1.
export type Event = {
	kind: string, -- an objective kind: "gather", "craft", "build", "travel", "loot", "lootBody", "kill", "consume"
	itemId: string?,
	recipeId: string?,
	pieceId: string?,
	locationId: string?,
	fogTier: number?, -- travel: the fog tier of the location arrived at
	enemyId: string?,
	count: number?,
}

-- What is true right now, for the state objectives.
export type Facts = {
	level: number,
	equipped: { [string]: boolean }, -- item ids worn or held
}

-- One tracker row: a quest and its objectives with progress.
export type Row = {
	questId: Types.QuestId,
	name: string,
	chapter: string,
	order: number,
	objectives: { { index: number, objective: Types.QuestObjective, have: number, need: number, done: boolean } },
	nextIndex: number?, -- the first objective not yet done
}

function Quests.newState(): State
	return { active = {}, completed = {} }
end

local function copy(state: State): State
	local active: { [string]: QuestState } = {}
	for id, quest in state.active do
		active[id] = { progress = table.clone(quest.progress) }
	end
	return { active = active, completed = table.clone(state.completed) }
end

-- The objectives that count, by index (flagged ones whose flag is off are left out).
function Quests.objectives(def: Types.QuestDef, flags: Flags): { [number]: Types.QuestObjective }
	local result: { [number]: Types.QuestObjective } = {}
	for index, objective in def.objectives do
		local flag = objective.flag
		if flag == nil or flags[flag] == true then
			result[index] = objective
		end
	end
	return result
end

function Quests.isDormant(def: Types.QuestDef, flags: Flags): boolean
	return next(Quests.objectives(def, flags)) == nil
end

-- How many an objective needs.
function Quests.need(objective: Types.QuestObjective): number
	local count = (objective :: any).count
	return if type(count) == "number" then count else 1
end

local function matches(objective: Types.QuestObjective, event: Event): boolean
	if objective.kind ~= event.kind then
		return false
	end
	if objective.kind == "gather" or objective.kind == "consume" then
		return objective.itemId == event.itemId
	elseif objective.kind == "craft" then
		return objective.recipeId == event.recipeId
	elseif objective.kind == "build" then
		return objective.pieceId == event.pieceId
	elseif objective.kind == "travel" then
		if objective.locationId ~= nil then
			return objective.locationId == event.locationId
		end
		return objective.fogTier ~= nil and objective.fogTier == event.fogTier
	elseif objective.kind == "loot" then
		return objective.locationId == nil or objective.locationId == event.locationId
	elseif objective.kind == "kill" then
		return objective.enemyId == nil or objective.enemyId == event.enemyId
	elseif objective.kind == "lootBody" then
		return true
	end
	return false
end

local function opened(def: Types.QuestDef, state: State): boolean
	return state.completed[def.id] == nil and (def.prerequisite == nil or state.completed[def.prerequisite] ~= nil)
end

-- Opens every quest whose prerequisite is complete. Returns the new state.
function Quests.open(state: State, defs: Defs): State
	local result = copy(state)
	for id, def in defs do
		if result.active[id] == nil and opened(def, result) then
			result.active[id] = { progress = {} }
		end
	end
	return result
end

-- Adds an event to every matching objective of the active quests. Returns the new state.
function Quests.record(state: State, defs: Defs, flags: Flags, event: Event): State
	local result = copy(state)
	local amount = event.count or 1
	if amount <= 0 then
		return result
	end
	for id, quest in result.active do
		local def = defs[id]
		if def then
			for index, objective in Quests.objectives(def, flags) do
				if matches(objective, event) then
					local key = tostring(index)
					quest.progress[key] = math.min(Quests.need(objective), (quest.progress[key] or 0) + amount)
				end
			end
		end
	end
	return result
end

-- Sets the state objectives (equip, reachLevel) of the active quests from `facts`.
function Quests.observe(state: State, defs: Defs, flags: Flags, facts: Facts): State
	local result = copy(state)
	for id, quest in result.active do
		local def = defs[id]
		if def then
			for index, objective in Quests.objectives(def, flags) do
				local key = tostring(index)
				local met = (objective.kind == "equip" and facts.equipped[objective.itemId] == true)
					or (objective.kind == "reachLevel" and facts.level >= objective.level)
				if met then
					quest.progress[key] = 1
				end
			end
		end
	end
	return result
end

function Quests.isComplete(def: Types.QuestDef, quest: QuestState?, flags: Flags): boolean
	if quest == nil then
		return false
	end
	local any = false
	for index, objective in Quests.objectives(def, flags) do
		any = true
		if (quest.progress[tostring(index)] or 0) < Quests.need(objective) then
			return false
		end
	end
	return any
end

--[[
	Completes every active quest whose objectives are all met, opens what follows and
	repeats until nothing changes. Returns the new state and the completed quest ids in
	trail order (the caller pays their rewards).
]]
function Quests.settle(state: State, defs: Defs, flags: Flags, facts: Facts, now: number): (State, { Types.QuestId })
	local result = Quests.observe(Quests.open(state, defs), defs, flags, facts)
	local done: { Types.QuestId } = {}
	for _ = 1, 100 do
		local finished: { Types.QuestDef } = {}
		for id, quest in result.active do
			local def = defs[id]
			if def and Quests.isComplete(def, quest, flags) then
				table.insert(finished, def)
			end
		end
		if #finished == 0 then
			break
		end
		table.sort(finished, function(a: Types.QuestDef, b: Types.QuestDef)
			return a.order < b.order
		end)
		for _, def in finished do
			result.active[def.id] = nil
			result.completed[def.id] = now
			table.insert(done, def.id)
		end
		result = Quests.observe(Quests.open(result, defs), defs, flags, facts)
	end
	-- Quests that left the content keep nothing open.
	for id in result.active do
		if defs[id] == nil then
			result.active[id] = nil
		end
	end
	return result, done
end

-- Location quests --------------------------------------------------------------------------

-- questId -> the period number (a UTC day for "daily") it last paid out.
export type LocationQuestLog = { [string]: number }

local DAY_SECONDS = 24 * 60 * 60

-- The period `now` falls in (Tuning.locationQuests.period).
function Quests.periodOf(now: number, config: { period: "daily" }): number
	assert(config.period == "daily", "unknown location quest period")
	return now // DAY_SECONDS
end

-- Whether a location quest can still pay out in this period.
function Quests.locationQuestOpen(
	log: LocationQuestLog,
	questId: Types.QuestId,
	now: number,
	config: { period: "daily" }
): boolean
	return log[questId] ~= Quests.periodOf(now, config)
end

-- The log after a location quest paid out at `now` (a new table).
function Quests.markLocationQuest(
	log: LocationQuestLog,
	questId: Types.QuestId,
	now: number,
	config: { period: "daily" }
): LocationQuestLog
	local result = table.clone(log)
	result[questId] = Quests.periodOf(now, config)
	return result
end

-- The daily Ration cap on location quests (Tuning.energy.locationQuestRations).
export type RationCap = { itemId: Types.ItemId, perDay: number }

-- What a finished location quest pays (`payLocationQuest`).
export type LocationPayout = {
	log: LocationQuestLog, -- the log with this quest marked paid for the period
	rewards: Types.QuestRewards, -- the quest's rewards with its Rations cut to the cap
	withheld: number, -- Rations the cap kept back
}

-- Every location quest by ID (each location keeps its own on `run.quests`).
function Quests.locationQuestDefs(locations: { [string]: Types.LocationDef }): { [string]: Types.LocationQuest }
	local defs: { [string]: Types.LocationQuest } = {}
	for _, location in locations do
		local run = location.run
		for _, quest in (if run then run.quests else {}) :: { Types.LocationQuest } do
			defs[quest.id] = quest
		end
	end
	return defs
end

local function countOf(items: { Types.ItemStack }?, itemId: string): number
	local total = 0
	for _, stack in (items or {}) :: { Types.ItemStack } do
		if stack.itemId == itemId then
			total += stack.count
		end
	end
	return total
end

-- The capped Rations the location quests in `log` paid in `now`'s period: min(cap, the sum
-- of the data Rations of every quest the log marks for that period). `defs` is
-- `locationQuestDefs` of the content; a quest no longer in it counts as none.
function Quests.locationRationsPaid(
	log: LocationQuestLog,
	defs: { [string]: Types.LocationQuest },
	now: number,
	config: { period: "daily" },
	cap: RationCap
): number
	local period = Quests.periodOf(now, config)
	local total = 0
	for questId, paid in log do
		local def = defs[questId]
		if paid == period and def then
			total += countOf(def.rewards.items, cap.itemId)
		end
	end
	return math.min(cap.perDay, total)
end

--[[
	Pays a finished location quest at `now`: nil if it already paid this period, else the
	log with it marked and the rewards to grant (XP and other items as the data has them;
	its Rations cut to what the day's cap has left, and dropped once the cap is spent).
]]
function Quests.payLocationQuest(
	log: LocationQuestLog,
	quest: Types.LocationQuest,
	defs: { [string]: Types.LocationQuest },
	now: number,
	config: { period: "daily" },
	cap: RationCap
): LocationPayout?
	if not Quests.locationQuestOpen(log, quest.id, now, config) then
		return nil
	end
	local left = math.max(0, cap.perDay - Quests.locationRationsPaid(log, defs, now, config, cap))
	local wanted = countOf(quest.rewards.items, cap.itemId)
	local items: { Types.ItemStack } = {}
	for _, stack in (quest.rewards.items or {}) :: { Types.ItemStack } do
		if stack.itemId ~= cap.itemId then
			table.insert(items, { itemId = stack.itemId, count = stack.count })
		elseif left > 0 then
			local count = math.min(stack.count, left)
			left -= count
			table.insert(items, { itemId = stack.itemId, count = count })
		end
	end
	local paid = countOf(items, cap.itemId)
	return {
		log = Quests.markLocationQuest(log, quest.id, now, config),
		rewards = { xp = quest.rewards.xp, items = items, energy = quest.rewards.energy },
		withheld = wanted - paid,
	}
end

-- The tracker (#50): up to `limit` active quests that can progress, in trail order, each
-- with its objectives and the next step.
function Quests.tracker(state: State, defs: Defs, flags: Flags, limit: number?): { Row }
	local rows: { Row } = {}
	for id, quest in state.active do
		local def = defs[id]
		if def and not Quests.isDormant(def, flags) then
			local row: Row = {
				questId = id,
				name = def.name,
				chapter = def.chapter,
				order = def.order,
				objectives = {},
				nextIndex = nil,
			}
			local indices: { number } = {}
			for index in Quests.objectives(def, flags) do
				table.insert(indices, index)
			end
			table.sort(indices)
			for _, index in indices do
				local objective = def.objectives[index]
				local need = Quests.need(objective)
				local have = math.min(need, quest.progress[tostring(index)] or 0)
				table.insert(
					row.objectives,
					{ index = index, objective = objective, have = have, need = need, done = have >= need }
				)
				if have < need and row.nextIndex == nil then
					row.nextIndex = index
				end
			end
			table.insert(rows, row)
		end
	end
	table.sort(rows, function(a: Row, b: Row)
		return a.order < b.order
	end)
	local cap = limit or 3
	while #rows > cap do
		table.remove(rows)
	end
	return rows
end

return Quests
