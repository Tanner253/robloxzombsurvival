--!strict
--[[
	The economy rescale's rules (docs/ECONOMY.md §10-11): the v0.1 data pinned to the spec,
	and the domain changes that carry it (yieldEvery, Loot.expected, food-first station
	lists, durability wear, fog-tier travel objectives, daily location quests, the station
	fallback, the v8 and outpost v3 save migrations and the new validator checks).
	Pacing itself is tests/Pacing.spec.
]]

local TestKit = require("./TestKit")
local Types = require("../src/shared/Types")
local Content = require("../src/shared/Data")
local Items = require("../src/shared/Data/Items")
local Recipes = require("../src/shared/Data/Recipes")
local Stations = require("../src/shared/Data/Stations")
local Nodes = require("../src/shared/Data/Nodes")
local BuildPieces = require("../src/shared/Data/BuildPieces")
local Tuning = require("../src/shared/Data/Tuning")
local Combat = require("../src/shared/Domain/Combat")
local Converter = require("../src/shared/Domain/Converter")
local DataValidator = require("../src/shared/Domain/DataValidator")
local Gathering = require("../src/shared/Domain/Gathering")
local Loot = require("../src/shared/Domain/Loot")
local Migrations = require("../src/shared/Domain/Migrations")
local OutpostSchema = require("../src/shared/Domain/OutpostSchema")
local PlayerSchema = require("../src/shared/Domain/PlayerSchema")
local Quests = require("../src/shared/Domain/Quests")
local Rng = require("../src/shared/Domain/Rng")
local StationFallback = require("../src/shared/StationFallback")
local TableUtil = require("../src/shared/Util/Table")

local T0 = 1_700_000_000

local function costOf(stacks: { Types.ItemStack }): { [string]: number }
	local result: { [string]: number } = {}
	for _, stack in stacks do
		result[stack.itemId] = (result[stack.itemId] or 0) + stack.count
	end
	return result
end

local function line(recipeId: string): (number, number, number, string?, number)
	local recipe = Recipes[recipeId]
	return recipe.inputs[1].count,
		recipe.outputs[1].count,
		recipe.craftSeconds,
		recipe.stationId,
		recipe.stationLevel or 1
end

local function brokenCopy(mutate: (content: any) -> ()): { string }
	local copy = TableUtil.deepCopy(Content) :: any
	mutate(copy)
	return DataValidator.validate(copy)
end

return function(test: TestKit.Register)
	-- The v0.1 data, pinned to the spec ----------------------------------------------------------
	test("§2.1: refinement ratios, timers and station levels", function()
		local cases: { { any } } = {
			{ "recipe.plank", 2, 1, 4 * 60, "station.woodworking_bench", 1 },
			{ "recipe.ironbark_plank", 5, 1, 20 * 60, "station.woodworking_bench", 2 },
			{ "recipe.stone_block", 3, 1, 5 * 60, "station.stonecutter", 1 },
			{ "recipe.iron_ingot", 2, 1, 4 * 60, "station.smelter", 1 },
			{ "recipe.iron_ingot_from_scrap", 5, 1, 4 * 60, "station.smelter", 1 },
			{ "recipe.copper_ingot", 5, 1, 60 * 60, "station.smelter", 2 },
			{ "recipe.scrap_plate", 1, 1, 20 * 60, "station.workbench", 1 },
			{ "recipe.rivets", 1, 2, 4 * 60, "station.workbench", 1 },
			{ "recipe.copper_wire", 1, 2, 10 * 60, "station.workbench", 2 },
			{ "recipe.embercoal", 2, 1, 4 * 60, "station.campfire", 1 },
			{ "recipe.pitch_glue", 2, 1, 4 * 60, "station.campfire", 1 },
			{ "recipe.cloth", 2, 1, 2 * 60, "station.workbench", 1 },
		}
		for _, case in cases do
			local input, output, seconds, stationId, level = line(case[1])
			TestKit.equal(input, case[2], `{case[1]} input`)
			TestKit.equal(output, case[3], `{case[1]} output`)
			TestKit.equal(seconds, case[4], `{case[1]} timer`)
			TestKit.equal(stationId, case[5], `{case[1]} station`)
			TestKit.equal(level, case[6], `{case[1]} station level`)
		end
		TestKit.equal(Recipes["recipe.scrap_plate"].inputs[1].itemId, "item.iron_ingot", "plates are hammered ingots")
	end)

	test("§8.1: durability; guns break fast, nothing outlasts LDoE", function()
		local expected: { [string]: number } = {
			["item.stone_hatchet"] = 40,
			["item.stone_pick"] = 40,
			["item.forged_hatchet"] = 75,
			["item.forged_pick"] = 75,
			["item.spiked_club"] = 80,
			["item.scrapblade"] = 80,
			["item.shortbow"] = 40,
			["item.padded_hood"] = 80,
			["item.padded_vest"] = 100,
			["item.machete"] = 70,
			["item.fire_axe"] = 50,
			-- F-14: with no ammo a gun's durability is its shot count, so the floors went up.
			["item.pipe_pistol"] = 150,
			["item.scrap_shotgun"] = 90,
			["item.flare_pistol"] = 72,
		}
		for itemId, durability in expected do
			TestKit.equal(Items[itemId].durability, durability, itemId)
		end
		TestKit.equal(Items["item.forged_hatchet"].tool and Items["item.forged_hatchet"].tool.tier, 2, "forged tier")
	end)

	test("§8.2-8.3: re-craft sinks; no ammo, and the Signal Flare is hand-made", function()
		TestKit.equal(costOf(Recipes["recipe.shortbow"].inputs)["item.pitch_glue"], 2, "Shortbow glue")
		for _, recipeId in { "recipe.scrapblade", "recipe.machete", "recipe.padded_vest" } do
			TestKit.equal(costOf(Recipes[recipeId].inputs)["item.pitch_glue"], 1, `{recipeId} glue`)
		end
		TestKit.equal(costOf(Recipes["recipe.field_dressing"].inputs)["item.cloth"], 5, "Field Dressing cloth")
		-- DECISIONS 2026-11-08 (F-13): guns and the bow run on durability; no rounds, no press.
		for _, recipeId in { "recipe.blackpowder", "recipe.light_rounds", "recipe.shells", "recipe.arrow" } do
			TestKit.equal(Recipes[recipeId], nil, `{recipeId} is gone`)
		end
		TestKit.equal(Stations["station.ammo_press"], nil, "no Ammo Press station")
		TestKit.equal(BuildPieces["build.ammo_press"], nil, "no Ammo Press piece")
		-- The flare extract's Signal Flare keeps its raw cost: 2 niter a flare, by hand.
		TestKit.equal(Recipes["recipe.flare"].stationId, nil, "the Signal Flare is made by hand")
		TestKit.equal(costOf(Recipes["recipe.flare"].inputs)["item.niter"], 4, "4 niter")
		TestKit.equal(Recipes["recipe.flare"].outputs[1].count, 2, "make 2 flares")
	end)

	test("§1: node hits and yields; the home plot", function()
		TestKit.equal(Nodes["node.pine_tree"].hits, 3, "pine")
		TestKit.equal(Nodes["node.boulder"].hits, 3, "boulder")
		TestKit.equal(Nodes["node.ember_bush"].yields[1].perHit, 3, "berry bush")
		TestKit.deepEqual(
			Gathering.expectedYield(Nodes["node.ironbark_tree"]),
			{ ["item.ironbark_log"] = 2 },
			"ironbark"
		)
		TestKit.deepEqual(
			Gathering.expectedYield(Nodes["node.ironstone_rock"]),
			{ ["item.ironstone"] = 3 },
			"ironstone"
		)
		TestKit.deepEqual(
			Gathering.expectedYield(Nodes["node.malachite_vein"]),
			{ ["item.malachite"] = 2 },
			"malachite"
		)
		TestKit.equal((Nodes["node.ironbark_tree"].tool :: Types.ToolStats).tier, 2, "ironbark needs a forged hatchet")
		TestKit.equal((Nodes["node.malachite_vein"].tool :: Types.ToolStats).tier, 2, "malachite needs a forged pick")
	end)

	test("§3 and §5.2: station and building costs", function()
		TestKit.equal(Stations["station.woodworking_bench"].name, "Saw Bench", "LDoE's name is not ours")
		TestKit.equal(BuildPieces["build.woodworking_bench"].name, "Saw Bench", "the piece too")
		TestKit.deepEqual(
			costOf(Stations["station.woodworking_bench"].levels[2].upgradeCost),
			{ ["item.plank"] = 20, ["item.scrap_plate"] = 6, ["item.rivets"] = 4 },
			"Saw Bench L2"
		)
		TestKit.deepEqual(
			costOf(Stations["station.woodworking_bench"].levels[3].upgradeCost),
			{ ["item.ironbark_plank"] = 20, ["item.scrap_plate"] = 12, ["item.brass_gear"] = 2 },
			"Saw Bench L3"
		)
		TestKit.deepEqual(
			costOf(Stations["station.smelter"].levels[2].upgradeCost),
			{ ["item.stone_block"] = 20, ["item.scrap_plate"] = 10, ["item.rivets"] = 4 },
			"Smelter L2"
		)
		TestKit.deepEqual(
			costOf(BuildPieces["build.stonecutter"].cost),
			{ ["item.timber"] = 8, ["item.stone"] = 10, ["item.rope"] = 2 },
			"Stonecutter"
		)
		TestKit.deepEqual(
			costOf(BuildPieces["build.workbench"].cost),
			{ ["item.plank"] = 6, ["item.stone_block"] = 3, ["item.rope"] = 4 },
			"Workbench"
		)
		local pieces: { [string]: { [string]: number } } = {
			["build.foundation_scrap"] = { ["item.plank"] = 6, ["item.stone_block"] = 4, ["item.scrap_plate"] = 3 },
			["build.wall_scrap"] = { ["item.plank"] = 8, ["item.stone_block"] = 4, ["item.scrap_plate"] = 2 },
			["build.window_scrap"] = { ["item.plank"] = 8, ["item.stone_block"] = 4, ["item.scrap_plate"] = 2 },
			["build.doorway_scrap"] = { ["item.plank"] = 6, ["item.stone_block"] = 4, ["item.scrap_plate"] = 2 },
			["build.door_scrap"] = { ["item.plank"] = 6, ["item.scrap_plate"] = 3, ["item.rivets"] = 4 },
			["build.foundation_reinforced"] = {
				["item.stone_block"] = 12,
				["item.scrap_plate"] = 8,
				["item.rivets"] = 4,
			},
			["build.wall_reinforced"] = {
				["item.stone_block"] = 12,
				["item.ironbark_plank"] = 7,
				["item.scrap_plate"] = 4,
				["item.rivets"] = 4,
				["item.copper_wire"] = 2,
			},
			["build.door_reinforced"] = {
				["item.ironbark_plank"] = 7,
				["item.scrap_plate"] = 6,
				["item.rivets"] = 6,
				["item.copper_wire"] = 4,
				["item.coil_spring"] = 1,
			},
		}
		for pieceId, expected in pieces do
			TestKit.deepEqual(costOf(BuildPieces[pieceId].cost), expected, pieceId)
		end
		local fuel = Stations["station.smelter"].fuel :: Types.StationFuel
		TestKit.equal(Converter.burnSeconds(Stations["station.smelter"], "item.embercoal"), 320, "Embercoal burns 5:20")
		TestKit.equal(Converter.burnSeconds(Stations["station.smelter"], "item.ironbark_log"), 120, "a log burns 2 min")
		TestKit.truthy(table.find(fuel.itemIds, "item.ironbark_plank") == nil, "tier-2 planks are never fuel")
	end)

	test("§11.2: the three tier-2 quests and their unlocks", function()
		TestKit.equal(Content.Quests["quest.heartwood"].prerequisite, "quest.the_dense_fog")
		TestKit.equal(Content.Quests["quest.green_vein"].prerequisite, "quest.the_dense_fog")
		TestKit.equal(Content.Quests["quest.into_the_black"].prerequisite, "quest.green_vein")
		TestKit.equal(Content.Quests["quest.into_the_black"].rewards.xp, 1000)
		local unlocks: { [string]: string } = {
			["recipe.forged_hatchet"] = "quest.the_dense_fog",
			["recipe.forged_pick"] = "quest.the_dense_fog",
			["recipe.ironbark_plank"] = "quest.heartwood",
			["recipe.copper_ingot"] = "quest.green_vein",
			["recipe.copper_wire"] = "quest.green_vein",
			["recipe.iron_ingot"] = "quest.into_the_fog",
			["recipe.iron_ingot_from_scrap"] = "quest.into_the_fog",
			["recipe.embercoal"] = "quest.keep_the_fire",
		}
		for recipeId, questId in unlocks do
			TestKit.deepEqual(Recipes[recipeId].unlock, { kind = "quest", questId = questId }, recipeId)
		end
		TestKit.equal(Content.Levels[8].xp, 16000, "level 8")
		TestKit.equal(Content.Levels[15].xp, 57000, "level 15")
		TestKit.equal(Content.Levels[20].xp, 115000, "level 20")
	end)

	test("levels 21-30 carry the §9.3 curve on: every step longer than the last, half rewarded", function()
		local levels = Content.Levels
		TestKit.equal(#levels, 30, "the launch cap")
		for index = 17, #levels do
			local step = levels[index].xp - levels[index - 1].xp
			local before = levels[index - 1].xp - levels[index - 2].xp
			TestKit.truthy(step > before, `level {index}: a {step} XP step after {before} (a flat tail)`)
		end
		local rewarded = 0
		for index = 21, 30 do
			rewarded += if levels[index].rewards then 1 else 0
		end
		TestKit.equal(rewarded, 5, "rewards on half of levels 21-30")
		TestKit.truthy(levels[30].rewards ~= nil, "the cap pays")
	end)

	-- Domain changes -------------------------------------------------------------------------------
	test("yieldEvery: Ironbark yields a log on every 2nd hit; XP is still per hit", function()
		local def = Nodes["node.ironbark_tree"]
		local node = Gathering.new(def)
		local rng = Rng.new(1)
		local yielded: { number } = {}
		for hit = 1, def.hits do
			local nextNode, yields = Gathering.hit(node, def, rng, T0, Gathering.NEVER)
			node = nextNode :: Gathering.Node
			yielded[hit] = if yields[1] then yields[1].count else 0
		end
		TestKit.deepEqual(yielded, { 0, 1, 0, 1 }, "logs on hits 2 and 4")
		TestKit.equal(Gathering.yieldsOnHit(Nodes["node.pine_tree"], 3), true, "pines yield every hit")
	end)

	test("Loot.expected: mean rolls, weights, nested tables and guaranteed stacks", function()
		local tables: any = {
			["loot.a"] = {
				id = "loot.a",
				rolls = { min = 1, max = 3 },
				entries = {
					{ itemId = "item.x", weight = 3, min = 1, max = 3 },
					{ tableId = "loot.b", weight = 1, min = 2, max = 2 },
				},
				guaranteed = { { itemId = "item.z", count = 2 } },
			},
			["loot.b"] = {
				id = "loot.b",
				rolls = { min = 1, max = 1 },
				entries = { { itemId = "item.y", weight = 1, min = 1, max = 1 } },
			},
		}
		local ev = Loot.expected(tables, "loot.a")
		TestKit.equal(ev["item.x"], 2 * 0.75 * 2, "2 rolls x 3/4 x 2 each")
		TestKit.equal(ev["item.y"], 2 * 0.25 * 2, "a nested table opened twice per pick")
		TestKit.equal(ev["item.z"], 2, "guaranteed once")
		TestKit.equal(Loot.expected(tables, "loot.a", 1.5)["item.x"], 4.5, "the band multiplier scales rolls")
	end)

	test("the Campfire lists food and drink before coal and glue (§8.4)", function()
		local def = Stations["station.campfire"]
		local keys: { string } = {}
		for _, entry in Converter.lines(def, Recipes, Items) do
			table.insert(keys, entry.key)
		end
		local coal = table.find(keys, "recipe.embercoal") :: number
		for _, food in { "recipe.boiled_water", "recipe.cooked_meat", "recipe.roasted_ashroot", "recipe.ember_tea" } do
			TestKit.truthy((table.find(keys, food) :: number) < coal, `{food} before Embercoal`)
		end
	end)

	test("durability wear: light 1, heavy 2, every round 1; warnings at 25% and 10%", function()
		local combat = Tuning.combat
		TestKit.equal(Combat.wear("light", combat), 1)
		TestKit.equal(Combat.wear("heavy", combat), 2)
		TestKit.equal(Combat.wear("shot", combat), 1)
		TestKit.equal(Combat.wear("arrow", combat), 1)
		TestKit.equal(Combat.wearWarning(14, 12, 50, combat), 1, "a Pipe Pistol crossing 12.5")
		TestKit.equal(Combat.wearWarning(6, 5, 50, combat), 2, "and 5")
		TestKit.equal(Combat.wearWarning(30, 29, 50, combat), nil, "no line crossed")
		TestKit.equal(Combat.wearWarning(14, 4, 50, combat), 2, "the deepest line wins")
	end)

	test("a travel objective can name a fog tier: 'any Black location'", function()
		local defs: { [string]: Types.QuestDef } = { ["quest.into_the_black"] = Content.Quests["quest.into_the_black"] }
		local state = Quests.open(Quests.newState(), {})
		state.active["quest.into_the_black"] = { progress = {} }
		local flags = { fogRuns = true }
		state = Quests.record(state, defs, flags, { kind = "travel", locationId = "loc.sunken_quarry", fogTier = 2 })
		TestKit.equal(state.active["quest.into_the_black"].progress["2"], nil, "Dense does not count")
		state = Quests.record(state, defs, flags, { kind = "travel", locationId = "loc.ashfall_depot", fogTier = 3 })
		TestKit.equal(state.active["quest.into_the_black"].progress["2"], 1, "Black does")
	end)

	test("location quests pay once per UTC day, never once per lobby (§6.2)", function()
		local config = Tuning.locationQuests
		local log: Quests.LocationQuestLog = {}
		local day = 24 * 60 * 60
		local now = 20_000 * day + 3600
		TestKit.equal(Quests.locationQuestOpen(log, "quest.pine_hunters_trail", now, config), true)
		log = Quests.markLocationQuest(log, "quest.pine_hunters_trail", now, config)
		TestKit.equal(Quests.locationQuestOpen(log, "quest.pine_hunters_trail", now + 600, config), false, "next lobby")
		TestKit.equal(Quests.locationQuestOpen(log, "quest.quarry_salt_of_stone", now, config), true, "per quest")
		TestKit.equal(Quests.locationQuestOpen(log, "quest.pine_hunters_trail", now + day, config), true, "next day")
	end)

	test("the station fallback moves a pending station's lines and nothing else", function()
		local content: any = { Recipes = Recipes, Tuning = Tuning }
		StationFallback.apply(content)
		for stationId, target in Tuning.stationFallback do
			for id, recipe in content.Recipes do
				TestKit.truthy(recipe.stationId ~= stationId, `{id} left {stationId}`)
				if Recipes[id].stationId == stationId then
					TestKit.equal(recipe.stationId, target, id)
					TestKit.equal(recipe.inputs[1].count, Recipes[id].inputs[1].count, `{id} keeps its ratio`)
				end
			end
		end
		TestKit.equal(content.Recipes["recipe.plank"], Recipes["recipe.plank"], "untouched lines are shared")
		TestKit.equal(Recipes["recipe.iron_ingot"].stationId, "station.smelter", "Data/Recipes itself is unchanged")
	end)

	-- Save migrations ------------------------------------------------------------------------------
	test("v7 -> v8: a station mid-way through a changed line settles into the inbox", function()
		local data: any = PlayerSchema.template()
		data.version = 7
		data.locationQuests = nil
		local bench = Converter.new(Stations["station.workbench"], T0)
		bench.input = { itemId = "item.scrap", count = 10 } -- v7: 3 scrap -> 1 plate in 4 min
		bench.output[1] = { itemId = "item.scrap_plate", count = 2 }
		local saw = Converter.new(Stations["station.woodworking_bench"], T0)
		saw.level = 2
		saw.input = { itemId = "item.timber", count = 5 } -- v7: 1 timber -> 1 plank in 4 min
		local fire = Converter.new(Stations["station.campfire"], T0)
		fire.input = { itemId = "item.murky_water", count = 4 } -- unchanged line: left alone
		fire.fuel = { itemId = "item.sticks", count = 6 }
		data.stations = { s1 = bench, s2 = saw, s3 = fire }
		PlayerSchema.migrateToV8(data, T0 + 8 * 60)
		local got: { [string]: number } = {}
		for _, entry in data.inbox do
			got[entry.itemId] = (got[entry.itemId] or 0) + entry.count
			TestKit.equal(entry.source, "Update", "source")
		end
		-- 8 minutes: the Workbench finished 2 old batches (6 scrap), the Saw Bench 2 planks.
		TestKit.equal(got["item.scrap_plate"], 4, "2 waiting + 2 finished plates")
		TestKit.equal(got["item.scrap"], 4, "unconverted scrap back")
		TestKit.equal(got["item.plank"], 2, "planks finished under the old rule")
		TestKit.equal(got["item.timber"], 3, "timber back")
		TestKit.equal(data.stations.s1.input.count, 0, "the Workbench restarts empty")
		TestKit.equal(data.stations.s2.level, 2, "levels are kept")
		TestKit.equal(data.stations.s3.input.count, 4, "an unchanged line keeps running")
		TestKit.deepEqual(data.locationQuests, {}, "location quest log")
	end)

	test("v7 -> v8: durability over the new maximum is clamped everywhere; stacks never change", function()
		local data: any = PlayerSchema.template()
		data.version = 7
		data.inventory.equipment.weapon = { itemId = "item.pipe_pistol", count = 1, durability = 200 }
		data.inventory.pockets[1] = { itemId = "item.stone_hatchet", count = 1, durability = 30 }
		data.inventory.pockets[2] = { itemId = "item.timber", count = 17 }
		data.storage = { c1 = { { itemId = "item.scrapblade", count = 1, durability = 110 } } }
		data.inbox =
			{ { id = "i1", itemId = "item.padded_vest", count = 1, durability = 150, source = "Quest", at = 0 } }
		data.inboxSeq = 1
		local ok, reason = Migrations.run(data, PlayerSchema.migrations, PlayerSchema.VERSION)
		TestKit.truthy(ok, reason)
		TestKit.equal(
			data.inventory.equipment.weapon.durability,
			150,
			"a Pipe Pistol over its maximum is clamped to it"
		)
		TestKit.equal(data.inventory.pockets[1].durability, 30, "already under the maximum")
		TestKit.equal(data.inventory.pockets[2].count, 17, "stack untouched")
		TestKit.equal(data.storage.c1[1].durability, 80, "crate")
		TestKit.equal(data.inbox[1].durability, 100, "inbox")
		TestKit.equal(data.version, PlayerSchema.VERSION, "migrated through every step after v8")
	end)

	test("outpost v2 -> v3: home nodes with more hits left than the node now has are whole again", function()
		local data: any = {
			version = 2,
			layout = OutpostSchema.template().layout,
			seeded = true,
			projects = {},
			nodes = {
				["node.boulder#1"] = { hitsLeft = 4, respawnAt = 0 }, -- 4 of the old 5
				["node.boulder#2"] = { hitsLeft = 2, respawnAt = 0 },
				["node.pine_tree#3"] = { hitsLeft = 0, respawnAt = Gathering.NEVER },
			},
		}
		local ok, reason = Migrations.run(data, OutpostSchema.migrations, OutpostSchema.VERSION)
		TestKit.truthy(ok, reason)
		TestKit.equal(data.nodes["node.boulder#1"], nil, "whole: no save")
		TestKit.equal(data.nodes["node.boulder#2"].hitsLeft, 2, "partly mined stays")
		TestKit.equal(data.nodes["node.pine_tree#3"].hitsLeft, 0, "depleted stays depleted")
	end)

	test("v10 -> v11: no ammo; every removed round becomes scrap one for one, nothing is lost", function()
		local data: any = PlayerSchema.template()
		data.version = 10
		data.inventory.pockets[1] = { itemId = "item.light_rounds", count = 60 }
		data.inventory.pockets[2] = { itemId = "item.arrow", count = 20 }
		data.inventory.backpack[1] = { itemId = "item.shells", count = 30 }
		data.inventory.backpack[2] = { itemId = "item.flare", count = 4 } -- a signal, not a round: kept
		data.storage = { c1 = { { itemId = "item.blackpowder", count = 45 }, { itemId = "item.timber", count = 7 } } }
		data.inbox = { { id = "i1", itemId = "item.light_rounds", count = 120, source = "Shop", at = 0 } }
		data.inboxSeq = 1
		local press = Converter.new(Stations["station.smelter"], T0)
		press.stationId = "station.ammo_press" -- a v10 Ammo Press, mid-batch
		press.input = { itemId = "item.niter", count = 6 }
		press.fuel = { itemId = "item.fatwood", count = 3 }
		press.output[1] = { itemId = "item.blackpowder", count = 5 }
		local fire = Converter.new(Stations["station.campfire"], T0)
		fire.input = { itemId = "item.murky_water", count = 2 }
		data.stations = { s1 = press, s2 = fire }
		data.unlocks.recipes = { ["recipe.light_rounds"] = true, ["recipe.flare"] = true }
		data.recipeMarks.favourites = { ["recipe.shells"] = true }
		local ok, reason = Migrations.run(data, PlayerSchema.migrations, PlayerSchema.VERSION)
		TestKit.truthy(ok, reason)
		TestKit.equal(data.version, PlayerSchema.VERSION, "version")
		local scrapStack = Items["item.scrap"].stackSize
		TestKit.deepEqual(data.inventory.pockets[1], { itemId = "item.scrap", count = scrapStack }, "rounds, capped")
		TestKit.deepEqual(data.inventory.pockets[2], { itemId = "item.scrap", count = 20 }, "arrows")
		TestKit.deepEqual(data.inventory.backpack[1], { itemId = "item.scrap", count = 30 }, "shells")
		TestKit.deepEqual(data.inventory.backpack[2], { itemId = "item.flare", count = 4 }, "Signal Flares stay")
		TestKit.deepEqual(data.storage.c1[1], { itemId = "item.scrap", count = 45 }, "crate powder")
		TestKit.deepEqual(data.storage.c1[2], { itemId = "item.timber", count = 7 }, "other stacks untouched")
		TestKit.equal(data.stations.s1, nil, "the Ammo Press record goes")
		TestKit.equal(data.stations.s2.input.count, 2, "other stations keep running")
		local got: { [string]: number } = {}
		for _, entry in data.inbox do
			got[entry.itemId] = (got[entry.itemId] or 0) + entry.count
			TestKit.equal(entry.durability, nil, "no durability on scrap")
		end
		-- The inbox: the old row (120), the pocket's overflow and the press's powder (5).
		TestKit.equal(got["item.scrap"], 120 + (60 - scrapStack) + 5, "scrap in the inbox")
		TestKit.equal(got["item.niter"], 6, "the press's input comes back")
		TestKit.equal(got["item.fatwood"], 3, "and its fuel")
		TestKit.equal(got["item.light_rounds"], nil, "no rounds left anywhere")
		TestKit.equal(data.unlocks.recipes["recipe.light_rounds"], nil, "removed recipe unlock dropped")
		TestKit.equal(data.unlocks.recipes["recipe.flare"], true, "the flare recipe stays unlocked")
		TestKit.equal(data.recipeMarks.favourites["recipe.shells"], nil, "removed favourite dropped")
		local held = 0
		for _, stack in
			{ data.inventory.pockets[1], data.inventory.pockets[2], data.inventory.backpack[1], data.storage.c1[1] }
		do
			held += stack.count
		end
		TestKit.equal(held + got["item.scrap"], 60 + 20 + 30 + 45 + 120 + 5, "one scrap for every round")
	end)

	test("outpost v4 -> v5: a placed Ammo Press comes off the plot; other pieces stay", function()
		local data: any = {
			version = 4,
			layout = {
				v = OutpostSchema.template().layout.v,
				n = 3,
				t = T0,
				p = { "build.ammo_press", "build.pitch_torch" },
				d = { 1, 1, 0, 0, 0, 450, 0, 0, 2, 2, 0, 4, 4, 100, 5, 0 },
			},
			seeded = true,
			nodes = {},
			projects = {},
		}
		local ok, reason = Migrations.run(data, OutpostSchema.migrations, OutpostSchema.VERSION)
		TestKit.truthy(ok, reason)
		TestKit.deepEqual(data.layout.d, { 2, 2, 0, 4, 4, 100, 5, 0 }, "only the torch is left")
	end)

	-- Validator ------------------------------------------------------------------------------------
	test("validator: yieldEvery must divide hits", function()
		local errors = brokenCopy(function(c)
			c.Nodes["node.ironbark_tree"].yieldEvery = 3
		end)
		TestKit.anyContains(
			errors,
			"Nodes['node.ironbark_tree']: yieldEvery must be a positive integer that divides hits"
		)
	end)

	test("validator: one line per input on a station", function()
		local errors = brokenCopy(function(c)
			local copy = TableUtil.deepCopy(c.Recipes["recipe.plank"])
			copy.id = "recipe.plank_twice"
			c.Recipes["recipe.plank_twice"] = copy
		end)
		TestKit.anyContains(errors, "already converts 'item.timber'")
	end)

	test("validator: an upgrade can't need what only that level makes", function()
		local errors = brokenCopy(function(c)
			table.insert(c.Stations["station.woodworking_bench"].levels[2].upgradeCost, {
				itemId = "item.ironbark_plank",
				count = 5,
			})
		end)
		TestKit.anyContains(errors, "'item.ironbark_plank' is only made at this station's level 2 or above")
	end)

	test("validator: a station's own cost can't need what only it makes", function()
		local errors = brokenCopy(function(c)
			for _, recipe in c.Recipes do
				if recipe.id == "recipe.stone_block" then
					recipe.stationId = "station.workbench"
				end
			end
			c.Tuning.stationFallback = {}
		end)
		TestKit.anyContains(
			errors,
			"BuildPieces['build.workbench'].cost: 'item.stone_block' is only made at 'station.workbench' itself"
		)
	end)

	test("validator: travel objectives name a location or a fog tier that exists", function()
		local errors = brokenCopy(function(c)
			c.Quests["quest.into_the_black"].objectives[2].fogTier = 9
		end)
		TestKit.anyContains(errors, "no location is in fog tier 9")
		local both = brokenCopy(function(c)
			c.Quests["quest.into_the_black"].objectives[2].locationId = "loc.ashfall_depot"
		end)
		TestKit.anyContains(both, "names a locationId or a fogTier, not both")
	end)
end
