--!strict
local TestKit = require("./TestKit")
local Inventory = require("../src/shared/Domain/Inventory")

local ITEMS: Inventory.ItemLookup = {
	["item.wood"] = { stackSize = 50 },
	["item.stone"] = { stackSize = 20 },
	["item.hatchet"] = { stackSize = 1, durability = 100 },
}

local function slot(itemId: string, count: number): Inventory.Slot
	return { itemId = itemId, count = count }
end

return function(test: TestKit.Register)
	test("new inventory has empty pockets and backpack of the given sizes", function()
		local inv = Inventory.new(2, 3)
		TestKit.equal(#inv.pockets, 2, "pockets")
		TestKit.equal(#inv.backpack, 3, "backpack")
		TestKit.truthy(Inventory.isEmpty(inv.backpack[3]), "empty slot")
	end)

	test("add tops up an existing stack before using an empty slot", function()
		local inv = Inventory.new(2, 0)
		inv.pockets[2] = slot("item.wood", 45)
		local result, left = Inventory.add(inv, "item.wood", 10, ITEMS)
		TestKit.equal(left, 0, "leftover")
		TestKit.equal(result.pockets[2].count, 50, "topped-up stack")
		TestKit.equal(result.pockets[1].count, 5, "overflow into empty slot")
	end)

	test("add splits by stack size and overflows pockets into the backpack", function()
		local inv = Inventory.new(1, 2)
		local result, left = Inventory.add(inv, "item.stone", 45, ITEMS)
		TestKit.equal(left, 0, "leftover")
		TestKit.equal(result.pockets[1].count, 20, "pocket")
		TestKit.equal(result.backpack[1].count, 20, "backpack 1")
		TestKit.equal(result.backpack[2].count, 5, "backpack 2")
	end)

	test("add returns what does not fit and never mutates its input", function()
		local inv = Inventory.new(1, 1)
		local result, left = Inventory.add(inv, "item.stone", 50, ITEMS)
		TestKit.equal(left, 10, "leftover")
		TestKit.equal(Inventory.count(result, "item.stone"), 40, "stored")
		TestKit.truthy(Inventory.isEmpty(inv.pockets[1]), "input untouched")
	end)

	test("non-stackable items take one slot each and get full durability", function()
		local result, left = Inventory.add(Inventory.new(2, 1), "item.hatchet", 2, ITEMS)
		TestKit.equal(left, 0, "leftover")
		TestKit.equal(result.pockets[1].count, 1, "one per slot")
		TestKit.equal(result.pockets[2].durability, 100, "durability")
	end)

	test("spaceFor counts partial stacks and empty slots", function()
		local inv = Inventory.new(1, 1)
		inv.pockets[1] = slot("item.wood", 30)
		TestKit.equal(Inventory.spaceFor(inv, "item.wood", ITEMS), 20 + 50)
		TestKit.equal(Inventory.spaceFor(inv, "item.stone", ITEMS), 20)
	end)

	test("remove takes from the backpack first, then pockets", function()
		local inv = Inventory.new(1, 1)
		inv.pockets[1] = slot("item.wood", 10)
		inv.backpack[1] = slot("item.wood", 5)
		local result = Inventory.remove(inv, "item.wood", 7) :: Inventory.Inventory
		TestKit.truthy(Inventory.isEmpty(result.backpack[1]), "backpack emptied first")
		TestKit.equal(result.pockets[1].count, 8, "pockets")
	end)

	test("remove returns nil when there is not enough, leaving the input untouched", function()
		local inv = Inventory.new(1, 0)
		inv.pockets[1] = slot("item.wood", 3)
		TestKit.equal(Inventory.remove(inv, "item.wood", 4), nil)
		TestKit.equal(inv.pockets[1].count, 3, "input untouched")
	end)

	test("removeAll is atomic and sums duplicate entries", function()
		local inv = Inventory.new(2, 0)
		inv.pockets[1] = slot("item.wood", 5)
		inv.pockets[2] = slot("item.stone", 2)
		local cost = { { itemId = "item.wood", count = 3 }, { itemId = "item.wood", count = 3 } }
		TestKit.equal(Inventory.hasAll(inv, cost), false, "6 wood needed, 5 held")
		TestKit.equal(Inventory.removeAll(inv, cost), nil)

		local ok =
			Inventory.removeAll(inv, { { itemId = "item.wood", count = 5 }, { itemId = "item.stone", count = 1 } })
		TestKit.truthy(ok, "affordable")
		local result = ok :: Inventory.Inventory
		TestKit.equal(Inventory.count(result, "item.wood"), 0, "wood")
		TestKit.equal(Inventory.count(result, "item.stone"), 1, "stone")
	end)

	test("backpack grows freely but only shrinks over empty slots", function()
		local inv = Inventory.new(1, 2)
		local grown = Inventory.setBackpackCapacity(inv, 4) :: Inventory.Inventory
		TestKit.equal(#grown.backpack, 4, "grown")
		grown.backpack[4] = slot("item.wood", 1)
		TestKit.equal(Inventory.setBackpackCapacity(grown, 3), nil, "shrink over an item refused")
		local shrunk = Inventory.setBackpackCapacity(inv, 1) :: Inventory.Inventory
		TestKit.equal(#shrunk.backpack, 1, "shrunk over empty slots")
	end)

	test("rejects unknown items and bad counts", function()
		TestKit.throws(function()
			Inventory.add(Inventory.new(1, 0), "item.unknown", 1, ITEMS)
		end, "unknown item")
		TestKit.throws(function()
			Inventory.add(Inventory.new(1, 0), "item.wood", 0, ITEMS)
		end, "positive integer")
		TestKit.throws(function()
			Inventory.remove(Inventory.new(1, 0), "item.wood", 1.5)
		end, "positive integer")
	end)
	test("addSlot keeps a worn item's durability and stacks plain items", function()
		local inv = Inventory.new(1, 1)
		local result, left = Inventory.addSlot(inv, { itemId = "item.hatchet", count = 1, durability = 12 }, ITEMS)
		TestKit.equal(left, 0)
		TestKit.equal(result.pockets[1].durability, 12, "not reset to max")
		local stacked, rest = Inventory.addSlot(result, slot("item.stone", 25), ITEMS)
		TestKit.equal(stacked.backpack[1].count, 20, "plain items go through add")
		TestKit.equal(rest, 5, "overflow reported")
		local _, refused = Inventory.addSlot(stacked, { itemId = "item.hatchet", count = 1, durability = 3 }, ITEMS)
		TestKit.equal(refused, 1, "no empty slot")
	end)
end
