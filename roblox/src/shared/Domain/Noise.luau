--!strict
--[[
	Noise: what the Hollow hear (GAME_DESIGN "Combat and the arsenal": guns are a
	push-your-luck choice; checklist 13.7).

	Every loud action emits an event with a radius: each gun its own
	(FirearmStats.noiseRadius), melee, bows, sprint footsteps, searching and the
	bloater burst from Tuning.noise. An event shrinks linearly to nothing over
	decaySeconds. A Hollow hears it while its distance is within the shrinking
	radius times its own `hearing`; the loudest margin wins, so a gunshot pulls
	every Hollow in range toward one spot and packs form around the noise.

	Pure; positions are Plane points.
]]

local Types = require("../Types")
local Plane = require("./Plane")

local Noise = {}

export type Config = Types.NoiseTuning
export type Kind = "gunshot" | "melee" | "bow" | "sprint" | "search" | "bloaterBurst" | "flare" | "walk"

export type Event = {
	id: number,
	kind: Kind,
	position: Plane.Point,
	radius: number,
	at: number,
	sourceId: string?, -- who made it, e.g. "u123" or "h4"
}

export type Listener = {
	id: string,
	position: Plane.Point,
	hearing: number,
}

-- The radius an action emits. Gunshots need the weapon's firearm stats.
function Noise.radius(kind: Kind, config: Config, firearm: Types.FirearmStats?): number
	if kind == "gunshot" then
		assert(firearm, "a gunshot needs the gun's firearm stats")
		return firearm.noiseRadius
	elseif kind == "melee" then
		return config.melee
	elseif kind == "bow" then
		return config.bow
	elseif kind == "sprint" then
		return config.sprint
	elseif kind == "search" then
		return config.search
	elseif kind == "bloaterBurst" then
		return config.bloaterBurst
	elseif kind == "flare" then
		return config.flare
	end
	return 0 -- walking is silent
end

--[[
	LDOE_PARITY #44: a sneaking player's own noise is quieter. Melee and footsteps
	scale by the sneak noiseMultiplier; guns, bows and everything else stay as loud.
]]
function Noise.sneaky(kind: Kind, radius: number, sneak: Types.SneakTuning): number
	if kind == "melee" or kind == "sprint" or kind == "walk" or kind == "search" then
		return radius * sneak.noiseMultiplier
	end
	return radius
end

function Noise.new(
	id: number,
	kind: Kind,
	position: Plane.Point,
	now: number,
	config: Config,
	firearm: Types.FirearmStats?,
	sourceId: string?,
	sneak: Types.SneakTuning? -- set when the maker is sneaking
): Event
	local radius = Noise.radius(kind, config, firearm)
	return {
		id = id,
		kind = kind,
		position = { x = position.x, z = position.z },
		radius = if sneak then Noise.sneaky(kind, radius, sneak) else radius,
		at = now,
		sourceId = sourceId,
	}
end

-- The radius left after decay (0 once it has died away).
function Noise.effectiveRadius(event: Event, now: number, config: Config): number
	local age = now - event.at
	if age < 0 or age >= config.decaySeconds then
		return 0
	end
	return event.radius * (1 - age / config.decaySeconds)
end

-- Events still audible at `now`, in emission order.
function Noise.prune(events: { Event }, now: number, config: Config): { Event }
	local live: { Event } = {}
	for _, event in events do
		if Noise.effectiveRadius(event, now, config) > 0 then
			table.insert(live, event)
		end
	end
	return live
end

-- How far inside the event's reach the listener is (<= 0: not heard).
function Noise.margin(event: Event, listener: Listener, now: number, config: Config): number
	return Noise.effectiveRadius(event, now, config) * listener.hearing
		- Plane.distance(event.position, listener.position)
end

-- The event this listener hears best, or nil.
function Noise.loudest(events: { Event }, listener: Listener, now: number, config: Config): Event?
	local best: Event? = nil
	local bestMargin = 0
	for _, event in events do
		local margin = Noise.margin(event, listener, now, config)
		if margin > bestMargin then
			best, bestMargin = event, margin
		end
	end
	return best
end

-- The IDs of every listener that hears `event` (the Hollow it pulls), sorted.
function Noise.heardBy(event: Event, listeners: { Listener }, now: number, config: Config): { string }
	local ids: { string } = {}
	for _, listener in listeners do
		if Noise.margin(event, listener, now, config) > 0 then
			table.insert(ids, listener.id)
		end
	end
	table.sort(ids)
	return ids
end

return Noise
