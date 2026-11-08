--!strict
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Combat = require("../src/shared/Domain/Combat")
local Rng = require("../src/shared/Domain/Rng")

local T0 = 1_000
local TUNING = Content.Tuning
local COMBAT: Combat.CombatConfig = TUNING.combat
local MELEE = TUNING.melee
local STAMINA = TUNING.stamina

local function weapon(itemId: string): any
	return (Content.Items[itemId] :: any).weapon
end

local function near(actual: number, expected: number, label: string)
	if math.abs(actual - expected) > 1e-6 then
		error(`{label}: expected {expected}, got {actual}`, 2)
	end
end

-- A source whose NextNumber always returns `value`.
local function fixed(value: number): Rng.Source
	local source: Rng.Source = {
		NextNumber = function(_self: Rng.Source): number
			return value
		end,
		NextInteger = function(_self: Rng.Source, min: number, _max: number): number
			return min
		end,
	}
	return source
end

return function(test: TestKit.Register)
	test("damage: multipliers, crit, then armor (LDoE's reduction)", function()
		near(Combat.armorReduction(0, 50 / 3), 0, "no armor")
		near(Combat.armorReduction(50 / 3, 50 / 3), 0.5, "defense equal to k halves it")
		local amount = Combat.damage({
			base = 20,
			multiplier = 1.5,
			crit = true,
			critMultiplier = 2,
			defense = 50 / 3,
			armorConstant = 50 / 3,
		})
		near(amount, 30, "20 x 1.5 x 2 x 0.5")
	end)

	test("crits use the weapon's chance, else the default", function()
		near(Combat.critChance(weapon("item.machete"), COMBAT), 0.12, "machete override")
		near(Combat.critChance(weapon("item.spiked_club"), COMBAT), COMBAT.critChance, "default")
		TestKit.equal(Combat.rollCrit(0.1, fixed(0.05)), true)
		TestKit.equal(Combat.rollCrit(0.1, fixed(0.5)), false)
		TestKit.equal(Combat.rollCrit(0, fixed(0)), false, "zero never crits")
	end)

	test("melee: heavy swings hit harder, knock back further and cost more stamina", function()
		local axe = weapon("item.fire_axe")
		local stats = Combat.meleeStats(axe, MELEE)
		TestKit.equal(stats.arcDegrees, 80, "the axe's own arc")
		TestKit.equal(stats.heavyMultiplier, MELEE.heavyMultiplier, "default heavy")
		local ctx = { rng = fixed(0.99), combat = COMBAT }
		local light = Combat.meleeHit(axe, stats, false, ctx)
		local heavy = Combat.meleeHit(axe, stats, true, ctx)
		near(light.damage, axe.damage, "light")
		near(heavy.damage, axe.damage * MELEE.heavyMultiplier, "heavy")
		TestKit.truthy(heavy.knockbackStuds > light.knockbackStuds, "heavy knocks back further")
		TestKit.truthy(heavy.hitStopSeconds > light.hitStopSeconds, "and stops longer")
		near(light.hitStopSeconds, MELEE.hitStopSeconds, "about 60 ms (13.4)")
		TestKit.truthy(Combat.meleeCost(stats, true) > Combat.meleeCost(stats, false), "stamina")
		near(Combat.swingSeconds(axe, stats, true), 1 / axe.attacksPerSecond + MELEE.heavyWindupSeconds, "wind-up")
	end)

	test("stamina spends, waits, then regenerates to max", function()
		local state = Combat.newStamina(STAMINA, T0)
		local spent = Combat.spendStamina(state, T0, 60, STAMINA) :: Combat.Stamina
		near(Combat.staminaAt(spent, T0 + STAMINA.regenDelaySeconds, STAMINA), 40, "no regen during the delay")
		near(Combat.staminaAt(spent, T0 + STAMINA.regenDelaySeconds + 1, STAMINA), 40 + STAMINA.regenPerSecond, "regen")
		near(Combat.staminaAt(spent, T0 + 999, STAMINA), STAMINA.max, "capped")
		TestKit.equal(Combat.spendStamina(spent, T0, 41, STAMINA), nil, "not enough")
	end)

	test("Pipe Pistol: one round, fire, reload from the bag", function()
		local gun = weapon("item.pipe_pistol").firearm
		local state = Combat.newGun(1)
		TestKit.truthy(Combat.canFire(gun, state, T0), "loaded")
		state = Combat.fire(state, T0)
		local _, empty = Combat.canFire(gun, state, T0 + 5)
		TestKit.equal(empty, "empty")
		local _, noAmmo = Combat.startReload(gun, state, T0 + 1, 0)
		TestKit.equal(noAmmo, "noAmmo", "dry click")
		state = Combat.startReload(gun, state, T0 + 1, 7) :: Combat.Gun
		TestKit.equal(Combat.isReloading(state, T0 + 1.5), true)
		local _, reloading = Combat.canFire(gun, state, T0 + 1.5)
		TestKit.equal(reloading, "reloading")
		local early, none = Combat.finishReload(gun, state, T0 + 2, 7)
		TestKit.equal(none, 0, "not done yet")
		TestKit.equal(early.loaded, 0)
		local done, taken = Combat.finishReload(gun, state, T0 + 1 + gun.reloadSeconds, 7)
		TestKit.equal(taken, 1, "one round moves from the bag")
		TestKit.equal(done.loaded, 1)
		local _, full = Combat.startReload(gun, done, T0 + 9, 6)
		TestKit.equal(full, "full")
	end)

	test("Scrap Shotgun: two barrels, a fire interval, a partial reload, cancel costs nothing", function()
		local gun = weapon("item.scrap_shotgun").firearm
		local state = Combat.newGun(2)
		state = Combat.fire(state, T0)
		local _, cooldown = Combat.canFire(gun, state, T0 + 0.1)
		TestKit.equal(cooldown, "cooldown")
		TestKit.truthy(Combat.canFire(gun, state, T0 + gun.fireInterval), "second barrel")
		state = Combat.startReload(gun, state, T0 + 1, 1) :: Combat.Gun
		local cancelled = Combat.cancelReload(state)
		TestKit.equal(cancelled.reloadEndsAt, nil)
		TestKit.equal(cancelled.loaded, 1, "nothing lost")
		state = Combat.startReload(gun, cancelled, T0 + 2, 1) :: Combat.Gun
		local done, taken = Combat.finishReload(gun, state, T0 + 2 + gun.reloadSeconds, 1)
		TestKit.equal(taken, 1, "only what is carried")
		TestKit.equal(done.loaded, 2)
	end)

	test("shotgun pellets fan across the spread cone", function()
		local gun = weapon("item.scrap_shotgun").firearm
		local yaws = Combat.shotYaws(gun, 0, Rng.new(7))
		TestKit.equal(#yaws, gun.pellets)
		local half = math.rad(gun.spreadDegrees) / 2
		for _, yaw in yaws do
			TestKit.truthy(math.abs(yaw) <= half + 1e-9, "inside the cone")
		end
		TestKit.equal(#Combat.shotYaws(weapon("item.pipe_pistol").firearm, 1, Rng.new(1)), 1, "pistols fire one")
	end)

	test("falloff: full damage up close, falloffMin at range", function()
		local def = weapon("item.scrap_shotgun")
		near(Combat.falloff(def.firearm, def.range, 5), 1, "inside falloffStart")
		near(Combat.falloff(def.firearm, def.range, def.range), def.firearm.falloffMin, "at range")
		local mid = Combat.falloff(def.firearm, def.range, (def.firearm.falloffStart + def.range) / 2)
		near(mid, (1 + def.firearm.falloffMin) / 2, "linear")
		near(Combat.falloff(weapon("item.flare_pistol").firearm, 60, 59), 1, "no falloff data, no falloff")
		near(Combat.travelSeconds(320, 320), 1, "travel time")
	end)

	test("the item card's attacksPerSecond is the sustained rate", function()
		for _, itemId in { "item.pipe_pistol", "item.scrap_shotgun", "item.flare_pistol" } do
			local def = weapon(itemId)
			near(def.attacksPerSecond, Combat.sustainedRate(def.firearm), itemId)
		end
	end)

	test("bow: draw time, duds and arrow recovery", function()
		local bow = weapon("item.shortbow").bow
		near(Combat.drawFraction(bow, T0, T0 + bow.drawSeconds / 2), 0.5, "half draw")
		near(Combat.drawFraction(bow, T0, T0 + 99), 1, "capped")
		TestKit.equal(Combat.release(bow, T0, T0 + 0.01), nil, "a dud")
		near(Combat.release(bow, T0, T0 + bow.drawSeconds) :: number, 1, "full draw")
		TestKit.equal(Combat.arrowRecovered(bow, fixed(bow.recoveryChance - 0.01)), true)
		TestKit.equal(Combat.arrowRecovered(bow, fixed(bow.recoveryChance)), false)
	end)

	test("dodge roll: stamina, cooldown and an i-frame window", function()
		local config = TUNING.dodge
		local stamina = Combat.newStamina(STAMINA, T0)
		local dodge, after = Combat.dodge(Combat.newDodge(), stamina, T0, config, STAMINA)
		TestKit.truthy(dodge, "rolled")
		near(Combat.staminaAt(after :: Combat.Stamina, T0, STAMINA), STAMINA.max - config.staminaCost, "cost")
		TestKit.equal(Combat.invulnerable(dodge :: Combat.Dodge, T0 + config.iframeSeconds - 0.01), true)
		TestKit.equal(Combat.invulnerable(dodge :: Combat.Dodge, T0 + config.iframeSeconds), false)
		local _, _, cooldown = Combat.dodge(dodge :: Combat.Dodge, after :: Combat.Stamina, T0 + 0.1, config, STAMINA)
		TestKit.equal(cooldown, "cooldown")
		local tired = { value = 5, updatedAt = T0, regenFrom = T0 + 10 }
		local _, _, reason = Combat.dodge(Combat.newDodge(), tired, T0, config, STAMINA)
		TestKit.equal(reason, "stamina")
	end)

	test("TTK: no weapon one-shots a full-health survivor, even on a heavy crit", function()
		local maxHealth = TUNING.player.maxHealth
		for itemId, item in Content.Items do
			if item.weapon then
				local biggest = Combat.maxHit(item.weapon, COMBAT, MELEE)
				TestKit.truthy(biggest < maxHealth, `{itemId}: biggest hit {biggest} must be under {maxHealth}`)
				local capped = Combat.pvpCap(biggest, maxHealth, COMBAT)
				TestKit.truthy(Combat.hitsToKill(capped, maxHealth) >= 2, `{itemId}: at least two hits`)
			end
		end
	end)

	test("the PvP cap and hitsToKill", function()
		near(Combat.pvpCap(150, 100, COMBAT), 100 * COMBAT.pvpMaxHitFraction, "capped")
		near(Combat.pvpCap(20, 100, COMBAT), 20, "small hits untouched")
		TestKit.equal(Combat.hitsToKill(34, 100), 3, "the Pipe Pistol kills a survivor in 3")
		TestKit.equal(Combat.hitsToKill(50, 100), 2)
		TestKit.equal(Combat.hitsToKill(0, 100), math.huge)
	end)

	test("the Pipe Pistol drops a Shambler in two body shots and a Runner in three", function()
		local pistol = weapon("item.pipe_pistol")
		TestKit.equal(Combat.hitsToKill(pistol.damage, Content.Enemies["enemy.shambler"].hp), 2)
		TestKit.equal(Combat.hitsToKill(pistol.damage, Content.Enemies["enemy.runner"].hp), 3)
	end)
end
