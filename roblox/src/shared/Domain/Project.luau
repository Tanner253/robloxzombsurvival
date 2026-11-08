--!strict
--[[
	Project: a long-term build goal restored by handing in parts (Data/Projects, LDOE_PARITY
	#56; LDoE's broken-chopper checklist). Pure.

	Saved per outpost as { delivered = { [itemId] = count }, finishedAt = 0 }. The checklist
	screen shows have/need per part (have = the home pool), a per-part FILL UP that hands in
	as much as the pool allows, and FINALIZE once every part is in.
]]

local Types = require("../Types")

local Project = {}

export type State = {
	delivered: { [string]: number },
	finishedAt: number, -- 0 until finalized
}

-- One checklist row.
export type Row = {
	itemId: Types.ItemId,
	delivered: number,
	need: number,
	done: boolean,
}

function Project.new(): State
	return { delivered = {}, finishedAt = 0 }
end

local function needOf(def: Types.ProjectDef, itemId: string): number
	for _, part in def.parts do
		if part.itemId == itemId then
			return part.count
		end
	end
	return 0
end

-- The checklist, in the def's part order.
function Project.rows(def: Types.ProjectDef, state: State): { Row }
	local rows: { Row } = {}
	for _, part in def.parts do
		local delivered = math.min(part.count, state.delivered[part.itemId] or 0)
		table.insert(
			rows,
			{ itemId = part.itemId, delivered = delivered, need = part.count, done = delivered >= part.count }
		)
	end
	return rows
end

-- How many of `itemId` the project still needs.
function Project.missing(def: Types.ProjectDef, state: State, itemId: string): number
	return math.max(0, needOf(def, itemId) - (state.delivered[itemId] or 0))
end

--[[
	Hands in up to `available` of a part (FILL UP for one row). Returns the new state and
	how many were taken (0 when the part isn't needed, is complete, or the project is
	finished).
]]
function Project.deliver(def: Types.ProjectDef, state: State, itemId: string, available: number): (State, number)
	if state.finishedAt > 0 then
		return state, 0
	end
	local taken = math.min(math.max(0, math.floor(available)), Project.missing(def, state, itemId))
	if taken <= 0 then
		return state, 0
	end
	local delivered = table.clone(state.delivered)
	delivered[itemId] = (delivered[itemId] or 0) + taken
	return { delivered = delivered, finishedAt = state.finishedAt }, taken
end

function Project.isReady(def: Types.ProjectDef, state: State): boolean
	for _, part in def.parts do
		if (state.delivered[part.itemId] or 0) < part.count then
			return false
		end
	end
	return state.finishedAt == 0
end

-- FINALIZE: returns the finished state, or nil and "missingParts" / "finished".
function Project.finalize(def: Types.ProjectDef, state: State, now: number): (State?, string?)
	if state.finishedAt > 0 then
		return nil, "finished"
	end
	if not Project.isReady(def, state) then
		return nil, "missingParts"
	end
	return { delivered = table.clone(state.delivered), finishedAt = now }, nil
end

return Project
