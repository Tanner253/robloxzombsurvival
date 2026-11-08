--!strict
-- Specs for Domain/MaterialPool and Domain/Inbox: home builds and crafts draw from
-- pockets, backpack, crates and the inbox in that order, all or nothing (5.13, 4.15).
local TestKit = require("./TestKit")
local MaterialPool = require("../src/shared/Domain/MaterialPool")
local Inbox = require("../src/shared/Domain/Inbox")

local function slot(itemId: string, count: number): any
	return { itemId = itemId, count = count }
end

local function empty(): any
	return { itemId = "", count = 0 }
end

local function home(): { MaterialPool.Source }
	return {
		{ key = "pockets", slots = { slot("item.timber", 2), empty() } },
		{ key = "backpack", slots = { slot("item.stone", 4), slot("item.timber", 3) } },
		{ key = "crate:a", slots = { slot("item.timber", 10) } },
		{ key = "inbox", slots = { slot("item.timber", 50), slot("item.rope", 5) } },
	}
end

return function(test: TestKit.Register)
	test("counts every source", function()
		TestKit.equal(MaterialPool.count(home(), "item.timber"), 65)
		TestKit.deepEqual(
			MaterialPool.breakdown(home(), "item.timber"),
			{ pockets = 2, backpack = 3, ["crate:a"] = 10, inbox = 50 }
		)
	end)

	test("draws pockets first, then backpack, crates, inbox", function()
		local changed = MaterialPool.take(home(), { { itemId = "item.timber", count = 4 } })
		assert(changed, "taken")
		TestKit.equal(changed.pockets[1].count, 0, "pockets emptied first")
		TestKit.equal(changed.backpack[2].count, 1, "then the backpack")
		TestKit.equal(changed["crate:a"], nil, "crates untouched")
		TestKit.equal(changed.inbox, nil, "inbox untouched")
	end)

	test("a partial draw spans sources", function()
		local changed = MaterialPool.take(home(), { { itemId = "item.timber", count = 20 } })
		assert(changed, "taken")
		TestKit.equal(changed.pockets[1].count, 0)
		TestKit.equal(changed.backpack[2].count, 0)
		TestKit.equal(changed["crate:a"][1].count, 0)
		TestKit.equal(changed.inbox[1].count, 45, "the last 5 come from the inbox")
		TestKit.equal(changed.inbox[2].count, 5, "other inbox rows untouched")
	end)

	test("repeated stacks fold together", function()
		local changed =
			MaterialPool.take(home(), { { itemId = "item.stone", count = 2 }, { itemId = "item.stone", count = 2 } })
		assert(changed, "taken")
		TestKit.equal(changed.backpack[1].count, 0)
	end)

	test("a short stack changes nothing (atomic)", function()
		local sources = home()
		local changed, short = MaterialPool.take(sources, {
			{ itemId = "item.timber", count = 5 },
			{ itemId = "item.rope", count = 9 },
		})
		TestKit.equal(changed, nil, "refused")
		assert(short, "short")
		TestKit.equal(short.itemId, "item.rope")
		TestKit.equal(short.count, 4, "how many are missing")
		TestKit.equal(sources[1].slots[1].count, 2, "sources unchanged")
		TestKit.equal(sources[4].slots[1].count, 50, "inbox unchanged")
	end)

	test("inbox rows merge stackables per source and keep tools apart", function()
		local entries, seq = Inbox.add({}, 0, { slot("item.timber", 5) }, "LevelUp", 1)
		entries, seq = Inbox.add(entries, seq, { slot("item.timber", 3) }, "LevelUp", 2)
		entries, seq = Inbox.add(entries, seq, { slot("item.timber", 1) }, "Quest", 3)
		entries, seq = Inbox.add(
			entries,
			seq,
			{ { itemId = "item.stone_hatchet", count = 1, durability = 40 } :: any },
			"LevelUp",
			4
		)
		TestKit.equal(#entries, 3)
		TestKit.equal(entries[1].count, 8, "same item and source merged")
		TestKit.equal(entries[3].durability, 40)
		TestKit.equal(Inbox.totals(entries)["item.timber"], 9)
		TestKit.equal(seq, 3)
	end)

	test("inbox rows round-trip through the pool", function()
		local entries = Inbox.add({}, 0, { slot("item.timber", 5), slot("item.rope", 2) }, "Purchase", 1)
		local sources = { { key = "inbox", slots = Inbox.asSlots(entries) } }
		local changed = MaterialPool.take(sources, { { itemId = "item.timber", count = 5 } })
		assert(changed, "taken")
		local after = Inbox.fromSlots(entries, changed.inbox)
		TestKit.equal(#after, 1, "the emptied row is gone")
		TestKit.equal(after[1].itemId, "item.rope")
		TestKit.equal(#Inbox.withCount(after, after[1].id, 0), 0, "taking a row removes it")
	end)
end
