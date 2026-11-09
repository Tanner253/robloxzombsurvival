--!strict
--[[
	Builder: the toolkit the Fog Run location maps are written with (world-as-code,
	ARCHITECTURE §11). A layout module (Maps/<Location>) calls these with map-local
	coordinates: +X east, +Z south, y up from the map's ground level, all in studs.
	The game camera looks north-west, so building fronts face south or east.

	What it makes, all under the map's folder (FogRuns/Map's marker contract):
	- terrain from the layout's height and surface functions (three-layer ground,
	  ART_DIRECTION §4), plus optional water;
	- exact-geometry buildings (walls with door and window openings, floors, gable
	  or flat roofs, trim, ruins), fences, rails, platforms and shipping containers,
	  in one shared material table (palette-locked; MaterialVariants when present);
	- approved kit props (Shared/Art, World/Models; anything below grade A is skipped);
	- lootable containers with hinged lids and doors (the client opens them once
	  searched, or shows them open when the lobby didn't stock them);
	- the RunMarker parts: spawn, hollow, container, extract, bounds, node.

	Walls are Models with Layer "fill" and roofs Layer "roof", so the client's
	occlusion fade sees through them; a building's Interior box lets the client lift
	the roof off while you're inside (checklist 2.3).
]]

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Art)
local Models = require("../../World/Models")

local Builder = {}

Builder.CONTAINER_TAG = "EO_RunContainer"
Builder.CANOPY_TAG = "EO_Canopy"
Builder.ROOF_TAG = "EO_Roof"
Builder.EXIT_TAG = "EO_RunExit"

export type Ctx = {
	locationId: string,
	root: Instance, -- the map folder
	origin: Vector3, -- world position of the map's (0, 0, 0)
	half: number, -- the playable half-size (bounds)
	rng: Random,
	groundHeight: (x: number, z: number) -> number, -- map-local ground height
	folders: { [string]: Instance },
	parts: number,
}

-- Materials ------------------------------------------------------------------------------------------

export type Paint = {
	material: Enum.Material,
	color: Color3, -- the colour without the variant (and the tint multiplied over it with one)
	variant: string?, -- a MaterialVariant in MaterialService on the same base material
	tint: Color3?, -- the colour over the variant's own texture (default: a light neutral)
	transparency: number?,
	reflectance: number?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- One shared palette for every map (ART_DIRECTION §3: muted earth tones, about 60% saturation).
-- The generated PBR variants (place/materials) carry the detail; tints only nudge them.
Builder.paints = {
	siding = {
		material = Enum.Material.WoodPlanks,
		color = rgb(152, 144, 126),
		variant = "EO_Siding",
		tint = rgb(226, 220, 206),
	},
	sidingBlue = {
		material = Enum.Material.WoodPlanks,
		color = rgb(112, 124, 128),
		variant = "EO_Siding",
		tint = rgb(170, 188, 196),
	},
	sidingGreen = {
		material = Enum.Material.WoodPlanks,
		color = rgb(118, 128, 106),
		variant = "EO_Siding",
		tint = rgb(182, 196, 166),
	},
	barn = {
		material = Enum.Material.WoodPlanks,
		color = rgb(128, 78, 56),
		variant = "EO_BarnBoards",
		tint = rgb(176, 160, 150),
	},
	boards = {
		material = Enum.Material.Wood,
		color = rgb(122, 98, 74),
		variant = "EO_WornWood",
		tint = rgb(222, 206, 186),
	},
	bark = {
		-- Log bark: plain wood grain along the log (QA: the plank variant wrapped round a
		-- cylinder read as banded grey pipe).
		material = Enum.Material.Wood,
		color = rgb(86, 68, 52),
	},
	endGrain = {
		-- A sawn log end: pale, so a stack reads as logs from the gameplay camera.
		material = Enum.Material.Wood,
		color = rgb(178, 150, 112),
	},
	charred = {
		-- Fire-blackened boards (Gloaming Deep's burnt cabin and bridge).
		material = Enum.Material.Wood,
		color = rgb(52, 46, 42),
		variant = "EO_WornWood",
		tint = rgb(92, 80, 72),
	},
	brick = {
		material = Enum.Material.Brick,
		color = rgb(134, 88, 70),
		variant = "EO_Brick",
		tint = rgb(176, 156, 146),
	},
	brickDark = {
		material = Enum.Material.Brick,
		color = rgb(102, 74, 64),
		variant = "EO_Brick",
		tint = rgb(128, 116, 110),
	},
	plaster = {
		material = Enum.Material.Plaster,
		color = rgb(176, 166, 146),
		variant = "EO_Plaster",
		tint = rgb(196, 192, 182),
	},
	concrete = {
		material = Enum.Material.Concrete,
		color = rgb(140, 138, 132),
		variant = "EO_Concrete",
		tint = rgb(216, 214, 208),
	},
	concreteDark = {
		material = Enum.Material.Concrete,
		color = rgb(104, 104, 102),
		variant = "EO_Concrete",
		tint = rgb(150, 148, 144),
	},
	corrugated = {
		material = Enum.Material.CorrodedMetal,
		color = rgb(124, 108, 96),
		variant = "EO_Corrugated",
		tint = rgb(176, 176, 176),
	},
	corrugatedTeal = {
		material = Enum.Material.CorrodedMetal,
		color = rgb(96, 112, 108),
		variant = "EO_Corrugated",
		tint = rgb(140, 162, 160),
	},
	shingle = {
		material = Enum.Material.RoofShingles,
		color = rgb(84, 80, 78),
		variant = "EO_Shingle",
		tint = rgb(210, 206, 204),
	},
	shingleRed = {
		material = Enum.Material.RoofShingles,
		color = rgb(104, 72, 62),
		variant = "EO_Shingle",
		tint = rgb(214, 170, 156),
	},
	roofMetal = {
		material = Enum.Material.CorrodedMetal,
		color = rgb(118, 94, 78),
		variant = "EO_Corrugated",
		tint = rgb(150, 140, 134),
	},
	floorPlanks = {
		material = Enum.Material.WoodPlanks,
		-- Tinted down from the deck texture's warm orange: old, unvarnished, dusty boards.
		color = rgb(104, 92, 80),
		variant = "EO_Deck_Planks",
		tint = rgb(196, 170, 132),
	},
	floorTile = {
		material = Enum.Material.CeramicTiles,
		color = rgb(150, 146, 136),
		variant = "EO_FloorTile",
		tint = rgb(220, 216, 206),
	},
	floorConcrete = {
		material = Enum.Material.Concrete,
		color = rgb(120, 118, 114),
		variant = "EO_Concrete",
		tint = rgb(180, 178, 172),
	},
	trim = {
		material = Enum.Material.Wood,
		color = rgb(86, 68, 52),
		variant = "EO_WornWood",
		tint = rgb(150, 128, 106),
	},
	trimLight = {
		material = Enum.Material.Wood,
		color = rgb(176, 168, 150),
		variant = "EO_WornWood",
		tint = rgb(236, 230, 216),
	},
	steel = {
		material = Enum.Material.Metal,
		color = rgb(92, 94, 96),
		variant = "EO_PaintedMetal",
		tint = rgb(176, 178, 180),
	},
	rust = {
		material = Enum.Material.CorrodedMetal,
		color = rgb(122, 86, 64),
		variant = "EO_RustSteel",
		tint = rgb(140, 124, 116),
	},
	paintedMetal = {
		material = Enum.Material.Metal,
		color = rgb(94, 110, 104),
		variant = "EO_PaintedMetal",
		tint = rgb(196, 200, 194),
	},
	darkMetal = {
		material = Enum.Material.Metal,
		color = rgb(58, 60, 62),
		variant = "EO_PaintedMetal",
		tint = rgb(104, 106, 108),
	},
	glass = { material = Enum.Material.Glass, color = rgb(70, 84, 90), transparency = 0.45, reflectance = 0.05 },
	void = { material = Enum.Material.SmoothPlastic, color = rgb(34, 34, 36) },
	rubble = { material = Enum.Material.Cobblestone, color = rgb(116, 110, 102) },
	gravel = { material = Enum.Material.Pebble, color = rgb(118, 114, 106) },
	hay = { material = Enum.Material.Grass, color = rgb(176, 158, 104) },
	cloth = { material = Enum.Material.Fabric, color = rgb(112, 104, 88) },
	tarp = { material = Enum.Material.Fabric, color = rgb(78, 92, 84) },
	asphalt = {
		material = Enum.Material.Asphalt,
		color = rgb(78, 80, 84),
		variant = "EO_Asphalt",
		tint = rgb(190, 190, 190),
	},
	kerb = {
		material = Enum.Material.Concrete,
		color = rgb(132, 130, 124),
		variant = "EO_Concrete",
		tint = rgb(196, 194, 188),
	},
	roadPaint = { material = Enum.Material.SmoothPlastic, color = rgb(176, 160, 112) },
	exitGlow = { material = Enum.Material.Neon, color = rgb(92, 200, 110), transparency = 0.7 },
} :: { [string]: Paint }

local function variantExists(name: string?): boolean
	if name == nil then
		return false
	end
	return MaterialService:FindFirstChild(name, true) ~= nil
end

function Builder.paint(part: BasePart, key: string)
	local paint = Builder.paints[key] or Builder.paints.concrete
	part.Material = paint.material
	part.Color = paint.color
	if variantExists(paint.variant) then
		part.MaterialVariant = paint.variant :: string
		part.Color = paint.tint or Color3.fromRGB(220, 220, 220)
	end
	part.Transparency = paint.transparency or 0
	part.Reflectance = paint.reflectance or 0
end

-- Context --------------------------------------------------------------------------------------------

function Builder.new(locationId: string, root: Instance, origin: Vector3, half: number, seed: number): Ctx
	local ctx: Ctx = {
		locationId = locationId,
		root = root,
		origin = origin,
		half = half,
		rng = Random.new(seed),
		groundHeight = function(_x: number, _z: number): number
			return 0
		end,
		folders = {},
		parts = 0,
	}
	return ctx
end

-- A named sub-folder of the map (Dressing, Buildings, Markers, Containers...).
function Builder.folder(ctx: Ctx, name: string): Instance
	local existing = ctx.folders[name]
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = ctx.root
	ctx.folders[name] = folder
	return folder
end

-- World position of a map-local point on the ground (plus `lift`).
function Builder.at(ctx: Ctx, x: number, z: number, lift: number?): Vector3
	return ctx.origin + Vector3.new(x, ctx.groundHeight(x, z) + (lift or 0), z)
end

-- A world CFrame at a map-local point, turned by `yaw` degrees (0 faces -Z, north).
function Builder.frame(ctx: Ctx, x: number, z: number, yaw: number, lift: number?): CFrame
	return CFrame.new(Builder.at(ctx, x, z, lift)) * CFrame.Angles(0, math.rad(yaw), 0)
end

-- Yields now and then so a big build never freezes the server.
function Builder.breathe(ctx: Ctx, cost: number?)
	ctx.parts += cost or 1
	if ctx.parts >= 400 then
		ctx.parts = 0
		task.wait()
	end
end

-- Parts ----------------------------------------------------------------------------------------------

function Builder.part(parent: Instance, size: Vector3, cframe: CFrame, paint: string, name: string?): Part
	local part = Instance.new("Part")
	part.Name = name or "Part"
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	part.CastShadow = true
	part.CanTouch = false
	Builder.paint(part, paint)
	part.Parent = parent
	return part
end

function Builder.wedge(parent: Instance, size: Vector3, cframe: CFrame, paint: string): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Anchored = true
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.CanTouch = false
	Builder.paint(wedge, paint)
	wedge.Parent = parent
	return wedge
end

function Builder.cylinder(parent: Instance, height: number, diameter: number, cframe: CFrame, paint: string): Part
	-- Roblox cylinders run along X: stand it up.
	local part = Builder.part(
		parent,
		Vector3.new(height, diameter, diameter),
		cframe * CFrame.Angles(0, 0, math.rad(90)),
		paint,
		"Cylinder"
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function model(parent: Instance, name: string): Model
	local made = Instance.new("Model")
	made.Name = name
	made.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	made.Parent = parent
	return made
end
Builder.model = model

-- Terrain --------------------------------------------------------------------------------------------

export type TerrainSpec = {
	extent: number, -- half-size of the painted square (past the bounds, under the edge forest)
	height: (x: number, z: number) -> number, -- map-local ground height
	surface: (x: number, z: number, y: number) -> Enum.Material,
	water: ((x: number, z: number) -> number?)?, -- the water surface height there, if any
}

-- Ground colours for the materials without a generated variant (palette-locked, ART_DIRECTION §3).
local TERRAIN_COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Asphalt] = Color3.fromRGB(78, 82, 88),
	[Enum.Material.Pavement] = Color3.fromRGB(128, 126, 120),
	[Enum.Material.Basalt] = Color3.fromRGB(74, 72, 70), -- ash
	[Enum.Material.Slate] = Color3.fromRGB(96, 98, 100),
	[Enum.Material.Rock] = Color3.fromRGB(112, 108, 102),
	[Enum.Material.Cobblestone] = Color3.fromRGB(112, 108, 100), -- rail ballast
}

-- Generated variants for the Fog Run ground beyond the home set (Art.ground).
local TERRAIN_VARIANTS: { [Enum.Material]: string } = {
	[Enum.Material.Slate] = "EO_QuarryRock",
	[Enum.Material.Cobblestone] = "EO_Gravel",
}

-- Writes the ground in strips (yielding between them) from the layout's functions.
function Builder.terrain(ctx: Ctx, spec: TerrainSpec)
	ctx.groundHeight = spec.height
	local terrain = workspace.Terrain
	for material, color in TERRAIN_COLORS do
		terrain:SetMaterialColor(material, color)
	end
	for material, variant in TERRAIN_VARIANTS do
		if variantExists(variant) then
			MaterialService:SetBaseMaterialOverride(material, variant)
			terrain:SetMaterialColor(material, Color3.fromRGB(200, 200, 200))
		end
	end
	for material, look in Art.ground do
		if variantExists(look.variant) then
			MaterialService:SetBaseMaterialOverride(material, look.variant)
		end
		terrain:SetMaterialColor(material, look.tint)
	end
	if spec.water then
		-- Murky woodland water, not Roblox's bright default (only Fog Run maps have water).
		terrain.WaterColor = Color3.fromRGB(58, 70, 56)
		terrain.WaterTransparency = 0.2
		terrain.WaterReflectance = 0.25
		terrain.WaterWaveSize = 0.06
		terrain.WaterWaveSpeed = 6
	end
	local res = 4
	local extent = spec.extent
	local minY = -48 -- deep enough for the quarry pit
	local maxY = 40
	local strip = 64 -- studs of X per write
	local x0 = -extent
	while x0 < extent do
		local x1 = math.min(x0 + strip, extent)
		local lo = ctx.origin + Vector3.new(x0, minY, -extent)
		local hi = ctx.origin + Vector3.new(x1, maxY, extent)
		local region = Region3.new(lo, hi):ExpandToGrid(res)
		local size = region.Size / res
		local nx, ny, nz = math.floor(size.X + 0.5), math.floor(size.Y + 0.5), math.floor(size.Z + 0.5)
		local corner = region.CFrame.Position - region.Size / 2
		local materials: { { { any } } } = table.create(nx)
		local occupancy: { { { number } } } = table.create(nx)
		for ix = 1, nx do
			local mx: { { any } }, ox: { { number } } = table.create(ny), table.create(ny)
			for iy = 1, ny do
				mx[iy] = table.create(nz)
				ox[iy] = table.create(nz)
			end
			materials[ix], occupancy[ix] = mx, ox
			local wx = corner.X + (ix - 0.5) * res
			local x = wx - ctx.origin.X
			for iz = 1, nz do
				local wz = corner.Z + (iz - 0.5) * res
				local z = wz - ctx.origin.Z
				local ground = ctx.origin.Y + spec.height(x, z)
				local material = spec.surface(x, z, ground - ctx.origin.Y)
				local waterTop = if spec.water then spec.water(x, z) else nil
				local waterY = if waterTop then ctx.origin.Y + waterTop else nil
				for iy = 1, ny do
					local centre = corner.Y + (iy - 0.5) * res
					local fill = if centre + res <= ground then 1 else math.clamp((ground - centre) / res, 0, 1)
					if fill > 0 then
						mx[iy][iz] = if centre + res <= ground - res * 2 then Enum.Material.Ground else material
						ox[iy][iz] = fill
					elseif waterY and centre - res / 2 < waterY then
						mx[iy][iz] = Enum.Material.Water
						ox[iy][iz] = math.clamp((waterY - (centre - res / 2)) / res, 0, 1)
					else
						mx[iy][iz] = Enum.Material.Air
						ox[iy][iz] = 0
					end
				end
			end
		end
		terrain:WriteVoxels(region, res, materials, occupancy)
		x0 = x1
		task.wait()
	end
end

-- Noise helpers for layouts.
function Builder.noise(x: number, z: number, scale: number, seed: number): number
	return math.noise(x / scale, z / scale, seed)
end

-- Distance from a point to a polyline (map-local), and the parameter along it.
function Builder.distanceToPath(x: number, z: number, path: { Vector2 }): number
	local best = math.huge
	for index = 1, #path - 1 do
		local a, b = path[index], path[index + 1]
		local ab = b - a
		local length2 = ab:Dot(ab)
		local t = if length2 > 0 then math.clamp((Vector2.new(x, z) - a):Dot(ab) / length2, 0, 1) else 0
		local closest = a + ab * t
		best = math.min(best, (Vector2.new(x, z) - closest).Magnitude)
	end
	return best
end

-- Roads ---------------------------------------------------------------------------------------------

--[[
	A road along a polyline: asphalt slabs laid on the ground in short lengths (so it
	follows gentle slopes), faded centre dashes, and optional kerbed sidewalks on both
	sides. The terrain under it should be flat earth (the layout's surface function).
]]
function Builder.road(ctx: Ctx, path: { Vector2 }, width: number, sidewalk: number?, lift: number?)
	local holder = model(Builder.folder(ctx, "Roads"), "Road")
	for index = 1, #path - 1 do
		local a, b = path[index], path[index + 1]
		local length = (b - a).Magnitude
		local pieces = math.max(1, math.ceil(length / 16))
		for step = 0, pieces - 1 do
			local p = a:Lerp(b, step / pieces)
			local q = a:Lerp(b, (step + 1) / pieces)
			-- Each piece runs from ground to ground along the slope, so neighbours meet without
			-- a step. Crossing roads sit a little apart in height, so overlaps never z-fight (6.11).
			local p3 = Vector3.new(p.X, ctx.groundHeight(p.X, p.Y) + (lift or 0), p.Y)
			local q3 = Vector3.new(q.X, ctx.groundHeight(q.X, q.Y) + (lift or 0), q.Y)
			local along = (q3 - p3).Unit
			local up = (Vector3.yAxis - along * along.Y).Unit
			local span = (q3 - p3).Magnitude + 0.3
			local frame = CFrame.fromMatrix(ctx.origin + (p3 + q3) / 2, along, up, along:Cross(up))
			Builder.part(holder, Vector3.new(span, 1, width), frame * CFrame.new(0, -0.3, 0), "asphalt", "Asphalt")
			-- Faded dashes down the middle, a few long gone.
			if ctx.rng:NextNumber() > 0.25 then
				local dash = Builder.part(
					holder,
					Vector3.new(span * 0.45, 0.06, 0.35),
					frame * CFrame.new(0, 0.23, 0),
					"roadPaint",
					"Dash"
				)
				dash.Transparency = 0.25
				dash.CanCollide = false
			end
			if sidewalk then
				for _, side in { -1, 1 } do
					local off = side * (width / 2 + sidewalk / 2)
					Builder.part(
						holder,
						Vector3.new(span, 1.2, sidewalk),
						frame * CFrame.new(0, -0.2, off),
						"concrete",
						"Sidewalk"
					)
					Builder.part(
						holder,
						Vector3.new(span, 1.3, 0.5),
						frame * CFrame.new(0, -0.15, side * (width / 2 + 0.25)),
						"kerb",
						"Kerb"
					)
				end
			end
		end
		Builder.breathe(ctx, pieces * 6)
	end
end

-- Kit props --------------------------------------------------------------------------------------------

export type KitOptions = {
	height: number?, -- scale so the model stands this tall
	scale: number?, -- or multiply its conformed size
	solid: boolean?,
	lift: number?,
	tilt: number?, -- degrees of lean, for wrecks and fallen things
	pitch: number?, -- degrees about the width axis (a vehicle: positive drops its nose)
	canopy: boolean?, -- tall foliage: fades when it hides the survivor
	parent: Instance?,
}

-- Places an approved kit model standing on the ground. nil when no approved model exists.
function Builder.kit(ctx: Ctx, names: { string }, x: number, z: number, yaw: number, options: KitOptions?): Model?
	local opts: KitOptions = options or {}
	local found = Models.kit(names)
	if found == nil then
		return nil
	end
	local placed = found :: Model
	if opts.height then
		local size = placed:GetExtentsSize()
		if size.Y > 0 then
			placed:ScaleTo(placed:GetScale() * opts.height / size.Y)
		end
	elseif opts.scale then
		placed:ScaleTo(placed:GetScale() * opts.scale)
	end
	local frame = Builder.frame(ctx, x, z, yaw, opts.lift)
	if opts.tilt then
		frame *= CFrame.Angles(math.rad(opts.tilt), 0, 0)
	end
	if opts.pitch then
		frame *= CFrame.Angles(0, 0, math.rad(opts.pitch))
	end
	placed:PivotTo(frame)
	local solid = opts.solid ~= false
	for _, descendant in placed:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = solid
			descendant.CanTouch = false
		end
	end
	if opts.canopy then
		CollectionService:AddTag(placed, Builder.CANOPY_TAG)
	end
	placed.Parent = opts.parent or Builder.folder(ctx, "Dressing")
	Builder.breathe(ctx, 4)
	return placed
end

--[[
	A vehicle wreck. Every vehicle model has its rear (boot, tailgate, back doors) at its
	+X end and its length along X, so `yaw` 0 parks it east-west, nose to the west. With
	`trunk`, a trunk container spot sits at the rear (the lobby stocks some of them).
]]
function Builder.vehicle(
	ctx: Ctx,
	name: string,
	x: number,
	z: number,
	yaw: number,
	options: KitOptions?,
	trunk: boolean?
): Model?
	local placed = Builder.kit(ctx, { name }, x, z, yaw, options)
	if placed and trunk then
		local frame, size = placed:GetBoundingBox()
		local rear = frame * CFrame.new(size.X / 2 + 0.5, 0, 0)
		local at = rear.Position - ctx.origin
		Builder.container(ctx, "trunk", at.X, at.Z, yaw + 90)
	end
	return placed
end

-- Scatters kit props in a disc, keeping `spacing` apart and clear of `avoid` (map-local points).
function Builder.scatter(
	ctx: Ctx,
	names: { string },
	centre: Vector2,
	radius: number,
	count: number,
	spacing: number,
	options: KitOptions?,
	keepOut: ((x: number, z: number) -> boolean)?
): { Vector2 }
	local placed: { Vector2 } = {}
	local tries = 0
	while #placed < count and tries < count * 30 do
		tries += 1
		local angle = ctx.rng:NextNumber() * math.pi * 2
		local distance = math.sqrt(ctx.rng:NextNumber()) * radius
		local spot = centre + Vector2.new(math.cos(angle), math.sin(angle)) * distance
		local clear = math.abs(spot.X) < ctx.half + 60 and math.abs(spot.Y) < ctx.half + 60
		for _, other in placed do
			if (other - spot).Magnitude < spacing then
				clear = false
				break
			end
		end
		if clear and keepOut and keepOut(spot.X, spot.Y) then
			clear = false
		end
		if clear then
			local opts: KitOptions = table.clone(options or {})
			if opts.height then
				opts.height = (opts.height :: number) * (0.85 + ctx.rng:NextNumber() * 0.3)
			end
			if Builder.kit(ctx, names, spot.X, spot.Y, ctx.rng:NextNumber() * 360, opts) then
				table.insert(placed, spot)
			else
				return placed -- no approved model: nothing to scatter
			end
		end
	end
	return placed
end

-- Markers ----------------------------------------------------------------------------------------------

function Builder.marker(
	ctx: Ctx,
	kind: string,
	x: number,
	z: number,
	attributes: { [string]: any }?,
	size: Vector3?
): Part
	local part = Instance.new("Part")
	part.Name = `{kind}Marker`
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size or Vector3.new(2, 2, 2)
	part.CFrame = CFrame.new(Builder.at(ctx, x, z, 1))
	part:SetAttribute("RunMarker", kind)
	for key, value in (attributes or {}) :: { [string]: any } do
		part:SetAttribute(key, value)
	end
	part.Parent = Builder.folder(ctx, "Markers")
	return part
end

function Builder.bounds(ctx: Ctx)
	local part = Builder.marker(ctx, "bounds", 0, 0, nil, Vector3.new(ctx.half * 2, 60, ctx.half * 2))
	part.CFrame = CFrame.new(ctx.origin + Vector3.new(0, 20, 0))
end

-- A gatherable node spot (Gathering spawns the node's own model there when the lobby opens).
function Builder.node(ctx: Ctx, nodeId: string, x: number, z: number)
	Builder.marker(ctx, "node", x, z, { NodeId = nodeId })
end

--[[
	An extraction point: a green ground overlay ring with a flare pole, its marker
	(PointId) and the exit tag for the minimap arc. `edge` exits (Light fog) are the
	same overlay at a road or trail leaving the map.
]]
function Builder.exit(ctx: Ctx, pointId: string, name: string, x: number, z: number, radius: number, yaw: number)
	local holder = model(Builder.folder(ctx, "Exits"), `Exit_{pointId}`)
	holder:SetAttribute("PointId", pointId)
	holder:SetAttribute("ExitName", name)
	holder:SetAttribute("Radius", radius)
	local centre = Builder.at(ctx, x, z, 0.12)
	-- The overlay: a soft translucent green disc just over the highest ground under it (so
	-- slopes never cut it), and a thin glowing rim laid segment by segment on the ground.
	local top = ctx.groundHeight(x, z)
	for step = 0, 11 do
		local angle = step / 12 * math.pi * 2
		top = math.max(top, ctx.groundHeight(x + math.cos(angle) * radius, z + math.sin(angle) * radius))
	end
	-- Just clear of a road surface too (Builder.road pieces stand 0.2 + lift above ground).
	local discCentre = ctx.origin + Vector3.new(x, top + 0.45, z)
	local disc = Instance.new("Part")
	disc.Name = "Overlay"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.1, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(discCentre) * CFrame.Angles(0, 0, math.rad(90))
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	Builder.paint(disc, "exitGlow")
	disc.Material = Enum.Material.SmoothPlastic
	disc.Transparency = 0.7
	disc.Parent = holder
	local segments = 28
	for step = 0, segments - 1 do
		local a0 = step / segments * math.pi * 2
		local a1 = (step + 1) / segments * math.pi * 2
		local p0 = Builder.at(ctx, x + math.cos(a0) * radius, z + math.sin(a0) * radius, 0.2)
		local p1 = Builder.at(ctx, x + math.cos(a1) * radius, z + math.sin(a1) * radius, 0.2)
		local seg = Instance.new("Part")
		seg.Name = "Rim"
		seg.Size = Vector3.new(0.35, 0.12, (p1 - p0).Magnitude + 0.1)
		seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CanTouch = false
		seg.CastShadow = false
		Builder.paint(seg, "exitGlow")
		seg.Transparency = 0.2
		seg.Parent = holder
	end
	-- A pole with a green lantern, so the point reads from afar and at night.
	local pole = Builder.part(
		holder,
		Vector3.new(0.4, 7, 0.4),
		CFrame.new(centre + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, math.rad(yaw), 0),
		"darkMetal",
		"Pole"
	)
	local lamp =
		Builder.part(holder, Vector3.new(0.9, 0.9, 0.9), pole.CFrame * CFrame.new(0, 3.6, 0), "exitGlow", "Lamp")
	lamp.Transparency = 0.15
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(110, 230, 130)
	light.Range = radius + 8
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = lamp
	CollectionService:AddTag(holder, Builder.EXIT_TAG)
	Builder.marker(ctx, "extract", x, z, { PointId = pointId, ExitName = name })
end

-- Buildings --------------------------------------------------------------------------------------------

export type Opening = {
	side: "N" | "S" | "E" | "W",
	at: number, -- offset along the wall from its centre
	kind: "door" | "window" | "gap", -- gap: a doorless opening (garage, barn)
	width: number?,
	height: number?,
}

export type BuildingSpec = {
	name: string,
	x: number,
	z: number,
	yaw: number?, -- 0, 90, 180 or 270
	width: number, -- along X
	depth: number, -- along Z
	height: number?, -- wall height (default 10)
	wall: string, -- paint key
	trim: string?,
	floor: string?,
	roof: ("gable" | "flat" | "shed" | "none")?,
	roofPaint: string?,
	openings: { Opening },
	ruin: number?, -- 0..1: broken wall tops, missing roof panels
	porch: ("S" | "E")?,
	plinth: number?, -- height of the base slab (default 0.8)
	chimney: boolean?,
}

export type Building = {
	model: Model,
	frame: CFrame,
	floor: number, -- map-local height of the floor's top
	inside: (x: number, z: number) -> boolean,
}

local WALL = 0.8
local DOOR_W, DOOR_H = 4.5, 7.5
local WINDOW_W, WINDOW_H, SILL = 4, 3.6, 3.2

local SIDES = {
	N = { axis = "X", normal = Vector3.new(0, 0, -1) },
	S = { axis = "X", normal = Vector3.new(0, 0, 1) },
	E = { axis = "Z", normal = Vector3.new(1, 0, 0) },
	W = { axis = "Z", normal = Vector3.new(-1, 0, 0) },
}

-- One wall side as its own Model (Layer "fill") with its openings cut out.
local function wallSide(
	ctx: Ctx,
	building: Model,
	base: CFrame,
	spec: BuildingSpec,
	side: "N" | "S" | "E" | "W",
	height: number
)
	local info = SIDES[side]
	local length = if info.axis == "X" then spec.width else spec.depth
	local offset = if info.axis == "X" then spec.depth / 2 else spec.width / 2
	local holder = model(building, `Wall{side}`)
	holder:SetAttribute("Layer", "fill")
	-- The wall's own frame: X runs along the building's +X (north and south walls) or +Z
	-- (east and west walls), so an opening's `at` is that offset; `out` says which way
	-- local Z faces (+1 out of the building, -1 in).
	local right = if info.axis == "X" then Vector3.xAxis else Vector3.zAxis
	local back = right:Cross(Vector3.yAxis)
	local out = if back:Dot(info.normal) > 0 then 1 else -1
	local wallFrame = base * CFrame.fromMatrix(info.normal * (offset - WALL / 2), right, Vector3.yAxis, back)
	local openings: { Opening } = {}
	for _, opening in spec.openings do
		if opening.side == side then
			table.insert(openings, opening)
		end
	end
	table.sort(openings, function(a: Opening, b: Opening): boolean
		return a.at < b.at
	end)
	local trimKey = spec.trim or "trim"
	local ruin = spec.ruin or 0
	-- Wall height along the wall: a ruin drops in steps toward one end.
	local function topAt(u: number): number
		if ruin <= 0 then
			return height
		end
		-- Broken stretches where the noise peaks, sloping in and out; whole wall elsewhere.
		local n = math.noise(u / 10, offset / 7, #spec.name)
		local drop = math.clamp((n - 0.05) * (0.6 + ruin * 2), 0, 0.72)
		return math.max(height * (1 - drop), 3)
	end
	local function column(u0: number, u1: number, y0: number, y1: number)
		if u1 - u0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		if ruin > 0 and y1 >= height - 0.01 then
			-- Broken top: split into 2-stud columns with their own heights.
			local u = u0
			while u < u1 - 0.01 do
				local step = math.min(1.5, u1 - u)
				local top = math.max(topAt(u + step / 2), y0 + 0.5)
				Builder.part(
					holder,
					Vector3.new(step, top - y0, WALL),
					wallFrame * CFrame.new((u + step / 2), y0 + (top - y0) / 2, 0),
					spec.wall
				)
				u += step
			end
			return
		end
		Builder.part(
			holder,
			Vector3.new(u1 - u0, y1 - y0, WALL),
			wallFrame * CFrame.new((u0 + u1) / 2, (y0 + y1) / 2, 0),
			spec.wall
		)
	end
	local cursor = -length / 2
	for _, opening in openings do
		local w = opening.width or (if opening.kind == "window" then WINDOW_W else DOOR_W)
		local h = opening.height or (if opening.kind == "window" then WINDOW_H else DOOR_H)
		local u0, u1 = opening.at - w / 2, opening.at + w / 2
		column(cursor, u0, 0, height)
		local bottom = if opening.kind == "window" then SILL else 0
		local top = math.min(bottom + h, height)
		column(u0, u1, 0, bottom) -- under a window
		column(u0, u1, top, height) -- the lintel above
		-- Frames: a dark trim around the opening, proud of the wall on both faces.
		local frameDepth = WALL + 0.24
		Builder.part(
			holder,
			Vector3.new(0.35, top - bottom, frameDepth),
			wallFrame * CFrame.new(u0 + 0.17, bottom + (top - bottom) / 2, 0),
			trimKey
		)
		Builder.part(
			holder,
			Vector3.new(0.35, top - bottom, frameDepth),
			wallFrame * CFrame.new(u1 - 0.17, bottom + (top - bottom) / 2, 0),
			trimKey
		)
		if top < height - 0.1 then
			Builder.part(
				holder,
				Vector3.new(w, 0.4, frameDepth),
				wallFrame * CFrame.new(opening.at, top - 0.2, 0),
				trimKey
			)
		end
		if opening.kind == "window" then
			Builder.part(
				holder,
				Vector3.new(w + 0.4, 0.3, frameDepth + 0.2),
				wallFrame * CFrame.new(opening.at, bottom + 0.15, 0),
				trimKey
			)
			-- Most panes are long gone: a cracked pane in some, boards over others.
			local roll = ctx.rng:NextNumber()
			if roll < 0.3 then
				Builder.part(
					holder,
					Vector3.new(w - 0.6, h - 0.6, 0.1),
					wallFrame * CFrame.new(opening.at, bottom + h / 2, 0),
					"glass",
					"Pane"
				)
			elseif roll < 0.55 then
				for board = 1, 2 do
					Builder.part(
						holder,
						Vector3.new(w + 0.4, 0.55, 0.16),
						wallFrame
							* CFrame.new(opening.at, bottom + h * (board / 3), out * (WALL / 2 + 0.2))
							* CFrame.Angles(0, 0, math.rad((ctx.rng:NextNumber() - 0.5) * 18)),
						"boards",
						"Board"
					)
				end
			end
		end
		if opening.kind == "door" then
			-- The door itself, left ajar into the room (never shut: nobody gets stuck).
			local swing = math.rad(70 + ctx.rng:NextNumber() * 40) * out
			local door = Builder.part(
				holder,
				Vector3.new(w - 0.5, h - 0.3, 0.22),
				wallFrame
					* CFrame.new(u0 + 0.25, h / 2, -out * (WALL / 2))
					* CFrame.Angles(0, swing, 0)
					* CFrame.new((w - 0.5) / 2, 0, 0),
				if ctx.rng:NextNumber() < 0.5 then "boards" else spec.trim or "trim",
				"Door"
			)
			door.CanCollide = false
		elseif opening.kind == "window" and ctx.rng:NextNumber() < 0.45 then
			-- Shutters on the outside, one hanging off its hinge now and then.
			for _, hand in { -1, 1 } do
				local hang = if ctx.rng:NextNumber() < 0.25 then math.rad(14) else 0
				Builder.part(
					holder,
					Vector3.new(w / 2 - 0.1, h + 0.2, 0.18),
					wallFrame
						* CFrame.new(opening.at + hand * (w * 0.75 + 0.1), bottom + h / 2, out * (WALL / 2 + 0.12))
						* CFrame.Angles(0, 0, hang * hand),
					spec.trim or "trim",
					"Shutter"
				)
			end
		end
		cursor = u1
	end
	column(cursor, length / 2, 0, height)
	-- A dark baseboard band and a top fascia (not on ruins' broken tops).
	Builder.part(
		holder,
		Vector3.new(length, 0.7, WALL + 0.12),
		wallFrame * CFrame.new(0, 0.35, 0),
		spec.trim or "concreteDark",
		"Base"
	)
	if ruin <= 0 then
		Builder.part(
			holder,
			Vector3.new(length + 0.2, 0.45, WALL + 0.2),
			wallFrame * CFrame.new(0, height - 0.22, 0),
			trimKey,
			"Fascia"
		)
	end
	Builder.breathe(ctx, 12)
end

local function gableRoof(ctx: Ctx, building: Model, base: CFrame, spec: BuildingSpec, height: number)
	local holder = model(building, "Roof")
	holder:SetAttribute("Layer", "roof")
	CollectionService:AddTag(holder, Builder.ROOF_TAG)
	local paint = spec.roofPaint or "shingle"
	local alongX = spec.width >= spec.depth
	local span = if alongX then spec.depth else spec.width
	local length = (if alongX then spec.width else spec.depth) + 1.6
	local pitch = math.rad(32)
	local rise = math.tan(pitch) * span / 2
	local slope = (span / 2 + 1.2) / math.cos(pitch)
	local turn = if alongX then CFrame.new() else CFrame.Angles(0, math.rad(90), 0)
	local top = base * turn * CFrame.new(0, height + rise, 0)
	local ruin = spec.ruin or 0
	for _, sideSign in { -1, 1 } do
		-- A missing panel on a ruin: the rafters show through.
		local missing = ruin > 0.2 and ctx.rng:NextNumber() < ruin
		local panel = top * CFrame.Angles(sideSign * pitch, 0, 0) * CFrame.new(0, -0.25, sideSign * slope / 2)
		if missing then
			for rafter = -length / 2 + 1, length / 2 - 1, 3 do
				Builder.part(holder, Vector3.new(0.4, 0.4, slope), panel * CFrame.new(rafter, -0.3, 0), "trim")
			end
		else
			Builder.part(holder, Vector3.new(length, 0.5, slope), panel, paint, "Panel")
		end
	end
	Builder.part(holder, Vector3.new(length + 0.1, 0.6, 0.9), top * CFrame.new(0, 0.05, 0), "trim", "Ridge")
	-- Fascia boards along both eaves.
	for _, sideSign in { -1, 1 } do
		local eave = top
			* CFrame.Angles(sideSign * pitch, 0, 0)
			* CFrame.new(0, -0.45, sideSign * slope)
			* CFrame.Angles(-sideSign * pitch, 0, 0)
		Builder.part(holder, Vector3.new(length + 0.2, 0.7, 0.3), eave, "trim", "Fascia")
	end
	if spec.chimney then
		local chimney = base * turn * CFrame.new(length * 0.28, height + rise * 0.6, -span * 0.18)
		Builder.part(holder, Vector3.new(2.4, rise + 4, 2.4), chimney, "brickDark", "Chimney")
		Builder.part(
			holder,
			Vector3.new(2.8, 0.4, 2.8),
			chimney * CFrame.new(0, (rise + 4) / 2, 0),
			"concreteDark",
			"ChimneyCap"
		)
	end
	-- Gable ends: two wedges each, in the wall's material, kept just under the roof
	-- panels (at full height their sloped faces showed through the shingles).
	local gableRise = math.max(0.5, rise - 0.6)
	for _, endSign in { -1, 1 } do
		local x = endSign * (length - 1.6) / 2
		local half = span / 2
		for _, sideSign in { -1, 1 } do
			local wedge = Builder.wedge(
				holder,
				Vector3.new(WALL, gableRise, half),
				base
					* turn
					* CFrame.new(x - endSign * WALL / 2, height + gableRise / 2, sideSign * half / 2)
					* CFrame.Angles(0, if sideSign > 0 then math.rad(180) else 0, 0),
				spec.wall
			)
			wedge.Name = "Gable"
		end
	end
	Builder.breathe(ctx, 8)
end

local function flatRoof(ctx: Ctx, building: Model, base: CFrame, spec: BuildingSpec, height: number)
	local holder = model(building, "Roof")
	holder:SetAttribute("Layer", "roof")
	CollectionService:AddTag(holder, Builder.ROOF_TAG)
	local paint = spec.roofPaint or "concreteDark"
	local ruin = spec.ruin or 0
	if ruin > 0.3 then
		-- A caved-in roof: only the beams and a corner of the deck remain.
		for x = -spec.width / 2 + 2, spec.width / 2 - 2, 4 do
			Builder.part(
				holder,
				Vector3.new(0.6, 0.8, spec.depth),
				base * CFrame.new(x, height + 0.4, 0),
				"darkMetal",
				"Beam"
			)
		end
		Builder.part(
			holder,
			Vector3.new(spec.width * 0.4, 0.5, spec.depth * 0.45),
			base * CFrame.new(-spec.width * 0.3, height + 0.25, -spec.depth * 0.27),
			paint,
			"Deck"
		)
	else
		Builder.part(
			holder,
			Vector3.new(spec.width + 0.6, 0.6, spec.depth + 0.6),
			base * CFrame.new(0, height + 0.3, 0),
			paint,
			"Deck"
		)
		-- A parapet lip around the edge.
		for _, side in
			{ { spec.width + 0.6, 0, spec.depth / 2 + 0.15 }, { spec.width + 0.6, 0, -spec.depth / 2 - 0.15 } }
		do
			Builder.part(
				holder,
				Vector3.new(side[1], 1, 0.6),
				base * CFrame.new(side[2], height + 1, side[3]),
				spec.wall
			)
		end
		for _, sign in { -1, 1 } do
			Builder.part(
				holder,
				Vector3.new(0.6, 1, spec.depth + 0.6),
				base * CFrame.new(sign * (spec.width / 2 + 0.15), height + 1, 0),
				spec.wall
			)
		end
	end
	Builder.breathe(ctx, 6)
end

local function shedRoof(ctx: Ctx, building: Model, base: CFrame, spec: BuildingSpec, height: number)
	local holder = model(building, "Roof")
	holder:SetAttribute("Layer", "roof")
	CollectionService:AddTag(holder, Builder.ROOF_TAG)
	local rise = spec.depth * 0.18
	local slope = math.sqrt(spec.depth * spec.depth + rise * rise) + 1.4
	local angle = math.atan2(rise, spec.depth)
	Builder.part(
		holder,
		Vector3.new(spec.width + 1.2, 0.4, slope),
		base * CFrame.new(0, height + rise / 2 + 0.2, 0) * CFrame.Angles(-angle, 0, 0),
		spec.roofPaint or "roofMetal",
		"Panel"
	)
	-- Fill the triangle above the side walls.
	for _, sign in { -1, 1 } do
		Builder.wedge(
			holder,
			Vector3.new(WALL, rise, spec.depth),
			base * CFrame.new(sign * (spec.width / 2 - WALL / 2), height + rise / 2, 0),
			spec.wall
		)
	end
	Builder.breathe(ctx, 4)
end

--[[
	An enterable building: a plinth, a floor, four walls with their openings, trim
	and a roof. Returns the model and a test for "is this map-local point inside".
]]
function Builder.building(ctx: Ctx, spec: BuildingSpec): Building
	local yaw = spec.yaw or 0
	local height = spec.height or 10
	local plinth = spec.plinth or 0.8
	-- Stand on the highest ground under the footprint, so no corner floats.
	local ground = -math.huge
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, 0 } } do
		local cx = spec.x + corner[1] * spec.width / 2
		local cz = spec.z + corner[2] * spec.depth / 2
		ground = math.max(ground, ctx.groundHeight(cx, cz))
	end
	local base = CFrame.new(ctx.origin + Vector3.new(spec.x, ground + plinth, spec.z))
		* CFrame.Angles(0, math.rad(yaw), 0)
	local building = model(Builder.folder(ctx, "Buildings"), spec.name)
	-- The interior box, for the client's roof lift (map-local footprint in world space).
	building:SetAttribute("Interior", Vector3.new(spec.width - WALL * 2, height, spec.depth - WALL * 2))
	building:SetAttribute("InteriorCFrame", base * CFrame.new(0, height / 2, 0))
	-- Plinth down into the ground, then the floor on it.
	Builder.part(
		building,
		Vector3.new(spec.width + 1, plinth + 3, spec.depth + 1),
		base * CFrame.new(0, -(plinth + 3) / 2, 0),
		"concreteDark",
		"Plinth"
	)
	Builder.part(
		building,
		Vector3.new(spec.width - WALL * 2 + 0.05, 0.2, spec.depth - WALL * 2 + 0.05),
		base * CFrame.new(0, 0.1, 0),
		spec.floor or "floorPlanks",
		"Floor"
	)
	for _, side in { "N", "S", "E", "W" } do
		wallSide(ctx, building, base, spec, side :: any, height)
	end
	-- Corner posts in trim.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Builder.part(
				building,
				Vector3.new(1, height, 1),
				base * CFrame.new(sx * (spec.width / 2 - 0.4), height / 2, sz * (spec.depth / 2 - 0.4)),
				spec.trim or "trim",
				"Corner"
			).Size =
				Vector3.new(1, if (spec.ruin or 0) > 0 then height * 0.55 else height, 1)
		end
	end
	local roof = spec.roof or "gable"
	if roof == "gable" then
		gableRoof(ctx, building, base, spec, height)
	elseif roof == "flat" then
		flatRoof(ctx, building, base, spec, height)
	elseif roof == "shed" then
		shedRoof(ctx, building, base, spec, height)
	end
	if spec.porch then
		-- A plank porch with posts and a small lean-to roof.
		local south = spec.porch == "S"
		local length = if south then spec.width * 0.6 else spec.depth * 0.6
		local reach = 5
		local centre = if south
			then base * CFrame.new(0, -0.1, spec.depth / 2 + reach / 2)
			else base * CFrame.new(spec.width / 2 + reach / 2, -0.1, 0) * CFrame.Angles(0, math.rad(90), 0)
		local porch = model(building, "Porch")
		Builder.part(porch, Vector3.new(length, 0.4, reach), centre, "boards", "Deck")
		for _, sign in { -1, 1 } do
			Builder.part(
				porch,
				Vector3.new(0.5, 7.5, 0.5),
				centre * CFrame.new(sign * (length / 2 - 0.5), 3.9, reach / 2 - 0.5),
				"trim"
			)
		end
		local roofPart = Builder.part(
			porch,
			Vector3.new(length + 1, 0.35, reach + 1),
			centre * CFrame.new(0, 7.9, 0) * CFrame.Angles(math.rad(-10), 0, 0),
			spec.roofPaint or "roofMetal",
			"Awning"
		)
		roofPart:SetAttribute("Porch", true)
		porch:SetAttribute("Layer", "roof")
	end
	local inverse = base:Inverse()
	local function inside(x: number, z: number): boolean
		local here = inverse * (ctx.origin + Vector3.new(x, ground + plinth, z))
		return math.abs(here.X) < spec.width / 2 and math.abs(here.Z) < spec.depth / 2
	end
	return { model = building, frame = base, floor = ground + plinth + 0.2, inside = inside }
end

-- A point in a building's own frame (x along its width, z along its depth), map-local.
function Builder.local2(ctx: Ctx, building: Building, x: number, z: number): Vector2
	local world = building.frame * Vector3.new(x, 0, z)
	return Vector2.new(world.X - ctx.origin.X, world.Z - ctx.origin.Z)
end

-- A spot on a building's floor: map-local x, z and the lift above the ground there.
function Builder.inside(ctx: Ctx, building: Building, x: number, z: number): (number, number, number)
	local p = Builder.local2(ctx, building, x, z)
	return p.X, p.Y, building.floor - ctx.groundHeight(p.X, p.Y)
end

-- Fences, rails, slabs ------------------------------------------------------------------------------------

-- A weathered rail fence along a polyline, with a few broken rails and gaps.
function Builder.railFence(ctx: Ctx, path: { Vector2 }, paint: string?)
	local holder = model(Builder.folder(ctx, "Fences"), "RailFence")
	local key = paint or "trim"
	for index = 1, #path - 1 do
		local a, b = path[index], path[index + 1]
		local length = (b - a).Magnitude
		local posts = math.max(1, math.floor(length / 6))
		for step = 0, posts do
			local p = a:Lerp(b, step / posts)
			local y = ctx.groundHeight(p.X, p.Y)
			Builder.part(
				holder,
				Vector3.new(0.55, 4.4, 0.55),
				CFrame.new(ctx.origin + Vector3.new(p.X, y + 1.6, p.Y))
					* CFrame.Angles(0, ctx.rng:NextNumber() * 0.3, 0),
				key,
				"Post"
			)
			if step < posts and ctx.rng:NextNumber() > 0.12 then
				local q = a:Lerp(b, (step + 1) / posts)
				local mid = (p + q) / 2
				local yMid = (y + ctx.groundHeight(q.X, q.Y)) / 2
				local dir = q - p
				local yaw = math.atan2(-dir.Y, dir.X)
				for _, rail in { 1.4, 2.9 } do
					if ctx.rng:NextNumber() > 0.1 then
						local droop = if ctx.rng:NextNumber() < 0.1 then math.rad(14) else 0
						Builder.part(
							holder,
							Vector3.new(dir.Magnitude + 0.4, 0.35, 0.25),
							CFrame.new(ctx.origin + Vector3.new(mid.X, yMid + rail, mid.Y))
								* CFrame.Angles(0, yaw, droop),
							key,
							"Rail"
						)
					end
				end
			end
		end
		Builder.breathe(ctx, posts * 3)
	end
end

-- A sheet-metal or concrete wall along a polyline (yards, depot perimeter).
function Builder.panelWall(ctx: Ctx, path: { Vector2 }, paint: string, height: number, gapEvery: number?)
	local holder = model(Builder.folder(ctx, "Fences"), "PanelWall")
	holder:SetAttribute("Layer", "fill")
	for index = 1, #path - 1 do
		local a, b = path[index], path[index + 1]
		local length = (b - a).Magnitude
		local count = math.max(1, math.floor(length / 6))
		for step = 0, count - 1 do
			local p = a:Lerp(b, step / count)
			local q = a:Lerp(b, (step + 1) / count)
			if gapEvery and step % gapEvery == gapEvery - 1 then
				continue
			end
			local mid = (p + q) / 2
			local y = math.min(ctx.groundHeight(p.X, p.Y), ctx.groundHeight(q.X, q.Y))
			local dir = q - p
			local lean = (ctx.rng:NextNumber() - 0.5) * 0.08
			Builder.part(
				holder,
				Vector3.new(dir.Magnitude + 0.1, height, 0.3),
				CFrame.new(ctx.origin + Vector3.new(mid.X, y + height / 2 - 0.4, mid.Y))
					* CFrame.Angles(0, math.atan2(-dir.Y, dir.X), lean),
				paint,
				"Panel"
			)
		end
		Builder.breathe(ctx, count)
	end
end

-- Railway track along a straight line: sleepers in gravel and two steel rails.
function Builder.track(ctx: Ctx, from: Vector2, to: Vector2)
	local holder = model(Builder.folder(ctx, "Rails"), "Track")
	local dir = to - from
	local length = dir.Magnitude
	local yaw = math.atan2(-dir.Y, dir.X)
	local mid = (from + to) / 2
	local y = ctx.groundHeight(mid.X, mid.Y)
	local frame = CFrame.new(ctx.origin + Vector3.new(mid.X, y, mid.Y)) * CFrame.Angles(0, yaw, 0)
	Builder.part(holder, Vector3.new(length, 0.5, 7.5), frame * CFrame.new(0, 0.05, 0), "gravel", "Ballast")
	for u = -length / 2 + 1, length / 2 - 1, 2.6 do
		local sleeper =
			Builder.part(holder, Vector3.new(1, 0.4, 6.2), frame * CFrame.new(u, 0.45, 0), "trim", "Sleeper")
		sleeper.CFrame *= CFrame.Angles(0, math.rad((ctx.rng:NextNumber() - 0.5) * 6), 0)
	end
	for _, side in { -1.9, 1.9 } do
		Builder.part(holder, Vector3.new(length, 0.45, 0.35), frame * CFrame.new(0, 0.85, side), "rust", "Rail")
	end
	Builder.breathe(ctx, length / 2.6 + 3)
end

-- A raised concrete slab (loading dock, platform, plinth) with a ramp on one side.
function Builder.platform(ctx: Ctx, x: number, z: number, width: number, depth: number, height: number, yaw: number)
	local holder = model(Builder.folder(ctx, "Buildings"), "Platform")
	local base = Builder.frame(ctx, x, z, yaw)
	Builder.part(
		holder,
		Vector3.new(width, height + 2, depth),
		base * CFrame.new(0, (height - 2) / 2, 0),
		"concrete",
		"Slab"
	)
	-- An edge kerb, and a ramp off the east end.
	Builder.part(
		holder,
		Vector3.new(width, 0.3, 0.6),
		base * CFrame.new(0, height + 0.05, depth / 2 - 0.3),
		"concreteDark"
	)
	local rampLength = height * 3
	local ramp = Builder.wedge(
		holder,
		Vector3.new(6, height, rampLength),
		base * CFrame.new(width / 2 + rampLength / 2, height / 2, 0) * CFrame.Angles(0, math.rad(-90), 0),
		"concrete"
	)
	ramp.Name = "Ramp"
	Builder.breathe(ctx, 4)
end

-- A corrugated shipping container, doors to the east.
function Builder.shippingContainer(ctx: Ctx, x: number, z: number, yaw: number, paint: string, stacked: boolean?)
	local holder = model(Builder.folder(ctx, "Dressing"), "ShippingContainer")
	holder:SetAttribute("Layer", "frame")
	local lift = if stacked then 8.6 else 0
	local base = Builder.frame(ctx, x, z, yaw, lift)
	local size = Vector3.new(20, 8.5, 8)
	Builder.part(holder, size, base * CFrame.new(0, size.Y / 2, 0), paint, "Box")
	-- Ribs along the sides and a dark door end.
	for u = -9, 9, 1.5 do
		for _, side in { -1, 1 } do
			Builder.part(holder, Vector3.new(0.35, 8.1, 0.2), base * CFrame.new(u, 4.25, side * 4.08), paint, "Rib")
		end
	end
	Builder.part(holder, Vector3.new(0.2, 8.1, 7.6), base * CFrame.new(10.05, 4.25, 0), "darkMetal", "Doors")
	for _, side in { -1.6, 1.6 } do
		Builder.part(holder, Vector3.new(0.3, 7, 0.25), base * CFrame.new(10.2, 4.25, side), "rust", "Bar")
	end
	Builder.breathe(ctx, 30)
end

-- Rubble: a low heap of broken masonry and planks.
function Builder.rubble(ctx: Ctx, x: number, z: number, radius: number, paint: string?)
	local holder = model(Builder.folder(ctx, "Dressing"), "Rubble")
	for _ = 1, math.floor(radius * 2.5) do
		local angle = ctx.rng:NextNumber() * math.pi * 2
		local d = math.sqrt(ctx.rng:NextNumber()) * radius
		local px, pz = x + math.cos(angle) * d, z + math.sin(angle) * d
		local s = 0.6 + ctx.rng:NextNumber() * 1.4 * (1 - d / radius * 0.6)
		local chunk = Builder.part(
			holder,
			Vector3.new(s * (0.8 + ctx.rng:NextNumber()), s * 0.6, s),
			Builder.frame(ctx, px, pz, ctx.rng:NextNumber() * 360, s * 0.15)
				* CFrame.Angles(ctx.rng:NextNumber() * 0.6, 0, ctx.rng:NextNumber() * 0.6),
			if ctx.rng:NextNumber() < 0.2 then "trim" else (paint or "rubble"),
			"Chunk"
		)
		chunk.CanCollide = s > 1.2
	end
	Builder.breathe(ctx, radius * 2.5)
end

-- Containers ----------------------------------------------------------------------------------------------

--[[
	A lootable container spot: the visible container with its hinged lid or door,
	and its RunMarker. The Containers service decides which spots hold loot this
	lobby (ContainerId); the client opens the lid when one is searched and shows
	unstocked ones open and empty.
	Kinds: crate, strongbox, locker, cabinet, pack, trunk (a car's open boot: the
	sack inside goes once searched).
]]
function Builder.container(
	ctx: Ctx,
	kind: string,
	x: number,
	z: number,
	yaw: number,
	parent: Instance?,
	lift: number?
): Model
	local holder = model(parent or Builder.folder(ctx, "Containers"), `Container_{kind}`)
	holder:SetAttribute("Kind", kind)
	local base = Builder.frame(ctx, x, z, yaw, lift)
	local body: BasePart
	if kind == "crate" or kind == "strongbox" then
		local metal = kind == "strongbox"
		local size = if metal then Vector3.new(3.4, 2, 2.2) else Vector3.new(4, 2.6, 2.8)
		local shell = if metal then "darkMetal" else "boards"
		body = Builder.part(holder, size, base * CFrame.new(0, size.Y / 2, 0), shell, "Body")
		-- Corner straps and a rim.
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Builder.part(
					holder,
					Vector3.new(0.3, size.Y + 0.05, 0.3),
					base * CFrame.new(sx * (size.X / 2 - 0.1), size.Y / 2, sz * (size.Z / 2 - 0.1)),
					if metal then "rust" else "darkMetal"
				)
			end
		end
		if not metal then
			for _, sx in { -1, 0, 1 } do
				Builder.part(
					holder,
					Vector3.new(0.25, 0.35, size.Z + 0.08),
					base * CFrame.new(sx * size.X / 3, size.Y * 0.5, 0),
					"trim"
				)
			end
		end
		-- The lid hinges along its back (north) edge.
		local lid = model(holder, "Lid")
		local hinge = base * CFrame.new(0, size.Y, -size.Z / 2)
		lid:SetAttribute("Hinge", hinge)
		lid:SetAttribute("OpenAngle", if metal then 100 else 110)
		Builder.part(
			lid,
			Vector3.new(size.X + 0.2, 0.4, size.Z + 0.2),
			hinge * CFrame.new(0, 0.2, size.Z / 2),
			if metal then "darkMetal" else "boards",
			"Lid"
		)
		Builder.part(
			lid,
			Vector3.new(size.X + 0.25, 0.42, 0.3),
			hinge * CFrame.new(0, 0.2, size.Z),
			if metal then "rust" else "darkMetal"
		)
		-- What's inside (seen once it's open): a dark void.
		Builder.part(
			holder,
			Vector3.new(size.X - 0.5, 0.1, size.Z - 0.5),
			base * CFrame.new(0, size.Y - 0.3, 0),
			"void",
			"Inside"
		)
	elseif kind == "locker" or kind == "cabinet" then
		local tall = kind == "locker"
		local size = if tall then Vector3.new(2.2, 7, 2) else Vector3.new(3.2, 4.2, 1.8)
		local paint = if tall then "paintedMetal" else "rust"
		body = Builder.part(holder, size, base * CFrame.new(0, size.Y / 2, 0), paint, "Body")
		Builder.part(
			holder,
			Vector3.new(size.X - 0.3, size.Y - 0.3, 0.1),
			base * CFrame.new(0, size.Y / 2, size.Z / 2 - 0.1),
			"void",
			"Inside"
		)
		-- The door hinges on its west edge (front faces south).
		local door = model(holder, "Door")
		local hinge = base * CFrame.new(-size.X / 2, 0, size.Z / 2)
		door:SetAttribute("Hinge", hinge)
		door:SetAttribute("OpenAngle", -105)
		door:SetAttribute("Axis", "Y")
		Builder.part(
			door,
			Vector3.new(size.X, size.Y - 0.1, 0.18),
			hinge * CFrame.new(size.X / 2, size.Y / 2, 0.09),
			paint,
			"Panel"
		)
		if tall then
			for v = 0, 3 do
				Builder.part(
					door,
					Vector3.new(1.2, 0.12, 0.08),
					hinge * CFrame.new(size.X / 2, size.Y - 0.8 - v * 0.3, 0.21),
					"darkMetal",
					"Vent"
				)
			end
		else
			for v = 1, 2 do
				Builder.part(
					door,
					Vector3.new(size.X - 0.4, 0.1, 0.08),
					hinge * CFrame.new(size.X / 2, size.Y * v / 3, 0.2),
					"darkMetal",
					"Seam"
				)
			end
		end
		Builder.part(
			door,
			Vector3.new(0.15, 0.6, 0.15),
			hinge * CFrame.new(size.X - 0.3, size.Y / 2, 0.25),
			"steel",
			"Handle"
		)
	elseif kind == "pack" then
		-- A dropped duffel: the sack model where approved; it sags flat once searched.
		local sack = Builder.kit(
			ctx,
			{ "EO_SupplySacksMesh" },
			x,
			z,
			yaw,
			{ height = 2.2, parent = holder :: Instance, lift = lift }
		)
		local anyPart = if sack then sack:FindFirstChildWhichIsA("BasePart", true) else nil
		if anyPart then
			body = anyPart
			holder:SetAttribute("Sags", true)
		else
			body = Builder.part(holder, Vector3.new(2.6, 1.4, 1.6), base * CFrame.new(0, 0.7, 0), "tarp", "Body")
		end
	else -- trunk: the sack in a car's open boot; the car is placed by the layout
		local sack = Builder.kit(
			ctx,
			{ "EO_SupplySacksMesh" },
			x,
			z,
			yaw,
			{ height = 1.4, parent = holder :: Instance, lift = lift }
		)
		local anyPart = if sack then sack:FindFirstChildWhichIsA("BasePart", true) else nil
		body = anyPart or Builder.part(holder, Vector3.new(2, 1, 1.4), base * CFrame.new(0, 0.5, 0), "tarp", "Body")
		holder:SetAttribute("Empties", true)
	end
	body.Name = "Body"
	body:SetAttribute("RunMarker", "container")
	body:SetAttribute("Kind", kind)
	holder.PrimaryPart = body
	CollectionService:AddTag(holder, Builder.CONTAINER_TAG)
	Builder.breathe(ctx, 10)
	return holder
end

-- Street furniture (exact geometry, shared by the town and the depot) ---------------------------------

-- A street lamp: a pole with an arm; `lit` ones still glow (warm), the rest are dead.
function Builder.streetLamp(ctx: Ctx, x: number, z: number, yaw: number, lit: boolean)
	local holder = model(Builder.folder(ctx, "Dressing"), "StreetLamp")
	local base = Builder.frame(ctx, x, z, yaw)
	Builder.part(holder, Vector3.new(0.6, 14, 0.6), base * CFrame.new(0, 7, 0), "darkMetal", "Pole")
	Builder.part(holder, Vector3.new(0.35, 0.35, 4), base * CFrame.new(0, 13.6, 1.8), "darkMetal", "Arm")
	local head = Builder.part(holder, Vector3.new(1.4, 0.5, 2), base * CFrame.new(0, 13.4, 3.6), "steel", "Head")
	if lit then
		local glow = Instance.new("SpotLight")
		glow.Face = Enum.NormalId.Bottom
		glow.Angle = 100
		glow.Range = 24
		glow.Brightness = 1.6
		glow.Color = Color3.fromRGB(255, 190, 130)
		glow.Shadows = true
		glow.Parent = head
		-- A warm lens under the head, not a neon block (it reads by day as well as night).
		local lens =
			Builder.part(holder, Vector3.new(1, 0.08, 1.5), head.CFrame * CFrame.new(0, -0.27, 0), "trimLight", "Lens")
		lens.Material = Enum.Material.Glass
		lens.Color = Color3.fromRGB(255, 220, 170)
		lens.Transparency = 0.2
	end
	Builder.breathe(ctx, 3)
end

-- A concrete jersey barrier, knocked a little askew.
function Builder.barrier(ctx: Ctx, x: number, z: number, yaw: number)
	local holder = model(Builder.folder(ctx, "Dressing"), "Barrier")
	local base = Builder.frame(ctx, x, z, yaw + (ctx.rng:NextNumber() - 0.5) * 10)
	Builder.part(holder, Vector3.new(6, 1.2, 2.2), base * CFrame.new(0, 0.6, 0), "concrete")
	Builder.part(holder, Vector3.new(6, 1.6, 1.1), base * CFrame.new(0, 1.9, 0), "concrete")
	Builder.part(holder, Vector3.new(6.02, 0.25, 1.12), base * CFrame.new(0, 2.1, 0), "rust", "Stripe")
	Builder.breathe(ctx, 3)
end

-- A dumpster with its lid half up.
function Builder.dumpster(ctx: Ctx, x: number, z: number, yaw: number)
	local holder = model(Builder.folder(ctx, "Dressing"), "Dumpster")
	local base = Builder.frame(ctx, x, z, yaw)
	Builder.part(holder, Vector3.new(6, 4, 3.6), base * CFrame.new(0, 2.2, 0), "paintedMetal", "Bin")
	Builder.part(
		holder,
		Vector3.new(6.2, 0.3, 3.8),
		base * CFrame.new(0, 4.5, -1.2) * CFrame.Angles(math.rad(35), 0, 0),
		"darkMetal",
		"Lid"
	)
	for _, side in { -2.6, 2.6 } do
		Builder.part(holder, Vector3.new(0.5, 0.5, 0.5), base * CFrame.new(side, 0.25, 1.4), "darkMetal", "Wheel")
	end
	Builder.breathe(ctx, 4)
end

-- A park bench of slats on iron legs.
function Builder.bench(ctx: Ctx, x: number, z: number, yaw: number)
	local holder = model(Builder.folder(ctx, "Dressing"), "Bench")
	local base = Builder.frame(ctx, x, z, yaw)
	for slat = -1, 1 do
		Builder.part(holder, Vector3.new(5, 0.2, 0.4), base * CFrame.new(0, 1.6, slat * 0.5), "boards")
	end
	Builder.part(
		holder,
		Vector3.new(5, 1, 0.2),
		base * CFrame.new(0, 2.5, 0.85) * CFrame.Angles(math.rad(-12), 0, 0),
		"boards"
	)
	for _, side in { -2.2, 2.2 } do
		Builder.part(holder, Vector3.new(0.25, 1.6, 1.6), base * CFrame.new(side, 0.8, 0.2), "darkMetal")
	end
	Builder.breathe(ctx, 6)
end

-- A wooden utility pole with a crossarm; `wireTo` strings a sagging wire to the next pole.
function Builder.utilityPole(ctx: Ctx, x: number, z: number, wireTo: Vector2?)
	local holder = model(Builder.folder(ctx, "Dressing"), "UtilityPole")
	local base = Builder.frame(ctx, x, z, 0)
	Builder.part(holder, Vector3.new(0.9, 20, 0.9), base * CFrame.new(0, 10, 0), "trim", "Pole")
	Builder.part(holder, Vector3.new(5, 0.4, 0.4), base * CFrame.new(0, 18.5, 0), "trim", "Arm")
	if wireTo then
		local from = Builder.at(ctx, x, z, 18.7)
		local to = Builder.at(ctx, wireTo.X, wireTo.Y, 18.7)
		local mid = (from + to) / 2 - Vector3.new(0, 1.4, 0)
		for _, sag in { { from, mid }, { mid, to } } do
			local a, b = sag[1], sag[2]
			local wire = Builder.part(
				holder,
				Vector3.new(0.08, 0.08, (b - a).Magnitude),
				CFrame.lookAt((a + b) / 2, b),
				"darkMetal",
				"Wire"
			)
			wire.CanCollide = false
			wire.CastShadow = false
		end
	end
	Builder.breathe(ctx, 4)
end

-- A road sign on a post (a blank weathered plate: no text in the world).
function Builder.sign(ctx: Ctx, x: number, z: number, yaw: number, paint: string)
	local holder = model(Builder.folder(ctx, "Dressing"), "Sign")
	local base = Builder.frame(ctx, x, z, yaw)
	Builder.part(holder, Vector3.new(0.25, 7, 0.25), base * CFrame.new(0, 3.5, 0), "steel")
	Builder.part(
		holder,
		Vector3.new(2.6, 2.6, 0.15),
		base * CFrame.new(0, 6.4, 0.15) * CFrame.Angles(0, 0, math.rad(45)),
		paint
	)
	Builder.breathe(ctx, 2)
end

-- Lights ---------------------------------------------------------------------------------------------------

-- A warm hanging lamp or a cold flicker, for interiors and yards (ART_DIRECTION §5).
--[[
	A tarp lean-to: a ridge on two poles, the tarp sloping from it to the ground behind,
	pegged out with guy ropes. Its open side faces the way `yaw` points (0 is north).
	Returns the frame at its foot, for placing things under it.
]]
function Builder.leanTo(
	ctx: Ctx,
	name: string,
	x: number,
	z: number,
	yaw: number,
	paint: string?,
	width: number?
): CFrame
	local folder = model(Builder.folder(ctx, "Dressing"), name)
	local base = Builder.frame(ctx, x, z, yaw)
	local ridge, reach = 7, 8 -- the ridge's height, and how far back the tarp meets the ground
	local wide = width or 11.4
	local post = wide / 2 - 0.7
	for _, side in { -post, post } do
		Builder.part(
			folder,
			Vector3.new(0.4, ridge + 0.3, 0.4),
			base * CFrame.new(side, ridge / 2, -3.5),
			"trim",
			"Pole"
		)
	end
	Builder.part(folder, Vector3.new(wide - 0.4, 0.25, 0.3), base * CFrame.new(0, ridge, -3.5), "trim", "Ridge")
	local length = math.sqrt(reach * reach + ridge * ridge)
	local slope = math.atan2(ridge - 0.2, reach)
	Builder.part(
		folder,
		Vector3.new(wide, 0.12, length),
		base * CFrame.new(0, ridge / 2 + 0.1, -3.5 + reach / 2) * CFrame.Angles(slope, 0, 0),
		paint or "tarp",
		"Tarp"
	)
	-- Guy ropes from the pole tops out to the sides, and pegs along the tarp's foot.
	local spread = math.atan2(ridge, 4)
	for _, sign in { -1, 1 } do
		local rope = Builder.part(
			folder,
			Vector3.new(math.sqrt(16 + ridge * ridge), 0.1, 0.1),
			base * CFrame.new(sign * (post + 2), ridge / 2, -3.5) * CFrame.Angles(0, 0, -sign * spread),
			"cloth",
			"Rope"
		)
		rope.CanCollide = false
		Builder.part(folder, Vector3.new(0.3, 0.6, 0.3), base * CFrame.new(sign * 9, 0.3, -3.5), "trim", "Peg")
		Builder.part(
			folder,
			Vector3.new(0.3, 0.6, 0.3),
			base * CFrame.new(sign * 5.4, 0.3, -3.5 + reach),
			"trim",
			"Peg"
		)
	end
	return base
end

-- A map-local point from a world frame (for placing things relative to a built piece).
function Builder.toLocal(ctx: Ctx, frame: CFrame): (number, number)
	local p = frame.Position - ctx.origin
	return p.X, p.Z
end

function Builder.lamp(ctx: Ctx, x: number, z: number, height: number, warm: boolean, range: number?)
	local part = Builder.part(
		Builder.folder(ctx, "Lights"),
		Vector3.new(0.6, 0.6, 0.6),
		CFrame.new(Builder.at(ctx, x, z, height)),
		if warm then "trimLight" else "steel",
		"Lamp"
	)
	part.CanCollide = false
	part.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = if warm then Color3.fromRGB(255, 186, 120) else Color3.fromRGB(150, 190, 210)
	light.Range = range or 16
	light.Brightness = if warm then 1.1 else 0.6
	light.Shadows = false
	light.Parent = part
end

-- Edges -------------------------------------------------------------------------------------------

export type EdgeSpec = {
	half: number, -- the playable half-size
	names: { string }, -- the trees of the wall
	depth: number?, -- how far past the edge the dense wall runs (default 70)
	spacing: number?, -- tree spacing in the wall (default 9)
	gaps: { Vector2 }?, -- trail ends kept open (the Light fog's marked exits)
	height: number?, -- tree height (default 20, varied)
	dead: { string }?, -- a share of dead trees mixed in
	deadShare: number?, -- how many of them are dead (default 0.12)
	clear: ((x: number, z: number) -> boolean)?, -- roads, rails and water kept free
}

-- A deep wall of trees all round the playable area, so no zoom shows the map's end:
-- dense from just inside the edge to `depth` past it, then thinning out further.
-- Trail ends in `gaps` stay open.
function Builder.treeWall(ctx: Ctx, spec: EdgeSpec)
	local rng = ctx.rng
	local half = spec.half
	local depth = spec.depth or 70
	local spacing = spec.spacing or 9
	local height = spec.height or 20
	local gaps: { Vector2 } = spec.gaps or {}
	local placed = 0
	local function open(x: number, z: number): boolean
		for _, gap in gaps do
			if (Vector2.new(x, z) - gap).Magnitude < 16 then
				return true
			end
		end
		return false
	end
	local reach = half + depth + 40
	for gx = -reach, reach, spacing do
		for gz = -reach, reach, spacing do
			local x = gx + (rng:NextNumber() - 0.5) * spacing * 0.9
			local z = gz + (rng:NextNumber() - 0.5) * spacing * 0.9
			local edge = math.max(math.abs(x), math.abs(z))
			local inner = edge > half - 6 and edge < half + depth
			local outer = edge >= half + depth and rng:NextNumber() < 0.45
			local kept = spec.clear and (spec.clear :: (number, number) -> boolean)(x, z)
			if (inner or outer) and not open(x, z) and not kept then
				local dead = spec.dead and rng:NextNumber() < (spec.deadShare or 0.12)
				local names = if dead then spec.dead :: { string } else spec.names
				Builder.kit(ctx, names, x, z, rng:NextNumber() * 360, {
					height = height * (0.8 + rng:NextNumber() * 0.5),
					canopy = edge < half + 12,
				})
				placed += 1
				if placed % 60 == 0 then
					task.wait()
				end
			end
		end
	end
end

-- A low fog bank drifting along the edge: big soft puffs that hide the wall's far side
-- (the Fog itself, at the location's tier colour).
function Builder.fogBank(ctx: Ctx, half: number, color: Color3, density: number?)
	local folder = Builder.folder(ctx, "FogBank")
	local step = 36
	local rate = density or 1.4
	for side = 1, 4 do
		for t = -half - step, half + step, step do
			local x, z
			if side == 1 then
				x, z = t, -half - 14
			elseif side == 2 then
				x, z = t, half + 14
			elseif side == 3 then
				x, z = -half - 14, t
			else
				x, z = half + 14, t
			end
			local anchor = Builder.part(folder, Vector3.new(1, 1, 1), Builder.frame(ctx, x, z, 0, 5), "void", "Bank")
			anchor.Transparency = 1
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			local puffs = Instance.new("ParticleEmitter")
			puffs.Texture = "rbxasset://textures/particles/smoke_main.dds"
			puffs.Color = ColorSequence.new(color)
			puffs.LightEmission = 0.05
			puffs.LightInfluence = 0.8
			puffs.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 0.72),
				NumberSequenceKeypoint.new(0.75, 0.78),
				NumberSequenceKeypoint.new(1, 1),
			})
			puffs.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 26), NumberSequenceKeypoint.new(1, 44) })
			puffs.Lifetime = NumberRange.new(14, 20)
			puffs.Rate = rate
			puffs.Speed = NumberRange.new(0.3, 1.2)
			puffs.SpreadAngle = Vector2.new(180, 20)
			puffs.Rotation = NumberRange.new(0, 360)
			puffs.RotSpeed = NumberRange.new(-4, 4)
			puffs.Shape = Enum.ParticleEmitterShape.Box
			puffs.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
			puffs.Parent = anchor
			anchor.Size = Vector3.new(step, 6, 18)
		end
	end
end

return Builder
