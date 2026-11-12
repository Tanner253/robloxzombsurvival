--!strict
--[[
	Travel: getting to a Fog-map location (GAME_DESIGN.md "Structure").

	Run costs the location's Energy and takes a short, fixed time (a loading
	beat). Walk is free and takes the location's real walk time. A trip is a pair
	of timestamps, so a player can log out mid-walk and arrive while offline: the profile
	keeps a Walk (saveWalk) and the next visit resumes it (resumeWalk, the flow review's F-36).

	Types.LocationDef satisfies Destination. Multipliers model buffs and perks
	(LDoE's VIP travel discount, the Walker skill); results round to the nearest
	whole point or second.
]]

local Types = require("../Types")
local Energy = require("./Energy")

local Travel = {}

export type Mode = "run" | "walk"

export type Destination = {
	id: string,
	energyCost: number,
	walkSeconds: number,
	levelGate: number,
	availability: Types.LocationAvailability?, -- rotating locations refuse trips while closed
	fogTier: number?, -- Dense and Black wait on their region gate (LDOE_PARITY #43)
}

export type Config = {
	runSeconds: number, -- how long a Run takes, whatever the distance
	energyMultiplier: number?, -- e.g. 0.9 for a 10% discount
	walkMultiplier: number?, -- e.g. 0.85 for a 15% faster walk
	reentryEnergyMultiplier: number?, -- Fog Runs: share of the Run cost to go back in for a bag
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
	reentry: boolean?, -- Fog Runs: going back into an open lobby for a dropped bag
}

export type Context = {
	now: number,
	level: number,
	energy: Energy.State,
	energyConfig: Energy.Config,
	config: Config,
	-- LDOE_PARITY #43 (all optional; left out, nothing is gated):
	gates: { Types.RegionGate }?, -- Tuning.regionGates
	repairedGates: { [string]: boolean }?, -- the player's repaired towers
	airdropPin: boolean?, -- the player has a live airdrop pin for an "airdrop" location
}

export type Options = {
	run: Plan,
	walk: Plan,
	canRun: boolean,
	runReadyIn: number, -- seconds of regeneration until a Run is affordable
	levelOk: boolean,
}

export type Reason = "level" | "energy" | "unavailable" | "tooLate" | "walkTooLate" | "gate"

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
	reason: "level" (below the location's level gate), "unavailable" (a rotating
	location that is closed now), "walkTooLate" (a Walk that would arrive after a
	rotating location closes) or "energy" (cannot afford the Run).
]]
function Travel.start(destination: Destination, mode: Mode, ctx: Context): (Trip?, Energy.State?, Reason?)
	if ctx.level < destination.levelGate then
		return nil, nil, "level"
	end
	local availability = destination.availability
	if availability and availability.kind == "airdrop" then
		if not ctx.airdropPin then
			return nil, nil, "unavailable"
		end
	elseif availability and not Travel.isAvailable(availability, ctx.now) then
		return nil, nil, "unavailable"
	end
	if mode == "walk" and Travel.walkTooLate(destination, ctx.config, ctx.now) then
		return nil, nil, "walkTooLate"
	end
	if
		destination.fogTier
		and ctx.gates
		and not Travel.gateOpen(destination.fogTier, ctx.gates, ctx.repairedGates or {})
	then
		return nil, nil, "gate"
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

-- Fog Runs (slice 2) --------------------------------------------------------------------

-- Whether a location is open now (rotating events open activeSeconds in every period;
-- an airdrop location answers through the player's pin, so it reads as closed here).
function Travel.isAvailable(availability: Types.LocationAvailability, now: number): boolean
	if availability.kind == "always" then
		return true
	elseif availability.kind == "airdrop" then
		return false
	end
	return (now - availability.offsetSeconds) % availability.periodSeconds < availability.activeSeconds
end

-- Seconds until a rotating location next opens or closes (the Fog map countdown);
-- math.huge for one that is always open (or opened by an airdrop pin).
function Travel.secondsUntilChange(availability: Types.LocationAvailability, now: number): number
	if availability.kind ~= "rotating" then
		return math.huge
	end
	local phase = (now - availability.offsetSeconds) % availability.periodSeconds
	if phase < availability.activeSeconds then
		return availability.activeSeconds - phase
	end
	return availability.periodSeconds - phase
end

--[[
	Going back into an open lobby for a dropped bag: a Run only (the lobby closes in
	minutes), at reentryEnergyMultiplier of the Run cost, rounded up and at least 1.
]]
function Travel.reentryPlan(destination: Destination, config: Config): Plan
	local run = Travel.plan(destination, "run", config)
	local multiplier = config.reentryEnergyMultiplier or 1
	local cost = if run.energyCost > 0 then math.max(1, math.ceil(run.energyCost * multiplier - 1e-9)) else 0
	return { mode = "run", energyCost = cost, seconds = run.seconds }
end

--[[
	Starts a re-entry trip. `lastArrival` is the latest moment the player may arrive
	(the lobby's re-entry cutoff). Returns the trip and new energy, or nil, nil and
	"tooLate" or "energy". The lobby itself checks the player died there.
]]
function Travel.startReentry(
	destination: Destination,
	ctx: Context,
	lastArrival: number
): (Trip?, Energy.State?, Reason?)
	local plan = Travel.reentryPlan(destination, ctx.config)
	if ctx.now + plan.seconds >= lastArrival then
		return nil, nil, "tooLate"
	end
	local energy = Energy.spend(ctx.energy, ctx.now, ctx.energyConfig, plan.energyCost)
	if not energy then
		return nil, nil, "energy"
	end
	return {
		destinationId = destination.id,
		mode = "run",
		departedAt = ctx.now,
		arrivesAt = ctx.now + plan.seconds,
		energySpent = plan.energyCost,
		reentry = true,
	},
		energy,
		nil
end

-- Whether a Walk started now would arrive before `deadline` (e.g. a rotating location closing).
function Travel.walkArrivesBefore(destination: Destination, config: Config, now: number, deadline: number): boolean
	return now + Travel.plan(destination, "walk", config).seconds < deadline
end

-- Whether a Walk to an open rotating location would arrive after it closes.
function Travel.walkTooLate(destination: Destination, config: Config, now: number): boolean
	local availability = destination.availability
	if availability == nil or availability.kind ~= "rotating" or not Travel.isAvailable(availability, now) then
		return false
	end
	local closes = now + Travel.secondsUntilChange(availability, now)
	return not Travel.walkArrivesBefore(destination, config, now, closes)
end

--[[
	Turning back: a Run still loading refunds its Energy (as does a failed teleport);
	a Walk costs nothing to abandon. Returns the Energy to give back.
]]
function Travel.cancelRefund(trip: Trip, now: number): number
	if trip.mode == "run" and now < trip.arrivesAt then
		return trip.energySpent
	end
	return 0
end

-- LDOE_PARITY #43: region gates and the Walk "Hurry" --------------------------------------

-- The tower a fog tier waits on, if any.
function Travel.gateFor(fogTier: number, gates: { Types.RegionGate }): Types.RegionGate?
	for _, gate in gates do
		if gate.fogTier == fogTier then
			return gate
		end
	end
	return nil
end

-- Whether a fog tier is open: no tower, or its tower is repaired.
function Travel.gateOpen(fogTier: number, gates: { Types.RegionGate }, repaired: { [string]: boolean }): boolean
	local gate = Travel.gateFor(fogTier, gates)
	return gate == nil or repaired[gate.id] == true
end

-- Energy to finish a Walk now: every started minute left costs perMinute.
function Travel.hurryCost(trip: Trip, now: number, perMinute: number): number
	if trip.mode ~= "walk" then
		return 0
	end
	return math.ceil(Travel.remaining(trip, now) / 60 - 1e-9) * perMinute
end

--[[
	"Hurry" on a Walk: pays hurryCost and arrives now. Returns the new trip and
	energy, or nil, nil and "energy".
]]
function Travel.hurry(trip: Trip, ctx: Context, perMinute: number): (Trip?, Energy.State?, Reason?)
	local cost = Travel.hurryCost(trip, ctx.now, perMinute)
	local energy = Energy.spend(ctx.energy, ctx.now, ctx.energyConfig, cost)
	if energy == nil then
		return nil, nil, "energy"
	end
	local hurried = table.clone(trip)
	hurried.arrivesAt = math.min(trip.arrivesAt, ctx.now)
	hurried.energySpent += cost
	return hurried, energy, nil
end

-- Saving a Walk (the flow review's F-36) -----------------------------------------------------

export type SavedWalk = { locationId: string, departedAt: number, arrivesAt: number, energySpent: number }

-- What the profile keeps of a trip: a Walk only (a Run arrives in seconds, a re-entry is
-- tied to its lobby), so leaving the game mid-walk doesn't end it. Nil for anything else.
function Travel.saveWalk(trip: Trip): SavedWalk?
	if trip.mode ~= "walk" or trip.reentry then
		return nil
	end
	return {
		locationId = trip.destinationId,
		departedAt = trip.departedAt,
		arrivesAt = trip.arrivesAt,
		energySpent = trip.energySpent,
	}
end

-- The trip a saved Walk resumes as on the next visit (arrived already if the time passed
-- offline), or nil for a malformed save or a place that no longer exists.
function Travel.resumeWalk(saved: any, exists: (locationId: string) -> boolean): Trip?
	if type(saved) ~= "table" or type(saved.locationId) ~= "string" or not exists(saved.locationId) then
		return nil
	end
	if
		type(saved.departedAt) ~= "number"
		or type(saved.arrivesAt) ~= "number"
		or saved.arrivesAt < saved.departedAt
	then
		return nil
	end
	return {
		destinationId = saved.locationId,
		mode = "walk",
		departedAt = saved.departedAt,
		arrivesAt = saved.arrivesAt,
		energySpent = if type(saved.energySpent) == "number" then saved.energySpent else 0,
	}
end

return Travel
