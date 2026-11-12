--!strict
--[[
	Throw: grenades and molotovs (2.0 batch 5). Pure math, shared by the server (which decides
	every hit, Services/Throwables) and the client's aim preview (Controllers/Throwing), so the
	arc the player sees is the arc the server flies.

	- `landing`: the aim, pulled inside the throwable's [minRange, range] ring around the thrower.
	- `flightSeconds` and `at`: the flight. The throwable moves along the ground at `flightSpeed`
	  and rises in a parabola over the straight line, highest at mid-flight: `apexFor` studs,
	  the item's `apex` on a long throw and lower on a short one (batch 5 follow-up: a 12-stud
	  lob rose 9 studs over the ground and caught roof edges and overhangs, so it fell short of
	  the ring the preview showed).
	- `solid`: whether a part stops an arc. See-through volumes (markers, exit edges, trigger
	  boxes) don't; Util/ArcCast applies it on both the server and the client preview.
	- `points`: the arc sampled for the preview and for the server's wall checks.
	- `falloff` and `blastDamage`: a blast hits hardest at its centre, down to `edgeMultiplier`
	  at its radius, nothing past it.
	- `fire`: a molotov's area burns `burnSeconds`, a tick every `burnTickSeconds`, each tick
	  `burnDps * burnTickSeconds` to every Hollow inside.
	- `detonatesAt`: a blast goes off its fuse after the release (never before it lands); a fire
	  bursts on landing.
	- `canThrow`: one throw per `intervalSeconds`.

	Points are plain { x, y, z } tables (studs), so this runs under Lune as well as in Roblox.
]]

local Types = require("../Types")

local Throw = {}

export type Point = { x: number, y: number, z: number }
export type Fire = { ticks: number, perTick: number, tickSeconds: number }

local MIN_FLIGHT_SECONDS = 0.35
local DEFAULT_EDGE = 0.25
local APEX_BASE = 1 -- studs: the lowest lob
local APEX_PER_STUD = 0.3 -- the rise grows with the throw's length up to the item's apex
Throw.SEE_THROUGH = 0.9 -- a part this transparent or more never stops an arc

local function point(x: number, y: number, z: number): Point
	return { x = x, y = y, z = z }
end

local function flat(from: Point, to: Point): number
	local dx, dz = to.x - from.x, to.z - from.z
	return math.sqrt(dx * dx + dz * dz)
end

Throw.point = point
Throw.flatDistance = flat

-- The aim pulled inside the throwable's ring; straight ahead at minRange when aimed at the feet.
function Throw.landing(from: Point, aim: Point, stats: Types.ThrowStats, facingYaw: number?): Point
	local distance = flat(from, aim)
	if distance < 1e-6 then
		local yaw = facingYaw or 0
		return point(from.x + math.sin(yaw) * stats.minRange, aim.y, from.z + math.cos(yaw) * stats.minRange)
	end
	local clamped = math.clamp(distance, stats.minRange, stats.range)
	local scale = clamped / distance
	return point(from.x + (aim.x - from.x) * scale, aim.y, from.z + (aim.z - from.z) * scale)
end

function Throw.flightSeconds(from: Point, to: Point, stats: Types.ThrowStats): number
	return math.max(MIN_FLIGHT_SECONDS, flat(from, to) / stats.flightSpeed)
end

-- The arc's height over the straight line at mid-flight for a throw `distance` studs long.
function Throw.apexFor(stats: Types.ThrowStats, distance: number): number
	return math.min(stats.apex, APEX_BASE + APEX_PER_STUD * math.max(distance, 0))
end

function Throw.solid(transparency: number): boolean
	return transparency < Throw.SEE_THROUGH
end

-- Where it is `t` seconds into a flight of `flight` seconds (clamped to the flight).
function Throw.at(from: Point, to: Point, stats: Types.ThrowStats, flight: number, t: number): Point
	local s = if flight > 0 then math.clamp(t / flight, 0, 1) else 1
	local rise = 4 * Throw.apexFor(stats, flat(from, to)) * s * (1 - s)
	return point(from.x + (to.x - from.x) * s, from.y + (to.y - from.y) * s + rise, from.z + (to.z - from.z) * s)
end

-- The arc as `segments` + 1 points, the first at the hand and the last at the landing.
function Throw.points(from: Point, to: Point, stats: Types.ThrowStats, segments: number): { Point }
	local flight = Throw.flightSeconds(from, to, stats)
	local list: { Point } = {}
	for i = 0, segments do
		table.insert(list, Throw.at(from, to, stats, flight, flight * i / segments))
	end
	return list
end

-- The damage multiplier `distance` studs from the centre: 1 there, `edgeMultiplier` at the radius.
function Throw.falloff(stats: Types.ThrowStats, distance: number): number
	if distance > stats.radius then
		return 0
	end
	local edge = stats.edgeMultiplier or DEFAULT_EDGE
	return 1 + (edge - 1) * math.clamp(distance / stats.radius, 0, 1)
end

function Throw.blastDamage(stats: Types.ThrowStats, distance: number): number
	return (stats.damage or 0) * Throw.falloff(stats, distance)
end

-- How a fire burns: its tick count, the damage each tick, and the seconds between ticks.
function Throw.fire(stats: Types.ThrowStats): Fire
	local tick = stats.burnTickSeconds or 0.5
	local ticks = math.floor((stats.burnSeconds or 0) / tick + 1e-9)
	return { ticks = ticks, perTick = (stats.burnDps or 0) * tick, tickSeconds = tick }
end

-- Seconds after the release when it goes off: a blast on its fuse (it never bursts in the
-- air), a fire on landing.
function Throw.detonatesAfter(stats: Types.ThrowStats, flight: number): number
	if stats.kind == "blast" then
		return math.max(stats.fuseSeconds or 0, flight)
	end
	return flight
end

function Throw.canThrow(stats: Types.ThrowStats, lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= stats.intervalSeconds
end

-- The most one throw can deal to one Hollow (a fire: every tick on one that never leaves).
function Throw.maxDamage(stats: Types.ThrowStats): number
	if stats.kind == "blast" then
		return stats.damage or 0
	end
	local fire = Throw.fire(stats)
	return fire.ticks * fire.perTick
end

return Throw
