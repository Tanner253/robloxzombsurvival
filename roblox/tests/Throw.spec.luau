--!strict
-- Domain/Throw and the throwables (2.0 batch 5): the aim ring, the arc, a blast's falloff, a
-- fire's ticks, and the Frag Grenade and Molotov as data (how they are held, made and found).
local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Throw = require("../src/shared/Domain/Throw")
local Slots = require("../src/shared/Domain/Slots")
local HoldRules = require("../src/shared/Domain/HoldRules")
local Combat = require("../src/shared/Domain/Combat")

local Items: any = Content.Items
local FRAG = Items["item.frag_grenade"].throw
local MOLOTOV = Items["item.molotov"].throw
local ORIGIN = Throw.point(0, 2, 0)

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

local function lootRows(itemId: string): { [string]: any }
	local found: { [string]: any } = {}
	for tableId, loot in Content.LootTables do
		for _, entry in (loot :: any).entries do
			if entry.itemId == itemId then
				found[tableId] = entry
			end
		end
	end
	return found
end

return function(test: TestKit.Register)
	test("the aim lands inside the throwable's ring", function()
		local far = Throw.landing(ORIGIN, Throw.point(100, 0, 0), FRAG)
		TestKit.truthy(near(Throw.flatDistance(ORIGIN, far), FRAG.range), "a far aim stops at the range")
		TestKit.truthy(near(far.z, 0) and far.x > 0, "in the aimed direction")
		local close = Throw.landing(ORIGIN, Throw.point(0, 0, 1), FRAG)
		TestKit.truthy(near(Throw.flatDistance(ORIGIN, close), FRAG.minRange), "a close aim lands at minRange")
		local mid = Throw.landing(ORIGIN, Throw.point(12, 0, 16), FRAG)
		TestKit.truthy(near(mid.x, 12) and near(mid.z, 16), "inside the ring it lands where aimed")
		local feet = Throw.landing(ORIGIN, ORIGIN, FRAG, math.pi / 2)
		TestKit.truthy(near(feet.x, FRAG.minRange) and near(feet.z, 0, 1e-4), "at the feet: ahead at minRange")
	end)

	test("the arc leaves the hand, peaks at mid-flight and lands on the aim", function()
		local to = Throw.point(20, 0, 0)
		local flight = Throw.flightSeconds(ORIGIN, to, FRAG)
		TestKit.truthy(near(flight, 20 / FRAG.flightSpeed), "flight time from the ground speed")
		local start, mid, finish =
			Throw.at(ORIGIN, to, FRAG, flight, 0),
			Throw.at(ORIGIN, to, FRAG, flight, flight / 2),
			Throw.at(ORIGIN, to, FRAG, flight, flight)
		TestKit.truthy(near(start.x, 0) and near(start.y, 2), "starts at the hand")
		TestKit.truthy(near(mid.y, 1 + FRAG.apex), "apex over the line at mid-flight")
		TestKit.truthy(near(finish.x, 20) and near(finish.y, 0), "ends on the landing")
		local points = Throw.points(ORIGIN, to, FRAG, 8)
		TestKit.equal(#points, 9)
		TestKit.truthy(near(points[9].x, 20), "the preview's last point is the landing")
		TestKit.truthy(Throw.flightSeconds(ORIGIN, Throw.point(0.5, 0, 0), FRAG) >= 0.35, "a lob still takes time")
	end)

	test("a short throw lobs lower, so it clears what a long arc would catch", function()
		local function peak(distance: number): number
			local to = Throw.point(distance, 2, 0)
			local flight = Throw.flightSeconds(ORIGIN, to, FRAG)
			return Throw.at(ORIGIN, to, FRAG, flight, flight / 2).y - 2
		end
		TestKit.truthy(peak(12) <= 5, `a 12-stud throw peaks {peak(12)} studs over the hand`)
		TestKit.truthy(peak(6) < peak(12) and peak(12) < peak(30), "higher the farther it goes")
		TestKit.truthy(near(peak(30), FRAG.apex), "a long throw keeps the item's apex")
		-- Wherever it peaks, it lands on the aim (the arc changes, the landing doesn't).
		for _, distance in { 6, 12, 20, 36 } do
			local to = Throw.landing(ORIGIN, Throw.point(distance, 0, 0), FRAG)
			local points = Throw.points(ORIGIN, to, FRAG, 10)
			TestKit.truthy(near(points[11].x, distance) and near(points[11].y, 0), `{distance}: lands on the aim`)
		end
		TestKit.truthy(Throw.solid(0) and Throw.solid(0.5), "a visible part stops it")
		TestKit.equal(Throw.solid(1), false, "an invisible volume does not")
	end)

	test("a blast hits hardest at its centre and nothing past its radius", function()
		TestKit.equal(Throw.blastDamage(FRAG, 0), FRAG.damage)
		TestKit.truthy(near(Throw.blastDamage(FRAG, FRAG.radius), FRAG.damage * FRAG.edgeMultiplier), "edge")
		TestKit.equal(Throw.blastDamage(FRAG, FRAG.radius + 0.01), 0)
		local half = Throw.blastDamage(FRAG, FRAG.radius / 2)
		TestKit.truthy(near(half, FRAG.damage * (1 + FRAG.edgeMultiplier) / 2), "linear between")
		-- The fuse never bursts it in the air.
		TestKit.equal(Throw.detonatesAfter(FRAG, 1), FRAG.fuseSeconds)
		TestKit.equal(Throw.detonatesAfter(FRAG, FRAG.fuseSeconds + 1), FRAG.fuseSeconds + 1)
	end)

	test("a molotov bursts on landing and burns its area in ticks", function()
		local fire = Throw.fire(MOLOTOV)
		TestKit.equal(fire.ticks, MOLOTOV.burnSeconds / MOLOTOV.burnTickSeconds)
		TestKit.truthy(near(fire.perTick, MOLOTOV.burnDps * MOLOTOV.burnTickSeconds), "damage a tick")
		TestKit.truthy(near(Throw.maxDamage(MOLOTOV), MOLOTOV.burnDps * MOLOTOV.burnSeconds), "the whole burn")
		TestKit.equal(Throw.detonatesAfter(MOLOTOV, 0.8), 0.8, "on landing")
	end)

	test("one throw per interval", function()
		TestKit.truthy(Throw.canThrow(FRAG, nil, 0), "the first")
		TestKit.equal(Throw.canThrow(FRAG, 10, 10 + FRAG.intervalSeconds - 0.01), false)
		TestKit.truthy(Throw.canThrow(FRAG, 10, 10 + FRAG.intervalSeconds + 1e-6))
	end)

	test("against the Hollow: a grenade drops a Black Runner at its centre, a molotov a Shambler", function()
		local scale = Content.Tuning.hollowTierScale.health[3]
		local runner = Content.Enemies["enemy.runner"].hp * scale
		local shambler = Content.Enemies["enemy.shambler"].hp * scale
		TestKit.truthy(Throw.blastDamage(FRAG, 0) >= runner, `grenade {FRAG.damage} against a Runner's {runner}`)
		TestKit.truthy(Throw.maxDamage(MOLOTOV) >= shambler, "a Shambler that stays in the fire burns")
		-- Never one hit on a survivor: the PvP cap holds a blast like any weapon (M2).
		local capped = Combat.pvpCap(FRAG.damage, Content.Tuning.player.maxHealth, Content.Tuning.combat)
		TestKit.truthy(capped <= Content.Tuning.player.maxHealth * Content.Tuning.combat.pvpMaxHitFraction + 1e-9)
	end)

	test("throwables are held as a stack in a weapon slot and thrown overhand", function()
		for _, id in { "item.frag_grenade", "item.molotov" } do
			local def = Items[id]
			TestKit.equal(def.category, "weapon", id)
			TestKit.equal(def.equipSlot, "weapon", id)
			TestKit.equal(def.durability, nil, `{id}: spent one a throw, not worn`)
			TestKit.equal(HoldRules.classOf(id, def), "throw", id)
			TestKit.equal(HoldRules.mountOf(id, def), "fist", id)
		end
		-- A stack of grenades goes into a weapon slot; a stack of anything else doesn't.
		local equipment = Slots.fromEquipment({
			head = { itemId = "", count = 0 },
			body = { itemId = "", count = 0 },
			legs = { itemId = "", count = 0 },
			feet = { itemId = "", count = 0 },
			weapon = { itemId = "", count = 0 },
			weapon2 = { itemId = "", count = 0 },
			bag = { itemId = "", count = 0 },
			quick = { itemId = "", count = 0 },
		})
		local pockets = { { itemId = "item.frag_grenade", count = 4 }, { itemId = "item.rivets", count = 4 } }
		local from = { slots = pockets }
		local to = { slots = equipment, accepts = Slots.equipmentAccepts() }
		local weaponIndex = table.find(Slots.EQUIP_ORDER, "weapon") :: number
		local _, moved = Slots.move(from, 1, to, weaponIndex, nil, Items)
		TestKit.truthy(moved and moved[weaponIndex].count == 4, "four grenades in the hand")
		local _, refused, reason = Slots.move(from, 2, to, weaponIndex, nil, Items)
		TestKit.equal(refused, nil)
		TestKit.equal(reason, "wrongSlot")
	end)

	test("both are made by hand on the trail and found in the fog", function()
		local recipes = { ["recipe.frag_grenade"] = "item.frag_grenade", ["recipe.molotov"] = "item.molotov" }
		for recipeId, itemId in recipes do
			local recipe = Content.Recipes[recipeId] :: any
			TestKit.truthy(recipe, recipeId)
			TestKit.equal(recipe.outputs[1].itemId, itemId)
			TestKit.equal(recipe.stationId, nil, `{recipeId} is made by hand`)
			TestKit.equal(recipe.unlock.kind, "quest", recipeId)
			TestKit.truthy(next(lootRows(itemId)) ~= nil, `{itemId} drops somewhere`)
		end
		-- The molotov gives the junk lantern a use.
		local lantern = false
		for _, input in (Content.Recipes["recipe.molotov"] :: any).inputs do
			lantern = lantern or input.itemId == "item.broken_lantern"
		end
		TestKit.truthy(lantern, "a Broken Lantern goes into a molotov")
	end)

	test("the server decides every throw, and the client draws the same arc", function()
		local server = fs.readFile("src/server/Services/Throwables.luau")
		TestKit.truthy(string.find(server, 'Net.onEvent("CombatThrow"', 1, true) ~= nil, "the remote")
		TestKit.truthy(string.find(server, "Throw.landing(", 1, true) ~= nil, "the server clamps the aim")
		TestKit.truthy(string.find(server, "Throw.blastDamage(", 1, true) ~= nil, "and deals the damage")
		TestKit.truthy(string.find(server, "Hollow.noise(", 1, true) ~= nil, "a throw draws the Hollow")
		local client = fs.readFile("src/client/Controllers/Throwing.luau")
		TestKit.truthy(string.find(client, "Throw.points(", 1, true) ~= nil, "the preview is the shared arc")
		local net = fs.readFile("src/shared/Net/FogRunRemotes.luau")
		TestKit.truthy(string.find(net, "CombatThrow", 1, true) ~= nil, "CombatThrow is a declared remote")
	end)
end
