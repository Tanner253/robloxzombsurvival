--!strict
-- Specs for Domain/ItemSources: ingredient hovers say where an item comes from (5.10).
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local ItemSources = require("../src/shared/Domain/ItemSources")

return function(test: TestKit.Register)
	test("timber is chopped from pines with a hatchet", function()
		local lines = ItemSources.of(Content :: any, "item.timber")
		TestKit.anyContains(lines, "Chopped from Pine with a hatchet")
	end)

	test("sticks are gathered by hand", function()
		TestKit.anyContains(ItemSources.of(Content :: any, "item.sticks"), "Gathered from Fallen Branches by hand")
	end)

	test("planks name the station and the recipe", function()
		local lines = ItemSources.of(Content :: any, "item.plank")
		TestKit.truthy(#lines > 0, "has a source")
		TestKit.anyContains(lines, "Timber →")
	end)

	test("every ingredient of every recipe has at least one source", function()
		for _, recipe in Content.Recipes do
			for _, stack in recipe.inputs do
				TestKit.truthy(#ItemSources.of(Content :: any, stack.itemId) > 0, `{stack.itemId} has a source`)
			end
		end
	end)
end
