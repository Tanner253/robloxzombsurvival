--!strict
--[[
	MomentOffers: what the two highest-intent buying moments show (the flow review's F-08 and
	F-09; SHOP_CATALOG §6). Pure: the screens and Services/Lobby ask, nothing is sold here.

	- deathScreen(input): the death screen's actions and offers. "Go back in" when the Energy
	  covers it, otherwise the Energy Refill in its place with the shortfall (never a dead
	  grey button); "Recover all" for its Embers while the bag is out there, otherwise the
	  Ember Pouch (LDoE: the button you can't pay opens the currency purchase); the gear
	  chip always (the Scavenger's Kit). The recover-by-ad option shows only once ads ship.
	- runSlot(energy, cost, blocked): the Fog map's Run. Short of Energy, the Run greys and
	  the Refill slot beside it shows the shortfall. A Run blocked for another reason (level,
	  an event between windows) offers nothing: Energy wouldn't open it.
	- afterHold(choice, recovered): where a dead player goes once they leave the death screen
	  on the run side (they stay there until they choose; the lobby closing counts as
	  "continue").
]]

local MomentOffers = {}

MomentOffers.KIT = "product.scavenger_kit"
MomentOffers.REFILL = "product.energy_refill"
MomentOffers.EMBERS = "product.embers_50" -- the Ember Pouch

export type DeathInput = {
	energy: number, -- Energy now
	reentryCost: number, -- what "Go back in" costs (half the location's Run)
	canReenter: boolean, -- the lobby still takes them back (open, before the cutoff)
	hasBag: boolean, -- their drop is still out there (not recovered, lobby open)
	embers: number,
	recoverCost: number, -- Tuning.embers.recoverAll
	adsShipped: boolean,
}

export type DeathScreen = {
	goBack: "pay" | "refill" | "none",
	energyShort: number,
	recover: "pay" | "buyEmbers" | "none",
	embersShort: number,
	recoverByAd: boolean,
	kit: string,
}

export type RunSlot = {
	run: "go" | "refill" | "blocked",
	short: number,
}

export type Choice = "continue" | "back" | "lobbyClosed"

-- How much of `cost` `have` doesn't cover, in whole points (0 when covered).
function MomentOffers.shortfall(have: number, cost: number): number
	return math.max(0, math.ceil(cost - have))
end

function MomentOffers.deathScreen(input: DeathInput): DeathScreen
	local energyShort = MomentOffers.shortfall(input.energy, input.reentryCost)
	local embersShort = MomentOffers.shortfall(input.embers, input.recoverCost)
	local goBack: "pay" | "refill" | "none" = "none"
	if input.canReenter and input.hasBag then
		goBack = if energyShort > 0 then "refill" else "pay"
	end
	local recover: "pay" | "buyEmbers" | "none" = "none"
	if input.hasBag then
		recover = if embersShort > 0 then "buyEmbers" else "pay"
	end
	return {
		goBack = goBack,
		energyShort = if goBack == "refill" then energyShort else 0,
		recover = recover,
		embersShort = if recover == "buyEmbers" then embersShort else 0,
		recoverByAd = input.adsShipped and input.hasBag,
		kit = MomentOffers.KIT,
	}
end

function MomentOffers.runSlot(energy: number, cost: number, blocked: boolean): RunSlot
	if blocked then
		return { run = "blocked", short = 0 }
	end
	local short = MomentOffers.shortfall(energy, cost)
	return { run = if short > 0 then "refill" else "go", short = short }
end

-- Once the death screen closes: whether to start the trip back in from home, and whether the
-- re-entry stays open (not once the bag is recovered, nor after the lobby closed).
function MomentOffers.afterHold(choice: Choice, recovered: boolean): { reenter: boolean, keepReentry: boolean }
	if choice == "lobbyClosed" then
		return { reenter = false, keepReentry = false }
	end
	local open = not recovered
	return { reenter = choice == "back" and open, keepReentry = open }
end

return MomentOffers
