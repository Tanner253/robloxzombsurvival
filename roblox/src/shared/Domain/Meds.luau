--!strict
--[[
	Meds: the meds ladder past the dressing (docs/CONTENT_2_0.md §4). Pure.

	A med heals its instant `consume.health` at once (Domain/Survival), then its
	`consume.healOverTime.amount` spread evenly over `seconds`. Up to MAX_ACTIVE heals run at
	once; a further one replaces the heal with the least left, so stacking kits is never a
	waste and never a stockpile. Heals stop on death (the server drops them).

	The ladder: Field Dressing 40 (LDoE's bandage) -> Trauma Pouch 25 + 40/10 s -> First-Aid
	Kit 40 + 60/12 s -> Ember Stim 60 + 50/5 s.
]]

local Types = require("../Types")

local Meds = {}

Meds.MAX_ACTIVE = 3

export type Heal = {
	perSecond: number,
	remaining: number, -- health still to give
	updatedAt: number, -- the clock (seconds) it was last stepped to
}

-- Everything a med gives: instant plus over time. The meds button picks the biggest.
function Meds.total(effect: Types.ConsumeEffect): number
	local hot = effect.healOverTime
	return (effect.health or 0) + (if hot then hot.amount else 0)
end

-- The heal a med starts at `now`, or nil if it has no healing over time.
function Meds.start(effect: Types.ConsumeEffect, now: number): Heal?
	local hot = effect.healOverTime
	if hot == nil or hot.amount <= 0 or hot.seconds <= 0 then
		return nil
	end
	return { perSecond = hot.amount / hot.seconds, remaining = hot.amount, updatedAt = now }
end

-- `heals` with `heal` added, keeping at most MAX_ACTIVE (the one with least left goes).
function Meds.add(heals: { Heal }, heal: Heal): { Heal }
	local result = table.clone(heals)
	table.insert(result, heal)
	if #result > Meds.MAX_ACTIVE then
		local least = 1
		for index, entry in result do
			if entry.remaining < result[least].remaining then
				least = index
			end
		end
		table.remove(result, least)
	end
	return result
end

-- Steps every heal to `now`. Returns the health to give and the heals still running.
function Meds.step(heals: { Heal }, now: number): (number, { Heal })
	local healed = 0
	local running: { Heal } = {}
	for _, heal in heals do
		local dt = math.max(0, now - heal.updatedAt)
		local amount = math.min(heal.remaining, heal.perSecond * dt)
		healed += amount
		local remaining = heal.remaining - amount
		if remaining > 1e-6 then
			table.insert(running, { perSecond = heal.perSecond, remaining = remaining, updatedAt = now })
		end
	end
	return healed, running
end

return Meds
