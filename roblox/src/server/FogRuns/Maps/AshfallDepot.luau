--!strict
--[[
	Ashfall Depot (Black fog): a fog-choked quarry and its rail yard.

	North: the quarry pit, cut in terraces down to a flooded floor, with a haul ramp
	from the south rim, gravel heaps, a conveyor up to the crusher house on the east
	rim. South: the rail yard, four tracks of abandoned freight cars between stacks
	of shipping containers, the depot warehouse on the loading dock, and the signal
	tower in the south-east.

	Black fog: three marked exits (Rail Yard, Loading Dock, Signal Tower; the lobby
	seed closes one) plus the flare extract anywhere. Containers: freight crates and
	strongboxes.
]]

local Builder = require("./Builder")

local AshfallDepot = {}

AshfallDepot.half = 180
AshfallDepot.seed = 113

local V2 = Vector2.new

local PIT = V2(-10, -92)
local PIT_RADIUS = 78
local TRACK_Z = { 34, 48, 62, 76 }
local DOCK_Z = 98
local RAMP = { V2(40, -12), V2(30, -46), V2(4, -70), V2(-20, -84) }
local TOWER = V2(132, 128)

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- The pit's depth at a point: terraces stepping down toward the flooded floor.
local function pitDepth(x: number, z: number): number
	local d = (V2(x, z) - PIT).Magnitude + math.noise(x / 18, z / 18, 6.4) * 6
	if d >= PIT_RADIUS then
		return 0
	end
	local t = 1 - d / PIT_RADIUS -- 0 at the rim, 1 at the centre
	-- Benches cut down in five steps: flat ledges with steep faces between them.
	local steps = 5
	local scaled = t * steps
	local bench = math.floor(scaled)
	local face = math.clamp((scaled - bench - 0.72) / 0.28, 0, 1)
	local level = math.min(bench + face, steps) / steps
	return -level * 38
end

local function rampLift(x: number, z: number): number
	-- The haul road climbs out of the pit along RAMP: keep it a smooth slope.
	local d = Builder.distanceToPath(x, z, RAMP)
	if d > 7 then
		return 0
	end
	local along = math.clamp((z + 12) / -72, 0, 1) -- 0 at the rim, 1 at the bottom
	local want = -along * 30
	local here = pitDepth(x, z)
	local blend = 1 - smoothstep(4, 7, d)
	return (want - here) * blend
end

local function height(x: number, z: number): number
	local outside = math.max(math.abs(x), math.abs(z)) - 160
	local rim = smoothstep(0, 80, outside) * 18
	local roll = math.noise(x / 50, z / 50, 9.2) * 1.4
	local pit = pitDepth(x, z)
	local spoil = 0
	-- Spoil heaps around the pit rim.
	local d = (V2(x, z) - PIT).Magnitude
	if d > PIT_RADIUS and d < PIT_RADIUS + 26 and z < 0 then
		spoil = math.max(0, math.noise(x / 16, z / 16, 3.1)) * 9
	end
	local yard = if z > 20 then 1 - smoothstep(0, 20, outside) else 0
	return (roll + spoil) * (1 - yard * 0.8) + rim + pit + rampLift(x, z)
end

local function surface(x: number, z: number, y: number): Enum.Material
	local grain = math.noise(x / 5, z / 5, 1.6)
	local d = (V2(x, z) - PIT).Magnitude
	if Builder.distanceToPath(x, z, RAMP) < 5 then
		return Enum.Material.Ground
	end
	if d < PIT_RADIUS + 2 then
		-- Bare rock walls and gravel ledges, wet mud on the floor.
		if y < -33 then
			return Enum.Material.Mud
		end
		return if grain > -0.2 then Enum.Material.Slate else Enum.Material.Cobblestone
	end
	for _, tz in TRACK_Z do
		if math.abs(z - tz) < 5 then
			return Enum.Material.Cobblestone
		end
	end
	if z > 20 and z < DOCK_Z + 30 then
		-- The yard: gravel and black ash drifts.
		local patch = math.noise(x / 20, z / 20, 7.7) + grain * 0.2
		return if patch > 0.2 then Enum.Material.Basalt else Enum.Material.Cobblestone
	end
	-- Everywhere else: ash drifts over gravel and spoil, a little packed earth on the tracks
	-- people walked (no green, no warm brown: Black fog).
	local patches = math.noise(x / 24, z / 24, 2.1) + grain * 0.2
	if patches > 0.1 then
		return Enum.Material.Basalt
	elseif patches > -0.35 then
		return Enum.Material.Cobblestone
	end
	return Enum.Material.Ground
end

local function water(x: number, z: number): number?
	return if (V2(x, z) - PIT).Magnitude < PIT_RADIUS * 0.3 then -35 else nil
end

local DEAD = { "EO_DeadTree" }

local function railYard(ctx: Builder.Ctx)
	for _, tz in TRACK_Z do
		Builder.track(ctx, V2(-250, tz), V2(250, tz))
	end
	-- Freight cars: runs of boxcars, one derailed on its side.
	local rng = ctx.rng
	local cars = {
		{ -120, 34, 90 },
		{ -96, 34, 90 },
		{ -20, 48, 90 },
		{ 4, 48, 90 },
		{ 28, 48, 90 },
		{ 90, 62, 90 },
		{ 114, 62, 90 },
		{ -60, 76, 90 },
		{ 60, 76, 90 },
	}
	for index, car in cars do
		local tilt = if index == 4 then 12 else 0
		Builder.kit(ctx, { "EO_Boxcar" }, car[1], car[2], car[3], { height = 9, lift = 1, tilt = tilt })
		if index % 3 == 1 then
			Builder.container(ctx, "crate", car[1] + 2, car[2] + 6.5, rng:NextNumber() * 30)
		end
	end
	-- Container stacks between the tracks and the pit.
	type Stack = { x: number, z: number, yaw: number, paint: string, stacked: boolean? }
	local stacks: { Stack } = {
		{ x = -150, z = 12, yaw = 0, paint = "corrugated" },
		{ x = -150, z = 12, yaw = 0, paint = "corrugatedTeal", stacked = true },
		{ x = -128, z = 12, yaw = 0, paint = "rust" },
		{ x = 120, z = 12, yaw = 0, paint = "corrugatedTeal" },
		{ x = 142, z = 12, yaw = 0, paint = "rust" },
		{ x = 142, z = 12, yaw = 0, paint = "corrugated", stacked = true },
		{ x = -40, z = 16, yaw = 0, paint = "rust" },
		{ x = 160, z = 92, yaw = 90, paint = "corrugated" },
	}
	for _, stack in stacks do
		Builder.shippingContainer(ctx, stack.x, stack.z, stack.yaw, stack.paint, stack.stacked)
	end
	Builder.container(ctx, "crate", -139, 20, 0)
	Builder.container(ctx, "strongbox", 131, 20, 0)
	-- Buffers at the track ends, and switch levers.
	for _, tz in TRACK_Z do
		local holder = Builder.model(Builder.folder(ctx, "Rails"), "Buffer")
		local base = Builder.frame(ctx, 168, tz, 0)
		Builder.part(holder, Vector3.new(1.2, 3, 7), base * CFrame.new(0, 1.5, 0), "rust")
		for _, side in { -2.2, 2.2 } do
			Builder.cylinder(
				holder,
				1.6,
				1.2,
				base * CFrame.new(-1.2, 2.2, side) * CFrame.Angles(0, 0, math.rad(90)),
				"darkMetal"
			)
		end
	end
end

local function depot(ctx: Builder.Ctx)
	Builder.platform(ctx, -40, DOCK_Z, 90, 12, 3.5, 0)
	local warehouse = Builder.building(ctx, {
		name = "DepotWarehouse",
		x = -40,
		z = DOCK_Z + 22,
		width = 52,
		depth = 28,
		height = 14,
		wall = "corrugated",
		trim = "darkMetal",
		floor = "floorConcrete",
		roof = "gable",
		roofPaint = "roofMetal",
		plinth = 3.5,
		openings = {
			{ side = "N", at = -14, kind = "gap", width = 10, height = 10 },
			{ side = "N", at = 12, kind = "gap", width = 10, height = 10 },
			{ side = "E", at = 4, kind = "door" },
			{ side = "S", at = 16, kind = "window" },
			{ side = "W", at = 0, kind = "window" },
		},
		ruin = 0.2,
	})
	local function put(kind: string, lx: number, lz: number, yaw: number)
		local x, z, lift = Builder.inside(ctx, warehouse, lx, lz)
		Builder.container(ctx, kind, x, z, yaw, nil, lift)
	end
	put("crate", -18, 6, 0)
	put("crate", -10, 9, 90)
	put("crate", 14, 8, 0)
	put("strongbox", 22, -9, 270) -- the yard office corner
	-- A stacked pallet row and the office partition.
	for x = -20, 0, 5 do
		local px, pz, lift = Builder.inside(ctx, warehouse, x, -8)
		Builder.kit(ctx, { "EO_StorageCrate" }, px, pz, 0, { lift = lift })
	end
	Builder.part(
		warehouse.model,
		Vector3.new(0.6, 8, 12),
		warehouse.frame * CFrame.new(16, 4, -7),
		"concreteDark",
		"Partition"
	)
	local lx, lz, lift = Builder.inside(ctx, warehouse, 0, 0)
	Builder.lamp(ctx, lx, lz, lift + 12, false, 26)
	Builder.lamp(ctx, -40, DOCK_Z - 4, 7, true, 20)
	Builder.kit(ctx, { "EO_BarrelCluster" }, -82, DOCK_Z - 2, 30, { lift = 3.5 })
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, -2, DOCK_Z + 2, 120, { lift = 3.5 })
end

local function signalTower(ctx: Builder.Ctx)
	local holder = Builder.model(Builder.folder(ctx, "Buildings"), "SignalTower")
	holder:SetAttribute("Layer", "frame")
	local base = Builder.frame(ctx, TOWER.X, TOWER.Y, 15)
	local towerHeight = 34
	for _, sx in { -3, 3 } do
		for _, sz in { -3, 3 } do
			Builder.part(
				holder,
				Vector3.new(0.5, towerHeight, 0.5),
				base * CFrame.new(sx, towerHeight / 2, sz),
				"rust",
				"Leg"
			)
		end
	end
	for y = 4, towerHeight - 2, 6 do
		for _, side in { -3, 3 } do
			Builder.part(holder, Vector3.new(6.4, 0.3, 0.3), base * CFrame.new(0, y, side), "rust", "Brace")
			Builder.part(holder, Vector3.new(0.3, 0.3, 6.4), base * CFrame.new(side, y, 0), "rust", "Brace")
			Builder.part(
				holder,
				Vector3.new(0.25, 8.4, 0.25),
				base * CFrame.new(0, y + 3, side) * CFrame.Angles(0, 0, math.rad(45)),
				"rust",
				"Cross"
			)
		end
	end
	Builder.part(holder, Vector3.new(8, 0.5, 8), base * CFrame.new(0, towerHeight, 0), "darkMetal", "Deck")
	Builder.part(holder, Vector3.new(5, 4, 5), base * CFrame.new(0, towerHeight + 2.25, 0), "corrugated", "Hut")
	local beacon =
		Builder.part(holder, Vector3.new(1, 1, 1), base * CFrame.new(0, towerHeight + 4.8, 0), "exitGlow", "Beacon")
	beacon.Transparency = 0.1
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 80)
	light.Range = 30
	light.Brightness = 0.8
	light.Parent = beacon
	beacon.Color = Color3.fromRGB(255, 120, 80)
	Builder.container(ctx, "strongbox", TOWER.X - 6, TOWER.Y + 2, 90)
end

local function quarry(ctx: Builder.Ctx)
	-- The crusher house on the east rim, and a conveyor truss running down into the pit.
	local crusher = Builder.building(ctx, {
		name = "CrusherHouse",
		x = 84,
		z = -60,
		width = 20,
		depth = 18,
		height = 16,
		wall = "corrugatedTeal",
		trim = "darkMetal",
		floor = "floorConcrete",
		roof = "shed",
		roofPaint = "roofMetal",
		openings = {
			{ side = "S", at = 3, kind = "door" },
			{ side = "W", at = 0, kind = "gap", width = 6, height = 6 },
			{ side = "N", at = -4, kind = "window" },
		},
	})
	local sx, sz, slift = Builder.inside(ctx, crusher, 5, -4)
	Builder.container(ctx, "strongbox", sx, sz, 180, nil, slift)
	local cx, cz, clift = Builder.inside(ctx, crusher, -5, 4)
	Builder.container(ctx, "crate", cx, cz, 0, nil, clift)
	local holder = Builder.model(Builder.folder(ctx, "Buildings"), "Conveyor")
	holder:SetAttribute("Layer", "frame")
	local top = ctx.origin + Vector3.new(72, ctx.groundHeight(72, -60) + 12, -60)
	local bottom = ctx.origin + Vector3.new(10, ctx.groundHeight(10, -84) + 3, -84)
	local frame = CFrame.lookAt((top + bottom) / 2, top)
	local length = (top - bottom).Magnitude
	Builder.part(holder, Vector3.new(3.2, 0.4, length), frame, "darkMetal", "Belt")
	for _, side in { -1.8, 1.8 } do
		Builder.part(holder, Vector3.new(0.3, 1.2, length), frame * CFrame.new(side, 0.4, 0), "rust", "Rail")
	end
	local legs = math.floor(length / 10)
	for leg = 1, legs - 1 do
		local p = bottom:Lerp(top, leg / legs)
		local ground = ctx.origin.Y + ctx.groundHeight(p.X - ctx.origin.X, p.Z - ctx.origin.Z)
		local tall = p.Y - ground
		if tall > 1 then
			Builder.part(holder, Vector3.new(0.6, tall, 0.6), CFrame.new(p.X, ground + tall / 2, p.Z), "rust", "Leg")
		end
	end
	-- Gravel heaps and a parked hopper on the ramp.
	local rng = ctx.rng
	for _ = 1, 6 do
		local angle = rng:NextNumber() * math.pi * 2
		local p = PIT + V2(math.cos(angle), math.sin(angle)) * (PIT_RADIUS * 0.55)
		Builder.rubble(ctx, p.X, p.Y, 5, "gravel")
	end
	Builder.kit(ctx, { "EO_OreHopper" }, 26, -40, 210, { height = 7 })
	Builder.container(ctx, "crate", -40, -150, 20)
	Builder.container(ctx, "crate", -78, -60, 120)
	Builder.lamp(ctx, 30, -46, 8, false, 22)
end

local function scrubland(ctx: Builder.Ctx)
	local rng = ctx.rng
	for _ = 1, 140 do
		local x = (rng:NextNumber() * 2 - 1) * 240
		local z = (rng:NextNumber() * 2 - 1) * 240
		local edge = math.max(math.abs(x), math.abs(z))
		local inYard = z > 18 and z < DOCK_Z + 40 and math.abs(x) < 170
		local inPit = (V2(x, z) - PIT).Magnitude < PIT_RADIUS + 6
		if edge > 156 and not inYard and not inPit then
			local names = if rng:NextNumber() < 0.6 then DEAD else { "EO_PineTree" }
			Builder.kit(ctx, names, x, z, rng:NextNumber() * 360, { height = 16 + rng:NextNumber() * 8, canopy = true })
		end
	end
	for _ = 1, 24 do
		local x, z = (rng:NextNumber() * 2 - 1) * 150, (rng:NextNumber() * 2 - 1) * 150
		if (V2(x, z) - PIT).Magnitude > PIT_RADIUS + 4 then
			Builder.kit(ctx, { "EO_LooseStonesClean" }, x, z, rng:NextNumber() * 360, { solid = false })
		end
	end
	for _, spot in { V2(-150, -20), V2(150, -30), V2(-100, 150), V2(80, 150) } do
		Builder.kit(ctx, DEAD, spot.X, spot.Y, rng:NextNumber() * 360, { height = 15 })
	end
	Builder.utilityPole(ctx, 100, 100, V2(60, 100))
	Builder.utilityPole(ctx, 60, 100, V2(20, 100))
	Builder.utilityPole(ctx, 20, 100, nil)
	for x = -170, 170, 34 do
		Builder.streetLamp(ctx, x, 88, 180, rng:NextNumber() < 0.25)
	end
end

local function gatherables(ctx: Builder.Ctx)
	local rng = ctx.rng
	local function near(centre: Vector2, radius: number): Vector2
		local angle = rng:NextNumber() * math.pi * 2
		return centre + V2(math.cos(angle), math.sin(angle)) * radius * (0.5 + rng:NextNumber() * 0.5)
	end
	for _ = 1, 14 do
		local p = near(V2(0, 130), 60)
		Builder.node(ctx, "node.scrap_heap", p.X, p.Y)
	end
	for _ = 1, 6 do
		local p = near(V2(-130, -120), 26)
		Builder.node(ctx, "node.fatwood_stump", p.X, p.Y)
		local q = near(PIT, PIT_RADIUS * 0.7)
		Builder.node(ctx, "node.boulder", q.X, q.Y)
		local n = near(PIT, PIT_RADIUS * 0.85)
		Builder.node(ctx, "node.niter_seam", n.X, n.Y)
	end
	Builder.node(ctx, "node.spring_pool", -120, 150)
	-- Ironstone on the quarry's benches (ECONOMY §6.3), above the flooded floor.
	for index = 1, 8 do
		local angle = (index / 8 + rng:NextNumber() * 0.08) * math.pi * 2
		local p = PIT + V2(math.cos(angle), math.sin(angle)) * PIT_RADIUS * (0.42 + rng:NextNumber() * 0.22)
		Builder.node(ctx, "node.ironstone_rock", p.X, p.Y)
	end
end

local function markers(ctx: Builder.Ctx)
	for index, spawn in { V2(-160, 150), V2(-150, 156), V2(-146, 146), V2(-138, 154), V2(-156, 140), V2(-132, 142) } do
		Builder.marker(ctx, "spawn", spawn.X, spawn.Y, { Index = index })
	end
	local hollows = {
		V2(-60, 40),
		V2(0, 60),
		V2(60, 40),
		V2(120, 70),
		V2(-120, 60),
		V2(-40, 120),
		V2(20, 130),
		V2(100, 130),
		V2(-100, 130),
		V2(30, -30),
		V2(-60, -40),
		V2(-90, -100),
		V2(-10, -100),
		V2(60, -110),
		V2(100, -40),
		V2(-140, -20),
		V2(140, -10),
		V2(0, -160),
		V2(-120, -150),
		V2(120, -140),
		V2(150, 40),
		V2(-150, 100),
	}
	for _, at in hollows do
		Builder.marker(ctx, "hollow", at.X, at.Y)
	end
	Builder.exit(ctx, "rail_yard", "Rail Yard", -166, 55, 10, 90)
	Builder.exit(ctx, "loading_dock", "Loading Dock", 40, 140, 10, 0)
	Builder.exit(ctx, "signal_tower", "Signal Tower", TOWER.X + 10, TOWER.Y - 14, 10, 0)
end

function AshfallDepot.build(ctx: Builder.Ctx)
	Builder.terrain(ctx, { extent = AshfallDepot.half + 140, height = height, surface = surface, water = water })
	railYard(ctx)
	depot(ctx)
	signalTower(ctx)
	quarry(ctx)
	scrubland(ctx)
	-- Past the edge: burnt woods (mostly dead), the rails kept open, and the Black fog's
	-- dark bank, so no zoom shows the map's end.
	Builder.treeWall(ctx, {
		half = AshfallDepot.half,
		names = { "EO_PineTree" },
		dead = DEAD,
		deadShare = 0.65,
		depth = 80,
		spacing = 9,
		height = 19,
		clear = function(_x: number, z: number): boolean
			return z > 26 and z < 84
		end,
	})
	Builder.fogBank(ctx, AshfallDepot.half, Color3.fromRGB(88, 90, 96), 2)
	gatherables(ctx)
	markers(ctx)
end

return AshfallDepot
