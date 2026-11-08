--!strict
local TestKit = require("./TestKit")
local Loot = require("../src/shared/Domain/Loot")
local Rng = require("../src/shared/Domain/Rng")

-- Local fixtures (not Data/LootTables). Typed `any` because they use the
-- nested/pity extensions that Types.LootTableDef does not declare yet.
local TABLES: any = {
	["loot.weighted"] = {
		id = "loot.weighted",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.a", weight = 70, min = 1, max = 1 },
			{ itemId = "item.b", weight = 20, min = 1, max = 1 },
			{ itemId = "item.c", weight = 10, min = 1, max = 1 },
			{ itemId = "item.never", weight = 0, min = 1, max = 1 },
		},
	},
	["loot.counts"] = {
		id = "loot.counts",
		rolls = { min = 2, max = 3 },
		entries = { { itemId = "item.a", weight = 1, min = 2, max = 4 } },
		guaranteed = { { itemId = "item.key", count = 1 }, { itemId = "item.a", count = 5 } },
	},
	["loot.maybe"] = {
		id = "loot.maybe",
		rolls = { min = 0, max = 1 },
		entries = { { itemId = "item.a", weight = 1, min = 0, max = 1 } },
	},
	["loot.outer"] = {
		id = "loot.outer",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.scrap", weight = 1, min = 1, max = 1 },
			{ tableId = "loot.inner", weight = 1, min = 2, max = 2 },
		},
	},
	["loot.inner"] = {
		id = "loot.inner",
		rolls = { min = 1, max = 1 },
		entries = {
			{ itemId = "item.bolt", weight = 3, min = 1, max = 1 },
			{ itemId = "item.gear", weight = 1, min = 1, max = 1 },
		},
	},
	["loot.loop"] = {
		id = "loot.loop",
		rolls = { min = 1, max = 1 },
		entries = { { tableId = "loot.loop", weight = 1, min = 1, max = 1 } },
	},
	["loot.pity"] = {
		id = "loot.pity",
		rolls = { min = 1, max = 1 },
		pity = { rarity = "rare", every = 5 },
		entries = {
			{ itemId = "item.junk", weight = 99, min = 1, max = 1 },
			{ itemId = "item.gem", weight = 1, min = 1, max = 1 },
		},
	},
}

local ITEMS: Loot.RarityLookup = {
	["item.junk"] = { rarity = "common" },
	["item.gem"] = { rarity = "rare" },
}

local function countOf(result: Loot.Result, itemId: string): number
	for _, stack in result.items do
		if stack.itemId == itemId then
			return stack.count
		end
	end
	return 0
end

return function(test: TestKit.Register)
	test("weighted picks match their weights within tolerance (20k seeded rolls)", function()
		local rng = Rng.new(2026)
		local tally: { [string]: number } = {}
		local runs = 20_000
		for _ = 1, runs do
			local result = Loot.roll(TABLES, "loot.weighted", rng)
			local itemId = result.items[1].itemId
			tally[itemId] = (tally[itemId] or 0) + 1
		end
		for itemId, expected in { ["item.a"] = 0.7, ["item.b"] = 0.2, ["item.c"] = 0.1 } do
			local share = (tally[itemId] or 0) / runs
			TestKit.truthy(math.abs(share - expected) < 0.015, `{itemId} share {share} vs {expected}`)
		end
		TestKit.equal(tally["item.never"], nil, "weight 0 never drops")
	end)

	test("the same seed reproduces the same rolls", function()
		local a, b = Rng.new(7), Rng.new(7)
		for _ = 1, 20 do
			TestKit.deepEqual(Loot.roll(TABLES, "loot.outer", a), Loot.roll(TABLES, "loot.outer", b))
		end
	end)

	test("roll counts and per-entry counts stay in range; guaranteed drops merge", function()
		local rng = Rng.new(99)
		local seen: { [number]: boolean } = {}
		for _ = 1, 500 do
			local result = Loot.roll(TABLES, "loot.counts", rng)
			TestKit.equal(countOf(result, "item.key"), 1, "guaranteed key")
			local rolled = countOf(result, "item.a") - 5
			TestKit.truthy(rolled >= 4 and rolled <= 12, `2-3 picks of 2-4 units, got {rolled}`)
			seen[rolled] = true
			TestKit.equal(#result.items, 2, "item.a merged into one stack")
		end
		TestKit.truthy(seen[4] and seen[12], "both extremes occur")
	end)

	test("zero rolls and zero counts can yield nothing", function()
		local rng = Rng.new(5)
		local empty = 0
		for _ = 1, 400 do
			if #Loot.roll(TABLES, "loot.maybe", rng).items == 0 then
				empty += 1
			end
		end
		TestKit.truthy(empty > 200 and empty < 400, `about 3/4 empty, got {empty}`)
	end)

	test("nested tables open min..max times and follow their own weights", function()
		local rng = Rng.new(31)
		local nested, bolts, gears = 0, 0, 0
		for _ = 1, 4000 do
			local result = Loot.roll(TABLES, "loot.outer", rng)
			local fromInner = countOf(result, "item.bolt") + countOf(result, "item.gear")
			if fromInner > 0 then
				nested += 1
				TestKit.equal(fromInner, 2, "inner table opened twice")
			end
			bolts += countOf(result, "item.bolt")
			gears += countOf(result, "item.gear")
		end
		TestKit.truthy(math.abs(nested / 4000 - 0.5) < 0.03, "half the picks go nested")
		TestKit.truthy(math.abs(bolts / (bolts + gears) - 0.75) < 0.03, "inner weights 3:1")
	end)

	test("a cycle or unknown table raises a clear error", function()
		TestKit.throws(function()
			Loot.roll(TABLES, "loot.loop", Rng.new(1))
		end, "nests deeper")
		TestKit.throws(function()
			Loot.roll(TABLES, "loot.missing", Rng.new(1))
		end, "unknown loot table")
	end)

	test("pity guarantees a rare at least every 5th open", function()
		local rng = Rng.new(11)
		local pity: Loot.PityState = {}
		local sinceRare, worst, rares = 0, 0, 0
		for _ = 1, 1000 do
			local result = Loot.roll(TABLES, "loot.pity", rng, { items = ITEMS, pity = pity })
			pity = result.pity
			if countOf(result, "item.gem") > 0 then
				rares += 1
				sinceRare = 0
				TestKit.equal(pity["loot.pity"], 0, "counter resets on a hit")
			else
				sinceRare += 1
				worst = math.max(worst, sinceRare)
			end
		end
		TestKit.truthy(worst <= 4, `at most 4 misses in a row, got {worst}`)
		TestKit.truthy(rares >= 200, "about one in five")
	end)

	test("pity counts across calls and does not mutate the input state", function()
		local input: Loot.PityState = { ["loot.pity"] = 4 }
		local result = Loot.roll(TABLES, "loot.pity", Rng.new(3), { items = ITEMS, pity = input })
		TestKit.equal(countOf(result, "item.gem"), 1, "fifth open is forced")
		TestKit.equal(result.pity["loot.pity"], 0)
		TestKit.equal(input["loot.pity"], 4, "input untouched")
	end)

	test("without a pity state the table rolls plainly", function()
		local rng = Rng.new(11)
		local rares = 0
		for _ = 1, 1000 do
			rares += countOf(Loot.roll(TABLES, "loot.pity", rng, { items = ITEMS }), "item.gem")
		end
		TestKit.truthy(rares < 40, `plain 1% odds, got {rares}`)
	end)

	test("shares flatten nested weights and report guaranteed items", function()
		local shares = Loot.shares(TABLES, "loot.outer")
		TestKit.equal(shares["item.scrap"], 0.5)
		TestKit.equal(shares["item.bolt"], 0.375)
		TestKit.equal(shares["item.gear"], 0.125)
		TestKit.equal(Loot.shares(TABLES, "loot.counts")["item.key"], 1)
	end)
end
