--!strict
--[[
	Pine Hollow (Light fog): an overgrown farmstead in a pine-ringed hollow, compact and
	dense like LDoE's locations (rec3 Pine Bushes, rec6): 250 x 250 studs of play.

	Four points of interest joined by worn paths, with pine woods and undergrowth in
	every gap (no open lawns):
	- the farmstead (centre): farmhouse, barn, silo and tool shed round a junk-strewn yard;
	- the orchard (east): broken rows of old apple trees, a stalled tractor, hay;
	- the pond and hunters' camp (south-west);
	- the burnt-out cottage (north-west).
	The farm track runs south to north through the yard; the orchard lane goes east, the
	pond trail west. Light fog: any edge is a way out; the four trail ends are marked.
	Past the edge a deep pine wall and a fog bank hide the map's end at every zoom, and
	the ground rises into hills well beyond it.
]]

local Builder = require("./Builder")

local PineHollow = {}

PineHollow.half = 125
PineHollow.seed = 41

local V2 = Vector2.new

local TRACK = {
	V2(4, 190),
	V2(4, 118),
	V2(2, 80),
	V2(-4, 40),
	V2(-6, 4),
	V2(-10, -40),
	V2(-22, -82),
	V2(-26, -118),
	V2(-24, -190),
}
local LANE = { V2(-6, 4), V2(30, 14), V2(66, 24), V2(118, 30), V2(190, 30) }
local POND_TRAIL = { V2(-190, 34), V2(-118, 36), V2(-84, 46), V2(-44, 40), V2(-6, 30) }
local COTTAGE_PATH = { V2(-10, -40), V2(-44, -60), V2(-78, -76) }
local YARD = V2(-4, -22)
local POND = V2(-74, 64)
local CAMP = V2(-40, 92)
local RUIN = V2(-84, -82)
local ORCHARD_MIN, ORCHARD_MAX = V2(44, 40), V2(112, 104)

local PINES = { "EO_PineTree" }
local DEAD = { "EO_DeadTree" }

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function pathDistance(x: number, z: number): number
	return math.min(
		Builder.distanceToPath(x, z, TRACK),
		Builder.distanceToPath(x, z, LANE),
		Builder.distanceToPath(x, z, POND_TRAIL),
		Builder.distanceToPath(x, z, COTTAGE_PATH)
	)
end

local function height(x: number, z: number): number
	local outside = math.max(math.abs(x), math.abs(z)) - 110
	-- The hollow: gentle inside, rising into wooded hills past the edge.
	local rim = smoothstep(0, 110, outside) * 26
	local roll = math.noise(x / 52, z / 52, 4.1) * 2.6 + math.noise(x / 18, z / 18, 7.3) * 0.8
	local yard = 1 - smoothstep(40, 62, (V2(x, z) - YARD).Magnitude)
	local dip = (1 - smoothstep(8, 22, (V2(x, z) - POND).Magnitude)) * -4
	local path = 1 - smoothstep(3, 8, pathDistance(x, z))
	return (roll * (1 - yard * 0.85) + rim + dip) * (1 - path * 0.4)
end

local function surface(x: number, z: number, _y: number): Enum.Material
	local here = V2(x, z)
	local grain = math.noise(x / 6, z / 6, 2.2)
	local track = Builder.distanceToPath(x, z, TRACK)
	if track < 2.6 + grain * 0.8 then
		-- Two wheel ruts with a grassy crown between them.
		return if track < 1 and grain > -0.1 then Enum.Material.LeafyGrass else Enum.Material.Mud
	end
	if pathDistance(x, z) < 2.4 + grain * 0.9 or track < 5 + grain * 1.5 then
		return Enum.Material.Ground
	end
	local pond = (here - POND).Magnitude
	if pond < 24 + grain * 3 then
		return if pond < 19 then Enum.Material.Mud else Enum.Material.Ground
	end
	local yard = (here - YARD).Magnitude
	if yard < 40 + math.noise(x / 14, z / 14, 3.3) * 7 then
		local worn = math.noise(x / 12, z / 12, 9.9) + (1 - yard / 40) * 0.3
		return if worn + grain * 0.25 > 0.2 then Enum.Material.Ground else Enum.Material.LeafyGrass
	end
	if (here - CAMP).Magnitude < 14 + grain * 3 or (here - RUIN).Magnitude < 16 + grain * 3 then
		return Enum.Material.Ground
	end
	if x > ORCHARD_MIN.X and x < ORCHARD_MAX.X and z > ORCHARD_MIN.Y and z < ORCHARD_MAX.Y then
		return if math.noise(x / 18, z / 18, 5.5) > 0.2 then Enum.Material.Sand else Enum.Material.LeafyGrass
	end
	-- Woods floor everywhere else: needles, moss and earth.
	local patches = math.noise(x / 20, z / 20, 1.9) + grain * 0.2
	if patches > 0.35 then
		return Enum.Material.Ground
	elseif patches < -0.3 then
		return Enum.Material.Grass
	end
	return Enum.Material.LeafyGrass
end

local function water(x: number, z: number): number?
	return if (V2(x, z) - POND).Magnitude < 19 then -2 else nil
end

-- Points of interest ---------------------------------------------------------------------------------

local function farmhouse(ctx: Builder.Ctx)
	local house = Builder.building(ctx, {
		name = "Farmhouse",
		x = -32,
		z = -30,
		width = 30,
		depth = 20,
		height = 12,
		wall = "siding",
		trim = "trimLight",
		floor = "floorPlanks",
		roof = "gable",
		roofPaint = "shingle",
		porch = "S",
		chimney = true,
		openings = {
			{ side = "S", at = 0, kind = "door" },
			{ side = "S", at = -9, kind = "window" },
			{ side = "S", at = 9, kind = "window" },
			{ side = "E", at = -4, kind = "window" },
			{ side = "E", at = 5, kind = "door" },
			{ side = "W", at = 0, kind = "window" },
			{ side = "N", at = -8, kind = "window" },
			{ side = "N", at = 8, kind = "window" },
		},
	})
	local folder = house.model
	Builder.part(folder, Vector3.new(7, 4, 2.4), house.frame * CFrame.new(-10, 2.2, -8), "boards", "Dresser")
	Builder.part(folder, Vector3.new(3.6, 0.3, 7.6), house.frame * CFrame.new(11, 1.6, -4.5), "trim", "BedFrame")
	Builder.part(folder, Vector3.new(3.2, 0.6, 6.8), house.frame * CFrame.new(11, 2.1, -4.5), "cloth", "Mattress")
	Builder.part(folder, Vector3.new(5, 0.3, 3), house.frame * CFrame.new(-1, 3, 1), "boards", "Table")
	for _, leg in { -2, 2 } do
		Builder.part(folder, Vector3.new(0.3, 2.8, 2.6), house.frame * CFrame.new(-1 + leg, 1.5, 1), "trim")
	end
	local cx, cz, lift = Builder.inside(ctx, house, -11, 5)
	Builder.container(ctx, "crate", cx, cz, 90, nil, lift)
	local px, pz, plift = Builder.inside(ctx, house, 10, 6)
	Builder.container(ctx, "pack", px, pz, 30, nil, plift)
	local kx, kz, klift = Builder.inside(ctx, house, -4, -7)
	Builder.container(ctx, "cabinet", kx, kz, 180, nil, klift)
	local lx, lz, llift = Builder.inside(ctx, house, 0, 0)
	Builder.lamp(ctx, lx, lz, llift + 9.5, true, 20)
	-- Round the house: a woodpile, barrels, a scrap heap and sacks by the porch.
	Builder.kit(ctx, { "EO_BarrelCluster" }, -52, -18, 40)
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, -16, -14, 120)
	Builder.kit(ctx, { "EO_ScrapHeapClean" }, -54, -42, 200)
	Builder.kit(ctx, { "EO_StorageCrate" }, -50, -30, 10)
end

local function barn(ctx: Builder.Ctx)
	local barnBuilding = Builder.building(ctx, {
		name = "Barn",
		x = 32,
		z = -40,
		width = 34,
		depth = 26,
		height = 15,
		wall = "barn",
		trim = "trim",
		floor = "floorConcrete",
		roof = "gable",
		roofPaint = "roofMetal",
		openings = {
			{ side = "S", at = 0, kind = "gap", width = 10, height = 11 },
			{ side = "N", at = 0, kind = "gap", width = 10, height = 11 },
			{ side = "E", at = -6, kind = "window" },
			{ side = "E", at = 6, kind = "window" },
			{ side = "W", at = 5, kind = "door" },
		},
	})
	for index, spot in { { -11, -7 }, { -11, 3 }, { 11, -8 }, { 11, 8 } } do
		local x, z, lift = Builder.inside(ctx, barnBuilding, spot[1], spot[2])
		Builder.kit(ctx, { "EO_HayBales" }, x, z, index * 70, { height = 4.4, lift = lift })
	end
	for z = -9, 9, 6 do
		Builder.part(
			barnBuilding.model,
			Vector3.new(0.4, 5, 5.2),
			barnBuilding.frame * CFrame.new(-6, 2.6, z),
			"boards",
			"Stall"
		)
	end
	for _, spot in { { 12, 1 }, { -12, 9 } } do
		local x, z, lift = Builder.inside(ctx, barnBuilding, spot[1], spot[2])
		Builder.container(ctx, "crate", x, z, 0, nil, lift)
	end
	local tx, tz, tlift = Builder.inside(ctx, barnBuilding, 4, -2)
	Builder.kit(ctx, { "EO_TractorWreck" }, tx, tz, 90, { height = 7.5, lift = tlift })
	local lx, lz, lift = Builder.inside(ctx, barnBuilding, 0, 4)
	Builder.lamp(ctx, lx, lz, lift + 12.5, true, 24)
	-- Out front: hay stacked by the doors, a dumped sack pile and a lantern.
	Builder.kit(ctx, { "EO_HayBales" }, 54, -22, 15, { height = 4.4 })
	Builder.kit(ctx, { "EO_HayBales" }, 58, -30, 80, { height = 4.4 })
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, 14, -20, 60)
end

local function silo(ctx: Builder.Ctx)
	local folder = Builder.model(Builder.folder(ctx, "Buildings"), "Silo")
	folder:SetAttribute("Layer", "frame")
	local base = Builder.frame(ctx, 62, -62, 0)
	Builder.cylinder(folder, 26, 12, base * CFrame.new(0, 13, 0), "corrugated")
	Builder.cylinder(folder, 1.4, 12.6, base * CFrame.new(0, 26.6, 0), "rust")
	Builder.cylinder(folder, 1.8, 7.6, base * CFrame.new(0, 28, 0), "rust")
	Builder.cylinder(folder, 2, 13, base * CFrame.new(0, 1, 0), "concreteDark")
	for _, side in { -0.7, 0.7 } do
		Builder.part(folder, Vector3.new(0.2, 24, 0.2), base * CFrame.new(side, 13, 6.1), "steel")
	end
	for rung = 2, 24, 1.2 do
		Builder.part(folder, Vector3.new(1.5, 0.15, 0.15), base * CFrame.new(0, rung, 6.1), "steel")
	end
	Builder.kit(ctx, { "EO_BarrelCluster" }, 72, -48, 120)
end

local function shed(ctx: Builder.Ctx)
	local toolShed = Builder.building(ctx, {
		name = "ToolShed",
		x = 4,
		z = -76,
		width = 15,
		depth = 11,
		height = 9.5,
		wall = "corrugated",
		trim = "darkMetal",
		floor = "floorConcrete",
		roof = "shed",
		roofPaint = "roofMetal",
		openings = { { side = "S", at = 3, kind = "door" }, { side = "E", at = 0, kind = "window" } },
	})
	Builder.part(
		toolShed.model,
		Vector3.new(9, 0.3, 2.4),
		toolShed.frame * CFrame.new(0, 3.2, -3.6),
		"boards",
		"Workbench"
	)
	local x, z, lift = Builder.inside(ctx, toolShed, -4, 1)
	Builder.container(ctx, "locker", x, z, 180, nil, lift)
	local cx, cz, clift = Builder.inside(ctx, toolShed, 4, 2)
	Builder.container(ctx, "crate", cx, cz, 0, nil, clift)
	Builder.kit(ctx, { "EO_ScrapHeapClean" }, 18, -78, 60)
end

local function yard(ctx: Builder.Ctx)
	-- Wrecks and junk crowd the yard, with lanterns on posts and a fenced paddock.
	Builder.vehicle(ctx, "EO_PickupWreck", -14, 0, 104, { height = 7, tilt = 3 }, true)
	Builder.vehicle(ctx, "EO_SedanWreck", 16, -2, 20, { height = 6 }, true)
	Builder.kit(ctx, { "EO_BarrelCluster" }, -2, -48, 10)
	Builder.kit(ctx, { "EO_StorageCrate" }, 8, -50, 30)
	Builder.kit(ctx, { "EO_ScrapHeapClean" }, 30, -8, 140)
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, -30, 12, 60)
	Builder.kit(ctx, { "EO_CampfireRing" }, 2, -26, 0)
	for _, spot in { V2(-14, -16), V2(14, -20), V2(-6, -60), V2(40, 2) } do
		Builder.kit(ctx, { "EO_LanternPost" }, spot.X, spot.Y, ctx.rng:NextNumber() * 360)
		Builder.lamp(ctx, spot.X, spot.Y, 6.5, true, 20)
	end
	Builder.container(ctx, "crate", 22, -18, 15)
	Builder.container(ctx, "pack", -8, -36, 70)
	Builder.container(ctx, "pack", 36, -4, 200)
	Builder.railFence(ctx, { V2(-62, 16), V2(-62, -54), V2(-30, -58) })
	Builder.railFence(ctx, { V2(50, 14), V2(80, 10), V2(84, -78), V2(30, -92) })
	Builder.railFence(ctx, { V2(-20, 20), V2(-58, 22) })
end

local function orchard(ctx: Builder.Ctx)
	local rng = ctx.rng
	local row = 0
	for z = ORCHARD_MIN.Y + 4, ORCHARD_MAX.Y - 4, 10 do
		row += 1
		for x = ORCHARD_MIN.X + 4, ORCHARD_MAX.X - 4, 10 do
			if rng:NextNumber() < 0.86 then
				local jx, jz = (rng:NextNumber() - 0.5) * 3, (rng:NextNumber() - 0.5) * 3
				local names = if rng:NextNumber() < 0.12 then DEAD else { "EO_AppleTree" }
				Builder.kit(ctx, names, x + jx + (row % 2) * 5, z + jz, rng:NextNumber() * 360, {
					height = 12 + rng:NextNumber() * 3,
					canopy = true,
				})
			end
		end
	end
	Builder.railFence(ctx, {
		V2(ORCHARD_MIN.X - 4, ORCHARD_MIN.Y - 4),
		V2(ORCHARD_MAX.X + 4, ORCHARD_MIN.Y - 4),
		V2(ORCHARD_MAX.X + 4, ORCHARD_MAX.Y + 4),
		V2(ORCHARD_MIN.X - 4, ORCHARD_MAX.Y + 4),
		V2(ORCHARD_MIN.X - 4, 74),
	})
	Builder.kit(ctx, { "EO_TractorWreck" }, 96, 58, 250, { height = 7.5 })
	Builder.kit(ctx, { "EO_HayBales" }, 52, 92, 30, { height = 4.4 })
	Builder.kit(ctx, { "EO_HayBales" }, 104, 44, 120, { height = 4.4 })
	Builder.kit(ctx, { "EO_BarrelCluster" }, 74, 98, 30)
	for _, spot in { V2(66, 60), V2(90, 84), V2(78, 46), V2(58, 74) } do
		Builder.container(ctx, "pack", spot.X, spot.Y, rng:NextNumber() * 360)
	end
	Builder.container(ctx, "crate", 100, 96, 40)
end

local function pondCamp(ctx: Builder.Ctx)
	-- A tarp lean-to over a cold fire by the reeds: someone camped here and left fast.
	-- Open to the north, towards the fire, so its slope faces the camera and reads as a tarp.
	Builder.leanTo(ctx, "HunterCamp", CAMP.X + 2, CAMP.Y + 13, 0, "tarp")
	Builder.kit(ctx, { "EO_CampfireRing" }, CAMP.X + 4, CAMP.Y + 6, 0)
	Builder.kit(ctx, { "EO_BarrelCluster" }, CAMP.X - 9, CAMP.Y + 2, 70)
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, CAMP.X + 9, CAMP.Y - 2, 20)
	Builder.kit(ctx, { "EO_LanternPost" }, CAMP.X + 10, CAMP.Y - 6, 200)
	Builder.lamp(ctx, CAMP.X + 9, CAMP.Y - 6, 6.5, true, 20)
	Builder.container(ctx, "pack", CAMP.X - 2, CAMP.Y - 1, 10)
	Builder.container(ctx, "pack", CAMP.X + 3, CAMP.Y + 1, 200)
	Builder.container(ctx, "crate", CAMP.X - 11, CAMP.Y - 6, 110)
	Builder.vehicle(ctx, "EO_VanWreck", CAMP.X + 26, CAMP.Y - 4, 160, { height = 8.5, tilt = 2 }, true)
	-- Reeds and stones round the pond.
	local rng = ctx.rng
	for index = 1, 22 do
		local angle = index / 22 * math.pi * 2 + rng:NextNumber() * 0.2
		local r = 19 + rng:NextNumber() * 4
		Builder.kit(
			ctx,
			{ "EO_ReedsClean" },
			POND.X + math.cos(angle) * r,
			POND.Y + math.sin(angle) * r,
			rng:NextNumber() * 360,
			{
				solid = false,
			}
		)
	end
	Builder.kit(ctx, { "EO_RockCluster" }, POND.X + 22, POND.Y + 14, 40)
	Builder.kit(ctx, { "EO_RockCluster" }, POND.X - 20, POND.Y - 16, 160)
end

local function ruinedCottage(ctx: Builder.Ctx)
	local cottage = Builder.building(ctx, {
		name = "RuinedCottage",
		x = RUIN.X,
		z = RUIN.Y,
		width = 20,
		depth = 15,
		height = 10,
		wall = "brickDark",
		trim = "trim",
		floor = "boards",
		roof = "none",
		ruin = 0.55,
		openings = {
			{ side = "S", at = -3, kind = "door" },
			{ side = "E", at = 0, kind = "window" },
			{ side = "W", at = 1, kind = "window" },
			{ side = "N", at = 4, kind = "window" },
		},
	})
	Builder.rubble(ctx, RUIN.X + 9, RUIN.Y + 9, 4, "brickDark")
	Builder.rubble(ctx, RUIN.X - 6, RUIN.Y - 3, 3, "brickDark")
	Builder.rubble(ctx, RUIN.X + 13, RUIN.Y - 6, 2.5, "brickDark")
	local x, z, lift = Builder.inside(ctx, cottage, 4, -3)
	Builder.container(ctx, "crate", x, z, 20, nil, lift)
	local sx, sz, slift = Builder.inside(ctx, cottage, -5, 3)
	Builder.container(ctx, "strongbox", sx, sz, 200, nil, slift)
	-- The roof came down inside: charred beams across the floor, fallen stone and weeds.
	for _, beam in { { -4, -2, 25, 12 }, { 3, 2, -35, 10 }, { 6, -4, 80, 8 }, { -6, 4, 100, 7 } } do
		Builder.part(
			cottage.model,
			Vector3.new(0.8, 0.8, beam[4]),
			cottage.frame
				* CFrame.new(beam[1], 1.1, beam[2])
				* CFrame.Angles(math.rad(7), math.rad(beam[3]), math.rad(5)),
			"trim",
			"FallenBeam"
		)
	end
	local inside = {
		{ x = -3, z = -4, name = "EO_LooseStonesClean" },
		{ x = 7, z = 4, name = "EO_EmberBushClean" },
		{ x = -7, z = -5, name = "EO_BareBranches" },
	}
	for _, spot in inside do
		local ix, iz, ilift = Builder.inside(ctx, cottage, spot.x, spot.z)
		Builder.kit(ctx, { spot.name }, ix, iz, ctx.rng:NextNumber() * 360, { lift = ilift, solid = false })
	end
	Builder.kit(ctx, DEAD, RUIN.X - 16, RUIN.Y + 12, 40, { height = 17 })
	Builder.kit(ctx, DEAD, RUIN.X + 18, RUIN.Y + 16, 200, { height = 15 })
	Builder.kit(ctx, { "EO_ScrapHeapClean" }, RUIN.X + 4, RUIN.Y + 14, 100)
	Builder.kit(ctx, { "EO_BarrelCluster" }, RUIN.X - 13, RUIN.Y - 6, 10)
end

-- Fill: woods and undergrowth in every gap --------------------------------------------------------

local function clearOf(x: number, z: number): boolean
	local here = V2(x, z)
	return pathDistance(x, z) < 7
		or (here - YARD).Magnitude < 58
		or (here - V2(62, -62)).Magnitude < 14
		or (here - POND).Magnitude < 26
		or (here - CAMP).Magnitude < 22
		or (here - V2(CAMP.X + 26, CAMP.Y)).Magnitude < 12
		or (here - RUIN).Magnitude < 22
		or (x > ORCHARD_MIN.X - 8 and x < ORCHARD_MAX.X + 8 and z > ORCHARD_MIN.Y - 8 and z < ORCHARD_MAX.Y + 8)
end

local function woods(ctx: Builder.Ctx)
	local rng = ctx.rng
	local half = PineHollow.half
	-- Pine woods filling the hollow between the points of interest.
	local placed = 0
	for gx = -half + 4, half - 4, 11 do
		for gz = -half + 4, half - 4, 11 do
			local x = gx + (rng:NextNumber() - 0.5) * 9
			local z = gz + (rng:NextNumber() - 0.5) * 9
			if not clearOf(x, z) and rng:NextNumber() < 0.78 then
				local dead = rng:NextNumber() < 0.08
				Builder.kit(ctx, if dead then DEAD else PINES, x, z, rng:NextNumber() * 360, {
					height = (if dead then 15 else 19) + rng:NextNumber() * 8,
					canopy = true,
				})
				placed += 1
				if placed % 40 == 0 then
					task.wait()
				end
			end
		end
	end
	-- Undergrowth: bushes, branches, stumps and stones under the trees and along the paths.
	local under = {
		{ "EO_EmberBushClean" },
		{ "EO_BareBranches" },
		{ "EO_LooseStonesClean" },
		{ "EO_FatwoodStump" },
		{ "EO_EmberBushClean" },
	}
	for count = 1, 260 do
		local x, z = (rng:NextNumber() * 2 - 1) * (half - 4), (rng:NextNumber() * 2 - 1) * (half - 4)
		if Builder.distanceToPath(x, z, TRACK) > 4 and (V2(x, z) - POND).Magnitude > 20 then
			local names = under[rng:NextInteger(1, #under)]
			Builder.kit(ctx, names, x, z, rng:NextNumber() * 360, { solid = false })
		end
		if count % 60 == 0 then
			task.wait()
		end
	end
	for _ = 1, 14 do
		local x, z = (rng:NextNumber() * 2 - 1) * (half - 10), (rng:NextNumber() * 2 - 1) * (half - 10)
		if not clearOf(x, z) then
			Builder.kit(ctx, { "EO_RockCluster" }, x, z, rng:NextNumber() * 360)
		end
	end
	-- Things left along the paths.
	Builder.container(ctx, "pack", -60, 108, 40)
	Builder.container(ctx, "pack", 48, -100, 300)
	Builder.container(ctx, "crate", -104, 6, 0)
	Builder.vehicle(ctx, "EO_SedanWreck", 14, 70, 168, { height = 6, tilt = 4 }, true)
end

local function edges(ctx: Builder.Ctx)
	local half = PineHollow.half
	Builder.treeWall(ctx, {
		half = half,
		names = PINES,
		dead = DEAD,
		depth = 80,
		spacing = 8.5,
		height = 22,
		gaps = { V2(4, half), V2(-26, -half), V2(half, 30), V2(-half, 34) },
	})
	-- Light fog's bank: pale and thin.
	Builder.fogBank(ctx, half, Color3.fromRGB(196, 202, 198), 1.2)
end

local function gatherables(ctx: Builder.Ctx)
	local rng = ctx.rng
	local function spot(radius: number, centre: Vector2): Vector2
		local angle = rng:NextNumber() * math.pi * 2
		return centre + V2(math.cos(angle), math.sin(angle)) * (radius * (0.4 + rng:NextNumber() * 0.6))
	end
	-- Pines to fell at the woods' edges, stones and branches in the clearings, reeds by
	-- the pond, stumps and ember bushes in the woods.
	for index = 1, 14 do
		local p = spot(26, if index % 2 == 0 then V2(-92, -20) else V2(86, -96))
		Builder.node(ctx, "node.pine_tree", p.X, p.Y)
	end
	for _ = 1, 8 do
		local p = spot(30, V2(-96, -40))
		Builder.node(ctx, "node.boulder", p.X, p.Y)
	end
	for _ = 1, 8 do
		local p = spot(40, V2(30, 60))
		Builder.node(ctx, "node.fallen_branches", p.X, p.Y)
		local q = spot(40, V2(-30, 50))
		Builder.node(ctx, "node.loose_stones", q.X, q.Y)
	end
	for _ = 1, 8 do
		local p = spot(24, POND)
		Builder.node(ctx, "node.reed_patch", p.X, p.Y)
	end
	for _ = 1, 5 do
		local p = spot(30, V2(80, 112))
		Builder.node(ctx, "node.ember_bush", p.X, p.Y)
		local q = spot(26, V2(-90, 100))
		Builder.node(ctx, "node.ashroot_mound", q.X, q.Y)
	end
	Builder.node(ctx, "node.spring_pool", POND.X + 22, POND.Y - 12)
	Builder.node(ctx, "node.spring_pool", 100, -110)
end

local function markers(ctx: Builder.Ctx)
	for index, spawn in { V2(4, 110), V2(-6, 106), V2(14, 106), V2(-14, 112), V2(10, 98), V2(-2, 96) } do
		Builder.marker(ctx, "spawn", spawn.X, spawn.Y, { Index = index })
	end
	local hollows = {
		V2(-26, -40),
		V2(26, -56),
		V2(40, -14),
		V2(-48, -70),
		V2(76, 70),
		V2(100, 36),
		V2(62, 96),
		V2(-60, 44),
		V2(-90, 20),
		V2(-58, 104),
		V2(-100, -96),
		V2(-70, -104),
		V2(80, -104),
		V2(-110, 70),
	}
	for _, at in hollows do
		Builder.marker(ctx, "hollow", at.X, at.Y)
	end
	-- Light fog: any edge works; the trail ends are marked.
	local half = PineHollow.half
	Builder.exit(ctx, "edge", "South trail", 4, half - 8, 9, 0)
	Builder.exit(ctx, "edge", "North trail", -26, -half + 8, 9, 0)
	Builder.exit(ctx, "edge", "Orchard lane", half - 8, 30, 9, 90)
	Builder.exit(ctx, "edge", "Pond path", -half + 8, 34, 9, 90)
end

function PineHollow.build(ctx: Builder.Ctx)
	Builder.terrain(ctx, { extent = PineHollow.half + 140, height = height, surface = surface, water = water })
	yard(ctx)
	farmhouse(ctx)
	barn(ctx)
	silo(ctx)
	shed(ctx)
	orchard(ctx)
	pondCamp(ctx)
	ruinedCottage(ctx)
	woods(ctx)
	edges(ctx)
	gatherables(ctx)
	markers(ctx)
end

return PineHollow
