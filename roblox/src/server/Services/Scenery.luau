--!strict
--[[
	Scenery: builds the Neighbourhood around the plots from code, so the repo is the
	master copy of the place (ARCHITECTURE "the repo is the master copy"). Every part
	is deterministic (one seed) and built only when it's missing, so a hand-tuned
	place keeps its world while a fresh `rojo build` place gets the same one from here.

	- Lighting: properties, atmosphere, colour grade, bloom, sun rays and sky. The
	  day/night cycle then eases these on each client (Controllers/DayNight).
	- Terrain (when the ground is empty): a grass slab with seeded patches of leafy
	  grass, earth and mud (three ground layers, ART_DIRECTION §4), a mud road between
	  the rows and an earth pad under every plot.
	- Dressing (when World.Dressing is missing): lamps flanking each plot front, a
	  couple of camp props, a ring of grass tufts, rocks and pebbles around each pad,
	  pines along the edges and a wrecked car.
	- The Trailhead at the road's west end (where Fog runs leave): lamps, crates and a
	  lit sign. The fog wall: drifting fog banks around the Neighbourhood's edge.
	- The Hearth on the road between the rows: its light reaches far, and a warm glow
	  on the ground marks its radius (9.4).
]]

local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local Models = require("../World/Models")

local Scenery = {}

local SEED = 20261108
local DEFAULT_ORIGIN = Vector3.new(0, 2.06, 900)
local HEARTH_RADIUS = 70
local tuning = Content.Tuning.plots
local GRID_STUDS = Content.Tuning.building.plotCells * Grid.CELL_STUDS

-- Neighbourhood extents (studs from the world origin).
local HALF_WIDTH = tuning.columns * tuning.spacingStuds / 2 + tuning.marginStuds
local HALF_DEPTH = tuning.rowGapStuds / 2 + tuning.marginStuds * 2 + GRID_STUDS

local function worldFolder(): Instance
	local world = workspace:FindFirstChild("World")
	if world == nil then
		local made = Instance.new("Folder")
		made.Name = "World"
		made:SetAttribute("Origin", DEFAULT_ORIGIN)
		made.Parent = workspace
		world = made
	end
	return world :: Instance
end

local function originOf(world: Instance): Vector3
	local origin = world:GetAttribute("Origin")
	return if typeof(origin) == "Vector3" then origin else DEFAULT_ORIGIN
end

-- Plot centres (x, z offsets from the origin), matching Plots' default layout.
local function plotCentres(): { { x: number, z: number, front: number } }
	local list = {}
	for index = 1, tuning.count do
		local column = (index - 1) % tuning.columns
		local row = (index - 1) // tuning.columns
		local x = (column - (tuning.columns - 1) / 2) * tuning.spacingStuds
		local offset = tuning.rowGapStuds / 2 + tuning.marginStuds + GRID_STUDS / 2
		table.insert(list, { x = x, z = if row == 0 then -offset else offset, front = if row == 0 then 1 else -1 })
	end
	return list
end

-- Lighting ------------------------------------------------------------------------------------------

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = Lighting
	return made
end

local function lighting()
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.GeographicLatitude = 38
	Lighting.ColorShift_Top = Color3.fromRGB(240, 236, 228)
	Lighting.ColorShift_Bottom = Color3.fromRGB(60, 64, 72)
	local atmosphere = ensure("Atmosphere", "EO_Atmosphere") :: Atmosphere
	atmosphere.Density = 0.34
	atmosphere.Offset = 0.16
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1.8
	local grade = ensure("ColorCorrectionEffect", "EO_Grade") :: ColorCorrectionEffect
	grade.Contrast = 0.12
	grade.Saturation = -0.2
	local bloom = ensure("BloomEffect", "EO_Bloom") :: BloomEffect
	bloom.Intensity = 0.55
	bloom.Size = 24
	bloom.Threshold = 1.35
	local rays = ensure("SunRaysEffect", "EO_SunRays") :: SunRaysEffect
	rays.Intensity = 0.05
	rays.Spread = 0.55
	local sky = ensure("Sky", "EO_Sky") :: Sky
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 1200
end

-- Terrain -------------------------------------------------------------------------------------------

local function groundIsEmpty(origin: Vector3): boolean
	local region = Region3.new(origin - Vector3.new(8, 8, 8), origin + Vector3.new(8, 4, 8)):ExpandToGrid(4)
	local materials = workspace.Terrain:ReadVoxels(region, 4) :: any
	local size: Vector3 = materials.Size -- the 3D array carries its size; index it numerically
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				if materials[x][y][z] ~= Enum.Material.Air then
					return false
				end
			end
		end
	end
	return true
end

-- The muted palette the look test settled on (ART_DIRECTION §4). The ground materials
-- take their variant and tint from Art.ground.
local TERRAIN_COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Rock] = Color3.fromRGB(84, 82, 76), -- QA: lighter read as snow blotches
	[Enum.Material.Slate] = Color3.fromRGB(88, 89, 86),
	[Enum.Material.Pavement] = Color3.fromRGB(120, 118, 112),
	[Enum.Material.Asphalt] = Color3.fromRGB(78, 82, 88),
	[Enum.Material.Basalt] = Color3.fromRGB(52, 48, 46), -- ash and scorch around the Hearth
}

local function terrain(origin: Vector3, random: Random)
	for material, color in TERRAIN_COLORS do
		workspace.Terrain:SetMaterialColor(material, color)
	end
	for material, look in Art.ground do
		MaterialService:SetBaseMaterialOverride(material, look.variant)
		workspace.Terrain:SetMaterialColor(material, look.tint)
	end
	if not groundIsEmpty(origin) then
		return
	end
	local terrainService = workspace.Terrain
	local pad = 260 -- ground past the edges, under the fog wall and beyond
	local width, depth = HALF_WIDTH * 2 + pad * 2, HALF_DEPTH * 2 + pad * 2
	local top = origin.Y -- the flat ground's surface; foundations stand on it
	local roadHalf = tuning.rowGapStuds * 0.4
	local plots = plotCentres()
	local seedX, seedZ = random:NextNumber(0, 1000), random:NextNumber(0, 1000)

	local function outside(x: number, z: number): number
		return math.max(math.abs(x) - HALF_WIDTH, math.abs(z) - HALF_DEPTH)
	end

	-- Every surface material comes from this one function, painted in one pass
	-- (ART_DIRECTION §4): mid-layer wear first (Hearth scorch, the road, plot pads,
	-- worn paths), then macro zones from layered noise, drying to dead grass toward
	-- the fog. Nothing here changes the height.
	local function surface(x: number, z: number): Enum.Material
		local grain = math.noise((x + seedX) / 6, (z + seedZ) / 6, 3.7)
		local fromHearth = math.sqrt(x * x + z * z)
		if Art.approved.Hearth and fromHearth < 5 + math.noise(x / 4, z / 4, 6.6) * 1.5 then
			return Enum.Material.Basalt -- ash and scorch under the Hearth's fire (with the Hearth only)
		end
		if fromHearth < 14 then
			return Enum.Material.Ground -- the trodden plaza where the Hearth will stand
		end
		-- The road: a compacted dirt track with a gravel crown down the middle, ragged verges.
		local ragged = math.noise(x / 9, 0, 3.3) * 2.5 + math.noise(x / 27, 0, 8.1) * 4 + grain * 1.5
		if math.abs(z) < roadHalf + ragged and math.abs(x) < HALF_WIDTH + 60 then
			local sway = math.noise(x / 30, 0, 4.4) * 1.2
			if math.abs(z + sway) < 2 + grain * 0.8 then
				return Enum.Material.Ground
			end
			return Enum.Material.Mud
		end
		for _, centre in plots do
			local dx, dz = math.abs(x - centre.x), math.abs(z - centre.z)
			local padHalf = GRID_STUDS / 2 + 4
			if dx < padHalf and dz < padHalf then
				-- Trodden earth in patches, more worn toward the middle; never one flat colour.
				local worn = math.noise((x + seedX) / 16, (z + seedZ) / 16, 9.1)
					+ (1 - math.max(dx, dz) / padHalf) * 0.45
				-- No plain Grass on a plot: its wind blades would poke up through the decks.
				-- The grain breaks the border into islands of earth and litter.
				if worn + grain * 0.3 > 0.42 then
					return Enum.Material.Ground
				end
				return Enum.Material.LeafyGrass
			end
			-- A worn path from the plot's front edge to the road, wandering a little.
			local front = centre.z + centre.front * (GRID_STUDS / 2 + 4)
			local lo, hi = math.min(front, 0), math.max(front, 0)
			local wobble = math.noise(centre.x / 10, z / 14, 2.2) * 3
			if z > lo and z < hi and math.abs(x - centre.x - wobble) < 2.5 + grain then
				return Enum.Material.Ground -- a footpath about two survivors wide
			end
		end
		-- Out to the Trailhead along the road's line.
		if x < -HALF_WIDTH and x > -HALF_WIDTH - 66 and math.abs(z - math.noise(x / 20, 0, 5.5) * 4) < 3.5 then
			return Enum.Material.Ground
		end
		local edge = outside(x, z)
		local zones = math.noise((x + seedX) / 70, (z + seedZ) / 70, 0.31)
		local patches = math.noise((x + seedX) / 22, (z + seedZ) / 22, 1.73)
		local speckle = math.noise((x + seedX) / 8, (z + seedZ) / 8, 4.11)
		patches += grain * 0.15
		if edge > 0 and patches * 0.5 + edge / 90 > 0.42 then
			return Enum.Material.Sand -- dead, dry grass toward the fog
		elseif edge > 15 and speckle > 0.5 then
			return Enum.Material.Ground -- stony patches past the edge (QA2: bare Rock read as snow)
		elseif patches > 0.38 then
			return Enum.Material.Ground
		elseif zones + grain * 0.12 > 0.18 then
			return Enum.Material.LeafyGrass
		end
		return Enum.Material.Grass
	end

	-- Flat inside the neighbourhood; gently rolling beyond it.
	local function height(x: number, z: number): number
		local rise = math.clamp((outside(x, z) - 25) / 70, 0, 1)
		local hills = math.noise((x + seedX) / 55, (z + seedZ) / 55, 7.7) * 0.5 + 0.5
		return top + rise * hills * 9
	end

	-- Deep ground under everything, then the painted surface layers on top of it. This
	-- runs without yielding: nodes and plots are placed on the ground right after.
	local base = math.floor(top / 4) * 4 - 4 -- one full layer under the surface voxel
	terrainService:FillBlock(
		CFrame.new(Vector3.new(origin.X, base - 6, origin.Z)),
		Vector3.new(width, 12, depth),
		Enum.Material.Grass
	)
	local half = Vector3.new(width / 2, 0, depth / 2)
	local lo = Vector3.new(origin.X, base, origin.Z) - half
	local region = Region3.new(lo, lo + Vector3.new(width, 5 * 4, depth)):ExpandToGrid(4)
	local size = region.Size / 4
	local nx, ny, nz = math.floor(size.X), math.floor(size.Y), math.floor(size.Z)
	local minCorner = region.CFrame.Position - region.Size / 2
	local materials: { { { any } } }, occupancy: { { { number } } } = {}, {}
	for ix = 1, nx do
		local mx: { { any } }, ox: { { number } } = {}, {}
		for iy = 1, ny do
			mx[iy], ox[iy] = {}, {}
		end
		materials[ix], occupancy[ix] = mx, ox
		local x = minCorner.X + (ix - 0.5) * 4 - origin.X
		for iz = 1, nz do
			local z = minCorner.Z + (iz - 0.5) * 4 - origin.Z
			local ground = height(x, z)
			local material = surface(x, z)
			for iy = 1, ny do
				-- Roblox puts a partly filled top voxel's surface at its centre plus
				-- 4 x occupancy (measured: 0.25 -> centre + 1, 1 -> centre + 4), so a
				-- layer is full when the ground is a whole voxel above its centre.
				local centre = minCorner.Y + (iy - 0.5) * 4
				local fill = if centre + 4 <= ground then 1 else math.clamp((ground - centre) / 4, 0, 1)
				mx[iy][iz] = if fill > 0 then material else Enum.Material.Air
				ox[iy][iz] = fill
			end
		end
	end
	terrainService:WriteVoxels(region, 4, materials, occupancy)
end

-- Props ---------------------------------------------------------------------------------------------

-- Places a kit model (bottom pivot) at a world position, turned, at an absolute scale
-- (the scale the hand-built Neighbourhood used for that kit mesh).
local function place(folder: Instance, names: { string }, at: Vector3, yaw: number, scale: number, solid: boolean)
	local model = Models.kit(names)
	if model == nil then
		return
	end
	model:ScaleTo(scale)
	model:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0))
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = solid
			descendant.CanTouch = false
		end
	end
	model.Parent = folder
end

-- (The look-test WaterCollector, a stone ring with a red can inside, is gone: off-pipeline.)
local CAMP_PROPS = { "CrateStack", "Generator", "Barrels", "Sacks" }
local PROP_SCALE: { [string]: number } = { CrateStack = 5.5, Generator = 4.4, Barrels = 5.17, Sacks = 4.6 }

local function dressing(world: Instance, origin: Vector3, random: Random)
	if world:FindFirstChild("Dressing") then
		return
	end
	local root = Instance.new("Folder")
	root.Name = "Dressing"
	local half = GRID_STUDS / 2
	for index, centre in plotCentres() do
		local folder = Instance.new("Folder")
		folder.Name = `Plot{index}`
		folder.Parent = root
		-- The plot's road edge: rows face each other across the road (z = 0).
		local frontZ = if centre.front > 0 then -22 else 22
		local base = origin + Vector3.new(centre.x, 0, 0)
		-- Lamps flank the plot's road edge; two camp props sit near them.
		local facing = if centre.front > 0 then 0 else 180
		place(folder, { "Lamp" }, base + Vector3.new(-9, 0, frontZ), facing, 12.5, true)
		place(folder, { "Lamp" }, base + Vector3.new(9, 0, frontZ), facing, 12.5, true)
		for slot = 1, 2 do
			local name = CAMP_PROPS[random:NextInteger(1, #CAMP_PROPS)]
			local side = if slot == 1 then -1 else 1
			local x = side * random:NextNumber(24, 50)
			place(
				folder,
				{ name },
				base + Vector3.new(x, 0, frontZ + random:NextNumber(-1.5, 1.5)),
				random:NextInteger(-180, 180),
				PROP_SCALE[name],
				true
			)
		end
		-- A ring of rocks and pebbles around the pad (never on it). The look-test
		-- GrassClump (a dirt chunk with straw that read as a mud blob) is gone.
		local scatter: { { name: string, count: number, min: number, max: number, solid: boolean } } = {
			{ name = "RockClump", count = 4, min = 2.8, max = 4.8, solid = true },
			{ name = "Gen_pebbles", count = 3, min = 0.8, max = 1.4, solid = false },
		}
		for _, kind in scatter do
			local placed = 0
			local tries = 0
			while placed < kind.count and tries < 200 do
				tries += 1
				local x = random:NextNumber(-84, 84)
				local depthOut = random:NextNumber(22, 192)
				local onPad = math.abs(x) < half + 6 and depthOut > half - 26 and depthOut < half * 2 + 26 + 40
				if not onPad then
					local z = if centre.front > 0 then -depthOut else depthOut
					place(
						folder,
						{ kind.name },
						base + Vector3.new(x, -0.1, z),
						random:NextInteger(-180, 180),
						random:NextNumber(kind.min, kind.max),
						kind.solid
					)
					placed += 1
				end
			end
		end
	end
	-- A dense line of tall pines in front of the fog on every side (the neighbourhood's
	-- boundary), scaled by height: the kit pine's own scale is about a stud.
	local edges = Instance.new("Folder")
	edges.Name = "Edges"
	edges.Parent = root
	local function tree(x: number, z: number)
		local model = Models.kit({ "EO_PineTree" })
		if model == nil then
			return
		end
		local height = model:GetExtentsSize().Y
		if height > 0.01 then
			model:ScaleTo(model:GetScale() * random:NextNumber(26, 36) / height)
		end
		model:PivotTo(
			CFrame.new(origin + Vector3.new(x, -0.3, z)) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
		)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanTouch = false
			end
		end
		model.Parent = edges
	end
	for row = 0, 2 do
		local depthOut = HALF_DEPTH + 26 + row * 11
		local widthOut = HALF_WIDTH + 30 + row * 11
		local step = 9 + row * 2
		for x = -widthOut, widthOut, step do
			tree(x + random:NextNumber(-3, 3), -depthOut + random:NextNumber(-3, 3))
			tree(x + random:NextNumber(-3, 3), depthOut + random:NextNumber(-3, 3))
		end
		for z = -depthOut, depthOut, step do
			if math.abs(z) > tuning.rowGapStuds * 0.6 then -- leave the road open to the Trailhead
				tree(-widthOut + random:NextNumber(-3, 3), z + random:NextNumber(-3, 3))
				tree(widthOut + random:NextNumber(-3, 3), z + random:NextNumber(-3, 3))
			end
		end
	end
	root.Parent = world
end

-- Trailhead, fog wall, Hearth -------------------------------------------------------------------------

local function light(part: BasePart, range: number, brightness: number, color: Color3)
	local glow = Instance.new("PointLight")
	glow.Range = range
	glow.Brightness = brightness
	glow.Color = color
	glow.Shadows = true
	glow.Parent = part
end

local function anchorPart(name: string, at: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = at
	part.Parent = parent
	return part
end

local function trailhead(world: Instance, origin: Vector3)
	if world:FindFirstChild("Trailhead") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Trailhead"
	local at = origin + Vector3.new(-HALF_WIDTH - 60, 0, 0)
	place(folder, { "Lamp" }, at + Vector3.new(0, 0, -12), 90, 12.5, true)
	place(folder, { "Lamp" }, at + Vector3.new(0, 0, 12), 90, 12.5, true)
	place(folder, { "CrateStack" }, at + Vector3.new(6, 0, -20), 20, 5.5, true)
	place(folder, { "Barrels" }, at + Vector3.new(4, 0, 19), -40, 5.17, true)
	local sign = anchorPart("Sign", at + Vector3.new(0, 9, 0), folder)
	light(sign, 30, 1.2, Color3.fromRGB(255, 196, 140))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 64)
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromName("BuilderSans", Enum.FontWeight.ExtraBold)
	label.Text = "TRAILHEAD\nThe Fog lies beyond"
	label.TextSize = 24
	label.TextColor3 = Color3.fromHex("FFE3A3")
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = sign
	folder.Parent = world
end

local function fogWall(world: Instance, origin: Vector3, random: Random)
	if world:FindFirstChild("FogWall") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "FogWall"
	local x0, x1 = -HALF_WIDTH - 110, HALF_WIDTH + 110
	local z0, z1 = -HALF_DEPTH - 90, HALF_DEPTH + 90
	local function bank(at: Vector3)
		local emitterHost = anchorPart("Bank", origin + at + Vector3.new(0, 8, 0), folder)
		emitterHost.Size = Vector3.new(60, 16, 60)
		local fog = Instance.new("ParticleEmitter")
		fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
		fog.Color = ColorSequence.new(Color3.fromRGB(190, 198, 206))
		fog.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.72),
			NumberSequenceKeypoint.new(0.7, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		})
		fog.Size = NumberSequence.new(30, 46)
		fog.Lifetime = NumberRange.new(14, 22)
		fog.Rate = 1.2
		fog.Speed = NumberRange.new(1, 3)
		fog.SpreadAngle = Vector2.new(180, 20)
		fog.RotSpeed = NumberRange.new(-6, 6)
		fog.LightInfluence = 0.6
		fog.Parent = emitterHost
	end
	local step = 60
	for x = x0, x1, step do
		bank(Vector3.new(x + random:NextNumber(-8, 8), 0, z0))
		bank(Vector3.new(x + random:NextNumber(-8, 8), 0, z1))
	end
	for z = z0 + step, z1 - step, step do
		-- Leave the Trailhead road open to the west: the Fog is entered there.
		if math.abs(z) > 30 then
			bank(Vector3.new(x0, 0, z + random:NextNumber(-8, 8)))
		end
		bank(Vector3.new(x1, 0, z + random:NextNumber(-8, 8)))
	end
	folder.Parent = world
end

local function hearth(world: Instance, origin: Vector3)
	if world:FindFirstChild("Hearth") then
		return
	end
	-- No light without its source: the Hearth appears with its fire model (checklist §0).
	if not Art.approved.Hearth then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Hearth"
	place(folder, { "Hearth" }, origin, 0, 8.5, true)
	local core = anchorPart("Light", origin + Vector3.new(0, 6, 0), folder)
	light(core, 60, 1.6, Color3.fromRGB(255, 170, 96))
	-- The light radius on the ground: a warm disc that fades out at HEARTH_RADIUS.
	local glow = Instance.new("Part")
	glow.Name = "Radius"
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CastShadow = false
	glow.Shape = Enum.PartType.Cylinder
	glow.Size = Vector3.new(0.05, HEARTH_RADIUS * 2, HEARTH_RADIUS * 2)
	glow.CFrame = CFrame.new(origin + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	glow.Transparency = 1
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Right
	decal.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	decal.Color3 = Color3.fromRGB(255, 160, 80)
	decal.Transparency = 0.86
	decal.Parent = glow
	glow.Parent = folder
	folder.Parent = world
end

function Scenery.start()
	lighting()
	local world = worldFolder()
	local origin = originOf(world)
	local random = Random.new(SEED)
	terrain(origin, random)
	dressing(world, origin, random)
	trailhead(world, origin)
	fogWall(world, origin, random)
	hearth(world, origin)
end

return Scenery
