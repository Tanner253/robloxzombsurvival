--!strict
--[[
	The LDoE parity rulings for slice 2 (docs/LDOE_PARITY.md #31, #34, #35, #37, #38,
	#40, #43, #44, #45, #46), as data and pure logic.
]]
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local AutoClear = require("../src/shared/Domain/AutoClear")
local Combat = require("../src/shared/Domain/Combat")
local DeathRecovery = require("../src/shared/Domain/DeathRecovery")
local FogExposure = require("../src/shared/Domain/FogExposure")
local FogMap = require("../src/shared/Domain/FogMap")
local Hands = require("../src/shared/Domain/Hands")
local HollowAI = require("../src/shared/Domain/HollowAI")
local Inventory = require("../src/shared/Domain/Inventory")
local Lobby = require("../src/shared/Domain/Lobby")
local Noise = require("../src/shared/Domain/Noise")
local Rng = require("../src/shared/Domain/Rng")
local Travel = require("../src/shared/Domain/Travel")
local TravelBonus = require("../src/shared/Domain/TravelBonus")

local T0 = 1_700_006_400 -- a UTC midnight
local DAY = 24 * 60 * 60
local TUNING = Content.Tuning
local ITEMS = Content.Items :: any
local QUARRY = Content.Locations["loc.sunken_quarry"]

local function near(actual: number, expected: number, label: string)
	if math.abs(actual - expected) > 1e-6 then
		error(`{label}: expected {expected}, got {actual}`, 2)
	end
end

local function aiInputs(now: number, targets: { any }, extra: { [string]: any }?): HollowAI.Inputs
	local base: { [string]: any } = {
		now = now,
		position = { x = 0, z = 0 },
		home = { x = 0, z = 0 },
		hp = 30,
		targets = targets,
		rng = Rng.new(2),
	}
	for key, value in extra or {} do
		base[key] = value
	end
	return base :: any
end

local function travelCtx(value: number, extra: { [string]: any }?): Travel.Context
	local base: { [string]: any } = {
		now = T0,
		level = 20,
		energy = { value = value, updatedAt = T0 },
		energyConfig = TUNING.energy,
		config = TUNING.travel,
	}
	for key, v in extra or {} do
		base[key] = v
	end
	return base :: any
end

return function(test: TestKit.Register)
	-- #31 AUTO ---------------------------------------------------------------------------------
	test("#31 paid AUTO: ads from level 13, ten a day; Rations by tier", function()
		local config = TUNING.autoClear
		local daily = { day = 0, adsUsed = 0 }
		local ok, reason = AutoClear.canPay("ad", 2, 12, daily, 0, T0, config)
		TestKit.equal(ok, false)
		TestKit.equal(reason, "level")
		TestKit.truthy(AutoClear.canPay("ad", 2, 13, daily, 0, T0, config), "level 13")
		for _ = 1, config.adPerDay do
			daily = AutoClear.useAd(daily, T0)
		end
		local _, noAds = AutoClear.canPay("ad", 2, 20, daily, 0, T0 + 60, config)
		TestKit.equal(noAds, "noAds", "ten a day")
		TestKit.equal(AutoClear.adsLeft(daily, T0 + DAY, config), config.adPerDay, "a new UTC day")
		TestKit.equal(AutoClear.rationsCost(3, config), 3)
		local _, broke = AutoClear.canPay("rations", 3, 20, daily, 2, T0, config)
		TestKit.equal(broke, "rations")
		TestKit.truthy(AutoClear.canPay("premium", 3, 1, daily, 0, T0, config), "premium (S3)")
	end)

	test("#31 an AUTO clear rolls the containers, half the nodes and half the Hollow", function()
		local ctx = {
			tables = Content.LootTables :: any,
			nodes = Content.Nodes :: any,
			enemies = Content.Enemies :: any,
			items = ITEMS,
			rng = Rng.new(9),
			config = TUNING.autoClear,
		}
		local haul = AutoClear.roll(QUARRY, ctx)
		-- Rustwater, a loot hub since ECONOMY §6.3: 3-4 cabinets, 2-3 boots, 2-3 lockers.
		TestKit.truthy(haul.containers >= 7 and haul.containers <= 10, `containers {haul.containers}`)
		TestKit.truthy(haul.kills >= 5 and haul.kills <= 8, `kills {haul.kills}`)
		TestKit.truthy(haul.xp > 0 and #haul.items > 0, "XP and items")
		local stone = 0
		for _, stack in haul.items do
			if stack.itemId == "item.stone" then
				stone += stack.count
			end
		end
		TestKit.truthy(stone > 0, "boulders were broken")
		local replay = table.clone(ctx)
		replay.rng = Rng.new(9)
		TestKit.deepEqual(AutoClear.roll(QUARRY, replay), haul, "the same seed, the same haul")
	end)

	test("#31 AUTO harvests only the nodes the survivor's tools can cut", function()
		-- Ironbark Stand's nodes alone: its crates can hold logs too.
		local stand =
			{ containers = {}, nodes = Content.Locations["loc.ironbark_stand"].nodes, enemySpawns = {} } :: any
		local function logs(canHarvest: ((any) -> boolean)?): number
			local haul = AutoClear.roll(stand, {
				tables = Content.LootTables :: any,
				nodes = Content.Nodes :: any,
				enemies = Content.Enemies :: any,
				rng = Rng.new(4),
				config = TUNING.autoClear,
				canHarvest = canHarvest,
			})
			local count = 0
			for _, stack in haul.items do
				if stack.itemId == Content.Nodes["node.ironbark_tree"].yields[1].itemId then
					count += stack.count
				end
			end
			return count
		end
		TestKit.truthy(logs(nil) > 0, "ungated, ironbark falls")
		local noForgedHatchet = function(def: any): boolean
			return def.tool == nil or def.tool.tier < 2
		end
		TestKit.equal(logs(noForgedHatchet), 0, "without a Forged Hatchet, no ironbark logs")
	end)

	test("#31 in-world AUTO targets the nearest Hollow in its radius", function()
		local radius = TUNING.autoAttack.radiusStuds
		local candidates =
			{ { id = "h2", distance = 9 }, { id = "h1", distance = 5 }, { id = "h3", distance = radius + 1 } }
		TestKit.equal(Combat.autoTarget(candidates, radius), "h1")
		TestKit.equal(Combat.autoTarget({ { id = "h3", distance = radius + 1 } }, radius), nil)
	end)

	-- #34 tools ---------------------------------------------------------------------------------
	test("#34 a tool in a weapon slot swings as weak melee", function()
		local hands = Hands.new({ "item.stone_hatchet" }, ITEMS, TUNING.hands)
		TestKit.equal(Hands.weapon(hands, ITEMS), nil, "without melee tuning it's not a weapon")
		local weapon = Hands.weapon(hands, ITEMS, TUNING.melee) :: any
		TestKit.equal(weapon.kind, "melee")
		TestKit.truthy(weapon.damage < (ITEMS["item.spiked_club"].weapon.damage :: number), "weaker than a club")
		TestKit.equal(Combat.toolWeapon(ITEMS["item.timber"], TUNING.melee), nil, "timber is no tool")
	end)

	-- #35 wildlife ------------------------------------------------------------------------------
	test("#35 a deer bolts from a nearby player; a sneaking one gets closer", function()
		local deer = HollowAI.archetype(Content.Enemies["enemy.deer"], TUNING.hollow, TUNING.sneak)
		local spook = Content.Enemies["enemy.deer"].wildlife.spookRadius
		local close = { id = "u1", position = { x = spook - 1, z = 0 }, visible = true }
		local state, output = HollowAI.step(deer, HollowAI.new(T0), aiInputs(T0, { close }))
		TestKit.equal(state.name, "flee")
		TestKit.truthy((output.moveTo :: any).x < 0, "away from the player")
		local sneaking = { id = "u1", position = { x = spook - 1, z = 0 }, visible = true, sneaking = true }
		local calm = HollowAI.step(deer, HollowAI.new(T0), aiInputs(T0, { sneaking }))
		TestKit.equal(calm.name, "wander", "a sneak gets within reach")
		local _, heard = HollowAI.step(deer, HollowAI.new(T0), aiInputs(T0, {}, { noise = { x = 30, z = 0 } }))
		TestKit.equal(heard.action, "move")
		TestKit.truthy((heard.moveTo :: any).x < 0, "a gunshot sends it running the other way")
	end)

	test("#35 a wolf hunts like a Hollow; both give meat and hide", function()
		local wolf = HollowAI.archetype(Content.Enemies["enemy.wolf"], TUNING.hollow, TUNING.sneak)
		local prey = { id = "u1", position = { x = 10, z = 0 }, visible = true }
		local state = HollowAI.step(wolf, HollowAI.new(T0), aiInputs(T0, { prey }, { hp = 55 }))
		TestKit.equal(state.name, "chase")
		for _, id in { "loot.animal_deer", "loot.animal_wolf" } do
			local guaranteed = (Content.LootTables[id].guaranteed :: any)[1]
			TestKit.equal(guaranteed.itemId, "item.raw_meat", id)
		end
		-- Post-launch until our own rigs exist: nothing spawns them, and the defs say why.
		for _, id in { "enemy.deer", "enemy.wolf" } do
			TestKit.truthy(Content.Enemies[id].deferred ~= nil, `{id} is deferred`)
			for locationId, location in Content.Locations do
				for _, spawn in location.enemySpawns do
					TestKit.truthy(spawn.enemyId ~= id, `{locationId} doesn't spawn {id}`)
				end
			end
		end
	end)

	-- #37 fog exposure ---------------------------------------------------------------------------
	test("#37 Dense fog fills the meter in about 10 min, Black in 4; armor slows it", function()
		local config = TUNING.fogExposure
		near(FogExposure.secondsToFull(0, 2, 0, config), 600, "Dense, unprotected")
		near(FogExposure.secondsToFull(0, 3, 0, config), 240, "Black, unprotected")
		TestKit.equal(FogExposure.secondsToFull(0, 1, 0, config), math.huge, "Light fog never fills")
		local equipment = {
			head = { itemId = "item.padded_hood", count = 1 },
			body = { itemId = "item.padded_vest", count = 1 },
		}
		local resist = FogExposure.resist(equipment :: any, ITEMS, config)
		near(resist, 0.25, "hood 0.10 + vest 0.15")
		near(FogExposure.secondsToFull(0, 2, resist, config), 800, "padded gear buys time")
		local stacked = FogExposure.resist({ head = { itemId = "item.padded_vest", count = 1 } } :: any, ITEMS, {
			max = 100,
			ratePerTier = { 0, 1, 1 },
			maxResist = 0.1,
			damagePerSecond = 1,
		})
		near(stacked, 0.1, "capped at maxResist")
		TestKit.equal(FogExposure.damage(99, 1, config), 0, "no damage until full")
		near(FogExposure.damage(config.max, 0.5, config), config.damagePerSecond * 0.5, "full: it hurts")
		near(FogExposure.step(config.max - 1, 100, 3, 0, config), config.max, "clamped")
	end)

	-- #40 travel bonus prices --------------------------------------------------------------------
	test("#40 TAKE is an ad per item; TAKE ALL is Rations", function()
		TestKit.deepEqual(TravelBonus.price("one", TUNING.travelBonus), { method = "ad", count = 1 })
		TestKit.deepEqual(TravelBonus.price("all", TUNING.travelBonus), { method = "rations", count = 1 })
	end)

	-- #43 airdrops, gates, hurry ------------------------------------------------------------------
	test("#43 airdrops land as Energy falls below 140, 80 and 20, once each a day", function()
		local config = TUNING.airdrops
		local day = { day = 0, fired = {} }
		local crossed, day1 = FogMap.airdropsCrossed(150, 130, day, T0, config)
		TestKit.deepEqual(crossed, { 140 })
		local again = FogMap.airdropsCrossed(150, 130, day1, T0 + 60, config)
		TestKit.deepEqual(again, {}, "not twice in a day")
		local both = FogMap.airdropsCrossed(100, 10, day1, T0 + 120, config)
		TestKit.deepEqual(both, { 80, 20 }, "a big spend crosses two")
		local tomorrow = FogMap.airdropsCrossed(150, 130, day1, T0 + DAY, config)
		TestKit.deepEqual(tomorrow, { 140 }, "a new day")
		TestKit.deepEqual((FogMap.airdropsCrossed(130, 150, day, T0, config)), {}, "regen never triggers")
	end)

	test("#43 an airdrop pin opens the drop location, once", function()
		local drop = Content.Locations[TUNING.airdrops.locationId]
		local _, _, closed = Travel.start(drop, "run", travelCtx(100))
		TestKit.equal(closed, "unavailable", "no pin, no drop")
		TestKit.truthy(Travel.start(drop, "run", travelCtx(100, { airdropPin = true })), "with a pin")
		local pins = { FogMap.pin(140, T0, TUNING.airdrops) }
		TestKit.equal(#FogMap.livePins(pins, T0 + TUNING.airdrops.pinSeconds - 1), 1)
		TestKit.equal(#FogMap.livePins(pins, T0 + TUNING.airdrops.pinSeconds), 0, "pins expire")
		TestKit.deepEqual(FogMap.usePin(pins, T0 + 5), {})
		TestKit.equal(FogMap.usePin({}, T0), nil)
	end)

	test("#43 Dense and Black wait on their signal tower: FILL UP, then FINALIZE", function()
		local gates = TUNING.regionGates
		local ctx = travelCtx(100, { gates = gates, repairedGates = {} })
		local _, _, reason = Travel.start(QUARRY, "walk", ctx)
		TestKit.equal(reason, "gate")
		TestKit.truthy(Travel.start(Content.Locations["loc.pine_hollow"], "walk", ctx), "Light fog is open")
		local tower = Travel.gateFor(2, gates) :: any
		local inventory = Inventory.new(6, 0)
		inventory.pockets[1] = { itemId = "item.plank", count = 30 }
		inventory.pockets[2] = { itemId = "item.rope", count = 4 }
		local after, contributed, taken = FogMap.fillUp(tower, {}, inventory)
		TestKit.equal(Inventory.count(after, "item.plank"), 10, "only what's missing")
		TestKit.equal(#taken, 2)
		local rows, complete = FogMap.checklist(tower, contributed)
		TestKit.equal(complete, false)
		TestKit.truthy(#rows == #tower.parts, "a row per part")
		TestKit.equal(FogMap.finalize(tower, contributed, {}), nil, "not until it's complete")
		local full: { [string]: number } = {}
		for _, part in tower.parts do
			full[part.itemId] = part.count
		end
		local repaired = FogMap.finalize(tower, full, {}) :: any
		TestKit.equal(repaired[tower.id], true)
		TestKit.truthy(Travel.start(QUARRY, "walk", travelCtx(100, { gates = gates, repairedGates = repaired })))
	end)

	test("#43 Hurry finishes a Walk for Energy by the minute left", function()
		local trip = Travel.start(QUARRY, "walk", travelCtx(100)) :: Travel.Trip
		local perMinute = TUNING.travelBonus.hurryEnergyPerMinute
		TestKit.equal(Travel.hurryCost(trip, T0, perMinute), 19 * perMinute)
		TestKit.equal(Travel.hurryCost(trip, T0 + 18 * 60 + 1, perMinute), perMinute, "a started minute counts")
		local hurried, energy = Travel.hurry(trip, travelCtx(100, { now = T0 + 60 }), perMinute)
		TestKit.equal((hurried :: any).arrivesAt, T0 + 60, "there now")
		TestKit.equal((energy :: any).value, 100 - 18 * perMinute)
		local _, _, broke = Travel.hurry(trip, travelCtx(1), perMinute)
		TestKit.equal(broke, "energy")
	end)

	-- #44 sneak ------------------------------------------------------------------------------------
	test("#44 sneaking: a 3x backstab on the unaware, quieter steps, harder to spot", function()
		local sneak = TUNING.sneak
		TestKit.equal(Combat.backstab(true, false, sneak), 3)
		TestKit.equal(Combat.backstab(true, true, sneak), 1, "not once it has seen you")
		TestKit.equal(Combat.backstab(false, false, sneak), 1)
		near(Noise.sneaky("melee", 10, sneak), 10 * sneak.noiseMultiplier, "quiet swings")
		TestKit.equal(Noise.sneaky("gunshot", 90, sneak), 90, "a gun is still a gun")
		local event = Noise.new(1, "sprint", { x = 0, z = 0 }, T0, TUNING.noise, nil, nil, sneak)
		near(event.radius, TUNING.noise.sprint * sneak.noiseMultiplier, "footsteps")
		local shambler = HollowAI.archetype(Content.Enemies["enemy.shambler"], TUNING.hollow, sneak)
		local at = shambler.sightRadius * 0.75
		local seen = HollowAI.step(
			shambler,
			HollowAI.new(T0),
			aiInputs(T0, { { id = "u", position = { x = at, z = 0 }, visible = true } }, { hp = 40 })
		)
		TestKit.equal(seen.name, "chase")
		local unseen = HollowAI.step(
			shambler,
			HollowAI.new(T0),
			aiInputs(T0, { { id = "u", position = { x = at, z = 0 }, visible = true, sneaking = true } }, { hp = 40 })
		)
		TestKit.equal(unseen.name, "wander", "a sneak at 3/4 sight range goes unseen")
		TestKit.equal(HollowAI.isAware(unseen), false)
		TestKit.equal(HollowAI.isAware(seen), true)
	end)

	-- #45 weapon break and location quests -----------------------------------------------------------
	test("#45 a broken weapon switches to the other slot, else fists", function()
		local hands = Hands.new({ "item.machete", "item.pipe_pistol" }, ITEMS, TUNING.hands)
		local switched, slot = Hands.onBreak(hands, T0, ITEMS, TUNING.hands)
		TestKit.equal(slot, 2)
		TestKit.equal(switched.active, 2)
		TestKit.equal(switched.hands[1].itemId, "", "the broken one is gone")
		local alone = Hands.new({ "item.machete" }, ITEMS, TUNING.hands)
		local fists, none = Hands.onBreak(alone, T0, ITEMS, TUNING.hands)
		TestKit.equal(none, nil)
		TestKit.equal(Hands.weapon(fists, ITEMS), nil, "bare fists")
	end)

	test("#45 every fog location has a location quest", function()
		for id, location in Content.Locations do
			if location.availability.kind ~= "airdrop" then
				TestKit.truthy(#location.run.quests >= 1, id)
			end
		end
	end)

	-- #46 death recovery --------------------------------------------------------------------------------
	test("#46 a carried Reanimator is used up instead of dying", function()
		local inventory = Inventory.new(2, 0)
		TestKit.equal(DeathRecovery.useReanimator(inventory, ITEMS), nil, "none carried")
		inventory.pockets[2] = { itemId = "item.reanimator", count = 2 }
		local after = DeathRecovery.useReanimator(inventory, ITEMS) :: any
		TestKit.equal(Inventory.count(after, "item.reanimator"), 1)
	end)

	test("#46 Recover all: owner only, once a day by ad, unlimited by premium", function()
		local config = TUNING.deathRecovery
		local daily = { day = 0, used = 0 }
		TestKit.equal(DeathRecovery.canRecoverAll(daily, "ad", T0, config), true)
		daily = DeathRecovery.useRecoverAll(daily, T0)
		TestKit.equal(DeathRecovery.canRecoverAll(daily, "ad", T0 + 60, config), false, "once a day")
		TestKit.equal(DeathRecovery.canRecoverAll(daily, "premium", T0 + 60, config), true)
		TestKit.equal(DeathRecovery.canRecoverAll(daily, "ad", T0 + DAY, config), true, "tomorrow")

		local lobby =
			Lobby.new({ id = "L", locationId = "loc.sunken_quarry", fogTier = 2, seed = 1, powerBand = 1, now = T0 })
		assert(Lobby.reserve(lobby, T0, TUNING.lobby, { 1, 2 }, nil, 1))
		assert(Lobby.arrive(lobby, 1, T0, TUNING.lobby))
		local inventory = Inventory.new(2, 0)
		inventory.pockets[1] = { itemId = "item.scrap", count = 9 }
		local drop = Lobby.die(lobby, 1, T0 + 5, TUNING.lobby, TUNING.death :: any, {
			inventory = inventory,
			equipment = {},
			cause = "hollow",
		}).drop :: Lobby.DeathDrop
		local _, denied = Lobby.recoverAll(lobby, drop.id, 2, T0 + 6, TUNING.lobby)
		TestKit.equal(denied, "denied")
		local slots = Lobby.recoverAll(lobby, drop.id, 1, T0 + 6, TUNING.lobby) :: { any }
		TestKit.equal(slots[1].count, 9)
		TestKit.equal(lobby.drops[drop.id], nil, "the drop is gone from the world")
	end)

	test("#46 death-milestone gifts", function()
		local config = TUNING.deathRecovery
		TestKit.equal(#DeathRecovery.milestoneGifts(0, 1, config), 1, "the first death")
		TestKit.equal(#DeathRecovery.milestoneGifts(1, 4, config), 0)
		TestKit.equal(DeathRecovery.milestoneGifts(4, 5, config)[1].itemId, "item.rations")
		TestKit.equal(#DeathRecovery.milestoneGifts(0, 99, config), 3, "all of them at once")
	end)
end
