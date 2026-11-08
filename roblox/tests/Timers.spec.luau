--!strict
local TestKit = require("./TestKit")
local Timers = require("../src/shared/Domain/Timers")

local T0 = 1_700_000_000 -- an arbitrary UTC timestamp

return function(test: TestKit.Register)
	test("a timer reports remaining time, progress and completion", function()
		local timer = Timers.start(T0, 100)
		TestKit.equal(Timers.remaining(timer, T0 + 40), 60, "remaining")
		TestKit.equal(Timers.progress(timer, T0 + 25), 0.25, "progress")
		TestKit.equal(Timers.isDone(timer, T0 + 99), false, "not done")
		TestKit.equal(Timers.isDone(timer, T0 + 100), true, "done")
		TestKit.equal(Timers.remaining(timer, T0 + 500), 0, "remaining clamps at 0")
	end)

	test("progress clamps when the clock reads before the start", function()
		local timer = Timers.start(T0, 10)
		TestKit.equal(Timers.progress(timer, T0 - 50), 0)
		TestKit.equal(Timers.progress(Timers.start(T0, 0), T0), 1, "zero-length timer")
	end)

	test("queued jobs run back to back", function()
		local queue = Timers.enqueue({}, T0, "recipe.plank", 60, 3) :: Timers.Queue
		queue = Timers.enqueue(queue, T0 + 10, "recipe.plank", 60, 3) :: Timers.Queue
		TestKit.equal(queue[2].startsAt, T0 + 60, "second starts when first ends")
		TestKit.equal(queue[2].endsAt, T0 + 120, "second end")
	end)

	test("an idle queue starts a new job now", function()
		local queue = Timers.enqueue({}, T0, "a", 10, 3) :: Timers.Queue
		queue = Timers.enqueue(queue, T0 + 500, "b", 10, 3) :: Timers.Queue
		TestKit.equal(queue[2].startsAt, T0 + 500)
	end)

	test("enqueue refuses when all slots are used", function()
		local queue = Timers.enqueue({}, T0, "a", 10, 1) :: Timers.Queue
		TestKit.equal(Timers.enqueue(queue, T0, "b", 10, 1), nil)
	end)

	test("collect applies offline progress across several jobs", function()
		local queue: Timers.Queue = {}
		for _ = 1, 3 do
			queue = Timers.enqueue(queue, T0, "recipe.plank", 60, 5) :: Timers.Queue
		end
		-- The player logs back in 150 s later: two jobs are done, one is running.
		local pending, finished = Timers.collect(queue, T0 + 150)
		TestKit.equal(#finished, 2, "finished")
		TestKit.equal(#pending, 1, "pending")
		TestKit.equal(pending[1].endsAt, T0 + 180, "pending job keeps its timestamps")
	end)

	test("accrue regenerates whole units and keeps partial progress", function()
		-- 1 unit per 60 s; 150 s offline gives 2 units, 30 s carried toward the next.
		local value, updatedAt = Timers.accrue(5, T0, T0 + 150, 20, 60)
		TestKit.equal(value, 7, "value")
		TestKit.equal(updatedAt, T0 + 120, "timestamp advanced by whole units")
		local nextValue = Timers.accrue(value, updatedAt, T0 + 180, 20, 60)
		TestKit.equal(nextValue, 8, "carried 30 s + 30 s = one more unit")
	end)

	test("accrue stops at the cap and never reduces a value above it", function()
		local value, updatedAt = Timers.accrue(18, T0, T0 + 10_000, 20, 60)
		TestKit.equal(value, 20, "capped")
		TestKit.equal(updatedAt, T0 + 10_000, "clock restarts at cap")
		local over = Timers.accrue(35, T0, T0 + 10_000, 20, 60)
		TestKit.equal(over, 35, "purchased overflow kept")
	end)

	test("accrue ignores a clock that went backwards", function()
		local value, updatedAt = Timers.accrue(5, T0, T0 - 600, 20, 60)
		TestKit.equal(value, 5, "no change")
		TestKit.equal(updatedAt, T0, "timestamp kept")
	end)
end
