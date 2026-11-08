--!strict
local TestKit = require("./TestKit")
local Energy = require("../src/shared/Domain/Energy")

local T0 = 1_700_000_000
local CONFIG: Energy.Config = { cap = 20, secondsPerPoint = 60 }

return function(test: TestKit.Register)
	test("current applies offline regeneration and keeps partial progress", function()
		local state = Energy.current({ value = 5, updatedAt = T0 }, T0 + 150, CONFIG)
		TestKit.equal(state.value, 7, "two whole points")
		TestKit.equal(state.updatedAt, T0 + 120, "30 s carried")
	end)

	test("spend applies regeneration first and refuses when short", function()
		local state = { value = 3, updatedAt = T0 }
		TestKit.equal(Energy.spend(state, T0, CONFIG, 4), nil, "3 < 4")
		local after = Energy.spend(state, T0 + 60, CONFIG, 4) :: Energy.State
		TestKit.equal(after.value, 0, "regen point used")
		TestKit.equal(after.updatedAt, T0 + 60)
	end)

	test("spending at the cap starts the regen clock at now", function()
		local after = Energy.spend({ value = 20, updatedAt = T0 }, T0 + 5_000, CONFIG, 5) :: Energy.State
		TestKit.equal(after.value, 15)
		TestKit.equal(after.updatedAt, T0 + 5_000, "no banked regen at the cap")
		TestKit.equal(Energy.current(after, T0 + 5_059, CONFIG).value, 15, "1 s before the next point")
		TestKit.equal(Energy.current(after, T0 + 5_060, CONFIG).value, 16, "on the boundary")
	end)

	test("clamp restore fills to the cap and drops the excess", function()
		local state, added = Energy.restore({ value = 18, updatedAt = T0 }, T0, CONFIG, 10, "clamp")
		TestKit.equal((state :: Energy.State).value, 20)
		TestKit.equal(added, 2)
	end)

	test("item restore is refused at the cap but may exceed it from below", function()
		local refused, none = Energy.restore({ value = 20, updatedAt = T0 }, T0, CONFIG, 50, "item")
		TestKit.equal(refused, nil, "refused at cap")
		TestKit.equal(none, 0)
		local state, added = Energy.restore({ value = 19, updatedAt = T0 }, T0, CONFIG, 50, "item")
		TestKit.equal((state :: Energy.State).value, 69, "over cap")
		TestKit.equal(added, 50)
	end)

	test("item restore refuses when regeneration has already filled the cap", function()
		local refused = Energy.restore({ value = 10, updatedAt = T0 }, T0 + 600, CONFIG, 50, "item")
		TestKit.equal(refused, nil)
	end)

	test("grant always applies, respects hardCap, and over-cap never decays", function()
		local config: Energy.Config = { cap = 20, secondsPerPoint = 60, hardCap = 100 }
		local state, added = Energy.restore({ value = 90, updatedAt = T0 }, T0, config, 50, "grant")
		TestKit.equal((state :: Energy.State).value, 100, "hard cap")
		TestKit.equal(added, 10)
		TestKit.equal(Energy.current(state :: Energy.State, T0 + 86_400, config).value, 100, "kept a day later")
	end)

	test("secondsUntil counts down to a target and handles unreachable targets", function()
		local state = { value = 5, updatedAt = T0 }
		TestKit.equal(Energy.secondsUntil(state, T0 + 30, CONFIG, 7), 90, "2 points minus 30 s progress")
		TestKit.equal(Energy.secondsUntil(state, T0, CONFIG, 5), 0, "already there")
		TestKit.equal(Energy.secondsUntil(state, T0, CONFIG, 25), math.huge, "above cap")
		TestKit.equal(Energy.secondsUntilFull(state, T0, CONFIG), 15 * 60)
	end)

	test("a clock that went backwards changes nothing", function()
		local after = Energy.spend({ value = 5, updatedAt = T0 }, T0 - 600, CONFIG, 1) :: Energy.State
		TestKit.equal(after.value, 4)
		TestKit.equal(after.updatedAt, T0)
	end)
end
