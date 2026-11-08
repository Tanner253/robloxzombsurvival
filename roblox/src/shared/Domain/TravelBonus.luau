--!strict
--[[
	TravelBonus: "found on the way" (checklist 11.6; LDoE's travel loot). On
	arrival at a location the trip may turn something up, shown in a panel with
	TAKE per item and Take all. Whatever is left is gone once the panel closes.

	Walking is free but slow, so it always finds something and rolls twice
	(Tuning.travelBonus: walkChance, walkRolls). A Run sometimes does (runChance).
	The table is the location's run.travelBonusTableId. The ad slot that doubles it
	is wired in S3. Pure.
]]

local Types = require("../Types")
local Loot = require("./Loot")
local Rng = require("./Rng")

local TravelBonus = {}

export type Config = Types.TravelBonusTuning
export type Mode = "run" | "walk"

export type Bonus = {
	locationId: Types.LocationId,
	mode: Mode,
	items: { Types.ItemStack },
}

export type RollContext = {
	tables: Loot.Tables,
	rng: Rng.Source,
	items: Loot.RarityLookup?,
	pity: Loot.PityState?,
	config: Config,
}

local function merge(into: { Types.ItemStack }, stacks: { Types.ItemStack })
	for _, stack in stacks do
		local found = false
		for _, existing in into do
			if existing.itemId == stack.itemId then
				existing.count += stack.count
				found = true
				break
			end
		end
		if not found then
			table.insert(into, { itemId = stack.itemId, count = stack.count })
		end
	end
end

--[[
	Rolls the bonus for arriving at `locationId` by `mode`. Returns the bonus (nil
	when the trip turned up nothing) and the updated pity state.
]]
function TravelBonus.roll(
	locationId: Types.LocationId,
	tableId: Types.LootTableId,
	mode: Mode,
	ctx: RollContext
): (Bonus?, Loot.PityState)
	local pity = ctx.pity or {}
	local chance = if mode == "walk" then ctx.config.walkChance else ctx.config.runChance
	if chance <= 0 or ctx.rng:NextNumber() >= chance then
		return nil, pity
	end
	local rolls = if mode == "walk" then ctx.config.walkRolls else 1
	local items: { Types.ItemStack } = {}
	for _ = 1, rolls do
		local result = Loot.roll(ctx.tables, tableId, ctx.rng, { items = ctx.items, pity = pity })
		pity = result.pity
		merge(items, result.items)
	end
	if #items == 0 then
		return nil, pity
	end
	return { locationId = locationId, mode = mode, items = items }, pity
end

-- TAKE on one row: removes and returns it.
function TravelBonus.take(bonus: Bonus, index: number): Types.ItemStack?
	local stack = bonus.items[index]
	if stack == nil then
		return nil
	end
	table.remove(bonus.items, index)
	return stack
end

-- Take all: removes and returns every row (the service puts back what doesn't fit).
function TravelBonus.takeAll(bonus: Bonus): { Types.ItemStack }
	local all = table.clone(bonus.items)
	table.clear(bonus.items)
	return all
end

function TravelBonus.putBack(bonus: Bonus, stacks: { Types.ItemStack })
	merge(bonus.items, stacks)
end

function TravelBonus.isEmpty(bonus: Bonus): boolean
	return #bonus.items == 0
end

return TravelBonus
