--!strict
-- Domain/Trigger: one throw per press, and a gun that comes into the hand mid-hold (the last
-- grenade thrown) waits for a new press instead of firing on.
local TestKit = require("./TestKit")
local Trigger = require("../src/shared/Domain/Trigger")

return function(test: TestKit.Register)
	test("a press and its release throw exactly once", function()
		local state = Trigger.new()
		TestKit.truthy(Trigger.press(state, "throw"), "a new press")
		TestKit.equal(Trigger.press(state, "throw"), false, "a second down from another input path is the same press")
		TestKit.equal(Trigger.release(state, "throw"), "throw", "the release throws")
		TestKit.equal(Trigger.release(state, "throw"), nil, "a second up throws nothing")
		TestKit.equal(state.presses, 1)
	end)

	test("the bug: a grenade press, the hand switches to the rifle, nothing fires", function()
		local state = Trigger.new()
		Trigger.press(state, "throw")
		-- The last grenade left and the hand switched to the Assault Rifle during the hold.
		local shots = 0
		for _ = 1, 600 do
			if Trigger.firing(state, "gun") then
				shots += 1
			end
		end
		TestKit.equal(shots, 0, "no rounds on a hold that began with a grenade")
		TestKit.equal(Trigger.release(state, "gun"), nil, "and the release does nothing")
		Trigger.press(state, "gun")
		TestKit.truthy(Trigger.firing(state, "gun"), "a new press fires")
	end)

	test("a throwable put away mid-hold throws nothing", function()
		local state = Trigger.new()
		Trigger.press(state, "throw")
		TestKit.equal(Trigger.release(state, "melee"), nil)
	end)

	test("three grenades need three presses, each one past the interval", function()
		local state = Trigger.new()
		local thrown = 0
		local lastAt: number? = nil
		-- Presses 0.5 s apart: only those 1.5 s after the last throw go.
		for i = 0, 9 do
			local now = i * 0.5
			Trigger.press(state, "throw")
			if Trigger.release(state, "throw") == "throw" and Trigger.throwReady(lastAt, now, 1.5) then
				thrown += 1
				lastAt = now
			end
		end
		TestKit.equal(thrown, 4, "at 0, 1.5, 3 and 4.5 s")
	end)

	test("a cancelled hold completes nothing", function()
		local state = Trigger.new()
		Trigger.press(state, "gun")
		Trigger.cancel(state)
		TestKit.equal(Trigger.firing(state, "gun"), false)
		TestKit.equal(Trigger.release(state, "gun"), nil)
	end)
end
