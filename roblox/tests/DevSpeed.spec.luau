--!strict
-- Specs for Shared/DevSpeed: the Studio-only pacing multiplier (DECISIONS 2026-11-08).
local TestKit = require("./TestKit")
local DevSpeed = require("../src/shared/DevSpeed")

local function sample(): any
	return {
		Recipes = { r = { craftSeconds = 60 } },
		Nodes = { n = { respawnSeconds = 180, xpPerHit = 20, yields = { { perHit = 2 } } } },
		Tuning = {
			devSpeed = 1,
			energy = { secondsPerPoint = 300 },
			home = { regrowHours = { n = { min = 8, max = 12 } } },
		},
	}
end

return function(test: TestKit.Register)
	test("live servers always run at 1, whatever the data says", function()
		TestKit.equal(DevSpeed.resolve(10, false), 1)
		TestKit.equal(DevSpeed.resolve(nil, false), 1)
	end)

	test("Studio is off by default and on only by the explicit attribute", function()
		TestKit.equal(DevSpeed.resolve(1, true, nil), 1, "default off")
		TestKit.equal(DevSpeed.resolve(1, true, 10), 10, "Workspace DevSpeed attribute")
		TestKit.equal(DevSpeed.resolve(1, true, 0.2), 1, "never below 1")
		TestKit.equal(DevSpeed.resolve(1, false, 10), 1, "never on a live server")
	end)

	test("apply compresses timers only: yields and XP never change", function()
		local content = sample()
		DevSpeed.apply(content, 10)
		DevSpeed.apply(content, 10) -- a second call changes nothing
		TestKit.equal(content.Recipes.r.craftSeconds, 6)
		TestKit.equal(content.Nodes.n.respawnSeconds, 18)
		TestKit.equal(content.Tuning.energy.secondsPerPoint, 30)
		TestKit.equal(content.Tuning.home.regrowHours.n.min, 0.8)
		TestKit.equal(content.Nodes.n.xpPerHit, 20, "XP unchanged")
		TestKit.equal(content.Nodes.n.yields[1].perHit, 2, "yield unchanged")
	end)

	test("a factor of 1 leaves the content alone", function()
		local content = sample()
		DevSpeed.apply(content, 1)
		TestKit.equal(content.Recipes.r.craftSeconds, 60)
		TestKit.equal(content.Tuning.energy.secondsPerPoint, 300)
	end)
end
