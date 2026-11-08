--!strict
-- Fog map location definitions, keyed by permanent ID. See docs/CONTENT_MVP.md and, for
-- the Fog Run rules (`run`, container kinds, spawn bands), docs/CONTENT_S2.md.
-- One location per fog tier plus one rotating event. Energy costs are about two thirds
-- of LDoE's for the same tier at the same regen rate (Tuning.energy).
-- Level gates follow GAME_DESIGN "Rules by fog tier": Dense 8+, Black 15+. Pacing: Dense
-- on day 2 for a free player (about 2-3 h a day), Black around day 5-6.
-- Spawns with a minBand join once the lobby's Fog meter reaches that band.

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
			{ lootTableId = "loot.pine_pack", count = { min = 2, max = 3 }, kind = "pack", searchSeconds = 3 },
			{ lootTableId = "loot.pine_crate", count = { min = 1, max = 2 }, kind = "crate" },
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
			{ enemyId = "enemy.runner", count = { min = 0, max = 2 }, minBand = 2 },
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
			"item.light_rounds",
			"item.steel_pipe",
		},
		run = {
			recommendedGearScore = 40, -- a Spiked Club: anyone can go
			placeId = 0,
			extraction = { kind = "edge" },
			bandLoot = {
				{ band = 2, lootTableId = "loot.pine_band2" },
				{ band = 3, lootTableId = "loot.pine_band3" },
			},
			travelBonusTableId = "loot.road_light",
		},
	},
	["loc.sunken_quarry"] = {
		id = "loc.sunken_quarry",
		name = "Sunken Quarry",
		fogTier = 2,
		levelGate = 8,
		energyCost = 15,
		walkSeconds = 7 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.quarry_toolbox", count = { min = 2, max = 3 }, kind = "cabinet" },
			{ lootTableId = "loot.quarry_locker", count = { min = 1, max = 2 }, kind = "locker" },
		},
		nodes = {
			{ nodeId = "node.boulder", count = 18 },
			{ nodeId = "node.scrap_heap", count = 8 },
			{ nodeId = "node.fatwood_stump", count = 6 },
			{ nodeId = "node.pine_tree", count = 6 },
			{ nodeId = "node.ashroot_mound", count = 4 },
			{ nodeId = "node.niter_seam", count = 4 },
			{ nodeId = "node.spring_pool", count = 2 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 8, max = 10 } },
			{ enemyId = "enemy.runner", count = { min = 3, max = 5 } },
			{ enemyId = "enemy.bloater", count = { min = 1, max = 2 }, minBand = 2 },
		},
		mainLoot = { "item.stone", "item.scrap", "item.fatwood", "item.timber", "item.niter" },
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
			"item.blackpowder",
			"item.steel_pipe",
			"item.trigger_group",
			"item.light_rounds",
			"item.machete",
		},
		run = {
			recommendedGearScore = 90, -- a Scrapblade and a hood
			placeId = 0,
			extraction = {
				kind = "points",
				points = {
					{ id = "north_ramp", name = "North Ramp" },
					{ id = "conveyor_gate", name = "Conveyor Gate" },
					{ id = "flooded_cut", name = "Flooded Cut" },
				},
				closeCount = 1,
			},
			bandLoot = {
				{ band = 2, lootTableId = "loot.quarry_band2" },
				{ band = 3, lootTableId = "loot.quarry_band3" },
			},
			travelBonusTableId = "loot.road_dense",
		},
	},
	["loc.ashfall_depot"] = {
		id = "loc.ashfall_depot",
		name = "Ashfall Depot",
		fogTier = 3,
		levelGate = 15,
		energyCost = 22,
		walkSeconds = 12 * 60,
		-- A dungeon-style timer: shorter than a day so a daily player can always re-run it.
		reset = { kind = "timer", seconds = 20 * 60 * 60 },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.depot_freight", count = { min = 4, max = 5 }, kind = "crate" },
			{
				lootTableId = "loot.depot_strongbox",
				count = { min = 1, max = 2 },
				kind = "strongbox",
				searchSeconds = 8,
			},
		},
		nodes = {
			{ nodeId = "node.scrap_heap", count = 14 },
			{ nodeId = "node.fatwood_stump", count = 6 },
			{ nodeId = "node.boulder", count = 6 },
			{ nodeId = "node.niter_seam", count = 6 },
			{ nodeId = "node.spring_pool", count = 1 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 8, max = 12 } },
			{ enemyId = "enemy.runner", count = { min = 5, max = 7 } },
			{ enemyId = "enemy.bloater", count = { min = 2, max = 3 } },
			{ enemyId = "enemy.runner", count = { min = 2, max = 3 }, minBand = 3 },
		},
		mainLoot = { "item.scrap", "item.scrap_plate", "item.rivets", "item.coil_spring", "item.fatwood", "item.niter" },
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
			"item.blackpowder",
			"item.trigger_group",
			"item.shells",
			"item.flare",
			"item.fire_axe",
			"item.pipe_pistol",
			"item.flare_pistol",
			"item.scrap_shotgun",
		},
		run = {
			recommendedGearScore = 140, -- tier 2 weapon, hood, vest and a pack frame
			placeId = 0,
			extraction = {
				kind = "points",
				points = {
					{ id = "rail_yard", name = "Rail Yard" },
					{ id = "loading_dock", name = "Loading Dock" },
					{ id = "signal_tower", name = "Signal Tower" },
				},
				closeCount = 1, -- two open, plus the flare extract (GAME_DESIGN)
				flare = true,
			},
			bandLoot = {
				{ band = 2, lootTableId = "loot.depot_band2" },
				{ band = 3, lootTableId = "loot.depot_band3" },
			},
			travelBonusTableId = "loot.road_black",
		},
	},
	["loc.stranded_caravan"] = {
		id = "loc.stranded_caravan",
		name = "Stranded Caravan",
		fogTier = 2,
		levelGate = 8,
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
			{ lootTableId = "loot.caravan_wagon", count = { min = 3, max = 4 }, kind = "trunk" },
			{
				lootTableId = "loot.caravan_strongbox",
				count = { min = 1, max = 1 },
				kind = "strongbox",
				searchSeconds = 8,
			},
		},
		nodes = {
			{ nodeId = "node.scrap_heap", count = 6 },
			{ nodeId = "node.fatwood_stump", count = 4 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 6, max = 8 } },
			{ enemyId = "enemy.runner", count = { min = 4, max = 5 } },
			{ enemyId = "enemy.bloater", count = { min = 1, max = 2 }, minBand = 2 },
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
			"item.blackpowder",
			"item.flare",
			"item.trigger_group",
			"item.flare_pistol",
		},
		run = {
			recommendedGearScore = 110,
			placeId = 0,
			extraction = {
				kind = "points",
				points = {
					{ id = "lead_trail", name = "Lead Wagon Trail" },
					{ id = "riverbank", name = "Riverbank" },
					{ id = "old_bridge", name = "Old Bridge" },
				},
				closeCount = 1,
			},
			bandLoot = {
				{ band = 2, lootTableId = "loot.caravan_band2" },
				{ band = 3, lootTableId = "loot.caravan_band3" },
			},
			travelBonusTableId = "loot.road_dense",
		},
	},
}

return Locations
