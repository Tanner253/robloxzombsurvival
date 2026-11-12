--!strict
--[[
	Recipe definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.

	Hand recipes (no stationId) are the crafting catalogue: every tool, weapon, armor piece,
	bag, food mix and Signal Flare is made by hand (LDOE_PARITY #20). Station recipes are
	converter lines (#18): one input stack -> one output stack, one batch per craftSeconds.

	Economy (docs/ECONOMY.md §2, binding): every refinement is LDoE's ratio and timer or
	harsher. 2 timber make a plank, 5 Ironbark Logs an Ironbark Plank, 3 stone a block;
	ore or scrap smelts to Iron Ingots, an ingot is hammered into a Scrap Plate (20 min),
	a plate cuts to 2 rivets. Tier-2 lines need a level 2 station (stationLevel). Worn gear
	is re-crafted from these recipes (§8.2): the rare parts in them are the sink.

	Unlocks (#49): only the hatchet, pick, satchel (and the cord it needs) start unlocked.
	Everything else unlocks by completing an Ember Trail quest (Data/Quests), or by reading
	a found schematic. Repair doesn't exist yet: worn gear is re-crafted (#21).
]]

local Types = require("../Types")

local function quest(questId: string): Types.UnlockGate
	return { kind = "quest", questId = questId }
end

-- Every line sits on its own station (ECONOMY §10.1: the Smelter and Stonecutter are launch
-- requirements). While one of their models still waits for its A grade, Tuning.stationFallback
-- moves its lines (Shared/StationFallback): ingots to the Campfire, blocks to the Saw Bench.

local Recipes: { [Types.RecipeId]: Types.RecipeDef } = {
	-- Hand-crafted: the starter set ----------------------------------------------------
	["recipe.stone_hatchet"] = {
		id = "recipe.stone_hatchet",
		inputs = {
			{ itemId = "item.sticks", count = 3 },
			{ itemId = "item.stone", count = 3 },
		},
		outputs = { { itemId = "item.stone_hatchet", count = 1 } },
		craftSeconds = 5,
		unlock = { kind = "default" },
	},
	["recipe.stone_pick"] = {
		id = "recipe.stone_pick",
		inputs = {
			{ itemId = "item.sticks", count = 3 },
			{ itemId = "item.stone", count = 3 },
		},
		outputs = { { itemId = "item.stone_pick", count = 1 } },
		craftSeconds = 5,
		unlock = { kind = "default" },
	},
	["recipe.rope"] = {
		id = "recipe.rope",
		inputs = { { itemId = "item.fiber", count = 2 } },
		outputs = { { itemId = "item.rope", count = 1 } },
		craftSeconds = 3,
		unlock = { kind = "default" },
	},
	["recipe.satchel"] = {
		id = "recipe.satchel",
		inputs = {
			{ itemId = "item.rope", count = 2 },
			{ itemId = "item.fiber", count = 3 },
		},
		outputs = { { itemId = "item.satchel", count = 1 } },
		craftSeconds = 10,
		unlock = { kind = "default" },
	},

	-- Hand-crafted: unlocked along the Ember Trail ---------------------------------------
	["recipe.field_dressing"] = {
		id = "recipe.field_dressing",
		inputs = { { itemId = "item.cloth", count = 5 } }, -- LDoE's bandage: 5 cloth (ECONOMY §8.2)
		outputs = { { itemId = "item.field_dressing", count = 1 } },
		craftSeconds = 5,
		unlock = quest("quest.keep_the_fire"),
	},
	["recipe.spiked_club"] = {
		id = "recipe.spiked_club",
		inputs = {
			{ itemId = "item.plank", count = 4 },
			{ itemId = "item.rope", count = 2 },
			{ itemId = "item.scrap", count = 3 },
		},
		outputs = { { itemId = "item.spiked_club", count = 1 } },
		craftSeconds = 10,
		unlock = quest("quest.into_the_fog"),
	},
	["recipe.padded_hood"] = {
		id = "recipe.padded_hood",
		inputs = {
			{ itemId = "item.cloth", count = 4 },
			{ itemId = "item.rope", count = 2 },
		},
		outputs = { { itemId = "item.padded_hood", count = 1 } },
		craftSeconds = 10,
		unlock = quest("quest.hold_the_door"),
	},
	["recipe.hearth_stew"] = {
		id = "recipe.hearth_stew",
		inputs = {
			{ itemId = "item.roasted_ashroot", count = 2 },
			{ itemId = "item.emberberry", count = 3 },
			{ itemId = "item.boiled_water", count = 1 },
		},
		outputs = { { itemId = "item.hearth_stew", count = 1 } },
		craftSeconds = 5,
		unlock = quest("quest.hold_the_door"),
	},
	["recipe.shortbow"] = {
		id = "recipe.shortbow",
		inputs = {
			{ itemId = "item.plank", count = 4 },
			{ itemId = "item.rope", count = 4 },
			{ itemId = "item.pitch_glue", count = 2 }, -- ECONOMY §8.2 (was 1)
		},
		outputs = { { itemId = "item.shortbow", count = 1 } },
		craftSeconds = 10,
		unlock = quest("quest.stand_your_ground"),
	},
	["recipe.padded_vest"] = {
		id = "recipe.padded_vest",
		inputs = {
			{ itemId = "item.cloth", count = 6 },
			{ itemId = "item.rope", count = 3 },
			{ itemId = "item.scrap_plate", count = 2 },
			{ itemId = "item.pitch_glue", count = 1 }, -- ECONOMY §8.2
		},
		outputs = { { itemId = "item.padded_vest", count = 1 } },
		craftSeconds = 10,
		unlock = quest("quest.stand_your_ground"),
	},
	["recipe.scrapblade"] = {
		id = "recipe.scrapblade",
		inputs = {
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.plank", count = 2 },
			{ itemId = "item.cloth", count = 2 },
			{ itemId = "item.rivets", count = 2 },
			{ itemId = "item.pitch_glue", count = 1 }, -- ECONOMY §8.2
		},
		outputs = { { itemId = "item.scrapblade", count = 1 } },
		craftSeconds = 10,
		unlock = quest("quest.scavenger"),
	},
	["recipe.pack_frame"] = {
		id = "recipe.pack_frame",
		inputs = {
			{ itemId = "item.cloth", count = 6 },
			{ itemId = "item.rope", count = 6 },
			{ itemId = "item.scrap_plate", count = 3 },
			{ itemId = "item.rivets", count = 2 },
			{ itemId = "item.brass_gear", count = 1 },
		},
		outputs = { { itemId = "item.pack_frame", count = 1 } },
		craftSeconds = 15,
		unlock = { kind = "blueprint", itemId = "item.bp_pack_frame" },
	},
	-- Forged tools (ECONOMY §4.1): LDoE's Iron Hatchet and Iron Pickaxe, unlocked with the
	-- Dense fog as LDoE's "Limestone Cliffs" quest unlocks the iron tools.
	["recipe.forged_hatchet"] = {
		id = "recipe.forged_hatchet",
		inputs = {
			{ itemId = "item.iron_ingot", count = 5 },
			{ itemId = "item.plank", count = 3 },
			{ itemId = "item.rivets", count = 2 },
			{ itemId = "item.pitch_glue", count = 2 },
		},
		outputs = { { itemId = "item.forged_hatchet", count = 1 } },
		craftSeconds = 10,
		unlock = quest("quest.the_dense_fog"),
	},
	["recipe.forged_pick"] = {
		id = "recipe.forged_pick",
		inputs = {
			{ itemId = "item.iron_ingot", count = 5 },
			{ itemId = "item.plank", count = 3 },
			{ itemId = "item.rivets", count = 2 },
			{ itemId = "item.pitch_glue", count = 2 },
		},
		outputs = { { itemId = "item.forged_pick", count = 1 } },
		craftSeconds = 10,
		unlock = quest("quest.the_dense_fog"),
	},

	-- Saw Bench (station.woodworking_bench) ------------------------------------------------------
	["recipe.plank"] = {
		id = "recipe.plank",
		inputs = { { itemId = "item.timber", count = 2 } }, -- LDoE 1 -> 1: 2x harsher
		outputs = { { itemId = "item.plank", count = 1 } },
		stationId = "station.woodworking_bench",
		craftSeconds = 4 * 60,
		unlock = quest("quest.claim_the_ground"),
	},
	["recipe.ironbark_plank"] = {
		id = "recipe.ironbark_plank",
		-- LDoE 3 oak -> 1 in 20 min. A full level 1 slot (20 logs) is the developer's "20 logs
		-- turns into 4 planks"; the line needs a level 2 bench.
		inputs = { { itemId = "item.ironbark_log", count = 5 } },
		outputs = { { itemId = "item.ironbark_plank", count = 1 } },
		stationId = "station.woodworking_bench",
		stationLevel = 2,
		craftSeconds = 20 * 60,
		unlock = quest("quest.heartwood"),
	},

	-- Stonecutter -----------------------------------------------------------------------------
	["recipe.stone_block"] = {
		id = "recipe.stone_block",
		inputs = { { itemId = "item.stone", count = 3 } }, -- LDoE 2 -> 1 in 4 min
		outputs = { { itemId = "item.stone_block", count = 1 } },
		stationId = "station.stonecutter",
		craftSeconds = 5 * 60,
		unlock = quest("quest.a_place_to_work"),
	},

	-- Smelter (fuelled) -----------------------------------------------------------------------
	["recipe.iron_ingot"] = {
		id = "recipe.iron_ingot",
		inputs = { { itemId = "item.ironstone", count = 2 } }, -- LDoE's iron bar: equal
		outputs = { { itemId = "item.iron_ingot", count = 1 } },
		stationId = "station.smelter",
		craftSeconds = 4 * 60,
		unlock = quest("quest.into_the_fog"),
	},
	["recipe.iron_ingot_from_scrap"] = {
		id = "recipe.iron_ingot_from_scrap",
		inputs = { { itemId = "item.scrap", count = 5 } }, -- LDoE 4 scrap: mining ore pays better
		outputs = { { itemId = "item.iron_ingot", count = 1 } },
		stationId = "station.smelter",
		craftSeconds = 4 * 60,
		unlock = quest("quest.into_the_fog"),
	},
	["recipe.copper_ingot"] = {
		id = "recipe.copper_ingot",
		inputs = { { itemId = "item.malachite", count = 5 } }, -- LDoE's copper bar: 5 ore, 1 h
		outputs = { { itemId = "item.copper_ingot", count = 1 } },
		stationId = "station.smelter",
		stationLevel = 2,
		craftSeconds = 60 * 60,
		unlock = quest("quest.green_vein"),
	},

	-- Workbench: plates and parts ---------------------------------------------------------------
	["recipe.scrap_plate"] = {
		id = "recipe.scrap_plate",
		inputs = { { itemId = "item.iron_ingot", count = 1 } }, -- LDoE's iron plate: 1 bar, 20 min
		outputs = { { itemId = "item.scrap_plate", count = 1 } },
		stationId = "station.workbench",
		craftSeconds = 20 * 60,
		unlock = quest("quest.into_the_fog"),
	},
	["recipe.copper_wire"] = {
		id = "recipe.copper_wire",
		inputs = { { itemId = "item.copper_ingot", count = 1 } },
		outputs = { { itemId = "item.copper_wire", count = 2 } },
		stationId = "station.workbench",
		stationLevel = 2,
		craftSeconds = 10 * 60,
		unlock = quest("quest.green_vein"),
	},
	["recipe.cloth"] = {
		id = "recipe.cloth",
		inputs = { { itemId = "item.fiber", count = 2 } },
		outputs = { { itemId = "item.cloth", count = 1 } },
		stationId = "station.workbench",
		craftSeconds = 2 * 60,
		unlock = quest("quest.keep_the_fire"),
	},
	["recipe.rivets"] = {
		id = "recipe.rivets",
		inputs = { { itemId = "item.scrap_plate", count = 1 } },
		outputs = { { itemId = "item.rivets", count = 2 } },
		stationId = "station.workbench",
		craftSeconds = 4 * 60,
		unlock = quest("quest.hold_the_door"),
	},

	-- Campfire (fuelled): cooking first, then coal and glue ------------------------------------
	["recipe.boiled_water"] = {
		id = "recipe.boiled_water",
		inputs = { { itemId = "item.murky_water", count = 1 } },
		outputs = { { itemId = "item.boiled_water", count = 1 } },
		stationId = "station.campfire",
		craftSeconds = 2 * 60,
		unlock = quest("quest.tools_of_survival"),
	},
	["recipe.roasted_ashroot"] = {
		id = "recipe.roasted_ashroot",
		inputs = { { itemId = "item.ashroot", count = 1 } },
		outputs = { { itemId = "item.roasted_ashroot", count = 1 } },
		stationId = "station.campfire",
		craftSeconds = 2 * 60,
		unlock = quest("quest.tools_of_survival"),
	},
	["recipe.ember_tea"] = {
		id = "recipe.ember_tea",
		inputs = { { itemId = "item.emberberry", count = 3 } },
		outputs = { { itemId = "item.ember_tea", count = 1 } },
		stationId = "station.campfire",
		craftSeconds = 2 * 60,
		unlock = quest("quest.keep_the_fire"),
	},
	["recipe.pitch_glue"] = {
		id = "recipe.pitch_glue",
		inputs = { { itemId = "item.fatwood", count = 2 } },
		outputs = { { itemId = "item.pitch_glue", count = 1 } },
		stationId = "station.campfire",
		craftSeconds = 4 * 60,
		unlock = quest("quest.keep_the_fire"),
	},
	["recipe.embercoal"] = {
		id = "recipe.embercoal",
		-- LDoE's charcoal is 1 log; ours is 2. Coal loses burn-minutes but packs a 20-item fuel
		-- slot 2.7x longer than timber: long smelts need it (ECONOMY §2.2).
		inputs = { { itemId = "item.timber", count = 2 } },
		outputs = { { itemId = "item.embercoal", count = 1 } },
		stationId = "station.campfire",
		craftSeconds = 4 * 60,
		unlock = quest("quest.keep_the_fire"),
	},

	-- Fog Runs (slice 2): hidden until Tuning.features.fogRuns ----------------------------
	-- Pacing (GAME_DESIGN free-player targets, about 2-3 h a day): level 10 and Workbench
	-- level 2 arrive on day 2; the Trigger Group (Dense/Black, late in a run) is the wait.
	-- That puts the Pipe Pistol on day 3, the Flare Pistol on day 4 and the Shotgun on days
	-- 4-5: "the first firearm, days 3-5". A paying player buys parts and gets there day 1.
	["recipe.machete"] = {
		id = "recipe.machete",
		inputs = {
			{ itemId = "item.scrap_plate", count = 5 },
			{ itemId = "item.rivets", count = 3 },
			{ itemId = "item.cloth", count = 2 },
			{ itemId = "item.pitch_glue", count = 1 }, -- ECONOMY §8.2
		},
		outputs = { { itemId = "item.machete", count = 1 } },
		craftSeconds = 10 * 60,
		unlock = quest("quest.the_dense_fog"), -- was level 10: recipes unlock on the Ember Trail (LDOE_PARITY #49)
		feature = "fogRuns",
	},
	["recipe.fire_axe"] = {
		id = "recipe.fire_axe",
		inputs = {
			{ itemId = "item.scrap_plate", count = 6 },
			{ itemId = "item.plank", count = 3 },
			{ itemId = "item.rivets", count = 4 },
			{ itemId = "item.steel_pipe", count = 1 },
		},
		outputs = { { itemId = "item.fire_axe", count = 1 } },
		craftSeconds = 15 * 60,
		unlock = quest("quest.the_dense_fog"), -- was level 12: recipes unlock on the Ember Trail (LDOE_PARITY #49)
		feature = "fogRuns",
	},
	["recipe.pipe_pistol"] = {
		id = "recipe.pipe_pistol",
		inputs = {
			{ itemId = "item.steel_pipe", count = 1 },
			{ itemId = "item.trigger_group", count = 1 },
			{ itemId = "item.plank", count = 2 },
			{ itemId = "item.rivets", count = 4 },
			{ itemId = "item.coil_spring", count = 1 },
		},
		outputs = { { itemId = "item.pipe_pistol", count = 1 } },
		craftSeconds = 20 * 60,
		unlock = quest("quest.the_dense_fog"), -- was level 11: recipes unlock on the Ember Trail (LDOE_PARITY #49)
		feature = "fogRuns",
	},
	["recipe.flare_pistol"] = {
		id = "recipe.flare_pistol",
		inputs = {
			{ itemId = "item.steel_pipe", count = 1 },
			{ itemId = "item.trigger_group", count = 1 },
			{ itemId = "item.scrap_plate", count = 3 },
			{ itemId = "item.pitch_glue", count = 2 },
		},
		outputs = { { itemId = "item.flare_pistol", count = 1 } },
		craftSeconds = 20 * 60,
		unlock = quest("quest.the_dense_fog"), -- was level 12: recipes unlock on the Ember Trail (LDOE_PARITY #49)
		feature = "fogRuns",
	},
	["recipe.scrap_shotgun"] = {
		id = "recipe.scrap_shotgun",
		inputs = {
			{ itemId = "item.steel_pipe", count = 2 },
			{ itemId = "item.trigger_group", count = 2 },
			{ itemId = "item.plank", count = 4 },
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.rivets", count = 6 },
		},
		outputs = { { itemId = "item.scrap_shotgun", count = 1 } },
		craftSeconds = 45 * 60,
		unlock = quest("quest.the_dense_fog"), -- was level 14: recipes unlock on the Ember Trail (LDOE_PARITY #49)
		feature = "fogRuns",
	},
	-- Standard guns (ARSENAL §3.3): one per chapter-3 quest. Copper Wire and the Trigger Group
	-- are the throttle.
	["recipe.duty_pistol"] = {
		id = "recipe.duty_pistol",
		inputs = {
			{ itemId = "item.steel_pipe", count = 1 },
			{ itemId = "item.trigger_group", count = 1 },
			{ itemId = "item.scrap_plate", count = 3 },
			{ itemId = "item.rivets", count = 4 },
			{ itemId = "item.coil_spring", count = 2 },
			{ itemId = "item.copper_wire", count = 2 },
			{ itemId = "item.pitch_glue", count = 1 },
		},
		outputs = { { itemId = "item.duty_pistol", count = 1 } },
		craftSeconds = 30 * 60,
		unlock = quest("quest.into_the_black"),
		feature = "fogRuns",
	},
	["recipe.pump_shotgun"] = {
		id = "recipe.pump_shotgun",
		inputs = {
			{ itemId = "item.steel_pipe", count = 2 },
			{ itemId = "item.trigger_group", count = 2 },
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.ironbark_plank", count = 3 },
			{ itemId = "item.rivets", count = 6 },
			{ itemId = "item.coil_spring", count = 2 },
			{ itemId = "item.copper_wire", count = 2 },
		},
		outputs = { { itemId = "item.pump_shotgun", count = 1 } },
		craftSeconds = 60 * 60,
		unlock = quest("quest.the_plans"),
		feature = "fogRuns",
	},
	["recipe.hunting_rifle"] = {
		id = "recipe.hunting_rifle",
		inputs = {
			{ itemId = "item.steel_pipe", count = 2 },
			{ itemId = "item.trigger_group", count = 1 },
			{ itemId = "item.brass_gear", count = 1 },
			{ itemId = "item.ironbark_plank", count = 4 },
			{ itemId = "item.scrap_plate", count = 3 },
			{ itemId = "item.rivets", count = 4 },
			{ itemId = "item.copper_wire", count = 2 },
			{ itemId = "item.leather", count = 1 },
		},
		outputs = { { itemId = "item.hunting_rifle", count = 1 } },
		craftSeconds = 60 * 60,
		unlock = quest("quest.copper_lines"),
		feature = "fogRuns",
	},
	-- Advanced: learned from a schematic found in Black fog (the Pack Frame Schematic pattern).
	-- The Anti-Materiel Rifle has no recipe: it is loot only.
	["recipe.assault_rifle"] = {
		id = "recipe.assault_rifle",
		inputs = {
			{ itemId = "item.steel_pipe", count = 2 },
			{ itemId = "item.trigger_group", count = 3 },
			{ itemId = "item.brass_gear", count = 2 },
			{ itemId = "item.scrap_plate", count = 6 },
			{ itemId = "item.rivets", count = 8 },
			{ itemId = "item.copper_wire", count = 4 },
			{ itemId = "item.coil_spring", count = 3 },
			{ itemId = "item.ironbark_plank", count = 3 },
		},
		outputs = { { itemId = "item.assault_rifle", count = 1 } },
		craftSeconds = 2 * 60 * 60,
		-- No feature tag (as the Pack Frame): its schematic must always have a recipe to unlock.
		unlock = { kind = "blueprint", itemId = "item.bp_assault_rifle" },
	},

	-- Guns and the bow run on durability alone (DECISIONS 2026-11-08): there are no rounds and
	-- no press to make them. The Signal Flare stays: it is what the Black-fog flare extract burns, not a
	-- round. It keeps its raw cost (2 niter a flare) now that Blackpowder is gone.
	["recipe.flare"] = {
		id = "recipe.flare",
		inputs = {
			{ itemId = "item.niter", count = 4 },
			{ itemId = "item.pitch_glue", count = 1 },
			{ itemId = "item.cloth", count = 1 },
		},
		outputs = { { itemId = "item.flare", count = 2 } },
		craftSeconds = 10,
		unlock = quest("quest.the_dense_fog"), -- was level 12: recipes unlock on the Ember Trail (LDOE_PARITY #49)
		feature = "fogRuns",
	},

	-- LDoE parity (slice 2): wildlife and the respawn mat ---------------------------------------
	["recipe.cooked_meat"] = {
		id = "recipe.cooked_meat",
		inputs = { { itemId = "item.raw_meat", count = 2 } },
		outputs = { { itemId = "item.cooked_meat", count = 2 } },
		stationId = "station.campfire",
		craftSeconds = 3 * 60,
		unlock = { kind = "default" },
		feature = "fogRuns",
	},
	["recipe.leather"] = {
		id = "recipe.leather",
		inputs = { { itemId = "item.hide", count = 3 } },
		outputs = { { itemId = "item.leather", count = 2 } },
		stationId = "station.workbench",
		craftSeconds = 8 * 60,
		unlock = quest("quest.scavenger"), -- was level 4: recipes unlock on the Ember Trail (LDOE_PARITY #49)
		feature = "fogRuns",
	},
	["recipe.doormat"] = {
		id = "recipe.doormat",
		inputs = {
			{ itemId = "item.fiber", count = 8 },
			{ itemId = "item.rope", count = 2 },
		},
		outputs = { { itemId = "item.doormat", count = 1 } },
		craftSeconds = 10,
		unlock = quest("quest.scavenger"), -- was level 3: recipes unlock on the Ember Trail (LDOE_PARITY #49)
		feature = "fogRuns",
	},
	-- Launch content (docs/research/ldoe-mvp-parity-content.md LB-1, LB-2, LB-5) ----------
	-- The Reedweave set opens with the fire line; the Padded legs and boots with leather.
	["recipe.reedweave_cap"] = {
		id = "recipe.reedweave_cap",
		inputs = {
			{ itemId = "item.fiber", count = 3 },
			{ itemId = "item.cloth", count = 1 },
		},
		outputs = { { itemId = "item.reedweave_cap", count = 1 } },
		craftSeconds = 8,
		unlock = quest("quest.keep_the_fire"),
	},
	["recipe.reedweave_shirt"] = {
		id = "recipe.reedweave_shirt",
		inputs = {
			{ itemId = "item.fiber", count = 4 },
			{ itemId = "item.cloth", count = 3 },
		},
		outputs = { { itemId = "item.reedweave_shirt", count = 1 } },
		craftSeconds = 8,
		unlock = quest("quest.keep_the_fire"),
	},
	["recipe.reedweave_trousers"] = {
		id = "recipe.reedweave_trousers",
		inputs = {
			{ itemId = "item.fiber", count = 4 },
			{ itemId = "item.cloth", count = 3 },
			{ itemId = "item.rope", count = 2 },
		},
		outputs = { { itemId = "item.reedweave_trousers", count = 1 } },
		craftSeconds = 8,
		unlock = quest("quest.keep_the_fire"),
	},
	["recipe.reedweave_wraps"] = {
		id = "recipe.reedweave_wraps",
		inputs = {
			{ itemId = "item.fiber", count = 3 },
			{ itemId = "item.cloth", count = 2 },
			{ itemId = "item.rope", count = 2 },
		},
		outputs = { { itemId = "item.reedweave_wraps", count = 1 } },
		craftSeconds = 8,
		unlock = quest("quest.keep_the_fire"),
	},
	["recipe.padded_leggings"] = {
		id = "recipe.padded_leggings",
		inputs = {
			{ itemId = "item.cloth", count = 4 },
			{ itemId = "item.leather", count = 2 },
			{ itemId = "item.rope", count = 2 },
			{ itemId = "item.pitch_glue", count = 1 },
		},
		outputs = { { itemId = "item.padded_leggings", count = 1 } },
		craftSeconds = 10,
		unlock = quest("quest.scavenger"),
		feature = "fogRuns",
	},
	["recipe.padded_boots"] = {
		id = "recipe.padded_boots",
		inputs = {
			{ itemId = "item.cloth", count = 2 },
			{ itemId = "item.leather", count = 2 },
			{ itemId = "item.rope", count = 2 },
		},
		outputs = { { itemId = "item.padded_boots", count = 1 } },
		craftSeconds = 10,
		unlock = quest("quest.scavenger"),
		feature = "fogRuns",
	},
	-- The starter weapon: unlocked from the start, made in the first quest.
	["recipe.sharpened_stake"] = {
		id = "recipe.sharpened_stake",
		inputs = {
			{ itemId = "item.sticks", count = 4 },
			{ itemId = "item.rope", count = 1 },
		},
		outputs = { { itemId = "item.sharpened_stake", count = 1 } },
		craftSeconds = 4,
		unlock = { kind = "default" },
	},
	-- The no-fuel food and water stations (LB-5): water off the roof, meat in the smoke.
	["recipe.rain_water"] = {
		id = "recipe.rain_water",
		inputs = { { itemId = "item.murky_water", count = 1 } },
		outputs = { { itemId = "item.boiled_water", count = 1 } },
		stationId = "station.rain_barrel",
		craftSeconds = 10 * 60,
		unlock = quest("quest.keep_the_fire"),
	},
	["recipe.smoked_meat"] = {
		id = "recipe.smoked_meat",
		inputs = { { itemId = "item.raw_meat", count = 1 } },
		outputs = { { itemId = "item.smoked_meat", count = 1 } },
		stationId = "station.smoke_rack",
		craftSeconds = 10 * 60,
		unlock = quest("quest.stand_your_ground"),
		feature = "fogRuns",
	},
}

-- 2.0 batch 4 (docs/CONTENT_2_0.md), all tagged content2 -----------------------------------------
local function stacks(list: { { any } }): { Types.ItemStack }
	local result: { Types.ItemStack } = {}
	for _, pair in list do
		table.insert(result, { itemId = pair[1] :: string, count = pair[2] :: number })
	end
	return result
end

-- A hand recipe making one `output` (gear, bags and meds are crafted on the spot, #20).
local function hand(output: string, inputs: { { any } }, questId: string, seconds: number?)
	local id = "recipe." .. string.sub(output, 6)
	Recipes[id] = {
		id = id,
		inputs = stacks(inputs),
		outputs = { { itemId = output, count = 1 } },
		craftSeconds = seconds or 10,
		unlock = quest(questId),
		feature = "content2",
	}
end

-- Melee (ARSENAL §4).
hand("item.hand_axe", {
	{ "item.iron_ingot", 3 },
	{ "item.ironbark_plank", 2 },
	{ "item.rivets", 2 },
	{ "item.pitch_glue", 1 },
}, "quest.heartwood")
hand(
	"item.field_knife",
	{ { "item.iron_ingot", 2 }, { "item.scrap_plate", 1 }, { "item.leather", 1 }, { "item.rope", 1 } },
	"quest.scavenger"
)

-- Armor levels 3 and 4 (ARSENAL §5): each piece consumes the matching lower piece, at any
-- durability, as LDoE's Reinforced Jacket consumes a Thick Jacket.
local HIDEBOUND = "quest.padded_through"
local RIVETED = "quest.black_fog_regular"
hand("item.hidebound_cap", {
	{ "item.padded_hood", 1 },
	{ "item.leather", 3 },
	{ "item.scrap_plate", 1 },
	{ "item.rivets", 1 },
	{ "item.pitch_glue", 1 },
}, HIDEBOUND)
hand("item.hidebound_coat", {
	{ "item.padded_vest", 1 },
	{ "item.leather", 6 },
	{ "item.scrap_plate", 3 },
	{ "item.rivets", 2 },
	{ "item.pitch_glue", 2 },
}, HIDEBOUND)
hand("item.hidebound_leggings", {
	{ "item.padded_leggings", 1 },
	{ "item.leather", 5 },
	{ "item.scrap_plate", 2 },
	{ "item.rivets", 2 },
	{ "item.pitch_glue", 1 },
}, HIDEBOUND)
hand("item.hidebound_boots", {
	{ "item.padded_boots", 1 },
	{ "item.leather", 3 },
	{ "item.scrap_plate", 1 },
	{ "item.rivets", 1 },
	{ "item.pitch_glue", 1 },
}, HIDEBOUND)
hand("item.riveted_helm", {
	{ "item.hidebound_cap", 1 },
	{ "item.scrap_plate", 3 },
	{ "item.rivets", 4 },
	{ "item.copper_wire", 2 },
}, RIVETED)
hand("item.riveted_cuirass", {
	{ "item.hidebound_coat", 1 },
	{ "item.scrap_plate", 6 },
	{ "item.rivets", 8 },
	{ "item.copper_wire", 4 },
	{ "item.brass_gear", 1 },
}, RIVETED)
hand("item.riveted_legguards", {
	{ "item.hidebound_leggings", 1 },
	{ "item.scrap_plate", 5 },
	{ "item.rivets", 6 },
	{ "item.copper_wire", 3 },
}, RIVETED)
hand("item.riveted_boots", {
	{ "item.hidebound_boots", 1 },
	{ "item.scrap_plate", 2 },
	{ "item.rivets", 4 },
	{ "item.copper_wire", 2 },
}, RIVETED)

-- Helmet, gas mask and bags.
hand(
	"item.steel_helmet",
	{ { "item.scrap_plate", 4 }, { "item.rivets", 2 }, { "item.leather", 1 }, { "item.cloth", 1 } },
	"quest.walls_that_hold"
)
hand("item.gas_mask", {
	{ "item.leather", 2 },
	{ "item.cloth", 2 },
	{ "item.copper_wire", 1 },
	{ "item.embercoal", 4 }, -- the filter
	{ "item.pitch_glue", 1 },
}, "quest.pack_mule")
hand("item.hide_rucksack", { { "item.leather", 4 }, { "item.rope", 3 }, { "item.cloth", 2 } }, "quest.scavenger")
hand("item.ranger_pack", {
	{ "item.pack_frame", 1 }, -- consumed, as the armor tiers consume theirs
	{ "item.leather", 6 },
	{ "item.cloth", 4 },
	{ "item.steel_plate", 2 },
	{ "item.rivets", 2 },
}, "quest.hide_and_rivet")

-- Meds.
hand(
	"item.trauma_pouch",
	{ { "item.field_dressing", 2 }, { "item.leather", 1 }, { "item.pitch_glue", 1 } },
	HIDEBOUND,
	5
)
hand(
	"item.first_aid_kit",
	{ { "item.trauma_pouch", 2 }, { "item.antiseptic", 2 }, { "item.scrap_plate", 1 } },
	"quest.steel_floors",
	5
)

-- Station lines: the Blast Furnace (LDoE's Refined Melting Furnace) and the Apothecary
-- (LDoE's Chemistry Station).
Recipes["recipe.steel_plate"] = {
	id = "recipe.steel_plate",
	inputs = { { itemId = "item.iron_ingot", count = 3 } },
	outputs = { { itemId = "item.steel_plate", count = 1 } },
	stationId = "station.blast_furnace",
	craftSeconds = 30 * 60,
	unlock = quest("quest.hold_the_line"),
	feature = "content2",
}
Recipes["recipe.antiseptic"] = {
	id = "recipe.antiseptic",
	inputs = { { itemId = "item.emberberry", count = 4 } },
	outputs = { { itemId = "item.antiseptic", count = 1 } },
	stationId = "station.apothecary",
	craftSeconds = 10 * 60,
	unlock = quest("quest.steel_floors"),
	feature = "content2",
}

return Recipes
