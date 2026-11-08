--!strict
--[[
	Recipe definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.

	Hand recipes (no stationId) are the crafting catalogue: every tool, weapon, armor piece,
	bag and food mix is made by hand (LDOE_PARITY #20). Station recipes are converter lines
	(#18): one input stack -> one output stack, one batch per craftSeconds, at LDoE's pace
	(a plank or stone block every 4 minutes, cooking every 2).

	Unlocks (#49): only the hatchet, pick, satchel (and the cord it needs) start unlocked.
	Everything else unlocks by completing an Ember Trail quest (Data/Quests), or by reading
	a found schematic. Repair doesn't exist yet: worn gear is re-crafted (#21).
]]

local Types = require("../Types")

local function quest(questId: string): Types.UnlockGate
	return { kind = "quest", questId = questId }
end

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
		inputs = { { itemId = "item.cloth", count = 3 } },
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
			{ itemId = "item.pitch_glue", count = 1 },
		},
		outputs = { { itemId = "item.shortbow", count = 1 } },
		craftSeconds = 10,
		unlock = quest("quest.stand_your_ground"),
	},
	["recipe.arrow"] = {
		id = "recipe.arrow",
		inputs = {
			{ itemId = "item.sticks", count = 2 },
			{ itemId = "item.scrap", count = 2 },
			{ itemId = "item.fiber", count = 1 },
		},
		outputs = { { itemId = "item.arrow", count = 5 } },
		craftSeconds = 5,
		unlock = quest("quest.stand_your_ground"),
	},
	["recipe.padded_vest"] = {
		id = "recipe.padded_vest",
		inputs = {
			{ itemId = "item.cloth", count = 6 },
			{ itemId = "item.rope", count = 3 },
			{ itemId = "item.scrap_plate", count = 2 },
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

	-- Woodworking Bench ------------------------------------------------------------------
	["recipe.plank"] = {
		id = "recipe.plank",
		inputs = { { itemId = "item.timber", count = 1 } },
		outputs = { { itemId = "item.plank", count = 1 } },
		stationId = "station.woodworking_bench",
		craftSeconds = 4 * 60,
		unlock = quest("quest.claim_the_ground"),
	},

	-- Stonecutter -------------------------------------------------------------------------
	["recipe.stone_block"] = {
		id = "recipe.stone_block",
		inputs = { { itemId = "item.stone", count = 2 } },
		outputs = { { itemId = "item.stone_block", count = 1 } },
		stationId = "station.stonecutter",
		craftSeconds = 4 * 60,
		unlock = quest("quest.a_place_to_work"),
	},

	-- Smelter ------------------------------------------------------------------------------
	["recipe.scrap_plate"] = {
		id = "recipe.scrap_plate",
		inputs = { { itemId = "item.scrap", count = 3 } },
		outputs = { { itemId = "item.scrap_plate", count = 1 } },
		stationId = "station.smelter",
		craftSeconds = 4 * 60,
		unlock = quest("quest.into_the_fog"),
	},

	-- Workbench: parts -----------------------------------------------------------------------
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

	-- Campfire: cooking ----------------------------------------------------------------------
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

	-- Ammo Press: the steady ammo sink (GAME_DESIGN "Combat and the arsenal").
	["recipe.blackpowder"] = {
		id = "recipe.blackpowder",
		inputs = { { itemId = "item.niter", count = 2 } }, -- fatwood is the press fuel now
		outputs = { { itemId = "item.blackpowder", count = 2 } },
		stationId = "station.ammo_press",
		craftSeconds = 6 * 60,
		unlock = quest("quest.the_dense_fog"), -- was level 10: recipes unlock on the Ember Trail (LDOE_PARITY #49)
		feature = "fogRuns",
	},
	["recipe.light_rounds"] = {
		id = "recipe.light_rounds",
		inputs = {
			{ itemId = "item.scrap", count = 2 },
			{ itemId = "item.blackpowder", count = 1 },
		},
		outputs = { { itemId = "item.light_rounds", count = 6 } },
		craftSeconds = 4 * 60, -- a full 3-job queue is 18 rounds: about one Dense run's shooting
		unlock = quest("quest.the_dense_fog"), -- was level 11: recipes unlock on the Ember Trail (LDOE_PARITY #49)
		feature = "fogRuns",
	},
	["recipe.flare"] = {
		id = "recipe.flare",
		inputs = {
			{ itemId = "item.blackpowder", count = 2 },
			{ itemId = "item.pitch_glue", count = 1 },
			{ itemId = "item.cloth", count = 1 },
		},
		outputs = { { itemId = "item.flare", count = 2 } },
		craftSeconds = 8 * 60,
		unlock = quest("quest.the_dense_fog"), -- was level 12: recipes unlock on the Ember Trail (LDOE_PARITY #49)
		feature = "fogRuns",
	},
	["recipe.shells"] = {
		id = "recipe.shells",
		inputs = {
			{ itemId = "item.scrap", count = 3 },
			{ itemId = "item.blackpowder", count = 2 },
			{ itemId = "item.cloth", count = 1 },
		},
		outputs = { { itemId = "item.shells", count = 4 } },
		craftSeconds = 6 * 60,
		unlock = quest("quest.the_dense_fog"), -- was level 14: recipes unlock on the Ember Trail (LDOE_PARITY #49)
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
}

return Recipes
