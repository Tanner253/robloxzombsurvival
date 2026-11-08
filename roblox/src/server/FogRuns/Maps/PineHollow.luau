--!strict
--[[
	Pine Hollow (Light fog): an overgrown farmstead and orchard in a pine-rimmed hollow.

	The farm track comes in from the south, through the yard (farmhouse, barn, silo,
	tool shed) and out to the north. East of the yard the old orchard runs in broken
	rows; a reed pond lies west, a hunters' camp in the south-west woods and a
	collapsed cottage in the north-west. Light fog: you can leave from any edge; the
	four trail ends carry green exit overlays.
]]

local Builder = require("./Builder")

local PineHollow = {}

PineHollow.half = 170
PineHollow.seed = 41

local V2 = Vector2.new

-- The farm track (south edge to north edge) and the orchard lane.
local TRACK = {
	V2(8, 240),
	V2(8, 168),
	V2(4, 120),
	V2(-6, 70),
	V2(-12, 20),
	V2(-12, -24),
	V2(-22, -70),
	V2(-40, -120),
	V2(-38, -168),
	V2(-36, -240),
}
local LANE = { V2(-12, -16), V2(30, -4), V2(80, 8), V2(168, 22), V2(240, 24) }
local WEST_TRAIL = { V2(-240, -26), V2(-168, -22), V2(-120, 12), V2(-96, 40) }
local YARD = V2(-6, -44)
local POND = V2(-112, 44)
local CAMP = V2(-104, 112)
local RUIN = V2(-98, -104)

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function height(x: number, z: number): number
	local outside = math.max(math.abs(x), math.abs(z)) - 150
	-- The hollow: flat-ish inside, rising into pine-covered hills past the bounds.
	local rim = smoothstep(0, 90, outside) * 22
	local roll = math.noise(x / 60, z / 60, 4.1) * 3.2 + math.noise(x / 22, z / 22, 7.3) * 0.9
	local yard = 1 - smoothstep(48, 78, (V2(x, z) - YARD).Magnitude)
	local pond = (V2(x, z) - POND).Magnitude
	local dip = (1 - smoothstep(10, 30, pond)) * -4.5
	local track = 1 - smoothstep(4, 9, Builder.distanceToPath(x, z, TRACK))
	local h = roll * (1 - yard * 0.85) + rim + dip
	return h * (1 - track * 0.4)
end

local function surface(x: number, z: number, _y: number): Enum.Material
	local here = V2(x, z)
	local grain = math.noise(x / 6, z / 6, 2.2)
	local track = Builder.distanceToPath(x, z, TRACK)
	local lane = Builder.distanceToPath(x, z, LANE)
	local trail = Builder.distanceToPath(x, z, WEST_TRAIL)
	if track < 2.6 + grain * 0.8 then
		-- Two wheel ruts with a grassy crown between them.
		local crown = math.abs(track) < 1.0
		return if crown and grain > -0.1 then Enum.Material.LeafyGrass else Enum.Material.Mud
	end
	if track < 5 + grain * 1.5 or lane < 2.4 + grain or trail < 1.8 + grain * 0.8 then
		return Enum.Material.Ground
	end
	local pond = (here - POND).Magnitude
	if pond < 30 + grain * 3 then
		return if pond < 24 then Enum.Material.Mud else Enum.Material.Ground
	end
	local yard = (here - YARD).Magnitude
	if yard < 46 + math.noise(x / 14, z / 14, 3.3) * 8 then
		local worn = math.noise(x / 12, z / 12, 9.9) + (1 - yard / 46) * 0.3
		if worn + grain * 0.25 > 0.25 then
			return Enum.Material.Ground
		end
		return Enum.Material.LeafyGrass
	end
	if (here - CAMP).Magnitude < 16 + grain * 3 then
		return Enum.Material.Ground
	end
	-- The orchard: long grass between the rows, trodden under the trees.
	if x > 50 and x < 150 and z > -30 and z < 96 then
		return if math.noise(x / 18, z / 18, 5.5) > 0.2 then Enum.Material.Sand else Enum.Material.LeafyGrass
	end
	local outside = math.max(math.abs(x), math.abs(z)) - 130
	if outside > 0 then
		return if grain > 0.35 then Enum.Material.Ground else Enum.Material.LeafyGrass -- forest floor
	end
	local zones = math.noise(x / 70, z / 70, 0.7)
	local patches = math.noise(x / 24, z / 24, 1.9) + grain * 0.15
	if patches > 0.45 then
		return Enum.Material.Sand -- dry, dead grass
	elseif zones + grain * 0.1 > 0.15 then
		return Enum.Material.LeafyGrass
	end
	return Enum.Material.Grass
end

local function water(x: number, z: number): number?
	return if (V2(x, z) - POND).Magnitude < 25 then -2.2 else nil
end

local PINES = { "EO_PineConifer" }
local DEAD = { "EO_DeadTree" }

local function nearTrack(x: number, z: number): boolean
	return Builder.distanceToPath(x, z, TRACK) < 9
		or Builder.distanceToPath(x, z, LANE) < 7
		or Builder.distanceToPath(x, z, WEST_TRAIL) < 6
end

local function farmhouse(ctx: Builder.Ctx)
	local house = Builder.building(ctx, {
		name = "Farmhouse",
		x = -44,
		z = -50,
		width = 24,
		depth = 16,
		height = 10,
		wall = "siding",
		trim = "trimLight",
		floor = "floorPlanks",
		roof = "gable",
		roofPaint = "shingle",
		porch = "S",
		openings = {
			{ side = "S", at = 0, kind = "door" },
			{ side = "S", at = -7, kind = "window" },
			{ side = "S", at = 7, kind = "window" },
			{ side = "E", at = -3, kind = "window" },
			{ side = "E", at = 4, kind = "door" },
			{ side = "W", at = 0, kind = "window" },
			{ side = "N", at = -6, kind = "window" },
			{ side = "N", at = 6, kind = "window" },
		},
	})
	-- Inside: a kitchen dresser and a bed frame in exact geometry, plus the loot.
	local folder = house.model
	Builder.part(folder, Vector3.new(6, 3.4, 2), house.frame * CFrame.new(-8, 1.9, -6.4), "boards", "Dresser")
	Builder.part(folder, Vector3.new(3, 0.3, 6.4), house.frame * CFrame.new(9, 1.6, -3.5), "trim", "BedFrame")
	Builder.part(folder, Vector3.new(2.6, 0.5, 5.6), house.frame * CFrame.new(9, 2, -3.5), "cloth", "Mattress")
	Builder.part(folder, Vector3.new(4, 0.3, 2.6), house.frame * CFrame.new(-1, 2.8, 1), "boards", "Table")
	for _, leg in { { -2.6, -0.6 }, { 2.6, -0.6 } } do
		Builder.part(folder, Vector3.new(0.3, 2.6, 2.2), house.frame * CFrame.new(-1 + leg[1] * 0.6, 1.4, 1), "trim")
	end
	local cx, cz, lift = Builder.inside(ctx, house, -9, 4)
	Builder.container(ctx, "crate", cx, cz, 90, nil, lift)
	local px, pz, plift = Builder.inside(ctx, house, 8, 4.5)
	Builder.container(ctx, "pack", px, pz, 30, nil, plift)
	local lx, lz, llift = Builder.inside(ctx, house, 0, 0)
	Builder.lamp(ctx, lx, lz, llift + 8, true, 18)
end

local function barn(ctx: Builder.Ctx)
	local barnBuilding = Builder.building(ctx, {
		name = "Barn",
		x = 30,
		z = -66,
		width = 28,
		depth = 22,
		height = 13,
		wall = "barn",
		trim = "trim",
		floor = "floorConcrete",
		roof = "gable",
		roofPaint = "roofMetal",
		openings = {
			{ side = "S", at = 0, kind = "gap", width = 9, height = 10 },
			{ side = "N", at = 0, kind = "gap", width = 9, height = 10 },
			{ side = "E", at = -5, kind = "window" },
			{ side = "E", at = 5, kind = "window" },
			{ side = "W", at = 4, kind = "door" },
		},
	})
	-- Hay inside and stalls along the west wall.
	for index, spot in { { -9, -6 }, { -9, 2 }, { 9, -7 } } do
		local x, z, lift = Builder.inside(ctx, barnBuilding, spot[1], spot[2])
		Builder.kit(ctx, { "EO_HayBales" }, x, z, index * 70, { height = 4, lift = lift })
	end
	for z = -8, 8, 5.5 do
		Builder.part(
			barnBuilding.model,
			Vector3.new(0.4, 4.5, 4.6),
			barnBuilding.frame * CFrame.new(-5, 2.3, z),
			"boards",
			"Stall"
		)
	end
	for _, spot in { { 10, 6 }, { -11, 8 } } do
		local x, z, lift = Builder.inside(ctx, barnBuilding, spot[1], spot[2])
		Builder.container(ctx, "crate", x, z, 0, nil, lift)
	end
	local lx, lz, lift = Builder.inside(ctx, barnBuilding, 0, 2)
	Builder.lamp(ctx, lx, lz, lift + 11, true, 22)
end

local function silo(ctx: Builder.Ctx)
	local folder = Builder.model(Builder.folder(ctx, "Buildings"), "Silo")
	folder:SetAttribute("Layer", "frame")
	local base = Builder.frame(ctx, 58, -84, 0)
	Builder.cylinder(folder, 22, 10, base * CFrame.new(0, 11, 0), "corrugated")
	Builder.cylinder(folder, 1.2, 10.6, base * CFrame.new(0, 22.4, 0), "rust")
	Builder.cylinder(folder, 1.5, 6.4, base * CFrame.new(0, 23.6, 0), "rust")
	Builder.cylinder(folder, 2, 11, base * CFrame.new(0, 1, 0), "concreteDark")
	-- A ladder up its side.
	for _, side in { -0.6, 0.6 } do
		Builder.part(folder, Vector3.new(0.18, 20, 0.18), base * CFrame.new(side, 11, 5.1), "steel")
	end
	for rung = 2, 20, 1.2 do
		Builder.part(folder, Vector3.new(1.3, 0.15, 0.15), base * CFrame.new(0, rung, 5.1), "steel")
	end
end

local function shed(ctx: Builder.Ctx)
	local toolShed = Builder.building(ctx, {
		name = "ToolShed",
		x = -2,
		z = -104,
		width = 12,
		depth = 9,
		height = 8.5,
		wall = "corrugated",
		trim = "darkMetal",
		floor = "floorConcrete",
		roof = "shed",
		roofPaint = "roofMetal",
		openings = { { side = "S", at = 2, kind = "door" }, { side = "E", at = 0, kind = "window" } },
	})
	Builder.part(toolShed.model, Vector3.new(8, 0.3, 2), toolShed.frame * CFrame.new(0, 3, -3), "boards", "Workbench")
	local x, z, lift = Builder.inside(ctx, toolShed, -3.5, 1)
	Builder.container(ctx, "crate", x, z, 0, nil, lift)
end

local function ruinedCottage(ctx: Builder.Ctx)
	local cottage = Builder.building(ctx, {
		name = "RuinedCottage",
		x = RUIN.X,
		z = RUIN.Y,
		width = 16,
		depth = 12,
		height = 9,
		wall = "plaster",
		trim = "trim",
		floor = "floorPlanks",
		roof = "none",
		ruin = 0.65,
		openings = {
			{ side = "S", at = -2, kind = "door" },
			{ side = "E", at = 0, kind = "window" },
			{ side = "W", at = 1, kind = "window" },
		},
	})
	Builder.rubble(ctx, RUIN.X + 7, RUIN.Y + 7, 4, "plaster")
	Builder.rubble(ctx, RUIN.X - 5, RUIN.Y - 2, 3, "plaster")
	local x, z, lift = Builder.inside(ctx, cottage, 3, -2)
	Builder.container(ctx, "crate", x, z, 20, nil, lift)
	Builder.kit(ctx, DEAD, RUIN.X - 12, RUIN.Y + 10, 40, { height = 16 })
end

local function hunterCamp(ctx: Builder.Ctx)
	-- A tarp lean-to over a cold fire, sacks and barrels: someone camped here and left fast.
	local folder = Builder.model(Builder.folder(ctx, "Dressing"), "HunterCamp")
	local base = Builder.frame(ctx, CAMP.X, CAMP.Y, 25)
	for _, side in { -4, 4 } do
		Builder.part(folder, Vector3.new(0.4, 6, 0.4), base * CFrame.new(side, 3, -3), "trim", "Pole")
	end
	Builder.part(folder, Vector3.new(9, 0.25, 0.3), base * CFrame.new(0, 6, -3), "trim", "Ridge")
	Builder.part(
		folder,
		Vector3.new(9.4, 0.12, 7.2),
		base * CFrame.new(0, 3.2, -0.2) * CFrame.Angles(math.rad(-56), 0, 0),
		"tarp",
		"Tarp"
	)
	Builder.rubble(ctx, CAMP.X + 4, CAMP.Y + 5, 1.6, "rubble")
	Builder.kit(ctx, { "EO_BarrelCluster" }, CAMP.X - 7, CAMP.Y + 2, 70)
	Builder.kit(ctx, { "EO_LanternPost" }, CAMP.X + 8, CAMP.Y - 4, 200)
	Builder.lamp(ctx, CAMP.X + 7, CAMP.Y - 4, 6, true, 18)
	Builder.container(ctx, "pack", CAMP.X - 2, CAMP.Y - 1, 10)
	Builder.container(ctx, "pack", CAMP.X + 3, CAMP.Y + 1, 200)
	Builder.container(ctx, "crate", CAMP.X - 9, CAMP.Y - 5, 110)
end

local function orchard(ctx: Builder.Ctx)
	local rng = ctx.rng
	local row = 0
	for z = -18, 88, 15 do
		row += 1
		for x = 60, 146, 13 do
			if rng:NextNumber() < 0.82 then
				local jx, jz = (rng:NextNumber() - 0.5) * 4, (rng:NextNumber() - 0.5) * 4
				local names = if rng:NextNumber() < 0.15 then DEAD else { "EO_AppleTree" }
				Builder.kit(ctx, names, x + jx + (row % 2) * 6, z + jz, rng:NextNumber() * 360, {
					height = 11 + rng:NextNumber() * 3,
					canopy = true,
				})
			end
		end
	end
	Builder.railFence(ctx, { V2(52, -26), V2(150, -26), V2(152, 96), V2(52, 98), V2(52, 30) })
	for _, spot in { V2(84, 30), V2(120, 64), V2(100, -10) } do
		Builder.container(ctx, "pack", spot.X, spot.Y, rng:NextNumber() * 360)
	end
	Builder.kit(ctx, { "EO_HayBales" }, 64, 74, 30, { height = 4 })
	Builder.kit(ctx, { "EO_TractorWreck" }, 132, 6, 250, { height = 7 })
end

local function yard(ctx: Builder.Ctx)
	Builder.kit(ctx, { "EO_TractorWreck" }, 6, -28, 32, { height = 7 })
	Builder.kit(ctx, { "EO_PickupWreck" }, -26, -18, 104, { height = 6.5 })
	Builder.kit(ctx, { "EO_HayBales" }, 52, -46, 0, { height = 4 })
	Builder.kit(ctx, { "EO_WaterTrough" }, 10, -48, 90, { height = 2.6 })
	Builder.kit(ctx, { "EO_BarrelCluster" }, -24, -40, 10)
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, -54, -36, 60)
	for _, spot in { V2(-18, -30), V2(14, -14), V2(-30, -76) } do
		Builder.kit(ctx, { "EO_LanternPost" }, spot.X, spot.Y, ctx.rng:NextNumber() * 360)
		Builder.lamp(ctx, spot.X, spot.Y, 6, true, 18)
	end
	Builder.container(ctx, "crate", 18, -40, 15)
	Builder.container(ctx, "pack", -16, -64, 70)
	-- Rail fences around the yard and the paddock to its west.
	Builder.railFence(ctx, { V2(-66, -24), V2(-66, -82), V2(-20, -86) })
	Builder.railFence(ctx, { V2(46, -26), V2(70, -30), V2(76, -100), V2(20, -102) })
	Builder.railFence(ctx, { V2(-70, 0), V2(-120, 2), V2(-124, -50), V2(-70, -60) })
end

local function woods(ctx: Builder.Ctx)
	local rng = ctx.rng
	local function clearOf(x: number, z: number): boolean
		local here = V2(x, z)
		return nearTrack(x, z)
			or (here - YARD).Magnitude < 70
			or (here - POND).Magnitude < 30
			or (here - CAMP).Magnitude < 20
			or (here - RUIN).Magnitude < 18
			or (x > 46 and x < 156 and z > -32 and z < 104)
	end
	-- The pine rim: dense past the bounds, thinning into the hollow.
	for _ = 1, 220 do
		local x = (rng:NextNumber() * 2 - 1) * 230
		local z = (rng:NextNumber() * 2 - 1) * 230
		local edge = math.max(math.abs(x), math.abs(z))
		local keep = edge > 150 or (edge > 110 and rng:NextNumber() < 0.6) or rng:NextNumber() < 0.08
		if keep and not clearOf(x, z) then
			Builder.kit(ctx, PINES, x, z, rng:NextNumber() * 360, { height = 18 + rng:NextNumber() * 9, canopy = true })
		end
	end
	for _ = 1, 16 do
		local x, z = (rng:NextNumber() * 2 - 1) * 150, (rng:NextNumber() * 2 - 1) * 150
		if not clearOf(x, z) then
			Builder.kit(ctx, DEAD, x, z, rng:NextNumber() * 360, { height = 14 + rng:NextNumber() * 5 })
		end
	end
	-- Ground scatter: branches and fieldstones (small, walk-through).
	for _ = 1, 40 do
		local x, z = (rng:NextNumber() * 2 - 1) * 160, (rng:NextNumber() * 2 - 1) * 160
		if Builder.distanceToPath(x, z, TRACK) > 5 then
			local names = if rng:NextNumber() < 0.5 then { "EO_BareBranches" } else { "EO_LooseStonesClean" }
			Builder.kit(ctx, names, x, z, rng:NextNumber() * 360, { solid = false })
		end
	end
	-- Packs and crates left along the way.
	Builder.container(ctx, "pack", -60, 128, 40)
	Builder.container(ctx, "pack", 70, 132, 300)
	Builder.container(ctx, "pack", -128, 24, 80)
	Builder.container(ctx, "crate", 96, -128, 0)
	Builder.kit(ctx, { "EO_SedanWreck" }, 20, 92, 168, { height = 5 })
	Builder.container(ctx, "trunk", 20, 98, 168)
end

local function gatherables(ctx: Builder.Ctx)
	local rng = ctx.rng
	local function spot(radius: number, centre: Vector2): Vector2
		local angle = rng:NextNumber() * math.pi * 2
		return centre + V2(math.cos(angle), math.sin(angle)) * (radius * (0.4 + rng:NextNumber() * 0.6))
	end
	-- Pines to fell along the woods edge, fieldstones and branches across the meadow,
	-- stumps in the clearing, reeds round the pond.
	for index = 1, 16 do
		local p = spot(30, if index % 2 == 0 then V2(-120, -150) else V2(120, 130))
		Builder.node(ctx, "node.pine_tree", p.X, p.Y)
	end
	for _ = 1, 10 do
		local p = spot(40, V2(-120, -60))
		Builder.node(ctx, "node.boulder", p.X, p.Y)
	end
	for _ = 1, 8 do
		local p = spot(90, V2(40, 60))
		Builder.node(ctx, "node.fallen_branches", p.X, p.Y)
		local q = spot(90, V2(-40, 40))
		Builder.node(ctx, "node.loose_stones", q.X, q.Y)
	end
	for _ = 1, 10 do
		local p = spot(30, POND)
		Builder.node(ctx, "node.reed_patch", p.X, p.Y)
	end
	for _ = 1, 6 do
		local p = spot(40, V2(70, 140))
		Builder.node(ctx, "node.ember_bush", p.X, p.Y)
		local q = spot(30, V2(-60, 100))
		Builder.node(ctx, "node.ashroot_mound", q.X, q.Y)
	end
	Builder.node(ctx, "node.spring_pool", POND.X + 26, POND.Y - 10)
	Builder.node(ctx, "node.spring_pool", 120, -120)
end

local function markers(ctx: Builder.Ctx)
	for index, spawn in { V2(4, 150), V2(-6, 146), V2(16, 146), V2(-16, 152), V2(10, 138), V2(-2, 134) } do
		Builder.marker(ctx, "spawn", spawn.X, spawn.Y, { Index = index })
	end
	local hollows = {
		V2(-30, -60),
		V2(20, -80),
		V2(40, -30),
		V2(-50, -96),
		V2(90, 20),
		V2(130, 60),
		V2(110, -20),
		V2(-110, 60),
		V2(-130, 10),
		V2(-90, 120),
		V2(-60, 150),
		V2(60, 120),
		V2(-100, -130),
		V2(30, -140),
		V2(140, -120),
		V2(-140, -140),
	}
	for _, at in hollows do
		Builder.marker(ctx, "hollow", at.X, at.Y)
	end
	-- Light fog: any edge works; the trail ends are marked.
	Builder.exit(ctx, "edge", "South trail", 8, 158, 9, 0)
	Builder.exit(ctx, "edge", "North trail", -38, -158, 9, 0)
	Builder.exit(ctx, "edge", "Orchard lane", 160, 22, 9, 90)
	Builder.exit(ctx, "edge", "Pond path", -160, -22, 9, 90)
end

function PineHollow.build(ctx: Builder.Ctx)
	Builder.terrain(ctx, { extent = 250, height = height, surface = surface, water = water })
	yard(ctx)
	farmhouse(ctx)
	barn(ctx)
	silo(ctx)
	shed(ctx)
	ruinedCottage(ctx)
	hunterCamp(ctx)
	orchard(ctx)
	woods(ctx)
	gatherables(ctx)
	markers(ctx)
end

return PineHollow
