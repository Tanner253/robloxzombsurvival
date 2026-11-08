--!strict
--[[
	Station definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.
	Each station is placed through its build piece in Data/BuildPieces.

	Stations are LDoE converters (LDOE_PARITY #18-19, Domain/Converter): one input slot
	feeds one output slot, a batch per recipe craftSeconds. Each slot holds slotCap items:
	20 at level 1 and +20 per level, as in LDoE. Fuelled stations burn fuel only while
	converting. Stations only refine materials; gear is crafted by hand (#20).

	Roster (#19): Woodworking Bench (timber -> planks), Stonecutter (stone -> blocks),
	Smelter (scrap -> plate), Workbench (cloth and rivets), Campfire (cooking), and the
	Recycler (junk -> parts). The Tanning Rack and Sewing Table come later.

	Fuel burn times follow LDoE's station pages: a log 2 min, a plank 3 min, a charcoal-like
	fatwood about 5 min.
]]

local Types = require("../Types")

local function levels(level2: { Types.ItemStack }, level3: { Types.ItemStack }): { Types.StationLevel }
	return {
		{ level = 1, upgradeCost = {}, slotCap = 20, speedMultiplier = 1 },
		{ level = 2, upgradeCost = level2, slotCap = 40, speedMultiplier = 1 },
		{ level = 3, upgradeCost = level3, slotCap = 60, speedMultiplier = 1 },
	}
end

local WOOD_FUEL: Types.StationFuel = {
	itemIds = { "item.sticks", "item.timber", "item.plank", "item.fatwood" },
	secondsPerUnit = 2 * 60,
	burnSeconds = {
		["item.sticks"] = 60,
		["item.plank"] = 3 * 60,
		["item.fatwood"] = 5 * 60 + 20,
	},
}

local Stations: { [Types.StationId]: Types.StationDef } = {
	["station.woodworking_bench"] = {
		id = "station.woodworking_bench",
		name = "Woodworking Bench",
		levels = levels({
			{ itemId = "item.plank", count = 20 },
			{ itemId = "item.scrap_plate", count = 6 },
		}, {
			{ itemId = "item.plank", count = 30 },
			{ itemId = "item.scrap_plate", count = 12 },
			{ itemId = "item.brass_gear", count = 2 },
		}),
	},
	["station.stonecutter"] = {
		id = "station.stonecutter",
		name = "Stonecutter",
		levels = levels({
			{ itemId = "item.stone_block", count = 20 },
			{ itemId = "item.scrap_plate", count = 6 },
		}, {
			{ itemId = "item.stone_block", count = 30 },
			{ itemId = "item.scrap_plate", count = 12 },
			{ itemId = "item.brass_gear", count = 2 },
		}),
	},
	["station.smelter"] = {
		id = "station.smelter",
		name = "Smelter",
		levels = levels({
			{ itemId = "item.stone_block", count = 20 },
			{ itemId = "item.scrap_plate", count = 10 },
		}, {
			{ itemId = "item.stone_block", count = 30 },
			{ itemId = "item.scrap_plate", count = 16 },
			{ itemId = "item.brass_gear", count = 3 },
		}),
		fuel = WOOD_FUEL,
	},
	["station.workbench"] = {
		id = "station.workbench",
		name = "Workbench",
		levels = levels({
			{ itemId = "item.plank", count = 20 },
			{ itemId = "item.stone_block", count = 10 },
			{ itemId = "item.scrap_plate", count = 6 },
		}, {
			{ itemId = "item.plank", count = 30 },
			{ itemId = "item.stone_block", count = 20 },
			{ itemId = "item.scrap_plate", count = 12 },
			{ itemId = "item.brass_gear", count = 3 },
		}),
	},
	["station.campfire"] = {
		id = "station.campfire",
		name = "Campfire",
		levels = levels({
			{ itemId = "item.stone_block", count = 12 },
			{ itemId = "item.scrap_plate", count = 4 },
		}, {
			{ itemId = "item.stone_block", count = 20 },
			{ itemId = "item.scrap_plate", count = 8 },
			{ itemId = "item.coil_spring", count = 2 },
		}),
		fuel = WOOD_FUEL,
	},
	["station.recycler"] = {
		id = "station.recycler",
		name = "Recycler",
		outputSlots = 4,
		levels = {
			{ level = 1, upgradeCost = {}, slotCap = 20, speedMultiplier = 1 },
			{
				level = 2,
				upgradeCost = {
					{ itemId = "item.scrap_plate", count = 10 },
					{ itemId = "item.rivets", count = 6 },
					{ itemId = "item.coil_spring", count = 2 },
				},
				slotCap = 40,
				speedMultiplier = 1,
				salvageChanceBonus = 0.05,
			},
			{
				level = 3,
				upgradeCost = {
					{ itemId = "item.scrap_plate", count = 16 },
					{ itemId = "item.rivets", count = 10 },
					{ itemId = "item.coil_spring", count = 4 },
					{ itemId = "item.brass_gear", count = 2 },
				},
				slotCap = 60,
				speedMultiplier = 1,
				salvageChanceBonus = 0.1,
			},
		},
		salvage = {
			{
				inputItemId = "item.broken_lantern",
				seconds = 6 * 60,
				outputs = {
					{ itemId = "item.scrap", min = 2, max = 4, chance = 1 },
					{ itemId = "item.pitch_glue", min = 1, max = 1, chance = 0.5 },
					{ itemId = "item.rivets", min = 1, max = 2, chance = 0.4 },
				},
			},
			{
				inputItemId = "item.snarled_wire",
				seconds = 5 * 60,
				outputs = {
					{ itemId = "item.scrap", min = 1, max = 3, chance = 1 },
					{ itemId = "item.rivets", min = 2, max = 3, chance = 0.6 },
				},
			},
			{
				inputItemId = "item.seized_motor",
				seconds = 20 * 60,
				outputs = {
					{ itemId = "item.scrap_plate", min = 1, max = 2, chance = 1 },
					{ itemId = "item.coil_spring", min = 1, max = 2, chance = 0.6 },
					{ itemId = "item.brass_gear", min = 1, max = 1, chance = 0.25 },
				},
			},
			{
				inputItemId = "item.spiked_club",
				seconds = 5 * 60,
				outputs = {
					{ itemId = "item.plank", min = 1, max = 2, chance = 1 },
					{ itemId = "item.scrap", min = 1, max = 2, chance = 0.5 },
				},
			},
			{
				inputItemId = "item.scrapblade",
				seconds = 10 * 60,
				outputs = {
					{ itemId = "item.scrap_plate", min = 1, max = 2, chance = 1 },
					{ itemId = "item.rivets", min = 1, max = 1, chance = 0.5 },
				},
			},
			{
				inputItemId = "item.shortbow",
				seconds = 10 * 60,
				outputs = {
					{ itemId = "item.plank", min = 1, max = 2, chance = 1 },
					{ itemId = "item.rope", min = 1, max = 2, chance = 0.6 },
					{ itemId = "item.coil_spring", min = 1, max = 1, chance = 0.15 },
				},
			},
			{
				inputItemId = "item.padded_hood",
				seconds = 8 * 60,
				outputs = {
					{ itemId = "item.cloth", min = 1, max = 2, chance = 1 },
					{ itemId = "item.rope", min = 1, max = 1, chance = 0.5 },
				},
			},
			{
				inputItemId = "item.padded_vest",
				seconds = 10 * 60,
				outputs = {
					{ itemId = "item.cloth", min = 2, max = 3, chance = 1 },
					{ itemId = "item.scrap_plate", min = 1, max = 1, chance = 0.4 },
				},
			},
			-- Spare blueprints are never wasted.
			{
				inputItemId = "item.bp_pack_frame",
				seconds = 10 * 60,
				outputs = {
					{ itemId = "item.rivets", min = 2, max = 3, chance = 1 },
					{ itemId = "item.brass_gear", min = 1, max = 1, chance = 1 },
				},
			},
			{
				inputItemId = "item.bp_reinforced",
				seconds = 10 * 60,
				outputs = {
					{ itemId = "item.rivets", min = 2, max = 3, chance = 1 },
					{ itemId = "item.brass_gear", min = 1, max = 1, chance = 1 },
				},
			},
		},
	},
	-- Fog Runs (slice 2): hidden until Tuning.features.fogRuns.
	["station.ammo_press"] = {
		id = "station.ammo_press",
		name = "Ammo Press",
		-- A converter like every station (LDOE_PARITY #18): niter -> blackpowder, burning
		-- fatwood. Rounds, shells and flares are then made by hand from the powder.
		levels = levels({
			{ itemId = "item.scrap_plate", count = 12 },
			{ itemId = "item.rivets", count = 8 },
			{ itemId = "item.brass_gear", count = 2 },
		}, {
			{ itemId = "item.scrap_plate", count = 20 },
			{ itemId = "item.rivets", count = 12 },
			{ itemId = "item.brass_gear", count = 4 },
		}),
		fuel = WOOD_FUEL,
		feature = "fogRuns",
	},
}

return Stations
