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

	test("every pack is repurchasable and its gear arrives fresh, one piece a row", function()
		local onceOnly = {
			["product.starter_offer"] = true, -- the one-time Firestarter Kit
			["product.pack_expansion"] = true, -- game passes
			["product.vip_lounge"] = true,
			["product.smelter_slot"] = true, -- capacity
			["product.recycler_slot"] = true,
		}
		for id, product in Products do
			if not onceOnly[id] then
				TestKit.equal(product.limit, nil, `{id} can be bought again`)
			end
			-- Nothing in a repeatable pack is a permanent unlock (a blueprint or a bag).
			if not onceOnly[id] then
				for _, grant in product.grants do
					local g: any = grant
					if g.kind == "item" then
						local def = Content.Items[g.itemId]
						TestKit.truthy(def.category ~= "blueprint" and def.category ~= "bag", `{id}: {g.itemId}`)
					end
				end
			end
		end
		local slots = Receipts.inboxSlots({
			{ itemId = "item.pipe_pistol", count = 2 },
			{ itemId = "item.field_dressing", count = 5 },
		}, Content.Items :: any)
		TestKit.equal(#slots, 3, "two pistols in their own rows, the dressings stacked")
		TestKit.equal((slots[1] :: any).durability, Content.Items["item.pipe_pistol"].durability)
		TestKit.equal((slots[3] :: any).count, 5)
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
			math.ceil(2 * embers.fillUp["item.scrap_plate"] + 5 * embers.fillUp["item.timber"])
		)
		TestKit.equal(Offers.fillUpPrice({ { itemId = "item.blueprint_nope", count = 1 } }, embers), nil)
		for itemId, unit in embers.fillUp do
			TestKit.truthy(Content.Items[itemId] ~= nil, `Fill Up prices a real item: {itemId}`)
			local thirds = unit * 3
			TestKit.truthy(
				unit >= 1 / 3 and math.abs(thirds - math.round(thirds)) < 1e-9,
				`{itemId}: thirds of an Ember`
			)
		end
		-- F-25: raw materials are a third of an Ember a unit, rounded up once per buy.
		TestKit.equal(Offers.fillUpPrice({ { itemId = "item.timber", count = 30 } }, embers), 10)
		TestKit.equal(Offers.fillUpPrice({ { itemId = "item.timber", count = 1 } }, embers), 1, "never free")
		TestKit.equal(
			Offers.fillUpPrice({ { itemId = "item.stone", count = 4 }, { itemId = "item.timber", count = 3 } }, embers),
			3
		)
		TestKit.equal(Offers.rationsPrice(1, embers), 20)
		TestKit.equal(Offers.rationsPrice(5, embers), 90)
		TestKit.equal(Offers.rationsPrice(7, embers), 130)
	end)

	test("F-25: a speed-up never costs more than buying what it makes", function()
		local plate = Content.Recipes["recipe.scrap_plate"]
		local seconds = plate.craftSeconds
		-- One 20-minute plate: 18 by time, 13 by Fill Up (the review's example).
		local one = Offers.speedUpMakes(plate.outputs, seconds, seconds, seconds)
		TestKit.deepEqual(one, { { itemId = "item.scrap_plate", count = 1 } })
		TestKit.equal(Offers.speedUpPrice(seconds, embers), 18, "by time alone")
		TestKit.equal(Offers.speedUpPrice(seconds, embers, one), embers.fillUp["item.scrap_plate"], "capped")
		-- A long queue still prices by time (78 for 20 plates, under their 260).
		local queue = Offers.speedUpMakes(plate.outputs, seconds, seconds, 20 * seconds)
		TestKit.equal(queue[1].count, 20)
		TestKit.equal(Offers.speedUpPrice(20 * seconds, embers, queue), 78)
		-- A batch the fuel won't finish makes nothing; then only time prices it.
		TestKit.deepEqual(Offers.speedUpMakes(plate.outputs, seconds, seconds, seconds - 60), {})
		-- The minimum still holds when what it makes is cheap.
		local timber = { { itemId = "item.timber", count = 1 } }
		TestKit.equal(Offers.speedUpPrice(10 * 60, embers, timber), embers.speedUpMin)
		-- Every station recipe: the capped price is at most its output's Fill Up value.
		for id, recipe in Content.Recipes do
			if recipe.stationId and recipe.craftSeconds >= embers.speedUpMinSeconds then
				local value = Offers.fillUpPrice(recipe.outputs, embers)
				local price = Offers.speedUpPrice(recipe.craftSeconds, embers, recipe.outputs) :: number
				if value then
					TestKit.truthy(price <= math.max(embers.speedUpMin, value), `{id}: {price} > {value}`)
				end
			end
		end
	end)

	test("F-25: the bigger resource pack is the better rate, at Fill Up prices per Robux", function()
		local packs = { "product.resource_pack", "product.builders_crate", "product.room_kit_reinforced" }
		local last = 0
		for _, id in packs do
			local product = Products[id]
			local stacks = {}
			for _, grant in product.grants do
				TestKit.equal(grant.kind, "item", id)
				table.insert(stacks, { itemId = (grant :: any).itemId, count = (grant :: any).count })
			end
			local value = Offers.fillUpPrice(stacks, embers) :: number
			local rate = value / product.defaultPriceRobux
			TestKit.truthy(rate > last, `{id}: {value} Embers for {product.defaultPriceRobux} is not a better rate`)
			last = rate
		end
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

	test("F-08: the death screen and Fog map hooks exist and prompt their products", function()
		local fs = require("@lune/fs")
		local hooks = fs.readFile("src/client/UI/offers.luau")
		for _, name in { "gear", "gearChip", "buyEnergy", "energyChip" } do
			TestKit.truthy(string.find(hooks, `\n\t{name} = nil :: `, 1, true), `offers.{name} is declared`)
		end
		local shop = fs.readFile("src/client/Controllers/Shop.luau")
		TestKit.truthy(string.find(shop, 'local GEAR = "product.scavenger_kit"', 1, true), "the kit")
		TestKit.truthy(string.find(shop, 'local REFILL = "product.energy_refill"', 1, true), "the refill")
		for _, name in { "gear", "gearChip", "buyEnergy", "energyChip" } do
			TestKit.truthy(string.find(shop, `offers.{name} = function`, 1, true), `Controllers/Shop sets {name}`)
		end
		TestKit.truthy(string.find(shop, "Actions.buyProduct(GEAR)", 1, true), "gear prompts the kit")
		TestKit.truthy(string.find(shop, "Actions.buyProduct(REFILL)", 1, true), "buyEnergy prompts the refill")
		-- The toast the offer rides on is the server's own text.
		local travel = fs.readFile("src/server/Services/Travel.luau")
		TestKit.truthy(string.find(travel, 'energy = "Not enough Energy for a Run"', 1, true), "the toast")
		TestKit.truthy(string.find(shop, '"not enough energy"', 1, true), "matched")
		local refill = 0
		for _, grant in Products["product.energy_refill"].grants do
			refill += if grant.kind == "energy" then grant.amount else 0
		end
		TestKit.truthy(refill > 0, "the Refill gives Energy")
	end)

	-- Batch 2 (the flow review's quality-of-life findings) ---------------------------------

	local Unlocks = require("../src/shared/Domain/Unlocks")
	local MomentOffers = require("../src/shared/Domain/MomentOffers")
	local NAMES: any = { items = Content.Items, quests = Content.Quests }

	local function progress(completed: { [string]: number }?, blueprints: { [string]: boolean }?): Unlocks.Progress
		return {
			level = 1,
			unlocks = { recipes = {}, blueprints = blueprints or {} },
			quests = { completed = completed or {} },
		}
	end

	local function gated(gate: any, ctx: Receipts.OfferContext): Receipts.OfferContext
		ctx.progress = if gate.kind == "quest"
			then progress({ [gate.questId] = 1 })
			else progress(nil, { [gate.itemId] = true })
		return ctx
	end

	test("F-12: a pack whose gate isn't met is greyed with its line, and sells once it is", function()
		local kit = Products["product.room_kit_reinforced"]
		TestKit.deepEqual(kit.unlock, { kind = "blueprint", itemId = "item.bp_reinforced" }, "the Plans")
		local ctx = context(0, 1000)
		ctx.progress = progress()
		local ok, reason = Receipts.canOffer(kit, fresh(), 1, ctx)
		TestKit.equal(ok, false)
		TestKit.equal(reason, "locked")
		TestKit.equal(
			Receipts.lockLine(kit, reason, ctx, NAMES, Content.BuildPieces :: any),
			"Read the Reinforcement Plans"
		)
		TestKit.equal((Receipts.canOffer(kit, fresh(), 1, gated(kit.unlock, context(0, 1000)))), true, "after reading")
		-- Every gate names something real, and the parts pack opens with the re-crafts it feeds.
		for id, product in Products do
			local gate: any = product.unlock
			if gate then
				TestKit.truthy(Unlocks.text(gate, NAMES) ~= nil, `{id} has a lock line`)
				TestKit.truthy(
					(gate.kind == "quest" and Content.Quests[gate.questId] ~= nil)
						or (gate.kind == "blueprint" and Content.Items[gate.itemId] ~= nil),
					`{id}'s gate exists`
				)
			end
		end
		local parts = Products["product.weapon_parts"].unlock :: any
		local feeds = false
		for _, recipe in Content.Recipes do
			local gate: any = recipe.unlock
			for _, input in recipe.inputs do
				if input.itemId == "item.trigger_group" and gate.kind == "quest" and gate.questId == parts.questId then
					feeds = true
				end
			end
		end
		TestKit.truthy(feeds, "Weapon Parts opens with the first recipe that takes a Trigger Group")
	end)

	test("F-27: '+1 can be placed' waits for a full plot and names the count", function()
		local slot = Products["product.smelter_slot"]
		local ctx = context(0, 1000)
		ctx.progress = progress({ ["quest.into_the_fog"] = 1 })
		TestKit.equal(select(2, Receipts.canOffer(slot, fresh(), 1, ctx)), "notFull", "no plot known: not offered")
		ctx.placed = { ["build.smelter"] = { count = 1, limit = 2 } }
		local ok, reason = Receipts.canOffer(slot, fresh(), 1, ctx)
		TestKit.equal(ok, false)
		TestKit.equal(
			Receipts.lockLine(slot, reason, ctx, NAMES, Content.BuildPieces :: any),
			"Placed 1/2: buy when your plot is full"
		)
		ctx.placed = { ["build.smelter"] = { count = 2, limit = 2 } }
		TestKit.equal((Receipts.canOffer(slot, fresh(), 1, ctx)), true, "full: on offer")
		-- Before the Smelter unlocks the line names its quest, not a count.
		local early = context(0, 1000)
		early.progress = progress()
		early.placed = { ["build.smelter"] = { count = 0, limit = 2 } }
		local _, why = Receipts.canOffer(slot, fresh(), 1, early)
		local line = Receipts.lockLine(slot, why, early, NAMES, Content.BuildPieces :: any) :: string
		TestKit.truthy(string.find(line, "quest", 1, true) ~= nil, line)
		-- BuildRules.placedCaps counts each capped chain on a real layout.
		local BuildRules = require("../src/shared/Domain/BuildRules")
		local Grid = require("../src/shared/Domain/Grid")
		local caps = BuildRules.placedCaps(Grid.new(), Content.BuildPieces :: any, { ["build.smelter"] = 1 })
		TestKit.deepEqual(
			caps["build.smelter"],
			{ count = 0, limit = (BuildRules.limitOf("build.smelter", Content.BuildPieces :: any) :: number) + 1 }
		)
	end)

	test("F-26: the Scout's Kit has its own job, not a worse Scavenger's Kit", function()
		local function contents(id: string): { [string]: number }
			local result: { [string]: number } = {}
			for _, grant in Products[id].grants do
				local g: any = grant
				if g.kind == "item" then
					result[g.itemId] = (result[g.itemId] or 0) + g.count
				end
			end
			return result
		end
		local scout, scavenger = contents("product.scouts_kit"), contents("product.scavenger_kit")
		local armor, only = 0, 0
		for itemId in scout do
			if Content.Items[itemId].category == "armor" then
				armor += 1
			end
			if scavenger[itemId] == nil then
				only += 1
			end
		end
		TestKit.equal(armor, 4, "a whole armor set, head to feet")
		TestKit.truthy((scout["item.rations"] or 0) > 0, "Rations for the road")
		TestKit.truthy(only >= 5, "most of it is nothing the Scavenger's Kit has")
	end)

	test("F-28: a broken weapon offers the kit, a broken tool its Fill Up, armor nothing", function()
		local items: any, recipes: any = Content.Items, Content.Recipes
		TestKit.deepEqual(
			MomentOffers.forBreak("Your Scrapblade broke: switched weapons", items, recipes),
			{ kind = "kit" }
		)
		local tool = MomentOffers.forBreak("Your Stone Hatchet broke", items, recipes) :: any
		TestKit.equal(tool and tool.kind, "fillUp")
		TestKit.equal(recipes[tool.recipeId].outputs[1].itemId, "item.stone_hatchet")
		TestKit.equal(MomentOffers.forBreak("Your armor broke", items, recipes), nil)
		TestKit.equal(MomentOffers.forBreak("Your bag is full", items, recipes), nil)
		local fs = require("@lune/fs")
		local shop = fs.readFile("src/client/Controllers/Shop.luau")
		TestKit.truthy(string.find(shop, "MomentOffers.forBreak(text", 1, true), "the toast asks forBreak")
		TestKit.equal(string.find(shop, '" broke"', 1, true), nil, "no blanket match on any break")
	end)

	test("F-11: the Firestarter window opens out loud: a one-time card, then the strip countdown", function()
		local rows = {
			["product.starter_offer"] = { available = true, endsAt = 5000 },
			["product.resource_pack"] = { available = true, endsAt = 0 },
			["product.vip_lounge"] = { available = false, endsAt = 9000 },
		}
		TestKit.deepEqual({ Offers.stripOffer(rows, 1000) }, { "product.starter_offer", 5000 })
		TestKit.deepEqual({ Offers.stripOffer(rows, 5000) }, { nil, 0 }, "gone when the window ends")
		TestKit.deepEqual({ Offers.stripOffer(nil, 1000) }, { nil, 0 }, "nothing before the shop syncs")
		-- The wiring: the server's one-time effect, the client's card and the HUD's strip.
		local fs = require("@lune/fs")
		local needles = {
			{ "src/server/Services/Shop.luau", 'Sync.fx(player, "firstOffer"' },
			{ "src/server/Services/Shop.luau", "data.shop.cardShown = true" },
			{ "src/server/Services/Shop.luau", 'if outcome == "extracted" then' },
			{ "src/client/Controllers/Shop.luau", 'kind == "firstOffer"' },
			{ "src/client/UI/App.luau", "e(OfferCard)" },
			{ "src/client/UI/screens/ldoe/OfferCard.luau", "Actions.buyProduct(card.productId)" },
			{ "src/client/UI/screens/ldoe/Hud.luau", "Offers.stripOffer(shop, now)" },
			{ "src/client/UI/screens/ldoe/Hud.luau", "Offer = not onRun and e(OfferStrip)" },
		}
		for _, needle in needles do
			TestKit.truthy(string.find(fs.readFile(needle[1]), needle[2], 1, true), `{needle[1]}: {needle[2]}`)
		end
	end)

	test("F-10: Fill Up charges for what is missing, never the whole cost", function()
		local have = function(itemId: string): number
			return if itemId == "item.timber" then 2 else 0
		end
		local cost = { { itemId = "item.timber", count = 3 }, { itemId = "item.stone", count = 2 } }
		TestKit.deepEqual(
			Offers.shortfall(cost, have),
			{ { itemId = "item.timber", count = 1 }, { itemId = "item.stone", count = 2 } }
		)
		TestKit.deepEqual(Offers.shortfall(cost, have, 2)[1], { itemId = "item.timber", count = 4 }, "two crafts")
		local short, price = Offers.fillUpFor(cost, have, embers)
		TestKit.equal(#(short :: any), 2)
		TestKit.equal(price, Offers.fillUpPrice(short :: any, embers))
		TestKit.equal(Offers.fillUpFor({ { itemId = "item.timber", count = 2 } }, have, embers), nil, "nothing short")
		TestKit.equal(
			Offers.fillUpFor({ { itemId = "item.bp_reinforced", count = 1 } }, have, embers),
			nil,
			"not for sale"
		)
	end)
end
