--!strict
-- MomentOffers: the death screen's actions and offers, and the Fog map's Refill slot (F-08, F-09).
local TestKit = require("./TestKit")
local MomentOffers = require("../src/shared/Domain/MomentOffers")
local Content = require("../src/shared/Data")

local function death(overrides: { [string]: any }): MomentOffers.DeathScreen
	local input: { [string]: any } = {
		energy = 100,
		reentryCost = 10,
		canReenter = true,
		hasBag = true,
		embers = 150,
		recoverCost = 100,
		adsShipped = false,
	}
	for key, value in overrides do
		input[key] = value
	end
	return MomentOffers.deathScreen(input :: any)
end

return function(test: TestKit.Register)
	test("MomentOffers: the SKUs it offers exist in the shop data", function()
		for _, id in { MomentOffers.KIT, MomentOffers.REFILL, MomentOffers.EMBERS } do
			TestKit.truthy(Content.Products[id] ~= nil, `{id} is a product`)
		end
		TestKit.equal(Content.Products[MomentOffers.EMBERS].name, "Ember Pouch")
	end)

	test("MomentOffers: Go back in when the Energy covers it, the Refill with the shortfall when not", function()
		local paid = death({})
		TestKit.equal(paid.goBack, "pay")
		TestKit.equal(paid.energyShort, 0)
		local short = death({ energy = 3.4 })
		TestKit.equal(short.goBack, "refill", "never a dead grey button")
		TestKit.equal(short.energyShort, 7, "10 - 3.4, rounded up")
		TestKit.equal(death({ energy = 10 }).goBack, "pay", "exactly enough")
	end)

	test("MomentOffers: no Go back in past the cutoff or once the bag is recovered", function()
		TestKit.equal(death({ canReenter = false }).goBack, "none")
		TestKit.equal(death({ hasBag = false }).goBack, "none")
		TestKit.equal(death({ canReenter = false, energy = 0 }).energyShort, 0, "no refill for a door that's shut")
	end)

	test("MomentOffers: Recover all for 100 Embers, or the Ember Pouch when short", function()
		TestKit.equal(death({ embers = 100 }).recover, "pay")
		local short = death({ embers = 40 })
		TestKit.equal(short.recover, "buyEmbers")
		TestKit.equal(short.embersShort, 60)
		TestKit.equal(death({ hasBag = false }).recover, "none", "nothing left to recover")
		TestKit.equal(Content.Tuning.embers.recoverAll, 100, "the designed sink")
	end)

	test("MomentOffers: the kit chip always shows; the ad option only once ads ship", function()
		TestKit.equal(death({}).kit, "product.scavenger_kit")
		TestKit.equal(death({ hasBag = false, canReenter = false }).kit, "product.scavenger_kit")
		TestKit.equal(death({}).recoverByAd, false, "ads aren't shipped")
		TestKit.equal(death({ adsShipped = true }).recoverByAd, true)
		TestKit.equal(death({ adsShipped = true, hasBag = false }).recoverByAd, false)
	end)

	test("MomentOffers: the Run slot greys with a Refill only when Energy is what's missing", function()
		TestKit.deepEqual(MomentOffers.runSlot(50, 20, false), { run = "go", short = 0 })
		TestKit.deepEqual(MomentOffers.runSlot(12, 20, false), { run = "refill", short = 8 })
		TestKit.deepEqual(MomentOffers.runSlot(0, 20, true), { run = "blocked", short = 0 })
	end)

	test("MomentOffers: leaving the death screen", function()
		TestKit.deepEqual(MomentOffers.afterHold("back", false), { reenter = true, keepReentry = true })
		TestKit.deepEqual(MomentOffers.afterHold("continue", false), { reenter = false, keepReentry = true })
		TestKit.deepEqual(MomentOffers.afterHold("back", true), { reenter = false, keepReentry = false })
		TestKit.deepEqual(
			MomentOffers.afterHold("lobbyClosed", false),
			{ reenter = false, keepReentry = false },
			"the lobby ending counts as Continue"
		)
	end)
end
