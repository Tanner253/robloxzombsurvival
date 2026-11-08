--!strict
--[[
	Starter questline, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.

	Ten linked quests teach the loop in order: gather -> craft -> build -> travel ->
	loot -> defend. Each one names the next step's prerequisite, and rewards supply
	whatever the following quest needs, so nobody stalls on a missing input.
]]

local Types = require("../Types")

local Quests: { [Types.QuestId]: Types.QuestDef } = {
	["quest.first_light"] = {
		id = "quest.first_light",
		name = "First Light",
		description = "The fog thins at dawn. Pick up fallen branches and loose stones around your outpost.",
		objectives = {
			{ kind = "gather", itemId = "item.timber", count = 6 },
			{ kind = "gather", itemId = "item.stone", count = 6 },
		},
		rewards = { xp = 150, items = { { itemId = "item.sealed_tin", count = 2 } } },
	},
	["quest.tools_of_survival"] = {
		id = "quest.tools_of_survival",
		name = "Tools of Survival",
		description = "Bind stone to timber. A hatchet fells pines and a pick breaks boulders.",
		prerequisite = "quest.first_light",
		objectives = {
			{ kind = "craft", recipeId = "recipe.stone_hatchet", count = 1 },
			{ kind = "craft", recipeId = "recipe.stone_pick", count = 1 },
		},
		rewards = { xp = 150, items = { { itemId = "item.fiber", count = 6 } } },
	},
	["quest.claim_the_ground"] = {
		id = "quest.claim_the_ground",
		name = "Claim the Ground",
		description = "Lay timber foundations and raise your first walls.",
		prerequisite = "quest.tools_of_survival",
		objectives = {
			{ kind = "build", pieceId = "build.foundation_wood", count = 2 },
			{ kind = "build", pieceId = "build.wall_wood", count = 2 },
		},
		rewards = {
			xp = 200,
			items = { { itemId = "item.timber", count = 10 }, { itemId = "item.rope", count = 4 } },
		},
	},
	["quest.a_place_to_work"] = {
		id = "quest.a_place_to_work",
		name = "A Place to Work",
		description = "Build a Workbench and set it to cutting planks. It keeps working while you are away.",
		prerequisite = "quest.claim_the_ground",
		objectives = {
			{ kind = "build", pieceId = "build.workbench", count = 1 },
			{ kind = "craft", recipeId = "recipe.plank", count = 1 },
		},
		rewards = {
			xp = 250,
			items = { { itemId = "item.murky_water", count = 2 }, { itemId = "item.ashroot", count = 2 } },
		},
	},
	["quest.keep_the_fire"] = {
		id = "quest.keep_the_fire",
		name = "Keep the Fire",
		description = "Light a Campfire, feed it fuel, and boil water you can safely drink.",
		prerequisite = "quest.a_place_to_work",
		objectives = {
			{ kind = "build", pieceId = "build.campfire", count = 1 },
			{ kind = "craft", recipeId = "recipe.boiled_water", count = 1 },
			{ kind = "consume", itemId = "item.boiled_water", count = 1 },
		},
		rewards = { xp = 250, items = { { itemId = "item.fatwood", count = 3 } } },
	},
	["quest.into_the_fog"] = {
		id = "quest.into_the_fog",
		name = "Into the Fog",
		description = "Weave a satchel, then Run or Walk to Pine Hollow on the Fog map.",
		prerequisite = "quest.keep_the_fire",
		objectives = {
			{ kind = "craft", recipeId = "recipe.satchel", count = 1 },
			{ kind = "equip", itemId = "item.satchel" },
			{ kind = "travel", locationId = "loc.pine_hollow" },
		},
		rewards = { xp = 300, energy = 10, items = { { itemId = "item.field_dressing", count = 2 } } },
	},
	["quest.scavenger"] = {
		id = "quest.scavenger",
		name = "Scavenger",
		description = "Search what others left behind in Pine Hollow, and dig up ashroot to eat.",
		prerequisite = "quest.into_the_fog",
		objectives = {
			{ kind = "loot", count = 3, locationId = "loc.pine_hollow" },
			{ kind = "gather", itemId = "item.ashroot", count = 4 },
		},
		rewards = {
			xp = 300,
			items = { { itemId = "item.scrap", count = 4 }, { itemId = "item.cloth", count = 4 } },
		},
	},
	["quest.stand_your_ground"] = {
		id = "quest.stand_your_ground",
		name = "Stand Your Ground",
		description = "Make a proper weapon and put five of the Hollow to rest.",
		prerequisite = "quest.scavenger",
		objectives = {
			{ kind = "craft", recipeId = "recipe.spiked_club", count = 1 },
			{ kind = "equip", itemId = "item.spiked_club" },
			{ kind = "kill", count = 5 },
		},
		rewards = { xp = 400, items = { { itemId = "item.padded_hood", count = 1 } } },
	},
	["quest.hold_the_door"] = {
		id = "quest.hold_the_door",
		name = "Hold the Door",
		description = "Close your walls with a doorway and a door, and put your loot in a crate.",
		prerequisite = "quest.stand_your_ground",
		objectives = {
			{ kind = "build", pieceId = "build.doorway_wood", count = 1 },
			{ kind = "build", pieceId = "build.door_wood", count = 1 },
			{ kind = "build", pieceId = "build.crate_wood", count = 1 },
		},
		rewards = { xp = 350, items = { { itemId = "item.plank", count = 6 } } },
	},
	["quest.the_dense_fog"] = {
		id = "quest.the_dense_fog",
		name = "The Dense Fog",
		description = "Grow strong enough to face the Dense fog, then reach the Sunken Quarry.",
		prerequisite = "quest.hold_the_door",
		objectives = {
			{ kind = "reachLevel", level = 4 },
			{ kind = "travel", locationId = "loc.sunken_quarry" },
		},
		rewards = {
			xp = 500,
			items = { { itemId = "item.ember_tonic", count = 1 }, { itemId = "item.scrap", count = 6 } },
		},
	},
}

return Quests
