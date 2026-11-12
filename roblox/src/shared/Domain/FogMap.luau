--!strict
--[[
	FogMap: the map-level rules from LDOE_PARITY #43. Pure.

	- Airdrops: as a player's Energy falls below each Tuning.airdrops threshold
	  (140, 80, 20), a guarded crate lands: a pin on their map for pinSeconds that
	  opens the airdrop location (availability "airdrop"). Each threshold fires once
	  per UTC day, so three a day at most, and only for Energy actually spent.
	- Region gates: Dense and Black fog open once their signal tower is repaired
	  from a parts checklist (have / need, FILL UP, FINALIZE). Travel.gateOpen reads
	  the repaired set; this module runs the checklist.
]]

local Types = require("../Types")
local Inventory = require("./Inventory")

local FogMap = {}

local DAY = 24 * 60 * 60

-- Airdrops ------------------------------------------------------------------------------------

export type AirdropDay = { day: number, fired: { [number]: boolean } }

export type Pin = {
	locationId: Types.LocationId,
	threshold: number,
	landedAt: number,
	expiresAt: number,
}

--[[
	Energy went from `before` to `after` (a spend). Returns the thresholds it fell
	below that haven't fired today, highest first, and the updated day record.
]]
function FogMap.airdropsCrossed(
	before: number,
	after: number,
	day: AirdropDay,
	now: number,
	config: Types.AirdropTuning
): ({ number }, AirdropDay)
	local today = now // DAY
	local fired: { [number]: boolean } = if day.day == today then table.clone(day.fired) else {}
	local crossed: { number } = {}
	for _, threshold in config.thresholds do
		if before >= threshold and after < threshold and not fired[threshold] then
			fired[threshold] = true
			table.insert(crossed, threshold)
		end
	end
	return crossed, { day = today, fired = fired }
end

--[[
	The airdrop day as the profile keeps it (PlayerSchema v13, the flow review's F-23): the
	thresholds fired as a sorted list, since a DataStore can't hold a sparse number-keyed
	table. `loadDay` takes whatever was saved (nil or junk reads as no airdrop yet).
]]
export type SavedAirdropDay = { day: number, fired: { number } }

function FogMap.saveDay(day: AirdropDay): SavedAirdropDay
	local fired: { number } = {}
	for threshold, done in day.fired do
		if done then
			table.insert(fired, threshold)
		end
	end
	table.sort(fired)
	return { day = day.day, fired = fired }
end

function FogMap.loadDay(saved: any): AirdropDay
	local fired: { [number]: boolean } = {}
	if type(saved) ~= "table" or type(saved.day) ~= "number" then
		return { day = 0, fired = fired }
	end
	for _, threshold in (if type(saved.fired) == "table" then saved.fired else {}) :: { any } do
		if type(threshold) == "number" then
			fired[threshold] = true
		end
	end
	return { day = saved.day, fired = fired }
end

function FogMap.pin(threshold: number, now: number, config: Types.AirdropTuning): Pin
	return { locationId = config.locationId, threshold = threshold, landedAt = now, expiresAt = now + config.pinSeconds }
end

-- Pins still on the map.
function FogMap.livePins(pins: { Pin }, now: number): { Pin }
	local live: { Pin } = {}
	for _, pin in pins do
		if now < pin.expiresAt then
			table.insert(live, pin)
		end
	end
	return live
end

-- Uses one live pin for the trip out (the crate is yours once). Returns the rest, or nil if none.
function FogMap.usePin(pins: { Pin }, now: number): { Pin }?
	local live = FogMap.livePins(pins, now)
	if #live == 0 then
		return nil
	end
	table.remove(live, 1)
	return live
end

-- Region gates -------------------------------------------------------------------------------------

export type Contributed = { [Types.ItemId]: number }

export type Row = { itemId: Types.ItemId, have: number, need: number }

-- The checklist: what's been put in against what the tower needs.
function FogMap.checklist(gate: Types.RegionGate, contributed: Contributed): ({ Row }, boolean)
	local rows: { Row } = {}
	local complete = true
	for _, part in gate.parts do
		local have = math.min(part.count, contributed[part.itemId] or 0)
		table.insert(rows, { itemId = part.itemId, have = have, need = part.count })
		if have < part.count then
			complete = false
		end
	end
	return rows, complete
end

--[[
	FILL UP: moves whatever the checklist still lacks from the inventory into the
	tower. Returns the new inventory, the new contributed counts and what was taken.
]]
function FogMap.fillUp(
	gate: Types.RegionGate,
	contributed: Contributed,
	inventory: Types.Inventory
): (Types.Inventory, Contributed, { Types.ItemStack })
	local result = inventory
	local nextContributed = table.clone(contributed)
	local taken: { Types.ItemStack } = {}
	for _, part in gate.parts do
		local missing = part.count - math.min(part.count, nextContributed[part.itemId] or 0)
		local amount = math.min(missing, Inventory.count(result, part.itemId))
		if amount > 0 then
			result = Inventory.remove(result, part.itemId, amount) :: Types.Inventory
			nextContributed[part.itemId] = (nextContributed[part.itemId] or 0) + amount
			table.insert(taken, { itemId = part.itemId, count = amount })
		end
	end
	return result, nextContributed, taken
end

-- FINALIZE: marks the tower repaired once the checklist is complete.
function FogMap.finalize(
	gate: Types.RegionGate,
	contributed: Contributed,
	repaired: { [string]: boolean }
): { [string]: boolean }?
	local _, complete = FogMap.checklist(gate, contributed)
	if not complete then
		return nil
	end
	local result = table.clone(repaired)
	result[gate.id] = true
	return result
end

return FogMap
