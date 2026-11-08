--!strict
local TestKit = require("./TestKit")
local Survival = require("../src/shared/Domain/Survival")

local T0 = 1_700_000_000

-- 1 point per 10 s (LDoE), 2 HP/s at zero hunger, 0.5 + 1.5 HP/s for thirst.
local CONFIG: Survival.Config = {
	hunger = { max = 100, decayPerSecond = 0.1, thresholds = { { atOrBelow = 0, damagePerSecond = 2 } } },
	thirst = {
		max = 100,
		decayPerSecond = 0.1,
		thresholds = { { atOrBelow = 20, damagePerSecond = 0.5 }, { atOrBelow = 0, damagePerSecond = 1.5 } },
	},
}

local function near(actual: number, expected: number, label: string)
	if math.abs(actual - expected) > 1e-6 then
		error(`{label}: expected {expected}, got {actual}`, 2)
	end
end

return function(test: TestKit.Register)
	test("meters drain linearly from the timestamp", function()
		local state, damage = Survival.advance(Survival.new(T0, CONFIG), T0 + 300, CONFIG)
		near(state.hunger, 70, "hunger")
		near(state.thirst, 70, "thirst")
		TestKit.equal(state.updatedAt, T0 + 300)
		TestKit.equal(damage, 0, "no threshold reached")
	end)

	test("damage starts exactly when a meter crosses a threshold mid-interval", function()
		-- Hunger 10 hits 0 after 100 s; 150 s total leaves 50 s at zero: 100 HP.
		local state = { hunger = 10, thirst = 100, updatedAt = T0 }
		local after, damage = Survival.advance(state, T0 + 150, CONFIG)
		TestKit.equal(after.hunger, 0, "clamped at zero")
		near(damage, 100, "damage")
	end)

	test("thresholds are additive", function()
		-- Thirst 30: 100 s to reach 20, 300 s to reach 0. Over 400 s:
		-- 300 s at or below 20 (0.5/s) + 100 s at 0 (1.5/s) = 150 + 150.
		local state = { hunger = 100, thirst = 30, updatedAt = T0 }
		local _, damage = Survival.advance(state, T0 + 400, CONFIG)
		near(damage, 300, "damage")
		near(Survival.damagePerSecond({ hunger = 100, thirst = 0, updatedAt = T0 }, CONFIG), 2, "rate at zero")
	end)

	test("splitting an interval gives the same result as one long advance", function()
		local start = { hunger = 15, thirst = 25, updatedAt = T0 }
		local whole, wholeDamage = Survival.advance(start, T0 + 1000, CONFIG)
		local half, firstDamage = Survival.advance(start, T0 + 333, CONFIG)
		local rest, secondDamage = Survival.advance(half, T0 + 1000, CONFIG)
		near(rest.hunger, whole.hunger, "hunger")
		near(rest.thirst, whole.thirst, "thirst")
		near(firstDamage + secondDamage, wholeDamage, "damage")
	end)

	test("resume skips time away without draining", function()
		local state = Survival.resume({ hunger = 40, thirst = 40, updatedAt = T0 }, T0 + 86_400)
		local after, damage = Survival.advance(state, T0 + 86_400, CONFIG)
		TestKit.equal(after.hunger, 40, "an offline day costs nothing")
		TestKit.equal(damage, 0)
	end)

	test("a clock that went backwards drains nothing", function()
		local after, damage = Survival.advance({ hunger = 50, thirst = 50, updatedAt = T0 }, T0 - 100, CONFIG)
		TestKit.equal(after.hunger, 50)
		TestKit.equal(after.updatedAt, T0, "timestamp kept")
		TestKit.equal(damage, 0)
	end)

	test("consume drains first, then applies the effect clamped to max", function()
		local state = { hunger = 95, thirst = 10, updatedAt = T0 }
		local result = Survival.consume(state, T0 + 100, CONFIG, { hunger = 30, thirst = 50, health = 20, energy = 5 })
		near(result.state.hunger, 100, "85 + 30 clamps to 100")
		near(result.state.thirst, 50, "0 + 50")
		near(result.damage, 0.5 * 100 + 1.5 * 0, "thirst sat at or below 20 for 100 s, hit 0 exactly at the end")
		TestKit.equal(result.heal, 20)
		TestKit.equal(result.energy, 5)
	end)

	test("secondsUntil predicts when a meter reaches a level", function()
		local state = { hunger = 50, thirst = 20, updatedAt = T0 }
		near(Survival.secondsUntil(state, CONFIG, "hunger", 0), 500, "hunger to zero")
		TestKit.equal(Survival.secondsUntil(state, CONFIG, "thirst", 20), 0, "already at threshold")
	end)
end
