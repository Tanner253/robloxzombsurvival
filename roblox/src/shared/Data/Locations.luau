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
		energyCost = 15,
		walkSeconds = 12 * 60, -- LDOE_PARITY #38: 12/19/29 min by tier
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			-- A loot hub now (ECONOMY §6.3): more containers, fewer nodes than the Forest.
			{ lootTableId = "loot.pine_pack", count = { min = 3, max = 5 }, kind = "pack", searchSeconds = 3 },
			{ lootTableId = "loot.pine_crate", count = { min = 2, max = 3 }, kind = "crate" },
		},
		nodes = {
			{ nodeId = "node.pine_tree", count = 8 },
			{ nodeId = "node.boulder", count = 4 },
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
			-- Wildlife (deer, wolf) returns post-launch with our own rigs (S2B; ECONOMY §6.2 counts).
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
			"item.steel_pipe",
			"item.hide",
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
			quests = {
				{
					id = "quest.pine_hunters_trail",
					name = "The Hunter's Trail",
					-- Two Fog Deer until wildlife returns post-launch: any three Hollow for now.
					description = "Put down three Hollow on the trail through Pine Hollow.",
					objectives = { { kind = "kill", count = 3 } },
					rewards = { xp = 150, items = { { itemId = "item.rations", count = 1 } } },
				},
			},
		},
	},
	["loc.sunken_quarry"] = {
		id = "loc.sunken_quarry", -- the ID predates the map: it is the roadside town of Rustwater
		name = "Rustwater",
		fogTier = 2,
		levelGate = 8,
		energyCost = 22,
		walkSeconds = 19 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			-- The Dense parts town (ECONOMY §6.3): more containers, fewer nodes.
			{ lootTableId = "loot.quarry_toolbox", count = { min = 3, max = 4 }, kind = "cabinet" },
			{ lootTableId = "loot.quarry_toolbox", count = { min = 2, max = 3 }, kind = "trunk" }, -- car boots
			{ lootTableId = "loot.quarry_locker", count = { min = 2, max = 3 }, kind = "locker" },
		},
		nodes = {
			{ nodeId = "node.boulder", count = 6 },
			{ nodeId = "node.scrap_heap", count = 8 },
			{ nodeId = "node.fatwood_stump", count = 4 },
			{ nodeId = "node.pine_tree", count = 4 },
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
			"item.sealed_tin",
			"item.field_dressing",
			"item.seized_motor",
			"item.padded_hood",
			"item.shortbow",
			"item.ember_tonic",
			"item.steel_pipe",
			"item.trigger_group",
			"item.machete",
		},
		run = {
			recommendedGearScore = 90, -- a Scrapblade and a hood
			placeId = 0,
			extraction = {
				kind = "points",
				points = {
					{ id = "north_ramp", name = "North Road" },
					{ id = "conveyor_gate", name = "Highway West" },
					{ id = "flooded_cut", name = "Creek Bridge" },
				},
				closeCount = 1,
			},
			bandLoot = {
				{ band = 2, lootTableId = "loot.quarry_band2" },
				{ band = 3, lootTableId = "loot.quarry_band3" },
			},
			travelBonusTableId = "loot.road_dense",
			quests = {
				{
					id = "quest.quarry_salt_of_stone",
					name = "Cellar Salt",
					description = "Scrape six Niter Crust from the damp cellars of Rustwater.",
					objectives = { { kind = "gather", itemId = "item.niter", count = 6 } },
					rewards = { xp = 300, items = { { itemId = "item.rations", count = 1 } } },
				},
			},
		},
	},
	["loc.ashfall_depot"] = {
		id = "loc.ashfall_depot",
		name = "Ashfall Depot",
		fogTier = 3,
		levelGate = 15,
		energyCost = 33, -- LDOE_PARITY #38: 15/22/33 by tier
		walkSeconds = 29 * 60,
		-- A dungeon-style timer: shorter than a day so a daily player can always re-run it.
		reset = { kind = "timer", seconds = 20 * 60 * 60 },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.depot_freight", count = { min = 5, max = 6 }, kind = "crate" }, -- ECONOMY §6.3
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
			{ nodeId = "node.ironstone_rock", count = 8 }, -- the quarry pit (ECONOMY §6.3)
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
			"item.trigger_group",
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
			quests = {
				{
					id = "quest.depot_signal_in_ash",
					name = "Signal in the Ash",
					description = "Search five containers in the Ashfall Depot and get out alive.",
					objectives = { { kind = "loot", count = 5, locationId = "loc.ashfall_depot" } },
					rewards = { xp = 500, items = { { itemId = "item.rations", count = 2 } } },
				},
			},
		},
	},
	-- The resource zones (ECONOMY §6): nodes first, a few weak containers. Fixed maps.
	-- Forest L1 (LDoE Pine Bushes): pines, branches and reeds; deer to hunt. ECONOMY §6.2.
	["loc.bracken_edge"] = {
		id = "loc.bracken_edge",
		name = "Bracken Edge",
		fogTier = 1,
		levelGate = 1,
		energyCost = 15,
		walkSeconds = 12 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.zone_pack_t1", count = { min = 1, max = 2 }, kind = "pack", searchSeconds = 3 },
			{ lootTableId = "loot.forest_crate_t1", count = { min = 0, max = 1 }, kind = "crate", searchSeconds = 5 },
		},
		nodes = {
			{ nodeId = "node.pine_tree", count = 30 },
			{ nodeId = "node.boulder", count = 3 },
			{ nodeId = "node.fatwood_stump", count = 4 },
			{ nodeId = "node.fallen_branches", count = 12 },
			{ nodeId = "node.loose_stones", count = 12 },
			{ nodeId = "node.reed_patch", count = 20 },
			{ nodeId = "node.ember_bush", count = 10 },
			{ nodeId = "node.ashroot_mound", count = 6 },
			{ nodeId = "node.spring_pool", count = 1 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 5, max = 7 } },
			{ enemyId = "enemy.runner", count = { min = 0, max = 1 } },
			-- Wildlife (deer, wolf) returns post-launch with our own rigs (S2B; ECONOMY §6.2 counts).
		},
		mainLoot = { "item.timber", "item.sticks", "item.fiber", "item.emberberry", "item.fatwood", "item.stone" },
		possibleLoot = {
			"item.plank",
			"item.rope",
			"item.cloth",
			"item.sealed_tin",
			"item.boiled_water",
			"item.field_dressing",
			"item.pitch_glue",
			"item.stone_hatchet",
			"item.coil_spring",
			"item.snarled_wire",
			"item.hide",
		},
		run = {
			recommendedGearScore = 40,
			placeId = 0,
			extraction = { kind = "edge" },
			bandLoot = {
				{ band = 2, lootTableId = "loot.pine_band2" },
			},
			travelBonusTableId = "loot.road_light",
			quests = {
				{
					id = "quest.bracken_kindling",
					name = "Kindling",
					description = "Gather thirty timber in Bracken Edge.",
					objectives = { { kind = "gather", itemId = "item.timber", count = 30 } },
					rewards = { xp = 150, items = { { itemId = "item.rope", count = 2 } } },
				},
			},
		},
	},
	-- Forest L2 (LDoE Pine Grove and Oak Bushes): ironbark for the forged tier. ECONOMY §6.2.
	["loc.ironbark_stand"] = {
		id = "loc.ironbark_stand",
		name = "Ironbark Stand",
		fogTier = 2,
		levelGate = 8,
		energyCost = 22,
		walkSeconds = 19 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.zone_pack_t2", count = { min = 2, max = 2 }, kind = "pack", searchSeconds = 3 },
			{ lootTableId = "loot.forest_crate_t2", count = { min = 1, max = 2 }, kind = "crate", searchSeconds = 5 },
		},
		nodes = {
			{ nodeId = "node.pine_tree", count = 40 },
			{ nodeId = "node.ironbark_tree", count = 15 },
			{ nodeId = "node.boulder", count = 5 },
			{ nodeId = "node.fatwood_stump", count = 6 },
			{ nodeId = "node.fallen_branches", count = 15 },
			{ nodeId = "node.loose_stones", count = 12 },
			{ nodeId = "node.reed_patch", count = 30 },
			{ nodeId = "node.ember_bush", count = 10 },
			{ nodeId = "node.ashroot_mound", count = 6 },
			{ nodeId = "node.spring_pool", count = 1 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 6, max = 8 } },
			{ enemyId = "enemy.runner", count = { min = 3, max = 4 } },
			{ enemyId = "enemy.bloater", count = { min = 1, max = 2 }, minBand = 2 },
			{ enemyId = "enemy.runner", count = { min = 1, max = 2 }, minBand = 2 },
			-- Wildlife (deer, wolf) returns post-launch with our own rigs (S2B; ECONOMY §6.2 counts).
		},
		mainLoot = { "item.timber", "item.ironbark_log", "item.fatwood", "item.fiber", "item.sticks" },
		possibleLoot = {
			"item.plank",
			"item.rivets",
			"item.embercoal",
			"item.iron_ingot",
			"item.coil_spring",
			"item.steel_pipe",
			"item.trigger_group",
			"item.forged_hatchet",
			"item.seized_motor",
			"item.ember_tonic",
		},
		run = {
			recommendedGearScore = 90,
			placeId = 0,
			extraction = {
				kind = "points",
				points = {
					{ id = "logging_road", name = "Logging Road" },
					{ id = "creek_ford", name = "Creek Ford" },
					{ id = "ranger_hut", name = "Ranger Hut" },
				},
				closeCount = 1,
			},
			bandLoot = {
				{ band = 2, lootTableId = "loot.quarry_band2" },
			},
			travelBonusTableId = "loot.road_dense",
			quests = {
				{
					id = "quest.ironbark_hard_grain",
					name = "Hard Grain",
					description = "Fell ironbark in Ironbark Stand: ten logs.",
					objectives = { { kind = "gather", itemId = "item.ironbark_log", count = 10 } },
					rewards = { xp = 300, items = { { itemId = "item.pitch_glue", count = 2 } } },
				},
			},
		},
	},
	-- Forest L3 (LDoE Pine Wood and Oak Grove): old ironbark under black fog. ECONOMY §6.2.
	["loc.gloaming_deep"] = {
		id = "loc.gloaming_deep",
		name = "Gloaming Deep",
		fogTier = 3,
		levelGate = 15,
		energyCost = 33,
		walkSeconds = 29 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.zone_pack_t3", count = { min = 2, max = 3 }, kind = "pack", searchSeconds = 3 },
			{ lootTableId = "loot.forest_crate_t3", count = { min = 2, max = 2 }, kind = "crate", searchSeconds = 5 },
		},
		nodes = {
			{ nodeId = "node.pine_tree", count = 50 },
			{ nodeId = "node.ironbark_tree", count = 25 },
			{ nodeId = "node.boulder", count = 5 },
			{ nodeId = "node.fatwood_stump", count = 10 },
			{ nodeId = "node.fallen_branches", count = 20 },
			{ nodeId = "node.loose_stones", count = 10 },
			{ nodeId = "node.reed_patch", count = 40 },
			{ nodeId = "node.ember_bush", count = 10 },
			{ nodeId = "node.ashroot_mound", count = 6 },
			{ nodeId = "node.spring_pool", count = 1 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 8, max = 10 } },
			{ enemyId = "enemy.runner", count = { min = 5, max = 7 } },
			{ enemyId = "enemy.bloater", count = { min = 2, max = 3 } },
			{ enemyId = "enemy.runner", count = { min = 2, max = 3 }, minBand = 3 },
			-- Wildlife (deer, wolf) returns post-launch with our own rigs (S2B; ECONOMY §6.2 counts).
		},
		mainLoot = { "item.ironbark_log", "item.timber", "item.fatwood", "item.fiber", "item.pitch_glue" },
		possibleLoot = {
			"item.ironbark_plank",
			"item.rivets",
			"item.embercoal",
			"item.scrap_plate",
			"item.coil_spring",
			"item.brass_gear",
			"item.steel_pipe",
			"item.trigger_group",
			"item.forged_hatchet",
			"item.bp_pack_frame",
			"item.hearth_stew",
		},
		run = {
			recommendedGearScore = 140,
			placeId = 0,
			extraction = {
				kind = "points",
				points = {
					{ id = "old_trail", name = "Old Trail" },
					{ id = "fire_lookout", name = "Fire Lookout" },
					{ id = "burnt_bridge", name = "Burnt Bridge" },
				},
				closeCount = 1,
				flare = true,
			},
			bandLoot = {
				{ band = 2, lootTableId = "loot.depot_band2" },
			},
			travelBonusTableId = "loot.road_black",
			quests = {
				{
					id = "quest.gloaming_into_the_gloam",
					name = "Into the Gloam",
					-- ECONOMY §6.2 says five, but the Deep holds only 4-5 contested containers and
					-- quest progress is per run: three keeps it doable (QA; flagged to the orchestrator).
					description = "Search three containers in Gloaming Deep.",
					objectives = { { kind = "loot", count = 3, locationId = "loc.gloaming_deep" } },
					rewards = { xp = 500, items = { { itemId = "item.coil_spring", count = 1 } } },
				},
			},
		},
	},
	-- Mine L1 (LDoE Limestone Ridge): fieldstone and the first ironstone. ECONOMY §6.2.
	["loc.rockfall_slope"] = {
		id = "loc.rockfall_slope",
		name = "Rockfall Slope",
		fogTier = 1,
		levelGate = 1,
		energyCost = 15,
		walkSeconds = 12 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.zone_pack_t1", count = { min = 1, max = 2 }, kind = "pack", searchSeconds = 3 },
			{ lootTableId = "loot.mine_box_t1", count = { min = 0, max = 1 }, kind = "crate", searchSeconds = 5 },
		},
		nodes = {
			{ nodeId = "node.boulder", count = 25 },
			{ nodeId = "node.ironstone_rock", count = 5 },
			{ nodeId = "node.scrap_heap", count = 3 },
			{ nodeId = "node.pine_tree", count = 10 },
			{ nodeId = "node.fallen_branches", count = 8 },
			{ nodeId = "node.loose_stones", count = 20 },
			{ nodeId = "node.reed_patch", count = 20 },
			{ nodeId = "node.ember_bush", count = 10 },
			{ nodeId = "node.spring_pool", count = 1 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 5, max = 7 } },
			{ enemyId = "enemy.runner", count = { min = 1, max = 2 } },
			-- Wildlife (deer, wolf) returns post-launch with our own rigs (S2B; ECONOMY §6.2 counts).
		},
		mainLoot = { "item.stone", "item.ironstone", "item.scrap", "item.timber", "item.fiber" },
		possibleLoot = {
			"item.iron_ingot",
			"item.rivets",
			"item.pitch_glue",
			"item.stone_pick",
			"item.rope",
			"item.coil_spring",
			"item.broken_lantern",
			"item.snarled_wire",
			"item.seized_motor",
		},
		run = {
			recommendedGearScore = 40,
			placeId = 0,
			extraction = { kind = "edge" },
			bandLoot = {
				{ band = 2, lootTableId = "loot.pine_band2" },
			},
			travelBonusTableId = "loot.road_light",
			quests = {
				{
					id = "quest.rockfall_loose_rock",
					name = "Loose Rock",
					description = "Break thirty fieldstone on Rockfall Slope.",
					objectives = { { kind = "gather", itemId = "item.stone", count = 30 } },
					rewards = { xp = 150, items = { { itemId = "item.scrap", count = 4 } } },
				},
			},
		},
	},
	-- Mine L2 (LDoE Limestone Cliffs and Frosty Backwoods): ironstone walls, malachite seams. ECONOMY §6.2.
	["loc.greenvein_bluffs"] = {
		id = "loc.greenvein_bluffs",
		name = "Greenvein Bluffs",
		fogTier = 2,
		levelGate = 8,
		energyCost = 22,
		walkSeconds = 19 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.zone_pack_t2", count = { min = 2, max = 2 }, kind = "pack", searchSeconds = 3 },
			{ lootTableId = "loot.mine_box_t2", count = { min = 1, max = 2 }, kind = "crate", searchSeconds = 5 },
		},
		nodes = {
			{ nodeId = "node.boulder", count = 20 },
			{ nodeId = "node.ironstone_rock", count = 30 },
			{ nodeId = "node.malachite_vein", count = 10 },
			{ nodeId = "node.scrap_heap", count = 4 },
			{ nodeId = "node.niter_seam", count = 4 },
			{ nodeId = "node.pine_tree", count = 13 },
			{ nodeId = "node.fallen_branches", count = 10 },
			{ nodeId = "node.loose_stones", count = 15 },
			{ nodeId = "node.reed_patch", count = 30 },
			{ nodeId = "node.ember_bush", count = 10 },
			{ nodeId = "node.spring_pool", count = 1 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 6, max = 8 } },
			{ enemyId = "enemy.runner", count = { min = 3, max = 5 } },
			{ enemyId = "enemy.bloater", count = { min = 1, max = 2 }, minBand = 2 },
		},
		mainLoot = { "item.ironstone", "item.stone", "item.malachite", "item.scrap", "item.niter" },
		possibleLoot = {
			"item.iron_ingot",
			"item.stone_block",
			"item.rivets",
			"item.copper_ingot",
			"item.coil_spring",
			"item.brass_gear",
			"item.forged_pick",
			"item.steel_pipe",
			"item.trigger_group",
		},
		run = {
			recommendedGearScore = 90,
			placeId = 0,
			extraction = {
				kind = "points",
				points = {
					{ id = "haul_road", name = "Haul Road" },
					{ id = "ore_chute", name = "Ore Chute" },
					{ id = "switchback", name = "Switchback" },
				},
				closeCount = 1,
			},
			bandLoot = {
				{ band = 2, lootTableId = "loot.quarry_band2" },
			},
			travelBonusTableId = "loot.road_dense",
			quests = {
				{
					id = "quest.greenvein_green_seam",
					name = "Green Seam",
					description = "Cut six malachite from the Greenvein Bluffs.",
					objectives = { { kind = "gather", itemId = "item.malachite", count = 6 } },
					rewards = { xp = 300, items = { { itemId = "item.embercoal", count = 4 } } },
				},
			},
		},
	},
	-- Mine L3 (LDoE Limestone Spires): the deepest ore under black fog. ECONOMY §6.2.
	["loc.deepcut_pit"] = {
		id = "loc.deepcut_pit",
		name = "Deepcut Pit",
		fogTier = 3,
		levelGate = 15,
		energyCost = 33,
		walkSeconds = 29 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "always" },
		containers = {
			{ lootTableId = "loot.zone_pack_t3", count = { min = 2, max = 3 }, kind = "pack", searchSeconds = 3 },
			{ lootTableId = "loot.mine_box_t3", count = { min = 2, max = 2 }, kind = "crate", searchSeconds = 5 },
		},
		nodes = {
			{ nodeId = "node.boulder", count = 45 },
			{ nodeId = "node.ironstone_rock", count = 50 },
			{ nodeId = "node.malachite_vein", count = 20 },
			{ nodeId = "node.scrap_heap", count = 6 },
			{ nodeId = "node.niter_seam", count = 6 },
			{ nodeId = "node.pine_tree", count = 20 },
			{ nodeId = "node.fallen_branches", count = 10 },
			{ nodeId = "node.loose_stones", count = 22 },
			{ nodeId = "node.reed_patch", count = 40 },
			{ nodeId = "node.ember_bush", count = 10 },
			{ nodeId = "node.spring_pool", count = 1 },
		},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 8, max = 12 } },
			{ enemyId = "enemy.runner", count = { min = 5, max = 7 } },
			{ enemyId = "enemy.bloater", count = { min = 2, max = 3 } },
			{ enemyId = "enemy.runner", count = { min = 2, max = 3 }, minBand = 3 },
		},
		mainLoot = { "item.ironstone", "item.malachite", "item.stone", "item.scrap", "item.niter" },
		possibleLoot = {
			"item.scrap_plate",
			"item.iron_ingot",
			"item.copper_ingot",
			"item.copper_wire",
			"item.rivets",
			"item.coil_spring",
			"item.brass_gear",
			"item.forged_pick",
			"item.steel_pipe",
			"item.trigger_group",
		},
		run = {
			recommendedGearScore = 140,
			placeId = 0,
			extraction = {
				kind = "points",
				points = {
					{ id = "pit_ramp", name = "Pit Ramp" },
					{ id = "conveyor_head", name = "Conveyor Head" },
					{ id = "spoil_heap", name = "Spoil Heap" },
				},
				closeCount = 1,
				flare = true,
			},
			bandLoot = {
				{ band = 2, lootTableId = "loot.depot_band2" },
			},
			travelBonusTableId = "loot.road_black",
			quests = {
				{
					id = "quest.deepcut_bottom_of_pit",
					name = "Bottom of the Pit",
					description = "Dig twenty ironstone out of Deepcut Pit.",
					objectives = { { kind = "gather", itemId = "item.ironstone", count = 20 } },
					rewards = { xp = 500, items = { { itemId = "item.brass_gear", count = 1 } } },
				},
			},
		},
	},
	["loc.stranded_caravan"] = {
		id = "loc.stranded_caravan",
		name = "Stranded Caravan",
		fogTier = 2,
		levelGate = 8,
		energyCost = 22,
		walkSeconds = 19 * 60,
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
			{ nodeId = "node.pine_tree", count = 6 },
			{ nodeId = "node.reed_patch", count = 4 },
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
			quests = {
				{
					id = "quest.caravan_salvage",
					name = "What the Wagons Carried",
					description = "Search four wagons of the Stranded Caravan before the Fog takes it.",
					objectives = { { kind = "loot", count = 4, locationId = "loc.stranded_caravan" } },
					rewards = { xp = 400, items = { { itemId = "item.rations", count = 1 } } },
				},
			},
		},
	},
	-- The airdrop (LDOE_PARITY #43): a guarded crate that lands as your Energy falls past
	-- 140, 80 and 20. Its pin stays two hours; the trip is a short, cheap Light run.
	["loc.supply_drop"] = {
		id = "loc.supply_drop",
		name = "Supply Drop",
		fogTier = 1,
		levelGate = 1,
		energyCost = 10,
		walkSeconds = 8 * 60,
		reset = { kind = "onExit" },
		availability = { kind = "airdrop" },
		containers = {
			{ lootTableId = "loot.airdrop_crate", count = { min = 1, max = 1 }, kind = "strongbox", searchSeconds = 8 },
		},
		nodes = {},
		enemySpawns = {
			{ enemyId = "enemy.shambler", count = { min = 4, max = 6 } },
			{ enemyId = "enemy.runner", count = { min = 1, max = 2 } },
			{ enemyId = "enemy.bloater", count = { min = 1, max = 1 } },
		},
		mainLoot = { "item.rations", "item.sealed_tin", "item.field_dressing" },
		possibleLoot = { "item.ember_tonic", "item.steel_pipe", "item.trigger_group" },
		run = {
			recommendedGearScore = 60,
			placeId = 0,
			extraction = { kind = "edge" },
			bandLoot = {},
			travelBonusTableId = "loot.road_light",
			quests = {},
		},
	},
}

return Locations
