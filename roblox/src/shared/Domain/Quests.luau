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
		return objective.locationId == event.locationId
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
