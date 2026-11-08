--!strict
--[[
	The data validator as a test. The first case checks the real content: any broken
	reference in src/shared/Data fails this test and therefore the build. The other
	cases break one reference in a copy of the content and assert it is caught.
]]

local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local DataValidator = require("../src/shared/Domain/DataValidator")
local Energy = require("../src/shared/Domain/Energy")
local Grid = require("../src/shared/Domain/Grid")
local Survival = require("../src/shared/Domain/Survival")
local TableUtil = require("../src/shared/Util/Table")
local Travel = require("../src/shared/Domain/Travel")

local function brokenCopy(mutate: (content: any) -> ()): { string }
	local copy = TableUtil.deepCopy(Content) :: any
	mutate(copy)
	return DataValidator.validate(copy)
end

local function count(dict: { [string]: any }): number
	local total = 0
	for _ in dict do
		total += 1
	end
	return total
end

return function(test: TestKit.Register)
	test("all content in src/shared/Data is valid", function()
		local errors = DataValidator.validate(Content)
		if #errors > 0 then
			error(`{#errors} content error(s):\n        ` .. table.concat(errors, "\n        "), 0)
		end
	end)

	test("content is frozen at load", function()
		TestKit.truthy(table.isfrozen(Content.Items["item.timber"]), "Items entry frozen")
		TestKit.truthy(table.isfrozen(Content.Levels), "Levels frozen")
	end)

	test("MVP content covers the GAME_DESIGN scope", function()
		local tiers: { [number]: number } = {}
		local rotating = 0
		for _, location in Content.Locations do
			if location.availability.kind == "rotating" then
				rotating += 1
			else
				tiers[location.fogTier] = (tiers[location.fogTier] or 0) + 1
			end
		end
		TestKit.equal(tiers[1], 1, "Light locations")
		TestKit.equal(tiers[2], 1, "Dense locations")
		TestKit.equal(tiers[3], 1, "Black locations")
		TestKit.equal(rotating, 1, "rotating event locations")
		TestKit.equal(count(Content.Enemies), 3, "Hollow types")
		TestKit.equal(#Content.Levels, 20, "player levels")
		TestKit.truthy(count(Content.Quests) >= 8 and count(Content.Quests) <= 10, "8-10 starter quests")
		TestKit.equal(count(Content.Products), 4, "shop products")

		local structural: { [string]: { [number]: boolean } } = {}
		for _, piece in Content.BuildPieces do
			if piece.kind ~= "station" and piece.kind ~= "storage" then
				structural[piece.kind] = structural[piece.kind] or {}
				structural[piece.kind][piece.tier] = true
			end
		end
		for _, kind in { "foundation", "wall", "doorway", "door", "window" } do
			local byTier = structural[kind] or {}
			TestKit.truthy(byTier[1] and byTier[2] and byTier[3], `{kind} in all 3 tiers`)
		end
	end)

	test("Tuning sections and locations plug straight into the Domain modules", function()
		local tuning = Content.Tuning
		-- Energy: a Run to the Black fog regenerates in 22 x 5 min.
		local energy = Energy.spend({ value = tuning.energy.cap, updatedAt = 0 }, 0, tuning.energy, 22)
		TestKit.truthy(energy, "spend")
		TestKit.equal(Energy.secondsUntilFull(energy :: any, 0, tuning.energy), 22 * 5 * 60, "regen time")
		-- Survival: a full thirst meter lasts about 18 active minutes.
		local meters = Survival.new(0, tuning.survival)
		local thirstSeconds = Survival.secondsUntil(meters, tuning.survival, "thirst", 0)
		TestKit.truthy(thirstSeconds > 17 * 60 and thirstSeconds < 19 * 60, `thirst lasts {thirstSeconds} s`)
		-- Travel: Run and Walk to every location.
		for _, location in Content.Locations do
			TestKit.equal(Travel.plan(location, "run", tuning.travel).energyCost, location.energyCost, location.id)
			TestKit.equal(Travel.plan(location, "walk", tuning.travel).seconds, location.walkSeconds, location.id)
		end
		-- Grid: our window and door kinds land on the layers Grid expects.
		TestKit.equal(Grid.layerOf(Content.BuildPieces["build.window_scrap"]), "frame", "window layer")
		TestKit.equal(Grid.layerOf(Content.BuildPieces["build.door_reinforced"]), "fill", "door layer")
	end)

	test("catches an unknown item in a recipe input", function()
		local errors = brokenCopy(function(c)
			c.Recipes["recipe.stone_hatchet"].inputs[1].itemId = "item.does_not_exist"
		end)
		TestKit.anyContains(errors, "Recipes['recipe.stone_hatchet'].inputs[1]: unknown item 'item.does_not_exist'")
	end)

	test("catches an unknown station on a recipe", function()
		local errors = brokenCopy(function(c)
			c.Recipes["recipe.plank"].stationId = "station.missing"
		end)
		TestKit.anyContains(errors, "unknown station 'station.missing'")
	end)

	test("catches an unknown item in a loot entry", function()
		local errors = brokenCopy(function(c)
			c.LootTables["loot.pine_crate"].entries[2].itemId = "item.ghost"
		end)
		TestKit.anyContains(errors, "LootTables['loot.pine_crate'].entries[2]: unknown item 'item.ghost'")
	end)

	test("catches an unknown loot table on a location container", function()
		local errors = brokenCopy(function(c)
			c.Locations["loc.pine_hollow"].containers[1].lootTableId = "loot.nowhere"
		end)
		TestKit.anyContains(errors, "unknown loot table 'loot.nowhere'")
	end)

	test("catches broken node, enemy and enemy loot references", function()
		local errors = brokenCopy(function(c)
			c.Locations["loc.pine_hollow"].nodes[1].nodeId = "node.ghost"
			c.Locations["loc.sunken_quarry"].enemySpawns[1].enemyId = "enemy.ghost"
			c.Enemies["enemy.bloater"].lootTableId = "loot.ghost"
		end)
		TestKit.anyContains(errors, "unknown node 'node.ghost'")
		TestKit.anyContains(errors, "unknown enemy 'enemy.ghost'")
		TestKit.anyContains(errors, "Enemies['enemy.bloater']: unknown loot table 'loot.ghost'")
	end)

	test("catches an unknown item in a product grant", function()
		local errors = brokenCopy(function(c)
			c.Products["product.resource_pack"].grants[1].itemId = "item.free_robux"
		end)
		TestKit.anyContains(errors, "unknown item 'item.free_robux'")
	end)

	test("catches broken build piece upgrade and station links", function()
		local errors = brokenCopy(function(c)
			c.BuildPieces["build.wall_wood"].upgradesTo = "build.wall_unobtainium"
			c.BuildPieces["build.workbench"].stationId = nil
		end)
		TestKit.anyContains(errors, "unknown upgradesTo piece 'build.wall_unobtainium'")
		TestKit.anyContains(errors, "station pieces need a stationId")
	end)

	test("catches unknown items in station costs, fuel and salvage", function()
		local errors = brokenCopy(function(c)
			c.Stations["station.workbench"].levels[2].upgradeCost[1].itemId = "item.nope"
			c.Stations["station.campfire"].fuel.itemIds[1] = "item.also_nope"
			c.Stations["station.recycler"].salvage[1].outputs[1].itemId = "item.still_nope"
		end)
		TestKit.anyContains(errors, "unknown item 'item.nope'")
		TestKit.anyContains(errors, "unknown item 'item.also_nope'")
		TestKit.anyContains(errors, "unknown item 'item.still_nope'")
	end)

	test("catches a key that does not match its id or prefix", function()
		local errors = brokenCopy(function(c)
			c.Items["item.timber"].id = "item.wood"
			c.Items["wood_no_prefix"] = TableUtil.deepCopy(c.Items["item.stone"])
			c.Items["wood_no_prefix"].id = "wood_no_prefix"
		end)
		TestKit.anyContains(errors, "id field is 'item.wood', expected 'item.timber'")
		TestKit.anyContains(errors, "Items['wood_no_prefix']: ID must look like 'item.snake_case'")
	end)

	test("catches bad values", function()
		local errors = brokenCopy(function(c)
			c.Items["item.timber"].stackSize = 0
			c.LootTables["loot.quarry_toolbox"].entries[1].min = 9
		end)
		TestKit.anyContains(errors, "stackSize must be a positive integer")
		TestKit.anyContains(errors, "need integers 0 <= min <= max, max >= 1")
	end)

	test("catches item fields that don't match the category", function()
		local errors = brokenCopy(function(c)
			c.Items["item.shortbow"].weapon.ammoItemId = "item.timber"
			c.Items["item.padded_vest"].equipSlot = "weapon"
			c.Items["item.stone_pick"].tool = nil
		end)
		TestKit.anyContains(errors, "'item.timber' is not an ammo item")
		TestKit.anyContains(errors, "Items['item.padded_vest']: armor needs equipSlot")
		TestKit.anyContains(errors, "Items['item.stone_pick']: tool stats are required on tools")
	end)

	test("catches a node that no tool can harvest", function()
		local errors = brokenCopy(function(c)
			c.Nodes["node.boulder"].tool.tier = 2
		end)
		TestKit.anyContains(errors, "Nodes['node.boulder']: no item is a tier 2+ pick")
	end)

	test("catches a loot preview that never drops at the location", function()
		local errors = brokenCopy(function(c)
			table.insert(c.Locations["loc.pine_hollow"].mainLoot, "item.brass_gear")
		end)
		TestKit.anyContains(errors, "'item.brass_gear' is previewed but never drops here")
	end)

	test("catches build tiers that don't chain", function()
		local errors = brokenCopy(function(c)
			c.BuildPieces["build.door_scrap"].minFoundationTier = 1
			c.BuildPieces["build.window_wood"].upgradesTo = "build.wall_scrap"
		end)
		TestKit.anyContains(errors, "door tier can't exceed its foundation tier")
		TestKit.anyContains(errors, "BuildPieces['build.window_wood']: upgradesTo must be the same kind, one tier up")
		TestKit.anyContains(errors, "BuildPieces['build.wall_scrap']: upgraded into from more than one piece")
		TestKit.anyContains(
			errors,
			"BuildPieces['build.window_scrap']: tier 2 window has no lower tier upgrading into it"
		)
	end)

	test("catches broken loot nesting, entries and pity", function()
		local errors = brokenCopy(function(c)
			c.LootTables["loot.quarry_toolbox"].entries[4].tableId = "loot.nowhere"
			c.LootTables["loot.junk"].entries[1] = { tableId = "loot.road_dense", weight = 1, min = 1, max = 1 }
			c.LootTables["loot.pine_pack"].entries[1].tableId = "loot.junk"
			c.LootTables["loot.pine_crate"].pity = { rarity = "epic", every = 4 }
		end)
		TestKit.anyContains(errors, "unknown loot table 'loot.nowhere'")
		TestKit.anyContains(errors, "LootTables['loot.junk']: nested tables loop back on themselves")
		TestKit.anyContains(errors, "LootTables['loot.pine_pack'].entries[1]: set exactly one of itemId and tableId")
		TestKit.anyContains(errors, "LootTables['loot.pine_crate'].pity: no entry is epic or better")
	end)

	test("nested loot counts for previews and earnability", function()
		local errors = brokenCopy(function(c)
			-- The Seized Motor now drops only through loot.junk, and the Quarry still previews it.
			c.LootTables["loot.quarry_locker"].entries[5].itemId = "item.cloth"
		end)
		for _, message in errors do
			TestKit.truthy(not string.find(message, "seized_motor", 1, true), `unexpected error: {message}`)
		end
	end)

	test("catches blueprint gates on non-blueprints and blueprints that unlock nothing", function()
		local errors = brokenCopy(function(c)
			c.Recipes["recipe.pack_frame"].unlock.itemId = "item.timber"
		end)
		TestKit.anyContains(errors, "'item.timber' is not a blueprint item")
		TestKit.anyContains(errors, "Items['item.bp_pack_frame']: blueprint doesn't unlock any recipe or build piece")
	end)

	test("catches bad quest references and prerequisite loops", function()
		local errors = brokenCopy(function(c)
			c.Quests["quest.first_light"].prerequisite = "quest.the_dense_fog"
			c.Quests["quest.scavenger"].objectives[1].locationId = "loc.nowhere"
			c.Quests["quest.tools_of_survival"].objectives[1].recipeId = "recipe.ghost"
		end)
		TestKit.anyContains(errors, "prerequisite chain loops back on itself")
		TestKit.anyContains(errors, "Quests: at least one quest must have no prerequisite")
		TestKit.anyContains(errors, "unknown location 'loc.nowhere'")
		TestKit.anyContains(errors, "unknown recipe 'recipe.ghost'")
	end)

	test("catches orphaned tables and items that can only be bought", function()
		local errors = brokenCopy(function(c)
			table.remove(c.Locations["loc.stranded_caravan"].containers, 2)
			c.Items["item.gold_crown"] = TableUtil.deepCopy(c.Items["item.sealed_tin"])
			c.Items["item.gold_crown"].id = "item.gold_crown"
			table.insert(
				c.Products["product.resource_pack"].grants,
				{ kind = "item", itemId = "item.gold_crown", count = 1 }
			)
		end)
		TestKit.anyContains(
			errors,
			"LootTables['loot.caravan_strongbox']: not used by any location container, enemy or nested entry"
		)
		TestKit.anyContains(errors, "Items['item.gold_crown']: can't be earned in play")
	end)

	test("catches level curve and level gate problems", function()
		local errors = brokenCopy(function(c)
			c.Levels[3].xp = 100
			c.Locations["loc.sunken_quarry"].levelGate = 99
		end)
		TestKit.anyContains(errors, "Levels[3]: xp must be higher than the previous level's")
		TestKit.anyContains(errors, "level 99 must be an integer from 1 to 20")
	end)

	test("catches rotating availability and reset mismatches", function()
		local errors = brokenCopy(function(c)
			local caravan = c.Locations["loc.stranded_caravan"]
			caravan.availability.activeSeconds = caravan.availability.periodSeconds
			c.Locations["loc.ashfall_depot"].reset = { kind = "perAppearance" }
		end)
		TestKit.anyContains(errors, "need 0 < activeSeconds < periodSeconds")
		TestKit.anyContains(
			errors,
			"Locations['loc.ashfall_depot']: perAppearance resets go with rotating availability"
		)
	end)

	test("catches a backpack cap below what bags and upgrades reach", function()
		local errors = brokenCopy(function(c)
			c.Tuning.inventory.maxBackpackSlots = 10
		end)
		TestKit.anyContains(errors, "maxBackpackSlots is 10 but bags and upgrades reach 18")
	end)
end
