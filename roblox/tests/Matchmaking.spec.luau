--!strict
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Inventory = require("../src/shared/Domain/Inventory")
local Matchmaking = require("../src/shared/Domain/Matchmaking")

local T0 = 1_700_000_000
local CONFIG = Content.Tuning.matchmaking
local CAPACITY = Content.Tuning.lobby.capacity
local ITEMS: Matchmaking.ItemLookup = Content.Items :: any
local QUARRY = "loc.sunken_quarry"

local function solo(id: string, power: number, at: number?): Matchmaking.Entry
	return Matchmaking.entry(id, QUARRY, { tonumber(string.sub(id, 2)) or 1 }, { power }, nil, at or T0, CONFIG)
end

local function lobby(id: string, band: number, free: number, joinable: boolean?): Matchmaking.OpenLobby
	return {
		id = id,
		locationId = QUARRY,
		powerBand = band,
		freeSeats = free,
		joinable = if joinable == nil then true else joinable,
	}
end

return function(test: TestKit.Register)
	test("gear score: best weapon, one armor piece per slot, the bag", function()
		local score = Matchmaking.gearScore({
			weaponIds = { "item.spiked_club", "item.pipe_pistol" },
			armorIds = { "item.padded_hood", "item.padded_vest" },
			bagId = "item.pack_frame",
		}, ITEMS, CONFIG)
		local w = CONFIG.weights
		TestKit.equal(score, 2 * w.weapon + (1 + 2) * w.armor + 2 * w.bag)
		local naked = Matchmaking.gearScore({ weaponIds = {}, armorIds = {} }, ITEMS, CONFIG)
		TestKit.equal(naked, 0)
	end)

	test("gear score ignores non-weapons and stacks a companion hook (weight 0 in M1)", function()
		local score = Matchmaking.gearScore({
			weaponIds = { "item.timber" },
			armorIds = { "item.padded_hood", "item.padded_hood" },
			companionScore = 50,
		}, ITEMS, CONFIG)
		TestKit.equal(score, CONFIG.weights.armor, "one hood counts once, timber is no weapon")
		local hooked = Matchmaking.gearScore(
			{ weaponIds = {}, armorIds = {}, companionScore = 50 },
			ITEMS,
			{ weights = { weapon = 0, armor = 0, bag = 0, companion = 2 } } :: any
		)
		TestKit.equal(hooked, 100, "the M3 hook adds the companion's score")
	end)

	test("the loadout is read from what is carried and worn", function()
		local inventory = Inventory.new(2, 1)
		inventory.pockets[1] = { itemId = "item.machete", count = 1, durability = 10 }
		inventory.backpack[1] = { itemId = "item.scrap", count = 4 }
		local equipment = {
			weapon = { itemId = "item.shortbow", count = 1 },
			head = { itemId = "item.padded_hood", count = 1 },
			body = Inventory.emptySlot(),
			legs = Inventory.emptySlot(),
			feet = Inventory.emptySlot(),
			bag = { itemId = "item.satchel", count = 1 },
		}
		local loadout = Matchmaking.loadoutOf(inventory, equipment, ITEMS)
		TestKit.deepEqual(loadout.weaponIds, { "item.machete", "item.shortbow" })
		TestKit.deepEqual(loadout.armorIds, { "item.padded_hood" })
		TestKit.equal(loadout.bagId, "item.satchel")
	end)

	test("power bands: level and gear together, bandWidth wide", function()
		local power = Matchmaking.power(8, 92, CONFIG)
		TestKit.equal(power, 8 * CONFIG.levelWeight + 92)
		TestKit.equal(Matchmaking.band(0, CONFIG), 1)
		TestKit.equal(Matchmaking.band(CONFIG.bandWidth - 1, CONFIG), 1)
		TestKit.equal(Matchmaking.band(CONFIG.bandWidth, CONFIG), 2)
	end)

	test("a party is matched at its strongest member", function()
		local entry = Matchmaking.entry("p1", QUARRY, { 1, 2, 3 }, { 40, 300, 90 }, "party1", T0, CONFIG)
		TestKit.equal(entry.power, 300)
		TestKit.equal(entry.band, Matchmaking.band(300, CONFIG))
		TestKit.throws(function()
			Matchmaking.entry("p2", QUARRY, { 1, 2 }, { 40 }, nil, T0, CONFIG)
		end, "one power per member")
	end)

	test("the band tolerance widens the longer you wait", function()
		TestKit.equal(Matchmaking.tolerance(0, CONFIG), 0)
		TestKit.equal(Matchmaking.tolerance(CONFIG.widenEverySeconds, CONFIG), 1)
		TestKit.equal(Matchmaking.tolerance(999, CONFIG), CONFIG.maxTolerance, "capped")
		local entry = solo("u1", 130) -- band 3
		local farLobby = lobby("L9", 5, 6)
		TestKit.equal(Matchmaking.pickLobby(entry, { farLobby }, T0, CONFIG), nil, "too far at first")
		local waited = T0 + 2 * CONFIG.widenEverySeconds
		TestKit.equal(Matchmaking.pickLobby(entry, { farLobby }, waited, CONFIG), farLobby, "two bands after waiting")
	end)

	test("pickLobby prefers the fullest fitting lobby, then the nearest band", function()
		local entry = solo("u1", 130, T0 - 10) -- band 3, tolerance 2
		local roomy = lobby("A", 3, 10)
		local nearlyFull = lobby("B", 4, 2)
		local closedLobby = lobby("C", 3, 1, false)
		local otherPlace = { id = "D", locationId = "loc.pine_hollow", powerBand = 3, freeSeats = 1, joinable = true }
		local picked = Matchmaking.pickLobby(entry, { roomy, nearlyFull, closedLobby, otherPlace }, T0, CONFIG)
		TestKit.equal((picked :: any).id, "B", "fills lobbies up")
		local party = Matchmaking.entry("p1", QUARRY, { 1, 2, 3 }, { 130, 130, 130 }, "party", T0 - 10, CONFIG)
		TestKit.equal(
			(Matchmaking.pickLobby(party, { roomy, nearlyFull }, T0, CONFIG) :: any).id,
			"A",
			"parties fit whole"
		)
	end)

	test("tick joins open lobbies, keeps parties together and never overfills", function()
		local queue = {
			Matchmaking.entry("p1", QUARRY, { 1, 2, 3 }, { 130, 130, 130 }, "party", T0, CONFIG),
			solo("u4", 140, T0 + 1),
			solo("u5", 150, T0 + 2),
		}
		local plan = Matchmaking.tick(queue, { lobby("L1", 3, 4) }, T0 + 3, CONFIG, CAPACITY)
		TestKit.equal(#plan.joins, 2, "the party and one solo fit 4 seats")
		TestKit.equal(plan.joins[1].entryId, "p1", "oldest first")
		TestKit.deepEqual(plan.waiting, { "u5" }, "the lobby is full")
		TestKit.equal(#plan.creates, 0, "u5 hasn't waited long enough for a fresh lobby")
	end)

	test("after newLobbyAfterSeconds a fresh lobby opens and others pile in", function()
		local queue = {
			solo("u1", 130, T0),
			solo("u2", 135, T0 + 1),
			solo("u3", 600, T0 + 1), -- far stronger
		}
		local plan = Matchmaking.tick(queue, {}, T0 + CONFIG.newLobbyAfterSeconds, CONFIG, CAPACITY)
		TestKit.equal(#plan.creates, 1, "one fresh lobby for the first two")
		TestKit.deepEqual(plan.creates[1].entryIds, { "u1", "u2" })
		TestKit.equal(plan.creates[1].powerBand, Matchmaking.band(130, CONFIG))
		TestKit.deepEqual(plan.waiting, { "u3" }, "the veteran waits for their own band")
		local later = Matchmaking.tick({ queue[3] }, {}, T0 + 1 + CONFIG.newLobbyAfterSeconds, CONFIG, CAPACITY)
		TestKit.equal(#later.creates, 1, "and gets a lobby of their own soon after")
	end)

	test("a Run's trip counts as waiting: a lobby opens at the first tick after it", function()
		local runSeconds = Content.Tuning.travel.runSeconds
		local departed = T0
		local arrived = departed + runSeconds
		TestKit.equal(Matchmaking.waitSince(departed, arrived), departed)
		TestKit.equal(Matchmaking.waitSince(nil, arrived), arrived, "no trip: the wait starts now")
		TestKit.equal(Matchmaking.waitSince(arrived + 5, arrived), arrived, "never in the future")
		TestKit.truthy(
			CONFIG.newLobbyAfterSeconds <= runSeconds,
			"the shipped wait fits inside the Run's trip (batch 3: arrive within 5 s of the timer)"
		)
		local entry = solo("u1", 130, Matchmaking.waitSince(departed, arrived))
		local plan = Matchmaking.tick({ entry }, {}, arrived, CONFIG, CAPACITY)
		TestKit.equal(#plan.creates, 1, "no lobby to join: a fresh one at once")
	end)

	test("a fresh lobby fills to capacity and no further", function()
		local queue = {}
		for index = 1, 14 do
			table.insert(queue, solo(`u{index}`, 130, T0))
		end
		local plan = Matchmaking.tick(queue, {}, T0 + CONFIG.newLobbyAfterSeconds, CONFIG, CAPACITY)
		local seated = 0
		for _, created in plan.creates do
			TestKit.truthy(#created.entryIds <= CAPACITY, "never overfilled")
			seated += #created.entryIds
		end
		TestKit.equal(#plan.creates[1].entryIds, CAPACITY, "the first lobby is full")
		TestKit.equal(seated + #plan.waiting, 14, "everyone is accounted for")
	end)

	test("AI-raider backfill stays off until the M2 flag", function()
		local features = { fogRuns = true, aiRaiders = false }
		TestKit.equal(Matchmaking.backfill(3, features, CONFIG), 0)
		features.aiRaiders = true
		TestKit.equal(Matchmaking.backfill(3, features, CONFIG), CONFIG.aiBackfillTarget - 3)
		TestKit.equal(Matchmaking.backfill(12, features, CONFIG), 0)
	end)
end
