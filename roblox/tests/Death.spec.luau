--!strict
local TestKit = require("./TestKit")
local Death = require("../src/shared/Domain/Death")
local Inventory = require("../src/shared/Domain/Inventory")

local T0 = 1_700_000_000
local OWNER = 101
local ITEMS: Inventory.ItemLookup = {
	["item.wood"] = { stackSize = 20 },
	["item.axe"] = { stackSize = 1, durability = 100 },
}
local CONFIG: Death.Config = { despawnSeconds = 3600 }

local function ctx(): Death.DropContext
	return { id = "drop.1", ownerUserId = OWNER, locationId = "loc.pines", now = T0 }
end

local function carrying(): Inventory.Inventory
	local inventory = Inventory.new(2, 3)
	inventory = (Inventory.add(inventory, "item.wood", 30, ITEMS))
	inventory.backpack[3] = { itemId = "item.axe", count = 1, durability = 37 }
	return inventory
end

return function(test: TestKit.Register)
	test("drop empties pockets and backpack into a record and keeps capacities", function()
		local inventory, drop = Death.drop(carrying(), ctx(), CONFIG)
		TestKit.equal(Inventory.count(inventory, "item.wood"), 0, "wood dropped")
		TestKit.equal(#inventory.pockets, 2, "pocket capacity")
		TestKit.equal(#inventory.backpack, 3, "backpack capacity")
		local record = drop :: Death.DroppedBackpack
		TestKit.equal(#record.contents, 3, "two wood stacks and an axe")
		TestKit.equal(record.locationId, "loc.pines")
		TestKit.equal(record.despawnAt, T0 + 3600)
	end)

	test("keepPockets keeps the pocket items", function()
		local inventory, drop = Death.drop(carrying(), ctx(), { despawnSeconds = 60, keepPockets = true })
		TestKit.equal(Inventory.count(inventory, "item.wood"), 30, "both wood stacks were in pockets")
		TestKit.equal(#(drop :: Death.DroppedBackpack).contents, 1, "only the axe dropped")
	end)

	test("nothing carried means no record", function()
		local _, drop = Death.drop(Inventory.new(2, 2), ctx(), CONFIG)
		TestKit.equal(drop, nil)
	end)

	test("an earlier despawn (location reset) wins", function()
		local context = ctx()
		context.despawnAt = T0 + 600
		local _, drop = Death.drop(carrying(), context, CONFIG)
		TestKit.equal((drop :: Death.DroppedBackpack).despawnAt, T0 + 600)
	end)

	test("recovery rules: owner, location and despawn boundary", function()
		local _, drop = Death.drop(carrying(), ctx(), CONFIG)
		local record = drop :: Death.DroppedBackpack
		TestKit.deepEqual({ Death.canRecover(record, 999, "loc.pines", T0) }, { false, "notOwner" })
		TestKit.deepEqual({ Death.canRecover(record, OWNER, "loc.other", T0) }, { false, "wrongLocation" })
		TestKit.equal((Death.canRecover(record, OWNER, "loc.pines", T0 + 3599)), true, "one second left")
		TestKit.deepEqual({ Death.canRecover(record, OWNER, "loc.pines", T0 + 3600) }, { false, "expired" })
	end)

	test("recover restores items and keeps worn durability", function()
		local emptied, drop = Death.drop(carrying(), ctx(), CONFIG)
		local inventory, leftover = Death.recover(drop :: any, emptied, ITEMS, OWNER, "loc.pines", T0 + 10)
		TestKit.equal(leftover, nil, "fully recovered")
		local recovered = inventory :: Inventory.Inventory
		TestKit.equal(Inventory.count(recovered, "item.wood"), 30)
		local axeDurability = nil
		for _, slot in recovered.backpack do
			if slot.itemId == "item.axe" then
				axeDurability = slot.durability
			end
		end
		TestKit.equal(axeDurability, 37, "not repaired by the round trip")
	end)

	test("recover with a full inventory leaves the rest in the backpack", function()
		local _, drop = Death.drop(carrying(), ctx(), CONFIG)
		local small = Inventory.new(1, 0) -- room for one stack of 20
		local inventory, leftover = Death.recover(drop :: any, small, ITEMS, OWNER, "loc.pines", T0)
		TestKit.equal(Inventory.count(inventory :: any, "item.wood"), 20)
		local rest = leftover :: Death.DroppedBackpack
		TestKit.equal(#rest.contents, 2, "10 wood and the axe remain")
		TestKit.equal(rest.contents[1].count, 10)
		TestKit.equal(rest.despawnAt, T0 + 3600, "same timer")
	end)

	test("recover refuses with a reason and changes nothing", function()
		local _, drop = Death.drop(carrying(), ctx(), CONFIG)
		local inventory, leftover, reason =
			Death.recover(drop :: any, Inventory.new(5, 5), ITEMS, OWNER, "loc.pines", T0 + 4000)
		TestKit.equal(inventory, nil)
		TestKit.equal(leftover, nil)
		TestKit.equal(reason, "expired")
	end)

	test("prune drops expired records and keeps the newest", function()
		local function record(id: string, droppedAt: number): Death.DroppedBackpack
			return {
				id = id,
				ownerUserId = OWNER,
				locationId = "loc.a",
				droppedAt = droppedAt,
				despawnAt = droppedAt + 100,
				contents = {},
			}
		end
		local kept =
			Death.prune({ record("old", T0 - 500), record("a", T0 - 10), record("b", T0 - 5), record("c", T0) }, T0, 2)
		TestKit.equal(#kept, 2)
		TestKit.equal(kept[1].id, "c", "newest first")
		TestKit.equal(kept[2].id, "b")
	end)
end
