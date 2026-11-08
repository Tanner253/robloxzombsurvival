--!strict
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Inventory = require("../src/shared/Domain/Inventory")
local Lobby = require("../src/shared/Domain/Lobby")
local TableUtil = require("../src/shared/Util/Table")

local T0 = 1_700_000_000
local CONFIG: Lobby.Config = Content.Tuning.lobby
local DEATH = Content.Tuning.death

local function newLobby(fogTier: number?, band: number?): Lobby.State
	return Lobby.new({
		id = "L1",
		locationId = "loc.sunken_quarry",
		fogTier = fogTier or 2,
		seed = 42,
		powerBand = band or 3,
		now = T0,
	})
end

-- A lobby whose first player arrived at T0.
local function started(fogTier: number?, users: { number }?, partyId: string?): Lobby.State
	local lobby = newLobby(fogTier)
	local ids = users or { 1 }
	assert(Lobby.reserve(lobby, T0, CONFIG, ids, partyId, 3))
	for _, userId in ids do
		assert(Lobby.arrive(lobby, userId, T0, CONFIG))
	end
	return lobby
end

local function carried(): Inventory.Inventory
	local inventory = Inventory.new(2, 2)
	inventory.pockets[1] = { itemId = "item.light_rounds", count = 12 }
	inventory.backpack[1] = { itemId = "item.scrap", count = 20 }
	return inventory
end

local function equipment(): { [string]: any }
	return {
		weapon = { itemId = "item.pipe_pistol", count = 1, durability = 90 },
		head = { itemId = "item.padded_hood", count = 1, durability = 100 },
		body = Inventory.emptySlot(),
		legs = Inventory.emptySlot(),
		feet = Inventory.emptySlot(),
		bag = { itemId = "item.satchel", count = 1 },
	}
end

local function death(): Lobby.DeathInfo
	return { inventory = carried(), equipment = equipment(), position = { x = 10, z = 4 }, cause = "hollow" }
end

return function(test: TestKit.Register)
	test("lifecycle: open, joinable for 3 min, running, a 60 s warning, closed at about 15 min", function()
		local lobby = newLobby()
		TestKit.equal(Lobby.phase(lobby, T0 + 30, CONFIG), "open", "waiting for the first arrival")
		assert(Lobby.reserve(lobby, T0, CONFIG, { 1 }, nil, 3))
		assert(Lobby.arrive(lobby, 1, T0 + 10, CONFIG))
		local start = T0 + 10
		TestKit.equal(Lobby.phase(lobby, start + 179, CONFIG), "joinable")
		TestKit.equal(Lobby.phase(lobby, start + 180, CONFIG), "running")
		TestKit.equal(Lobby.phase(lobby, start + 15 * 60 - 61, CONFIG), "running")
		TestKit.equal(Lobby.phase(lobby, start + 15 * 60 - 60, CONFIG), "warning")
		TestKit.equal(Lobby.phase(lobby, start + 15 * 60, CONFIG), "closed")
		TestKit.equal(Lobby.closesAt(lobby, CONFIG), start + 15 * 60)
	end)

	test("a reserved lobby nobody reaches closes after the open timeout", function()
		local lobby = newLobby()
		TestKit.equal(Lobby.phase(lobby, T0 + CONFIG.openTimeoutSeconds - 1, CONFIG), "open")
		TestKit.equal(Lobby.phase(lobby, T0 + CONFIG.openTimeoutSeconds, CONFIG), "closed")
		local result = Lobby.tick(lobby, T0 + CONFIG.openTimeoutSeconds, CONFIG)
		TestKit.equal(result.closed, true)
		TestKit.equal(lobby.closeReason, "unused")
	end)

	test("the Fog meter rises from 0 to 1 and picks loot and Hollow bands", function()
		local lobby = started()
		TestKit.equal(Lobby.meter(lobby, T0, CONFIG), 0)
		TestKit.equal(Lobby.meter(lobby, T0 + 15 * 60, CONFIG), 1)
		TestKit.equal(Lobby.meter(lobby, T0 + 99_999, CONFIG), 1, "clamped")
		local half = Lobby.meter(lobby, T0 + 450, CONFIG)
		TestKit.truthy(half < 0.5, `exponent above 1 keeps the first half quiet ({half})`)
		local index, band = Lobby.band(lobby, T0, CONFIG)
		TestKit.equal(index, 1)
		TestKit.equal(band.lootMultiplier, 1)
		local lateIndex, late = Lobby.band(lobby, T0 + 15 * 60 - 1, CONFIG)
		TestKit.equal(lateIndex, #CONFIG.bands, "the last band before close")
		TestKit.truthy(late.hollowStrength > 1 and late.lootMultiplier > 1, "late is richer and harder")
	end)

	test("secondsUntilBand inverts the meter curve", function()
		local lobby = started()
		for band = 2, #CONFIG.bands do
			local wait = Lobby.secondsUntilBand(lobby, T0, CONFIG, band)
			local reached = Lobby.band(lobby, T0 + wait + 0.01, CONFIG)
			local before = Lobby.band(lobby, T0 + wait - 0.5, CONFIG)
			TestKit.equal(reached, band, `band {band} reached`)
			TestKit.equal(before, band - 1, `band {band} not before`)
		end
		TestKit.equal(Lobby.secondsUntilBand(lobby, T0 + 99_999, CONFIG, 2), 0)
		TestKit.equal(Lobby.secondsUntilBand(newLobby(), T0, CONFIG, 2), math.huge, "not started")
	end)

	test("join checks: power band, the join window, capacity, closed", function()
		local lobby = started()
		TestKit.truthy(Lobby.canJoin(lobby, T0 + 10, CONFIG, { seats = 1, powerBand = 4 }), "one band away is fine")
		local _, far = Lobby.canJoin(lobby, T0 + 10, CONFIG, { seats = 1, powerBand = 5 })
		TestKit.equal(far, "powerBand", "a veteran can't drop into newcomers")
		local _, late = Lobby.canJoin(lobby, T0 + 181, CONFIG, { seats = 1, powerBand = 3 })
		TestKit.equal(late, "notJoinable", "joining closes after 3 min")
		local _, full = Lobby.canJoin(lobby, T0 + 10, CONFIG, { seats = 12, powerBand = 3 })
		TestKit.equal(full, "full", "11 free seats can't take a party of 12")
		local _, closed = Lobby.canJoin(lobby, T0 + 15 * 60, CONFIG, { seats = 1, powerBand = 3 })
		TestKit.equal(closed, "closed")
	end)

	test("capacity is 12 and a party joins whole or not at all", function()
		local lobby = newLobby()
		local eleven = {}
		for userId = 1, 11 do
			table.insert(eleven, userId)
		end
		TestKit.truthy(Lobby.reserve(lobby, T0, CONFIG, eleven, nil, 3), "eleven seats")
		local ok, reason = Lobby.reserve(lobby, T0, CONFIG, { 20, 21 }, "p9", 3)
		TestKit.equal(ok, false)
		TestKit.equal(reason, "full")
		TestKit.equal(lobby.members[20], nil, "nobody from the party got a seat")
		TestKit.truthy(Lobby.reserve(lobby, T0, CONFIG, { 30 }, nil, 3), "the twelfth seat")
		TestKit.equal(Lobby.freeSeats(lobby, T0, CONFIG), 0)
	end)

	test("reservations: arrival in time starts the meter; stale ones expire and free the seat", function()
		local lobby = newLobby()
		assert(Lobby.reserve(lobby, T0, CONFIG, { 1, 2 }, "p1", 3))
		TestKit.truthy(Lobby.arrive(lobby, 1, T0 + 5, CONFIG), "in time")
		TestKit.equal(lobby.startedAt, T0 + 5, "the first arrival starts the clock")
		local ok, reason = Lobby.arrive(lobby, 2, T0 + CONFIG.reservationSeconds, CONFIG)
		TestKit.equal(ok, false)
		TestKit.equal(reason, "expired")
		local result = Lobby.tick(lobby, T0 + CONFIG.reservationSeconds, CONFIG)
		TestKit.deepEqual(result.expired, { 2 })
		TestKit.equal(lobby.members[2].state, "left")
		TestKit.equal(Lobby.seatsTaken(lobby, T0 + CONFIG.reservationSeconds, CONFIG), 1)
		local _, notReserved = Lobby.arrive(lobby, 99, T0 + 6, CONFIG)
		TestKit.equal(notReserved, "notReserved")
	end)

	test("Light fog: the backpack drops, gear stays, and only the owner and party open it", function()
		local lobby = started(1, { 1, 2, 3 }, "pA")
		lobby.members[3].partyId = nil -- a stranger in the same lobby
		local result = Lobby.die(lobby, 1, T0 + 100, CONFIG, DEATH, death())
		local drop = result.drop :: Lobby.DeathDrop
		TestKit.truthy(drop, "a drop")
		TestKit.equal(#drop.backpack, 2, "pockets and backpack drop (keepPockets is false)")
		TestKit.equal(#drop.equipment, 0, "equipped gear is kept")
		TestKit.equal(result.equipment.weapon.itemId, "item.pipe_pistol")
		TestKit.equal(Inventory.count(result.inventory, "item.scrap"), 0, "the carried items left the player")
		TestKit.equal(lobby.members[1].state, "dead")
		TestKit.truthy(Lobby.canAccessDrop(lobby, drop.id, 1, nil, T0 + 101, CONFIG), "owner")
		TestKit.truthy(Lobby.canAccessDrop(lobby, drop.id, 2, "pA", T0 + 101, CONFIG), "party")
		local ok, reason = Lobby.canAccessDrop(lobby, drop.id, 3, nil, T0 + 101, CONFIG)
		TestKit.equal(ok, false)
		TestKit.equal(reason, "denied", "a stranger can't loot it in Light fog")
	end)

	test("Dense fog: anyone can take the backpack; gear is still kept", function()
		local lobby = started(2, { 1, 5 })
		local result = Lobby.die(lobby, 1, T0 + 100, CONFIG, DEATH, death())
		local drop = result.drop :: Lobby.DeathDrop
		TestKit.equal(#drop.equipment, 0, "equipment kept in Dense")
		local slot = Lobby.takeFromDrop(lobby, drop.id, 5, nil, "backpack", 1, nil, T0 + 120, CONFIG)
		TestKit.truthy(slot, "a stranger takes from it")
	end)

	test("Black fog: everything carried drops, equipped gear included", function()
		local lobby = started(3, { 1, 5 })
		local result = Lobby.die(lobby, 1, T0 + 100, CONFIG, DEATH, death())
		local drop = result.drop :: Lobby.DeathDrop
		TestKit.equal(#drop.equipment, 3, "weapon, hood and bag")
		TestKit.equal(result.equipment.weapon.count, 0, "nothing stays equipped")
		TestKit.equal(drop.equipment[1].durability, 90, "durability travels with the item")
		local slot = Lobby.takeFromDrop(lobby, drop.id, 5, nil, "equipment", 1, nil, T0 + 120, CONFIG)
		TestKit.equal((slot :: any).itemId, "item.pipe_pistol", "anyone takes the gun")
	end)

	test("taking from a drop: partial counts, then the empty drop disappears", function()
		local lobby = started(2, { 1, 5 })
		local drop = Lobby.die(lobby, 1, T0 + 10, CONFIG, DEATH, death()).drop :: Lobby.DeathDrop
		local part = Lobby.takeFromDrop(lobby, drop.id, 5, nil, "backpack", 1, 5, T0 + 11, CONFIG) :: any
		TestKit.equal(part.count, 5)
		TestKit.equal(drop.backpack[1].count, 7, "the rest stays")
		local _, bad = Lobby.takeFromDrop(lobby, drop.id, 5, nil, "backpack", 9, nil, T0 + 11, CONFIG)
		TestKit.equal(bad, "badSlot")
		Lobby.takeFromDrop(lobby, drop.id, 5, nil, "backpack", 1, nil, T0 + 12, CONFIG)
		Lobby.takeFromDrop(lobby, drop.id, 5, nil, "backpack", 1, nil, T0 + 12, CONFIG)
		TestKit.equal(lobby.drops[drop.id], nil, "emptied")
		Lobby.returnToDrop(lobby, drop.id, "backpack", { itemId = "item.scrap", count = 3 }, T0 + 13, 1)
		TestKit.equal(lobby.drops[drop.id].backpack[1].count, 3, "what didn't fit goes back")
	end)

	test("nothing carried means no drop", function()
		local lobby = started(1)
		local info = death()
		info.inventory = Inventory.new(2, 2)
		local result = Lobby.die(lobby, 1, T0 + 5, CONFIG, DEATH, info)
		TestKit.equal(result.drop, nil)
		TestKit.equal(next(lobby.drops), nil)
	end)

	test("drops last until the lobby closes, however the player died", function()
		local lobby = started(2, { 1, 2 })
		local drop = Lobby.die(lobby, 1, T0 + 10, CONFIG, DEATH, death()).drop :: Lobby.DeathDrop
		TestKit.equal(#Lobby.drops(lobby, T0 + 15 * 60 - 1, CONFIG), 1, "still there a second before the end")
		TestKit.equal(#Lobby.drops(lobby, T0 + 15 * 60, CONFIG), 0, "gone when the Fog closes in")
		local _, reason = Lobby.canAccessDrop(lobby, drop.id, 1, nil, T0 + 15 * 60, CONFIG)
		TestKit.equal(reason, "gone")
	end)

	test("re-entry: only the dead, only while open and before the warning", function()
		local lobby = started(1, { 1, 2 })
		local _, alive = Lobby.canReenter(lobby, 2, T0 + 60, CONFIG)
		TestKit.equal(alive, "notDead")
		Lobby.die(lobby, 1, T0 + 60, CONFIG, DEATH, death())
		TestKit.truthy(Lobby.canReenter(lobby, 1, T0 + 300, CONFIG), "running is fine (past the join window)")
		local _, late = Lobby.canReenter(lobby, 1, T0 + 15 * 60 - 60, CONFIG)
		TestKit.equal(late, "tooLate", "not once the warning sounds")
		local _, stranger = Lobby.canReenter(lobby, 77, T0 + 300, CONFIG)
		TestKit.equal(stranger, "notMember")
		TestKit.truthy(Lobby.reenter(lobby, 1, T0 + 300, CONFIG), "seat re-reserved")
		TestKit.truthy(Lobby.arrive(lobby, 1, T0 + 303, CONFIG), "back inside")
		TestKit.equal(lobby.members[1].entries, 2)
	end)

	test("a dead player's seat is held so a full lobby can't lock them out of their bag", function()
		local lobby = newLobby()
		local twelve = {}
		for userId = 1, 12 do
			table.insert(twelve, userId)
		end
		assert(Lobby.reserve(lobby, T0, CONFIG, twelve, nil, 3))
		for _, userId in twelve do
			assert(Lobby.arrive(lobby, userId, T0, CONFIG))
		end
		Lobby.die(lobby, 4, T0 + 20, CONFIG, DEATH, death())
		local _, reason = Lobby.canJoin(lobby, T0 + 30, CONFIG, { seats = 1, powerBand = 3 })
		TestKit.equal(reason, "full", "the dead player's seat is not up for grabs")
		TestKit.truthy(Lobby.reenter(lobby, 4, T0 + 40, CONFIG))
	end)

	test("a re-entry that never arrives leaves the player dead, bag still there", function()
		local lobby = started(1, { 1, 2 })
		Lobby.die(lobby, 1, T0 + 10, CONFIG, DEATH, death())
		assert(Lobby.reenter(lobby, 1, T0 + 20, CONFIG))
		local result = Lobby.tick(lobby, T0 + 20 + CONFIG.reservationSeconds, CONFIG)
		TestKit.deepEqual(result.expired, { 1 })
		TestKit.equal(lobby.members[1].state, "dead")
		TestKit.equal(#Lobby.drops(lobby, T0 + 100, CONFIG), 1)
	end)

	test("closing: whoever is still inside is lost to the Fog", function()
		local lobby = started(2, { 1, 2, 3 })
		Lobby.extract(lobby, 1)
		Lobby.die(lobby, 2, T0 + 50, CONFIG, DEATH, death())
		local result = Lobby.tick(lobby, T0 + 15 * 60, CONFIG)
		TestKit.equal(result.closed, true)
		TestKit.deepEqual(result.lost, { 3 })
		TestKit.equal(lobby.members[3].state, "lost")
		TestKit.equal(lobby.members[1].state, "extracted")
		TestKit.equal(lobby.closedAt, T0 + 15 * 60)
		TestKit.equal(next(lobby.drops), nil, "drops are gone")
		TestKit.equal(Lobby.tick(lobby, T0 + 15 * 60 + 5, CONFIG).closed, false, "closes once")
	end)

	test("lost to the Fog follows the tier's drop rule but leaves nothing behind", function()
		local lobby = started(3, { 1 })
		local result = Lobby.loseToFog(lobby, 1, T0 + 900, CONFIG, DEATH, death())
		TestKit.equal(result.drop, nil)
		TestKit.equal(result.equipment.weapon.count, 0, "Black fog takes the equipped gun too")
		TestKit.equal(Inventory.count(result.inventory, "item.light_rounds"), 0)
		TestKit.equal(next(lobby.drops), nil)
		TestKit.equal(lobby.members[1].state, "lost")
	end)

	test("closing early: only once empty and no bag can still be fetched", function()
		local lobby = started(1, { 1, 2 })
		TestKit.equal(Lobby.canCloseEarly(lobby, T0 + 10, CONFIG), false, "players inside")
		Lobby.extract(lobby, 1)
		Lobby.die(lobby, 2, T0 + 20, CONFIG, DEATH, death())
		TestKit.equal(Lobby.canCloseEarly(lobby, T0 + 30, CONFIG), false, "player 2 may come back for the bag")
		TestKit.equal(Lobby.canCloseEarly(lobby, T0 + 15 * 60 - 60, CONFIG), true, "past the re-entry cutoff")
		local copy = TableUtil.deepCopy(lobby)
		Lobby.close(copy, T0 + 15 * 60 - 60, "empty")
		TestKit.equal(copy.closeReason, "empty")
	end)

	test("leaving keeps what you carry; extraction marks you out", function()
		local lobby = started(2, { 1, 2 })
		Lobby.leave(lobby, 1)
		TestKit.equal(lobby.members[1].state, "left")
		TestKit.equal(Lobby.extract(lobby, 2), true)
		TestKit.equal(Lobby.extract(lobby, 2), false, "only once")
		TestKit.deepEqual(Lobby.inside(lobby), {})
	end)
end
