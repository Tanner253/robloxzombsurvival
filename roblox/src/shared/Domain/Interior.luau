--!strict
--[[
	Interior: is the survivor inside a building, and what of it fades (checklist 2.3,
	LDoE parity: walk into a house and its roof lifts away so the room reads clearly).

	Every building with a roof carries its footprint as data, written where it is built
	(FogRuns/Maps/Builder and ZoneDress, World/Haven, via World/Interiors): the floor's
	centre and height, the building's yaw, and the room's width, depth and roof height.
	The survivor is inside when their position, turned into the building's own frame,
	lies within the width and depth and between the floor and the roof.

	Hysteresis: you count as in once ENTER_INSET past the footprint's edge, and as out
	again only EXIT_PAD beyond it, so standing in a doorway never flickers the roof.

	What fades (Controllers/RoofFade does the easing):
	- the building you're in: its roof, upper parts and eave signs all but vanish
	  (ROOF_ALPHA), and its walls that face the camera turn to a ghost (WALL_ALPHA), so
	  the room reads like LDoE's open-topped interiors while its shape stays legible;
	- a roof that hides you from the camera while you're outside: a ghost (SHADE_ALPHA),
	  the same look as the wall occlusion fade.

	Pure: plain numbers in, plain answers out (tests/Interior.spec.luau).
]]

local Interior = {}

-- Tags and attributes (written by server/World/Interiors, read by Controllers/RoofFade).
Interior.TAG = "EO_Interior" -- the building: a Model carrying the two attributes below
Interior.ROOF_TAG = "EO_InteriorRoof" -- roof, upper floor, eave sign: a holder or a part
Interior.WALL_TAG = "EO_InteriorWall" -- a wall side, with a Facing attribute
Interior.FLOOR_ATTR = "InteriorFloor" -- CFrame: the floor's centre, turned by the yaw
Interior.SIZE_ATTR = "InteriorSize" -- Vector3: width (own X), roof height (Y), depth (own Z)
Interior.FACING_ATTR = "Facing" -- Vector3: a wall's outward normal, world space

Interior.ENTER_INSET = 0.3 -- studs past the footprint's edge before you count as in
Interior.EXIT_PAD = 1.5 -- studs beyond it before you count as out again
Interior.BELOW = 2 -- how far under the floor the survivor may stand and still count
Interior.NEAR = 70 -- studs: only buildings this close (plus their own size) are checked
Interior.FADE_SECONDS = 0.25 -- a full fade, either way
-- Not 1: the roof stays a hair short of gone, so it keeps shading the room in every
-- lighting mode (no sunlit floor inside a house at noon). CastShadow is left alone.
Interior.ROOF_ALPHA = 0.97
Interior.WALL_ALPHA = 0.6 -- the same ghost as the wall occlusion fade (Controllers/WorldFx)
Interior.SHADE_ALPHA = 0.6
Interior.FACING_MIN = 0.3 -- how squarely a wall must face the camera to fade

export type Footprint = {
	x: number, -- the floor's centre (world)
	y: number, -- the floor's top (world)
	z: number,
	yaw: number, -- radians about +Y, as CFrame.Angles(0, yaw, 0)
	width: number, -- along its own X
	depth: number, -- along its own Z
	height: number, -- floor to the underside of the roof
}

function Interior.footprint(
	x: number,
	y: number,
	z: number,
	yaw: number,
	width: number,
	depth: number,
	height: number
): Footprint
	return { x = x, y = y, z = z, yaw = yaw, width = width, depth = depth, height = height }
end

-- A world point in the footprint's own frame: (along its width, along its depth).
function Interior.toLocal(footprint: Footprint, x: number, z: number): (number, number)
	local dx, dz = x - footprint.x, z - footprint.z
	local c, s = math.cos(footprint.yaw), math.sin(footprint.yaw)
	return dx * c - dz * s, dx * s + dz * c
end

-- Within the footprint grown by `pad` studs on every side (a negative pad shrinks it
-- across the floor; the height range only ever grows), and between floor and roof.
function Interior.contains(footprint: Footprint, x: number, y: number, z: number, pad: number): boolean
	local lx, lz = Interior.toLocal(footprint, x, z)
	if math.abs(lx) > footprint.width / 2 + pad or math.abs(lz) > footprint.depth / 2 + pad then
		return false
	end
	local grow = math.max(pad, 0)
	return y >= footprint.y - Interior.BELOW - grow and y <= footprint.y + footprint.height + grow
end

-- Is the survivor in this building now, given whether they were a moment ago?
function Interior.isInside(footprint: Footprint, x: number, y: number, z: number, was: boolean): boolean
	return Interior.contains(footprint, x, y, z, if was then Interior.EXIT_PAD else -Interior.ENTER_INSET)
end

-- Which footprint of `list` the survivor is in (its index): the current one while they
-- are still inside it, else the smallest one they have walked into, else nil.
function Interior.pick(list: { Footprint }, x: number, y: number, z: number, current: number?): number?
	if current and list[current] and Interior.isInside(list[current], x, y, z, true) then
		return current
	end
	local best: number? = nil
	local bestArea = math.huge
	for index, footprint in list do
		local area = footprint.width * footprint.depth
		if area < bestArea and Interior.isInside(footprint, x, y, z, false) then
			best, bestArea = index, area
		end
	end
	return best
end

-- Whether the footprint lies within `radius` of the point (its corners count), for culling.
function Interior.near(footprint: Footprint, x: number, z: number, radius: number): boolean
	local reach = radius + math.sqrt(footprint.width ^ 2 + footprint.depth ^ 2) / 2
	local dx, dz = x - footprint.x, z - footprint.z
	return dx * dx + dz * dz <= reach * reach
end

-- Whether a wall with outward normal (nx, nz) faces a camera looking along (lookX, lookZ).
function Interior.facesCamera(nx: number, nz: number, lookX: number, lookZ: number): boolean
	local normal = math.sqrt(nx * nx + nz * nz)
	local look = math.sqrt(lookX * lookX + lookZ * lookZ)
	if normal < 1e-6 or look < 1e-6 then
		return false
	end
	return -(nx * lookX + nz * lookZ) / (normal * look) >= Interior.FACING_MIN
end

-- What a building's roof and camera-facing walls fade to: (roof, walls).
function Interior.targets(inside: boolean, shading: boolean): (number, number)
	if inside then
		return Interior.ROOF_ALPHA, Interior.WALL_ALPHA
	elseif shading then
		return Interior.SHADE_ALPHA, 0
	end
	return 0, 0
end

-- One easing step from `now` toward `target`: the whole 0..1 range takes FADE_SECONDS.
function Interior.step(now: number, target: number, dt: number): number
	local step = math.max(dt, 0) / Interior.FADE_SECONDS
	local diff = target - now
	if math.abs(diff) <= step then
		return target
	end
	return now + math.sign(diff) * step
end

return Interior
