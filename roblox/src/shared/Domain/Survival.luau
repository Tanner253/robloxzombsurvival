--!strict
--[[
	Survival: hunger and thirst meters (ldoe-systems/economy-progression.md §5).

	Each meter drains linearly from a timestamp, so the value at any moment is
	computed, not ticked. Meters only drain while the player is in the world:
	LDoE does not drain them on the global map, and an offline player must never
	starve. Call `resume` when the player enters the world (join, arrival at a
	location) so time away is not charged, and `advance` while they play.

	Damage-over-time thresholds are additive: each threshold whose level a meter
	is at or below adds its damage per second. For example hunger
	{ { atOrBelow = 20, damagePerSecond = 0.5 }, { atOrBelow = 0, damagePerSecond = 1.5 } }
	deals 0.5 HP/s below 20 and 2 HP/s at 0. Damage is computed exactly, even
	when a meter crosses a threshold partway through the interval.

	Survival does not own health or energy; it reports damage, healing and
	energy for the Combat and Energy code to apply.
]]

local Survival = {}

export type Meter = "hunger" | "thirst"

export type State = {
	hunger: number,
	thirst: number,
	updatedAt: number,
}

export type Threshold = {
	atOrBelow: number,
	damagePerSecond: number,
}

export type MeterConfig = {
	max: number,
	decayPerSecond: number,
	thresholds: { Threshold },
}

export type Config = {
	hunger: MeterConfig,
	thirst: MeterConfig,
}

-- What eating or drinking one item does. Negative values are allowed (salty food).
export type Effect = {
	health: number?,
	hunger: number?,
	thirst: number?,
	energy: number?,
}

export type ConsumeResult = {
	state: State,
	damage: number, -- from draining up to `now`, before the item took effect
	heal: number, -- health to add (Effect.health)
	energy: number, -- energy to restore with Energy.restore(..., "clamp")
}

local function valueOf(state: State, meter: Meter): number
	return if meter == "hunger" then state.hunger else state.thirst
end

local function configOf(config: Config, meter: Meter): MeterConfig
	return if meter == "hunger" then config.hunger else config.thirst
end

-- A full state with its clock at `now`.
function Survival.new(now: number, config: Config): State
	return { hunger = config.hunger.max, thirst = config.thirst.max, updatedAt = now }
end

-- Restarts the clock without draining (the player was offline or on the map).
function Survival.resume(state: State, now: number): State
	return { hunger = state.hunger, thirst = state.thirst, updatedAt = now }
end

-- What a respawn sets (Tuning.survival's respawn values).
export type RespawnConfig = { respawnHealth: number, respawnHunger: number, respawnThirst: number }

--[[
	The meters and health after a death (the flow review's F-05): exactly the respawn
	values, whatever they were before. Dying never refills a meter past them, so resetting
	is not a meal, and a death at an empty meter still wakes with enough to eat or drink
	before it bites again.
]]
function Survival.respawn(config: RespawnConfig, now: number): (State, number)
	return { hunger = config.respawnHunger, thirst = config.respawnThirst, updatedAt = now }, config.respawnHealth
end

-- Seconds within `elapsed` that a meter starting at `value` and draining at
-- `rate` spends at or below `level`.
local function secondsAtOrBelow(value: number, rate: number, elapsed: number, level: number): number
	if value <= level then
		return elapsed
	end
	if rate <= 0 then
		return 0
	end
	return math.max(0, elapsed - (value - level) / rate)
end

local function drain(value: number, meter: MeterConfig, elapsed: number): (number, number)
	local damage = 0
	for _, threshold in meter.thresholds do
		damage += secondsAtOrBelow(value, meter.decayPerSecond, elapsed, threshold.atOrBelow) * threshold.damagePerSecond
	end
	return math.max(0, value - meter.decayPerSecond * elapsed), damage
end

--[[
	Drains both meters up to `now`. Returns the new state and the damage taken
	from thresholds over the interval. A clock that reads earlier than
	`updatedAt` drains nothing.
]]
function Survival.advance(state: State, now: number, config: Config): (State, number)
	local elapsed = math.max(0, now - state.updatedAt)
	local hunger, hungerDamage = drain(state.hunger, config.hunger, elapsed)
	local thirst, thirstDamage = drain(state.thirst, config.thirst, elapsed)
	return { hunger = hunger, thirst = thirst, updatedAt = math.max(now, state.updatedAt) }, hungerDamage + thirstDamage
end

--[[
	Drains up to `now`, then applies a food or drink effect. Meters clamp to
	[0, max]; the excess is lost.
]]
function Survival.consume(state: State, now: number, config: Config, effect: Effect): ConsumeResult
	local current, damage = Survival.advance(state, now, config)
	local hunger = math.clamp(current.hunger + (effect.hunger or 0), 0, config.hunger.max)
	local thirst = math.clamp(current.thirst + (effect.thirst or 0), 0, config.thirst.max)
	return {
		state = { hunger = hunger, thirst = thirst, updatedAt = current.updatedAt },
		damage = damage,
		heal = effect.health or 0,
		energy = effect.energy or 0,
	}
end

-- Seconds of play until `meter` drains to `level` (0 if already there; math.huge
-- if it never drains). Useful for HUD warnings.
function Survival.secondsUntil(state: State, config: Config, meter: Meter, level: number): number
	local value = valueOf(state, meter)
	local rate = configOf(config, meter).decayPerSecond
	if value <= level then
		return 0
	end
	if rate <= 0 then
		return math.huge
	end
	return (value - level) / rate
end

local function meterDamagePerSecond(value: number, meter: MeterConfig): number
	local total = 0
	for _, threshold in meter.thresholds do
		if value <= threshold.atOrBelow then
			total += threshold.damagePerSecond
		end
	end
	return total
end

-- The total damage per second at the current meter values.
function Survival.damagePerSecond(state: State, config: Config): number
	return meterDamagePerSecond(state.hunger, config.hunger) + meterDamagePerSecond(state.thirst, config.thirst)
end

return Survival
