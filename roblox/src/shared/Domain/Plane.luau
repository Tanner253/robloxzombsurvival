--!strict
--[[
	Plane: 2D math on the ground plane for the top-down Fog Run modules (Combat,
	Noise, HollowAI, Flare, Extraction). Pure; points are plain { x, z } tables so
	Lune can test them.

	Yaw is the heading in radians with direction(yaw) = (sin yaw, cos yaw): yaw 0
	faces +Z, yaw pi/2 faces +X. Services convert a Roblox vector with
	`math.atan2(v.X, v.Z)`.
]]

local Plane = {}

export type Point = { x: number, z: number }

function Plane.point(x: number, z: number): Point
	return { x = x, z = z }
end

function Plane.distance(a: Point, b: Point): number
	local dx, dz = b.x - a.x, b.z - a.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Unit vector for a heading.
function Plane.direction(yaw: number): Point
	return { x = math.sin(yaw), z = math.cos(yaw) }
end

-- Heading from `from` toward `to` (0 when they coincide).
function Plane.yawTo(from: Point, to: Point): number
	local dx, dz = to.x - from.x, to.z - from.z
	if dx == 0 and dz == 0 then
		return 0
	end
	return math.atan2(dx, dz)
end

-- The signed difference b - a, wrapped to [-pi, pi].
function Plane.angleDiff(a: number, b: number): number
	local diff = (b - a) % (2 * math.pi)
	if diff > math.pi then
		diff -= 2 * math.pi
	end
	return diff
end

-- `distance` studs from `origin` along `yaw`.
function Plane.offset(origin: Point, yaw: number, distance: number): Point
	local dir = Plane.direction(yaw)
	return { x = origin.x + dir.x * distance, z = origin.z + dir.z * distance }
end

-- A step of at most `step` studs from `from` toward `to` (lands on `to` when close).
function Plane.moveToward(from: Point, to: Point, step: number): Point
	local distance = Plane.distance(from, to)
	if distance <= step or distance == 0 then
		return { x = to.x, z = to.z }
	end
	local t = step / distance
	return { x = from.x + (to.x - from.x) * t, z = from.z + (to.z - from.z) * t }
end

--[[
	Whether a target of radius `targetRadius` centred at `target` is inside the arc
	of `arcDegrees` (full width) facing `yaw` from `origin`, within `range`.
]]
function Plane.inArc(
	origin: Point,
	yaw: number,
	target: Point,
	range: number,
	arcDegrees: number,
	targetRadius: number?
): boolean
	local radius = targetRadius or 0
	local distance = Plane.distance(origin, target)
	if distance > range + radius then
		return false
	end
	if distance <= radius then
		return true -- standing inside the target
	end
	local half = math.rad(arcDegrees) / 2
	-- The target's own width widens the arc a little at close range.
	local widen = math.asin(math.clamp(radius / distance, 0, 1))
	return math.abs(Plane.angleDiff(yaw, Plane.yawTo(origin, target))) <= half + widen
end

--[[
	Where a ray from `origin` heading `yaw` first meets the circle (`center`,
	`radius`), as a distance along the ray within `range`, or nil when it misses.
	A ray starting inside the circle hits at 0.
]]
function Plane.rayCircle(origin: Point, yaw: number, range: number, center: Point, radius: number): number?
	local dir = Plane.direction(yaw)
	local ox, oz = origin.x - center.x, origin.z - center.z
	local c = ox * ox + oz * oz - radius * radius
	if c <= 0 then
		return 0
	end
	local b = ox * dir.x + oz * dir.z
	if b > 0 then
		return nil -- pointing away
	end
	local discriminant = b * b - c
	if discriminant < 0 then
		return nil
	end
	local t = -b - math.sqrt(discriminant)
	if t > range then
		return nil
	end
	return t
end

return Plane
