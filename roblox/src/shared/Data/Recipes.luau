--!strict
-- Recipe definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.
-- Processed materials craft in batches so a full Workbench queue runs for an hour
-- or more, the way LDoE's 20-slot station inputs do.

local Types = require("../Types")

local Recipes: { [Types.RecipeId]: Types.RecipeDef } = {
	-- Hand-crafted ---------------------------------------------------------------
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
	["recipe.field_dressing"] = {
		id = "recipe.field_dressing",
		inputs = { { itemId = "item.cloth", count = 3 } },
		outputs = { { itemId = "item.field_dressing", count = 1 } },
		craftSeconds = 5,
		unlock = { kind = "level", level = 2 },
	},

	-- Workbench --------------------------------------------------------------------
	["recipe.plank"] = {
		id = "recipe.plank",
		inputs = { { itemId = "item.timber", count = 4 } },
		outputs = { { itemId = "item.plank", count = 4 } },
		stationId = "station.workbench",
		craftSeconds = 10 * 60,
		unlock = { kind = "default" },
	},
	["recipe.cloth"] = {
		id = "recipe.cloth",
		inputs = { { itemId = "item.fiber", count = 4 } },
		outputs = { { itemId = "item.cloth", count = 2 } },
		stationId = "station.workbench",
		craftSeconds = 3 * 60,
		unlock = { kind = "level", level = 2 },
	},
	["recipe.stone_block"] = {
		id = "recipe.stone_block",
		inputs = { { itemId = "item.stone", count = 4 } },
		outputs = { { itemId = "item.stone_block", count = 2 } },
		stationId = "station.workbench",
		craftSeconds = 5 * 60,
		unlock = { kind = "level", level = 3 },
	},
	["recipe.scrap_plate"] = {
		id = "recipe.scrap_plate",
		inputs = { { itemId = "item.scrap", count = 6 } },
		outputs = { { itemId = "item.scrap_plate", count = 2 } },
		stationId = "station.workbench",
		craftSeconds = 10 * 60,
		unlock = { kind = "level", level = 4 },
	},
	["recipe.spiked_club"] = {
		id = "recipe.spiked_club",
		inputs = {
			{ itemId = "item.plank", count = 4 },
			{ itemId = "item.rope", count = 2 },
			{ itemId = "item.scrap", count = 3 },
		},
		outputs = { { itemId = "item.spiked_club", count = 1 } },
		stationId = "station.workbench",
		craftSeconds = 60,
		unlock = { kind = "level", level = 2 },
	},
	["recipe.padded_hood"] = {
		id = "recipe.padded_hood",
		inputs = {
			{ itemId = "item.cloth", count = 4 },
			{ itemId = "item.rope", count = 2 },
		},
		outputs = { { itemId = "item.padded_hood", count = 1 } },
		stationId = "station.workbench",
		craftSeconds = 2 * 60,
		unlock = { kind = "level", level = 4 },
	},
	["recipe.shortbow"] = {
		id = "recipe.shortbow",
		inputs = {
			{ itemId = "item.plank", count = 4 },
			{ itemId = "item.rope", count = 4 },
			{ itemId = "item.pitch_glue", count = 1 },
		},
		outputs = { { itemId = "item.shortbow", count = 1 } },
		stationId = "station.workbench",
		craftSeconds = 3 * 60,
		unlock = { kind = "level", level = 5 },
	},
	["recipe.arrow"] = {
		id = "recipe.arrow",
		inputs = {
			{ itemId = "item.sticks", count = 2 },
			{ itemId = "item.scrap", count = 2 },
			{ itemId = "item.fiber", count = 1 },
		},
		outputs = { { itemId = "item.arrow", count = 5 } },
		stationId = "station.workbench",
		craftSeconds = 60,
		unlock = { kind = "level", level = 5 },
	},
	["recipe.padded_vest"] = {
		id = "recipe.padded_vest",
		inputs = {
			{ itemId = "item.cloth", count = 6 },
			{ itemId = "item.rope", count = 3 },
			{ itemId = "item.scrap_plate", count = 2 },
		},
		outputs = { { itemId = "item.padded_vest", count = 1 } },
		stationId = "station.workbench",
		craftSeconds = 5 * 60,
		unlock = { kind = "level", level = 6 },
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
		stationId = "station.workbench",
		craftSeconds = 5 * 60,
		unlock = { kind = "level", level = 8 },
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
		stationId = "station.workbench",
		stationLevel = 2,
		craftSeconds = 10 * 60,
		unlock = { kind = "blueprint", itemId = "item.bp_pack_frame" },
	},

	-- Campfire ------------------------------------------------------------------------
	["recipe.boiled_water"] = {
		id = "recipe.boiled_water",
		inputs = { { itemId = "item.murky_water", count = 2 } },
		outputs = { { itemId = "item.boiled_water", count = 2 } },
		stationId = "station.campfire",
		craftSeconds = 2 * 60,
		unlock = { kind = "default" },
	},
	["recipe.roasted_ashroot"] = {
		id = "recipe.roasted_ashroot",
		inputs = { { itemId = "item.ashroot", count = 2 } },
		outputs = { { itemId = "item.roasted_ashroot", count = 2 } },
		stationId = "station.campfire",
		craftSeconds = 2 * 60,
		unlock = { kind = "default" },
	},
	["recipe.ember_tea"] = {
		id = "recipe.ember_tea",
		inputs = {
			{ itemId = "item.emberberry", count = 3 },
			{ itemId = "item.boiled_water", count = 1 },
		},
		outputs = { { itemId = "item.ember_tea", count = 1 } },
		stationId = "station.campfire",
		craftSeconds = 2 * 60,
		unlock = { kind = "level", level = 3 },
	},
	["recipe.pitch_glue"] = {
		id = "recipe.pitch_glue",
		inputs = { { itemId = "item.fatwood", count = 2 } },
		outputs = { { itemId = "item.pitch_glue", count = 1 } },
		stationId = "station.campfire",
		craftSeconds = 4 * 60,
		unlock = { kind = "level", level = 5 },
	},
	["recipe.hearth_stew"] = {
		id = "recipe.hearth_stew",
		inputs = {
			{ itemId = "item.ashroot", count = 2 },
			{ itemId = "item.emberberry", count = 3 },
			{ itemId = "item.boiled_water", count = 1 },
		},
		outputs = { { itemId = "item.hearth_stew", count = 1 } },
		stationId = "station.campfire",
		stationLevel = 2,
		craftSeconds = 8 * 60,
		unlock = { kind = "level", level = 8 },
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
		stationId = "station.workbench",
		craftSeconds = 10 * 60,
		unlock = { kind = "level", level = 10 }, -- the melee step after the Scrapblade (day 2)
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
		stationId = "station.workbench",
		stationLevel = 2,
		craftSeconds = 15 * 60,
		unlock = { kind = "level", level = 12 }, -- day 3-4, alongside the first guns
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
		stationId = "station.workbench",
		stationLevel = 2,
		craftSeconds = 20 * 60,
		unlock = { kind = "level", level = 11 }, -- the first firearm: day 3 (target days 3-5)
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
		stationId = "station.workbench",
		stationLevel = 2,
		craftSeconds = 20 * 60,
		unlock = { kind = "level", level = 12 }, -- day 4: the light weapon follows the first gun
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
		stationId = "station.workbench",
		stationLevel = 2,
		craftSeconds = 45 * 60,
		unlock = { kind = "level", level = 14 }, -- days 4-5: two Trigger Groups is the grind
		feature = "fogRuns",
	},

	-- Ammo Press: the steady ammo sink (GAME_DESIGN "Combat and the arsenal").
	["recipe.blackpowder"] = {
		id = "recipe.blackpowder",
		inputs = {
			{ itemId = "item.niter", count = 2 },
			{ itemId = "item.fatwood", count = 1 },
		},
		outputs = { { itemId = "item.blackpowder", count = 2 } },
		stationId = "station.ammo_press",
		craftSeconds = 6 * 60,
		unlock = { kind = "level", level = 10 },
		feature = "fogRuns",
	},
	["recipe.light_rounds"] = {
		id = "recipe.light_rounds",
		inputs = {
			{ itemId = "item.scrap", count = 2 },
			{ itemId = "item.blackpowder", count = 1 },
		},
		outputs = { { itemId = "item.light_rounds", count = 6 } },
		stationId = "station.ammo_press",
		craftSeconds = 4 * 60, -- a full 3-job queue is 18 rounds: about one Dense run's shooting
		unlock = { kind = "level", level = 11 },
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
		stationId = "station.ammo_press",
		craftSeconds = 8 * 60,
		unlock = { kind = "level", level = 12 },
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
		stationId = "station.ammo_press",
		craftSeconds = 6 * 60,
		unlock = { kind = "level", level = 14 },
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
		inputs = {
			{ itemId = "item.hide", count = 3 },
			{ itemId = "item.pitch_glue", count = 1 },
		},
		outputs = { { itemId = "item.leather", count = 2 } },
		stationId = "station.workbench",
		craftSeconds = 8 * 60,
		unlock = { kind = "level", level = 4 },
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
		unlock = { kind = "level", level = 3 },
		feature = "fogRuns",
	},
}

return Recipes
