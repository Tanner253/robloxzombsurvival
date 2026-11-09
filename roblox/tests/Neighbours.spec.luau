--!strict
--[[
	Domain/Neighbours: the Fog map's neighbour markers and the raid rules (M2; v0.1 ships
	the model only).
]]
local TestKit = require("./TestKit")
local Neighbours = require("../src/shared/Domain/Neighbours")

local RULES = Neighbours.RULES
local NOW = 1_800_000_000
local DAY = 24 * 60 * 60

local function outpost(userId: number, level: number, extra: { [string]: any }?): Neighbours.Neighbour
	local neighbour: any = {
		userId = userId,
		name = `Survivor{userId}`,
		hearthLevel = level,
		defense = level * 100,
		stockValue = 500,
		online = false,
		createdAt = NOW - 10 * DAY,
	}
	for key, value in extra or {} do
		neighbour[key] = value
	end
	return neighbour
end

return function(test: TestKit.Register)
	test("status: a live shield wins, then online or offline", function()
		local status, left = Neighbours.status(outpost(1, 5, { shieldUntil = NOW + 600, online = true }), NOW)
		TestKit.equal(status, "shielded")
		TestKit.equal(left, 600)
		TestKit.equal((Neighbours.status(outpost(1, 5, { shieldUntil = NOW - 1, online = true }), NOW)), "online")
		TestKit.equal((Neighbours.status(outpost(1, 5), NOW)), "offline")
	end)

	test("loot tier from the stockpile ('smoke from the chimneys')", function()
		TestKit.equal(Neighbours.lootTier(0, RULES), "low")
		TestKit.equal(Neighbours.lootTier(RULES.lootTiers.medium, RULES), "medium")
		TestKit.equal(Neighbours.lootTier(RULES.lootTiers.high + 1, RULES), "high")
	end)

	test("raids: own outpost, new players, shields and the power band refuse", function()
		local me = { userId = 7, hearthLevel = 6 }
		TestKit.deepEqual({ Neighbours.canRaid(me, outpost(7, 6), NOW, RULES) }, { false, "self" })
		TestKit.deepEqual({ Neighbours.canRaid(me, outpost(8, 2), NOW, RULES) }, { false, "protected" })
		local fresh = outpost(8, 6, { createdAt = NOW - 2 * DAY })
		TestKit.deepEqual({ Neighbours.canRaid(me, fresh, NOW, RULES) }, { false, "protected" })
		local shielded = outpost(8, 6, { shieldUntil = NOW + 3600 })
		TestKit.deepEqual({ Neighbours.canRaid(me, shielded, NOW, RULES) }, { false, "shielded" })
		TestKit.deepEqual({ Neighbours.canRaid(me, outpost(8, 9), NOW, RULES) }, { false, "band" })
		TestKit.deepEqual({ Neighbours.canRaid(me, outpost(8, 8), NOW, RULES) }, { true, nil })
		TestKit.deepEqual({ Neighbours.canRaid(me, outpost(8, 4), NOW, RULES) }, { true, nil })
	end)

	test("a raid takes at most the raid share of raidable storage", function()
		TestKit.equal(Neighbours.raidCap(1000, RULES), 400)
		TestKit.equal(Neighbours.raidCap(-5, RULES), 0)
	end)

	test("shown: others only, in band first, nearest level, capped", function()
		local me = { userId = 1, hearthLevel = 5 }
		local list = { outpost(1, 5), outpost(2, 12), outpost(3, 6), outpost(4, 4), outpost(5, 9), outpost(6, 5) }
		local shown = Neighbours.shown(list, me, RULES, 4)
		local ids = {}
		for _, neighbour in shown do
			table.insert(ids, neighbour.userId)
		end
		TestKit.deepEqual(ids, { 6, 3, 4, 5 }, "level 5, then 6 and 4, then the nearest out of band")
	end)

	test("slots: stable per player, never shared, within the count", function()
		local shown = { outpost(101, 5), outpost(2_000_000_123, 5), outpost(9_876_543_210, 5), outpost(77, 5) }
		local first = Neighbours.slots(shown, 6)
		TestKit.deepEqual(Neighbours.slots(shown, 6), first, "the same slots every time")
		local seen: { [number]: boolean } = {}
		for _, slot in first do
			TestKit.truthy(slot >= 1 and slot <= 6, `slot {slot} in range`)
			TestKit.truthy(not seen[slot], `slot {slot} used once`)
			seen[slot] = true
		end
		TestKit.equal(#Neighbours.slots(shown, 2), 2, "only as many as there are slots")
	end)
end
