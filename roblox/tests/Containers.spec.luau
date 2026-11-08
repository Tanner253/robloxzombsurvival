--!strict
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Containers = require("../src/shared/Domain/Containers")
local Rng = require("../src/shared/Domain/Rng")

local T0 = 2_000
local CONFIG = Content.Tuning.containers
local TABLES = Content.LootTables :: any
local ITEMS = Content.Items :: any

local function ctx(seed: number, multiplier: number?, bandTables: { string }?): Containers.RollContext
	return {
		tables = TABLES,
		rng = Rng.new(seed),
		items = ITEMS,
		pity = {},
		scaling = { lootMultiplier = multiplier or 1, bandTableIds = bandTables or {} },
	}
end

local function crate(fogTier: number, searchSeconds: number?): Containers.State
	return Containers.new(
		{ id = "c1", kind = "crate", lootTableId = "loot.pine_crate", searchSeconds = searchSeconds },
		fogTier,
		CONFIG
	)
end

local function total(stacks: { any }): number
	local sum = 0
	for _, stack in stacks do
		sum += stack.count
	end
	return sum
end

return function(test: TestKit.Register)
	test("a search takes about 5 s by default, or the container's own time", function()
		local state = crate(1)
		TestKit.equal(state.searchSeconds, CONFIG.searchSeconds)
		local search = Containers.beginSearch(state, 1, T0) :: Containers.Search
		TestKit.equal(search.endsAt, T0 + 5)
		TestKit.equal(Containers.progress(search, T0 + 2.5), 0.5)
		TestKit.equal(Containers.isDone(search, T0 + 4.9), false)
		local early = Containers.complete(state, search, T0 + 4.9, ctx(1))
		TestKit.equal(early, nil, "not before it's done (an interrupted search never completes)")
		TestKit.equal(crate(1, 8).searchSeconds, 8, "strongboxes take longer")
	end)

	test("Light fog: every player rolls their own loot, once", function()
		local state = crate(1)
		TestKit.equal(state.mode, "personal")
		local a = Containers.beginSearch(state, 1, T0) :: Containers.Search
		local lootA = Containers.complete(state, a, T0 + 5, ctx(1)) :: { any }
		TestKit.truthy(#lootA > 0, "something inside")
		local _, again = Containers.beginSearch(state, 1, T0 + 6)
		TestKit.equal(again, "searched", "the loot panel just opens")
		TestKit.equal(Containers.isSearched(state, 2), false, "player 2 hasn't searched it")
		local b = Containers.beginSearch(state, 2, T0 + 6) :: Containers.Search
		local lootB = Containers.complete(state, b, T0 + 11, ctx(99)) :: { any }
		TestKit.truthy(lootB ~= lootA, "player 2 gets their own roll")
		Containers.takeAll(state, 1)
		TestKit.equal(#(Containers.view(state, 2) :: { any }), #lootB, "taking mine leaves theirs")
		TestKit.equal(Containers.isOpened(state), true)
	end)

	test("Dense and Black: one shared roll, contested", function()
		local state = Containers.new({ id = "c2", lootTableId = "loot.quarry_toolbox" }, 2, CONFIG)
		TestKit.equal(state.mode, "shared")
		local a = Containers.beginSearch(state, 1, T0) :: Containers.Search
		local b = Containers.beginSearch(state, 2, T0 + 1) :: Containers.Search
		local lootA = Containers.complete(state, a, T0 + 5, ctx(3)) :: { any }
		local lootB = Containers.complete(state, b, T0 + 6, ctx(4)) :: { any }
		TestKit.equal(lootB, lootA, "the second searcher sees the same pile")
		local first = Containers.take(state, 1, 1) :: any
		TestKit.truthy(first, "player 1 grabs a stack")
		TestKit.equal(#(Containers.view(state, 2) :: { any }), #lootA, "and it's gone for player 2 too")
		local _, searched = Containers.beginSearch(state, 3, T0 + 7)
		TestKit.equal(searched, "searched", "late arrivals open it instantly")
		TestKit.equal(Containers.modeFor(3, CONFIG), "shared")
	end)

	test("take and putBack: partial counts and returns", function()
		local state = crate(1)
		local search = Containers.beginSearch(state, 1, T0) :: Containers.Search
		local loot = Containers.complete(state, search, T0 + 5, ctx(5)) :: { any }
		local before = total(loot)
		local stack = Containers.take(state, 1, 1, 1) :: any
		TestKit.equal(stack.count, 1)
		TestKit.equal(total(Containers.view(state, 1) :: { any }), before - 1)
		Containers.putBack(state, 1, { stack })
		TestKit.equal(total(Containers.view(state, 1) :: { any }), before, "what didn't fit goes back")
		local _, bad = Containers.take(state, 1, 99)
		TestKit.equal(bad, "badSlot")
		local _, notSearched = Containers.take(state, 7, 1)
		TestKit.equal(notSearched, "notSearched")
	end)

	test("the Fog meter scales loot: more base opens and band tables", function()
		TestKit.equal(Containers.opens(1, Rng.new(1)), 1)
		TestKit.equal(Containers.opens(2, Rng.new(1)), 2)
		local extra = 0
		local rng = Rng.new(8)
		for _ = 1, 1000 do
			extra += Containers.opens(1.25, rng) - 1
		end
		TestKit.truthy(extra > 200 and extra < 300, `about a quarter get an extra open ({extra})`)

		local bandLoot = Content.Locations["loc.sunken_quarry"].run.bandLoot
		TestKit.deepEqual(Containers.bandTables(bandLoot, 1), {}, "band 1 is the base loot")
		TestKit.deepEqual(Containers.bandTables(bandLoot, 2), { "loot.quarry_band2" })
		TestKit.deepEqual(Containers.bandTables(bandLoot, 3), { "loot.quarry_band2", "loot.quarry_band3" })
	end)

	test("late, rich runs out-loot early ones on average", function()
		local function average(multiplier: number, bandTables: { string }): number
			local sum = 0
			for seed = 1, 300 do
				local loot = Containers.roll("loot.quarry_toolbox", ctx(seed, multiplier, bandTables))
				sum += #loot
			end
			return sum / 300
		end
		local early = average(1, {})
		local late = average(1.5, { "loot.quarry_band2", "loot.quarry_band3" })
		TestKit.truthy(late > early + 1, `late {late} vs early {early} distinct stacks`)
	end)

	test("trigger groups only come from Dense and Black band loot", function()
		local function canDrop(tableId: string): boolean
			for _, entry in TABLES[tableId].entries do
				if entry.itemId == "item.trigger_group" then
					return true
				end
			end
			return false
		end
		for _, id in { "loot.pine_band2", "loot.pine_band3", "loot.pine_pack", "loot.pine_crate" } do
			TestKit.equal(canDrop(id), false, id)
		end
		for _, id in { "loot.quarry_band2", "loot.depot_band2", "loot.depot_band3" } do
			TestKit.equal(canDrop(id), true, id)
		end
	end)
end
