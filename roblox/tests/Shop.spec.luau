--!strict
-- Specs for Domain/Receipts (Robux purchases, MVP_LAUNCH v0.1) and the shop's products.
local TestKit = require("./TestKit")
local Receipts = require("../src/shared/Domain/Receipts")
local PlayerSchema = require("../src/shared/Domain/PlayerSchema")
local Content = require("../src/shared/Data")

local Products: any = Content.Products

local function fresh(): Receipts.Purchases
	return { receiptIds = {}, counts = {}, backpackSlots = 0 }
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

	test("limits gate the offer, never a paid delivery", function()
		local purchases = fresh()
		local starter = Products["product.starter_offer"]
		TestKit.equal((Receipts.canOffer(starter, purchases, 1)), true)
		Receipts.apply(purchases, starter, "r-a", 100, 15)
		local ok, why = Receipts.canOffer(starter, purchases, 1)
		TestKit.equal(ok, false)
		TestKit.equal(why, "limit")
		-- A second receipt that slipped through a race is still delivered.
		local decision, delivery = Receipts.apply(purchases, starter, "r-b", 100, 15)
		TestKit.equal(decision, "granted")
		TestKit.truthy(delivery ~= nil and #delivery.items > 0, "still delivered")
	end)

	test("the starter pack is offered only up to its level", function()
		local starter = Products["product.starter_offer"]
		local ok, why = Receipts.canOffer(starter, fresh(), (starter.offerMaxLevel :: number) + 1)
		TestKit.equal(ok, false)
		TestKit.equal(why, "level")
	end)

	test("backpack slots bought add up to the cap and report what was added", function()
		local purchases = fresh()
		local upgrade = Products["product.backpack_upgrade"]
		local _, first = Receipts.apply(purchases, upgrade, "r-1", 100, 7)
		TestKit.equal((first :: any).backpackSlots, 5)
		local _, second = Receipts.apply(purchases, upgrade, "r-2", 100, 7)
		TestKit.equal((second :: any).backpackSlots, 2, "only up to the cap")
		TestKit.equal(purchases.backpackSlots, 7)
	end)

	test("energy refills deliver energy, and every v0.1 product is listed with art", function()
		local _, delivery = Receipts.apply(fresh(), Products["product.energy_refill"], "r-1", 100, 15)
		TestKit.equal((delivery :: any).energy, 100)
		local count = 0
		for id, product in Products do
			count += 1
			TestKit.truthy(product.robloxId > 0, `{id} has its Roblox product`)
			TestKit.truthy(product.kind == "devProduct", `{id} is a developer product`)
			TestKit.truthy(type(product.icon) == "string" and product.icon ~= "", `{id} has its icon`)
			TestKit.truthy(product.description ~= "", `{id} has its card line`)
			TestKit.equal(Receipts.productByRobloxId(Products, product.robloxId), product)
		end
		TestKit.equal(count, 4, "four products in v0.1")
		TestKit.equal(Receipts.productByRobloxId(Products, 0), nil)
	end)

	test("new profiles carry an empty purchase record", function()
		local template: any = PlayerSchema.template()
		TestKit.equal(#template.purchases.receiptIds, 0)
		TestKit.equal(template.purchases.backpackSlots, 0)
		TestKit.truthy(type(template.purchases.counts) == "table", "counts")
	end)
end
