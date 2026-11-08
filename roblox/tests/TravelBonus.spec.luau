--!strict
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Rng = require("../src/shared/Domain/Rng")
local TravelBonus = require("../src/shared/Domain/TravelBonus")

local CONFIG = Content.Tuning.travelBonus
local TABLES = Content.LootTables :: any
local PINES = Content.Locations["loc.pine_hollow"]

local function ctx(seed: number, config: any?): TravelBonus.RollContext
	return { tables = TABLES, rng = Rng.new(seed), items = Content.Items :: any, pity = {}, config = config or CONFIG }
end

return function(test: TestKit.Register)
	test("walking always turns something up, from the location's road table", function()
		for seed = 1, 50 do
			local bonus = TravelBonus.roll(PINES.id, PINES.run.travelBonusTableId, "walk", ctx(seed))
			TestKit.truthy(bonus and #bonus.items > 0, `seed {seed}`)
			TestKit.equal((bonus :: any).mode, "walk")
		end
	end)

	test("a Run finds something about runChance of the time", function()
		local found = 0
		for seed = 1, 1000 do
			if TravelBonus.roll(PINES.id, PINES.run.travelBonusTableId, "run", ctx(seed)) then
				found += 1
			end
		end
		local expected = CONFIG.runChance * 1000
		TestKit.truthy(math.abs(found - expected) < 60, `{found} of 1000 (expected about {expected})`)
	end)

	test("a zero chance never rolls", function()
		local off = { runChance = 0, walkChance = 0, walkRolls = 2 }
		TestKit.equal(TravelBonus.roll(PINES.id, PINES.run.travelBonusTableId, "walk", ctx(1, off)), nil)
	end)

	test("TAKE per item, Take all, and put back what didn't fit", function()
		local bonus = TravelBonus.roll(PINES.id, PINES.run.travelBonusTableId, "walk", ctx(4)) :: TravelBonus.Bonus
		local rows = #bonus.items
		local first = TravelBonus.take(bonus, 1) :: any
		TestKit.truthy(first, "took a row")
		TestKit.equal(#bonus.items, rows - 1)
		TestKit.equal(TravelBonus.take(bonus, 99), nil)
		local rest = TravelBonus.takeAll(bonus)
		TestKit.equal(#rest, rows - 1)
		TestKit.equal(TravelBonus.isEmpty(bonus), true)
		TravelBonus.putBack(bonus, { first })
		TestKit.equal(#bonus.items, 1)
	end)

	test("every location's road table rolls clean", function()
		for id, location in Content.Locations do
			local bonus = TravelBonus.roll(id, location.run.travelBonusTableId, "walk", ctx(7))
			TestKit.truthy(bonus, id)
		end
	end)
end
