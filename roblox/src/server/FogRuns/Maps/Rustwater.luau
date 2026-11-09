--!strict
--[[
	Rustwater (Dense fog, loc.sunken_quarry): an abandoned roadside town.

	The highway runs east-west along the south; Main Street leaves it north through
	the town to the North Road. Cross Street runs east to the creek bridge. Shops line
	Main Street (diner, hardware store, post office on the west; general store,
	garage and a chapel on the east), houses with dead lawns along Cross Street, the
	gas station on the highway corner. Cars sit where they were left.

	Dense fog: three marked exits (North Road, Highway West, Creek Bridge); the
	lobby seed closes one. Containers: lockers and cabinets indoors, car boots.
]]

local Builder = require("./Builder")

local Rustwater = {}

Rustwater.half = 180
Rustwater.seed = 77

local V2 = Vector2.new

local HIGHWAY_Z = 112
local CROSS_Z = -42
local CREEK_X = 132

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function creekDistance(x: number, z: number): number
	local meander = math.noise(z / 50, 0, 3.7) * 10
	return math.abs(x - (CREEK_X + meander))
end

local function height(x: number, z: number): number
	local outside = math.max(math.abs(x), math.abs(z)) - 160
	local rim = smoothstep(0, 80, outside) * 16
	local roll = math.noise(x / 70, z / 70, 1.3) * 1.6
	-- The town is graded flat along its streets: the road slabs lie on level ground.
	local street = math.min(math.abs(x), math.abs(z - HIGHWAY_Z), math.abs(z - CROSS_Z))
	roll *= smoothstep(10, 26, street)
	local creek = creekDistance(x, z)
	local channel = (1 - smoothstep(6, 16, creek)) * -7
	-- The bridge deck crosses the creek on Cross Street, so the banks stay up there.
	return roll + rim + channel
end

local function surface(x: number, z: number, _y: number): Enum.Material
	local grain = math.noise(x / 5, z / 5, 8.8)
	local creek = creekDistance(x, z)
	if creek < 9 then
		return if creek < 6 then Enum.Material.Mud else Enum.Material.Ground
	end
	local main = math.abs(x)
	local highway = math.abs(z - HIGHWAY_Z)
	local cross = math.abs(z - CROSS_Z)
	local onMain = main < 9 and z < HIGHWAY_Z + 8
	local onHighway = highway < 8
	local onCross = cross < 8.5 and x > -152
	if onMain or onHighway or onCross then
		return Enum.Material.Ground -- earth under the road slabs (Builder.road) and sidewalks
	end
	if highway < 13 then
		return Enum.Material.Cobblestone -- the gravel shoulder
	end
	-- The gas station forecourt (a concrete slab covers it).
	if x > 22 and x < 78 and z > 66 and z < HIGHWAY_Z - 8 then
		return Enum.Material.Ground
	end
	local outside = math.max(math.abs(x), math.abs(z)) - 140
	if outside > 0 then
		return if grain > 0.3 then Enum.Material.Ground else Enum.Material.LeafyGrass
	end
	-- Dead lawns and vacant lots: dry grass with worn earth.
	local patches = math.noise(x / 26, z / 26, 2.6) + grain * 0.2
	if patches > 0.35 then
		return Enum.Material.Ground
	elseif patches > -0.1 then
		return Enum.Material.Sand
	end
	return Enum.Material.Grass
end

local function water(x: number, z: number): number?
	return if creekDistance(x, z) < 6 then -4.4 else nil
end

local CARS = { "EO_SedanWreck", "EO_PickupWreck", "EO_VanWreck" }

local function place(ctx: Builder.Ctx, building: Builder.Building, kind: string, lx: number, lz: number, yaw: number)
	local x, z, lift = Builder.inside(ctx, building, lx, lz)
	Builder.container(ctx, kind, x, z, yaw, nil, lift)
end

local function lamp(ctx: Builder.Ctx, building: Builder.Building, lx: number, lz: number, above: number, warm: boolean)
	local x, z, lift = Builder.inside(ctx, building, lx, lz)
	Builder.lamp(ctx, x, z, lift + above, warm, 18)
end

local function shelving(building: Builder.Building, lx: number, lz: number, length: number, yaw: number)
	local frame = building.frame * CFrame.new(lx, 0, lz) * CFrame.Angles(0, math.rad(yaw), 0)
	for level = 0, 2 do
		Builder.part(
			building.model,
			Vector3.new(length, 0.25, 2),
			frame * CFrame.new(0, 0.6 + level * 2.2, 0),
			"rust",
			"Shelf"
		)
	end
	for _, side in { -1, 1 } do
		Builder.part(
			building.model,
			Vector3.new(0.25, 6.4, 2),
			frame * CFrame.new(side * length / 2, 3.2, 0),
			"darkMetal",
			"Upright"
		)
	end
end

local function counter(building: Builder.Building, lx: number, lz: number, length: number, yaw: number)
	local frame = building.frame * CFrame.new(lx, 0, lz) * CFrame.Angles(0, math.rad(yaw), 0)
	Builder.part(building.model, Vector3.new(length, 3.4, 2), frame * CFrame.new(0, 1.9, 0), "boards", "Counter")
	Builder.part(
		building.model,
		Vector3.new(length + 0.3, 0.25, 2.3),
		frame * CFrame.new(0, 3.7, 0),
		"floorTile",
		"CounterTop"
	)
end

local function westShops(ctx: Builder.Ctx)
	-- Fronts face east onto Main Street.
	local diner = Builder.building(ctx, {
		name = "Diner",
		x = -26,
		z = 66,
		width = 18,
		depth = 26,
		height = 10,
		wall = "plaster",
		trim = "trimLight",
		floor = "floorTile",
		roof = "flat",
		roofPaint = "concreteDark",
		openings = {
			{ side = "E", at = 0, kind = "door" },
			{ side = "E", at = -7, kind = "window", width = 5 },
			{ side = "E", at = 7, kind = "window", width = 5 },
			{ side = "S", at = 0, kind = "window", width = 6 },
			{ side = "W", at = 6, kind = "door" },
		},
	})
	counter(diner, -3, -4, 10, 90)
	place(ctx, diner, "locker", -6.5, 9, 180)
	place(ctx, diner, "cabinet", -6.5, -10, 90)
	lamp(ctx, diner, 0, 0, 8.6, false)

	local hardware = Builder.building(ctx, {
		name = "Hardware",
		x = -30,
		z = 10,
		width = 24,
		depth = 28,
		height = 12,
		wall = "brick",
		trim = "trim",
		floor = "floorConcrete",
		roof = "flat",
		openings = {
			{ side = "E", at = -3, kind = "door", width = 6 },
			{ side = "E", at = 6, kind = "window", width = 6 },
			{ side = "E", at = -10, kind = "window" },
			{ side = "N", at = 4, kind = "window" },
			{ side = "W", at = -8, kind = "door" },
		},
	})
	shelving(hardware, -4, -6, 12, 0)
	shelving(hardware, -4, 3, 12, 0)
	counter(hardware, 7, -9, 8, 90)
	place(ctx, hardware, "cabinet", -9, 11, 0)
	place(ctx, hardware, "cabinet", 6, 11, 0)
	lamp(ctx, hardware, 0, 0, 10.4, true)

	local post = Builder.building(ctx, {
		name = "PostOffice",
		x = -28,
		z = -84,
		width = 20,
		depth = 22,
		height = 11,
		wall = "brickDark",
		trim = "trimLight",
		floor = "floorTile",
		roof = "flat",
		openings = {
			{ side = "E", at = 0, kind = "door" },
			{ side = "E", at = -6, kind = "window" },
			{ side = "E", at = 6, kind = "window" },
			{ side = "S", at = 3, kind = "window" },
		},
	})
	counter(post, 2, 0, 12, 90)
	place(ctx, post, "locker", -6.5, -8, 90)
	place(ctx, post, "locker", -6.5, -5.5, 90)
	place(ctx, post, "cabinet", -6, 7, 90)

	local house = Builder.building(ctx, {
		name = "MainHouse",
		x = -32,
		z = -138,
		width = 18,
		depth = 14,
		height = 10,
		wall = "sidingBlue",
		trim = "trimLight",
		roof = "gable",
		roofPaint = "shingleRed",
		porch = "E",
		openings = {
			{ side = "E", at = 0, kind = "door" },
			{ side = "E", at = -4.5, kind = "window" },
			{ side = "S", at = -4, kind = "window" },
			{ side = "S", at = 4, kind = "window" },
		},
	})
	place(ctx, house, "cabinet", -5, -4, 0)
end

local function eastShops(ctx: Builder.Ctx)
	-- Fronts face west onto Main Street (their backs to the camera: the fade shows inside).
	local store = Builder.building(ctx, {
		name = "GeneralStore",
		x = 32,
		z = 18,
		width = 24,
		depth = 30,
		height = 12,
		wall = "brick",
		trim = "trimLight",
		floor = "floorPlanks",
		roof = "flat",
		openings = {
			{ side = "W", at = 0, kind = "door", width = 6 },
			{ side = "W", at = -9, kind = "window", width = 6 },
			{ side = "W", at = 9, kind = "window", width = 6 },
			{ side = "S", at = 5, kind = "window" },
			{ side = "E", at = 6, kind = "door" },
		},
	})
	shelving(store, 2, -6, 10, 90)
	shelving(store, 6, -6, 10, 90)
	counter(store, -6, 10, 8, 0)
	place(ctx, store, "cabinet", 9, 12, 270)
	place(ctx, store, "locker", 9, -12, 270)
	lamp(ctx, store, 0, 0, 10.4, false)

	local garage = Builder.building(ctx, {
		name = "Garage",
		x = 38,
		z = -32,
		width = 26,
		depth = 22,
		height = 11,
		wall = "corrugated",
		trim = "darkMetal",
		floor = "floorConcrete",
		roof = "shed",
		roofPaint = "roofMetal",
		openings = {
			{ side = "W", at = -3, kind = "gap", width = 10, height = 9 },
			{ side = "W", at = 8, kind = "door" },
			{ side = "S", at = 6, kind = "window" },
			{ side = "E", at = 0, kind = "window" },
		},
	})
	local carX, carZ, carLift = Builder.inside(ctx, garage, -2, -3)
	Builder.kit(ctx, { "EO_SedanWreck" }, carX, carZ, 90, { height = 5, lift = carLift })
	place(ctx, garage, "locker", 11.5, 7, 270)
	place(ctx, garage, "locker", 11.5, 4.6, 270)
	place(ctx, garage, "cabinet", 6, -9.2, 0)
	Builder.part(garage.model, Vector3.new(10, 0.3, 2.4), garage.frame * CFrame.new(5, 3.2, 9.2), "steel", "Workbench")
	lamp(ctx, garage, 0, 0, 9.4, true)

	local chapel = Builder.building(ctx, {
		name = "Chapel",
		x = 40,
		z = -100,
		width = 18,
		depth = 30,
		height = 13,
		wall = "plaster",
		trim = "trim",
		floor = "floorPlanks",
		roof = "gable",
		roofPaint = "shingle",
		openings = {
			{ side = "W", at = 0, kind = "door", width = 5 },
			{ side = "N", at = -4, kind = "window" },
			{ side = "N", at = 4, kind = "window" },
			{ side = "S", at = -4, kind = "window" },
			{ side = "S", at = 4, kind = "window" },
		},
		ruin = 0.35,
	})
	for z = -9, 9, 4.5 do
		for _, side in { -4, 4 } do
			Builder.part(
				chapel.model,
				Vector3.new(4.2, 1.6, 1.2),
				chapel.frame * CFrame.new(side, 1.2, z),
				"boards",
				"Pew"
			)
		end
	end
	place(ctx, chapel, "cabinet", 5, 13, 180)
	Builder.rubble(ctx, 50, -112, 4, "plaster")
end

local function houses(ctx: Builder.Ctx)
	local specs = {
		{ x = -78, z = -66, wall = "siding", roof = "shingle", yaw = 0 },
		{ x = -104, z = -10, wall = "sidingGreen", roof = "shingleRed", yaw = 90 },
		{ x = 86, z = -74, wall = "sidingBlue", roof = "shingle", yaw = 0 },
		{ x = 92, z = 18, wall = "siding", roof = "shingle", yaw = 270 },
	}
	for index, spec in specs do
		local house = Builder.building(ctx, {
			name = `House{index}`,
			x = spec.x,
			z = spec.z,
			yaw = spec.yaw,
			width = 16,
			depth = 12,
			height = 9.5,
			wall = spec.wall,
			trim = "trimLight",
			floor = "floorPlanks",
			roof = "gable",
			roofPaint = spec.roof,
			porch = "S",
			openings = {
				{ side = "S", at = 0, kind = "door" },
				{ side = "S", at = -5, kind = "window" },
				{ side = "S", at = 5, kind = "window" },
				{ side = "E", at = 0, kind = "window" },
				{ side = "N", at = 3, kind = "door" },
			},
			ruin = if index == 3 then 0.45 else 0,
		})
		place(ctx, house, "cabinet", -5.5, -3.5, 0)
		Builder.part(house.model, Vector3.new(3, 0.3, 6), house.frame * CFrame.new(5, 1.5, -2), "trim", "Bed")
		Builder.part(house.model, Vector3.new(2.6, 0.5, 5.4), house.frame * CFrame.new(5, 1.9, -2), "cloth", "Mattress")
		-- A picket fence round the front yard.
		local a = Builder.local2(ctx, house, -10, 6)
		local b = Builder.local2(ctx, house, -10, 14)
		local c = Builder.local2(ctx, house, 10, 14)
		local d = Builder.local2(ctx, house, 10, 6)
		Builder.railFence(ctx, { a, b, V2((b.X + c.X) / 2 - 2, (b.Y + c.Y) / 2) }, "trimLight")
		Builder.railFence(ctx, { V2((b.X + c.X) / 2 + 2, (b.Y + c.Y) / 2), c, d }, "trimLight")
	end
end

local function gasStation(ctx: Builder.Ctx)
	local forecourt = Builder.model(Builder.folder(ctx, "Buildings"), "Forecourt")
	Builder.part(forecourt, Vector3.new(54, 1, 38), Builder.frame(ctx, 50, 85, 0, -0.32), "concrete", "Slab")
	local holder = Builder.model(Builder.folder(ctx, "Buildings"), "GasCanopy")
	holder:SetAttribute("Layer", "roof")
	local base = Builder.frame(ctx, 50, 86, 0)
	for _, x in { -11, 11 } do
		for _, z in { -5, 5 } do
			Builder.part(holder, Vector3.new(1, 13, 1), base * CFrame.new(x, 6.5, z), "concrete", "Pillar")
		end
	end
	Builder.part(holder, Vector3.new(28, 1.6, 16), base * CFrame.new(0, 13.6, 0), "concreteDark", "Canopy")
	Builder.part(holder, Vector3.new(28.2, 0.6, 16.2), base * CFrame.new(0, 12.9, 0), "rust", "Band")
	for _, x in { -5, 5 } do
		Builder.part(holder, Vector3.new(4, 0.8, 2), base * CFrame.new(x, 0.4, 0), "concrete", "Island")
		Builder.kit(ctx, { "EO_FuelPump" }, 50 + x, 86, 180, { height = 5, lift = 0.8 })
	end
	Builder.lamp(ctx, 50, 86, 12.5, false, 24)
	local kiosk = Builder.building(ctx, {
		name = "Kiosk",
		x = 50,
		z = 64,
		width = 16,
		depth = 12,
		height = 10,
		wall = "brickDark",
		trim = "trimLight",
		floor = "floorTile",
		roof = "flat",
		openings = {
			{ side = "S", at = -2, kind = "door" },
			{ side = "S", at = 4, kind = "window", width = 6 },
			{ side = "W", at = 0, kind = "window" },
		},
	})
	counter(kiosk, 0, 0, 8, 0)
	shelving(kiosk, 0, -4, 10, 0)
	place(ctx, kiosk, "locker", 6.5, -3, 270)
	place(ctx, kiosk, "cabinet", -5.5, 3, 90)
	Builder.sign(ctx, 74, 100, 0, "rust")
	Builder.utilityPole(ctx, 26, 104, V2(-26, 104))
	Builder.utilityPole(ctx, -26, 104, V2(-80, 104))
	Builder.utilityPole(ctx, -80, 104, nil)
end

local function street(ctx: Builder.Ctx)
	local rng = ctx.rng
	-- Lamps down Main Street, a few still burning.
	for z = 90, -150, -30 do
		Builder.streetLamp(ctx, -9, z, 90, rng:NextNumber() < 0.35)
		Builder.streetLamp(ctx, 9, z - 15, 270, rng:NextNumber() < 0.35)
	end
	-- Cars where they were left: parked at the kerb, abandoned mid-street, a highway jam.
	local cars = {
		{ -5, 40, 2 },
		{ 4, -10, 178 },
		{ -4, -60, 8 },
		{ 3, -118, 186 },
		{ -2, 22, 24 },
		{ -60, HIGHWAY_Z - 3, 90 },
		{ -34, HIGHWAY_Z + 4, 268 },
		{ 18, HIGHWAY_Z - 4, 96 },
		{ 96, HIGHWAY_Z + 3, 272 },
		{ 130, HIGHWAY_Z - 2, 80 },
		{ 70, CROSS_Z + 2, 92 },
		{ -70, CROSS_Z - 2, 270 },
		{ 36, 82, 40 },
	}
	for index, car in cars do
		local names = { CARS[(index % #CARS) + 1] }
		-- Every sedan's boot is a container spot.
		local tall = if names[1] == "EO_VanWreck" then 7 else 5.5
		Builder.vehicle(ctx, names[1], car[1], car[2], car[3], { height = tall }, names[1] == "EO_SedanWreck")
	end
	-- Barricades where someone tried to hold Main Street, and a checkpoint on the highway.
	for x = -12, 12, 6.5 do
		Builder.barrier(ctx, x, -20, 0)
	end
	for z = HIGHWAY_Z - 9, HIGHWAY_Z + 9, 6.5 do
		Builder.barrier(ctx, -120, z, 90)
	end
	Builder.dumpster(ctx, -46, 40, 90)
	Builder.dumpster(ctx, 52, -8, 270)
	Builder.dumpster(ctx, -46, -110, 90)
	for _, spot in { V2(-14, 30), V2(14, -60), V2(-14, -100) } do
		Builder.bench(ctx, spot.X, spot.Y, if spot.X < 0 then 90 else 270)
	end
	Builder.kit(ctx, { "EO_BarrelCluster" }, 62, -50, 20)
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, -48, 22, 80)
	Builder.kit(ctx, { "EO_StorageCrate" }, 62, -14, 0)
	-- Dead street trees and the little square by the post office.
	for _, spot in { V2(-16, -40), V2(16, 44), V2(-16, 92), V2(-70, -110), V2(-90, -122), V2(-60, -128), V2(70, 40) } do
		Builder.kit(
			ctx,
			{ "EO_DeadTree" },
			spot.X,
			spot.Y,
			rng:NextNumber() * 360,
			{ height = 14 + rng:NextNumber() * 4 }
		)
	end
	Builder.bench(ctx, -76, -118, 30)
	Builder.bench(ctx, -84, -104, 200)
end

local function bridge(ctx: Builder.Ctx)
	local holder = Builder.model(Builder.folder(ctx, "Buildings"), "CreekBridge")
	local x = CREEK_X + math.noise(CROSS_Z / 50, 0, 3.7) * 10
	local deckY = math.max(ctx.groundHeight(x - 16, CROSS_Z), ctx.groundHeight(x + 16, CROSS_Z)) + 0.4
	local base = CFrame.new(ctx.origin + Vector3.new(x, deckY, CROSS_Z))
	Builder.part(holder, Vector3.new(34, 1, 11), base, "concrete", "Deck")
	for _, side in { -5.2, 5.2 } do
		Builder.part(holder, Vector3.new(34, 0.4, 0.4), base * CFrame.new(0, 3, side), "rust", "Rail")
		for post = -16, 16, 4 do
			Builder.part(holder, Vector3.new(0.4, 2.6, 0.4), base * CFrame.new(post, 1.8, side), "rust", "Post")
		end
	end
	for _, pier in { -8, 8 } do
		Builder.part(holder, Vector3.new(2, 10, 9), base * CFrame.new(pier, -5.5, 0), "concreteDark", "Pier")
	end
end

local function edges(ctx: Builder.Ctx)
	local rng = ctx.rng
	for _ = 1, 160 do
		local x = (rng:NextNumber() * 2 - 1) * 240
		local z = (rng:NextNumber() * 2 - 1) * 240
		local edge = math.max(math.abs(x), math.abs(z))
		local road = math.abs(x) < 14 or math.abs(z - HIGHWAY_Z) < 16 or (math.abs(z - CROSS_Z) < 12 and x > -150)
		if edge > 158 and not road and creekDistance(x, z) > 12 then
			local names = if rng:NextNumber() < 0.7 then { "EO_PineTree" } else { "EO_DeadTree" }
			Builder.kit(ctx, names, x, z, rng:NextNumber() * 360, { height = 18 + rng:NextNumber() * 8, canopy = true })
		end
	end
	-- Creek-side reeds and stumps; fieldstones and branches across the lots.
	for _ = 1, 30 do
		local x, z = (rng:NextNumber() * 2 - 1) * 150, (rng:NextNumber() * 2 - 1) * 150
		if math.abs(x) > 50 and math.abs(z - HIGHWAY_Z) > 16 then
			local names = if rng:NextNumber() < 0.5 then { "EO_BareBranches" } else { "EO_LooseStonesClean" }
			Builder.kit(ctx, names, x, z, rng:NextNumber() * 360, { solid = false })
		end
	end
end

local function gatherables(ctx: Builder.Ctx)
	local rng = ctx.rng
	local function near(centre: Vector2, radius: number): Vector2
		local angle = rng:NextNumber() * math.pi * 2
		return centre + V2(math.cos(angle), math.sin(angle)) * radius * (0.5 + rng:NextNumber() * 0.5)
	end
	for _ = 1, 6 do
		local p = near(V2(-120, -140), 28)
		Builder.node(ctx, "node.pine_tree", p.X, p.Y)
		local q = near(V2(110, -140), 24)
		Builder.node(ctx, "node.fatwood_stump", q.X, q.Y)
	end
	for _ = 1, 18 do
		local p = near(V2(if rng:NextNumber() < 0.5 then -110 else 100, 60), 40)
		Builder.node(ctx, "node.boulder", p.X, p.Y)
	end
	for _ = 1, 8 do
		local p = near(V2(70, -10), 26)
		Builder.node(ctx, "node.scrap_heap", p.X, p.Y)
	end
	-- Niter crusts on the damp cellar walls behind the houses (the Cellar Salt quest).
	for _, spot in { V2(-78, -80), V2(-118, -10), V2(86, -88), V2(106, 18) } do
		Builder.node(ctx, "node.niter_seam", spot.X, spot.Y)
	end
	for _ = 1, 4 do
		local p = near(V2(-120, 40), 20)
		Builder.node(ctx, "node.ashroot_mound", p.X, p.Y)
	end
	Builder.node(ctx, "node.spring_pool", CREEK_X - 14, 40)
	Builder.node(ctx, "node.spring_pool", CREEK_X - 16, -110)
end

local function markers(ctx: Builder.Ctx)
	for index, spawn in { V2(158, 104), V2(158, 116), V2(150, 110), V2(146, 102), V2(146, 118), V2(140, 110) } do
		Builder.marker(ctx, "spawn", spawn.X, spawn.Y, { Index = index })
	end
	local hollows = {
		V2(-20, 60),
		V2(20, 0),
		V2(-20, -70),
		V2(20, -120),
		V2(-80, -40),
		V2(-110, 20),
		V2(90, -50),
		V2(100, 40),
		V2(60, 90),
		V2(-60, 100),
		V2(-120, -120),
		V2(120, -140),
		V2(0, -150),
		V2(-140, 80),
		V2(70, -100),
		V2(-40, -150),
		V2(110, -20),
		V2(-90, 60),
		V2(30, 50),
		V2(-30, 120),
	}
	for _, at in hollows do
		Builder.marker(ctx, "hollow", at.X, at.Y)
	end
	Builder.exit(ctx, "north_ramp", "North Road", 0, -164, 10, 0)
	Builder.exit(ctx, "conveyor_gate", "Highway West", -164, HIGHWAY_Z, 10, 90)
	Builder.exit(ctx, "flooded_cut", "Creek Bridge", CREEK_X + 30, CROSS_Z, 10, 90)
end

local function roads(ctx: Builder.Ctx)
	local bridgeX = CREEK_X + math.noise(CROSS_Z / 50, 0, 3.7) * 10
	-- The highway along the south (no sidewalks: gravel shoulders), then Main Street north
	-- and Cross Street east and west, their sidewalks broken at the junctions.
	-- Roads run on past the edge into the woods and fog, so their ends never show.
	Builder.road(ctx, { V2(-300, HIGHWAY_Z), V2(300, HIGHWAY_Z) }, 15, nil, 0)
	Builder.road(ctx, { V2(0, HIGHWAY_Z - 7.5), V2(0, CROSS_Z + 8.5) }, 11, 3, 0.12)
	Builder.road(ctx, { V2(0, CROSS_Z - 8.5), V2(0, -172) }, 11, 3, 0.12)
	Builder.road(ctx, { V2(0, -172), V2(0, -300) }, 11, nil, 0.12)
	Builder.road(ctx, { V2(0, CROSS_Z + 5), V2(0, CROSS_Z - 5) }, 11, nil, 0.12)
	Builder.road(ctx, { V2(9, CROSS_Z), V2(bridgeX - 17, CROSS_Z) }, 10, 3, 0.06)
	Builder.road(ctx, { V2(-152, CROSS_Z), V2(-9, CROSS_Z) }, 10, 3, 0.06)
	Builder.road(ctx, { V2(bridgeX + 17, CROSS_Z), V2(300, CROSS_Z) }, 10, nil, 0.06)
end

function Rustwater.build(ctx: Builder.Ctx)
	Builder.terrain(ctx, { extent = Rustwater.half + 140, height = height, surface = surface, water = water })
	roads(ctx)
	westShops(ctx)
	eastShops(ctx)
	houses(ctx)
	gasStation(ctx)
	street(ctx)
	bridge(ctx)
	edges(ctx)
	-- Past the edge: a deep wall of pines and dead trees, roads and the creek kept open,
	-- and the Dense fog's grey bank, so no zoom shows the map's end.
	Builder.treeWall(ctx, {
		half = Rustwater.half,
		names = { "EO_PineTree" },
		dead = { "EO_DeadTree" },
		deadShare = 0.3,
		depth = 80,
		spacing = 9,
		height = 21,
		clear = function(x: number, z: number): boolean
			return math.abs(x) < 14 or math.abs(z - HIGHWAY_Z) < 16 or creekDistance(x, z) < 12
		end,
	})
	Builder.fogBank(ctx, Rustwater.half, Color3.fromRGB(150, 158, 164), 1.6)
	gatherables(ctx)
	markers(ctx)
end

return Rustwater
