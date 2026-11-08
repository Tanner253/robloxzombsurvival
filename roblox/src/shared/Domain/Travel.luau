--!strict
--[[
	Travel: getting to a Fog-map location (GAME_DESIGN.md "Structure").

	Run costs the location's Energy and takes a short, fixed time (a loading
	beat). Walk is free and takes the location's real walk time. A trip is a pair
	of timestamps, so a player can log out mid-walk and arrive while offline.

	Types.LocationDef satisfies Destination. Multipliers model buffs and perks
	(LDoE's VIP travel discount, the Walker skill); results round to the nearest
	whole point or second.
]]

local Energy = require("./Energy")

local Travel = {}

export type Mode = "run" | "walk"

export type Destination = {
	id: string,
	energyCost: number,
	walkSeconds: number,
	levelGate: number,
}

export type Config = {
	runSeconds: number, -- how long a Run takes, whatever the distance
	energyMultiplier: number?, -- e.g. 0.9 for a 10% discount
	walkMultiplier: number?, -- e.g. 0.85 for a 15% faster walk
}

export type Plan = {
	mode: Mode,
	energyCost: number,
	seconds: number,
}

export type Trip = {
	destinationId: string,
	mode: Mode,
	departedAt: number,
	arrivesAt: number,
	energySpent: number,
}

export type Context = {
	now: number,
	level: number,
	energy: Energy.State,
	energyConfig: Energy.Config,
	config: Config,
}

export type Options = {
	run: Plan,
	walk: Plan,
	canRun: boolean,
	runReadyIn: number, -- seconds of regeneration until a Run is affordable
	levelOk: boolean,
}

export type Reason = "level" | "energy"

local function round(value: number): number
	return math.max(0, math.floor(value + 0.5))
end

-- The cost and duration of going to `destination` in `mode`. A Run is never
-- slower than walking.
function Travel.plan(destination: Destination, mode: Mode, config: Config): Plan
	local walkSeconds = round(destination.walkSeconds * (config.walkMultiplier or 1))
	if mode == "run" then
		return {
			mode = "run",
			energyCost = round(destination.energyCost * (config.energyMultiplier or 1)),
			seconds = math.min(config.runSeconds, walkSeconds),
		}
	end
	return { mode = "walk", energyCost = 0, seconds = walkSeconds }
end

-- Both plans plus whether a Run is affordable now, for the location panel.
function Travel.options(destination: Destination, ctx: Context): Options
	local run = Travel.plan(destination, "run", ctx.config)
	return {
		run = run,
		walk = Travel.plan(destination, "walk", ctx.config),
		canRun = Energy.canSpend(ctx.energy, ctx.now, ctx.energyConfig, run.energyCost),
		runReadyIn = Energy.secondsUntil(ctx.energy, ctx.now, ctx.energyConfig, run.energyCost),
		levelOk = ctx.level >= destination.levelGate,
	}
end

--[[
	Starts a trip. Returns the trip and the new energy state, or nil, nil and a
	reason: "level" (below the location's level gate) or "energy" (cannot afford
	the Run).
]]
function Travel.start(destination: Destination, mode: Mode, ctx: Context): (Trip?, Energy.State?, Reason?)
	if ctx.level < destination.levelGate then
		return nil, nil, "level"
	end
	local plan = Travel.plan(destination, mode, ctx.config)
	local energy = Energy.spend(ctx.energy, ctx.now, ctx.energyConfig, plan.energyCost)
	if not energy then
		return nil, nil, "energy"
	end
	local trip: Trip = {
		destinationId = destination.id,
		mode = mode,
		departedAt = ctx.now,
		arrivesAt = ctx.now + plan.seconds,
		energySpent = plan.energyCost,
	}
	return trip, energy, nil
end

function Travel.hasArrived(trip: Trip, now: number): boolean
	return now >= trip.arrivesAt
end

function Travel.remaining(trip: Trip, now: number): number
	return math.max(0, trip.arrivesAt - now)
end

-- Progress from 0 to 1; a zero-length trip is complete.
function Travel.progress(trip: Trip, now: number): number
	local length = trip.arrivesAt - trip.departedAt
	if length <= 0 then
		return 1
	end
	return math.clamp((now - trip.departedAt) / length, 0, 1)
end

return Travel
