--!strict
-- Specs for the v0.1 shop (MVP_LAUNCH Monetization v0.1): Domain/Receipts, Domain/Offers,
-- Domain/Kits and the products.
local TestKit = require("./TestKit")
local Receipts = require("../src/shared/Domain/Receipts")
local Offers = require("../src/shared/Domain/Offers")
local Kits = require("../src/shared/Domain/Kits")
local PlayerSchema = require("../src/shared/Domain/PlayerSchema")
local Content = require("../src/shared/Data")

local Products: any = Content.Products
local embers: any = Content.Tuning.embers
local HOUR = 3600

local function fresh(): Receipts.Purchases
	return { receiptIds = {}, counts = {}, backpackSlots = 0 }
end

local function context(firstWinAt: number, now: number): Receipts.OfferContext
	return { now = now, firstWinAt = firstWinAt, firstPurchaseHours = embers.firstPurchaseHours }
end

return function(test: TestKit.Register)
	test("a receipt is granted once; the same receipt again grants nothing", function()
		local purchases = fresh()
		local product = Products["product.resource_pack"]
		local decision, delivery = Receipts.apply(purchases, product, "r-1", 100, 15)
		TestKit.equal(decision, "granted")
		TestKit.truthy(delivery ~= nil and #delivery.items > 0, "items delivered")
		local again, nothing = Receipts.apply(purchases, product, "r-1", 100, 15)
		TestKit.equal(again, "duplicate")
		TestKit.equal(nothing, nil)
		TestKit.equal(purchases.counts["product.resource_pack"], 1, "counted once")
	end)

	test("the receipt log keeps the newest entries up to its size", function()
		local purchases = fresh()
		local product = Products["product.energy_refill"]
		for index = 1, 5 do
			Receipts.apply(purchases, product, `r-{index}`, 3, 15)
		end
		TestKit.equal(#purchases.receiptIds, 3)
		TestKit.equal(purchases.receiptIds[1], "r-3")
		TestKit.equal(purchases.receiptIds[3], "r-5")
		TestKit.equal(purchases.counts["product.energy_refill"], 5)
	end)

	test("the Firestarter Kit: never-payers only, 48 h from the first win, once", function()
		local starter = Products["product.starter_offer"]
		local win = 1000000
		-- Before any win, never.
		TestKit.equal((Receipts.canOffer(starter, fresh(), 1, context(0, win))), false)
		-- In the window, with an accurate end.
		local ok, _, endsAt = Receipts.canOffer(starter, fresh(), 1, context(win, win + HOUR))
		TestKit.equal(ok, true)
		TestKit.equal(endsAt, win + 48 * HOUR)
		-- After the window, never again (it doesn't restart).
		local late, why = Receipts.canOffer(starter, fresh(), 1, context(win, win + 48 * HOUR))
		TestKit.equal(late, false)
		TestKit.equal(why, "window")
		-- Anyone who paid for anything, never.
		local paid = fresh()
		Receipts.apply(paid, Products["product.energy_refill"], "r-1", 100, 15)
		TestKit.equal((Receipts.canOffer(starter, paid, 1, context(win, win + HOUR))), false)
		-- A second receipt that slipped through a race is still delivered.
		local bought = fresh()
		Receipts.apply(bought, starter, "r-a", 100, 15)
		local decision, delivery = Receipts.apply(bought, starter, "r-b", 100, 15)
		TestKit.equal(decision, "granted")
		TestKit.truthy(delivery ~= nil and #delivery.items > 0, "still delivered")
	end)

	test("a game pass is recorded once and adds its backpack slots up to the cap", function()
		local purchases = fresh()
		local pass = Products["product.pack_expansion"]
		local first = Receipts.applyPass(purchases, pass, 7)
		TestKit.equal((first :: any).backpackSlots, 5)
		TestKit.equal(Receipts.applyPass(purchases, pass, 7), nil, "already recorded")
		TestKit.equal(purchases.backpackSlots, 5)
		TestKit.truthy(Offers.hasPaid(purchases.counts), "a pass counts as paying")
		local vip = Receipts.applyPass(fresh(), Products["product.vip_lounge"], 15)
		TestKit.truthy(vip ~= nil and vip.vipLounge, "the Lounge pass")
	end)

	test("Embers and energy deliver; every product has its card and exists on Roblox", function()
		local _, pouch = Receipts.apply(fresh(), Products["product.embers_50"], "r-1", 100, 15)
		TestKit.equal((pouch :: any).embers, 50)
		local _, chest = Receipts.apply(fresh(), Products["product.embers_300"], "r-2", 100, 15)
		TestKit.equal((chest :: any).embers, 300)
		local _, energy = Receipts.apply(fresh(), Products["product.energy_refill"], "r-3", 100, 15)
		TestKit.equal((energy :: any).energy, 100)
		local count, passes = 0, 0
		for id, product in Products do
			count += 1
			TestKit.equal(product.defaultPriceRobux, Content.Tuning.prices.robux[id], `{id} price from Tuning`)
			TestKit.truthy(product.description ~= "", `{id} has its card line`)
			TestKit.truthy(product.tab ~= nil, `{id} has its tab`)
			TestKit.truthy(product.robloxId > 0, `{id} exists on Roblox`)
			TestKit.truthy(type(product.icon) == "string" and product.icon ~= "", `{id} has its icon`)
			if product.kind == "gamePass" then
				passes += 1
				TestKit.equal(product.limit, 1)
			end
		end
		TestKit.equal(count, 18, "v0.1's ten, the Equipment six, the Building two")
		TestKit.equal(passes, 2, "Pack Expansion and the VIP Lounge")
		TestKit.equal(Receipts.productByRobloxId(Products, 0), nil)
	end)

	test("a +1 Smelter purchase raises the Smelter's plot limit by one per purchase", function()
		local BuildRules = require("../src/shared/Domain/BuildRules")
		local base = BuildRules.limitOf("build.smelter", Content.BuildPieces :: any)
		TestKit.truthy(base ~= nil, "the Smelter has a plot limit")
		local none = BuildRules.pieceSlots(Products :: any, {})
		TestKit.equal(BuildRules.limitOf("build.smelter", Content.BuildPieces :: any, none), base)
		local two = BuildRules.pieceSlots(Products :: any, { ["product.smelter_slot"] = 2 })
		TestKit.equal(BuildRules.limitOf("build.smelter", Content.BuildPieces :: any, two), (base :: number) + 2)
		-- Other pieces keep their limits.
		TestKit.equal(
			BuildRules.limitOf("build.recycler", Content.BuildPieces :: any, two),
			BuildRules.limitOf("build.recycler", Content.BuildPieces :: any)
		)
	end)

	test("Kits.room: every material for a 3x3 room up the upgrade chain (the Firestarter's Scrap room)", function()
		local kit = Kits.room(Content.BuildPieces :: any, 3)
		TestKit.truthy(#kit > 0, "materials")
		-- Exactly the chain costs: 9 foundations, 11 walls, a doorway and a door.
		local expect: { [string]: number } = {}
		for baseId, count in Kits.ROOM_3X3 do
			for _, stack in Kits.chainCost(Content.BuildPieces :: any, baseId, 3) or {} do
				expect[stack.itemId] = (expect[stack.itemId] or 0) + stack.count * count
			end
		end
		for _, stack in kit do
			TestKit.equal(stack.count, expect[stack.itemId], stack.itemId)
		end
		-- A Reinforced room costs more than the Scrap room in the Firestarter Kit. (The Reinforced
		-- Room Kit product is a head start on it, not the whole room: Data/Products.)
		local scrap = 0
		for _, stack in Kits.room(Content.BuildPieces :: any, 2) do
			scrap += stack.count
		end
		local reinforced = 0
		for _, stack in kit do
			reinforced += stack.count
		end
		TestKit.truthy(reinforced > scrap, "reinforced > scrap")
	end)

	test("Ember prices: speed-ups by time left, Fill Up per unit, Rations in fives", function()
		TestKit.equal(Offers.speedUpPrice(60, embers), nil, "under 2 minutes")
		TestKit.equal(Offers.speedUpPrice(10 * 60, embers), 13)
		TestKit.equal(Offers.speedUpPrice(60 * 60, embers), 31)
		TestKit.equal(Offers.speedUpPrice(4 * 60 * 60, embers), 61)
		TestKit.equal(
			Offers.fillUpPrice(
				{ { itemId = "item.scrap_plate", count = 2 }, { itemId = "item.timber", count = 5 } },
				embers
			),
			2 * embers.fillUp["item.scrap_plate"] + 5 * embers.fillUp["item.timber"]
		)
		TestKit.equal(Offers.fillUpPrice({ { itemId = "item.blueprint_nope", count = 1 } }, embers), nil)
		for itemId, unit in embers.fillUp do
			TestKit.truthy(Content.Items[itemId] ~= nil, `Fill Up prices a real item: {itemId}`)
			TestKit.truthy(unit >= 1 and unit == math.floor(unit), `{itemId} costs whole Embers`)
		end
		TestKit.equal(Offers.rationsPrice(1, embers), 20)
		TestKit.equal(Offers.rationsPrice(5, embers), 90)
		TestKit.equal(Offers.rationsPrice(7, embers), 130)
	end)

	test("sales are genuine 72 h windows and never restart; nothing sells stash capacity", function()
		local start = 5000000
		TestKit.equal(Offers.validSale({ startsAt = start, endsAt = start + 71 * HOUR, percentOff = 20 }), false)
		local sale = { startsAt = start, endsAt = start + 72 * HOUR, percentOff = 20 }
		TestKit.truthy(Offers.saleActive(sale, start + HOUR), "running")
		TestKit.equal(Offers.saleActive(sale, start + 72 * HOUR), false, "ended for good")
		for id, product in Products do
			for _, grant in product.grants do
				TestKit.truthy((grant :: any).kind ~= "stash", `{id} never sells locked-stash capacity`)
			end
		end
	end)

	test("v10 profiles start with no Embers and no win; the old backpack product maps to the pass", function()
		local template: any = PlayerSchema.template()
		TestKit.equal(template.embers, 0)
		TestKit.equal(template.shop.firstWinAt, 0)
		TestKit.equal(template.haven.vipTrialUntil, 0)
		TestKit.equal(#template.purchases.receiptIds, 0)
		local old: any = {
			version = 9,
			haven = PlayerSchema.freshHaven(),
			purchases = { receiptIds = {}, counts = { ["product.backpack_upgrade"] = 1 }, backpackSlots = 5 },
		}
		PlayerSchema.migrations[9](old)
		TestKit.equal(old.purchases.counts["product.pack_expansion"], 1)
		TestKit.equal(old.purchases.counts["product.backpack_upgrade"], nil)
		TestKit.equal(old.embers, 0)
	end)
end
