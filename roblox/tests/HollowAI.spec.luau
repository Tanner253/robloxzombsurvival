--!strict
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local HollowAI = require("../src/shared/Domain/HollowAI")
local Rng = require("../src/shared/Domain/Rng")

local T0 = 1_000
local TUNING = Content.Tuning.hollow
local SHAMBLER = HollowAI.archetype(Content.Enemies["enemy.shambler"], TUNING)
local RUNNER = HollowAI.archetype(Content.Enemies["enemy.runner"], TUNING)
local BLOATER = HollowAI.archetype(Content.Enemies["enemy.bloater"], TUNING)
local HOME = { x = 0, z = 0 }

local function inputs(now: number, extra: { [string]: any }?): HollowAI.Inputs
	local base: { [string]: any } = {
		now = now,
		position = { x = 0, z = 0 },
		home = HOME,
		hp = 40,
		targets = {},
		noise = nil,
		light = nil,
		rng = Rng.new(11),
	}
	for key, value in extra or {} do
		base[key] = value
	end
	return base :: any
end

local function player(x: number, visible: boolean?): HollowAI.Target
	return { id = "u1", position = { x = x, z = 0 }, visible = if visible == nil then true else visible }
end

return function(test: TestKit.Register)
	test("ECONOMY §6.4: Hollow stats scale by fog tier on top of the bands; wildlife doesn't", function()
		local scale = Content.Tuning.hollowTierScale
		local shambler = Content.Enemies["enemy.shambler"]
		TestKit.deepEqual({ HollowAI.scaled(shambler, 1, scale, 1) }, { 40, 5 }, "Light: base stats")
		local hp, damage = HollowAI.scaled(shambler, 1, scale, 2)
		TestKit.equal(hp, 48, "Dense health")
		TestKit.truthy(math.abs(damage - 5.75) < 1e-9, "Dense damage")
		local worstHp = HollowAI.scaled(shambler, Content.Tuning.lobby.bands[3].hollowStrength, scale, 3) / shambler.hp
		TestKit.truthy(math.abs(worstHp - 2.03) < 0.01, `Black at band 3: HP x{worstHp}`)
		local wolf = Content.Enemies["enemy.wolf"]
		TestKit.deepEqual({ HollowAI.scaled(wolf, 1, scale, 3) }, { wolf.hp, wolf.damage }, "wildlife ignores the tier")
		TestKit.deepEqual({ HollowAI.scaled(shambler, 1.2) }, { 48, 6 }, "no scale given: the band alone")
	end)

	test("archetypes come from enemy data and Tuning.hollow", function()
		TestKit.equal(SHAMBLER.sightRadius, Content.Enemies["enemy.shambler"].aggroRadius)
		TestKit.equal(RUNNER.moveSpeed, 18)
		TestKit.truthy(BLOATER.burst, "the bloater bursts")
		TestKit.equal(SHAMBLER.burst, nil)
		local hp, damage = HollowAI.scaled(Content.Enemies["enemy.runner"], 1.5)
		TestKit.equal(hp, 105)
		TestKit.equal(damage, 9)
	end)

	test("idle, then wander near home, then idle again on arrival", function()
		local state = HollowAI.new(T0)
		local s1, o1 = HollowAI.step(SHAMBLER, state, inputs(T0))
		TestKit.equal(s1.name, "wander", "idle time is up at spawn")
		TestKit.equal(o1.action, "move")
		local goal = o1.moveTo :: any
		TestKit.truthy(math.sqrt(goal.x ^ 2 + goal.z ^ 2) <= TUNING.wanderRadius, "within the wander radius")
		TestKit.truthy(o1.speed < SHAMBLER.moveSpeed, "wandering is slow")
		local s2 = HollowAI.step(SHAMBLER, s1, inputs(T0 + 1, { position = goal }))
		TestKit.equal(s2.name, "idle", "arrived")
		local s3, o3 = HollowAI.step(SHAMBLER, s2, inputs(T0 + 1.5, { position = goal }))
		TestKit.equal(s3.name, "idle", "idles a moment")
		TestKit.equal(o3.action, "none")
	end)

	test("a visible player within sight is chased, with the alert cue", function()
		local state = HollowAI.new(T0)
		local s1, o1 = HollowAI.step(SHAMBLER, state, inputs(T0, { targets = { player(20) } }))
		TestKit.equal(s1.name, "chase")
		TestKit.equal(o1.cue, "alert", "the '!' read")
		TestKit.equal(o1.targetId, "u1")
		TestKit.equal(o1.speed, SHAMBLER.moveSpeed)
		local _, o2 = HollowAI.step(SHAMBLER, s1, inputs(T0 + 0.2, { targets = { player(19) } }))
		TestKit.equal(o2.cue, nil, "no repeat cue mid-chase")
	end)

	test("no line of sight or out of sight range: not seen", function()
		local state = HollowAI.new(T0)
		local behindWall = HollowAI.step(SHAMBLER, state, inputs(T0, { targets = { player(10, false) } }))
		TestKit.equal(behindWall.name, "wander")
		local tooFar = HollowAI.step(SHAMBLER, state, inputs(T0, { targets = { player(SHAMBLER.sightRadius + 1) } }))
		TestKit.equal(tooFar.name, "wander")
	end)

	test("attacks in range on its attack timer", function()
		local state = HollowAI.new(T0)
		local s1, o1 = HollowAI.step(SHAMBLER, state, inputs(T0, { targets = { player(3) } }))
		TestKit.equal(s1.name, "attack")
		TestKit.equal(o1.action, "attack")
		local s2, o2 = HollowAI.step(SHAMBLER, s1, inputs(T0 + 0.5, { targets = { player(3) } }))
		TestKit.equal(o2.action, "none", "waiting for the next swing")
		local _, o3 = HollowAI.step(SHAMBLER, s2, inputs(T0 + SHAMBLER.attackSeconds, { targets = { player(3) } }))
		TestKit.equal(o3.action, "attack")
	end)

	test("after losing sight it chases the last seen spot, then gives up", function()
		local state = HollowAI.new(T0)
		local s1 = HollowAI.step(SHAMBLER, state, inputs(T0, { targets = { player(20) } }))
		local s2, o2 = HollowAI.step(SHAMBLER, s1, inputs(T0 + 1, { targets = { player(25, false) } }))
		TestKit.equal(s2.name, "chase", "on memory")
		TestKit.equal((o2.moveTo :: any).x, 20, "to where it last saw them")
		local s3 = HollowAI.step(SHAMBLER, s2, inputs(T0 + TUNING.loseTargetSeconds + 0.1, { targets = {} }))
		TestKit.equal(s3.name, "idle", "lost the trail")
		TestKit.equal(s3.targetId, nil)
	end)

	test("a noise draws it to the spot, where it lingers, then calms down", function()
		local state = HollowAI.new(T0)
		local noise = { x = 40, z = 10 }
		local s1, o1 = HollowAI.step(SHAMBLER, state, inputs(T0, { noise = noise }))
		TestKit.equal(s1.name, "alert")
		TestKit.equal(o1.cue, "alert")
		TestKit.equal((o1.moveTo :: any).x, 40)
		local s2, o2 = HollowAI.step(SHAMBLER, s1, inputs(T0 + 2, { position = noise }))
		TestKit.equal(s2.name, "alert", "still alert")
		TestKit.equal(o2.action, "none", "lingers where the noise was")
		local s3 = HollowAI.step(SHAMBLER, s2, inputs(T0 + TUNING.alertSeconds + 0.1, { position = noise }))
		TestKit.equal(s3.name, "idle")
	end)

	test("light at or above its fear sends it fleeing directly away", function()
		local state = HollowAI.new(T0)
		local chasing = HollowAI.step(SHAMBLER, state, inputs(T0, { targets = { player(10) } }))
		local light = { exposure = 0.5, source = { x = 10, z = 0 } }
		local s1, o1 = HollowAI.step(SHAMBLER, chasing, inputs(T0 + 0.2, { targets = { player(10) }, light = light }))
		TestKit.equal(s1.name, "flee")
		TestKit.equal(o1.cue, "flee")
		TestKit.truthy((o1.moveTo :: any).x < 0, "away from the light")
		TestKit.truthy(o1.speed > SHAMBLER.moveSpeed, "flees fast")
		local s2, o2 = HollowAI.step(SHAMBLER, s1, inputs(T0 + 1, { targets = { player(10) } }))
		TestKit.equal(s2.name, "flee", "keeps fleeing for fleeSeconds")
		TestKit.equal(o2.cue, nil)
		local s3 = HollowAI.step(SHAMBLER, s2, inputs(T0 + 0.2 + TUNING.fleeSeconds, { targets = { player(10) } }))
		TestKit.equal(s3.name, "chase", "then comes back")
	end)

	test("a Runner shrugs off light that sends a Shambler running", function()
		local light = { exposure = 0.5, source = { x = 5, z = 0 } }
		local runner = HollowAI.step(RUNNER, HollowAI.new(T0), inputs(T0, { targets = { player(10) }, light = light }))
		TestKit.equal(runner.name, "chase")
		local shambler =
			HollowAI.step(SHAMBLER, HollowAI.new(T0), inputs(T0, { targets = { player(10) }, light = light }))
		TestKit.equal(shambler.name, "flee")
	end)

	test("the bloater lights its fuse in range, holds, then bursts", function()
		local state = HollowAI.new(T0)
		local s1, o1 = HollowAI.step(BLOATER, state, inputs(T0, { targets = { player(4) }, hp = 60 }))
		TestKit.equal(o1.action, "fuse")
		TestKit.equal(o1.cue, "fuse")
		local s2, o2 = HollowAI.step(BLOATER, s1, inputs(T0 + 0.4, { targets = { player(20) }, hp = 60 }))
		TestKit.equal(o2.action, "none", "a lit fuse can't be stopped by running")
		local fuse = (Content.Enemies["enemy.bloater"].burst :: any).fuseSeconds
		local s3, o3 = HollowAI.step(BLOATER, s2, inputs(T0 + fuse, { hp = 60 }))
		TestKit.equal(o3.action, "burst")
		TestKit.equal(s3.name, "dead")
		local _, o4 = HollowAI.step(BLOATER, s3, inputs(T0 + fuse + 1, { hp = 60 }))
		TestKit.equal(o4.action, "none", "bursts once")
	end)

	test("killing a bloater bursts it too; other Hollow just die", function()
		local s1, o1 = HollowAI.step(BLOATER, HollowAI.new(T0), inputs(T0, { hp = 0 }))
		TestKit.equal(s1.name, "dead")
		TestKit.equal(o1.action, "burst")
		local s2, o2 = HollowAI.step(SHAMBLER, HollowAI.new(T0), inputs(T0, { hp = -3 }))
		TestKit.equal(s2.name, "dead")
		TestKit.equal(o2.action, "none")
	end)

	test("step never changes the state it was given", function()
		local state = HollowAI.new(T0)
		HollowAI.step(SHAMBLER, state, inputs(T0, { targets = { player(10) } }))
		TestKit.equal(state.name, "idle")
		TestKit.equal(state.targetId, nil)
	end)
end
