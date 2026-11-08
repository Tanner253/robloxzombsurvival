--!strict
-- Fog map location definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.
-- One location per fog tier plus one rotating event. Energy costs are about two thirds
-- of LDoE's for the same tier at the same regen rate (Tuning.energy).

local Types = require("../Types")

local Locations: { [Types.LocationId]: Types.LocationDef } = {
	["loc.pine_hollow"] = {
		id = "loc.pine_hollow",
		name = "Pine Hollow",
		fogTier = 1,
		levelGate = 1,
		energyCost = 10,
		walkSeconds = 4 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.pine_pack", count = { min = 2, max = 3 } },
			{ lootTableId = "loot.pine_crate", count = { min = 1, max = 2 } },
		},
		nodes = {
			{ nodeId = "node.pine_tree", count = 16 },
			{ nodeId = "node.boulder", count = 10 },
			{ nodeId = "node.fallen_branches", count = 8 },
			{ nodeId = "node.loose_stones", count = 8 },
			{ nodeId = "node.reed_patch", count = 10 },
			{ nodeId = "node.ember_bush", count = 6 },
			{ nodeId = "node.ashroot_mound", count = 6 },
			{ nodeId = "node.spring_pool", count = 2 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 6, max = 9 } },
			{ enemyId = "enemy.runner", count = { min = 0, max = 2 } },
		},
		mainLoot = { "item.timber", "item.stone", "item.fiber", "item.emberberry", "item.ashroot", "item.murky_water" },
		possibleLoot = {
			"item.plank",
			"item.rope",
			"item.cloth",
			"item.scrap",
			"item.sealed_tin",
			"item.field_dressing",
			"item.broken_lantern",
			"item.stone_hatchet",
			"item.spiked_club",
		},
	},
	-- The one-time crash site Ember Trail quest 6 sends you to (LDOE_PARITY #57): a wreck
	-- in the Light fog with salvage, a few Hollow and a reason to build the Smelter. Fog Runs
	-- (S2) build its lobby; until then quest 6's travel objective waits on that flag.
	["loc.crash_site"] = {
		id = "loc.crash_site",
		name = "The Crash Site",
		fogTier = 1,
		levelGate = 1,
		energyCost = 6,
		walkSeconds = 3 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.pine_crate", count = { min = 2, max = 3 } },
			{ lootTableId = "loot.pine_pack", count = { min = 1, max = 2 } },
		},
		nodes = {
			{ nodeId = "node.scrap_heap", count = 6 },
			{ nodeId = "node.fallen_branches", count = 4 },
			{ nodeId = "node.loose_stones", count = 4 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 3, max = 4 } },
		},
		mainLoot = { "item.scrap", "item.sticks", "item.stone" },
		possibleLoot = {
			"item.rope",
			"item.cloth",
			"item.sealed_tin",
			"item.field_dressing",
			"item.broken_lantern",
		},
	},
	["loc.sunken_quarry"] = {
		id = "loc.sunken_quarry",
		name = "Sunken Quarry",
		fogTier = 2,
		levelGate = 4,
		energyCost = 15,
		walkSeconds = 7 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.quarry_toolbox", count = { min = 2, max = 3 } },
			{ lootTableId = "loot.quarry_locker", count = { min = 1, max = 2 } },
		},
		nodes = {
			{ nodeId = "node.boulder", count = 18 },
			{ nodeId = "node.scrap_heap", count = 8 },
			{ nodeId = "node.fatwood_stump", count = 6 },
			{ nodeId = "node.pine_tree", count = 6 },
			{ nodeId = "node.ashroot_mound", count = 4 },
			{ nodeId = "node.spring_pool", count = 2 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 8, max = 10 } },
			{ enemyId = "enemy.runner", count = { min = 3, max = 5 } },
			{ enemyId = "enemy.brute", count = { min = 0, max = 1 } },
		},
		mainLoot = { "item.stone", "item.scrap", "item.fatwood", "item.timber" },
		possibleLoot = {
			"item.scrap_plate",
			"item.rivets",
			"item.coil_spring",
			"item.arrow",
			"item.sealed_tin",
			"item.field_dressing",
			"item.seized_motor",
			"item.padded_hood",
			"item.shortbow",
			"item.ember_tonic",
		},
	},
	["loc.ashfall_depot"] = {
		id = "loc.ashfall_depot",
		name = "Ashfall Depot",
		fogTier = 3,
		levelGate = 10,
		energyCost = 22,
		walkSeconds = 12 * 60,
		-- A dungeon-style timer: shorter than a day so a daily player can always re-run it.
		reset = { kind = "timer", seconds = 20 * 60 * 60 },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.depot_freight", count = { min = 4, max = 5 } },
			{ lootTableId = "loot.depot_strongbox", count = { min = 1, max = 2 } },
		},
		nodes = {
			{ nodeId = "node.scrap_heap", count = 14 },
			{ nodeId = "node.fatwood_stump", count = 6 },
			{ nodeId = "node.boulder", count = 6 },
			{ nodeId = "node.spring_pool", count = 1 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 8, max = 12 } },
			{ enemyId = "enemy.runner", count = { min = 5, max = 7 } },
			{ enemyId = "enemy.brute", count = { min = 2, max = 3 } },
		},
		mainLoot = { "item.scrap", "item.scrap_plate", "item.rivets", "item.coil_spring", "item.fatwood" },
		possibleLoot = {
			"item.stone_block",
			"item.seized_motor",
			"item.brass_gear",
			"item.hearth_stew",
			"item.ember_tonic",
			"item.scrapblade",
			"item.padded_vest",
			"item.bp_pack_frame",
			"item.bp_reinforced",
		},
	},
	["loc.stranded_caravan"] = {
		id = "loc.stranded_caravan",
		name = "Stranded Caravan",
		fogTier = 2,
		levelGate = 6,
		energyCost = 14,
		walkSeconds = 8 * 60,
		reset = { kind = "perAppearance" },
		-- Open 3 h in every 9 h. 9 does not divide 24, so the window drifts through the
		-- day and every time zone gets evening windows within three days.
		availability = {
			kind = "rotating",
			periodSeconds = 9 * 60 * 60,
			activeSeconds = 3 * 60 * 60,
			offsetSeconds = 0,
		},
		containers = {
			{ lootTableId = "loot.caravan_wagon", count = { min = 3, max = 4 } },
			{ lootTableId = "loot.caravan_strongbox", count = { min = 1, max = 1 } },
		},
		nodes = {
			{ nodeId = "node.scrap_heap", count = 6 },
			{ nodeId = "node.fatwood_stump", count = 4 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 6, max = 8 } },
			{ enemyId = "enemy.runner", count = { min = 4, max = 5 } },
			{ enemyId = "enemy.brute", count = { min = 1, max = 2 } },
		},
		mainLoot = { "item.plank", "item.stone_block", "item.scrap_plate", "item.rivets" },
		possibleLoot = {
			"item.coil_spring",
			"item.hearth_stew",
			"item.field_dressing",
			"item.ember_tonic",
			"item.brass_gear",
			"item.bp_pack_frame",
			"item.bp_reinforced",
		},
	},
}

return Locations
