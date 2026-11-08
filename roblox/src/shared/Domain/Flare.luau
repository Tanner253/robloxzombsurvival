--!strict
--[[
	Flare: light as a weapon (GAME_DESIGN "Light. Flares and fire are weapons";
	checklist 13.8). Pure.

	A flare lands, burns for `seconds` and lights `lightRadius`. Its light exposure
	(0..1) is full inside `fleeRadius` and fades to nothing at the light's edge; it
	dims over the last FADE_SECONDS. A Hollow flees when the exposure it stands in
	reaches its own lightFear (Data/Enemies), so a flare's core turns even a Runner
	while a Shambler backs off from its glow. A flare that hits a Hollow directly
	also sets it burning: burnDps for burnSeconds.

	Other light (the Hearth, torches) can feed HollowAI the same exposure value.
]]

local Types = require("../Types")
local Plane = require("./Plane")

local Flare = {}

Flare.FADE_SECONDS = 2

export type Flare = {
	id: number,
	position: Plane.Point,
	firedAt: number,
	expiresAt: number,
	stats: Types.FlareStats,
	ownerId: string?,
}

export type Burn = {
	dps: number,
	endsAt: number,
}

function Flare.new(id: number, stats: Types.FlareStats, position: Plane.Point, now: number, ownerId: string?): Flare
	return {
		id = id,
		position = { x = position.x, z = position.z },
		firedAt = now,
		expiresAt = now + stats.seconds,
		stats = stats,
		ownerId = ownerId,
	}
end

function Flare.isLit(flare: Flare, now: number): boolean
	return now >= flare.firedAt and now < flare.expiresAt
end

-- How strongly this flare lights `point` now, 0..1.
function Flare.exposure(flare: Flare, point: Plane.Point, now: number): number
	if not Flare.isLit(flare, now) then
		return 0
	end
	local stats = flare.stats
	local distance = Plane.distance(flare.position, point)
	if distance >= stats.lightRadius then
		return 0
	end
	local value = 1
	if distance > stats.fleeRadius then
		value = 1 - (distance - stats.fleeRadius) / (stats.lightRadius - stats.fleeRadius)
	end
	local left = flare.expiresAt - now
	if left < Flare.FADE_SECONDS then
		value *= left / Flare.FADE_SECONDS
	end
	return value
end

-- The brightest flare light at `point`: its exposure and where it comes from.
function Flare.strongest(flares: { Flare }, point: Plane.Point, now: number): (number, Plane.Point?)
	local best, source = 0, nil
	for _, flare in flares do
		local value = Flare.exposure(flare, point, now)
		if value > best then
			best, source = value, flare.position
		end
	end
	return best, source
end

-- Whether a point is inside the flare's flee radius (for the HUD and debug draws).
function Flare.inFleeRadius(flare: Flare, point: Plane.Point, now: number): boolean
	return Flare.isLit(flare, now) and Plane.distance(flare.position, point) <= flare.stats.fleeRadius
end

-- Flares still burning.
function Flare.prune(flares: { Flare }, now: number): { Flare }
	local live: { Flare } = {}
	for _, flare in flares do
		if now < flare.expiresAt then
			table.insert(live, flare)
		end
	end
	return live
end

-- A direct hit sets the target burning; a new burn replaces a weaker or shorter one.
function Flare.ignite(stats: Types.FlareStats, now: number, current: Burn?): Burn?
	if stats.burnDps <= 0 or stats.burnSeconds <= 0 then
		return current
	end
	local burn: Burn = { dps = stats.burnDps, endsAt = now + stats.burnSeconds }
	if current and current.dps >= burn.dps and current.endsAt >= burn.endsAt then
		return current
	end
	return burn
end

-- Burn damage dealt between `from` and `to` (a tick), 0 once it has burnt out.
function Flare.burnDamage(burn: Burn, from: number, to: number): number
	local seconds = math.max(0, math.min(to, burn.endsAt) - from)
	return burn.dps * seconds
end

return Flare
