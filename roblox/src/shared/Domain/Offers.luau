--!strict
--[[
	Offers: the pure rules of the v0.1 shop and its Ember sinks (MVP_LAUNCH Monetization
	v0.1, docs/research/ldoe-monetization-playbook.md).

	- The Firestarter Kit: shown only to accounts that never paid, for an accurate 48 h from
	  their first win (the first night survived or the first extraction), once; the window
	  never restarts. It opens out loud (F-11): a one-time card, then the strip icon with its
	  countdown (stripOffer) until it ends.
	- Ember prices: a speed-up by time left (max(2, ceil(3.9 x sqrt(minutes)))), only for
	  jobs with at least 2 minutes left; Fill Up per missing unit; Trail Rations in ones
	  and fives.
	- Sales: a discount is only a genuine window of at least 72 h, and a countdown never
	  restarts for the same item (a sale that ended can't run again).
]]

local Offers = {}

export type EmberTuning = {
	recoverAll: number,
	ration: number,
	rationsFive: number,
	speedUpFactor: number,
	speedUpMin: number,
	speedUpMinSeconds: number,
	fillUp: { [string]: number }, -- Embers per missing unit, by item
	vipTrialDays: number,
	firstPurchaseHours: number,
}

export type Sale = { startsAt: number, endsAt: number, percentOff: number }

local HOUR = 60 * 60

-- Whether the player has ever paid: any developer product or game pass bought.
function Offers.hasPaid(counts: { [string]: number }): boolean
	for _, count in counts do
		if count > 0 then
			return true
		end
	end
	return false
end

-- The Firestarter window: open, and when it ends (0 before the first win).
function Offers.firstPurchase(
	counts: { [string]: number },
	firstWinAt: number,
	now: number,
	hours: number
): (boolean, number)
	if firstWinAt <= 0 then
		return false, 0
	end
	local endsAt = firstWinAt + hours * HOUR
	return not Offers.hasPaid(counts) and now < endsAt, endsAt
end

--[[
	The HUD's offers strip (the flow review's F-11): the product whose countdown is running for
	this player now (on offer, ending in the future), the soonest to end first, and when it
	ends; nil and 0 when there is none. `rows` is the synced "shop" section.
]]
function Offers.stripOffer(rows: any, now: number): (string?, number)
	if type(rows) ~= "table" then
		return nil, 0
	end
	local best: string?, bestEnds = nil, math.huge
	for id, row in rows do
		local ends = if type(row) == "table" and row.available == true then row.endsAt else nil
		if type(ends) == "number" and ends > now and (ends < bestEnds or (ends == bestEnds and id < (best or id))) then
			best, bestEnds = id, ends
		end
	end
	return best, if best then bestEnds else 0
end

--[[
	Embers to finish `seconds` of a station's work now; nil when under the minimum. `makes`
	is what that work turns out (speedUpMakes): the price never tops the Fill Up value of it
	(the flow review's F-25: skipping a 20-minute Scrap Plate cost 18 Embers when buying the
	plate outright cost 13), and never falls under speedUpMin.
]]
function Offers.speedUpPrice(
	seconds: number,
	tuning: EmberTuning,
	makes: { { itemId: string, count: number } }?
): number?
	if seconds < tuning.speedUpMinSeconds then
		return nil
	end
	local price = math.max(tuning.speedUpMin, math.ceil(tuning.speedUpFactor * math.sqrt(seconds / 60)))
	local value = if makes and #makes > 0 then Offers.fillUpPrice(makes, tuning) else nil
	if value then
		price = math.min(price, math.max(tuning.speedUpMin, value))
	end
	return price
end

--[[
	What `seconds` of a station's work makes: the whole batches of `outputs` that finish in
	it, the current one first (`batchRemaining` left on it, `batchSeconds` a batch after).
]]
function Offers.speedUpMakes(
	outputs: { { itemId: string, count: number } },
	batchRemaining: number,
	batchSeconds: number,
	seconds: number
): { { itemId: string, count: number } }
	local batches = 0
	if seconds >= batchRemaining - 1e-6 then
		batches = 1
		if batchSeconds > 0 then
			batches += math.floor((seconds - batchRemaining) / batchSeconds + 1e-6)
		end
	end
	local makes: { { itemId: string, count: number } } = {}
	if batches > 0 then
		for _, output in outputs do
			table.insert(makes, { itemId = output.itemId, count = output.count * batches })
		end
	end
	return makes
end

-- Embers to Fill Up `stacks`, rounded up once for the whole buy (raw materials cost a third
-- of an Ember a unit, F-25); nil when any item can't be bought this way (rare parts and
-- blueprints come only from play).
function Offers.fillUpPrice(stacks: { { itemId: string, count: number } }, tuning: EmberTuning): number?
	local total = 0
	for _, stack in stacks do
		local unit = tuning.fillUp[stack.itemId]
		if unit == nil or stack.count < 1 or stack.count ~= math.floor(stack.count) then
			return nil
		end
		total += unit * stack.count
	end
	return if total > 0 then math.ceil(total - 1e-9) else nil
end

--[[
	What a cost lacks: each stack the player has fewer of than `times` x its count, by how many
	(in the cost's order). Fill Up charges for this, never the whole cost: having 2 of 3 Timber
	buys 1. `have` counts an item the way the screen does (the home pool at home).
]]
function Offers.shortfall(
	cost: { { itemId: string, count: number } },
	have: (itemId: string) -> number,
	times: number?
): { { itemId: string, count: number } }
	local short: { { itemId: string, count: number } } = {}
	for _, stack in cost do
		local missing = stack.count * (times or 1) - have(stack.itemId)
		if missing > 0 then
			table.insert(short, { itemId = stack.itemId, count = missing })
		end
	end
	return short
end

--[[
	The Fill Up slot for a cost (the build tray, upgrades, crafting; the flow review's F-10):
	the missing stacks and their Ember price, or nil when nothing is missing or something
	missing can't be bought this way (rare parts and blueprints come only from play).
]]
function Offers.fillUpFor(
	cost: { { itemId: string, count: number } },
	have: (itemId: string) -> number,
	tuning: EmberTuning,
	times: number?
): ({ { itemId: string, count: number } }?, number?)
	local short = Offers.shortfall(cost, have, times)
	if #short == 0 then
		return nil, nil
	end
	local price = Offers.fillUpPrice(short, tuning)
	if price == nil then
		return nil, nil
	end
	return short, price
end

-- Embers for `count` Trail Rations: 5 for the five-price, the rest at the single price.
function Offers.rationsPrice(count: number, tuning: EmberTuning): number
	return (count // 5) * tuning.rationsFive + (count % 5) * tuning.ration
end

-- Whether a sale is a genuine window (at least 72 h, a real discount).
function Offers.validSale(sale: Sale): boolean
	return sale.endsAt - sale.startsAt >= 72 * HOUR and sale.percentOff > 0 and sale.percentOff < 100
end

-- Whether a sale is running now; a sale that has ended never runs again (no restarts).
function Offers.saleActive(sale: Sale?, now: number): boolean
	return sale ~= nil and Offers.validSale(sale) and now >= sale.startsAt and now < sale.endsAt
end

return Offers
