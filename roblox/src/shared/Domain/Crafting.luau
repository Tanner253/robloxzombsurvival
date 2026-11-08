--!strict
--[[
	Crafting: recipes, station queues and fuel (ARCHITECTURE.md §1.5;
	ldoe-systems/economy-progression.md §3).

	A station's state is PlayerSchema.StationState: { stationId, level, queue,
	fuelEndsAt }. The queue is a Timers.Queue of back-to-back jobs, one job per
	recipe run, with absolute timestamps, so offline progress is just "which jobs
	end before now". A finished job stays in the queue, still using a slot, until
	its outputs are collected. That is the "full output slot": when the player's
	inventory cannot take a job's outputs, the job waits in the station.

	Fuel (stations with StationDef.fuel): fuel burns from the moment it is added,
	like a lit campfire, until `fuelEndsAt`. Jobs only progress while it burns. A
	job that would end after the fuel runs out is stalled; adding fuel later
	re-lays the stalled jobs from that moment, keeping the work already done.

	Every function is pure and atomic: it returns new state or nil and a reason,
	and never half-applies a change. Inventory changes use Domain/Inventory.
	Hand recipes (no stationId) complete instantly.
]]

local Types = require("../Types")
local Inventory = require("./Inventory")
local Timers = require("./Timers")

local Crafting = {}

export type Station = {
	stationId: Types.StationId,
	level: number,
	queue: Timers.Queue,
	fuelEndsAt: number,
}

-- The parts of PlayerData that gate recipes.
export type Progress = {
	level: number,
	unlocks: { recipes: { [string]: boolean }, blueprints: { [string]: boolean } },
}

export type Recipes = { [Types.RecipeId]: Types.RecipeDef }

export type Reason =
	"locked"
	| "wrongStation"
	| "stationLevel"
	| "missingInputs"
	| "queueFull"
	| "inventoryFull"
	| "notFound"
	| "finished"
	| "noFuel"
	| "notFuel"
	| "busy"
	| "maxLevel"

export type JobStatus = {
	index: number,
	recipeId: Types.RecipeId,
	done: boolean, -- outputs ready to collect
	stalled: boolean, -- waiting for fuel
	progress: number, -- 0 to 1
	remaining: number, -- seconds of work left
}

local EPSILON = 1e-9

local function assertCount(count: number)
	assert(count >= 1 and count % 1 == 0, "count must be a positive integer")
end

local function scaled(stacks: { Types.ItemStack }, times: number): { Types.ItemStack }
	local result: { Types.ItemStack } = {}
	for index, stack in stacks do
		result[index] = { itemId = stack.itemId, count = stack.count * times }
	end
	return result
end

-- Adds every stack or nothing. Returns nil when something would not fit.
local function addAll(
	inventory: Types.Inventory,
	stacks: { Types.ItemStack },
	items: Inventory.ItemLookup
): Types.Inventory?
	local result = inventory
	for _, stack in stacks do
		local nextInventory, left = Inventory.add(result, stack.itemId, stack.count, items)
		if left > 0 then
			return nil
		end
		result = nextInventory
	end
	return result
end

local function levelOf(stationDef: Types.StationDef, level: number): Types.StationLevel?
	for _, entry in stationDef.levels do
		if entry.level == level then
			return entry
		end
	end
	return nil
end

local function currentLevel(station: Station, stationDef: Types.StationDef): Types.StationLevel
	local entry = levelOf(stationDef, station.level)
	assert(entry, `station '{stationDef.id}' has no level {station.level}`)
	return entry
end

-- The moment up to which jobs have progressed: now, or when the fuel ran out.
local function workedUntil(station: Station, stationDef: Types.StationDef, now: number): number
	if stationDef.fuel then
		return math.min(now, station.fuelEndsAt)
	end
	return now
end

--[[
	Re-lays the unfinished jobs back to back from `origin`, keeping the work each
	had done by `measuredAt`. Jobs finished by `measuredAt` are untouched.
]]
local function relay(queue: Timers.Queue, measuredAt: number, origin: number): Timers.Queue
	local result: Timers.Queue = {}
	local cursor = origin
	for _, job in queue do
		if job.endsAt <= measuredAt then
			table.insert(result, job)
		else
			local duration = job.endsAt - job.startsAt
			local done = math.clamp(measuredAt - job.startsAt, 0, duration)
			local startsAt = cursor - done
			local endsAt = startsAt + duration
			table.insert(result, { id = job.id, startsAt = startsAt, endsAt = endsAt })
			cursor = endsAt
		end
	end
	return result
end

local function withQueue(station: Station, queue: Timers.Queue, fuelEndsAt: number?): Station
	return {
		stationId = station.stationId,
		level = station.level,
		queue = queue,
		fuelEndsAt = fuelEndsAt or station.fuelEndsAt,
	}
end

-- A freshly built station at level 1.
function Crafting.newStation(stationId: Types.StationId): Station
	return { stationId = stationId, level = 1, queue = {}, fuelEndsAt = 0 }
end

-- Whether the player has unlocked `recipe` (by its gate, or an explicit unlock).
function Crafting.isUnlocked(recipe: Types.RecipeDef, progress: Progress): boolean
	if progress.unlocks.recipes[recipe.id] then
		return true
	end
	local gate = recipe.unlock
	if gate.kind == "default" then
		return true
	elseif gate.kind == "level" then
		return progress.level >= gate.level
	else
		return progress.unlocks.blueprints[gate.itemId] == true
	end
end

-- Seconds one run of `recipe` takes at the station's level (whole seconds, rounded up).
function Crafting.jobSeconds(recipe: Types.RecipeDef, stationDef: Types.StationDef, level: number): number
	local entry = levelOf(stationDef, level)
	assert(entry, `station '{stationDef.id}' has no level {level}`)
	assert(entry.speedMultiplier > 0, "speedMultiplier must be positive")
	return math.max(0, math.ceil(recipe.craftSeconds / entry.speedMultiplier - EPSILON))
end

--[[
	Checks that `count` runs of `recipe` can start now. Pass the station for
	station recipes and nil for hand recipes. Returns true, or false and a reason.
]]
function Crafting.check(
	recipe: Types.RecipeDef,
	inventory: Types.Inventory,
	progress: Progress,
	station: Station?,
	stationDef: Types.StationDef?,
	count: number?
): (boolean, Reason?)
	local times = count or 1
	assertCount(times)
	if not Crafting.isUnlocked(recipe, progress) then
		return false, "locked"
	end
	if recipe.stationId then
		if
			not station
			or not stationDef
			or station.stationId ~= recipe.stationId
			or stationDef.id ~= recipe.stationId
		then
			return false, "wrongStation"
		end
		if station.level < (recipe.stationLevel or 1) then
			return false, "stationLevel"
		end
		if #station.queue + times > currentLevel(station, stationDef).queueSlots then
			return false, "queueFull"
		end
	elseif station then
		return false, "wrongStation"
	end
	if not Inventory.hasAll(inventory, scaled(recipe.inputs, times)) then
		return false, "missingInputs"
	end
	return true, nil
end

--[[
	Crafts a hand recipe instantly: inputs out, outputs in. Returns the new
	inventory, or nil and a reason ("inventoryFull" when the outputs would not fit
	after the inputs are taken).
]]
function Crafting.craftByHand(
	inventory: Types.Inventory,
	recipe: Types.RecipeDef,
	progress: Progress,
	items: Inventory.ItemLookup,
	count: number?
): (Types.Inventory?, Reason?)
	local times = count or 1
	local ok: boolean, reason: Reason? = Crafting.check(recipe, inventory, progress, nil, nil, times)
	if not ok then
		return nil, reason
	end
	local taken = Inventory.removeAll(inventory, scaled(recipe.inputs, times)) :: Types.Inventory
	local result = addAll(taken, scaled(recipe.outputs, times), items)
	if not result then
		return nil, "inventoryFull"
	end
	return result, nil
end

--[[
	Takes the inputs for `count` runs and queues them at the station. Returns
	the new inventory and station, or nil, nil and a reason.
]]
function Crafting.start(
	inventory: Types.Inventory,
	station: Station,
	stationDef: Types.StationDef,
	recipe: Types.RecipeDef,
	progress: Progress,
	now: number,
	count: number?
): (Types.Inventory?, Station?, Reason?)
	local times = count or 1
	local ok: boolean, reason: Reason? = Crafting.check(recipe, inventory, progress, station, stationDef, times)
	if not ok then
		return nil, nil, reason
	end
	local taken = Inventory.removeAll(inventory, scaled(recipe.inputs, times)) :: Types.Inventory
	local slots = currentLevel(station, stationDef).queueSlots
	local seconds = Crafting.jobSeconds(recipe, stationDef, station.level)
	local queue = station.queue
	for _ = 1, times do
		queue = Timers.enqueue(queue, now, recipe.id, seconds, slots) :: Timers.Queue
	end
	return taken, withQueue(station, queue), nil
end

--[[
	Moves the outputs of finished jobs into the inventory, oldest first,
	including everything that finished while the player was offline. Each job is
	all-or-nothing; collection stops at the first job whose outputs do not fit,
	and that job and the rest stay queued. Returns the new station, the new
	inventory and the stacks collected.
]]
function Crafting.collect(
	station: Station,
	stationDef: Types.StationDef,
	inventory: Types.Inventory,
	recipes: Recipes,
	items: Inventory.ItemLookup,
	now: number
): (Station, Types.Inventory, { Types.ItemStack })
	local cutoff = workedUntil(station, stationDef, now)
	local result = inventory
	local collected: { Types.ItemStack } = {}
	local remaining: Timers.Queue = {}
	local blocked = false
	for _, job in station.queue do
		local recipe = recipes[job.id]
		assert(recipe, `unknown recipe '{job.id}' in station queue`)
		local nextInventory = if not blocked and job.endsAt <= cutoff
			then addAll(result, recipe.outputs, items)
			else nil
		if nextInventory then
			result = nextInventory
			for _, stack in recipe.outputs do
				table.insert(collected, { itemId = stack.itemId, count = stack.count })
			end
		else
			blocked = true
			table.insert(remaining, job)
		end
	end
	return withQueue(station, remaining), result, collected
end

--[[
	Cancels the unfinished job at `index` and refunds its inputs in full. Later
	jobs move up. Finished jobs cannot be cancelled (collect them). Returns the
	new station and inventory, or nil, nil and a reason ("notFound", "finished",
	"inventoryFull").
]]
function Crafting.cancel(
	station: Station,
	stationDef: Types.StationDef,
	index: number,
	inventory: Types.Inventory,
	recipes: Recipes,
	items: Inventory.ItemLookup,
	now: number
): (Station?, Types.Inventory?, Reason?)
	local job = station.queue[index]
	if not job then
		return nil, nil, "notFound"
	end
	local cutoff = workedUntil(station, stationDef, now)
	if job.endsAt <= cutoff then
		return nil, nil, "finished"
	end
	local recipe = recipes[job.id]
	assert(recipe, `unknown recipe '{job.id}' in station queue`)
	local refunded = addAll(inventory, recipe.inputs, items)
	if not refunded then
		return nil, nil, "inventoryFull"
	end
	local queue = table.clone(station.queue)
	table.remove(queue, index)
	return withQueue(station, relay(queue, cutoff, cutoff)), refunded, nil
end

--[[
	Burns `count` units of a fuel item. Fuel added while the fire is still lit
	extends it; fuel added after it went out relights it now and resumes any
	stalled jobs. Returns the new station and inventory, or nil, nil and a reason
	("noFuel" for stations without fuel, "notFuel", "missingInputs").
]]
function Crafting.addFuel(
	station: Station,
	stationDef: Types.StationDef,
	inventory: Types.Inventory,
	itemId: Types.ItemId,
	count: number,
	now: number
): (Station?, Types.Inventory?, Reason?)
	assertCount(count)
	local fuel = stationDef.fuel
	if not fuel then
		return nil, nil, "noFuel"
	end
	if not table.find(fuel.itemIds, itemId) then
		return nil, nil, "notFuel"
	end
	local taken = Inventory.remove(inventory, itemId, count)
	if not taken then
		return nil, nil, "missingInputs"
	end
	local burn = count * Crafting.burnSeconds(stationDef, itemId)
	if station.fuelEndsAt >= now then
		return withQueue(station, station.queue, station.fuelEndsAt + burn), taken, nil
	end
	local queue = relay(station.queue, station.fuelEndsAt, now)
	return withQueue(station, queue, now + burn), taken, nil
end

-- Seconds one unit of a fuel item burns: StationFuel.burnSeconds, else secondsPerUnit.
function Crafting.burnSeconds(stationDef: Types.StationDef, itemId: Types.ItemId): number
	local fuel = stationDef.fuel
	if not fuel then
		return 0
	end
	local perItem = fuel.burnSeconds and fuel.burnSeconds[itemId]
	return perItem or fuel.secondsPerUnit
end

-- Seconds of fuel left (0 when out, or for stations without fuel).
function Crafting.fuelRemaining(station: Station, stationDef: Types.StationDef, now: number): number
	if not stationDef.fuel then
		return 0
	end
	return math.max(0, station.fuelEndsAt - now)
end

-- Per-job status for the station UI.
function Crafting.status(station: Station, stationDef: Types.StationDef, now: number): { JobStatus }
	local cutoff = workedUntil(station, stationDef, now)
	local result: { JobStatus } = {}
	for index, job in station.queue do
		local done = job.endsAt <= cutoff
		table.insert(result, {
			index = index,
			recipeId = job.id,
			done = done,
			stalled = not done and cutoff < now,
			progress = Timers.progress({ startedAt = job.startsAt, endsAt = job.endsAt }, cutoff),
			remaining = math.max(0, job.endsAt - math.max(cutoff, job.startsAt)),
		})
	end
	return result
end

--[[
	Upgrades the station one level, paying that level's upgradeCost. Like LDoE,
	a busy station (any queued or uncollected job) cannot be upgraded. Returns
	the new station and inventory, or nil, nil and a reason ("maxLevel", "busy",
	"missingInputs").
]]
function Crafting.upgradeStation(
	station: Station,
	stationDef: Types.StationDef,
	inventory: Types.Inventory
): (Station?, Types.Inventory?, Reason?)
	local nextLevel = levelOf(stationDef, station.level + 1)
	if not nextLevel then
		return nil, nil, "maxLevel"
	end
	if #station.queue > 0 then
		return nil, nil, "busy"
	end
	local paid = Inventory.removeAll(inventory, nextLevel.upgradeCost)
	if not paid then
		return nil, nil, "missingInputs"
	end
	return {
		stationId = station.stationId,
		level = nextLevel.level,
		queue = {},
		fuelEndsAt = station.fuelEndsAt,
	},
		paid,
		nil
end

return Crafting
