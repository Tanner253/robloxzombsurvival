--!strict
-- Specs for Shared/Clock: the day/night cycle from server time.
local TestKit = require("./TestKit")
local Clock = require("../src/shared/Clock")
local Content = require("../src/shared/Data")

return function(test: TestKit.Register)
	test("the clock runs through a whole day each cycle, smoothly", function()
		local cycle = Content.Tuning.dayNight.cycleSeconds
		local last = Clock.hoursAt(0)
		local wraps = 0
		for t = 1, cycle do
			local hours = Clock.hoursAt(t)
			TestKit.truthy(hours >= 0 and hours < 24, `hour {hours} out of range`)
			if hours < last then
				wraps += 1
				TestKit.truthy(last > 23.9 and hours < 0.1, "only wraps at midnight")
			else
				TestKit.truthy(hours - last < 0.1, "no jumps second to second")
			end
			last = hours
		end
		TestKit.equal(wraps, 1, "one midnight per cycle")
		TestKit.truthy(math.abs(Clock.hoursAt(0) - Clock.hoursAt(cycle)) < 1e-6, "repeats")
	end)

	test("daylight eases between night and day with day longer than night", function()
		TestKit.equal(Clock.daylight(12), 1)
		TestKit.equal(Clock.daylight(0), 0)
		TestKit.equal(Clock.daylight(21), 0)
		local dusk = Clock.daylight(18.5)
		TestKit.truthy(dusk > 0 and dusk < 1, "dusk is in between")
		local cycle = Content.Tuning.dayNight.cycleSeconds
		local dayTime = 0
		for t = 0, cycle - 1, 10 do
			if Clock.daylight(Clock.hoursAt(t)) > 0.5 then
				dayTime += 10
			end
		end
		TestKit.truthy(dayTime > cycle * 0.6, "days are longer than nights")
		TestKit.equal(Clock.label(6.5), "06:30")
	end)

	test("the sun stays high all day and sets during dusk", function()
		TestKit.truthy(Clock.sunTime(9) >= 8 and Clock.sunTime(17) <= 16, "high sun by day")
		TestKit.truthy(Clock.sunTime(18.5) > 16 and Clock.sunTime(18.5) < 19.6, "setting at dusk")
		TestKit.truthy(math.abs(Clock.sunTime(23.99) - 23.99) < 0.05, "night follows the clock")
		local last = Clock.sunTime(0)
		for step = 1, 240 do
			local now = Clock.sunTime(step / 10)
			if step < 240 then
				TestKit.truthy(now >= last, `sun time never runs backwards at {step / 10}`)
			end
			last = now
		end
	end)
end
