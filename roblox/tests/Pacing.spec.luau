--!strict
--[[
	The economy pacing simulation (docs/ECONOMY.md §9 and §11.4), on the real data.

	Domain/PacingSim plays one free player through three weeks with every §8 sink on:
	hunger and thirst, melee, armor and gun wear with re-crafts, dressings and ammo. The
	model below is §9.1's assumptions as parameters, ported from tools/economy/pacing.py
	(the reference model the spec's numbers come from): sessions, run choice, run costs, the
	Forest, Mine and POI locations and their container tables (ECONOMY §6-7, generated from
	pacing.py: they become Data/Locations and Data/LootTables in the next pass, docs/briefs/
	economy-notes-for-s2b.md) and the milestone goal lists. Everything else is the game's own
	data: nodes, recipes and stations (through Domain/Converter), build costs, durability,
	food, enemies, Energy, levels and quests.

	The bands asserted are GAME_DESIGN's, at 2.5 h a day (2 x 75 min) with both other
	layouts and play times checked at the edges: the hook in the first hour, Timber by the
	end of day 1, Scrap on days 3-5, Reinforced on days 10-14. The Ember Trail is played as
	it pays: the first quests on their first builds, chapter 3 (Hold the Line) on its own
	objectives, so the spec also checks that the trail now runs to about day 20.

	PACING_VERBOSE=1 lune run tests/run prints each case's milestones.
]]

local TestKit = require("./TestKit")
local Types = require("../src/shared/Types")
local PacingSim = require("../src/shared/Domain/PacingSim")
local StationFallback = require("../src/shared/StationFallback")
local Gathering = require("../src/shared/Domain/Gathering")
local DataValidator = require("../src/shared/Domain/DataValidator")
local Bundle = require("../src/shared/Data")
local Items = require("../src/shared/Data/Items")
local Recipes = require("../src/shared/Data/Recipes")
local Stations = require("../src/shared/Data/Stations")
local Nodes = require("../src/shared/Data/Nodes")
local Enemies = require("../src/shared/Data/Enemies")
local LootTables = require("../src/shared/Data/LootTables")
local BuildPieces = require("../src/shared/Data/BuildPieces")
local Levels = require("../src/shared/Data/Levels")
local Quests = require("../src/shared/Data/Quests")
local Tuning = require("../src/shared/Data/Tuning")
local process = require("@lune/process")

-- Generated from tools/economy/pacing.py (LOOT): ECONOMY §7's tables, with the §7.4 deltas.
local LOOT: { [string]: Types.LootTableDef } = {
	["loot.zone_pack_t1"] = {
		id = "loot.zone_pack_t1",
		rolls = { min = 1, max = 3 },
		entries = {
			{ itemId = "item.sealed_tin", weight = 10, min = 1, max = 1 },
			{ itemId = "item.boiled_water", weight = 8, min = 1, max = 1 },
			{ itemId = "item.murky_water", weight = 12, min = 1, max = 2 },
			{ itemId = "item.cloth", weight = 14, min = 1, max = 2 },
			{ itemId = "item.rope", weight = 12, min = 1, max = 2 },
			{ itemId = "item.field_dressing", weight = 8, min = 1, max = 1 },
			{ itemId = "item.pitch_glue", weight = 5, min = 1, max = 1 },
			{ itemId = "item.scrap", weight = 5, min = 2, max = 4 },
			{ itemId = "item.snarled_wire", weight = 3, min = 1, max = 1 },
			{ itemId = "item.coil_spring", weight = 2, min = 1, max = 1 },
		},
	},
	["loot.zone_pack_t2"] = {
		id = "loot.zone_pack_t2",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.sealed_tin", weight = 10, min = 1, max = 2 },
			{ itemId = "item.boiled_water", weight = 8, min = 1, max = 2 },
			{ itemId = "item.field_dressing", weight = 12, min = 1, max = 2 },
			{ itemId = "item.cloth", weight = 12, min = 2, max = 3 },
			{ itemId = "item.rope", weight = 10, min = 2, max = 3 },
			{ itemId = "item.pitch_glue", weight = 8, min = 1, max = 2 },
			{ itemId = "item.scrap", weight = 8, min = 3, max = 6 },
			{ itemId = "item.iron_ingot", weight = 6, min = 1, max = 2 },
			{ itemId = "item.coil_spring", weight = 4, min = 1, max = 1 },
			{ itemId = "item.snarled_wire", weight = 4, min = 1, max = 1 },
			{ itemId = "item.seized_motor", weight = 2, min = 1, max = 1 },
			{ itemId = "item.ember_tonic", weight = 2, min = 1, max = 1 },
		},
	},
	["loot.zone_pack_t3"] = {
		id = "loot.zone_pack_t3",
		rolls = { min = 2, max = 4 },
		entries = {
			{ itemId = "item.field_dressing", weight = 14, min = 2, max = 3 },
			{ itemId = "item.hearth_stew", weight = 10, min = 1, max = 1 },
			{ itemId = "item.sealed_tin", weight = 8, min = 2, max = 2 },
			{ itemId = "item.boiled_water", weight = 6, min = 2, max = 2 },
			{ itemId = "item.pitch_glue", weight = 10, min = 1, max = 2 },
			{ itemId = "item.iron_ingot", weight = 10, min = 2, max = 3 },
			{ itemId = "item.scrap_plate", weight = 8, min = 1, max = 2 },
			{ itemId = "item.rivets", weight = 8, min = 2, max = 4 },
			{ itemId = "item.coil_spring", weight = 8, min = 1, max = 2 },
			{ itemId = "item.ember_tonic", weight = 4, min = 1, max = 1 },
			{ itemId = "item.brass_gear", weight = 3, min = 1, max = 1 },
			{ itemId = "item.steel_pipe", weight = 3, min = 1, max = 1 },
		},
	},
	["loot.forest_crate_t1"] = {
		id = "loot.forest_crate_t1",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.timber", weight = 24, min = 3, max = 6 },
			{ itemId = "item.sticks", weight = 18, min = 4, max = 8 },
			{ itemId = "item.plank", weight = 14, min = 2, max = 3 },
			{ itemId = "item.rope", weight = 14, min = 1, max = 2 },
			{ itemId = "item.fatwood", weight = 12, min = 2, max = 3 },
			{ itemId = "item.pitch_glue", weight = 8, min = 1, max = 1 },
			{ itemId = "item.stone_hatchet", weight = 6, min = 1, max = 1 },
			{ itemId = "item.broken_lantern", weight = 4, min = 1, max = 1 },
		},
	},
	["loot.forest_crate_t2"] = {
		id = "loot.forest_crate_t2",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.timber", weight = 18, min = 5, max = 8 },
			{ itemId = "item.plank", weight = 18, min = 3, max = 5 },
			{ itemId = "item.fatwood", weight = 14, min = 3, max = 4 },
			{ itemId = "item.ironbark_log", weight = 12, min = 2, max = 4 },
			{ itemId = "item.pitch_glue", weight = 10, min = 1, max = 2 },
			{ itemId = "item.rope", weight = 10, min = 2, max = 3 },
			{ itemId = "item.rivets", weight = 8, min = 1, max = 2 },
			{ itemId = "item.embercoal", weight = 6, min = 2, max = 4 },
			{ itemId = "item.forged_hatchet", weight = 2, min = 1, max = 1 },
			{ itemId = "item.coil_spring", weight = 2, min = 1, max = 1 },
		},
	},
	["loot.forest_crate_t3"] = {
		id = "loot.forest_crate_t3",
		rolls = { min = 3, max = 4 },
		entries = {
			{ itemId = "item.plank", weight = 16, min = 4, max = 6 },
			{ itemId = "item.ironbark_log", weight = 16, min = 3, max = 6 },
			{ itemId = "item.ironbark_plank", weight = 8, min = 1, max = 2 },
			{ itemId = "item.fatwood", weight = 12, min = 4, max = 6 },
			{ itemId = "item.embercoal", weight = 10, min = 3, max = 5 },
			{ itemId = "item.pitch_glue", weight = 10, min = 2, max = 2 },
			{ itemId = "item.rivets", weight = 10, min = 2, max = 4 },
			{ itemId = "item.coil_spring", weight = 6, min = 1, max = 1 },
			{ itemId = "item.forged_hatchet", weight = 4, min = 1, max = 1 },
			{ itemId = "item.brass_gear", weight = 3, min = 1, max = 1 },
			{ itemId = "item.bp_pack_frame", weight = 2, min = 1, max = 1 },
			{ itemId = "item.seized_motor", weight = 3, min = 1, max = 1 },
		},
	},
	["loot.mine_box_t1"] = {
		id = "loot.mine_box_t1",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.stone", weight = 20, min = 4, max = 8 },
			{ itemId = "item.ironstone", weight = 18, min = 2, max = 4 },
			{ itemId = "item.scrap", weight = 18, min = 3, max = 6 },
			{ itemId = "item.rope", weight = 10, min = 1, max = 2 },
			{ itemId = "item.pitch_glue", weight = 6, min = 1, max = 1 },
			{ itemId = "item.stone_pick", weight = 6, min = 1, max = 1 },
			{ itemId = "item.iron_ingot", weight = 6, min = 1, max = 1 },
			{ tableId = "loot.junk", weight = 10, min = 1, max = 1 },
			{ itemId = "item.rivets", weight = 4, min = 1, max = 2 },
			{ itemId = "item.coil_spring", weight = 2, min = 1, max = 1 },
		},
	},
	["loot.mine_box_t2"] = {
		id = "loot.mine_box_t2",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.ironstone", weight = 18, min = 4, max = 6 },
			{ itemId = "item.scrap", weight = 14, min = 5, max = 8 },
			{ itemId = "item.iron_ingot", weight = 14, min = 1, max = 3 },
			{ itemId = "item.malachite", weight = 10, min = 2, max = 3 },
			{ itemId = "item.stone_block", weight = 10, min = 2, max = 3 },
			{ itemId = "item.rivets", weight = 10, min = 2, max = 3 },
			{ tableId = "loot.junk", weight = 10, min = 1, max = 1 },
			{ itemId = "item.coil_spring", weight = 6, min = 1, max = 1 },
			{ itemId = "item.forged_pick", weight = 3, min = 1, max = 1 },
			{ itemId = "item.copper_ingot", weight = 3, min = 1, max = 1 },
			{ itemId = "item.niter", weight = 2, min = 1, max = 2 },
			{ itemId = "item.brass_gear", weight = 2, min = 1, max = 1 },
		},
	},
	["loot.mine_box_t3"] = {
		id = "loot.mine_box_t3",
		rolls = { min = 3, max = 4 },
		entries = {
			{ itemId = "item.iron_ingot", weight = 16, min = 2, max = 4 },
			{ itemId = "item.malachite", weight = 12, min = 3, max = 5 },
			{ itemId = "item.scrap_plate", weight = 12, min = 2, max = 3 },
			{ itemId = "item.stone_block", weight = 10, min = 3, max = 5 },
			{ itemId = "item.rivets", weight = 10, min = 3, max = 5 },
			{ itemId = "item.copper_ingot", weight = 8, min = 1, max = 2 },
			{ itemId = "item.copper_wire", weight = 6, min = 2, max = 3 },
			{ itemId = "item.coil_spring", weight = 8, min = 1, max = 2 },
			{ itemId = "item.brass_gear", weight = 4, min = 1, max = 1 },
			{ itemId = "item.forged_pick", weight = 4, min = 1, max = 1 },
			{ tableId = "loot.junk", weight = 8, min = 1, max = 1 },
			{ itemId = "item.blackpowder", weight = 2, min = 1, max = 2 },
		},
	},
	["loot.pine_pack"] = {
		id = "loot.pine_pack",
		rolls = { min = 1, max = 3 },
		entries = {
			{ itemId = "item.sealed_tin", weight = 10, min = 1, max = 1 },
			{ itemId = "item.rope", weight = 20, min = 1, max = 3 },
			{ itemId = "item.murky_water", weight = 15, min = 1, max = 2 },
			{ itemId = "item.cloth", weight = 15, min = 1, max = 2 },
			{ itemId = "item.boiled_water", weight = 6, min = 1, max = 1 },
			{ itemId = "item.broken_lantern", weight = 10, min = 1, max = 1 },
			{ itemId = "item.field_dressing", weight = 8, min = 1, max = 1 },
			{ itemId = "item.snarled_wire", weight = 8, min = 1, max = 1 },
			{ itemId = "item.coil_spring", weight = 4, min = 1, max = 1 },
			{ itemId = "item.spiked_club", weight = 2, min = 1, max = 1 },
		},
	},
	["loot.pine_crate"] = {
		id = "loot.pine_crate",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.timber", weight = 20, min = 3, max = 6 },
			{ itemId = "item.sticks", weight = 15, min = 4, max = 8 },
			{ itemId = "item.plank", weight = 20, min = 2, max = 4 },
			{ itemId = "item.scrap", weight = 20, min = 2, max = 4 },
			{ itemId = "item.rope", weight = 15, min = 1, max = 2 },
			{ itemId = "item.pitch_glue", weight = 5, min = 1, max = 1 },
			{ itemId = "item.ironstone", weight = 6, min = 2, max = 4 },
			{ itemId = "item.stone_hatchet", weight = 5, min = 1, max = 1 },
			{ itemId = "item.broken_lantern", weight = 5, min = 1, max = 1 },
		},
	},
	["loot.pine_band2"] = {
		id = "loot.pine_band2",
		rolls = { min = 0, max = 1 },
		entries = {
			{ itemId = "item.cloth", weight = 25, min = 1, max = 2 },
			{ itemId = "item.rope", weight = 20, min = 1, max = 2 },
			{ itemId = "item.sealed_tin", weight = 15, min = 1, max = 1 },
			{ itemId = "item.arrow", weight = 15, min = 2, max = 4 },
			{ itemId = "item.field_dressing", weight = 10, min = 1, max = 1 },
			{ itemId = "item.light_rounds", weight = 10, min = 1, max = 3 },
			{ itemId = "item.pitch_glue", weight = 5, min = 1, max = 1 },
		},
	},
	["loot.pine_band3"] = {
		id = "loot.pine_band3",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.scrap", weight = 25, min = 3, max = 5 },
			{ itemId = "item.rivets", weight = 20, min = 1, max = 2 },
			{ itemId = "item.light_rounds", weight = 18, min = 2, max = 4 },
			{ itemId = "item.coil_spring", weight = 12, min = 1, max = 1 },
			{ itemId = "item.steel_pipe", weight = 10, min = 1, max = 1 },
			{ itemId = "item.ember_tonic", weight = 8, min = 1, max = 1 },
			{ itemId = "item.padded_hood", weight = 7, min = 1, max = 1 },
		},
	},
	["loot.quarry_toolbox"] = {
		id = "loot.quarry_toolbox",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.scrap", weight = 25, min = 3, max = 6 },
			{ itemId = "item.iron_ingot", weight = 15, min = 1, max = 2 },
			{ itemId = "item.scrap_plate", weight = 10, min = 1, max = 2 },
			{ itemId = "item.rivets", weight = 15, min = 1, max = 3 },
			{ tableId = "loot.junk", weight = 22, min = 1, max = 1 },
			{ itemId = "item.arrow", weight = 10, min = 4, max = 8 },
			{ itemId = "item.coil_spring", weight = 6, min = 1, max = 1 },
			{ itemId = "item.copper_wire", weight = 4, min = 1, max = 2 },
			{ itemId = "item.stone_pick", weight = 5, min = 1, max = 1 },
			{ itemId = "item.pitch_glue", weight = 2, min = 1, max = 1 },
		},
	},
	["loot.quarry_locker"] = {
		id = "loot.quarry_locker",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.sealed_tin", weight = 12, min = 1, max = 2 },
			{ itemId = "item.boiled_water", weight = 10, min = 1, max = 2 },
			{ itemId = "item.field_dressing", weight = 15, min = 1, max = 2 },
			{ itemId = "item.cloth", weight = 15, min = 2, max = 3 },
			{ itemId = "item.seized_motor", weight = 6, min = 1, max = 1 },
			{ itemId = "item.padded_hood", weight = 4, min = 1, max = 1 },
			{ itemId = "item.ember_tonic", weight = 3, min = 1, max = 1 },
			{ itemId = "item.shortbow", weight = 2, min = 1, max = 1 },
		},
	},
	["loot.quarry_band2"] = {
		id = "loot.quarry_band2",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.niter", weight = 22, min = 1, max = 3 },
			{ itemId = "item.blackpowder", weight = 16, min = 1, max = 2 },
			{ itemId = "item.light_rounds", weight = 16, min = 2, max = 5 },
			{ itemId = "item.steel_pipe", weight = 14, min = 1, max = 1 },
			{ itemId = "item.rivets", weight = 14, min = 1, max = 3 },
			{ itemId = "item.trigger_group", weight = 3, min = 1, max = 1 },
			{ itemId = "item.shells", weight = 6, min = 1, max = 2 },
			{ itemId = "item.machete", weight = 4, min = 1, max = 1 },
		},
	},
	["loot.quarry_band3"] = {
		id = "loot.quarry_band3",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.blackpowder", weight = 20, min = 2, max = 3 },
			{ itemId = "item.steel_pipe", weight = 16, min = 1, max = 2 },
			{ itemId = "item.trigger_group", weight = 5, min = 1, max = 1 },
			{ itemId = "item.light_rounds", weight = 14, min = 3, max = 6 },
			{ itemId = "item.shells", weight = 10, min = 2, max = 3 },
			{ itemId = "item.flare", weight = 10, min = 1, max = 2 },
			{ itemId = "item.coil_spring", weight = 8, min = 1, max = 2 },
			{ itemId = "item.fire_axe", weight = 4, min = 1, max = 1 },
			{ itemId = "item.machete", weight = 4, min = 1, max = 1 },
		},
	},
	["loot.depot_freight"] = {
		id = "loot.depot_freight",
		rolls = { min = 3, max = 4 },
		entries = {
			{ itemId = "item.scrap_plate", weight = 22, min = 2, max = 4 },
			{ itemId = "item.rivets", weight = 18, min = 2, max = 4 },
			{ itemId = "item.stone_block", weight = 15, min = 2, max = 4 },
			{ itemId = "item.coil_spring", weight = 12, min = 1, max = 2 },
			{ tableId = "loot.junk", weight = 14, min = 1, max = 1 },
			{ itemId = "item.iron_ingot", weight = 10, min = 2, max = 4 },
			{ itemId = "item.ironbark_plank", weight = 6, min = 2, max = 3 },
			{ itemId = "item.copper_ingot", weight = 4, min = 1, max = 1 },
			{ itemId = "item.arrow", weight = 10, min = 6, max = 10 },
			{ itemId = "item.sealed_tin", weight = 10, min = 1, max = 2 },
			{ itemId = "item.hearth_stew", weight = 4, min = 1, max = 1 },
			{ itemId = "item.brass_gear", weight = 4, min = 1, max = 1 },
		},
	},
	["loot.depot_strongbox"] = {
		id = "loot.depot_strongbox",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.brass_gear", weight = 20, min = 1, max = 2 },
			{ itemId = "item.coil_spring", weight = 20, min = 1, max = 2 },
			{ itemId = "item.ember_tonic", weight = 16, min = 1, max = 1 },
			{ itemId = "item.bp_pack_frame", weight = 14, min = 1, max = 1 },
			{ itemId = "item.bp_reinforced", weight = 12, min = 1, max = 1 },
			{ itemId = "item.shortbow", weight = 10, min = 1, max = 1 },
			{ itemId = "item.scrapblade", weight = 8, min = 1, max = 1 },
			{ itemId = "item.padded_vest", weight = 8, min = 1, max = 1 },
		},
		guaranteed = { { itemId = "item.rivets", count = 2 } },
	},
	["loot.depot_band2"] = {
		id = "loot.depot_band2",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.niter", weight = 20, min = 2, max = 4 },
			{ itemId = "item.blackpowder", weight = 18, min = 2, max = 3 },
			{ itemId = "item.trigger_group", weight = 14, min = 1, max = 1 },
			{ itemId = "item.steel_pipe", weight = 14, min = 1, max = 2 },
			{ itemId = "item.shells", weight = 12, min = 2, max = 4 },
			{ itemId = "item.light_rounds", weight = 12, min = 4, max = 8 },
			{ itemId = "item.flare", weight = 10, min = 1, max = 2 },
		},
	},
	["loot.depot_band3"] = {
		id = "loot.depot_band3",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.trigger_group", weight = 20, min = 1, max = 2 },
			{ itemId = "item.blackpowder", weight = 18, min = 3, max = 5 },
			{ itemId = "item.shells", weight = 14, min = 3, max = 6 },
			{ itemId = "item.flare", weight = 12, min = 2, max = 3 },
			{ itemId = "item.brass_gear", weight = 10, min = 1, max = 1 },
			{ itemId = "item.fire_axe", weight = 8, min = 1, max = 1 },
			{ itemId = "item.pipe_pistol", weight = 6, min = 1, max = 1 },
			{ itemId = "item.flare_pistol", weight = 6, min = 1, max = 1 },
			{ itemId = "item.scrap_shotgun", weight = 3, min = 1, max = 1 },
		},
	},
	["loot.junk"] = {
		id = "loot.junk",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.broken_lantern", weight = 45, min = 1, max = 1 },
			{ itemId = "item.snarled_wire", weight = 40, min = 1, max = 1 },
			{ itemId = "item.seized_motor", weight = 15, min = 1, max = 1 },
		},
	},
}

-- Generated from tools/economy/pacing.py (LOCS): ECONOMY §6.2-6.3, in the model's order.
local LOCATIONS: { PacingSim.Location } = {
	{
		id = "loc.bracken_edge",
		tier = 1,
		level = 1,
		energy = 15,
		walkMinutes = 12,
		nodes = {
			{ id = "node.pine_tree", count = 30 },
			{ id = "node.boulder", count = 3 },
			{ id = "node.fallen_branches", count = 12 },
			{ id = "node.loose_stones", count = 12 },
			{ id = "node.reed_patch", count = 20 },
			{ id = "node.ember_bush", count = 10 },
			{ id = "node.ashroot_mound", count = 6 },
			{ id = "node.fatwood_stump", count = 4 },
			{ id = "node.spring_pool", count = 1 },
		},
		containers = {
			{ tableId = "loot.zone_pack_t1", count = 1.5, searchSeconds = 3 },
			{ tableId = "loot.forest_crate_t1", count = 0.5, searchSeconds = 5 },
		},
		enemies = {
			{ id = "enemy.shambler", count = 6 },
			{ id = "enemy.runner", count = 1 },
			{ id = "enemy.wolf", count = 1.5 },
		},
		band2 = "loot.pine_band2",
	},
	{
		id = "loc.ironbark_stand",
		tier = 2,
		level = 8,
		energy = 22,
		walkMinutes = 19,
		nodes = {
			{ id = "node.pine_tree", count = 40 },
			{ id = "node.ironbark_tree", count = 15 },
			{ id = "node.boulder", count = 5 },
			{ id = "node.fallen_branches", count = 15 },
			{ id = "node.loose_stones", count = 12 },
			{ id = "node.reed_patch", count = 30 },
			{ id = "node.ember_bush", count = 10 },
			{ id = "node.ashroot_mound", count = 6 },
			{ id = "node.fatwood_stump", count = 6 },
			{ id = "node.spring_pool", count = 1 },
		},
		containers = {
			{ tableId = "loot.zone_pack_t2", count = 2, searchSeconds = 3 },
			{ tableId = "loot.forest_crate_t2", count = 1.5, searchSeconds = 5 },
		},
		enemies = {
			{ id = "enemy.shambler", count = 7 },
			{ id = "enemy.runner", count = 3.5 },
			{ id = "enemy.bloater", count = 1.5 },
			{ id = "enemy.wolf", count = 2.5 },
		},
		band2 = "loot.quarry_band2",
		gate = "tower_dense",
	},
	{
		id = "loc.gloaming_deep",
		tier = 3,
		level = 15,
		energy = 33,
		walkMinutes = 29,
		nodes = {
			{ id = "node.pine_tree", count = 50 },
			{ id = "node.ironbark_tree", count = 25 },
			{ id = "node.boulder", count = 5 },
			{ id = "node.fallen_branches", count = 20 },
			{ id = "node.loose_stones", count = 10 },
			{ id = "node.reed_patch", count = 40 },
			{ id = "node.ember_bush", count = 10 },
			{ id = "node.ashroot_mound", count = 6 },
			{ id = "node.fatwood_stump", count = 10 },
			{ id = "node.spring_pool", count = 1 },
		},
		containers = {
			{ tableId = "loot.zone_pack_t3", count = 2.5, searchSeconds = 3 },
			{ tableId = "loot.forest_crate_t3", count = 2, searchSeconds = 5 },
		},
		enemies = {
			{ id = "enemy.shambler", count = 9 },
			{ id = "enemy.runner", count = 6 },
			{ id = "enemy.bloater", count = 2.5 },
			{ id = "enemy.wolf", count = 2.5 },
		},
		band2 = "loot.depot_band2",
		gate = "tower_black",
	},
	{
		id = "loc.rockfall_slope",
		tier = 1,
		level = 1,
		energy = 15,
		walkMinutes = 12,
		nodes = {
			{ id = "node.boulder", count = 25 },
			{ id = "node.ironstone_rock", count = 5 },
			{ id = "node.scrap_heap", count = 3 },
			{ id = "node.pine_tree", count = 10 },
			{ id = "node.fallen_branches", count = 8 },
			{ id = "node.loose_stones", count = 20 },
			{ id = "node.reed_patch", count = 20 },
			{ id = "node.ember_bush", count = 10 },
			{ id = "node.spring_pool", count = 1 },
		},
		containers = {
			{ tableId = "loot.zone_pack_t1", count = 1.5, searchSeconds = 3 },
			{ tableId = "loot.mine_box_t1", count = 0.5, searchSeconds = 5 },
		},
		enemies = {
			{ id = "enemy.shambler", count = 6 },
			{ id = "enemy.runner", count = 1.5 },
			{ id = "enemy.wolf", count = 1.5 },
		},
		band2 = "loot.pine_band2",
	},
	{
		id = "loc.greenvein_bluffs",
		tier = 2,
		level = 8,
		energy = 22,
		walkMinutes = 19,
		nodes = {
			{ id = "node.boulder", count = 20 },
			{ id = "node.ironstone_rock", count = 30 },
			{ id = "node.malachite_vein", count = 10 },
			{ id = "node.scrap_heap", count = 4 },
			{ id = "node.niter_seam", count = 4 },
			{ id = "node.pine_tree", count = 13 },
			{ id = "node.fallen_branches", count = 10 },
			{ id = "node.loose_stones", count = 15 },
			{ id = "node.reed_patch", count = 30 },
			{ id = "node.ember_bush", count = 10 },
			{ id = "node.spring_pool", count = 1 },
		},
		containers = {
			{ tableId = "loot.zone_pack_t2", count = 2, searchSeconds = 3 },
			{ tableId = "loot.mine_box_t2", count = 1.5, searchSeconds = 5 },
		},
		enemies = {
			{ id = "enemy.shambler", count = 7 },
			{ id = "enemy.runner", count = 4 },
			{ id = "enemy.bloater", count = 1.5 },
		},
		band2 = "loot.quarry_band2",
		gate = "tower_dense",
	},
	{
		id = "loc.deepcut_pit",
		tier = 3,
		level = 15,
		energy = 33,
		walkMinutes = 29,
		nodes = {
			{ id = "node.boulder", count = 45 },
			{ id = "node.ironstone_rock", count = 50 },
			{ id = "node.malachite_vein", count = 20 },
			{ id = "node.scrap_heap", count = 6 },
			{ id = "node.niter_seam", count = 6 },
			{ id = "node.pine_tree", count = 20 },
			{ id = "node.fallen_branches", count = 10 },
			{ id = "node.loose_stones", count = 22 },
			{ id = "node.reed_patch", count = 40 },
			{ id = "node.ember_bush", count = 10 },
			{ id = "node.spring_pool", count = 1 },
		},
		containers = {
			{ tableId = "loot.zone_pack_t3", count = 2.5, searchSeconds = 3 },
			{ tableId = "loot.mine_box_t3", count = 2, searchSeconds = 5 },
		},
		enemies = {
			{ id = "enemy.shambler", count = 10 },
			{ id = "enemy.runner", count = 6 },
			{ id = "enemy.bloater", count = 2.5 },
		},
		band2 = "loot.depot_band2",
		gate = "tower_black",
	},
	{
		id = "loc.pine_hollow",
		tier = 1,
		level = 1,
		energy = 15,
		walkMinutes = 12,
		nodes = {
			{ id = "node.pine_tree", count = 8 },
			{ id = "node.boulder", count = 4 },
			{ id = "node.fallen_branches", count = 8 },
			{ id = "node.loose_stones", count = 8 },
			{ id = "node.reed_patch", count = 10 },
			{ id = "node.ember_bush", count = 6 },
			{ id = "node.ashroot_mound", count = 6 },
			{ id = "node.spring_pool", count = 2 },
		},
		containers = {
			{ tableId = "loot.pine_pack", count = 4, searchSeconds = 3 },
			{ tableId = "loot.pine_crate", count = 2.5, searchSeconds = 5 },
		},
		enemies = {
			{ id = "enemy.shambler", count = 7.5 },
			{ id = "enemy.runner", count = 1 },
			{ id = "enemy.deer", count = 2.5 },
			{ id = "enemy.wolf", count = 1.5 },
		},
		band2 = "loot.pine_band2",
		band3 = "loot.pine_band3",
	},
	{
		id = "loc.sunken_quarry",
		tier = 2,
		level = 8,
		energy = 22,
		walkMinutes = 19,
		nodes = {
			{ id = "node.scrap_heap", count = 8 },
			{ id = "node.boulder", count = 6 },
			{ id = "node.fatwood_stump", count = 4 },
			{ id = "node.pine_tree", count = 4 },
			{ id = "node.ashroot_mound", count = 4 },
			{ id = "node.niter_seam", count = 4 },
			{ id = "node.spring_pool", count = 2 },
		},
		containers = {
			{ tableId = "loot.quarry_toolbox", count = 3.5, searchSeconds = 5 },
			{ tableId = "loot.quarry_toolbox", count = 2.5, searchSeconds = 5 },
			{ tableId = "loot.quarry_locker", count = 2.5, searchSeconds = 5 },
		},
		enemies = {
			{ id = "enemy.shambler", count = 9 },
			{ id = "enemy.runner", count = 4 },
			{ id = "enemy.bloater", count = 1.5 },
		},
		band2 = "loot.quarry_band2",
		band3 = "loot.quarry_band3",
		gate = "tower_dense",
	},
	{
		id = "loc.ashfall_depot",
		tier = 3,
		level = 15,
		energy = 33,
		walkMinutes = 29,
		nodes = {
			{ id = "node.scrap_heap", count = 14 },
			{ id = "node.fatwood_stump", count = 6 },
			{ id = "node.boulder", count = 6 },
			{ id = "node.ironstone_rock", count = 8 },
			{ id = "node.niter_seam", count = 6 },
			{ id = "node.spring_pool", count = 1 },
		},
		containers = {
			{ tableId = "loot.depot_freight", count = 5.5, searchSeconds = 5 },
			{ tableId = "loot.depot_strongbox", count = 1.5, searchSeconds = 8 },
		},
		enemies = {
			{ id = "enemy.shambler", count = 10 },
			{ id = "enemy.runner", count = 8.5 },
			{ id = "enemy.bloater", count = 2.5 },
		},
		band2 = "loot.depot_band2",
		band3 = "loot.depot_band3",
		gate = "tower_black",
		dailyReset = true, -- the 20 h reset: full only on the day's first clear
	},
}

-- The model (§9.1, pacing.py's P, SINK and policy constants) ------------------------------------

local function count(id: string, n: number): PacingSim.Count
	return { id = id, count = n }
end

local function room(tier: string, foundations: number, walls: number): { PacingSim.Count }
	return {
		count(`build.foundation_{tier}`, foundations),
		count(`build.wall_{tier}`, walls),
		count(`build.window_{tier}`, 2),
		count(`build.doorway_{tier}`, 1),
		count(`build.door_{tier}`, 1),
	}
end

local function join(...: { PacingSim.Count }): { PacingSim.Count }
	local result: { PacingSim.Count } = {}
	for _, list in { ... } do
		for _, entry in list do
			table.insert(result, entry)
		end
	end
	return result
end

-- §11.4's milestone goal lists. `fallback` drops the Smelter and Stonecutter (no model) and
-- upgrades the Campfire, where their lines run, instead of the Smelter.
local function goals(fallback: boolean): { PacingSim.Goal }
	local function keep(list: { PacingSim.Count }): { PacingSim.Count }
		local result: { PacingSim.Count } = {}
		for _, entry in list do
			if fallback and (entry.id == "build.smelter" or entry.id == "build.stonecutter") then
				continue
			end
			if fallback and entry.id == "upgrade:station.smelter" then
				table.insert(result, count("upgrade:station.campfire", entry.count))
			else
				table.insert(result, entry)
			end
		end
		return result
	end
	return {
		{
			name = "hook",
			pieces = keep({
				count("craft:recipe.sharpened_stake", 1), -- First Light's starter weapon
				count("craft:recipe.satchel", 1),
				count("build.campfire", 1),
				count("build.foundation_wood", 2),
				count("build.wall_wood", 2),
				count("build.woodworking_bench", 1),
				count("build.stonecutter", 1),
				count("build.workbench", 1),
			}),
			minLevel = 5,
		},
		{
			name = "timber",
			pieces = keep(join(room("wood", 9, 9), {
				count("build.crate_wood", 2),
				count("build.smelter", 1),
				count("build.campfire", 1),
				count("craft:recipe.spiked_club", 1),
				count("build.woodworking_bench", 1),
			})),
		},
		{
			name = "scrap",
			pieces = keep(join(room("scrap", 9, 9), {
				count("upgrade:station.workbench", 1),
				count("build.recycler", 1),
				count("craft:recipe.pipe_pistol", 1),
				count("gate:tower_dense", 1),
				count("build.workbench", 1),
				count("build.smelter", 1),
				count("build.stonecutter", 1),
			})),
		},
		{
			name = "reinforced",
			pieces = keep(join({
				count("build.foundation_wood", 7),
				count("build.wall_wood", 4),
				count("build.foundation_scrap", 7),
				count("build.wall_scrap", 4),
				count("upgrade:station.woodworking_bench", 2),
				count("upgrade:station.smelter", 1),
				count("gate:tower_black", 1),
				count("build.ammo_press", 1),
			}, room("reinforced", 16, 13))),
			flags = { "item.bp_reinforced" },
		},
	}
end

local function model(minutesPerSession: number, fallback: boolean): PacingSim.Model
	return {
		days = 21, -- was 18: three full weeks, so chapter 3's last quests land inside the run
		sessions = { { start = 8 * 60, minutes = minutesPerSession }, { start = 19 * 60, minutes = minutesPerSession } },
		homeMinutes = 3,
		reservedSlots = 3,
		runCapMinutes = 14,
		hoard = 0.02,
		energyWeight = 0.5,
		contested = 0.6,
		xpWeight = 0.002,
		xpWeightGated = 0.02,
		demandFloor = 6,
		bandMultiplier = 1.15,
		band2Share = 0.45,
		band3Share = 0.15,
		overheadSeconds = { 150, 210, 210 },
		extractSeconds = { 15, 45, 45 },
		keep = { 1, 0.95, 0.92 },
		depotRunsPerDay = 1.2,
		killShare = 0.6,
		killSeconds = {
			["enemy.shambler"] = 5,
			["enemy.runner"] = 8,
			["enemy.bloater"] = 9,
			["enemy.wolf"] = 8,
			["enemy.deer"] = 12,
		},
		wildlife = { ["enemy.deer"] = true, ["enemy.wolf"] = true },
		stalk = { ["enemy.deer"] = true },
		hpScale = { 1, 1.2, 1.4 }, -- ECONOMY §6.4's hollowTierScale
		hitsTakenPerKill = { 0.8, 1.2, 1.5 },
		dressingsPerRun = { 0.3, 0.8, 1.5 },
		gunHitShare = 0.7,
		gunShotsPerRun = { 0, 0, 15 }, -- the Pipe Pistol on Black runs
		gunRecipe = "recipe.pipe_pistol",
		roundsRecipe = "recipe.light_rounds",
		roundsReserve = 45,
		earlyWeapon = "recipe.spiked_club",
		lateWeapon = "recipe.scrapblade",
		lateWeaponFromGoal = 3,
		armorRecipes = { "recipe.padded_hood", "recipe.padded_vest" },
		armorFromGoal = 2,
		dressingRecipe = "recipe.field_dressing",
		dressingReserve = 4,
		toolRecipes = {
			hatchet = { [1] = "recipe.stone_hatchet", [2] = "recipe.forged_hatchet" },
			pick = { [1] = "recipe.stone_pick", [2] = "recipe.forged_pick" },
		},
		spareTools = { below = 80, cost = { ["item.sticks"] = 12, ["item.stone"] = 12 } },
		forgedUpkeep = { fromGoal = 4, count = 2 },
		eatBelow = 55,
		hungerOrder = {
			"item.hearth_stew",
			"item.cooked_meat",
			"item.roasted_ashroot",
			"item.sealed_tin",
			"item.ashroot",
			"item.emberberry",
			"item.raw_meat",
		},
		thirstOrder = {
			"item.boiled_water",
			"item.ember_tea",
			"item.sealed_tin",
			"item.hearth_stew",
			"item.murky_water",
			"item.emberberry",
		},
		foodReserve = 1200,
		cookedValue = { ["item.raw_meat"] = "item.cooked_meat", ["item.murky_water"] = "item.boiled_water" },
		hungryBelow = 400,
		hungryValues = { ["item.raw_meat"] = 12, ["item.sealed_tin"] = 8, ["item.emberberry"] = 1 },
		thirstyValues = { ["item.murky_water"] = 8, ["item.boiled_water"] = 8, ["item.emberberry"] = 1 },
		-- Enemy loot the model counts: meat and hide from wildlife, the bloater's niter
		-- (§7.5: containers only, the other drops are extra).
		enemyDrops = { ["item.raw_meat"] = true, ["item.hide"] = true, ["item.niter"] = true },
		nodeOverheadSeconds = {
			["node.ironbark_tree"] = 4.5,
			["node.malachite_vein"] = 4.5,
			["node.fallen_branches"] = 2.5,
			["node.loose_stones"] = 2.5,
			["node.reed_patch"] = 2.5,
			["node.ember_bush"] = 2.5,
			["node.ashroot_mound"] = 2.5,
			["node.spring_pool"] = 2.5,
		},
		nodeValues = {
			["item.timber"] = 1,
			["item.stone"] = 0.8,
			["item.sticks"] = 0.4,
			["item.fiber"] = 0.5,
			["item.ironstone"] = 3,
			["item.scrap"] = 1.3,
			["item.ironbark_log"] = 5,
			["item.malachite"] = 7,
			["item.fatwood"] = 1.5,
			["item.niter"] = 0.5,
			["item.emberberry"] = 0.3,
			["item.ashroot"] = 0.3,
			["item.murky_water"] = 1.5,
		},
		nodeValueDefault = 0.2,
		offDemand = 0.15,
		values = {
			["item.timber"] = 1,
			["item.stone"] = 0.8,
			["item.sticks"] = 0.4,
			["item.fiber"] = 0.5,
			["item.ironstone"] = 3,
			["item.scrap"] = 1.3,
			["item.ironbark_log"] = 5,
			["item.malachite"] = 7,
			["item.fatwood"] = 1.5,
			["item.plank"] = 2,
			["item.stone_block"] = 3,
			["item.iron_ingot"] = 7,
			["item.scrap_plate"] = 9,
			["item.rivets"] = 4,
			["item.copper_ingot"] = 40,
			["item.copper_wire"] = 20,
			["item.ironbark_plank"] = 25,
			["item.coil_spring"] = 150,
			["item.brass_gear"] = 200,
			["item.steel_pipe"] = 150,
			["item.trigger_group"] = 400,
			["item.bp_reinforced"] = 800,
			["item.rope"] = 1,
			["item.pitch_glue"] = 4,
			["item.raw_meat"] = 3,
			["item.murky_water"] = 2,
			["item.boiled_water"] = 2,
			["item.sealed_tin"] = 2,
			["item.hearth_stew"] = 4,
			["item.emberberry"] = 0.3,
			["item.cloth"] = 1,
			["item.blackpowder"] = 2,
			["item.niter"] = 1,
		},
		valueDefault = 0.05,
		locations = LOCATIONS,
		lootTables = LOOT,
		goals = goals(fallback),
		priority = {
			"gate:tower_dense",
			"gate:tower_black",
			"upgrade:station.workbench",
			"upgrade:station.woodworking_bench",
			"upgrade:station.smelter",
			"upgrade:station.campfire",
			"build.recycler",
		},
		questTriggers = {
			"craft:recipe.sharpened_stake",
			"build.campfire",
			"build.foundation_wood",
			"build.wall_wood",
			"build.woodworking_bench",
			"build.workbench",
			"craft:recipe.spiked_club",
			"build.crate_wood",
			"build.doorway_wood",
			"build.door_wood",
		},
		laterQuests = {
			{ questId = "quest.heartwood", craft = "recipe.forged_hatchet" },
			{ questId = "quest.green_vein", craft = "recipe.forged_pick" },
			{ questId = "quest.into_the_black", blackRun = true },
			-- Chapter 3, Hold the Line. `cost` is what the objectives use up that the model
			-- doesn't build itself, from Data/BuildPieces and Data/Recipes: lights, the two
			-- no-fuel stations, the doormat and spare set, the Padded legs and boots, banded
			-- crates. The model has no Stranded Caravan, so a Dense run stands in for it.
			{
				questId = "quest.light_the_edges",
				cost = {
					["item.sticks"] = 12,
					["item.pitch_glue"] = 6,
					["item.cloth"] = 4,
					["item.plank"] = 4,
					["item.scrap_plate"] = 2,
				},
			},
			{
				questId = "quest.the_plans",
				searched = { ["loc.ashfall_depot"] = 6 },
				built = { ["build.foundation_reinforced"] = 1 },
			},
			{
				questId = "quest.rain_and_smoke",
				cost = {
					["item.timber"] = 8,
					["item.cloth"] = 3,
					["item.scrap"] = 2,
					["item.plank"] = 5,
					["item.rope"] = 10,
					["item.stone"] = 10,
					["item.raw_meat"] = 4,
				},
			},
			{ questId = "quest.copper_lines", crafts = { ["recipe.copper_ingot"] = 4 } },
			{
				questId = "quest.come_home_again",
				cost = { ["item.fiber"] = 22, ["item.cloth"] = 9, ["item.rope"] = 6 },
			},
			{ questId = "quest.walls_that_hold", built = { ["build.wall_reinforced"] = 4 } },
			{
				questId = "quest.room_for_more",
				cost = { ["item.plank"] = 12, ["item.scrap_plate"] = 8, ["item.rivets"] = 4 },
			},
			{
				questId = "quest.padded_through",
				cost = { ["item.cloth"] = 6, ["item.leather"] = 4, ["item.rope"] = 4, ["item.pitch_glue"] = 1 },
			},
			{ questId = "quest.stranded_caravan", runs = { tier2 = 1 } },
			{
				questId = "quest.black_fog_regular",
				searched = { ["loc.ashfall_depot"] = 30 },
				kills = 100,
			},
			{ questId = "quest.full_stores", cost = { ["item.raw_meat"] = 20 } },
			{ questId = "quest.hold_the_line", kills = 500 },
		},
		-- §4.2: the Workbench level is a "known recipe" gate on firearms.
		craftGates = { ["recipe.pipe_pistol"] = { stationId = "station.workbench", level = 2 } },
		recycle = { "item.seized_motor", "item.snarled_wire", "item.broken_lantern" },
		fuelOrder = { "item.embercoal", "item.fatwood", "item.timber", "item.plank", "item.sticks" },
		fuelKeep = { ["item.sticks"] = 15 },
		-- §8.4: the Campfire boils and cooks first.
		lineWants = {
			["item.cooked_meat"] = 30,
			["item.boiled_water"] = 30,
			["item.roasted_ashroot"] = 10,
			["item.ember_tea"] = 10,
			["item.blackpowder"] = 20,
		},
		lineBoost = { ["item.cooked_meat"] = 5, ["item.boiled_water"] = 5 },
		questBoost = 1e6, -- a quest's own craft (Copper Lines' ingots) goes in ahead of the grind
		plankFloat = { below = 30, extra = 10, yieldsTo = { "item.stone_block" } },
		glue = { early = 2, late = 8, fromGoal = 3 },
		coal = { stock = 30, below = 60, stationLevel = 2 },
		ids = {
			cord = "item.rope",
			cordRecipe = "recipe.rope",
			fuelStation = "station.campfire",
			ammoStation = "build.ammo_press",
			fiber = "item.fiber",
			plank = "item.plank",
			timber = "item.timber",
			murky = "item.murky_water",
			rawMeat = "item.raw_meat",
			fatwood = "item.fatwood",
			powder = "item.blackpowder",
			rounds = "item.light_rounds",
			dressing = "item.field_dressing",
			cloth = "item.cloth",
			glue = "item.pitch_glue",
			coal = "item.embercoal",
			plans = "item.bp_reinforced",
			packSchematic = "item.bp_pack_frame",
			satchel = "item.satchel",
			packFrame = "item.pack_frame",
		},
	}
end

-- Every recipe, Fog Runs ones included (the bundle strips them while the flag is off).
local function content(fallback: boolean): PacingSim.Content
	local result: Types.Content = {
		Items = Items,
		Recipes = Recipes,
		Stations = Stations,
		Nodes = Nodes,
		Enemies = Enemies,
		LootTables = LootTables,
		Locations = Bundle.Locations,
		BuildPieces = BuildPieces,
		Levels = Levels,
		Quests = Quests,
		Products = Bundle.Products,
		Projects = Bundle.Projects,
		StarterShelter = Bundle.StarterShelter,
		Tuning = Tuning,
	}
	if fallback then
		-- The layout used while the Smelter and Stonecutter had no approved model (both are
		-- graded A now, so Tuning.stationFallback is empty): kept so that if a model is ever
		-- pulled, the game is still known to be playable on the stand-ins.
		local tuning: any = table.clone(Tuning)
		tuning.stationFallback = {
			["station.smelter"] = "station.campfire",
			["station.stonecutter"] = "station.woodworking_bench",
		}
		result.Tuning = tuning
		StationFallback.apply(result)
	end
	return result :: any
end

-- The day each quest of an Ember Trail chapter was paid (math.huge if never), in pay order.
local function chapterDays(result: PacingSim.Result, chapter: string): { { id: string, day: number } }
	local list: { { id: string, day: number } } = {}
	for id, quest in Quests do
		if quest.chapter == chapter then
			local paid = result.questAt[id]
			table.insert(list, { id = id, day = if paid then PacingSim.day(paid) else math.huge })
		end
	end
	table.sort(list, function(a, b)
		if a.day ~= b.day then
			return a.day < b.day
		end
		return Quests[a.id].order < Quests[b.id].order
	end)
	return list
end

local cache: { [string]: PacingSim.Result } = {}
local function run(minutesPerSession: number, fallback: boolean?): PacingSim.Result
	local key = `{minutesPerSession}{if fallback then "f" else ""}`
	local cached = cache[key]
	if cached then
		return cached
	end
	local settings = model(minutesPerSession, fallback == true)
	if process.env.PACING_TRACE == key then
		settings.trace = function(minute: number, message: string)
			print(
				string.format("    day %d %02d:%02d %s", minute // 1440 + 1, minute % 1440 // 60, minute % 60, message)
			)
		end
	end
	local result = PacingSim.run(content(fallback == true), settings)
	cache[key] = result
	if process.env.PACING_VERBOSE then
		local function stamp(minute: number?): string
			return if minute then string.format("%.2f", PacingSim.day(minute)) else "-"
		end
		local sessions = model(minutesPerSession, false).sessions
		local trail: { string } = {}
		for _, entry in chapterDays(result, "Hold the Line") do
			table.insert(
				trail,
				`{Quests[entry.id].order} {if entry.day < math.huge then string.format("%.2f", entry.day) else "-"}`
			)
		end
		print(
			`  [{2 * minutesPerSession} min/day{if fallback then ", fallback" else ""}] Hold the Line: {table.concat(
				trail,
				", "
			)}; L25 {stamp(result.levelAt[25])}`
		)
		print(
			`  [{2 * minutesPerSession} min/day{if fallback then ", fallback" else ""}] hook {if result.milestones.hook
				then PacingSim.playMinutes(result.milestones.hook, sessions)
				else "-"} play-min, timber {stamp(result.milestones.timber)}, dense {stamp(
				math.max(result.levelAt[8] or math.huge, result.flagAt.tower_dense or math.huge)
			)}, scrap {stamp(result.milestones.scrap)}, black {stamp(
				math.max(result.levelAt[15] or math.huge, result.flagAt.tower_black or math.huge)
			)}, reinforced {stamp(result.milestones.reinforced)}, L20 {stamp(result.levelAt[20])}; runs {result.stats.runs}, broken {result.stats.brokenRuns}, starving {result.stats.starvingMinutes}, food {string.format(
				"%.1f%%",
				100 * result.stats.foodMinutes / math.max(1, result.stats.runMinutes)
			)}, guns {result.stats.gunsCrafted}/{result.stats.gunRuns} runs, L5 {if result.levelAt[5]
				then PacingSim.playMinutes(result.levelAt[5], sessions)
				else "-"} play-min, L8 {stamp(result.levelAt[8])}, L15 {stamp(result.levelAt[15])}`
		)
	end
	return result
end

local function day(minute: number?): number
	return if minute then PacingSim.day(minute) else math.huge
end

-- When a fog tier opens: its level gate and its tower, whichever comes last.
local function opens(result: PacingSim.Result, level: number, tower: string): number
	return math.max(day(result.levelAt[level]), day(result.flagAt[tower]))
end

local function within(value: number, low: number, high: number, label: string)
	TestKit.truthy(value >= low and value <= high, `{label}: day {string.format("%.2f", value)} not in [{low}, {high}]`)
end

-- The LDoE reference ratios of §2.1: input per output and the timer (seconds).
local LDOE: { [string]: { perOutput: number, seconds: number } } = {
	["recipe.plank"] = { perOutput = 1, seconds = 4 * 60 },
	["recipe.ironbark_plank"] = { perOutput = 3, seconds = 20 * 60 },
	["recipe.stone_block"] = { perOutput = 2, seconds = 4 * 60 },
	["recipe.iron_ingot"] = { perOutput = 2, seconds = 4 * 60 },
	["recipe.iron_ingot_from_scrap"] = { perOutput = 4, seconds = 4 * 60 },
	["recipe.copper_ingot"] = { perOutput = 5, seconds = 60 * 60 },
	["recipe.scrap_plate"] = { perOutput = 1, seconds = 20 * 60 },
	["recipe.rivets"] = { perOutput = 0.5, seconds = 4 * 60 },
	["recipe.copper_wire"] = { perOutput = 0.5, seconds = 10 * 60 },
	["recipe.embercoal"] = { perOutput = 1, seconds = 4 * 60 },
	["recipe.cloth"] = { perOutput = 2, seconds = 2 * 60 },
}

return function(test: TestKit.Register)
	-- Invariants (data only) -------------------------------------------------------------------
	test("ECONOMY §2.1: every refinement is LDoE's ratio and timer or harsher", function()
		for _, recipeId in { "recipe.plank", "recipe.ironbark_plank", "recipe.stone_block", "recipe.iron_ingot" } do
			TestKit.truthy(LDOE[recipeId], recipeId)
		end
		for recipeId, reference in LDOE do
			local recipe = Recipes[recipeId]
			TestKit.truthy(recipe and recipe.stationId, `{recipeId} is a station line`)
			local perOutput = recipe.inputs[1].count / recipe.outputs[1].count
			TestKit.truthy(
				perOutput >= reference.perOutput,
				`{recipeId}: {perOutput} per output, LDoE {reference.perOutput}`
			)
			TestKit.truthy(
				recipe.craftSeconds >= reference.seconds,
				`{recipeId}: {recipe.craftSeconds} s, LDoE {reference.seconds}`
			)
		end
		TestKit.equal(Recipes["recipe.ironbark_plank"].inputs[1].count * 4, 20, "20 logs make 4 planks")
	end)

	test("home covers the hook but not the Timber base: 84 timber against 221", function()
		local timber = 0
		for _, entry in Tuning.home.nodes do
			timber += (Gathering.expectedYield(Nodes[entry.nodeId])["item.timber"] or 0) * entry.count
		end
		TestKit.equal(timber, 84, "home timber (28 pines, the flow review's F-07)")
		local base = 0
		local timberGoal = goals(false)[2]
		for _, entry in timberGoal.pieces do
			local piece = BuildPieces[entry.id]
			for _, stack in (if piece then piece.cost else {}) :: { Types.ItemStack } do
				if stack.itemId == "item.timber" then
					base += stack.count * entry.count
				end
			end
		end
		TestKit.truthy(timber < base, `home {timber} timber, the Timber base's pieces {base}`)
	end)

	test("one stone tool returns at least 10x the material it costs", function()
		for _, pair in
			{
				{
					tool = "item.stone_hatchet",
					recipe = "recipe.stone_hatchet",
					node = "node.pine_tree",
					input = "item.sticks",
				},
				{ tool = "item.stone_pick", recipe = "recipe.stone_pick", node = "node.boulder", input = "item.stone" },
			}
		do
			local node = Nodes[pair.node]
			local perHit = 0
			for _, units in Gathering.expectedYield(node) do
				perHit += units / node.hits
			end
			local life = (Items[pair.tool].durability :: number) * perHit
			local spent = 0
			for _, stack in Recipes[pair.recipe].inputs do
				if stack.itemId == pair.input then
					spent += stack.count
				end
			end
			TestKit.truthy(life >= 10 * spent, `{pair.tool}: {life} units for {spent} {pair.input}`)
		end
	end)

	test("every station level's upgrade can be paid before that level exists", function()
		for _, layout in { false, true } do
			local errors = DataValidator.validate(content(layout) :: any)
			for _, message in errors do
				TestKit.truthy(not string.find(message, "upgradeCost", 1, true), message)
			end
		end
	end)

	test("tier-2 nodes need a tier-2 tool, and that tool is made from tier-1 materials", function()
		local tierTwo: { [string]: boolean } = {}
		for _, node in Nodes do
			if node.tool and node.tool.tier >= 2 then
				TestKit.equal(
					Gathering.canHarvest(node, { kind = node.tool.kind, tier = 1 }),
					false,
					`{node.id}: a tier-1 tool can't take it`
				)
				for itemId in Gathering.expectedYield(node) do
					tierTwo[itemId] = true
				end
			end
		end
		TestKit.truthy(next(tierTwo) ~= nil, "tier-2 nodes exist")
		local function fromTierOne(itemId: string, depth: number): boolean
			if tierTwo[itemId] then
				return false
			end
			if depth > 6 then
				return true
			end
			for id, recipe in Recipes do
				if recipe.outputs[1].itemId == itemId and not string.find(id, "_from_", 1, true) then
					for _, stack in recipe.inputs do
						if not fromTierOne(stack.itemId, depth + 1) then
							return false
						end
					end
					return true
				end
			end
			return true
		end
		for _, recipeId in { "recipe.forged_hatchet", "recipe.forged_pick" } do
			local output = Items[Recipes[recipeId].outputs[1].itemId]
			TestKit.equal((output.tool :: Types.ToolStats).tier, 2, recipeId)
			for _, stack in Recipes[recipeId].inputs do
				TestKit.truthy(fromTierOne(stack.itemId, 0), `{recipeId}: '{stack.itemId}' needs a tier-2 node`)
			end
		end
	end)

	test("ECONOMY §8.1: guns break fast; a Pipe Pistol lasts at most 4 Black runs", function()
		TestKit.equal(Items["item.pipe_pistol"].durability, 50, "Pipe Pistol shots")
		TestKit.equal(Items["item.scrap_shotgun"].durability, 30, "Scrap Shotgun shells")
		local shots = model(75, false).gunShotsPerRun[3]
		TestKit.truthy((Items["item.pipe_pistol"].durability :: number) / shots <= 4, "runs per pistol")
	end)

	-- The simulation ---------------------------------------------------------------------------
	test("2.5 h a day (2 x 75 min): every milestone lands in its GAME_DESIGN band", function()
		local result = run(75)
		local sessions = model(75, false).sessions
		TestKit.truthy(result.milestones.hook, "the hook is reached")
		local hook = PacingSim.playMinutes(result.milestones.hook, sessions)
		TestKit.truthy(hook <= 60, `the hook took {hook} play-minutes`)
		TestKit.truthy(day(result.milestones.timber) < 2, `Timber on day {day(result.milestones.timber)}`)
		-- On day 3 (DECISIONS 2026-11-08: "Dense and Black open on days 3 and 7"). §11.4's table
		-- says <= 3.5, but pacing.py itself repairs the tower at day 3 19:00 (3.79): the planks
		-- go to the Workbench's level 2 first.
		TestKit.truthy(opens(result, 8, "tower_dense") < 4, `Dense fog opens day {opens(result, 8, "tower_dense")}`)
		within(day(result.milestones.scrap), 3.0, 5.99, "Scrap tier")
		within(opens(result, 15, "tower_black"), 5.0, 8.0, "Black fog")
		within(day(result.milestones.reinforced), 10.0, 14.99, "Reinforced tier")
	end)

	test("2.5 h a day: every sink bites, and nobody starves", function()
		local result = run(75)
		local stats = result.stats
		TestKit.equal(stats.starvingMinutes, 0, "starving minutes")
		TestKit.truthy(stats.foodMinutes <= 0.15 * stats.runMinutes, "food time at most 15% of run time")
		TestKit.truthy(stats.brokenRuns >= 0.1 * stats.runs, `{stats.brokenRuns} of {stats.runs} runs broke a weapon`)
		TestKit.truthy(stats.gunsCrafted > 0 and stats.gunRuns > 0, "the Pipe Pistol is used on Black runs")
		TestKit.truthy(
			stats.gunRuns <= 4 * stats.gunsCrafted,
			`{stats.gunRuns} gun runs on {stats.gunsCrafted} pistols`
		)
		-- At least a Scrapblade a day once the Scrap tier is done, on average: on a day the
		-- plates all go into walls the blade waits (pacing.py has those days too, §8.5).
		local scrapDay = math.floor(day(result.milestones.scrap)) + 1
		local blades = stats.crafted["recipe.scrapblade"] or {}
		local total = 0
		for d = scrapDay, 18 do
			total += blades[d] or 0
		end
		TestKit.truthy(total >= 18 - scrapDay + 1, `{total} Scrapblades over days {scrapDay}-18`)
	end)

	test("2 h a day (2 x 60 min): the low edge still lands", function()
		local result = run(60)
		TestKit.truthy(day(result.milestones.timber) < 2, `Timber on day {day(result.milestones.timber)}`)
		TestKit.truthy(day(result.milestones.scrap) <= 6.5, `Scrap on day {day(result.milestones.scrap)}`)
		TestKit.truthy(
			day(result.milestones.reinforced) <= 15.99,
			`Reinforced on day {day(result.milestones.reinforced)}`
		)
	end)

	test("3 h a day (2 x 90 min): the grind still takes days", function()
		local result = run(90)
		TestKit.truthy(day(result.milestones.scrap) >= 3.0, `Scrap on day {day(result.milestones.scrap)}`)
		TestKit.truthy(
			day(result.milestones.reinforced) >= 10.0,
			`Reinforced on day {day(result.milestones.reinforced)}`
		)
	end)

	-- The content parity audit's BR-8: the trail used to end on day 7 and level 20 (the cap)
	-- came on day 12, a cliff before the Reinforced tier was even done.
	test("2.5 h a day: chapter 3 runs from the Black fog to about day 20, with no cliff", function()
		local result = run(75)
		local black = opens(result, 15, "tower_black")
		local last = day(result.questAt["quest.into_the_black"])
		TestKit.truthy(last <= black + 1, `Into the Black on day {last}, the Black fog opens {black}`)
		local list = chapterDays(result, "Hold the Line")
		TestKit.equal(#list, 12, "chapter 3 quests")
		for _, entry in list do
			TestKit.truthy(entry.day < math.huge, `{entry.id} is never finished`)
			TestKit.truthy(entry.day - last <= 3, `{entry.id} on day {entry.day}: over 3 days after the one before`)
			last = entry.day
		end
		within(list[1].day, black, black + 2, "chapter 3's first quest")
		within(last, 17, 21, "chapter 3's last quest")
		-- Level 25 is the trail's last ask; level 30, the cap, outlasts the three weeks.
		within(day(result.levelAt[25]), 15, 21, "level 25")
		TestKit.equal(result.levelAt[30], nil, "level 30 is reached inside three weeks")
	end)

	test("2 h and 3 h a day: chapter 3 never stalls, and still takes the low end two weeks", function()
		for _, minutes in { 60, 90 } do
			local list = chapterDays(run(minutes), "Hold the Line")
			for _, entry in list do
				-- At 2 h a day, level 25 (the last quest's ask) lands at the end of week three.
				if entry.id ~= "quest.hold_the_line" or minutes > 60 then
					TestKit.truthy(entry.day < math.huge, `{2 * minutes} min/day: {entry.id} is never finished`)
				end
			end
			TestKit.truthy(list[#list].day >= 14, `{2 * minutes} min/day: chapter 3 done on day {list[#list].day}`)
		end
	end)

	test("the station fallback layout (no Smelter or Stonecutter model) stays playable to Reinforced", function()
		-- Tuning.stationFallback: ingots at the Campfire, blocks at the Saw Bench (§10.1).
		-- It keeps every tier reachable, and the early game on time, but the two Campfires
		-- carry food, coal and every ingot, so the later tiers slip past their bands: the
		-- Smelter model is a hard launch requirement (DECISIONS 2026-11-08), not optional.
		local result = run(75, true)
		local sessions = model(75, true).sessions
		local hook = PacingSim.playMinutes(result.milestones.hook or math.huge, sessions)
		TestKit.truthy(hook <= 75, `the hook took {hook} play-minutes`)
		TestKit.truthy(day(result.milestones.timber) < 2, `Timber on day {day(result.milestones.timber)}`)
		within(day(result.milestones.scrap), 3.0, 6.99, "Scrap tier")
		TestKit.truthy(day(result.milestones.reinforced) < 19, `Reinforced on day {day(result.milestones.reinforced)}`)
	end)
end
