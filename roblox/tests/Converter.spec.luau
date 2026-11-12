--!strict
local TestKit = require("./TestKit")
local Converter = require("../src/shared/Domain/Converter")
local Rng = require("../src/shared/Domain/Rng")
local Types = require("../src/shared/Types")
local Content = require("../src/shared/Data")

local T0 = 1_700_000_000

-- Local fixtures, not Data/*.
local ITEMS: Converter.ItemLookup = {
	["item.log"] = { stackSize = 20 },
	["item.plank"] = { stackSize = 20 },
	["item.ore"] = { stackSize = 20 },
	["item.bar"] = { stackSize = 20 },
	["item.stick"] = { stackSize = 20 },
	["item.coal"] = { stackSize = 20 },
	["item.junk"] = { stackSize = 20 },
	["item.blade"] = { stackSize = 1, durability = 100 },
	["item.scrap"] = { stackSize = 50 },
	["item.gear"] = { stackSize = 20 },
}

local RECIPES: { [string]: Types.RecipeDef } = {
	["recipe.plank"] = {
		id = "recipe.plank",
		inputs = { { itemId = "item.log", count = 1 } },
		outputs = { { itemId = "item.plank", count = 1 } },
		stationId = "station.bench",
		craftSeconds = 240,
		unlock = { kind = "default" },
	},
	["recipe.bar"] = {
		id = "recipe.bar",
		inputs = { { itemId = "item.ore", count = 2 } },
		outputs = { { itemId = "item.bar", count = 1 } },
		stationId = "station.furnace",
		craftSeconds = 100,
		unlock = { kind = "quest", questId = "quest.smelt" },
	},
}

local BENCH: Types.StationDef = {
	id = "station.bench",
	name = "Bench",
	levels = {
		{ level = 1, upgradeCost = {}, slotCap = 20, speedMultiplier = 1 },
		{ level = 2, upgradeCost = { { itemId = "item.plank", count = 5 } }, slotCap = 40, speedMultiplier = 1 },
	},
}

local FURNACE: Types.StationDef = {
	id = "station.furnace",
	name = "Furnace",
	levels = { { level = 1, upgradeCost = {}, slotCap = 20, speedMultiplier = 1 } },
	fuel = {
		itemIds = { "item.stick", "item.coal" },
		secondsPerUnit = 60,
		burnSeconds = { ["item.coal"] = 300 },
	},
}

local RECYCLER: Types.StationDef = {
	id = "station.recycler",
	name = "Recycler",
	outputSlots = 3,
	levels = { { level = 1, upgradeCost = {}, slotCap = 20, speedMultiplier = 1 } },
	salvage = {
		{
			inputItemId = "item.blade",
			seconds = 60,
			outputs = {
				{ itemId = "item.scrap", min = 2, max = 3, chance = 1 },
				{ itemId = "item.gear", min = 1, max = 1, chance = 0.5 },
			},
		},
	},
}

local OPEN: any =
	{ level = 1, unlocks = { recipes = {}, blueprints = {} }, quests = { completed = { ["quest.smelt"] = 1 } } }
local NEW_PLAYER: any = { level = 1, unlocks = { recipes = {}, blueprints = {} }, quests = { completed = {} } }

local function ctx(def: Types.StationDef, rng: any?): Converter.Context
	return { def = def, recipes = RECIPES, items = ITEMS, rng = rng }
end

local function slot(itemId: string, count: number, durability: number?): Types.Slot
	return { itemId = itemId, count = count, durability = durability }
end

return function(test: TestKit.Register)
	test("a new station is level 1 with empty slots", function()
		local state = Converter.new(RECYCLER, T0)
		TestKit.equal(state.level, 1)
		TestKit.equal(#state.output, 3, "recycler output slots")
		TestKit.truthy(Converter.isEmpty(state))
		TestKit.equal(#Converter.new(BENCH, T0).output, 1, "one output slot by default")
	end)

	test("lists ALL RECIPES for a station, refiners and salvage alike", function()
		local bench = Converter.lines(BENCH, RECIPES)
		TestKit.equal(#bench, 1)
		TestKit.equal(bench[1].inputItemId, "item.log")
		local recycler = Converter.lines(RECYCLER, RECIPES)
		TestKit.equal(#recycler, 1)
		TestKit.equal(recycler[1].key, "salvage:item.blade")
		TestKit.equal(recycler[1].outputs[1].count, 3, "salvage lines show the max")
	end)

	test("a dropped stack converts one batch per craftSeconds, offline included", function()
		local state = Converter.new(BENCH, T0)
		local placed, accepted = Converter.putInput(state, ctx(BENCH), OPEN, slot("item.log", 20), T0)
		TestKit.equal(accepted, 20)
		local later, produced = Converter.advance(placed :: any, ctx(BENCH), T0 + 240 * 5 + 30)
		TestKit.equal(later.input.count, 15)
		TestKit.equal(later.output[1].itemId, "item.plank")
		TestKit.equal(later.output[1].count, 5)
		TestKit.equal(#produced, 5)
		TestKit.equal(later.worked, 30, "the batch in progress keeps its work")
		local done = Converter.advance(later, ctx(BENCH), T0 + 240 * 40)
		TestKit.equal(done.input.count, 0)
		TestKit.equal(done.output[1].count, 20)
		TestKit.equal(Converter.status(done, ctx(BENCH)).activity, "idle")
	end)

	test("slots hold 20 at level 1 and 40 at level 2", function()
		local state = Converter.new(BENCH, T0)
		local placed, accepted = Converter.putInput(state, ctx(BENCH), OPEN, slot("item.log", 30), T0)
		TestKit.equal(accepted, 20)
		local _, again, why = Converter.putInput(placed :: any, ctx(BENCH), OPEN, slot("item.log", 5), T0)
		TestKit.equal(again, 0)
		TestKit.equal(why, "inputFull")
		local upgraded = Converter.upgrade(state, ctx(BENCH), T0) :: Converter.State
		TestKit.equal(upgraded.level, 2)
		local _, more = Converter.putInput(upgraded, ctx(BENCH), OPEN, slot("item.log", 30), T0)
		TestKit.equal(more, 30)
	end)

	test("a full output pauses conversion until it is taken", function()
		local state = Converter.new(BENCH, T0)
		state.output[1] = slot("item.plank", 19)
		local placed = Converter.putInput(state, ctx(BENCH), OPEN, slot("item.log", 5), T0) :: Converter.State
		local later = Converter.advance(placed, ctx(BENCH), T0 + 240 * 5)
		TestKit.equal(later.output[1].count, 20)
		TestKit.equal(later.input.count, 4)
		TestKit.equal(Converter.status(later, ctx(BENCH)).activity, "outputFull")
		local taken, out = Converter.takeOutput(later, ctx(BENCH), 1, nil, T0 + 240 * 5)
		TestKit.equal(out.count, 20)
		local resumed = Converter.advance(taken, ctx(BENCH), T0 + 240 * 6)
		TestKit.equal(resumed.output[1].count, 1, "resumes from when it was emptied")
	end)

	test("a different item can't go in while the input is busy", function()
		local state =
			Converter.putInput(Converter.new(FURNACE, T0), ctx(FURNACE), OPEN, slot("item.ore", 4), T0) :: Converter.State
		local _, accepted, why = Converter.putInput(state, ctx(FURNACE), OPEN, slot("item.log", 1), T0)
		TestKit.equal(accepted, 0)
		TestKit.equal(why, "notConvertible", "logs aren't a furnace input")
	end)

	test("locked lines refuse input and name the reason", function()
		local _, accepted, why =
			Converter.putInput(Converter.new(FURNACE, T0), ctx(FURNACE), NEW_PLAYER, slot("item.ore", 4), T0)
		TestKit.equal(accepted, 0)
		TestKit.equal(why, "locked")
	end)

	test("fuel burns only while converting and stalls work when it runs out", function()
		local state = Converter.new(FURNACE, T0)
		state = (Converter.putFuel(state, ctx(FURNACE), "item.stick", 2, T0)) :: Converter.State
		local idle = Converter.advance(state, ctx(FURNACE), T0 + 1000)
		TestKit.equal(idle.fuel.count, 2, "no input, no burning")
		local placed = Converter.putInput(idle, ctx(FURNACE), OPEN, slot("item.ore", 6), T0 + 1000) :: Converter.State
		-- Two sticks = 120 s of fire: one bar (100 s) plus 20 s of the next.
		local later = Converter.advance(placed, ctx(FURNACE), T0 + 1000 + 500)
		TestKit.equal(later.output[1].count, 1)
		TestKit.equal(later.input.count, 4)
		TestKit.equal(later.worked, 20)
		TestKit.equal(later.fuel.count, 0)
		TestKit.equal(Converter.status(later, ctx(FURNACE)).activity, "noFuel")
		local refuelled = Converter.putFuel(later, ctx(FURNACE), "item.coal", 1, T0 + 1500) :: Converter.State
		local after = Converter.advance(refuelled, ctx(FURNACE), T0 + 1500 + 80)
		TestKit.equal(after.output[1].count, 2, "the stalled batch finishes from its kept work")
		TestKit.equal(after.burnItem, "item.coal")
		TestKit.equal(after.burnLeft, 220)
	end)

	test("the fuel slot takes only fuel, one kind at a time, up to the cap", function()
		local state = Converter.new(FURNACE, T0)
		local _, a, notFuel = Converter.putFuel(state, ctx(FURNACE), "item.ore", 1, T0)
		TestKit.equal(a, 0)
		TestKit.equal(notFuel, "notFuel")
		local fuelled, b = Converter.putFuel(state, ctx(FURNACE), "item.coal", 25, T0)
		TestKit.equal(b, 20)
		local _, c, busy = Converter.putFuel(fuelled :: any, ctx(FURNACE), "item.stick", 1, T0)
		TestKit.equal(c, 0)
		TestKit.equal(busy, "fuelBusy")
		local _, d, none = Converter.putFuel(Converter.new(BENCH, T0), ctx(BENCH), "item.stick", 1, T0)
		TestKit.equal(d, 0)
		TestKit.equal(none, "noFuelSlot")
	end)

	test("taking the whole input out loses the batch in progress", function()
		local placed =
			Converter.putInput(Converter.new(BENCH, T0), ctx(BENCH), OPEN, slot("item.log", 3), T0) :: Converter.State
		local taken, out = Converter.takeInput(placed, ctx(BENCH), nil, T0 + 100)
		TestKit.equal(out.count, 3)
		TestKit.equal(taken.worked, 0)
		TestKit.truthy(Converter.isEmpty(taken))
	end)

	test("upgrading is refused while converting and at the top level", function()
		local placed =
			Converter.putInput(Converter.new(BENCH, T0), ctx(BENCH), OPEN, slot("item.log", 3), T0) :: Converter.State
		local _, busy = Converter.upgrade(placed, ctx(BENCH), T0)
		TestKit.equal(busy, "busy")
		local top = Converter.upgrade(Converter.new(BENCH, T0), ctx(BENCH), T0) :: Converter.State
		local _, max = Converter.upgrade(top, ctx(BENCH), T0)
		TestKit.equal(max, "maxLevel")
	end)

	test("the Recycler takes one worn item at a time and rolls its outputs", function()
		local state = Converter.new(RECYCLER, T0)
		local placed, accepted = Converter.putInput(state, ctx(RECYCLER), OPEN, slot("item.blade", 1, 50), T0)
		TestKit.equal(accepted, 1)
		local _, more, why = Converter.putInput(placed :: any, ctx(RECYCLER), OPEN, slot("item.blade", 1, 80), T0)
		TestKit.equal(more, 0, "non-stacking items go in one at a time")
		TestKit.equal(why, "inputFull")
		local done = Converter.advance(placed :: any, ctx(RECYCLER, Rng.new(7)), T0 + 60)
		TestKit.truthy(done.input.count == 0)
		TestKit.equal(done.output[1].itemId, "item.scrap")
		TestKit.truthy(done.output[1].count >= 2 and done.output[1].count <= 3)
	end)

	test("status reports progress, the batch countdown and the burn bar", function()
		local state = Converter.putFuel(Converter.new(FURNACE, T0), ctx(FURNACE), "item.coal", 1, T0) :: Converter.State
		state = Converter.putInput(state, ctx(FURNACE), OPEN, slot("item.ore", 4), T0) :: Converter.State
		local later = Converter.advance(state, ctx(FURNACE), T0 + 50)
		local status = Converter.status(later, ctx(FURNACE))
		TestKit.equal(status.activity, "working")
		TestKit.equal(status.progress, 0.5)
		TestKit.equal(status.batchRemaining, 50)
		TestKit.equal(status.batchesLeft, 2)
		TestKit.equal(status.capacity, 20)
		TestKit.equal(status.burnFraction, 250 / 300)
	end)

	test("a state that was never stamped starts its clock on first advance", function()
		local state = Converter.new(BENCH, 0)
		state.input = slot("item.log", 5)
		local first = Converter.advance(state, ctx(BENCH), T0)
		TestKit.equal(first.at, T0)
		TestKit.equal(first.input.count, 5, "no work for the time before it was stamped")
	end)

	test("every real station line converts one input stack into one output stack", function()
		for _, def in Content.Stations do
			for _, line in Converter.lines(def, Content.Recipes) do
				-- A passive station (the Rain Barrel) takes nothing in.
				TestKit.truthy(line.inputCount >= 1 or def.passive ~= nil, line.key)
				TestKit.truthy(#line.outputs >= 1, line.key)
			end
		end
	end)

	test("F-21: the Rain Barrel fills itself, a Boiled Water every 15 minutes up to 5, offline too", function()
		local def = Content.Stations["station.rain_barrel"]
		TestKit.deepEqual(def.passive, { itemId = "item.boiled_water", seconds = 900, max = 5 })
		local items: any = Content.Items
		local context: Converter.Context = { def = def, recipes = Content.Recipes, items = items }
		local state = Converter.new(def, T0)
		local after, made = Converter.advance(state, context, T0 + 899)
		TestKit.equal(Converter.ready(after), 0, "not yet")
		after, made = Converter.advance(after, context, T0 + 900)
		TestKit.equal(Converter.ready(after), 1, "one at 15 minutes")
		TestKit.deepEqual(made, { { itemId = "item.boiled_water", count = 1 } })
		local day = Converter.advance(state, context, T0 + 24 * 3600)
		TestKit.equal(Converter.ready(day), 5, "a day away: full at 5, no more")
		TestKit.equal(Converter.status(day, context).activity, "outputFull")
		TestKit.equal(Converter.status(after, context).batchesLeft, 4, "room for four more")
		-- Taking one starts the next from now: no time banked while it was full.
		local taken = Converter.takeOutput(day, context, 1, 1, T0 + 24 * 3600)
		TestKit.equal(Converter.ready(taken), 4)
		local next = Converter.advance(taken, context, T0 + 24 * 3600 + 899)
		TestKit.equal(Converter.ready(next), 4, "the next one is a full 15 minutes away")
		-- Nothing can be put in it.
		local progress = { level = 99, unlocks = { recipes = {}, blueprints = {} } }
		local put, _, why = Converter.putInput(state, context, progress, { itemId = "item.murky_water", count = 1 }, T0)
		TestKit.equal(put, nil)
		TestKit.equal(why, "notConvertible", "no input on a rain catcher")
	end)
end
