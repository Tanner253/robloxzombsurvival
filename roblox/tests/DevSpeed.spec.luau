--!strict
-- Specs for Shared/DevSpeed: the Studio-only pacing multiplier (DECISIONS 2026-11-08).
local TestKit = require("./TestKit")
local DevSpeed = require("../src/shared/DevSpeed")

local function sample(): any
	return {
		Recipes = { r = { craftSeconds = 60 } },
		Nodes = { n = { respawnSeconds = 180, xpPerHit = 20, yields = { { perHit = 2 } } } },
		Tuning = { devSpeed = 10, energy = { secondsPerPoint = 300 } },
	}
end

return function(test: TestKit.Register)
	test("live servers always run at 1, whatever the data says", function()
		TestKit.equal(DevSpeed.resolve(10, false), 1)
		TestKit.equal(DevSpeed.resolve(nil, false), 1)
	end)

	test("Studio uses Tuning.devSpeed, never below 1", function()
		TestKit.equal(DevSpeed.resolve(10, true), 10)
		TestKit.equal(DevSpeed.resolve(0.2, true), 1)
	end)

	test("apply scales timers down and yields and XP up, once", function()
		local content = sample()
		DevSpeed.apply(content, 10)
		DevSpeed.apply(content, 10) -- a second call changes nothing
		TestKit.equal(content.Recipes.r.craftSeconds, 6)
		TestKit.equal(content.Nodes.n.respawnSeconds, 18)
		TestKit.equal(content.Nodes.n.xpPerHit, 200)
		TestKit.equal(content.Nodes.n.yields[1].perHit, 20)
		TestKit.equal(content.Tuning.energy.secondsPerPoint, 30)
	end)

	test("a factor of 1 leaves the content alone", function()
		local content = sample()
		DevSpeed.apply(content, 1)
		TestKit.equal(content.Recipes.r.craftSeconds, 60)
		TestKit.equal(content.Tuning.energy.secondsPerPoint, 300)
	end)
end
