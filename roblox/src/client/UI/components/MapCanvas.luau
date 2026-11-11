--!strict
--[[
	MapCanvas: a MapData map drawn once as composed UI, in the Fog map's illustrated style
	(its painted ground tiles, cloud and tree-cluster sprites; checklist 8.11). Shared by
	the minimap and the full-screen map.

	- One stud is one unit: the parent scales the picture (the minimap's UIScale, the full
	  map's fit). Its (0, 0) is the map bounds' (x0, z0) corner, x east, y south.
	- Layers, bottom up: the ground tile, the edge past the playable area, zones (earth,
	  water, rock, woods, fog...), paths, fences, buildings, single trees.
	- Within a layer, features small enough sit in buckets (MapData.BUCKET) named
	  "Q<ix>:<iz>", so the minimap can hide the ones far from its view; big ones sit in
	  the layer's "All" frame under them.
	- `Ground` re-renders only when the map changes; `Features` (outposts, plot nodes)
	  only when they do.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Art = require(ReplicatedStorage.Shared.Art)
local MapData = require(ReplicatedStorage.Shared.Domain.MapData)
local mark = require("../mark")

local e = React.createElement

local MapCanvas = {}

-- The illustrated palette (the Fog map's earth tones).
local ZONE_COLORS: { [string]: Color3 } = {
	grass = Color3.fromRGB(70, 92, 52),
	meadow = Color3.fromRGB(150, 146, 92),
	dry = Color3.fromRGB(138, 128, 88),
	earth = Color3.fromRGB(122, 100, 72),
	mud = Color3.fromRGB(92, 76, 58),
	plaza = Color3.fromRGB(134, 112, 82),
	yard = Color3.fromRGB(112, 96, 72),
	rock = Color3.fromRGB(110, 108, 102),
	sand = Color3.fromRGB(170, 152, 108),
	water = Color3.fromRGB(64, 98, 108),
	forest = Color3.fromRGB(38, 54, 36),
	fog = Color3.fromRGB(176, 184, 190),
}
local PATHS: { [string]: { outer: Color3, inner: Color3, core: number } } = {
	road = { outer = Color3.fromRGB(88, 72, 54), inner = Color3.fromRGB(146, 128, 98), core = 0.22 },
	path = { outer = Color3.fromRGB(104, 86, 62), inner = Color3.fromRGB(158, 136, 100), core = 0.5 },
	trail = { outer = Color3.fromRGB(104, 86, 62), inner = Color3.fromRGB(158, 136, 100), core = 0.5 },
	river = { outer = Color3.fromRGB(52, 70, 70), inner = Color3.fromRGB(92, 124, 130), core = 0.6 },
	rail = { outer = Color3.fromRGB(52, 48, 44), inner = Color3.fromRGB(120, 108, 92), core = 0.3 },
}
local ROOFS: { [string]: Color3 } = {
	house = Color3.fromRGB(104, 84, 68),
	barn = Color3.fromRGB(124, 70, 54),
	shed = Color3.fromRGB(104, 96, 84),
	stall = Color3.fromRGB(150, 120, 84),
	ruin = Color3.fromRGB(80, 74, 68),
	tent = Color3.fromRGB(128, 126, 100),
	container = Color3.fromRGB(84, 98, 104),
	tower = Color3.fromRGB(92, 86, 80),
}
local FENCES: { [string]: { color: Color3, width: number } } = {
	fence = { color = Color3.fromRGB(70, 54, 40), width = 1.4 },
	palisade = { color = Color3.fromRGB(62, 46, 32), width = 1.8 },
	wall = { color = Color3.fromRGB(96, 94, 90), width = 2 },
	rail = { color = Color3.fromRGB(110, 92, 70), width = 1 },
}
local OUTLINE = Color3.fromRGB(30, 26, 22)
local GROUND_SPRITES: { [string]: string } = { grass = "baseForest", meadow = "baseMeadow", dry = "baseMeadow" }
local TILE = 110 -- studs per ground tile
local TREE_SPRITES = { "trees1", "trees2", "trees3", "trees4" }

type Bucketed = { all: { [string]: any }, buckets: { [string]: { [string]: any } }, count: number }

local function bucketed(): Bucketed
	return { all = {}, buckets = {}, count = 0 }
end

-- Files one element under its bucket (or with the big ones).
local function put(into: Bucketed, bounds: MapData.Bounds, element: any)
	into.count += 1
	local key = MapData.bucketOf(bounds, MapData.BUCKET)
	if key == nil then
		into.all[`E{into.count}`] = element
		return
	end
	local bucket = into.buckets[key]
	if bucket == nil then
		bucket = {}
		into.buckets[key] = bucket
	end
	bucket[`E{into.count}`] = element
end

local function layer(order: number, from: Bucketed): any
	local children: { [string]: any } = {
		All = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, from.all),
	}
	for key, elements in from.buckets do
		children[`Q{key}`] =
			e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, elements)
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = order,
		ref = mark.backdrop,
	}, children)
end

local function sprite(name: string, x: number, z: number, w: number, d: number, extra: { [string]: any }?): any
	local props: { [string]: any } = {
		Size = UDim2.fromOffset(w, d),
		Position = UDim2.fromOffset(x, z),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = Art.fogMap.sprites[name] or "",
		ScaleType = Enum.ScaleType.Stretch,
	}
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return e("ImageLabel", props)
end

local function fill(kind: string): (Color3, string?)
	return ZONE_COLORS[kind] or ZONE_COLORS.earth, GROUND_SPRITES[kind]
end

-- A bar from a to b (canvas units) with round ends.
local function bar(ax: number, az: number, bx: number, bz: number, width: number, color: Color3, round: boolean): any
	local dx, dz = bx - ax, bz - az
	local length = math.sqrt(dx * dx + dz * dz)
	return e("Frame", {
		Size = UDim2.fromOffset(length + (if round then width else 0), width),
		Position = UDim2.fromOffset((ax + bx) / 2, (az + bz) / 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = math.deg(math.atan2(dz, dx)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, if round then { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) } else nil)
end

-- Zones --------------------------------------------------------------------------------------------

-- Bare-ground kinds get a faint grain (the meadow tile, washed in their colour).
local GRAINY: { [string]: boolean } = { earth = true, mud = true, plaza = true, yard = true, sand = true, rock = true }

--[[
	A filled shape. A crisp one is a flat paint (a tile texture for grass-like kinds). A
	soft one is painted: lumps of the Fog map's cloud sprite in the zone's colour, one over
	the middle and one toward each corner (or each end of an oval), over a grained core,
	so its edge is ragged like the ground it stands for.
]]
local function zoneShape(zone: MapData.Zone, ox: number, oz: number, seed: number): { any }
	local color, tile = fill(zone.kind)
	local x, z = (zone.x or 0) - ox, (zone.z or 0) - oz
	local w, d = zone.w or 0, zone.d or 0
	local rotation = -(zone.yaw or 0)
	local out: { any } = {}
	if zone.kind == "water" and zone.soft then
		table.insert(out, sprite("water", x, z, w * 1.12, d * 1.12, { Rotation = rotation }))
		return out
	end
	if zone.soft then
		local rng = Random.new(seed)
		local turn = math.rad(rotation)
		local c, s = math.cos(turn), math.sin(turn)
		local function lump(dx: number, dz: number, sw: number, sd: number)
			table.insert(
				out,
				sprite("fog", x + dx * c - dz * s, z + dx * s + dz * c, sw, sd, {
					Rotation = rotation + rng:NextNumber(-25, 25),
					ImageColor3 = color,
					ImageTransparency = 0.04,
				})
			)
		end
		lump(0, 0, w * 1.04, d * 1.04)
		if zone.shape == "ellipse" then
			-- Eight round the rim keep an oval round (four would make a cross).
			for step = 0, 7 do
				local angle = step * math.pi / 4
				lump(math.cos(angle) * w * 0.24, math.sin(angle) * d * 0.24, w * 0.56, d * 0.56)
			end
		else
			for _, corner in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
				lump(corner[1] * w * 0.27, corner[2] * d * 0.27, w * 0.62, d * 0.62)
			end
		end
	end
	local core = if zone.soft then 0.8 else 1
	local corner = if zone.shape == "ellipse"
		then UDim.new(1, 0)
		else UDim.new(0, math.min(zone.round or (if zone.soft then 10 else 0), math.min(w, d) / 2))
	local children: { [string]: any } = { Corner = e("UICorner", { CornerRadius = corner }) }
	local texture = tile or (if GRAINY[zone.kind] then "baseMeadow" else nil)
	if texture then
		children.Tile = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Art.fogMap.sprites[texture] or "",
			ImageColor3 = if tile then Color3.new(1, 1, 1) else color:Lerp(Color3.new(1, 1, 1), 0.3),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(TILE, TILE),
			ImageTransparency = if tile then 0.1 else 0.72,
		}, { Corner = e("UICorner", { CornerRadius = corner }) })
	end
	table.insert(
		out,
		e("Frame", {
			Size = UDim2.fromOffset(w * core, d * core),
			Position = UDim2.fromOffset(x, z),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BackgroundColor3 = color,
			BackgroundTransparency = if zone.soft then 0.25 else 0.05,
			BorderSizePixel = 0,
		}, children)
	)
	return out
end

-- A fog wash: opaque at the map's edge, fading toward its middle (no hard inner edge).
local function fogWash(zone: MapData.Zone, ox: number, oz: number, centre: Vector2): any
	local box = MapData.zoneBounds(zone)
	local dx = centre.X - (box.x0 + box.x1) / 2
	local dz = centre.Y - (box.z0 + box.z1) / 2
	local inward = if math.abs(dx) > math.abs(dz) then (if dx > 0 then 0 else 180) else (if dz > 0 then 90 else 270)
	return e("Frame", {
		Size = UDim2.fromOffset(box.x1 - box.x0, box.z1 - box.z0),
		Position = UDim2.fromOffset(box.x0 - ox, box.z0 - oz),
		BackgroundColor3 = ZONE_COLORS.fog,
		BorderSizePixel = 0,
	}, {
		Fade = e("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.6, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = inward,
		}),
	})
end

-- A polygon as horizontal strips (scanlines every STRIP studs).
local STRIP = 3
local function polygon(zone: MapData.Zone, ox: number, oz: number): { any }
	local points = zone.points or {}
	local color = fill(zone.kind)
	local box = MapData.pointsBounds(points)
	local out: { any } = {}
	local z = box.z0 + STRIP / 2
	while z < box.z1 do
		local crossings: { number } = {}
		for index = 1, #points do
			local a = points[index]
			local b = points[index % #points + 1]
			if (a.z <= z and b.z > z) or (b.z <= z and a.z > z) then
				table.insert(crossings, a.x + (z - a.z) / (b.z - a.z) * (b.x - a.x))
			end
		end
		table.sort(crossings)
		for index = 1, #crossings - 1, 2 do
			local x0, x1 = crossings[index], crossings[index + 1]
			table.insert(
				out,
				e("Frame", {
					Size = UDim2.fromOffset(x1 - x0, STRIP + 0.5),
					Position = UDim2.fromOffset((x0 + x1) / 2 - ox, z - oz),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
				})
			)
		end
		z += STRIP
	end
	return out
end

-- Woods: tree-cluster sprites scattered through the shape, the same every time.
local function woods(zone: MapData.Zone, ox: number, oz: number, into: Bucketed, seed: number)
	local box = MapData.zoneBounds(zone)
	local rng = Random.new(seed)
	local step = 24
	local x = box.x0 + step / 2
	while x < box.x1 do
		local z = box.z0 + step / 2
		while z < box.z1 do
			local px = x + rng:NextNumber(-step * 0.35, step * 0.35)
			local pz = z + rng:NextNumber(-step * 0.35, step * 0.35)
			local name = TREE_SPRITES[rng:NextInteger(1, #TREE_SPRITES)]
			local width = rng:NextNumber(34, 46)
			local height = width * (Art.fogMap.aspects[name] or 1)
			put(
				into,
				MapData.rectBounds(px, pz, width, height),
				sprite(name, px - ox, pz - oz, width, height, { ImageTransparency = 0.02 })
			)
			z += step
		end
		x += step
	end
end

-- Fog: a pale wash with drifting cloud sprites over it.
local function fogBank(zone: MapData.Zone, ox: number, oz: number, into: Bucketed, seed: number)
	local box = MapData.zoneBounds(zone)
	local rng = Random.new(seed)
	local step = 56
	local x = box.x0 + step / 2
	while x < box.x1 do
		local z = box.z0 + step / 2
		while z < box.z1 do
			local size = rng:NextNumber(90, 130)
			local px = x + rng:NextNumber(-12, 12)
			local pz = z + rng:NextNumber(-12, 12)
			put(
				into,
				MapData.rectBounds(px, pz, size, size),
				sprite(
					"fog",
					px - ox,
					pz - oz,
					size,
					size,
					{ ImageTransparency = 0.2, Rotation = rng:NextInteger(0, 359) }
				)
			)
			z += step
		end
		x += step
	end
end

-- The ground ---------------------------------------------------------------------------------------

export type GroundProps = { map: MapData.Map }

local function Ground(props: GroundProps)
	local map = props.map
	local bounds = map.bounds
	local ox, oz = bounds.x0, bounds.z0
	local spanX, spanZ = bounds.x1 - bounds.x0, bounds.z1 - bounds.z0
	local groundColor, groundTile = fill(map.ground)

	-- Past the playable area: the edge kind, fading in from the play edge outward. Each
	-- side is one band the map's full length (they overlap at the corners), so no seams.
	local edge = bucketed()
	local play = map.play
	if play and map.edge then
		local color = fill(map.edge)
		local function band(x0: number, z0: number, x1: number, z1: number, inward: number)
			if x1 - x0 <= 0 or z1 - z0 <= 0 then
				return
			end
			put(
				edge,
				{ x0 = x0, z0 = z0, x1 = x1, z1 = z1 },
				e("Frame", {
					Size = UDim2.fromOffset(x1 - x0, z1 - z0),
					Position = UDim2.fromOffset(x0 - ox, z0 - oz),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
				}, {
					Fade = e("UIGradient", {
						-- Opaque out to the far side, fading to nothing just inside the play edge.
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.1),
							NumberSequenceKeypoint.new(0.5, 0.2),
							NumberSequenceKeypoint.new(1, 1),
						}),
						Rotation = inward,
					}),
				})
			)
		end
		local reach = 30 -- the fade reaches this far into the play area's margin
		band(bounds.x0, bounds.z0, bounds.x1, play.z0 + reach, 90) -- north: fades toward +Z
		band(bounds.x0, play.z1 - reach, bounds.x1, bounds.z1, 270)
		band(bounds.x0, bounds.z0, play.x0 + reach, bounds.z1, 0)
		band(play.x1 - reach, bounds.z0, bounds.x1, bounds.z1, 180)
	end

	local zones, woodsLayer, fogLayer = bucketed(), bucketed(), bucketed()
	for index, zone in map.zones do
		if zone.kind == "forest" then
			woods(zone, ox, oz, woodsLayer, index * 7919 + 13)
		elseif zone.kind == "fog" then
			-- A pale wash fading inward, under drifting clouds.
			local centre = Vector2.new((bounds.x0 + bounds.x1) / 2, (bounds.z0 + bounds.z1) / 2)
			put(fogLayer, MapData.zoneBounds(zone), fogWash(zone, ox, oz, centre))
			fogBank(zone, ox, oz, fogLayer, index * 4513 + 7)
		elseif zone.shape == "poly" then
			for _, element in polygon(zone, ox, oz) do
				put(zones, MapData.zoneBounds(zone), element)
			end
		else
			local box = MapData.zoneBounds(zone)
			for _, element in zoneShape(zone, ox, oz, index * 6271 + 3) do
				put(zones, box, element)
			end
		end
	end

	local paths = bucketed()
	for pass = 1, 2 do
		for _, path in map.paths do
			local style = PATHS[path.kind] or PATHS.path
			local inner = pass == 2
			local width = if inner then path.width * style.core else path.width
			local color = if inner then style.inner else style.outer
			for index = 1, #path.points - 1 do
				local a, b = path.points[index], path.points[index + 1]
				local box = MapData.pointsBounds({ a, b }, width / 2)
				put(paths, box, bar(a.x - ox, a.z - oz, b.x - ox, b.z - oz, width, color, true))
			end
		end
	end

	local fences = bucketed()
	for _, fence in map.fences do
		local style = FENCES[fence.kind] or FENCES.fence
		for index = 1, #fence.points - 1 do
			local a, b = fence.points[index], fence.points[index + 1]
			put(
				fences,
				MapData.pointsBounds({ a, b }, style.width),
				bar(a.x - ox, a.z - oz, b.x - ox, b.z - oz, style.width, style.color, false)
			)
		end
	end

	local buildings = bucketed()
	for _, building in map.buildings do
		local roof = ROOFS[building.kind or "house"] or ROOFS.house
		local long = building.w >= building.d
		local children: { [string]: any } = {
			Stroke = e("UIStroke", { Color = OUTLINE, Thickness = 1, Transparency = 0.2 }),
			-- The roof's ridge along its longer side.
			Ridge = building.kind ~= "ruin" and e("Frame", {
				Size = if long then UDim2.new(1, -4, 0, 1.2) else UDim2.new(0, 1.2, 1, -4),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = roof:Lerp(Color3.new(1, 1, 1), 0.25),
				BorderSizePixel = 0,
			}),
		}
		local box = MapData.rectBounds(building.x, building.z, building.w, building.d, building.yaw)
		-- A soft shadow toward the south-east, then the roof.
		put(
			buildings,
			box,
			e("Frame", {
				Size = UDim2.fromOffset(building.w, building.d),
				Position = UDim2.fromOffset(building.x - ox + 1.6, building.z - oz + 1.6),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = -(building.yaw or 0),
				BackgroundColor3 = OUTLINE,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
			})
		)
		put(
			buildings,
			box,
			e("Frame", {
				Size = UDim2.fromOffset(building.w, building.d),
				Position = UDim2.fromOffset(building.x - ox, building.z - oz),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = -(building.yaw or 0),
				BackgroundColor3 = roof,
				BackgroundTransparency = if building.kind == "ruin" then 0.35 else 0,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, children)
		)
	end

	local trees = bucketed()
	for index, tree in (map.trees or {}) :: { MapData.Point } do
		local name = TREE_SPRITES[index % #TREE_SPRITES + 1]
		local size = 16 + (index * 37 % 7)
		put(
			trees,
			MapData.rectBounds(tree.x, tree.z, size, size),
			sprite(name, tree.x - ox, tree.z - oz, size, size * (Art.fogMap.aspects[name] or 1))
		)
	end

	return e("Frame", {
		Size = UDim2.fromOffset(spanX, spanZ),
		BackgroundColor3 = groundColor,
		BorderSizePixel = 0,
		ref = mark.backdrop,
	}, {
		Tile = groundTile and e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Art.fogMap.sprites[groundTile] or "",
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(TILE, TILE),
			ImageTransparency = 0.05,
			ZIndex = 1,
		}),
		Edge = layer(2, edge),
		Zones = layer(3, zones),
		Paths = layer(4, paths),
		Woods = layer(5, woodsLayer),
		Fences = layer(6, fences),
		Buildings = layer(7, buildings),
		Trees = layer(8, trees),
		Fog = layer(9, fogLayer),
	})
end

MapCanvas.Ground = React.memo(Ground)

-- Outposts and plot nodes --------------------------------------------------------------------------

local FLOOR = Color3.fromRGB(196, 158, 100)
local FLOOR_LINE = Color3.fromRGB(120, 90, 56)
local WALL = Color3.fromRGB(52, 40, 32)
local TREE_DOT = Color3.fromRGB(44, 74, 42)
local ROCK_DOT = Color3.fromRGB(170, 164, 152)

export type FeaturesProps = {
	bounds: MapData.Bounds,
	outposts: { { x: number, z: number, w: number, d: number, yaw: number, kind: string, mine: boolean } },
	trees: { MapData.Point },
	rocks: { MapData.Point },
	version: number,
}

local function Features(props: FeaturesProps)
	local ox, oz = props.bounds.x0, props.bounds.z0
	local spanX, spanZ = props.bounds.x1 - ox, props.bounds.z1 - oz
	local floors, walls, dots = bucketed(), bucketed(), bucketed()
	for _, rect in props.outposts do
		local into = if rect.kind == "floor" then floors else walls
		put(
			into,
			MapData.rectBounds(rect.x, rect.z, rect.w, rect.d, rect.yaw),
			e(
				"Frame",
				{
					Size = UDim2.fromOffset(rect.w, rect.d),
					Position = UDim2.fromOffset(rect.x - ox, rect.z - oz),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = -rect.yaw,
					BackgroundColor3 = if rect.kind == "floor" then FLOOR else WALL,
					BorderSizePixel = 0,
				},
				if rect.kind == "floor"
					then {
						-- Each foundation's edge, so a floor reads as LDoE's tile grid (rec8).
						Grid = e("UIStroke", {
							Color = FLOOR_LINE,
							Thickness = 1,
							Transparency = 0.35,
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						}),
					}
					else nil
			)
		)
	end
	local function dot(point: MapData.Point, size: number, color: Color3)
		put(
			dots,
			MapData.rectBounds(point.x, point.z, size, size),
			e("Frame", {
				Size = UDim2.fromOffset(size, size),
				Position = UDim2.fromOffset(point.x - ox, point.z - oz),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Stroke = e("UIStroke", { Color = OUTLINE, Thickness = 1, Transparency = 0.4 }),
			})
		)
	end
	for _, tree in props.trees do
		dot(tree, 7, TREE_DOT)
	end
	for _, rock in props.rocks do
		dot(rock, 4.5, ROCK_DOT)
	end
	return e("Frame", {
		Size = UDim2.fromOffset(spanX, spanZ),
		BackgroundTransparency = 1,
		ref = mark.backdrop,
	}, {
		Floors = layer(1, floors),
		Walls = layer(2, walls),
		Dots = layer(3, dots),
	})
end

MapCanvas.Features = React.memo(Features, function(a: FeaturesProps, b: FeaturesProps): boolean
	return a.version == b.version and a.bounds == b.bounds
end)

-- The bucket frames under a drawn canvas, for showing only those near a view.
function MapCanvas.buckets(root: Instance): { { frame: GuiObject, key: string } }
	local list = {}
	for _, child in root:GetDescendants() do
		if child:IsA("GuiObject") and string.sub(child.Name, 1, 1) == "Q" then
			table.insert(list, { frame = child, key = string.sub(child.Name, 2) })
		end
	end
	return list
end

return MapCanvas
