--!strict
-- Loot table definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.
-- One table per container type and per enemy, plus shared sub-tables. Each roll
-- picks one entry by weight; a `tableId` entry opens that sub-table; `guaranteed`
-- stacks are always added on top; `pity` guarantees a rarity every N opens
-- (Domain/Loot).

local Types = require("../Types")

local LootTables: { [Types.LootTableId]: Types.LootTableDef } = {
	-- The Hollow ------------------------------------------------------------------
	["loot.enemy_shambler"] = {
		id = "loot.enemy_shambler",
		rolls = { min = 0, max = 1 },
		entries = {
			{ itemId = "item.fiber", weight = 30, min = 1, max = 2 },
			{ itemId = "item.rope", weight = 25, min = 1, max = 1 },
			{ itemId = "item.cloth", weight = 20, min = 1, max = 1 },
			{ itemId = "item.scrap", weight = 25, min = 1, max = 3 },
		},
	},
	["loot.enemy_runner"] = {
		id = "loot.enemy_runner",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.scrap", weight = 35, min = 2, max = 4 },
			{ itemId = "item.rope", weight = 25, min = 1, max = 2 },
			{ itemId = "item.cloth", weight = 25, min = 1, max = 2 },
			{ itemId = "item.sealed_tin", weight = 10, min = 1, max = 1 },
			{ itemId = "item.snarled_wire", weight = 5, min = 1, max = 1 },
		},
	},
	["loot.enemy_brute"] = {
		id = "loot.enemy_brute",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.scrap_plate", weight = 30, min = 1, max = 2 },
			{ itemId = "item.rivets", weight = 25, min = 1, max = 2 },
			{ itemId = "item.sealed_tin", weight = 20, min = 1, max = 1 },
			{ itemId = "item.coil_spring", weight = 15, min = 1, max = 1 },
			{ tableId = "loot.junk", weight = 10, min = 1, max = 1 },
		},
		guaranteed = { { itemId = "item.scrap", count = 3 } },
	},

	-- Pine Hollow (Light fog) -------------------------------------------------------
	["loot.pine_pack"] = {
		id = "loot.pine_pack",
		rolls = { min = 1, max = 3 },
		entries = {
			{ itemId = "item.sealed_tin", weight = 20, min = 1, max = 1 },
			{ itemId = "item.rope", weight = 20, min = 1, max = 3 },
			{ itemId = "item.murky_water", weight = 15, min = 1, max = 2 },
			{ itemId = "item.cloth", weight = 15, min = 1, max = 2 },
			{ itemId = "item.boiled_water", weight = 10, min = 1, max = 1 },
			{ itemId = "item.broken_lantern", weight = 10, min = 1, max = 1 },
			{ itemId = "item.field_dressing", weight = 8, min = 1, max = 1 },
			{ itemId = "item.snarled_wire", weight = 8, min = 1, max = 1 },
			{ itemId = "item.spiked_club", weight = 2, min = 1, max = 1 },
		},
	},
	["loot.pine_crate"] = {
		id = "loot.pine_crate",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.timber", weight = 25, min = 3, max = 6 },
			{ itemId = "item.plank", weight = 25, min = 2, max = 4 },
			{ itemId = "item.scrap", weight = 20, min = 2, max = 4 },
			{ itemId = "item.rope", weight = 15, min = 1, max = 2 },
			{ itemId = "item.pitch_glue", weight = 5, min = 1, max = 1 },
			{ itemId = "item.stone_hatchet", weight = 5, min = 1, max = 1 },
			{ itemId = "item.broken_lantern", weight = 5, min = 1, max = 1 },
		},
	},

	-- Sunken Quarry (Dense fog) -------------------------------------------------------
	["loot.quarry_toolbox"] = {
		id = "loot.quarry_toolbox",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.scrap", weight = 25, min = 3, max = 6 },
			{ itemId = "item.scrap_plate", weight = 15, min = 1, max = 2 },
			{ itemId = "item.rivets", weight = 15, min = 1, max = 3 },
			{ tableId = "loot.junk", weight = 22, min = 1, max = 1 },
			{ itemId = "item.arrow", weight = 10, min = 4, max = 8 },
			{ itemId = "item.coil_spring", weight = 6, min = 1, max = 1 },
			{ itemId = "item.stone_pick", weight = 5, min = 1, max = 1 },
			{ itemId = "item.pitch_glue", weight = 2, min = 1, max = 1 },
		},
	},
	["loot.quarry_locker"] = {
		id = "loot.quarry_locker",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.sealed_tin", weight = 25, min = 1, max = 2 },
			{ itemId = "item.boiled_water", weight = 20, min = 1, max = 2 },
			{ itemId = "item.field_dressing", weight = 15, min = 1, max = 2 },
			{ itemId = "item.cloth", weight = 15, min = 2, max = 3 },
			{ itemId = "item.seized_motor", weight = 6, min = 1, max = 1 },
			{ itemId = "item.padded_hood", weight = 4, min = 1, max = 1 },
			{ itemId = "item.ember_tonic", weight = 3, min = 1, max = 1 },
			{ itemId = "item.shortbow", weight = 2, min = 1, max = 1 },
		},
	},

	-- Ashfall Depot (Black fog) -----------------------------------------------------------
	["loot.depot_freight"] = {
		id = "loot.depot_freight",
		rolls = { min = 3, max = 4 },
		entries = {
			{ itemId = "item.scrap_plate", weight = 22, min = 2, max = 4 },
			{ itemId = "item.rivets", weight = 18, min = 2, max = 4 },
			{ itemId = "item.stone_block", weight = 15, min = 2, max = 4 },
			{ itemId = "item.coil_spring", weight = 12, min = 1, max = 2 },
			{ tableId = "loot.junk", weight = 14, min = 1, max = 1 },
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
			{ itemId = "item.bp_pack_frame", weight = 14, min = 1, max = 1, rarity = "epic" },
			{ itemId = "item.bp_reinforced", weight = 12, min = 1, max = 1, rarity = "epic" },
			{ itemId = "item.shortbow", weight = 10, min = 1, max = 1 },
			{ itemId = "item.scrapblade", weight = 8, min = 1, max = 1 },
			{ itemId = "item.padded_vest", weight = 8, min = 1, max = 1 },
		},
		guaranteed = { { itemId = "item.rivets", count = 2 } },
		-- Bad-luck protection: a blueprint at least once in every 5 strongboxes.
		pity = { rarity = "epic", every = 5 },
	},

	-- Stranded Caravan (rotating event) ------------------------------------------------------
	["loot.caravan_wagon"] = {
		id = "loot.caravan_wagon",
		rolls = { min = 2, max = 4 },
		entries = {
			{ itemId = "item.plank", weight = 15, min = 4, max = 8 },
			{ itemId = "item.scrap_plate", weight = 15, min = 2, max = 4 },
			{ itemId = "item.rivets", weight = 14, min = 2, max = 4 },
			{ itemId = "item.stone_block", weight = 12, min = 3, max = 5 },
			{ itemId = "item.coil_spring", weight = 10, min = 1, max = 2 },
			{ itemId = "item.sealed_tin", weight = 10, min = 2, max = 3 },
			{ itemId = "item.hearth_stew", weight = 8, min = 1, max = 2 },
			{ itemId = "item.field_dressing", weight = 8, min = 2, max = 2 },
			{ itemId = "item.ember_tonic", weight = 4, min = 1, max = 1 },
			{ tableId = "loot.junk", weight = 6, min = 1, max = 1 },
		},
	},
	["loot.caravan_strongbox"] = {
		id = "loot.caravan_strongbox",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.bp_pack_frame", weight = 30, min = 1, max = 1, rarity = "epic" },
			{ itemId = "item.bp_reinforced", weight = 30, min = 1, max = 1, rarity = "epic" },
			{ itemId = "item.ember_tonic", weight = 20, min = 1, max = 1 },
			{ itemId = "item.brass_gear", weight = 20, min = 1, max = 2 },
		},
		guaranteed = {
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.rivets", count = 3 },
		},
		pity = { rarity = "epic", every = 3 },
	},

	-- Shared sub-tables (opened through an entry's tableId) ---------------------------------
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

return LootTables
