--!strict
-- Crafting station definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.
-- Each station is placed through its build piece in Data/BuildPieces.

local Types = require("../Types")

local Stations: { [Types.StationId]: Types.StationDef } = {
	["station.workbench"] = {
		id = "station.workbench",
		name = "Workbench",
		levels = {
			{ level = 1, upgradeCost = {}, queueSlots = 3, speedMultiplier = 1 },
			{
				level = 2,
				upgradeCost = {
					{ itemId = "item.plank", count = 20 },
					{ itemId = "item.stone_block", count = 10 },
					{ itemId = "item.scrap_plate", count = 6 },
				},
				queueSlots = 5,
				speedMultiplier = 1.25,
				requiredLevel = 10,
			},
			{
				level = 3,
				upgradeCost = {
					{ itemId = "item.plank", count = 30 },
					{ itemId = "item.stone_block", count = 20 },
					{ itemId = "item.scrap_plate", count = 12 },
					{ itemId = "item.brass_gear", count = 3 },
				},
				queueSlots = 7,
				speedMultiplier = 1.5,
				requiredLevel = 16,
			},
		},
	},
	["station.campfire"] = {
		id = "station.campfire",
		name = "Campfire",
		levels = {
			{ level = 1, upgradeCost = {}, queueSlots = 3, speedMultiplier = 1 },
			{
				level = 2,
				upgradeCost = {
					{ itemId = "item.stone_block", count = 12 },
					{ itemId = "item.scrap_plate", count = 4 },
				},
				queueSlots = 5,
				speedMultiplier = 1.25,
				requiredLevel = 6,
			},
		},
		fuel = {
			itemIds = { "item.sticks", "item.timber", "item.plank", "item.fatwood" },
			secondsPerUnit = 2 * 60,
			burnSeconds = {
				["item.sticks"] = 60,
				["item.plank"] = 3 * 60,
				["item.fatwood"] = 6 * 60,
			},
			maxUnits = 20,
		},
	},
	["station.recycler"] = {
		id = "station.recycler",
		name = "Recycler",
		levels = {
			{ level = 1, upgradeCost = {}, queueSlots = 2, speedMultiplier = 1 },
			{
				level = 2,
				upgradeCost = {
					{ itemId = "item.scrap_plate", count = 10 },
					{ itemId = "item.rivets", count = 6 },
					{ itemId = "item.coil_spring", count = 2 },
				},
				queueSlots = 3,
				speedMultiplier = 1.2,
				requiredLevel = 12,
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
				queueSlots = 4,
				speedMultiplier = 1.4,
				requiredLevel = 18,
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
		levels = {
			{ level = 1, upgradeCost = {}, queueSlots = 3, speedMultiplier = 1 },
			{
				level = 2,
				upgradeCost = {
					{ itemId = "item.scrap_plate", count = 12 },
					{ itemId = "item.rivets", count = 8 },
					{ itemId = "item.brass_gear", count = 2 },
				},
				queueSlots = 5,
				speedMultiplier = 1.25,
				requiredLevel = 15, -- about a week in: the Reinforced tier's ammo demand
			},
		},
		feature = "fogRuns",
	},
}

return Stations
