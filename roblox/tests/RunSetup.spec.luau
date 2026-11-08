--!strict
--[[
	Setting a lobby up from data: which Hollow spawn in which meter band, and which
	map spots hold which containers.
]]
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Containers = require("../src/shared/Domain/Containers")
local HollowAI = require("../src/shared/Domain/HollowAI")
local Rng = require("../src/shared/Domain/Rng")

local QUARRY = Content.Locations["loc.sunken_quarry"]

local function countOf(groups: { HollowAI.SpawnGroup }, enemyId: string): number
	local total = 0
	for _, group in groups do
		if group.enemyId == enemyId then
			total += group.count
		end
	end
	return total
end

return function(test: TestKit.Register)
	test("band 1 spawns the base sets; bloaters join the Quarry at band 2", function()
		local first = HollowAI.spawnsForBand(QUARRY.enemySpawns, 1, Rng.new(1))
		TestKit.truthy(countOf(first, "enemy.shambler") >= 8, "shamblers from the start")
		TestKit.equal(countOf(first, "enemy.bloater"), 0, "no bloaters yet")
		local second = HollowAI.spawnsForBand(QUARRY.enemySpawns, 2, Rng.new(1))
		TestKit.truthy(countOf(second, "enemy.bloater") >= 1, "the bloaters arrive")
		TestKit.equal(countOf(second, "enemy.shambler"), 0, "base sets don't respawn")
		TestKit.equal(#HollowAI.spawnsForBand(QUARRY.enemySpawns, 3, Rng.new(1)), 0, "nothing new at band 3")
	end)

	test("spawn counts stay in each set's range", function()
		for seed = 1, 40 do
			local groups = HollowAI.spawnsForBand(QUARRY.enemySpawns, 1, Rng.new(seed))
			local shamblers = countOf(groups, "enemy.shambler")
			TestKit.truthy(shamblers >= 8 and shamblers <= 10, `seed {seed}: {shamblers}`)
		end
	end)

	test("every location's spawn bands exist", function()
		local bands = #Content.Tuning.lobby.bands
		for id, location in Content.Locations do
			local total = 0
			for band = 1, bands do
				total += #HollowAI.spawnsForBand(location.enemySpawns, band, Rng.new(3))
			end
			TestKit.truthy(total > 0, id)
		end
	end)

	test("container layout fills matching spots first, then unmarked ones", function()
		local entries = {
			{ lootTableId = "loot.quarry_locker", count = { min = 2, max = 2 }, kind = "locker" },
			{ lootTableId = "loot.quarry_toolbox", count = { min = 2, max = 2 }, kind = "cabinet" },
		}
		local spots = { { kind = "locker" }, { kind = nil }, { kind = "cabinet" }, { kind = nil }, { kind = "trunk" } }
		local placements = Containers.layout(entries, spots, Rng.new(5))
		TestKit.equal(#placements, 4)
		local used: { [number]: number } = {}
		for _, placement in placements do
			used[placement.spot] = placement.entry
		end
		TestKit.equal(used[1], 1, "the locker spot holds a locker")
		TestKit.equal(used[3], 2, "the cabinet spot holds a cabinet")
		TestKit.equal(used[5], nil, "a trunk spot never takes a locker or cabinet")
		TestKit.truthy(used[2] and used[4], "the overflow uses the unmarked spots")
	end)

	test("container layout is seeded and never reuses a spot", function()
		local entries = QUARRY.containers
		local spots = {}
		for _ = 1, 6 do
			table.insert(spots, {})
		end
		local a = Containers.layout(entries, spots, Rng.new(77))
		TestKit.deepEqual(Containers.layout(entries, spots, Rng.new(77)), a, "the same seed, the same layout")
		local seen: { [number]: boolean } = {}
		for _, placement in a do
			TestKit.equal(seen[placement.spot], nil, "each spot once")
			seen[placement.spot] = true
		end
		local few = Containers.layout(entries, { {}, {} }, Rng.new(1))
		TestKit.equal(#few, 2, "only as many containers as spots")
	end)
end
