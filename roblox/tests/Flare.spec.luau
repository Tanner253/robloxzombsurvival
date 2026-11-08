--!strict
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Flare = require("../src/shared/Domain/Flare")

local T0 = 100
local STATS = (Content.Items["item.flare"] :: any).flare
local AT = { x = 0, z = 0 }

local function near(actual: number, expected: number, label: string)
	if math.abs(actual - expected) > 1e-6 then
		error(`{label}: expected {expected}, got {actual}`, 2)
	end
end

return function(test: TestKit.Register)
	test("a Signal Flare burns for 20 s (checklist 13.8)", function()
		local flare = Flare.new(1, STATS, AT, T0, "u1")
		TestKit.equal(STATS.seconds, 20)
		TestKit.equal(Flare.isLit(flare, T0 + 19.9), true)
		TestKit.equal(Flare.isLit(flare, T0 + 20), false)
		TestKit.equal(#Flare.prune({ flare }, T0 + 20), 0)
		TestKit.equal(#Flare.prune({ flare }, T0 + 5), 1)
	end)

	test("light is full inside the flee radius and fades to the edge", function()
		local flare = Flare.new(1, STATS, AT, T0)
		near(Flare.exposure(flare, { x = STATS.fleeRadius, z = 0 }, T0 + 1), 1, "flee radius")
		local mid = (STATS.fleeRadius + STATS.lightRadius) / 2
		near(Flare.exposure(flare, { x = mid, z = 0 }, T0 + 1), 0.5, "half way out")
		near(Flare.exposure(flare, { x = STATS.lightRadius, z = 0 }, T0 + 1), 0, "the edge")
		TestKit.equal(Flare.inFleeRadius(flare, { x = 1, z = 1 }, T0 + 1), true)
	end)

	test("the light dims over its last two seconds", function()
		local flare = Flare.new(1, STATS, AT, T0)
		near(Flare.exposure(flare, AT, T0 + STATS.seconds - 1), 0.5, "one second left")
		near(Flare.exposure(flare, AT, T0 + STATS.seconds), 0, "out")
	end)

	test("a flare's core turns even a Runner; a Shambler backs off from its glow", function()
		local flare = Flare.new(1, STATS, AT, T0)
		local runner = Content.Enemies["enemy.runner"]
		local shambler = Content.Enemies["enemy.shambler"]
		local glow = { x = STATS.fleeRadius + (STATS.lightRadius - STATS.fleeRadius) * 0.5, z = 0 }
		local exposure = Flare.exposure(flare, glow, T0 + 1)
		TestKit.truthy(exposure >= shambler.lightFear, "a Shambler flees the glow")
		TestKit.truthy(exposure < runner.lightFear, "a Runner holds its ground there")
		TestKit.truthy(Flare.exposure(flare, AT, T0 + 1) >= runner.lightFear, "but not in the core")
	end)

	test("the strongest of several flares is the one that counts", function()
		local a = Flare.new(1, STATS, { x = 0, z = 0 }, T0)
		local b = Flare.new(2, STATS, { x = 30, z = 0 }, T0)
		local value, source = Flare.strongest({ a, b }, { x = 28, z = 0 }, T0 + 1)
		near(value, 1, "inside b's core")
		TestKit.equal((source :: any).x, 30)
		local none = Flare.strongest({}, AT, T0)
		TestKit.equal(none, 0)
	end)

	test("a direct hit burns: dps for burnSeconds, refreshed by a new hit", function()
		local burn = Flare.ignite(STATS, T0, nil) :: Flare.Burn
		near(Flare.burnDamage(burn, T0, T0 + 1), STATS.burnDps, "one second")
		near(
			Flare.burnDamage(burn, T0 + STATS.burnSeconds - 0.5, T0 + STATS.burnSeconds + 3),
			STATS.burnDps * 0.5,
			"burns out"
		)
		local refreshed = Flare.ignite(STATS, T0 + 2, burn) :: Flare.Burn
		TestKit.equal(refreshed.endsAt, T0 + 2 + STATS.burnSeconds)
		local cold = table.clone(STATS)
		cold.burnDps = 0
		TestKit.equal(Flare.ignite(cold, T0, nil), nil, "nothing to burn with")
	end)
end
