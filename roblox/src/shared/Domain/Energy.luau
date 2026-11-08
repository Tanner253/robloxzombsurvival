--!strict
--[[
	Energy: the Run currency for Fog-map travel (GAME_DESIGN.md "Structure";
	ldoe-systems/economy-progression.md §5.5).

	Stored as { value, updatedAt } (PlayerSchema.energy). Regeneration is computed
	from timestamps with Timers.accrue: one point per `secondsPerPoint` up to
	`cap`, with partial progress kept. Nothing ticks.

	Over-cap rules (LDoE):
	- Natural regeneration stops at the cap.
	- Food and drink fill up to the cap; the excess is lost ("clamp").
	- Energy items (an Energy Drink) are refused at or above the cap, but otherwise
	  add their full amount and may go over it ("item").
	- Purchases and rewards always apply and may go over the cap ("grant").
	- Over-cap values are never reduced by regeneration; `hardCap` (optional) is
	  the absolute ceiling for "item" and "grant".

	All functions are pure; pass `now` in.
]]

local Timers = require("./Timers")

local Energy = {}

export type State = {
	value: number,
	updatedAt: number,
}

-- Types.TuningDef.energy satisfies this; hardCap is optional.
export type Config = {
	cap: number,
	secondsPerPoint: number,
	hardCap: number?,
}

export type RestoreMode = "clamp" | "item" | "grant"

local function assertAmount(amount: number)
	assert(amount >= 0 and amount % 1 == 0, "amount must be a non-negative integer")
end

-- The state brought up to `now`: regeneration applied, partial progress kept.
function Energy.current(state: State, now: number, config: Config): State
	local value, updatedAt = Timers.accrue(state.value, state.updatedAt, now, config.cap, config.secondsPerPoint)
	return { value = value, updatedAt = updatedAt }
end

function Energy.canSpend(state: State, now: number, config: Config, amount: number): boolean
	return Energy.current(state, now, config).value >= amount
end

--[[
	Spends `amount` after applying regeneration. Returns the new state, or nil if
	there is not enough. Spending from at or above the cap starts the regen clock
	at `now`; spending below the cap keeps the partial progress.
]]
function Energy.spend(state: State, now: number, config: Config, amount: number): State?
	assertAmount(amount)
	local current = Energy.current(state, now, config)
	if current.value < amount then
		return nil
	end
	return { value = current.value - amount, updatedAt = current.updatedAt }
end

--[[
	Adds energy using one of the over-cap rules above. Returns the new state and
	the amount actually added, or nil and 0 when an "item" is refused at the cap.
]]
function Energy.restore(state: State, now: number, config: Config, amount: number, mode: RestoreMode): (State?, number)
	assertAmount(amount)
	local current = Energy.current(state, now, config)
	local value = current.value
	local ceiling = config.hardCap or math.huge
	assert(ceiling >= config.cap, "hardCap must be at least cap")

	local newValue: number
	if mode == "clamp" then
		newValue = math.max(value, math.min(config.cap, value + amount))
	elseif mode == "item" then
		if value >= config.cap then
			return nil, 0
		end
		newValue = math.min(ceiling, value + amount)
	else
		newValue = math.max(value, math.min(ceiling, value + amount))
	end

	local updatedAt = if newValue >= config.cap then now else current.updatedAt
	return { value = newValue, updatedAt = updatedAt }, newValue - value
end

-- Seconds of regeneration until the value reaches `target` (0 if it already has;
-- math.huge if `target` is above the cap, which regeneration never reaches).
function Energy.secondsUntil(state: State, now: number, config: Config, target: number): number
	local current = Energy.current(state, now, config)
	if current.value >= target then
		return 0
	end
	if target > config.cap then
		return math.huge
	end
	local readyAt = current.updatedAt + (target - current.value) * config.secondsPerPoint
	return math.max(0, readyAt - now)
end

function Energy.secondsUntilFull(state: State, now: number, config: Config): number
	return Energy.secondsUntil(state, now, config, config.cap)
end

return Energy
