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
	-- The bloater's crust is niter: one of the few sources of Blackpowder.
	["loot.enemy_bloater"] = {
		id = "loot.enemy_bloater",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.niter", weight = 45, min = 1, max = 2 },
			{ itemId = "item.cloth", weight = 25, min = 1, max = 2 },
			{ itemId = "item.scrap", weight = 20, min = 2, max = 3 },
			{ itemId = "item.field_dressing", weight = 10, min = 1, max = 1 },
		},
	},
	-- Wildlife (LDOE_PARITY #35): meat always, hide usually.
	["loot.animal_deer"] = {
		id = "loot.animal_deer",
		rolls = { min = 1, max = 1 },
		entries = { { itemId = "item.hide", weight = 1, min = 1, max = 2 } },
		guaranteed = { { itemId = "item.raw_meat", count = 3 } },
	},
	["loot.animal_wolf"] = {
		id = "loot.animal_wolf",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.hide", weight = 70, min = 1, max = 1 },
			{ itemId = "item.raw_meat", weight = 30, min = 1, max = 1 },
		},
		guaranteed = { { itemId = "item.raw_meat", count = 1 } },
	},
	-- The airdrop's guarded crate (LDOE_PARITY #43): a reward for spending Energy.
	["loot.airdrop_crate"] = {
		id = "loot.airdrop_crate",
		rolls = { min = 3, max = 4 },
		entries = {
			{ itemId = "item.sealed_tin", weight = 20, min = 2, max = 3 },
			{ itemId = "item.field_dressing", weight = 18, min = 2, max = 3 },
			{ itemId = "item.light_rounds", weight = 16, min = 6, max = 10 },
			{ itemId = "item.blackpowder", weight = 14, min = 2, max = 4 },
			{ itemId = "item.scrap_plate", weight = 12, min = 2, max = 4 },
			{ itemId = "item.ember_tonic", weight = 8, min = 1, max = 1 },
			{ itemId = "item.steel_pipe", weight = 7, min = 1, max = 1 },
			{ itemId = "item.trigger_group", weight = 5, min = 1, max = 1 },
		},
		guaranteed = { { itemId = "item.rations", count = 1 } },
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
			-- Launch content: the found melee weapon and loose Reedweave pieces.
			{ itemId = "item.tire_iron", weight = 3, min = 1, max = 1 },
			{ itemId = "item.reedweave_cap", weight = 3, min = 1, max = 1 },
			{ itemId = "item.reedweave_wraps", weight = 3, min = 1, max = 1 },
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
			{ itemId = "item.stone_hatchet", weight = 5, min = 1, max = 1 },
			{ itemId = "item.tire_iron", weight = 3, min = 1, max = 1 },
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
			{ itemId = "item.rail_mallet", weight = 3, min = 1, max = 1 },
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
			{ itemId = "item.rail_mallet", weight = 3, min = 1, max = 1 },
			{ itemId = "item.padded_leggings", weight = 2, min = 1, max = 1 },
			{ itemId = "item.padded_boots", weight = 2, min = 1, max = 1 },
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

	-- Fog Runs (slice 2): meter-band bonus loot ---------------------------------------------
	-- Every container searched once the Fog meter reaches a band also rolls that band's
	-- table (Location.run.bandLoot, Domain/Containers): staying late pays, and it is where
	-- the gun parts are. Trigger Groups drop only in Dense and Black bands; at 2-3 band-2+
	-- containers a Dense run, a free player finds the first one in about 4-6 runs (day 3).
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
	["loot.quarry_band2"] = {
		id = "loot.quarry_band2",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.niter", weight = 22, min = 1, max = 3 },
			{ itemId = "item.blackpowder", weight = 16, min = 1, max = 2 },
			{ itemId = "item.light_rounds", weight = 16, min = 2, max = 5 },
			{ itemId = "item.steel_pipe", weight = 14, min = 1, max = 1 },
			{ itemId = "item.rivets", weight = 14, min = 1, max = 3 },
			{ itemId = "item.trigger_group", weight = 8, min = 1, max = 1 },
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
			{ itemId = "item.trigger_group", weight = 14, min = 1, max = 1 },
			{ itemId = "item.light_rounds", weight = 14, min = 3, max = 6 },
			{ itemId = "item.shells", weight = 10, min = 2, max = 3 },
			{ itemId = "item.flare", weight = 10, min = 1, max = 2 },
			{ itemId = "item.coil_spring", weight = 8, min = 1, max = 2 },
			{ itemId = "item.fire_axe", weight = 4, min = 1, max = 1 },
			{ itemId = "item.machete", weight = 4, min = 1, max = 1 },
		},
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
			{ itemId = "item.pipe_pistol", weight = 6, min = 1, max = 1, rarity = "epic" },
			{ itemId = "item.flare_pistol", weight = 6, min = 1, max = 1, rarity = "epic" },
			{ itemId = "item.scrap_shotgun", weight = 3, min = 1, max = 1, rarity = "epic" },
		},
		-- Bad-luck protection: a whole gun at least once in every 10 late Black-fog containers.
		pity = { rarity = "epic", every = 10 },
	},
	["loot.caravan_band2"] = {
		id = "loot.caravan_band2",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.blackpowder", weight = 25, min = 1, max = 3 },
			{ itemId = "item.flare", weight = 20, min = 1, max = 2 },
			{ itemId = "item.light_rounds", weight = 20, min = 3, max = 6 },
			{ itemId = "item.steel_pipe", weight = 20, min = 1, max = 1 },
			{ itemId = "item.trigger_group", weight = 15, min = 1, max = 1 },
		},
	},
	["loot.caravan_band3"] = {
		id = "loot.caravan_band3",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.trigger_group", weight = 25, min = 1, max = 1 },
			{ itemId = "item.shells", weight = 20, min = 2, max = 4 },
			{ itemId = "item.flare", weight = 20, min = 2, max = 3 },
			{ itemId = "item.blackpowder", weight = 20, min = 2, max = 4 },
			{ itemId = "item.flare_pistol", weight = 8, min = 1, max = 1 },
			{ itemId = "item.machete", weight = 7, min = 1, max = 1 },
		},
	},

	-- Fog Runs (slice 2): "found on the way" (Domain/TravelBonus) ---------------------------
	["loot.road_light"] = {
		id = "loot.road_light",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.sticks", weight = 25, min = 3, max = 6 },
			{ itemId = "item.fiber", weight = 25, min = 2, max = 4 },
			{ itemId = "item.emberberry", weight = 20, min = 2, max = 4 },
			{ itemId = "item.murky_water", weight = 15, min = 1, max = 2 },
			{ itemId = "item.scrap", weight = 10, min = 1, max = 2 },
			{ itemId = "item.broken_lantern", weight = 5, min = 1, max = 1 },
		},
	},
	["loot.road_dense"] = {
		id = "loot.road_dense",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.scrap", weight = 25, min = 2, max = 4 },
			{ itemId = "item.timber", weight = 20, min = 2, max = 4 },
			{ itemId = "item.fatwood", weight = 15, min = 1, max = 2 },
			{ itemId = "item.niter", weight = 15, min = 1, max = 1 },
			{ itemId = "item.sealed_tin", weight = 15, min = 1, max = 1 },
			{ tableId = "loot.junk", weight = 10, min = 1, max = 1 },
		},
	},
	["loot.road_black"] = {
		id = "loot.road_black",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.scrap_plate", weight = 25, min = 1, max = 2 },
			{ itemId = "item.niter", weight = 20, min = 1, max = 2 },
			{ itemId = "item.rivets", weight = 20, min = 1, max = 2 },
			{ itemId = "item.sealed_tin", weight = 15, min = 1, max = 1 },
			{ itemId = "item.blackpowder", weight = 10, min = 1, max = 1 },
			{ tableId = "loot.junk", weight = 10, min = 1, max = 1 },
		},
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
