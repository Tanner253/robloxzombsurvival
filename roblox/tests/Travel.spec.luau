--!strict
local TestKit = require("./TestKit")
local Travel = require("../src/shared/Domain/Travel")

local T0 = 1_700_000_000
local PINES: Travel.Destination = { id = "loc.test_pines", energyCost = 6, walkSeconds = 20 * 60, levelGate = 1 }
local DEEP: Travel.Destination = { id = "loc.test_deep", energyCost = 12, walkSeconds = 60 * 60, levelGate = 5 }

local function ctx(value: number, level: number?): Travel.Context
	return {
		now = T0,
		level = level or 1,
		energy = { value = value, updatedAt = T0 },
		energyConfig = { cap = 20, secondsPerPoint = 60 },
		config = { runSeconds = 5 },
	}
end

return function(test: TestKit.Register)
	test("run costs energy and is quick; walk is free and slow", function()
		local config = { runSeconds = 5 }
		local run = Travel.plan(PINES, "run", config)
		local walk = Travel.plan(PINES, "walk", config)
		TestKit.equal(run.energyCost, 6, "run cost")
		TestKit.equal(run.seconds, 5, "run time")
		TestKit.equal(walk.energyCost, 0, "walk cost")
		TestKit.equal(walk.seconds, 1200, "walk time")
	end)

	test("multipliers round to the nearest point and second", function()
		local plan = Travel.plan(PINES, "run", { runSeconds = 5, energyMultiplier = 0.9 })
		TestKit.equal(plan.energyCost, 5, "6 * 0.9 = 5.4 -> 5")
		local walk = Travel.plan(PINES, "walk", { runSeconds = 5, walkMultiplier = 0.85 })
		TestKit.equal(walk.seconds, 1020)
	end)

	test("a run is never slower than walking", function()
		local near = { id = "loc.next_door", energyCost = 1, walkSeconds = 3, levelGate = 1 }
		TestKit.equal(Travel.plan(near, "run", { runSeconds = 5 }).seconds, 3)
	end)

	test("start spends energy for a run and stamps arrival", function()
		local trip, energy = Travel.start(PINES, "run", ctx(10))
		TestKit.equal((energy :: any).value, 4, "energy spent")
		TestKit.equal((trip :: Travel.Trip).arrivesAt, T0 + 5)
		TestKit.equal((trip :: Travel.Trip).energySpent, 6)
	end)

	test("start refuses a run without enough energy but allows the walk", function()
		local trip, energy, reason = Travel.start(PINES, "run", ctx(5))
		TestKit.equal(trip, nil)
		TestKit.equal(energy, nil)
		TestKit.equal(reason, "energy")
		local walkTrip, walkEnergy = Travel.start(PINES, "walk", ctx(0))
		TestKit.equal((walkTrip :: Travel.Trip).arrivesAt, T0 + 1200, "walk arrives later")
		TestKit.equal((walkEnergy :: any).value, 0, "walk is free")
	end)

	test("start enforces the location level gate", function()
		local _, _, reason = Travel.start(DEEP, "walk", ctx(20, 4))
		TestKit.equal(reason, "level")
		TestKit.truthy(Travel.start(DEEP, "walk", ctx(20, 5)), "level 5 may go")
	end)

	test("options report run affordability and the regen wait", function()
		local options = Travel.options(PINES, ctx(4))
		TestKit.equal(options.canRun, false)
		TestKit.equal(options.runReadyIn, 120, "two points at 60 s each")
		TestKit.equal(options.levelOk, true)
	end)

	test("arrival, remaining and progress follow the timestamps (offline walk)", function()
		local trip = Travel.start(PINES, "walk", ctx(0)) :: Travel.Trip
		TestKit.equal(Travel.hasArrived(trip, T0 + 1199), false, "one second early")
		TestKit.equal(Travel.hasArrived(trip, T0 + 1200), true, "on the boundary")
		TestKit.equal(Travel.remaining(trip, T0 + 600), 600)
		TestKit.equal(Travel.progress(trip, T0 + 300), 0.25)
		TestKit.equal(Travel.progress(trip, T0 + 99_999), 1, "logged back in long after")
	end)
end
