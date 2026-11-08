--!strict
--[[
	Salvage: Recycler jobs (StationDef.salvage). Pure; pass `now` and an Rng in.

	A salvage job is one input item broken down over SalvageDef.seconds (divided
	by the station level's speedMultiplier). It shares the station's
	Timers.Queue with the same slot rules as Crafting. The job ID records the
	input and its condition, "<itemId>#<percent>", so a cancel refunds the item
	as it went in and outputs can scale with it.

	Outputs roll when collected: an output with chance 1 always drops; the others
	roll chance x condition (when Tuning.salvage.durabilityScalesChance and the
	item has durability) + the level's salvageChanceBonus.
]]

local Types = require("../Types")
local Timers = require("./Timers")
local Slots = require("./Slots")
local Rng = require("./Rng")

local Salvage = {}

export type Station = {
	stationId: Types.StationId,
	level: number,
	queue: Timers.Queue,
	fuelEndsAt: number,
}

export type Reason = "notSalvageable" | "queueFull" | "inventoryFull" | "notFound" | "finished"

export type ItemLookup = Slots.ItemLookup

export type Config = { durabilityScalesChance: boolean }

local EPSILON = 1e-9

local function levelOf(stationDef: Types.StationDef, level: number): Types.StationLevel
	for _, entry in stationDef.levels do
		if entry.level == level then
			return entry
		end
	end
	error(`station '{stationDef.id}' has no level {level}`)
end

-- The salvage definition for an input item, if the station breaks it down.
function Salvage.find(stationDef: Types.StationDef, itemId: Types.ItemId): Types.SalvageDef?
	local list = stationDef.salvage
	if list == nil then
		return nil
	end
	for _, def in list do
		if def.inputItemId == itemId then
			return def
		end
	end
	return nil
end

-- "<itemId>#<percent>": the input and its condition (100 for items without durability).
function Salvage.jobId(itemId: Types.ItemId, percent: number): string
	return `{itemId}#{math.clamp(math.floor(percent + 0.5), 0, 100)}`
end

-- The input item and condition (0..1) a job ID records.
function Salvage.parse(jobId: string): (Types.ItemId, number)
	local itemId, percent = string.match(jobId, "^(.-)#(%d+)$")
	if itemId == nil or percent == nil then
		return jobId, 1
	end
	return itemId, (tonumber(percent) :: number) / 100
end

-- Seconds a job takes at the station's level (whole seconds, rounded up).
function Salvage.jobSeconds(def: Types.SalvageDef, stationDef: Types.StationDef, level: number): number
	return math.max(0, math.ceil(def.seconds / levelOf(stationDef, level).speedMultiplier - EPSILON))
end

--[[
	Queues one input slot (already taken from the inventory by the caller).
	Returns the new station, or nil and a reason.
]]
function Salvage.start(
	station: Station,
	stationDef: Types.StationDef,
	slot: Types.Slot,
	items: ItemLookup,
	now: number
): (Station?, Reason?)
	local def = Salvage.find(stationDef, slot.itemId)
	if def == nil or slot.count ~= 1 then
		return nil, "notSalvageable"
	end
	local item = items[slot.itemId]
	local percent = if item
			and item.durability
			and slot.durability
		then 100 * slot.durability / item.durability
		else 100
	local queue = Timers.enqueue(
		station.queue,
		now,
		Salvage.jobId(slot.itemId, percent),
		Salvage.jobSeconds(def, stationDef, station.level),
		levelOf(stationDef, station.level).queueSlots
	)
	if queue == nil then
		return nil, "queueFull"
	end
	return { stationId = station.stationId, level = station.level, queue = queue, fuelEndsAt = station.fuelEndsAt }, nil
end

-- Rolls one job's outputs.
function Salvage.roll(
	def: Types.SalvageDef,
	condition: number,
	bonus: number,
	scales: boolean,
	rng: Rng.Source
): { Types.ItemStack }
	local result: { Types.ItemStack } = {}
	for _, output in def.outputs do
		local chance = output.chance
		if chance < 1 then
			chance = (if scales then chance * condition else chance) + bonus
		end
		if chance >= 1 or rng:NextNumber() < chance then
			local count = rng:NextInteger(output.min, output.max)
			if count > 0 then
				table.insert(result, { itemId = output.itemId, count = count })
			end
		end
	end
	return result
end

--[[
	Collects finished jobs oldest first, rolling each one's outputs into the
	inventory. A job whose outputs do not fit stays queued (re-rolled next time),
	and collection stops there. Returns the new station, inventory and stacks.
]]
function Salvage.collect(
	station: Station,
	stationDef: Types.StationDef,
	inventory: Types.Inventory,
	items: ItemLookup,
	rng: Rng.Source,
	now: number,
	config: Config
): (Station, Types.Inventory, { Types.ItemStack })
	local bonus = levelOf(stationDef, station.level).salvageChanceBonus or 0
	local containers = { inventory.pockets, inventory.backpack }
	local collected: { Types.ItemStack } = {}
	local remaining: Timers.Queue = {}
	local blocked = false
	for _, job in station.queue do
		local itemId, condition = Salvage.parse(job.id)
		local def = Salvage.find(stationDef, itemId)
		if not blocked and def and job.endsAt <= now then
			local item = items[itemId]
			local scales = config.durabilityScalesChance and item ~= nil and item.durability ~= nil
			local outputs = Salvage.roll(def, condition, bonus, scales, rng)
			local trial = containers
			local fits = true
			for _, stack in outputs do
				local after, left = Slots.addTo(trial, { itemId = stack.itemId, count = stack.count }, items)
				if left > 0 then
					fits = false
					break
				end
				trial = after
			end
			if fits then
				containers = trial
				for _, stack in outputs do
					table.insert(collected, stack)
				end
				continue
			end
			blocked = true
		end
		table.insert(remaining, job)
	end
	return {
		stationId = station.stationId,
		level = station.level,
		queue = remaining,
		fuelEndsAt = station.fuelEndsAt,
	},
		{ pockets = containers[1], backpack = containers[2] },
		collected
end

--[[
	Cancels the unfinished job at `index` and returns its input slot (with the
	condition it went in at). Later jobs move up and keep their progress order.
	Returns the new station and the refund slot, or nil, nil and a reason.
]]
function Salvage.cancel(
	station: Station,
	index: number,
	items: ItemLookup,
	now: number
): (Station?, Types.Slot?, Reason?)
	local job = station.queue[index]
	if job == nil then
		return nil, nil, "notFound"
	end
	if job.endsAt <= now then
		return nil, nil, "finished"
	end
	local itemId, condition = Salvage.parse(job.id)
	local item = items[itemId]
	local durability = if item and item.durability then math.max(1, math.floor(item.durability * condition)) else nil
	-- Re-lay the jobs after it back to back from now, keeping the work already done.
	local queue: Timers.Queue = {}
	local cursor = now
	for position, other in station.queue do
		if position ~= index then
			if other.endsAt <= now then
				table.insert(queue, other)
			else
				local length = other.endsAt - other.startsAt
				local done = math.clamp(now - other.startsAt, 0, length)
				local startsAt = cursor - done
				table.insert(queue, { id = other.id, startsAt = startsAt, endsAt = startsAt + length })
				cursor = startsAt + length
			end
		end
	end
	return { stationId = station.stationId, level = station.level, queue = queue, fuelEndsAt = station.fuelEndsAt },
		{ itemId = itemId, count = 1, durability = durability },
		nil
end

return Salvage
