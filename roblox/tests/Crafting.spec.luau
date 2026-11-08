--!strict
local TestKit = require("./TestKit")
local Crafting = require("../src/shared/Domain/Crafting")
local Inventory = require("../src/shared/Domain/Inventory")

-- Local fixtures, not Data/*.
local ITEMS: Inventory.ItemLookup = {
	["item.wood"] = { stackSize = 20 },
	["item.plank"] = { stackSize = 20 },
	["item.stick"] = { stackSize = 20 },
	["item.ore"] = { stackSize = 20 },
	["item.bar"] = { stackSize = 20 },
	["item.log"] = { stackSize = 20 },
	["item.axe"] = { stackSize = 1, durability = 50 },
}

local RECIPES: Crafting.Recipes = {
	["recipe.plank"] = {
		id = "recipe.plank",
		inputs = { { itemId = "item.wood", count = 2 } },
		outputs = { { itemId = "item.plank", count = 1 } },
		stationId = "station.bench",
		craftSeconds = 60,
		unlock = { kind = "default" },
	},
	["recipe.fine"] = {
		id = "recipe.fine",
		inputs = { { itemId = "item.plank", count = 1 } },
		outputs = { { itemId = "item.stick", count = 4 } },
		stationId = "station.bench",
		stationLevel = 2,
		craftSeconds = 60,
		unlock = { kind = "default" },
	},
	["recipe.bar"] = {
		id = "recipe.bar",
		inputs = { { itemId = "item.ore", count = 1 } },
		outputs = { { itemId = "item.bar", count = 1 } },
		stationId = "station.furnace",
		craftSeconds = 100,
		unlock = { kind = "default" },
	},
	["recipe.stick"] = {
		id = "recipe.stick",
		inputs = { { itemId = "item.wood", count = 1 } },
		outputs = { { itemId = "item.stick", count = 1 } },
		craftSeconds = 0,
		unlock = { kind = "level", level = 5 },
	},
	["recipe.axe"] = {
		id = "recipe.axe",
		inputs = { { itemId = "item.plank", count = 3 } },
		outputs = { { itemId = "item.axe", count = 1 } },
		craftSeconds = 0,
		unlock = { kind = "blueprint", itemId = "item.bp_axe" },
	},
	["recipe.torch"] = {
		id = "recipe.torch",
		inputs = { { itemId = "item.stick", count = 2 } },
		outputs = { { itemId = "item.log", count = 1 } },
		craftSeconds = 0,
		unlock = { kind = "quest", questId = "quest.first" },
	},
}

local function progress(level: number?): Crafting.Progress
	return { level = level or 10, unlocks = { recipes = {}, blueprints = {} }, quests = { completed = {} } }
end

local function stocked(stacks: { [string]: number }, pockets: number?, backpack: number?): Inventory.Inventory
	local inventory = Inventory.new(pockets or 4, backpack or 4)
	for itemId, count in stacks do
		inventory = (Inventory.add(inventory, itemId, count, ITEMS))
	end
	return inventory
end

return function(test: TestKit.Register)
	test("unlock gates: default, level, quest, blueprint and explicit unlocks", function()
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.plank"], progress(1)), true, "default")
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.stick"], progress(4)), false, "below level")
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.stick"], progress(5)), true, "at level")
		local learned = progress()
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.axe"], learned), false, "no blueprint")
		learned.unlocks.blueprints["item.bp_axe"] = true
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.axe"], learned), true, "blueprint learned")
		local trail = progress(1)
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.torch"], trail), false, "quest not done");
		(trail.quests :: any).completed["quest.first"] = 1700000000
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.torch"], trail), true, "quest done")
		local granted = progress(1)
		granted.unlocks.recipes["recipe.stick"] = true
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.stick"], granted), true, "explicit unlock")
	end)

	test("check reports each failure reason; station recipes never craft by hand", function()
		local inventory = stocked({ ["item.wood"] = 4, ["item.plank"] = 1 })
		local function reason(...): string?
			local _, why = Crafting.check(...)
			return why
		end
		TestKit.equal(reason(RECIPES["recipe.stick"], inventory, progress(1)), "locked")
		TestKit.equal(reason(RECIPES["recipe.plank"], inventory, progress()), "wrongStation")
		TestKit.equal(reason(RECIPES["recipe.axe"], stocked({}), progress()), "locked")
		local learned = progress()
		learned.unlocks.blueprints["item.bp_axe"] = true
		TestKit.equal(reason(RECIPES["recipe.axe"], stocked({}), learned), "missingInputs")
		TestKit.equal((Crafting.check(RECIPES["recipe.stick"], inventory, progress(), 4)), true)
	end)

	test("craftByHand swaps inputs for outputs at once", function()
		local learned = progress()
		learned.unlocks.blueprints["item.bp_axe"] = true
		local result = Crafting.craftByHand(stocked({ ["item.plank"] = 3 }), RECIPES["recipe.axe"], learned, ITEMS)
		TestKit.equal(Inventory.count(result :: any, "item.plank"), 0)
		TestKit.equal(Inventory.count(result :: any, "item.axe"), 1)
	end)

	test("craftByHand is atomic when the outputs do not fit", function()
		-- One slot holds 5 wood; taking 1 leaves 4, so the stick has nowhere to go.
		local inventory = stocked({ ["item.wood"] = 5 }, 1, 0)
		local result, reason = Crafting.craftByHand(inventory, RECIPES["recipe.stick"], progress(), ITEMS)
		TestKit.equal(result, nil)
		TestKit.equal(reason, "inventoryFull")
		TestKit.equal(Inventory.count(inventory, "item.wood"), 5, "input untouched")
	end)

	test("maxCrafts counts what the inventory pays for", function()
		TestKit.equal(Crafting.maxCrafts(RECIPES["recipe.axe"], stocked({ ["item.plank"] = 7 })), 2)
		TestKit.equal(Crafting.maxCrafts(RECIPES["recipe.axe"], stocked({})), 0)
	end)
end
