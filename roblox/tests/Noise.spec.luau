--!strict
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Noise = require("../src/shared/Domain/Noise")

local T0 = 500
local CONFIG = Content.Tuning.noise
local PISTOL = (Content.Items["item.pipe_pistol"] :: any).weapon.firearm
local SHOTGUN = (Content.Items["item.scrap_shotgun"] :: any).weapon.firearm

local function listener(id: string, x: number, hearing: number?): Noise.Listener
	return { id = id, position = { x = x, z = 0 }, hearing = hearing or 1 }
end

return function(test: TestKit.Register)
	test("each gun has its own radius; melee and bows are quiet", function()
		TestKit.equal(Noise.radius("gunshot", CONFIG, PISTOL), PISTOL.noiseRadius)
		TestKit.equal(Noise.radius("gunshot", CONFIG, SHOTGUN), SHOTGUN.noiseRadius)
		TestKit.truthy(SHOTGUN.noiseRadius > PISTOL.noiseRadius, "the shotgun is louder")
		TestKit.truthy(Noise.radius("melee", CONFIG) < PISTOL.noiseRadius / 4, "melee is the stealth option")
		TestKit.truthy(Noise.radius("bow", CONFIG) < Noise.radius("melee", CONFIG), "bows are quieter still")
		TestKit.equal(Noise.radius("sprint", CONFIG), CONFIG.sprint)
		TestKit.equal(Noise.radius("bloaterBurst", CONFIG), CONFIG.bloaterBurst)
		TestKit.equal(Noise.radius("walk", CONFIG), 0, "walking is silent")
		TestKit.throws(function()
			Noise.radius("gunshot", CONFIG, nil)
		end, "firearm stats")
	end)

	test("a noise shrinks to nothing over decaySeconds", function()
		local shot = Noise.new(1, "gunshot", { x = 0, z = 0 }, T0, CONFIG, PISTOL, "u1")
		TestKit.equal(Noise.effectiveRadius(shot, T0, CONFIG), PISTOL.noiseRadius)
		TestKit.equal(Noise.effectiveRadius(shot, T0 + CONFIG.decaySeconds / 2, CONFIG), PISTOL.noiseRadius / 2)
		TestKit.equal(Noise.effectiveRadius(shot, T0 + CONFIG.decaySeconds, CONFIG), 0)
		TestKit.equal(Noise.effectiveRadius(shot, T0 - 1, CONFIG), 0, "not yet made")
		TestKit.equal(#Noise.prune({ shot }, T0 + 1, CONFIG), 1)
		TestKit.equal(#Noise.prune({ shot }, T0 + CONFIG.decaySeconds, CONFIG), 0)
	end)

	test("a gunshot pulls every Hollow in range; a swing only the closest", function()
		local hollows = { listener("h1", 6), listener("h2", 60), listener("h3", 200) }
		local shot = Noise.new(1, "gunshot", { x = 0, z = 0 }, T0, CONFIG, PISTOL)
		TestKit.deepEqual(Noise.heardBy(shot, hollows, T0, CONFIG), { "h1", "h2" })
		local swing = Noise.new(2, "melee", { x = 0, z = 0 }, T0, CONFIG)
		TestKit.deepEqual(Noise.heardBy(swing, hollows, T0, CONFIG), { "h1" })
	end)

	test("hearing scales the reach: a sharp-eared Runner hears from further", function()
		local shot = Noise.new(1, "gunshot", { x = 0, z = 0 }, T0, CONFIG, PISTOL)
		local far = PISTOL.noiseRadius + 10
		TestKit.deepEqual(Noise.heardBy(shot, { listener("dull", far, 1) }, T0, CONFIG), {})
		local runner = Content.Enemies["enemy.runner"]
		TestKit.deepEqual(Noise.heardBy(shot, { listener("runner", far, runner.hearing) }, T0, CONFIG), { "runner" })
	end)

	test("the loudest noise wins for each listener", function()
		local near = Noise.new(1, "sprint", { x = 5, z = 0 }, T0, CONFIG)
		local shot = Noise.new(2, "gunshot", { x = 40, z = 0 }, T0, CONFIG, SHOTGUN)
		local heard = Noise.loudest({ near, shot }, listener("h", 0), T0, CONFIG)
		TestKit.equal((heard :: Noise.Event).id, 2, "the shotgun drowns out footsteps")
		TestKit.equal(Noise.loudest({ near }, listener("h", 500), T0, CONFIG), nil, "out of earshot")
	end)
end
