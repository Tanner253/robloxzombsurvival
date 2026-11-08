--!strict
--[[
	The Ember Trail: the starter questline, keyed by permanent ID (LDOE_PARITY #48-50).
	MVP content; see docs/CONTENT_MVP.md. (LDoE's own name for this is "Survivor's Path";
	ours is the Ember Trail everywhere.)

	The trail branches, as LDoE's does, so the tracker usually holds two or three quests:
	after Tools of Survival the building line (3, 4, 7) and the fire line (5, 6, 8) run side
	by side. `order` sorts the tracker and the quest screen. Completing one
	(Domain/Quests: automatically, on its last objective) pays its rewards into the inbox and
	unlocks every recipe and build piece whose UnlockGate names it (#49), which is exactly
	what the next quests ask for. Rewards supply what the following quest needs, so nobody
	stalls on a missing input.

	The home chapter (quests 1-7) is playable on the home plot alone. Objectives with a
	`flag` wait on that feature (Shared/Flags): quest 1's Hollow kill and body search
	(#57) and quest 6's crash site need Fog Runs; until they ship those objectives are
	left out, and quests whose every objective waits stay closed.
]]

local Types = require("../Types")

local HOME = "Ashes and Embers"
local FOG = "Into the Fog"

local Quests: { [Types.QuestId]: Types.QuestDef } = {
	["quest.first_light"] = {
		id = "quest.first_light",
		order = 1,
		chapter = HOME,
		name = "First Light",
		description = "The fog thins at dawn. Gather fallen branches and loose stones, and put down the Hollow that wandered in.",
		objectives = {
			{ kind = "gather", itemId = "item.sticks", count = 6 },
			{ kind = "gather", itemId = "item.stone", count = 6 },
			{ kind = "kill", count = 1, flag = "fogRuns" },
			{ kind = "lootBody", count = 1, flag = "fogRuns" },
		},
		rewards = { xp = 150, items = { { itemId = "item.sealed_tin", count = 2 } } },
	},
	["quest.tools_of_survival"] = {
		id = "quest.tools_of_survival",
		order = 2,
		chapter = HOME,
		name = "Tools of Survival",
		description = "Bind stone to wood. A hatchet fells pines and a pick breaks boulders.",
		prerequisite = "quest.first_light",
		objectives = {
			{ kind = "craft", recipeId = "recipe.stone_hatchet", count = 1 },
			{ kind = "craft", recipeId = "recipe.stone_pick", count = 1 },
		},
		rewards = { xp = 150, items = { { itemId = "item.fiber", count = 6 } } },
	},
	["quest.claim_the_ground"] = {
		id = "quest.claim_the_ground",
		order = 3,
		chapter = HOME,
		name = "Claim the Ground",
		description = "Patch the old shelter: lay timber foundations and raise walls.",
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
		order = 4,
		chapter = HOME,
		name = "A Place to Work",
		description = "Build a Woodworking Bench and feed it timber. It saws planks while you are away.",
		prerequisite = "quest.claim_the_ground",
		objectives = {
			{ kind = "build", pieceId = "build.woodworking_bench", count = 1 },
			{ kind = "craft", recipeId = "recipe.plank", count = 1 },
		},
		rewards = {
			xp = 250,
			items = { { itemId = "item.murky_water", count = 2 }, { itemId = "item.ashroot", count = 2 } },
		},
	},
	["quest.keep_the_fire"] = {
		id = "quest.keep_the_fire",
		order = 5,
		chapter = HOME,
		name = "Keep the Fire",
		description = "Feed the old campfire at the shelter, boil water you can safely drink, and drink it.",
		prerequisite = "quest.tools_of_survival",
		objectives = {
			{ kind = "craft", recipeId = "recipe.boiled_water", count = 1 },
			{ kind = "consume", itemId = "item.boiled_water", count = 1 },
		},
		rewards = { xp = 250, items = { { itemId = "item.fatwood", count = 6 } } },
	},
	["quest.crash_site"] = {
		id = "quest.crash_site",
		order = 6,
		chapter = HOME,
		name = "The Crash Site",
		description = "Smoke rises past the treeline. Weave a satchel to carry what you find, then reach the crash site.",
		prerequisite = "quest.keep_the_fire",
		objectives = {
			{ kind = "craft", recipeId = "recipe.satchel", count = 1 },
			{ kind = "equip", itemId = "item.satchel" },
			{ kind = "travel", locationId = "loc.crash_site", flag = "fogRuns" },
		},
		rewards = {
			xp = 300,
			items = { { itemId = "item.field_dressing", count = 2 }, { itemId = "item.scrap", count = 6 } },
		},
	},
	["quest.hold_the_door"] = {
		id = "quest.hold_the_door",
		order = 7,
		chapter = HOME,
		name = "Hold the Door",
		description = "Close your walls with a doorway and a door, and put your loot in a crate.",
		prerequisite = "quest.a_place_to_work",
		objectives = {
			{ kind = "build", pieceId = "build.doorway_wood", count = 1 },
			{ kind = "build", pieceId = "build.door_wood", count = 1 },
			{ kind = "build", pieceId = "build.crate_wood", count = 1 },
		},
		rewards = { xp = 350, items = { { itemId = "item.plank", count = 6 }, { itemId = "item.cloth", count = 4 } } },
	},
	["quest.stand_your_ground"] = {
		id = "quest.stand_your_ground",
		order = 8,
		chapter = FOG,
		name = "Stand Your Ground",
		description = "Make a proper weapon and put five of the Hollow to rest.",
		prerequisite = "quest.crash_site",
		objectives = {
			{ kind = "craft", recipeId = "recipe.spiked_club", count = 1 },
			{ kind = "equip", itemId = "item.spiked_club" },
			{ kind = "kill", count = 5, flag = "fogRuns" },
		},
		rewards = { xp = 400, items = { { itemId = "item.padded_hood", count = 1 } } },
	},
	["quest.into_the_fog"] = {
		id = "quest.into_the_fog",
		order = 9,
		chapter = FOG,
		name = "Into the Fog",
		description = "Run or Walk to Pine Hollow, search what others left behind, and dig up ashroot.",
		prerequisite = "quest.stand_your_ground",
		objectives = {
			{ kind = "travel", locationId = "loc.pine_hollow", flag = "fogRuns" },
			{ kind = "loot", count = 3, locationId = "loc.pine_hollow", flag = "fogRuns" },
			{ kind = "gather", itemId = "item.ashroot", count = 4, flag = "fogRuns" },
		},
		rewards = {
			xp = 300,
			energy = 10,
			items = { { itemId = "item.scrap", count = 4 }, { itemId = "item.cloth", count = 4 } },
		},
	},
	["quest.the_dense_fog"] = {
		id = "quest.the_dense_fog",
		order = 10,
		chapter = FOG,
		name = "The Dense Fog",
		description = "Grow strong enough to face the Dense fog, then reach the Sunken Quarry.",
		prerequisite = "quest.into_the_fog",
		objectives = {
			{ kind = "reachLevel", level = 4 },
			{ kind = "travel", locationId = "loc.sunken_quarry", flag = "fogRuns" },
		},
		rewards = {
			xp = 500,
			items = { { itemId = "item.ember_tonic", count = 1 }, { itemId = "item.scrap", count = 6 } },
		},
	},
}

return Quests
