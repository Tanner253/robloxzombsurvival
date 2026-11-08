--!strict
local TestKit = require("./TestKit")
local Crafting = require("../src/shared/Domain/Crafting")
local Inventory = require("../src/shared/Domain/Inventory")

local T0 = 1_700_000_000

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
}

local BENCH: any = {
	id = "station.bench",
	name = "Bench",
	levels = {
		{ level = 1, upgradeCost = {}, queueSlots = 2, speedMultiplier = 1 },
		{ level = 2, upgradeCost = { { itemId = "item.plank", count = 5 } }, queueSlots = 4, speedMultiplier = 2 },
	},
}

local FURNACE: any = {
	id = "station.furnace",
	name = "Furnace",
	levels = { { level = 1, upgradeCost = {}, queueSlots = 5, speedMultiplier = 1 } },
	fuel = { itemIds = { "item.log" }, secondsPerUnit = 120 },
}

local function progress(level: number?): Crafting.Progress
	return { level = level or 10, unlocks = { recipes = {}, blueprints = {} } }
end

local function stocked(stacks: { [string]: number }, pockets: number?, backpack: number?): Inventory.Inventory
	local inventory = Inventory.new(pockets or 4, backpack or 4)
	for itemId, count in stacks do
		inventory = (Inventory.add(inventory, itemId, count, ITEMS))
	end
	return inventory
end

return function(test: TestKit.Register)
	test("unlock gates: default, level, blueprint and explicit unlocks", function()
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.plank"], progress(1)), true, "default")
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.stick"], progress(4)), false, "below level")
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.stick"], progress(5)), true, "at level")
		local learned = progress()
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.axe"], learned), false, "no blueprint")
		learned.unlocks.blueprints["item.bp_axe"] = true
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.axe"], learned), true, "blueprint learned")
		local granted = progress(1)
		granted.unlocks.recipes["recipe.stick"] = true
		TestKit.equal(Crafting.isUnlocked(RECIPES["recipe.stick"], granted), true, "explicit unlock")
	end)

	test("check reports each failure reason", function()
		local inventory = stocked({ ["item.wood"] = 4, ["item.plank"] = 1 })
		local bench = Crafting.newStation("station.bench")
		local function reason(...): string?
			local _, why = Crafting.check(...)
			return why
		end
		TestKit.equal(reason(RECIPES["recipe.stick"], inventory, progress(1)), "locked")
		TestKit.equal(reason(RECIPES["recipe.plank"], inventory, progress()), "wrongStation", "no station")
		TestKit.equal(reason(RECIPES["recipe.bar"], inventory, progress(), bench, BENCH), "wrongStation")
		TestKit.equal(reason(RECIPES["recipe.stick"], inventory, progress(), bench, BENCH), "wrongStation", "hand")
		TestKit.equal(reason(RECIPES["recipe.fine"], inventory, progress(), bench, BENCH), "stationLevel")
		TestKit.equal(reason(RECIPES["recipe.plank"], inventory, progress(), bench, BENCH, 3), "queueFull")
		TestKit.equal(reason(RECIPES["recipe.plank"], stocked({}), progress(), bench, BENCH), "missingInputs")
		TestKit.equal((Crafting.check(RECIPES["recipe.plank"], inventory, progress(), bench, BENCH, 2)), true)
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

	test("start takes inputs for every run and queues jobs back to back", function()
		local inventory, station = Crafting.start(
			stocked({ ["item.wood"] = 5 }),
			Crafting.newStation("station.bench"),
			BENCH,
			RECIPES["recipe.plank"],
			progress(),
			T0,
			2
		)
		TestKit.equal(Inventory.count(inventory :: any, "item.wood"), 1, "4 wood taken")
		local queue = (station :: Crafting.Station).queue
		TestKit.equal(#queue, 2)
		TestKit.equal(queue[1].endsAt, T0 + 60)
		TestKit.equal(queue[2].startsAt, T0 + 60)
		TestKit.equal(queue[2].endsAt, T0 + 120)
	end)

	test("a faster station level shortens jobs", function()
		local bench = Crafting.newStation("station.bench")
		bench.level = 2
		local _, station =
			Crafting.start(stocked({ ["item.wood"] = 2 }), bench, BENCH, RECIPES["recipe.plank"], progress(), T0)
		TestKit.equal((station :: Crafting.Station).queue[1].endsAt, T0 + 30)
	end)

	test("start refuses a full queue without taking inputs", function()
		local inventory = stocked({ ["item.wood"] = 10 })
		local _, station = Crafting.start(
			inventory,
			Crafting.newStation("station.bench"),
			BENCH,
			RECIPES["recipe.plank"],
			progress(),
			T0,
			2
		)
		local again, sameStation, reason =
			Crafting.start(inventory, station :: any, BENCH, RECIPES["recipe.plank"], progress(), T0)
		TestKit.equal(again, nil)
		TestKit.equal(sameStation, nil)
		TestKit.equal(reason, "queueFull")
	end)

	test("collect applies offline progress and respects the job boundary", function()
		local inventory, station = Crafting.start(
			stocked({ ["item.wood"] = 4 }),
			Crafting.newStation("station.bench"),
			BENCH,
			RECIPES["recipe.plank"],
			progress(),
			T0,
			2
		)
		local early, _, none = Crafting.collect(station :: any, BENCH, inventory :: any, RECIPES, ITEMS, T0 + 59)
		TestKit.equal(#none, 0, "one second early")
		TestKit.equal(#early.queue, 2)
		local mid, midInventory, got =
			Crafting.collect(station :: any, BENCH, inventory :: any, RECIPES, ITEMS, T0 + 60)
		TestKit.equal(#got, 1, "first job on the boundary")
		TestKit.equal(#mid.queue, 1)
		local done, finalInventory = Crafting.collect(mid, BENCH, midInventory, RECIPES, ITEMS, T0 + 86_400)
		TestKit.equal(#done.queue, 0, "back after a day offline")
		TestKit.equal(Inventory.count(finalInventory, "item.plank"), 2)
	end)

	test("a full inventory leaves finished jobs in the station, still holding slots", function()
		-- One pocket: after the wood is taken it is filled with sticks, so planks cannot land.
		local inventory, station = Crafting.start(
			stocked({ ["item.wood"] = 4 }, 1, 0),
			Crafting.newStation("station.bench"),
			BENCH,
			RECIPES["recipe.plank"],
			progress(),
			T0,
			2
		)
		local blocker = (Inventory.add(inventory :: any, "item.stick", 20, ITEMS))
		local waiting, unchanged, got = Crafting.collect(station :: any, BENCH, blocker, RECIPES, ITEMS, T0 + 500)
		TestKit.equal(#got, 0, "nothing collected")
		TestKit.equal(#waiting.queue, 2, "both finished jobs wait")
		TestKit.equal(Inventory.count(unchanged, "item.stick"), 20)
		local _, _, reason = Crafting.start(
			stocked({ ["item.wood"] = 2 }),
			waiting,
			BENCH,
			RECIPES["recipe.plank"],
			progress(),
			T0 + 500
		)
		TestKit.equal(reason, "queueFull", "uncollected output blocks new jobs")
		local roomy = Inventory.new(1, 1)
		roomy.pockets[1] = { itemId = "item.plank", count = 19 }
		local partial, _, some = Crafting.collect(waiting, BENCH, roomy, RECIPES, ITEMS, T0 + 500)
		TestKit.equal(#some, 2, "19 + 1 tops up the stack, the next job takes the empty slot")
		TestKit.equal(#partial.queue, 0)
	end)

	test("cancel refunds inputs in full and moves later jobs up", function()
		local inventory, station = Crafting.start(
			stocked({ ["item.wood"] = 4 }),
			Crafting.newStation("station.bench"),
			BENCH,
			RECIPES["recipe.plank"],
			progress(),
			T0,
			2
		)
		local after, refunded = Crafting.cancel(station :: any, BENCH, 1, inventory :: any, RECIPES, ITEMS, T0 + 30)
		TestKit.equal(Inventory.count(refunded :: any, "item.wood"), 2, "running job refunded")
		local queue = (after :: Crafting.Station).queue
		TestKit.equal(#queue, 1)
		TestKit.equal(queue[1].startsAt, T0 + 30, "next job starts at cancel time")
		TestKit.equal(queue[1].endsAt, T0 + 90)
	end)

	test("cancel refuses finished, missing and unrefundable jobs", function()
		local inventory, station = Crafting.start(
			stocked({ ["item.wood"] = 4 }, 1, 0),
			Crafting.newStation("station.bench"),
			BENCH,
			RECIPES["recipe.plank"],
			progress(),
			T0,
			2
		)
		local function reason(index: number, inv: Inventory.Inventory, now: number): string?
			local _, _, why = Crafting.cancel(station :: any, BENCH, index, inv, RECIPES, ITEMS, now)
			return why
		end
		TestKit.equal(reason(1, inventory :: any, T0 + 60), "finished")
		TestKit.equal(reason(3, inventory :: any, T0), "notFound")
		local full = (Inventory.add(inventory :: any, "item.stick", 20, ITEMS))
		TestKit.equal(reason(2, full, T0), "inventoryFull")
	end)

	test("a fuel station stalls without fuel and resumes when lit", function()
		local _, station = Crafting.start(
			stocked({ ["item.ore"] = 1 }),
			Crafting.newStation("station.furnace"),
			FURNACE,
			RECIPES["recipe.bar"],
			progress(),
			T0
		)
		local cold, _, none = Crafting.collect(station :: any, FURNACE, Inventory.new(2, 0), RECIPES, ITEMS, T0 + 1000)
		TestKit.equal(#none, 0, "no fuel, no progress")
		TestKit.equal(Crafting.status(cold, FURNACE, T0 + 1000)[1].stalled, true)
		local lit = Crafting.addFuel(cold, FURNACE, stocked({ ["item.log"] = 1 }), "item.log", 1, T0 + 1000)
		TestKit.equal((lit :: Crafting.Station).queue[1].endsAt, T0 + 1100, "full job from relight")
		TestKit.equal((lit :: Crafting.Station).fuelEndsAt, T0 + 1120)
		local _, _, got = Crafting.collect(lit :: any, FURNACE, Inventory.new(2, 0), RECIPES, ITEMS, T0 + 1100)
		TestKit.equal(#got, 1)
	end)

	test("fuel running out mid-job keeps the work done until refuelled", function()
		local fuelled = Crafting.addFuel(
			Crafting.newStation("station.furnace"),
			FURNACE,
			stocked({ ["item.log"] = 1 }),
			"item.log",
			1,
			T0
		)
		local _, station = Crafting.start(
			stocked({ ["item.ore"] = 2 }),
			fuelled :: any,
			FURNACE,
			RECIPES["recipe.bar"],
			progress(),
			T0,
			2
		)
		-- Fuel lasts 120 s: job 1 ends at 100 s, job 2 has 20 s done when the fire dies.
		local cooled, inventory, got =
			Crafting.collect(station :: any, FURNACE, Inventory.new(2, 0), RECIPES, ITEMS, T0 + 500)
		TestKit.equal(#got, 1, "only the first bar")
		local status = Crafting.status(cooled, FURNACE, T0 + 500)[1]
		TestKit.equal(status.stalled, true)
		TestKit.equal(status.remaining, 80)
		TestKit.equal(status.progress, 0.2)
		local relit = Crafting.addFuel(cooled, FURNACE, stocked({ ["item.log"] = 1 }), "item.log", 1, T0 + 1000)
		TestKit.equal((relit :: Crafting.Station).queue[1].endsAt, T0 + 1080, "80 s left after relight")
		local _, finalInventory = Crafting.collect(relit :: any, FURNACE, inventory, RECIPES, ITEMS, T0 + 1080)
		TestKit.equal(Inventory.count(finalInventory, "item.bar"), 2)
	end)

	test("adding fuel while lit extends the burn; bad fuel is refused", function()
		local first = Crafting.addFuel(
			Crafting.newStation("station.furnace"),
			FURNACE,
			stocked({ ["item.log"] = 3 }),
			"item.log",
			1,
			T0
		)
		local second = Crafting.addFuel(first :: any, FURNACE, stocked({ ["item.log"] = 2 }), "item.log", 2, T0 + 60)
		TestKit.equal((second :: Crafting.Station).fuelEndsAt, T0 + 360)
		TestKit.equal(Crafting.fuelRemaining(second :: any, FURNACE, T0 + 300), 60)
		local function reason(def: any, itemId: string, inventory: Inventory.Inventory): string?
			local _, _, why = Crafting.addFuel(Crafting.newStation(def.id), def, inventory, itemId, 1, T0)
			return why
		end
		TestKit.equal(reason(BENCH, "item.log", stocked({ ["item.log"] = 1 })), "noFuel")
		TestKit.equal(reason(FURNACE, "item.wood", stocked({ ["item.wood"] = 1 })), "notFuel")
		TestKit.equal(reason(FURNACE, "item.log", stocked({})), "missingInputs")
	end)

	test("cancelling while stalled keeps the next job's progress for the relight", function()
		local fuelled = Crafting.addFuel(
			Crafting.newStation("station.furnace"),
			FURNACE,
			stocked({ ["item.log"] = 1 }),
			"item.log",
			1,
			T0
		)
		local inventory, station = Crafting.start(
			stocked({ ["item.ore"] = 3 }),
			fuelled :: any,
			FURNACE,
			RECIPES["recipe.bar"],
			progress(),
			T0,
			3
		)
		-- At 500 s: job 1 done, job 2 stalled with 20 s done, job 3 untouched. Cancel job 3.
		local after = Crafting.cancel(station :: any, FURNACE, 3, inventory :: any, RECIPES, ITEMS, T0 + 500)
		local relit = Crafting.addFuel(after :: any, FURNACE, stocked({ ["item.log"] = 1 }), "item.log", 1, T0 + 900)
		local queue = (relit :: Crafting.Station).queue
		TestKit.equal(#queue, 2)
		TestKit.equal(queue[2].endsAt, T0 + 980, "job 2 still has 80 s left")
	end)

	test("upgradeStation pays the cost and refuses when busy or maxed", function()
		local bench = Crafting.newStation("station.bench")
		local _, busy =
			Crafting.start(stocked({ ["item.wood"] = 2 }), bench, BENCH, RECIPES["recipe.plank"], progress(), T0)
		TestKit.equal(select(3, Crafting.upgradeStation(busy :: any, BENCH, stocked({ ["item.plank"] = 5 }))), "busy")
		TestKit.equal(
			select(3, Crafting.upgradeStation(bench, BENCH, stocked({ ["item.plank"] = 4 }))),
			"missingInputs"
		)
		local upgraded, paid = Crafting.upgradeStation(bench, BENCH, stocked({ ["item.plank"] = 6 }))
		TestKit.equal((upgraded :: Crafting.Station).level, 2)
		TestKit.equal(Inventory.count(paid :: any, "item.plank"), 1)
		TestKit.equal(select(3, Crafting.upgradeStation(upgraded :: any, BENCH, stocked({}))), "maxLevel")
	end)
end
