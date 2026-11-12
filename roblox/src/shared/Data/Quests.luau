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

	The home chapter (quests 1-7) is playable on the home plot alone (the flow review's F-07):
	its 28 pines give 84 timber and Claim the Ground pays 20 more, 104 against the 87 that
	quests 3, 4 and 7, the Stonecutter and the Workbench's planks take (tests/Pacing.spec),
	so about 17 are left for fuel. Home trees never regrow: when the last one falls the
	player is told, and the Guide points at the Trailhead, where the Fog has more. Objectives with a
	`flag` wait on that feature (Shared/Flags): quest 6's trip to Pine Hollow, its first
	Hollow kill and the drop that Hollow leaves (#57) need Fog Runs; until they ship those
	objectives are left out, and quests whose every objective waits stay closed. Quest 1 has
	no flagged objective, so it completes at home whether Fog Runs are on or off. (#57's
	one-time crash site is a Fog Runs location, slice 2's to add.)

	Quests 11-13 (docs/ECONOMY.md §11.2) open the tier-2 ladder after the Dense fog: the
	Forged Hatchet and Ironbark Planks, the Forged Pick and copper, then the Black fog.

	Chapter 3, "Hold the Line" (quests 14-25, docs/research/ldoe-mvp-parity-content.md SH-10
	and BR-8), opens with the Black fog and runs two lines side by side, so the tracker keeps
	two quests: the home line (14, 16, 18, 20, 22, 24: lights, rain and smoke, the doormat and
	a spare set, banded storage, the Stranded Caravan, full stores) and the fog line (15, 17,
	19, 21, 23, 25: the Reinforcement Plans, copper, reinforced walls, the Padded set, the
	Depot, then level 25). In the pacing model (tests/Pacing.spec, 2.5 h a day) they land
	from day 8 to day 18, so the trail no longer ends in the first week. Build objectives, and
	craft objectives for gear, count what the player already has when the quest opens
	(Domain/Quests.holdings, the flow review's F-06): the pieces they placed (never the
	starter shelter's) and the tools, weapons and bags they carry or wear. The reinforced
	ones ask for pieces a base keeps needing (walls, not its one door).
]]

local Types = require("../Types")

local HOME = "Ashes and Embers"
local FOG = "Into the Fog"
local LINE = "Hold the Line"

local Quests: { [Types.QuestId]: Types.QuestDef } = {
	["quest.first_light"] = {
		id = "quest.first_light",
		order = 1,
		chapter = HOME,
		name = "First Light",
		description = "The fog thins at dawn. Gather branches and stones, twist reeds into a cord, and sharpen a stake to keep in hand.",
		-- Home only, with or without Fog Runs (the flow review's F-02): every objective is
		-- something the plot reports. The stake takes 4 of the sticks and a rope; the other 6
		-- sticks and the stones make Tools of Survival. The first Hollow waits in Into the Fog.
		-- The reeds and the rope are steps of their own (launch playtest, 2026-11-11): a new
		-- player has no rope, and the Guide only points at a listed objective.
		objectives = {
			{ kind = "gather", itemId = "item.sticks", count = 10 },
			{ kind = "gather", itemId = "item.stone", count = 6 },
			{ kind = "gather", itemId = "item.fiber", count = 2 },
			{ kind = "craft", recipeId = "recipe.rope", count = 1 },
			{ kind = "craft", recipeId = "recipe.sharpened_stake", count = 1 },
			{ kind = "equip", itemId = "item.sharpened_stake" },
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
		-- Fiber for the cord ahead, and a third hatchet's sticks and stone: the plot's 28 pines
		-- (F-07) take 84 swings, more than two stone hatchets last.
		rewards = {
			xp = 150,
			items = {
				{ itemId = "item.fiber", count = 6 },
				{ itemId = "item.sticks", count = 3 },
				{ itemId = "item.stone", count = 3 },
			},
		},
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
		-- 20 timber (F-07): with the plot's 84, chapter 1's builds are paid for.
		rewards = {
			xp = 200,
			items = { { itemId = "item.timber", count = 20 }, { itemId = "item.rope", count = 4 } },
		},
	},
	["quest.a_place_to_work"] = {
		id = "quest.a_place_to_work",
		order = 4,
		chapter = HOME,
		name = "A Place to Work",
		description = "Build a Saw Bench and feed it timber. It saws planks while you are away.",
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
	["quest.into_the_fog"] = {
		id = "quest.into_the_fog",
		order = 6,
		chapter = HOME,
		name = "Into the Fog",
		description = "Weave a satchel to carry what you find, then Run or Walk to Pine Hollow on the Fog map. Put down a Hollow there and take what it drops.",
		prerequisite = "quest.keep_the_fire",
		-- The first kill and the first Hollow drop (#57) live here, where the Fog map opens:
		-- Services/LocationQuests reports "kill", and "lootBody" when a Hollow's drop is picked up.
		objectives = {
			{ kind = "craft", recipeId = "recipe.satchel", count = 1 },
			{ kind = "equip", itemId = "item.satchel" },
			{ kind = "travel", locationId = "loc.pine_hollow", flag = "fogRuns" },
			{ kind = "kill", count = 1, flag = "fogRuns" },
			{ kind = "lootBody", count = 1, flag = "fogRuns" },
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
		prerequisite = "quest.into_the_fog",
		objectives = {
			{ kind = "craft", recipeId = "recipe.spiked_club", count = 1 },
			{ kind = "equip", itemId = "item.spiked_club" },
			{ kind = "kill", count = 5, flag = "fogRuns" },
		},
		rewards = { xp = 400, items = { { itemId = "item.padded_hood", count = 1 } } },
	},
	["quest.scavenger"] = {
		id = "quest.scavenger",
		order = 9,
		chapter = FOG,
		name = "Scavenger",
		description = "Search what others left behind in Pine Hollow, and dig up ashroot to eat.",
		prerequisite = "quest.stand_your_ground",
		objectives = {
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
		description = "Grow strong enough to face the Dense fog, then reach Rustwater. Iron tools come next.",
		prerequisite = "quest.scavenger",
		objectives = {
			{ kind = "reachLevel", level = 8 }, -- the Dense fog's level gate (GAME_DESIGN, slice 2)
			{ kind = "travel", locationId = "loc.sunken_quarry", flag = "fogRuns" },
		},
		rewards = {
			xp = 500,
			items = { { itemId = "item.ember_tonic", count = 1 }, { itemId = "item.scrap", count = 6 } },
		},
	},
	["quest.heartwood"] = {
		id = "quest.heartwood",
		order = 11,
		chapter = FOG,
		name = "Heartwood",
		description = "Forge an iron hatchet and fell Ironbark. Its logs saw down to the planks a reinforced wall needs.",
		prerequisite = "quest.the_dense_fog",
		objectives = {
			{ kind = "craft", recipeId = "recipe.forged_hatchet", count = 1 },
			{ kind = "gather", itemId = "item.ironbark_log", count = 10, flag = "fogRuns" },
		},
		rewards = { xp = 600, items = { { itemId = "item.pitch_glue", count = 4 } } },
	},
	["quest.green_vein"] = {
		id = "quest.green_vein",
		order = 12,
		chapter = FOG,
		name = "The Green Vein",
		description = "Forge an iron pick and break the green veins. Copper smelts slow and draws into wire.",
		prerequisite = "quest.the_dense_fog",
		objectives = {
			{ kind = "craft", recipeId = "recipe.forged_pick", count = 1 },
			{ kind = "gather", itemId = "item.malachite", count = 6, flag = "fogRuns" },
		},
		rewards = { xp = 600, items = { { itemId = "item.embercoal", count = 10 } } },
	},
	["quest.into_the_black"] = {
		id = "quest.into_the_black",
		order = 13,
		chapter = FOG,
		name = "Into the Black",
		-- F-15: the Black fog's two costs, said before the first trip.
		description = "Grow strong enough for the Black fog and walk into it. The plans for reinforced walls are out there. The fog seeps in as you stay: wear a full padded set, carry dressings, and know that dying there leaves your gear behind.",
		prerequisite = "quest.green_vein",
		objectives = {
			{ kind = "reachLevel", level = 15 }, -- the Black fog's level gate (GAME_DESIGN)
			{ kind = "travel", fogTier = 3, flag = "fogRuns" },
		},
		-- Glue and cloth light the first torches and lanterns (Light the Edges).
		rewards = {
			xp = 1000,
			items = {
				{ itemId = "item.coil_spring", count = 2 },
				{ itemId = "item.pitch_glue", count = 4 },
				{ itemId = "item.cloth", count = 4 },
			},
		},
	},

	-- Chapter 3: Hold the Line ------------------------------------------------------------------
	-- The home line.
	["quest.light_the_edges"] = {
		id = "quest.light_the_edges",
		order = 14,
		chapter = LINE,
		name = "Light the Edges",
		description = "Light is territory. Ring your walls with Pitch Torches and set Post Lanterns by the door, so nothing reaches you unseen.",
		prerequisite = "quest.into_the_black",
		objectives = {
			{ kind = "build", pieceId = "build.pitch_torch", count = 4 },
			{ kind = "build", pieceId = "build.post_lantern", count = 2 },
		},
		-- Cord lashes the Smoke Rack; cloth covers the Rain Barrel (Rain and Smoke).
		rewards = {
			xp = 1200,
			items = { { itemId = "item.rope", count = 10 }, { itemId = "item.cloth", count = 3 } },
		},
	},
	["quest.rain_and_smoke"] = {
		id = "quest.rain_and_smoke",
		order = 16,
		chapter = LINE,
		name = "Rain and Smoke",
		description = "Stop boiling every drop. Set out a Rain Barrel: it catches clean water while you are out in the fog.",
		prerequisite = "quest.light_the_edges",
		objectives = {
			{ kind = "build", pieceId = "build.rain_barrel", count = 1 },
			-- The rack and its venison wait for deer (Tuning.features.wildlife, F-21).
			{ kind = "build", pieceId = "build.smoke_rack", count = 1, flag = "wildlife" },
			{ kind = "craft", recipeId = "recipe.smoked_meat", count = 4, flag = "wildlife" },
		},
		-- Cloth and cord for the spare Reedweave set and the doormat (Come Home Again).
		rewards = {
			xp = 1300,
			items = { { itemId = "item.cloth", count = 9 }, { itemId = "item.rope", count = 6 } },
		},
	},
	["quest.come_home_again"] = {
		id = "quest.come_home_again",
		order = 18,
		chapter = LINE,
		name = "Come Home Again",
		description = "When the fog takes you, you wake at home. Weave a Reed Doormat and lay it down, then weave a spare Reedweave set to walk back out in.",
		prerequisite = "quest.rain_and_smoke",
		objectives = {
			{ kind = "craft", recipeId = "recipe.doormat", count = 1, flag = "fogRuns" },
			{ kind = "build", pieceId = "build.doormat", count = 1, flag = "fogRuns" },
			{ kind = "craft", recipeId = "recipe.reedweave_cap", count = 1 },
			{ kind = "craft", recipeId = "recipe.reedweave_shirt", count = 1 },
			{ kind = "craft", recipeId = "recipe.reedweave_trousers", count = 1 },
			{ kind = "craft", recipeId = "recipe.reedweave_wraps", count = 1 },
		},
		-- Plates and rivets band the crates (Room for More).
		rewards = {
			xp = 1500,
			items = { { itemId = "item.scrap_plate", count = 4 }, { itemId = "item.rivets", count = 4 } },
		},
	},
	["quest.room_for_more"] = {
		id = "quest.room_for_more",
		order = 20,
		chapter = LINE,
		name = "Room for More",
		description = "Your stock has outgrown timber crates. Band two of them with plate and rivets into Banded Crates, to hold what the Black fog gives up.",
		prerequisite = "quest.come_home_again",
		objectives = {
			{ kind = "build", pieceId = "build.crate_banded", count = 2 },
		},
		-- Dressings and stew for the road to the Caravan.
		rewards = {
			xp = 1700,
			items = { { itemId = "item.field_dressing", count = 3 }, { itemId = "item.hearth_stew", count = 2 } },
		},
	},
	["quest.stranded_caravan"] = {
		id = "quest.stranded_caravan",
		order = 22,
		chapter = LINE,
		name = "The Stranded Caravan",
		description = "A caravan lies stranded in the Dense fog, and it is only there for a few hours at a time. Catch it on the Fog map and search the wagons.",
		prerequisite = "quest.room_for_more",
		objectives = {
			{ kind = "travel", locationId = "loc.stranded_caravan", flag = "fogRuns" },
			{ kind = "loot", count = 4, locationId = "loc.stranded_caravan", flag = "fogRuns" },
		},
		-- Venison to start the rack on (Full Stores).
		rewards = {
			xp = 2000,
			items = { { itemId = "item.raw_meat", count = 6 }, { itemId = "item.ember_tonic", count = 1 } },
		},
	},
	["quest.full_stores"] = {
		id = "quest.full_stores",
		order = 24,
		chapter = LINE,
		name = "Full Stores",
		description = "A base that holds needs food that keeps. Cook a store of Hearth Stew, and grow seasoned enough to live on it.",
		prerequisite = "quest.stranded_caravan",
		objectives = {
			{ kind = "craft", recipeId = "recipe.hearth_stew", count = 10 },
			{ kind = "craft", recipeId = "recipe.smoked_meat", count = 20, flag = "wildlife" },
			{ kind = "reachLevel", level = 24 },
		},
		rewards = {
			xp = 2600,
			items = { { itemId = "item.brass_gear", count = 2 }, { itemId = "item.ember_tonic", count = 2 } },
		},
	},

	-- The fog line.
	["quest.the_plans"] = {
		id = "quest.the_plans",
		order = 15,
		chapter = LINE,
		name = "The Plans",
		description = "The Reinforcement Plans are somewhere in the Ashfall Depot. Search its freight until you find them, read them, and reinforce a foundation.",
		prerequisite = "quest.into_the_black",
		objectives = {
			{ kind = "loot", count = 6, locationId = "loc.ashfall_depot", flag = "fogRuns" },
			{ kind = "build", pieceId = "build.foundation_reinforced", count = 1 },
		},
		-- Embercoal to fuel the copper smelt (Copper Lines).
		rewards = {
			xp = 1500,
			items = { { itemId = "item.embercoal", count = 10 }, { itemId = "item.field_dressing", count = 2 } },
		},
	},
	["quest.copper_lines"] = {
		id = "quest.copper_lines",
		order = 17,
		chapter = LINE,
		name = "Copper Lines",
		description = "Raise the Smelter to level 2 and smelt copper from malachite. Drawn into wire at a level 2 Workbench, it binds reinforced walls.",
		prerequisite = "quest.the_plans",
		objectives = {
			{ kind = "gather", itemId = "item.malachite", count = 20, flag = "fogRuns" },
			{ kind = "craft", recipeId = "recipe.copper_ingot", count = 4 },
		},
		-- Rivets for the first reinforced walls (Walls That Hold).
		rewards = { xp = 1600, items = { { itemId = "item.rivets", count = 8 } } },
	},
	["quest.walls_that_hold"] = {
		id = "quest.walls_that_hold",
		order = 19,
		chapter = LINE,
		name = "Walls That Hold",
		description = "Saw Ironbark into planks at a level 2 Saw Bench, then reinforce your walls with stone, ironbark and copper wire.",
		prerequisite = "quest.copper_lines",
		objectives = {
			{ kind = "build", pieceId = "build.wall_reinforced", count = 4 },
		},
		-- Leather and cloth for the Padded leggings and boots (Padded Through).
		rewards = {
			xp = 2000,
			items = { { itemId = "item.leather", count = 4 }, { itemId = "item.cloth", count = 6 } },
		},
	},
	["quest.padded_through"] = {
		id = "quest.padded_through",
		order = 21,
		chapter = LINE,
		name = "Padded Through",
		description = "Finish the Padded set with leggings and boots of leather and reedcloth, and wear all four pieces into the Black fog.",
		prerequisite = "quest.walls_that_hold",
		objectives = {
			{ kind = "craft", recipeId = "recipe.padded_leggings", count = 1, flag = "fogRuns" },
			{ kind = "craft", recipeId = "recipe.padded_boots", count = 1, flag = "fogRuns" },
			{ kind = "equip", itemId = "item.padded_hood" },
			{ kind = "equip", itemId = "item.padded_vest" },
			{ kind = "equip", itemId = "item.padded_leggings", flag = "fogRuns" },
			{ kind = "equip", itemId = "item.padded_boots", flag = "fogRuns" },
		},
		-- Dressings and food for the Depot (Black Fog Regular). Guns run on durability alone.
		rewards = {
			xp = 2000,
			items = { { itemId = "item.field_dressing", count = 5 }, { itemId = "item.sealed_tin", count = 3 } },
		},
	},
	["quest.black_fog_regular"] = {
		id = "quest.black_fog_regular",
		order = 23,
		chapter = LINE,
		name = "Black Fog Regular",
		description = "Make the Ashfall Depot yours. Search its crates again and again, and thin out the Hollow that guard it.",
		prerequisite = "quest.padded_through",
		objectives = {
			{ kind = "loot", count = 30, locationId = "loc.ashfall_depot", flag = "fogRuns" },
			{ kind = "kill", count = 100, flag = "fogRuns" },
		},
		-- Dressings and tonics for the long last stand (Hold the Line).
		rewards = {
			xp = 2800,
			items = { { itemId = "item.field_dressing", count = 4 }, { itemId = "item.ember_tonic", count = 2 } },
		},
	},
	["quest.hold_the_line"] = {
		id = "quest.hold_the_line",
		order = 25,
		chapter = LINE,
		name = "Hold the Line",
		description = "Hold your ground against the Black fog. Put down five hundred Hollow, reach level 25, then tell Old Hale at Haven Square.",
		prerequisite = "quest.black_fog_regular",
		objectives = {
			{ kind = "kill", count = 500, flag = "fogRuns" },
			{ kind = "reachLevel", level = 25 },
		},
		rewards = {
			xp = 4000,
			items = { { itemId = "item.brass_gear", count = 3 }, { itemId = "item.trigger_group", count = 1 } },
		},
	},
}

--[[
	Chapter 4, "Iron Lungs" (quests 26-33; docs/CONTENT_2_0.md §3), behind Tuning.features.content2.
	LDoE's Survivor's Path has its "Radiation Protection" chapter at this point (rec5): gear that
	lets you breathe where you couldn't. It opens after Hold the Line and runs two lines side by
	side again: the home line (26, 28, 30, 32: the Blast Furnace, Fortified floors, Fortified
	walls, the Apothecary) and the fog line (27, 29, 31, 33: the Riveted set, the Ranger Pack, the Gas
	Mask, the deep Black). In the pacing model (tests/Pacing.spec) it runs to about day 30.
]]
local IRON = "Iron Lungs"

local function chapter4(def: Types.QuestDef)
	def.feature = "content2"
	Quests[def.id] = def
end

-- The home line. Each build objective unlocks with the quest before it, so the trail is
-- the order a base goes up in: the furnace, then the floors, the walls, and the Apothecary that
-- needs a Fortified floor.
chapter4({
	id = "quest.hotter_fires",
	order = 26,
	chapter = IRON,
	name = "Hotter Fires",
	description = "Iron is not enough any more. Build a Blast Furnace on a reinforced floor, feed it Embercoal, and roll Iron Ingots into Steel Plate.",
	prerequisite = "quest.hold_the_line",
	objectives = {
		{ kind = "build", pieceId = "build.blast_furnace", count = 1 },
		{ kind = "craft", recipeId = "recipe.steel_plate", count = 6 },
	},
	-- Coal for the furnace and rivets for the first Fortified floors (Steel Underfoot).
	rewards = {
		xp = 4500,
		items = { { itemId = "item.embercoal", count = 20 }, { itemId = "item.rivets", count = 8 } },
	},
})
chapter4({
	id = "quest.steel_floors",
	order = 28,
	chapter = IRON,
	name = "Steel Underfoot",
	description = "Plate your reinforced foundations in steel. A Fortified floor holds what nothing else will stand on.",
	prerequisite = "quest.hotter_fires",
	objectives = {
		{ kind = "build", pieceId = "build.foundation_fortified", count = 4 },
	},
	-- Wire and rivets for the walls (The Last Wall).
	rewards = {
		xp = 5000,
		items = { { itemId = "item.copper_wire", count = 6 }, { itemId = "item.rivets", count = 8 } },
	},
})
chapter4({
	id = "quest.last_wall",
	order = 30,
	chapter = IRON,
	name = "The Last Wall",
	description = "Raise Fortified walls and hang a Fortified door. Let the Black fog throw what it likes at them.",
	prerequisite = "quest.steel_floors",
	objectives = {
		{ kind = "build", pieceId = "build.wall_fortified", count = 8 },
		{ kind = "build", pieceId = "build.door_fortified", count = 1 },
	},
	-- Cloth and wire for the Apothecary (A Clean Room).
	rewards = {
		xp = 5500,
		items = { { itemId = "item.cloth", count = 4 }, { itemId = "item.copper_wire", count = 4 } },
	},
})
chapter4({
	id = "quest.clean_room",
	order = 32,
	chapter = IRON,
	name = "A Clean Room",
	description = "Set up an Apothecary on a Fortified floor. Press Emberberries into Antiseptic Tablets and pack two First-Aid Kits.",
	prerequisite = "quest.last_wall",
	objectives = {
		{ kind = "build", pieceId = "build.apothecary", count = 1 },
		{ kind = "craft", recipeId = "recipe.antiseptic", count = 4 },
		{ kind = "craft", recipeId = "recipe.first_aid_kit", count = 2 },
	},
	rewards = {
		xp = 6000,
		items = {
			{ itemId = "item.brass_gear", count = 3 },
			{ itemId = "item.coil_spring", count = 2 },
			{ itemId = "item.field_dressing", count = 5 },
		},
	},
})

-- The fog line.
chapter4({
	id = "quest.hide_and_rivet",
	order = 27,
	chapter = IRON,
	name = "Hide and Rivet",
	description = "Rivet plate over your Hidebound coat and leggings, and wear the Riveted Cuirass and Legguards into the fog.",
	prerequisite = "quest.hold_the_line",
	objectives = {
		{ kind = "craft", recipeId = "recipe.riveted_cuirass", count = 1 },
		{ kind = "craft", recipeId = "recipe.riveted_legguards", count = 1 },
		{ kind = "equip", itemId = "item.riveted_cuirass" },
		{ kind = "equip", itemId = "item.riveted_legguards" },
	},
	-- Leather and cloth for the Ranger Pack (Pack Mule).
	rewards = {
		xp = 4500,
		items = { { itemId = "item.leather", count = 6 }, { itemId = "item.cloth", count = 6 } },
	},
})
chapter4({
	id = "quest.pack_mule",
	order = 29,
	chapter = IRON,
	name = "Pack Mule",
	description = "Rebuild your Pack Frame with riveted stays and a hide body. The Ranger Pack carries fifteen more: fill it from ten Ashfall Depot crates.",
	prerequisite = "quest.hide_and_rivet",
	objectives = {
		{ kind = "craft", recipeId = "recipe.ranger_pack", count = 1 },
		{ kind = "equip", itemId = "item.ranger_pack" },
		{ kind = "loot", count = 10, locationId = "loc.ashfall_depot", flag = "fogRuns" },
	},
	-- Coal and glue for the Gas Mask's filter (Breathe Easy).
	rewards = {
		xp = 5000,
		items = { { itemId = "item.embercoal", count = 10 }, { itemId = "item.pitch_glue", count = 4 } },
	},
})
chapter4({
	id = "quest.breathe_easy",
	order = 31,
	chapter = IRON,
	name = "Breathe Easy",
	description = "Stitch a Gas Mask with an Embercoal filter, put it on, and put down two hundred Hollow in the Black fog. Watch the filter: when it's spent, so are you.",
	prerequisite = "quest.pack_mule",
	objectives = {
		{ kind = "craft", recipeId = "recipe.gas_mask", count = 1 },
		{ kind = "equip", itemId = "item.gas_mask" },
		{ kind = "travel", fogTier = 3, flag = "fogRuns" },
		{ kind = "kill", count = 200, flag = "fogRuns" },
	},
	rewards = {
		xp = 5500,
		items = { { itemId = "item.first_aid_kit", count = 2 }, { itemId = "item.ember_tonic", count = 1 } },
	},
})
chapter4({
	id = "quest.deep_black",
	order = 33,
	chapter = IRON,
	name = "The Deep Black",
	description = "Live in the Black fog. Strip the Ashfall Depot thirty crates deep, put down three hundred more Hollow, and grow into a veteran.",
	prerequisite = "quest.breathe_easy",
	objectives = {
		{ kind = "loot", count = 30, locationId = "loc.ashfall_depot", flag = "fogRuns" },
		{ kind = "kill", count = 300, flag = "fogRuns" },
		{ kind = "reachLevel", level = 28 },
	},
	rewards = {
		xp = 8000,
		items = { { itemId = "item.trigger_group", count = 2 }, { itemId = "item.brass_gear", count = 3 } },
	},
})

return Quests
