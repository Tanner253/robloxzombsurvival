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
		TestKit.anyContains(lines, "Timber into")
	end)

	test("every ingredient of every recipe has at least one source", function()
		for _, recipe in Content.Recipes do
			for _, stack in recipe.inputs do
				TestKit.truthy(#ItemSources.of(Content :: any, stack.itemId) > 0, `{stack.itemId} has a source`)
			end
		end
	end)

	local NAMES: any = { items = Content.Items, quests = Content.Quests }
	local function after(...: string): any
		local completed = {}
		for _, questId in { ... } do
			completed[questId] = 1
		end
		return { level = 1, unlocks = { recipes = {}, blueprints = {} }, quests = { completed = completed } }
	end

	test("F-34: a cost no open station makes names where it will come from", function()
		local early = after("quest.first_light", "quest.tools_of_survival", "quest.claim_the_ground")
		TestKit.equal(
			ItemSources.lockedMaker(Content :: any, "item.stone_block", early, NAMES),
			"Stonecutter: Ember Trail 4",
			"quest 5's Workbench needs blocks from the build line's quest-4 Stonecutter"
		)
		local later = after("quest.first_light", "quest.claim_the_ground", "quest.a_place_to_work")
		TestKit.equal(ItemSources.lockedMaker(Content :: any, "item.stone_block", later, NAMES), nil, "cutter open")
		TestKit.equal(ItemSources.lockedMaker(Content :: any, "item.timber", early, NAMES), nil, "gathered")
		TestKit.equal(ItemSources.obtainable(Content :: any, "item.stone_block", early), false)
		TestKit.equal(ItemSources.obtainable(Content :: any, "item.stone_block", later), true)
		local fs = require("@lune/fs")
		local build = fs.readFile("src/client/UI/screens/ldoe/Build.luau")
		TestKit.truthy(string.find(build, "ItemSources.lockedMaker(", 1, true), "the build card asks")
	end)

	test("F-10: the build tray and the upgrade button carry the crafting pane's Fill Up", function()
		local fs = require("@lune/fs")
		local build = fs.readFile("src/client/UI/screens/ldoe/Build.luau")
		TestKit.truthy(string.find(build, "FillUp = fillShort and fillPrice and e(FillUpButton", 1, true), "tray")
		TestKit.truthy(string.find(build, "FillUp = upShort and upPrice and e(FillUpButton", 1, true), "upgrade")
		TestKit.truthy(string.find(build, "local fillUp = offers.fillUp", 1, true), "the same offer as crafting")
		-- Crafting and crate upgrades buy the shortfall, not the whole cost.
		for _, file in { "src/client/UI/screens/CraftingScreen.luau", "src/client/UI/screens/InventoryScreen.luau" } do
			local source = fs.readFile(file)
			TestKit.truthy(string.find(source, "Offers.shortfall(", 1, true), `{file} fills only the shortfall`)
		end
	end)
end
