--!strict
--[[
	The data validator as a test. The first case checks the real content: any broken
	reference in src/shared/Data fails this test and therefore the build. The other
	cases break one reference in a copy of the content and assert it is caught.
]]

local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local DataValidator = require("../src/shared/Domain/DataValidator")
local TableUtil = require("../src/shared/Util/Table")

local function brokenCopy(mutate: (content: any) -> ()): { string }
	local copy = TableUtil.deepCopy(Content) :: any
	mutate(copy)
	return DataValidator.validate(copy)
end

return function(test: TestKit.Register)
	test("all content in src/shared/Data is valid", function()
		local errors = DataValidator.validate(Content)
		if #errors > 0 then
			error(`{#errors} content error(s):\n        ` .. table.concat(errors, "\n        "), 0)
		end
	end)

	test("content is frozen at load", function()
		TestKit.truthy(table.isfrozen(Content.Items["item.wood"]), "Items entry frozen")
	end)

	test("catches an unknown item in a recipe input", function()
		local errors = brokenCopy(function(c)
			c.Recipes["recipe.hatchet"].inputs[1].itemId = "item.does_not_exist"
		end)
		TestKit.anyContains(errors, "Recipes['recipe.hatchet'].inputs[1]: unknown item 'item.does_not_exist'")
	end)

	test("catches an unknown station on a recipe", function()
		local errors = brokenCopy(function(c)
			c.Recipes["recipe.plank"].stationId = "station.missing"
		end)
		TestKit.anyContains(errors, "unknown station 'station.missing'")
	end)

	test("catches an unknown item in a loot entry", function()
		local errors = brokenCopy(function(c)
			c.LootTables["loot.pine_grove_crate"].entries[2].itemId = "item.ghost"
		end)
		TestKit.anyContains(errors, "LootTables['loot.pine_grove_crate'].entries[2]: unknown item 'item.ghost'")
	end)

	test("catches an unknown loot table on a location", function()
		local errors = brokenCopy(function(c)
			c.Locations["loc.pine_grove"].lootTableIds[1] = "loot.nowhere"
		end)
		TestKit.anyContains(errors, "unknown loot table 'loot.nowhere'")
	end)

	test("catches an unknown item in a product grant", function()
		local errors = brokenCopy(function(c)
			c.Products["product.resource_pack_small"].grants[1].itemId = "item.free_robux"
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

	test("catches unknown items in station costs and fuel", function()
		local errors = brokenCopy(function(c)
			c.Stations["station.workbench"].levels[2].upgradeCost[1].itemId = "item.nope"
			c.Stations["station.campfire"].fuel.itemIds[1] = "item.also_nope"
		end)
		TestKit.anyContains(errors, "unknown item 'item.nope'")
		TestKit.anyContains(errors, "unknown item 'item.also_nope'")
	end)

	test("catches a key that does not match its id or prefix", function()
		local errors = brokenCopy(function(c)
			c.Items["item.wood"].id = "item.timber"
			c.Items["wood_no_prefix"] = TableUtil.deepCopy(c.Items["item.stone"])
			c.Items["wood_no_prefix"].id = "wood_no_prefix"
		end)
		TestKit.anyContains(errors, "id field is 'item.timber', expected 'item.wood'")
		TestKit.anyContains(errors, "Items['wood_no_prefix']: ID must look like 'item.snake_case'")
	end)

	test("catches bad values", function()
		local errors = brokenCopy(function(c)
			c.Items["item.wood"].stackSize = 0
			c.LootTables["loot.quarry_cache"].entries[1].min = 9
		end)
		TestKit.anyContains(errors, "stackSize must be a positive integer")
		TestKit.anyContains(errors, "need 1 <= min <= max")
	end)
end
