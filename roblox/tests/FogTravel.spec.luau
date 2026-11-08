--!strict
--[[
	Fog Runs extensions to Travel and Energy: re-entry, rotating availability,
	cancel refunds and the Energy shortfall.
]]
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Energy = require("../src/shared/Domain/Energy")
local Travel = require("../src/shared/Domain/Travel")

local T0 = 1_700_000_000
local TRAVEL: Travel.Config = Content.Tuning.travel :: any
local ENERGY: Energy.Config = Content.Tuning.energy :: any
local QUARRY = Content.Locations["loc.sunken_quarry"]
local CARAVAN = Content.Locations["loc.stranded_caravan"]

local function ctx(value: number, now: number?, level: number?): Travel.Context
	return {
		now = now or T0,
		level = level or 20,
		energy = { value = value, updatedAt = now or T0 },
		energyConfig = ENERGY,
		config = TRAVEL,
	}
end

return function(test: TestKit.Register)
	test("re-entry costs half a Run, rounded up, and is always a Run", function()
		local plan = Travel.reentryPlan(QUARRY, TRAVEL)
		TestKit.equal(plan.mode, "run")
		TestKit.equal(plan.energyCost, 8, "15 x 0.5 = 7.5 -> 8")
		TestKit.equal(plan.seconds, TRAVEL.runSeconds)
		local cheap = { id = "loc.x", energyCost = 1, walkSeconds = 60, levelGate = 1 }
		TestKit.equal(Travel.reentryPlan(cheap, TRAVEL).energyCost, 1, "never free if the Run isn't")
		local free = { id = "loc.y", energyCost = 0, walkSeconds = 60, levelGate = 1 }
		TestKit.equal(Travel.reentryPlan(free, TRAVEL).energyCost, 0)
		for id, location in Content.Locations do
			local run = Travel.plan(location, "run", TRAVEL).energyCost
			TestKit.truthy(Travel.reentryPlan(location, TRAVEL).energyCost <= run, `{id}: cheaper than a Run`)
		end
	end)

	test("startReentry spends Energy, flags the trip, and refuses a late arrival", function()
		local trip, energy = Travel.startReentry(QUARRY, ctx(20), T0 + 600)
		TestKit.equal((trip :: Travel.Trip).reentry, true)
		TestKit.equal((energy :: Energy.State).value, 12)
		local _, _, late = Travel.startReentry(QUARRY, ctx(20), T0 + TRAVEL.runSeconds)
		TestKit.equal(late, "tooLate", "would arrive after the cutoff")
		local _, _, broke = Travel.startReentry(QUARRY, ctx(3), T0 + 600)
		TestKit.equal(broke, "energy")
	end)

	test("rotating locations: open windows, countdowns, and trips refused while closed", function()
		local availability = CARAVAN.availability :: any
		TestKit.equal(Travel.isAvailable(availability, availability.offsetSeconds), true, "opens at the offset")
		local closesIn = Travel.secondsUntilChange(availability, availability.offsetSeconds + 60)
		TestKit.equal(closesIn, availability.activeSeconds - 60)
		local closedAt = availability.offsetSeconds + availability.activeSeconds
		TestKit.equal(Travel.isAvailable(availability, closedAt), false)
		TestKit.equal(
			Travel.secondsUntilChange(availability, closedAt),
			availability.periodSeconds - availability.activeSeconds
		)
		local _, _, reason = Travel.start(CARAVAN, "walk", ctx(50, closedAt))
		TestKit.equal(reason, "unavailable")
		TestKit.truthy(Travel.start(CARAVAN, "walk", ctx(50, availability.offsetSeconds + 10)), "open: allowed")
		TestKit.equal(Travel.secondsUntilChange(QUARRY.availability, T0), math.huge, "always open")
	end)

	test("the level gates follow GAME_DESIGN: Dense 8+, Black 15+", function()
		local _, _, reason = Travel.start(QUARRY, "walk", ctx(50, T0, 7))
		TestKit.equal(reason, "level")
		TestKit.truthy(Travel.start(QUARRY, "walk", ctx(50, T0, 8)), "level 8 may go")
		TestKit.equal(Content.Locations["loc.ashfall_depot"].levelGate, 15)
	end)

	test("a Walk can be checked against a deadline", function()
		local walk = Travel.plan(QUARRY, "walk", TRAVEL).seconds
		TestKit.equal(Travel.walkArrivesBefore(QUARRY, TRAVEL, T0, T0 + walk + 1), true)
		TestKit.equal(Travel.walkArrivesBefore(QUARRY, TRAVEL, T0, T0 + walk), false)
	end)

	test("turning back refunds a loading Run; walks and finished trips refund nothing", function()
		local run = Travel.start(QUARRY, "run", ctx(50)) :: Travel.Trip
		TestKit.equal(Travel.cancelRefund(run, T0 + 1), run.energySpent)
		TestKit.equal(Travel.cancelRefund(run, run.arrivesAt), 0, "already there")
		local walk = Travel.start(QUARRY, "walk", ctx(50)) :: Travel.Trip
		TestKit.equal(Travel.cancelRefund(walk, T0 + 1), 0)
	end)

	test("Energy shortfall for the refill slot, and refunds that may pass the cap", function()
		local state = { value = 9, updatedAt = T0 }
		TestKit.equal(Energy.shortfall(state, T0, ENERGY, 15), 6)
		TestKit.equal(Energy.shortfall(state, T0 + 6 * ENERGY.secondsPerPoint, ENERGY, 15), 0, "regen closes it")
		local full = { value = ENERGY.cap, updatedAt = T0 }
		local refunded = Energy.refund(full, T0, ENERGY, 15)
		TestKit.equal(refunded.value, ENERGY.cap + 15, "a refund is never lost at the cap")
	end)
end
