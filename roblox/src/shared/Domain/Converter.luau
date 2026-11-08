--!strict
--[[
	Converter: LDoE's stations (LDOE_PARITY #18). Pure; pass `now`, and an Rng for the
	Recycler's rolls.

	A station is one input slot, an output (one slot, or StationDef.outputSlots for the
	Recycler), an optional fuel slot and a level. Drop a stack into the input and it converts
	one batch at a time: a station recipe's inputs[1] -> outputs[1] (Data/Recipes), or a
	SalvageDef for the Recycler. A batch takes the recipe's seconds divided by the level's
	speedMultiplier. Every slot holds the level's slotCap items (LDoE: 20, +20 per level).
	Conversion pauses when the input runs short or the next batch's outputs won't fit, and on
	fuelled stations when the fuel runs out. Fuel burns only while converting, a unit at a
	time.

	State is saved with a timestamp (`at`) and advanced lazily: `advance` replays the time
	since `at` (offline time too) batch by batch, so nothing ticks per player. A batch's work
	is kept while it waits (no fuel, output full) and resumes when that clears. Taking the
	whole input out loses the batch in progress.

	Every function returns new state and never mutates its input.
]]

local Types = require("../Types")
local Rng = require("./Rng")
local Salvage = require("./Salvage")
local Unlocks = require("./Unlocks")

local Converter = {}

export type State = {
	stationId: Types.StationId,
	level: number,
	input: Types.Slot,
	output: Types.Container,
	fuel: Types.Slot, -- unlit fuel
	burnItem: Types.ItemId, -- the fuel unit burning now ("" when none)
	burnLeft: number, -- seconds left on it
	worked: number, -- seconds of work done on the batch in progress
	at: number, -- when the fields above were true (UTC seconds; 0 = not set yet)
}

-- One conversion a station offers.
export type Line = {
	key: string, -- the recipe id, or "salvage:<itemId>"
	recipeId: Types.RecipeId?, -- nil for Recycler lines
	inputItemId: Types.ItemId,
	inputCount: number,
	-- Fixed outputs; for a Recycler line, every possible output at its max count.
	outputs: { Types.ItemStack },
	salvage: Types.SalvageDef?,
	seconds: number, -- one batch at speedMultiplier 1
	stationLevel: number,
	unlock: Types.UnlockGate,
}

export type ItemLookup = { [string]: { stackSize: number, durability: number? } }

export type Context = {
	def: Types.StationDef,
	recipes: { [string]: Types.RecipeDef },
	items: ItemLookup,
	rng: Rng.Source?, -- Recycler rolls; without one, only guaranteed outputs at their minimum
	scalesChance: boolean?, -- Tuning.salvage.durabilityScalesChance
}

export type Reason =
	"notConvertible"
	| "locked"
	| "stationLevel"
	| "inputBusy"
	| "inputFull"
	| "notFuel"
	| "noFuelSlot"
	| "fuelBusy"
	| "fuelFull"
	| "empty"
	| "busy"
	| "maxLevel"

-- Why a station isn't converting right now, or "working".
export type Activity = "working" | "idle" | "short" | "outputFull" | "noFuel"

export type Status = {
	line: Line?, -- what the input converts with (nil when the input is empty)
	activity: Activity,
	batchSeconds: number,
	progress: number, -- 0..1 of the batch in progress
	batchRemaining: number, -- seconds until the next batch is done (while working)
	batchesLeft: number, -- whole batches the input still holds
	ready: number, -- items waiting in the output
	capacity: number, -- slotCap at this level
	fuelSeconds: number, -- seconds of fuel left, lit and unlit
	burnFraction: number, -- 0..1 left on the unit burning now (the burn bar)
}

local EPSILON = 1e-6
local DEFAULT_GATE: Types.UnlockGate = { kind = "default" }

local function emptySlot(): Types.Slot
	return { itemId = "", count = 0 }
end

local function copySlot(slot: Types.Slot): Types.Slot
	return { itemId = slot.itemId, count = slot.count, durability = slot.durability }
end

local function copy(state: State): State
	local output = table.create(#state.output) :: Types.Container
	for index, slot in state.output do
		output[index] = copySlot(slot)
	end
	return {
		stationId = state.stationId,
		level = state.level,
		input = copySlot(state.input),
		output = output,
		fuel = copySlot(state.fuel),
		burnItem = state.burnItem,
		burnLeft = state.burnLeft,
		worked = state.worked,
		at = state.at,
	}
end

-- Definitions ---------------------------------------------------------------------------------

function Converter.levelOf(def: Types.StationDef, level: number): Types.StationLevel
	for _, entry in def.levels do
		if entry.level == level then
			return entry
		end
	end
	error(`station '{def.id}' has no level {level}`)
end

-- Items each slot holds at `level` (input, output and fuel alike).
function Converter.slotCap(def: Types.StationDef, level: number): number
	return Converter.levelOf(def, level).slotCap
end

function Converter.outputSlots(def: Types.StationDef): number
	return def.outputSlots or 1
end

-- The next level's definition, or nil at the top.
function Converter.nextLevel(def: Types.StationDef, level: number): Types.StationLevel?
	for _, entry in def.levels do
		if entry.level == level + 1 then
			return entry
		end
	end
	return nil
end

-- Every conversion the station offers ("ALL RECIPES"), sorted by key.
function Converter.lines(def: Types.StationDef, recipes: { [string]: Types.RecipeDef }): { Line }
	local result: { Line } = {}
	for id, recipe in recipes do
		if recipe.stationId == def.id then
			table.insert(result, {
				key = id,
				recipeId = id,
				inputItemId = recipe.inputs[1].itemId,
				inputCount = recipe.inputs[1].count,
				outputs = { { itemId = recipe.outputs[1].itemId, count = recipe.outputs[1].count } },
				seconds = recipe.craftSeconds,
				stationLevel = recipe.stationLevel or 1,
				unlock = recipe.unlock,
			})
		end
	end
	for _, salvage in (def.salvage or {}) :: { Types.SalvageDef } do
		local outputs: { Types.ItemStack } = {}
		for _, output in salvage.outputs do
			table.insert(outputs, { itemId = output.itemId, count = output.max })
		end
		table.insert(result, {
			key = `salvage:{salvage.inputItemId}`,
			inputItemId = salvage.inputItemId,
			inputCount = 1,
			outputs = outputs,
			salvage = salvage,
			seconds = salvage.seconds,
			stationLevel = 1,
			unlock = DEFAULT_GATE,
		})
	end
	table.sort(result, function(a: Line, b: Line)
		return a.key < b.key
	end)
	return result
end

-- The line that converts `itemId` at this station, if any.
function Converter.lineFor(def: Types.StationDef, recipes: { [string]: Types.RecipeDef }, itemId: string): Line?
	if itemId == "" then
		return nil
	end
	for _, line in Converter.lines(def, recipes) do
		if line.inputItemId == itemId then
			return line
		end
	end
	return nil
end

-- Seconds one batch of `line` takes at `level` (whole seconds, rounded up).
function Converter.batchSeconds(line: Line, def: Types.StationDef, level: number): number
	local multiplier = Converter.levelOf(def, level).speedMultiplier
	assert(multiplier > 0, "speedMultiplier must be positive")
	return math.max(0, math.ceil(line.seconds / multiplier - EPSILON))
end

-- Seconds one unit of a fuel item burns: StationFuel.burnSeconds, else secondsPerUnit.
function Converter.burnSeconds(def: Types.StationDef, itemId: Types.ItemId): number
	local fuel = def.fuel
	if fuel == nil or itemId == "" then
		return 0
	end
	local perItem = fuel.burnSeconds and fuel.burnSeconds[itemId]
	return perItem or fuel.secondsPerUnit
end

-- Seconds of fuel left, the burning unit plus the unlit ones.
function Converter.fuelSeconds(state: State, def: Types.StationDef): number
	if def.fuel == nil then
		return 0
	end
	return state.burnLeft + state.fuel.count * Converter.burnSeconds(def, state.fuel.itemId)
end

-- A freshly built station at level 1.
function Converter.new(def: Types.StationDef, now: number): State
	local output = table.create(Converter.outputSlots(def)) :: Types.Container
	for index = 1, Converter.outputSlots(def) do
		output[index] = emptySlot()
	end
	return {
		stationId = def.id,
		level = 1,
		input = emptySlot(),
		output = output,
		fuel = emptySlot(),
		burnItem = "",
		burnLeft = 0,
		worked = 0,
		at = now,
	}
end

-- Whether every slot is empty (a station can only be demolished, or picked up, then).
function Converter.isEmpty(state: State): boolean
	if state.input.count > 0 or state.fuel.count > 0 then
		return false
	end
	for _, slot in state.output do
		if slot.count > 0 then
			return false
		end
	end
	return true
end

-- Items waiting in the output (the teal ready badge over the station, #23).
function Converter.ready(state: State): number
	local total = 0
	for _, slot in state.output do
		total += slot.count
	end
	return total
end

-- Advancing -----------------------------------------------------------------------------------

local function perSlot(items: ItemLookup, itemId: string, cap: number): number
	local def = items[itemId]
	if def and def.stackSize <= 1 then
		return 1
	end
	return cap
end

-- Puts `stacks` into `output` (merging, then empty slots). Returns false and leaves the
-- copy unusable when something would not fit; callers pass a copy.
local function addOutputs(output: Types.Container, stacks: { Types.ItemStack }, cap: number, items: ItemLookup): boolean
	for _, stack in stacks do
		local left = stack.count
		local room = perSlot(items, stack.itemId, cap)
		if room > 1 then
			for _, slot in output do
				if left <= 0 then
					break
				end
				if slot.itemId == stack.itemId and slot.count > 0 and slot.count < room then
					local moved = math.min(left, room - slot.count)
					slot.count += moved
					left -= moved
				end
			end
		end
		for _, slot in output do
			if left <= 0 then
				break
			end
			if slot.count <= 0 then
				local moved = math.min(left, room)
				slot.itemId = stack.itemId
				slot.count = moved
				slot.durability = nil
				local def = items[stack.itemId]
				if def and def.durability then
					slot.durability = def.durability
				end
				left -= moved
			end
		end
		if left > 0 then
			return false
		end
	end
	return true
end

local function fits(output: Types.Container, stacks: { Types.ItemStack }, cap: number, items: ItemLookup): boolean
	local trial = table.create(#output) :: Types.Container
	for index, slot in output do
		trial[index] = copySlot(slot)
	end
	return addOutputs(trial, stacks, cap, items)
end

-- Burns `seconds` of fuel, lighting units as needed.
local function burn(state: State, def: Types.StationDef, seconds: number)
	local left = seconds
	while left > EPSILON do
		if state.burnLeft <= EPSILON then
			if state.fuel.count <= 0 then
				state.burnLeft = 0
				return
			end
			state.burnItem = state.fuel.itemId
			state.burnLeft += Converter.burnSeconds(def, state.fuel.itemId)
			state.fuel.count -= 1
			if state.fuel.count <= 0 then
				state.fuel = emptySlot()
			end
		end
		local take = math.min(left, state.burnLeft)
		state.burnLeft -= take
		left -= take
	end
	if state.burnLeft <= EPSILON then
		state.burnLeft = 0
	end
end

-- The input's condition, 0..1, for salvage rolls (1 for items without durability).
local function condition(slot: Types.Slot, items: ItemLookup): number
	local def = items[slot.itemId]
	if def == nil or def.durability == nil or slot.durability == nil or def.durability <= 0 then
		return 1
	end
	return math.clamp(slot.durability / def.durability, 0, 1)
end

local function rollSalvage(salvage: Types.SalvageDef, ctx: Context, state: State, cond: number): { Types.ItemStack }
	local bonus = Converter.levelOf(ctx.def, state.level).salvageChanceBonus or 0
	local rng = ctx.rng
	if rng then
		return Salvage.roll(salvage, cond, bonus, ctx.scalesChance ~= false, rng)
	end
	-- No Rng (a client's prediction): only the guaranteed outputs, at their minimum.
	local result: { Types.ItemStack } = {}
	for _, output in salvage.outputs do
		if output.chance >= 1 then
			table.insert(result, { itemId = output.itemId, count = output.min })
		end
	end
	return result
end

-- Whether the input holds a whole batch and the station can work on it, and why not.
local function readiness(state: State, ctx: Context): (Line?, Activity)
	local line = Converter.lineFor(ctx.def, ctx.recipes, state.input.itemId)
	if line == nil or state.input.count <= 0 then
		return nil, "idle"
	end
	if state.input.count < line.inputCount or state.level < line.stationLevel then
		return line, "short"
	end
	local cap = Converter.slotCap(ctx.def, state.level)
	if not fits(state.output, line.outputs, cap, ctx.items) then
		return line, "outputFull"
	end
	if ctx.def.fuel and Converter.fuelSeconds(state, ctx.def) <= EPSILON then
		return line, "noFuel"
	end
	return line, "working"
end

--[[
	The station at `now`: every batch the time since `at` allowed, done. Returns the new
	state and the stacks produced (for analytics and quest progress).
]]
function Converter.advance(state: State, ctx: Context, now: number): (State, { Types.ItemStack })
	local result = copy(state)
	local produced: { Types.ItemStack } = {}
	if result.at <= 0 or now <= result.at then
		result.at = math.max(result.at, now)
		return result, produced
	end
	local available = now - result.at
	while true do
		local line, activity = readiness(result, ctx)
		if line == nil or activity ~= "working" then
			break
		end
		local need = math.max(0, Converter.batchSeconds(line, ctx.def, result.level) - result.worked)
		local budget = available
		if ctx.def.fuel then
			budget = math.min(budget, Converter.fuelSeconds(result, ctx.def))
		end
		if budget + EPSILON < need then
			result.worked += budget
			available -= budget
			if ctx.def.fuel then
				burn(result, ctx.def, budget)
			end
			break
		end
		available -= need
		if ctx.def.fuel then
			burn(result, ctx.def, need)
		end
		result.worked = 0
		local cond = condition(result.input, ctx.items)
		result.input.count -= line.inputCount
		if result.input.count <= 0 then
			result.input = emptySlot()
		end
		local outputs: { Types.ItemStack } = if line.salvage
			then rollSalvage(line.salvage, ctx, result, cond)
			else line.outputs
		local cap = Converter.slotCap(ctx.def, result.level)
		addOutputs(result.output, outputs, cap, ctx.items)
		for _, stack in outputs do
			table.insert(produced, { itemId = stack.itemId, count = stack.count })
		end
	end
	result.at = now
	return result, produced
end

-- What the station panel shows at `now` (advance the state to `now` first).
function Converter.status(state: State, ctx: Context): Status
	local line: Line?, activity: Activity = readiness(state, ctx)
	local cap = Converter.slotCap(ctx.def, state.level)
	local batchSeconds = if line then Converter.batchSeconds(line, ctx.def, state.level) else 0
	local burnTotal = Converter.burnSeconds(ctx.def, state.burnItem)
	return {
		line = line,
		activity = activity,
		batchSeconds = batchSeconds,
		progress = if batchSeconds > 0 then math.clamp(state.worked / batchSeconds, 0, 1) else 0,
		batchRemaining = math.max(0, batchSeconds - state.worked),
		batchesLeft = if line then state.input.count // line.inputCount else 0,
		ready = Converter.ready(state),
		capacity = cap,
		fuelSeconds = Converter.fuelSeconds(state, ctx.def),
		burnFraction = if burnTotal > 0 then math.clamp(state.burnLeft / burnTotal, 0, 1) else 0,
	}
end

-- Slots ------------------------------------------------------------------------------------------

--[[
	Drops up to slot.count items of slot.itemId into the input (dragging a stack in).
	Returns the new state and how many it took, or nil, 0 and a reason. The caller removes
	the accepted count from wherever the stack came from.
]]
function Converter.putInput(
	state: State,
	ctx: Context,
	progress: Unlocks.Progress,
	slot: Types.Slot,
	now: number
): (State?, number, Reason?)
	local line = Converter.lineFor(ctx.def, ctx.recipes, slot.itemId)
	if line == nil or slot.count <= 0 then
		return nil, 0, "notConvertible"
	end
	if not Unlocks.isMet(line.unlock, progress) then
		return nil, 0, "locked"
	end
	if state.level < line.stationLevel then
		return nil, 0, "stationLevel"
	end
	local result = Converter.advance(state, ctx, now)
	local input = result.input
	if input.count > 0 and input.itemId ~= slot.itemId then
		return nil, 0, "inputBusy"
	end
	local room = perSlot(ctx.items, slot.itemId, Converter.slotCap(ctx.def, result.level)) - input.count
	local accepted = math.min(slot.count, room)
	if accepted <= 0 then
		return nil, 0, "inputFull"
	end
	if input.count <= 0 then
		result.worked = 0
		result.input = { itemId = slot.itemId, count = accepted, durability = slot.durability }
	else
		input.count += accepted
	end
	return result, accepted, nil
end

-- Takes up to `count` (default all) items back out of the input.
function Converter.takeInput(state: State, ctx: Context, count: number?, now: number): (State, Types.Slot)
	local result = Converter.advance(state, ctx, now)
	local input = result.input
	local taken = math.min(count or input.count, input.count)
	if taken <= 0 then
		return result, emptySlot()
	end
	local slot = { itemId = input.itemId, count = taken, durability = input.durability }
	input.count -= taken
	if input.count <= 0 then
		result.input = emptySlot()
		result.worked = 0
	end
	return result, slot
end

-- Takes up to `count` (default all) from output slot `index`.
function Converter.takeOutput(
	state: State,
	ctx: Context,
	index: number,
	count: number?,
	now: number
): (State, Types.Slot)
	local result = Converter.advance(state, ctx, now)
	local slot = result.output[index]
	if slot == nil or slot.count <= 0 then
		return result, emptySlot()
	end
	local taken = math.min(count or slot.count, slot.count)
	local out = { itemId = slot.itemId, count = taken, durability = slot.durability }
	slot.count -= taken
	if slot.count <= 0 then
		result.output[index] = emptySlot()
	end
	return result, out
end

-- Drops up to `count` fuel items into the fuel slot. Returns the new state and how many
-- it took, or nil, 0 and a reason.
function Converter.putFuel(
	state: State,
	ctx: Context,
	itemId: Types.ItemId,
	count: number,
	now: number
): (State?, number, Reason?)
	local fuel = ctx.def.fuel
	if fuel == nil then
		return nil, 0, "noFuelSlot"
	end
	if not table.find(fuel.itemIds, itemId) then
		return nil, 0, "notFuel"
	end
	local result = Converter.advance(state, ctx, now)
	if result.fuel.count > 0 and result.fuel.itemId ~= itemId then
		return nil, 0, "fuelBusy"
	end
	local accepted = math.min(count, Converter.slotCap(ctx.def, result.level) - result.fuel.count)
	if accepted <= 0 then
		return nil, 0, "fuelFull"
	end
	local filled: Types.Slot = { itemId = itemId, count = result.fuel.count + accepted }
	result.fuel = filled
	return result, accepted, nil
end

-- Takes up to `count` (default all) unlit fuel back out.
function Converter.takeFuel(state: State, ctx: Context, count: number?, now: number): (State, Types.Slot)
	local result = Converter.advance(state, ctx, now)
	local taken = math.min(count or result.fuel.count, result.fuel.count)
	if taken <= 0 then
		return result, emptySlot()
	end
	local slot: Types.Slot = { itemId = result.fuel.itemId, count = taken }
	result.fuel.count -= taken
	if result.fuel.count <= 0 then
		result.fuel = emptySlot()
	end
	return result, slot
end

--[[
	Raises the station one level (the caller pays Converter.nextLevel(...).upgradeCost). Like
	LDoE, a station that is converting can't be upgraded. Returns the new state, or nil and
	"maxLevel" or "busy".
]]
function Converter.upgrade(state: State, ctx: Context, now: number): (State?, Reason?)
	local nextLevel = Converter.nextLevel(ctx.def, state.level)
	if nextLevel == nil then
		return nil, "maxLevel"
	end
	local result = Converter.advance(state, ctx, now)
	if result.input.count > 0 then
		return nil, "busy"
	end
	result.level = nextLevel.level
	return result, nil
end

return Converter
