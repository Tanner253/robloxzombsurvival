--!strict
--[[
	MapData: a map's picture as data (PLAYER_EXPERIENCE_CHECKLIST 8.11), shared by the
	minimap, the full-screen map and whoever supplies a map: the Neighbourhood is built
	from Tuning (Domain/NeighbourhoodMap), the Fog Run locations come from Data/Maps
	(docs/MINIMAP_FORMAT.md). Pure.

	Coordinates are map-local studs on the ground plane: +X east, +Z south (north is -Z),
	from the map's origin (the World folder's Origin attribute at home, the run map
	folder's Origin on a Fog Run). A yaw is in degrees, Roblox's: a footprint turned by
	CFrame.Angles(0, math.rad(yaw), 0).

	Also the radar's math: world offsets to minimap pixels with the camera's view up,
	the heading of the player arrow, pinning off-radar markers to the rim, easing, the
	full map's fit, and the bucket grid the background is split into so only the part
	near the view is drawn.
]]

local MapData = {}

MapData.FORMAT = 1

export type Point = { x: number, z: number }
export type Bounds = { x0: number, z0: number, x1: number, z1: number }

-- What a patch of ground is (how it's painted).
export type ZoneKind =
	"grass" -- living grass (the painted forest-floor texture)
	| "meadow" -- pale open grass
	| "dry" -- dead, dry grass (toward the fog)
	| "earth" -- trodden earth (plot pads, yards)
	| "mud" -- wet worn ground
	| "plaza" -- a trodden square
	| "yard" -- a fenced yard
	| "rock" -- bare rock, quarry floor
	| "sand"
	| "water" -- ponds, lakes, flooded pits
	| "forest" -- woods: painted tree clusters fill the shape
	| "fog" -- the fog past the edge

export type ShapeKind = "rect" | "ellipse" | "poly"

export type Zone = {
	kind: ZoneKind,
	shape: ShapeKind,
	-- rect and ellipse: the centre, the full width (along X) and depth (along Z), a yaw
	x: number?,
	z: number?,
	w: number?,
	d: number?,
	yaw: number?,
	round: number?, -- rect: the corner radius in studs
	points: { Point }?, -- poly: the outline (3 or more points)
	soft: boolean?, -- a painted, ragged edge instead of a crisp one
}

export type PathKind = "road" | "path" | "trail" | "river" | "rail"
export type Path = { kind: PathKind, width: number, points: { Point } }

export type BuildingKind = "house" | "barn" | "shed" | "stall" | "ruin" | "tent" | "container" | "tower"
-- A footprint: a rotated rectangle (centre, width along X, depth along Z before the yaw).
export type Building = {
	kind: BuildingKind?,
	x: number,
	z: number,
	w: number,
	d: number,
	yaw: number?,
	label: string?,
}

export type FenceKind = "fence" | "wall" | "palisade" | "rail"
export type Fence = { kind: FenceKind, points: { Point } }

export type PointKind = "exit" | "trailhead" | "poi" | "plot" | "fire" | "npc" | "spawn"
-- A named point. Exits and the Trailhead are pinned to the minimap's rim when off it.
export type MapPoint = {
	id: string,
	kind: PointKind,
	x: number,
	z: number,
	label: string?,
	glyph: string?, -- an Art.glyphs name for its icon (npc, poi)
}

export type Map = {
	format: number, -- MapData.FORMAT
	id: string, -- "neighbourhood" or a location id ("loc.pine_hollow")
	name: string,
	bounds: Bounds, -- the drawn area: the playable area plus its surroundings
	play: Bounds?, -- the playable area; past it lies `edge`
	ground: ZoneKind, -- under everything
	edge: ZoneKind?, -- painted past `play` (fog, forest, dry)
	zones: { Zone }, -- drawn in order, later on top
	paths: { Path },
	buildings: { Building },
	fences: { Fence },
	trees: { Point }?, -- single trees (canopies), for maps that place them one by one
	points: { MapPoint },
}

local ZONE_KINDS: { [string]: boolean } = {
	grass = true,
	meadow = true,
	dry = true,
	earth = true,
	mud = true,
	plaza = true,
	yard = true,
	rock = true,
	sand = true,
	water = true,
	forest = true,
	fog = true,
}
local PATH_KINDS: { [string]: boolean } = { road = true, path = true, trail = true, river = true, rail = true }
local BUILDING_KINDS: { [string]: boolean } = {
	house = true,
	barn = true,
	shed = true,
	stall = true,
	ruin = true,
	tent = true,
	container = true,
	tower = true,
}
local FENCE_KINDS: { [string]: boolean } = { fence = true, wall = true, palisade = true, rail = true }
local POINT_KINDS: { [string]: boolean } =
	{ exit = true, trailhead = true, poi = true, plot = true, fire = true, npc = true, spawn = true }

MapData.ZONE_KINDS = ZONE_KINDS
MapData.PATH_KINDS = PATH_KINDS
MapData.POINT_KINDS = POINT_KINDS

-- Validation ---------------------------------------------------------------------------------------

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function validPoint(point: any): boolean
	return type(point) == "table" and finite(point.x) and finite(point.z)
end

local function validBounds(bounds: any): boolean
	return type(bounds) == "table"
		and finite(bounds.x0)
		and finite(bounds.z0)
		and finite(bounds.x1)
		and finite(bounds.z1)
		and bounds.x0 < bounds.x1
		and bounds.z0 < bounds.z1
end

local function validPoints(points: any, least: number): boolean
	if type(points) ~= "table" or #points < least then
		return false
	end
	for _, point in points do
		if not validPoint(point) then
			return false
		end
	end
	return true
end

local function validZone(zone: any): string?
	if type(zone) ~= "table" or not ZONE_KINDS[zone.kind] then
		return "kind"
	end
	if zone.shape == "rect" or zone.shape == "ellipse" then
		if not (finite(zone.x) and finite(zone.z) and finite(zone.w) and finite(zone.d)) then
			return "x, z, w, d"
		end
		if zone.w <= 0 or zone.d <= 0 then
			return "size"
		end
		if zone.yaw ~= nil and not finite(zone.yaw) then
			return "yaw"
		end
		return nil
	elseif zone.shape == "poly" then
		return if validPoints(zone.points, 3) then nil else "points"
	end
	return "shape"
end

--[[
	Checks a map against the format. Returns true, or false and the first problem
	("zones[3]: size"), so a supplier sees exactly what to fix.
]]
function MapData.validate(map: any): (boolean, string?)
	if type(map) ~= "table" then
		return false, "not a table"
	end
	if map.format ~= MapData.FORMAT then
		return false, `format must be {MapData.FORMAT}`
	end
	if type(map.id) ~= "string" or map.id == "" or type(map.name) ~= "string" then
		return false, "id and name"
	end
	if not validBounds(map.bounds) then
		return false, "bounds"
	end
	if map.play ~= nil and not validBounds(map.play) then
		return false, "play"
	end
	if not ZONE_KINDS[map.ground] or (map.edge ~= nil and not ZONE_KINDS[map.edge]) then
		return false, "ground or edge"
	end
	for _, list in { "zones", "paths", "buildings", "fences", "points" } do
		if type(map[list]) ~= "table" then
			return false, `{list} missing`
		end
	end
	for index, zone in map.zones do
		local problem = validZone(zone)
		if problem then
			return false, `zones[{index}]: {problem}`
		end
	end
	for index, path in map.paths do
		if type(path) ~= "table" or not PATH_KINDS[path.kind] then
			return false, `paths[{index}]: kind`
		end
		if not finite(path.width) or path.width <= 0 then
			return false, `paths[{index}]: width`
		end
		if not validPoints(path.points, 2) then
			return false, `paths[{index}]: points`
		end
	end
	for index, building in map.buildings do
		if type(building) ~= "table" or (building.kind ~= nil and not BUILDING_KINDS[building.kind]) then
			return false, `buildings[{index}]: kind`
		end
		if not (finite(building.x) and finite(building.z) and finite(building.w) and finite(building.d)) then
			return false, `buildings[{index}]: x, z, w, d`
		end
		if building.w <= 0 or building.d <= 0 then
			return false, `buildings[{index}]: size`
		end
	end
	for index, fence in map.fences do
		if type(fence) ~= "table" or not FENCE_KINDS[fence.kind] then
			return false, `fences[{index}]: kind`
		end
		if not validPoints(fence.points, 2) then
			return false, `fences[{index}]: points`
		end
	end
	if map.trees ~= nil and not validPoints(map.trees, 0) then
		return false, "trees"
	end
	local ids: { [string]: boolean } = {}
	for index, point in map.points do
		if type(point) ~= "table" or not POINT_KINDS[point.kind] or not validPoint(point) then
			return false, `points[{index}]: kind, x, z`
		end
		if type(point.id) ~= "string" or ids[point.id] then
			return false, `points[{index}]: id`
		end
		ids[point.id] = true
	end
	return true, nil
end

-- Geometry ------------------------------------------------------------------------------------------

-- The axis-aligned box a turned w x d rectangle covers.
function MapData.rectBounds(x: number, z: number, w: number, d: number, yaw: number?): Bounds
	local turn = math.rad(yaw or 0)
	local c, s = math.abs(math.cos(turn)), math.abs(math.sin(turn))
	local hx, hz = (w * c + d * s) / 2, (w * s + d * c) / 2
	return { x0 = x - hx, z0 = z - hz, x1 = x + hx, z1 = z + hz }
end

function MapData.pointsBounds(points: { Point }, pad: number?): Bounds
	local margin = pad or 0
	local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
	for _, point in points do
		x0, z0 = math.min(x0, point.x), math.min(z0, point.z)
		x1, z1 = math.max(x1, point.x), math.max(z1, point.z)
	end
	return { x0 = x0 - margin, z0 = z0 - margin, x1 = x1 + margin, z1 = z1 + margin }
end

function MapData.zoneBounds(zone: Zone): Bounds
	if zone.shape == "poly" then
		return MapData.pointsBounds(zone.points or {})
	end
	return MapData.rectBounds(zone.x or 0, zone.z or 0, zone.w or 0, zone.d or 0, zone.yaw)
end

-- A copy of `map` with `extra` buildings, points and trees added (features learned from
-- the world at runtime, such as Haven's stalls).
function MapData.with(map: Map, extra: { buildings: { Building }?, points: { MapPoint }?, trees: { Point }? }): Map
	local copy = table.clone(map)
	copy.buildings = table.clone(map.buildings)
	copy.points = table.clone(map.points)
	copy.trees = if map.trees then table.clone(map.trees) else {}
	local trees = copy.trees :: { Point }
	if extra.buildings then
		for _, building in extra.buildings do
			table.insert(copy.buildings, building)
		end
	end
	if extra.points then
		for _, point in extra.points do
			table.insert(copy.points, point)
		end
	end
	if extra.trees then
		for _, tree in extra.trees do
			table.insert(trees, tree)
		end
	end
	return copy
end

-- The radar's projection -------------------------------------------------------------------------------

--[[
	A world offset (dx, dz) from the viewer to minimap pixels from its centre (x right,
	y down), turned so the camera's view direction is up. `yaw` is the camera's yaw in
	radians (CFrame.Angles(0, yaw, 0)); `scale` is pixels per stud. Yaw 0 is north up.
]]
function MapData.project(dx: number, dz: number, yaw: number, scale: number): (number, number)
	local c, s = math.cos(yaw), math.sin(yaw)
	return (dx * c - dz * s) * scale, (dx * s + dz * c) * scale
end

-- The inverse of `project`: minimap pixels from the centre back to a world offset.
function MapData.unproject(sx: number, sy: number, yaw: number, scale: number): (number, number)
	local c, s = math.cos(yaw), math.sin(yaw)
	local x, y = sx / scale, sy / scale
	return x * c + y * s, -x * s + y * c
end

-- The GUI rotation (degrees, clockwise) that turns the world-aligned map picture (x east,
-- y south) the way `project` does.
function MapData.mapRotation(yaw: number): number
	return math.deg(yaw)
end

-- The GUI rotation (degrees) of an up-pointing arrow for a facing (lookX, lookZ).
function MapData.heading(lookX: number, lookZ: number, yaw: number): number
	local sx, sy = MapData.project(lookX, lookZ, yaw, 1)
	return math.deg(math.atan2(sx, -sy))
end

--[[
	Keeps a marker on the radar: inside `radius` it stays where it is (inside = true);
	outside it is pulled in along its direction to sit on the rim (inside = false).
]]
function MapData.rim(sx: number, sy: number, radius: number): (number, number, boolean)
	local distance = math.sqrt(sx * sx + sy * sy)
	if distance <= radius then
		return sx, sy, true
	end
	local k = radius / distance
	return sx * k, sy * k, false
end

-- `current` moved toward `target` (degrees) the short way round by `alpha` (0..1).
function MapData.easeAngle(current: number, target: number, alpha: number): number
	local diff = (target - current + 180) % 360 - 180
	return current + diff * alpha
end

-- The share of the way to close this frame for exponential easing at `rate` per second.
function MapData.ease(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

-- A zoom step: the radar's reach (studs) after `notches` of the wheel (positive zooms
-- in), clamped to [least, most].
function MapData.zoomBy(reach: number, notches: number, least: number, most: number): number
	return math.clamp(reach * (0.85 ^ notches), least, most)
end

--[[
	Fits `bounds` into a width x height area with `pad` pixels round it, north up: the
	scale (pixels per stud) and the pixel offset of the bounds' (x0, z0) corner.
]]
function MapData.fit(bounds: Bounds, width: number, height: number, pad: number): (number, number, number)
	local spanX, spanZ = bounds.x1 - bounds.x0, bounds.z1 - bounds.z0
	local scale = math.min((width - pad * 2) / spanX, (height - pad * 2) / spanZ)
	return scale, (width - spanX * scale) / 2, (height - spanZ * scale) / 2
end

-- The background's bucket grid -------------------------------------------------------------------------

-- The background is split into square buckets; only buckets near the view are drawn.
MapData.BUCKET = 96

-- The bucket a feature belongs in, or nil for one too big for a bucket (always drawn).
function MapData.bucketOf(bounds: Bounds, size: number): string?
	if bounds.x1 - bounds.x0 > size * 1.5 or bounds.z1 - bounds.z0 > size * 1.5 then
		return nil
	end
	local cx, cz = (bounds.x0 + bounds.x1) / 2, (bounds.z0 + bounds.z1) / 2
	return `{math.floor(cx / size)}:{math.floor(cz / size)}`
end

-- Every bucket whose features can reach within `radius` of (x, z).
function MapData.bucketsNear(x: number, z: number, radius: number, size: number): { [string]: boolean }
	local reach = radius + size * 1.5
	local set: { [string]: boolean } = {}
	for ix = math.floor((x - reach) / size), math.floor((x + reach) / size) do
		for iz = math.floor((z - reach) / size), math.floor((z + reach) / size) do
			set[`{ix}:{iz}`] = true
		end
	end
	return set
end

return MapData
