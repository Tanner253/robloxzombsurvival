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
		-- Always one roll: every Hollow leaves something to take, as every body in LDoE can
		-- be searched, so "take what it drops" (Into the Fog) never hangs on a coin flip.
		rolls = { min = 1, max = 1 },
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
	-- The bloater's crust is niter: Signal Flares are made from it.
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
			{ itemId = "item.scrap", weight = 30, min = 3, max = 6 }, -- was Light Rounds 16 and Blackpowder 14 (F-13)
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
			{ itemId = "item.sealed_tin", weight = 10, min = 1, max = 1 },
			{ itemId = "item.rope", weight = 20, min = 1, max = 3 },
			{ itemId = "item.murky_water", weight = 15, min = 1, max = 2 },
			{ itemId = "item.cloth", weight = 15, min = 1, max = 2 },
			{ itemId = "item.boiled_water", weight = 6, min = 1, max = 1 },
			{ itemId = "item.broken_lantern", weight = 10, min = 1, max = 1 },
			{ itemId = "item.field_dressing", weight = 8, min = 1, max = 1 },
			{ itemId = "item.hide", weight = 6, min = 1, max = 1 }, -- the hunters' camp (no wildlife until post-launch)
			{ itemId = "item.snarled_wire", weight = 8, min = 1, max = 1 },
			{ itemId = "item.coil_spring", weight = 4, min = 1, max = 1 },
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
			{ itemId = "item.ironstone", weight = 6, min = 2, max = 4 },
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
			{ itemId = "item.scrap", weight = 35, min = 3, max = 6 }, -- +10 from arrows (F-13)
			{ itemId = "item.iron_ingot", weight = 15, min = 1, max = 2 },
			{ itemId = "item.scrap_plate", weight = 10, min = 1, max = 2 },
			{ itemId = "item.rivets", weight = 15, min = 1, max = 3 },
			{ tableId = "loot.junk", weight = 22, min = 1, max = 1 },
			{ itemId = "item.coil_spring", weight = 6, min = 1, max = 1 },
			{ itemId = "item.copper_wire", weight = 4, min = 1, max = 2 },
			{ itemId = "item.stone_pick", weight = 5, min = 1, max = 1 },
			{ itemId = "item.rail_mallet", weight = 3, min = 1, max = 1 },
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
			{ itemId = "item.iron_ingot", weight = 10, min = 2, max = 4 },
			{ itemId = "item.ironbark_plank", weight = 6, min = 2, max = 3 },
			{ itemId = "item.copper_ingot", weight = 4, min = 1, max = 1 },
			{ itemId = "item.scrap", weight = 10, min = 3, max = 6 }, -- was arrows (F-13)
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
			{ itemId = "item.scrap", weight = 25, min = 2, max = 4 }, -- was arrows 15 and Light Rounds 10 (F-13)
			{ itemId = "item.field_dressing", weight = 10, min = 1, max = 1 },
			{ itemId = "item.pitch_glue", weight = 5, min = 1, max = 1 },
		},
	},
	["loot.pine_band3"] = {
		id = "loot.pine_band3",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.scrap", weight = 43, min = 3, max = 5 }, -- +18 from Light Rounds (F-13)
			{ itemId = "item.rivets", weight = 20, min = 1, max = 2 },
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
			{ itemId = "item.scrap", weight = 38, min = 2, max = 4 }, -- was Blackpowder 16, Light Rounds 16, Shells 6 (F-13)
			{ itemId = "item.steel_pipe", weight = 14, min = 1, max = 1 },
			{ itemId = "item.rivets", weight = 14, min = 1, max = 3 },
			{ itemId = "item.trigger_group", weight = 3, min = 1, max = 1, rarity = "epic" },
			{ itemId = "item.machete", weight = 4, min = 1, max = 1 },
		},
		pity = { rarity = "epic", every = 15 }, -- ECONOMY §7.4: a Trigger Group by the 15th band-2 Dense container
	},
	["loot.quarry_band3"] = {
		id = "loot.quarry_band3",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.scrap_plate", weight = 18, min = 1, max = 2 }, -- F-13: ARSENAL 3.4 parts replace the 44 weight of rounds
			{ itemId = "item.steel_pipe", weight = 16, min = 1, max = 2 },
			{ itemId = "item.trigger_group", weight = 5, min = 1, max = 1 },
			{ itemId = "item.rivets", weight = 14, min = 1, max = 3 },
			{ itemId = "item.flare", weight = 10, min = 1, max = 2 },
			{ itemId = "item.coil_spring", weight = 20, min = 1, max = 2 },
			{ itemId = "item.fire_axe", weight = 4, min = 1, max = 1 },
			{ itemId = "item.machete", weight = 4, min = 1, max = 1 },
		},
	},
	["loot.depot_band2"] = {
		id = "loot.depot_band2",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.niter", weight = 20, min = 2, max = 4 },
			{ itemId = "item.scrap", weight = 42, min = 3, max = 6 }, -- was Blackpowder 18, Shells 12, Light Rounds 12 (F-13)
			{ itemId = "item.trigger_group", weight = 14, min = 1, max = 1 },
			{ itemId = "item.steel_pipe", weight = 14, min = 1, max = 2 },
			{ itemId = "item.flare", weight = 10, min = 1, max = 2 },
		},
	},
	["loot.depot_band3"] = {
		id = "loot.depot_band3",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.trigger_group", weight = 20, min = 1, max = 2 },
			{ itemId = "item.coil_spring", weight = 18, min = 1, max = 2 }, -- was Blackpowder (F-13; ARSENAL 3.4)
			{ itemId = "item.steel_pipe", weight = 14, min = 1, max = 1 }, -- was Shells (F-13; ARSENAL 3.4)
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
			{ itemId = "item.scrap", weight = 45, min = 3, max = 6 }, -- was Blackpowder 25 and Light Rounds 20 (F-13)
			{ itemId = "item.flare", weight = 20, min = 1, max = 2 },
			{ itemId = "item.steel_pipe", weight = 20, min = 1, max = 1 },
			{ itemId = "item.trigger_group", weight = 15, min = 1, max = 1 },
		},
	},
	["loot.caravan_band3"] = {
		id = "loot.caravan_band3",
		rolls = { min = 1, max = 2 },
		entries = {
			{ itemId = "item.trigger_group", weight = 25, min = 1, max = 1 },
			{ itemId = "item.steel_pipe", weight = 20, min = 1, max = 2 }, -- was Shells (F-13; ARSENAL 3.4)
			{ itemId = "item.flare", weight = 20, min = 2, max = 3 },
			{ itemId = "item.coil_spring", weight = 20, min = 1, max = 2 }, -- was Blackpowder (F-13; ARSENAL 3.4)
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
			{ itemId = "item.scrap", weight = 10, min = 1, max = 2 }, -- was Blackpowder (F-13)
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

	-- ECONOMY §7.1-7.3: the resource zones' containers (Abandoned Pack, Woodcutter's Crate,
	-- Miner's Box), tier 1-3.
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
			{ itemId = "item.hide", weight = 4, min = 1, max = 1 }, -- leather stays craftable without wildlife
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
			{ itemId = "item.hide", weight = 4, min = 1, max = 2 },
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
			{ itemId = "item.bp_pack_frame", weight = 2, min = 1, max = 1, rarity = "epic" },
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
			{ itemId = "item.scrap", weight = 2, min = 2, max = 4 }, -- was Blackpowder (F-13)
		},
	},
}

return LootTables
