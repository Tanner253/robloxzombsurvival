--!strict
--[[
	Stranded Caravan (Dense fog, the rotating event location): a survivors' convoy that
	reached the old timber bridge just as its middle span fell into the river. They
	circled the vehicles in the pines, made camp, and the Fog came in. 220 x 220 studs
	of play, compact and dense like LDoE's convoy event.

	Points of interest, joined by the convoy's road and two worn trails:
	- the wagon circle (centre): five vehicles round a cold fire, tarps, crates, sacks;
	- the old bridge (east): stone abutments, a timber deck, its middle span in the
	  river with a car nose-down beside it;
	- the lead wagon (north): the pickup that scouted ahead, tipped in the ditch;
	- the riverbank camp (south-east): a fishing lean-to on the west bank;
	- the cutting (north-west): a logging clearing of stumps and fatwood.
	Dense fog: three marked exits (Lead Wagon Trail, Riverbank, Old Bridge); the lobby
	seed closes one. Containers: a trunk at every vehicle (the lobby stocks 3-4), and a
	strongbox spot at the circle, the riverbank and the lead wagon (it stocks one).
]]

local Builder = require("./Builder")

local StrandedCaravan = {}

StrandedCaravan.half = 110
StrandedCaravan.seed = 63

local V2 = Vector2.new

local PINES = { "EO_PineTree" }
local DEAD = { "EO_DeadTree" }

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- The river runs north-south east of the camp, meandering a little.
local function riverX(z: number): number
	return 70 + math.noise(z / 60, 0, 5.1) * 9
end

local function riverDistance(x: number, z: number): number
	return math.abs(x - riverX(z))
end

local WATER = -3.2
local BRIDGE_Z = -24
local BRIDGE_X = riverX(BRIDGE_Z)
local CIRCLE = V2(-20, 8)
local RING = 22
local LEAD_WRECK = V2(-46, -68)
local RIVERCAMP = V2(riverX(58) - 21, 58)
local CUTTING = V2(-72, -38)

local ROAD = {
	V2(-220, 28),
	V2(-104, 24),
	V2(-60, 16),
	V2(-20, 8),
	V2(10, -4),
	V2(34, -18),
	V2(BRIDGE_X - 17, BRIDGE_Z),
}
local ROAD_BEYOND = { V2(BRIDGE_X + 17, BRIDGE_Z), V2(140, -30), V2(220, -34) }
local LEAD_TRAIL = { V2(-30, -12), V2(-36, -42), V2(-34, -74), V2(-41, -118), V2(-42, -220) }
local BANK_TRAIL = { V2(-8, 28), V2(10, 48), V2(RIVERCAMP.X - 6, RIVERCAMP.Y - 4), V2(40, 102), V2(42, 220) }
local CUT_TRAIL = { V2(-35, -46), V2(-54, -42), V2(CUTTING.X + 10, CUTTING.Y) }

local function pathDistance(x: number, z: number): number
	return math.min(
		Builder.distanceToPath(x, z, ROAD),
		Builder.distanceToPath(x, z, ROAD_BEYOND),
		Builder.distanceToPath(x, z, LEAD_TRAIL),
		Builder.distanceToPath(x, z, BANK_TRAIL),
		Builder.distanceToPath(x, z, CUT_TRAIL)
	)
end

local function roadDistance(x: number, z: number): number
	return math.min(Builder.distanceToPath(x, z, ROAD), Builder.distanceToPath(x, z, ROAD_BEYOND))
end

local function height(x: number, z: number): number
	local river = riverDistance(x, z)
	local outside = math.max(math.abs(x), math.abs(z)) - 96
	-- Wooded hills past the edge, opening into a valley where the river leaves.
	local rim = smoothstep(0, 110, outside) * 24 * smoothstep(12, 36, river)
	local roll = math.noise(x / 48, z / 48, 2.7) * 2.4 + math.noise(x / 16, z / 16, 6.1) * 0.7
	local camp = 1 - smoothstep(30, 46, (V2(x, z) - CIRCLE).Magnitude)
	local channel = (1 - smoothstep(7, 17, river)) * -7.5
	local path = 1 - smoothstep(3, 8, pathDistance(x, z))
	return (roll * (1 - camp * 0.8) + rim) * (1 - path * 0.45) + channel
end

local function surface(x: number, z: number, _y: number): Enum.Material
	local here = V2(x, z)
	local grain = math.noise(x / 6, z / 6, 3.4)
	local river = riverDistance(x, z)
	if river < 10.5 + grain then
		return Enum.Material.Mud
	end
	if river < 14 + grain * 2 then
		return if grain > 0.2 then Enum.Material.Ground else Enum.Material.LeafyGrass
	end
	local road = roadDistance(x, z)
	if road < 2.8 + grain * 0.8 then
		-- Two wheel ruts with a grassy crown, churned to mud where the convoy stopped.
		return if road < 0.9 and grain > -0.1 then Enum.Material.LeafyGrass else Enum.Material.Mud
	end
	if pathDistance(x, z) < 2.3 + grain * 0.9 or road < 5 + grain * 1.5 then
		return Enum.Material.Ground
	end
	local camp = (here - CIRCLE).Magnitude
	if camp < 32 + math.noise(x / 12, z / 12, 4.4) * 5 then
		local worn = math.noise(x / 10, z / 10, 8.1) + (1 - camp / 32) * 0.4
		return if worn + grain * 0.25 > 0.15 then Enum.Material.Ground else Enum.Material.Mud
	end
	if (here - RIVERCAMP).Magnitude < 13 + grain * 3 or (here - LEAD_WRECK).Magnitude < 12 + grain * 3 then
		return Enum.Material.Ground
	end
	if (here - CUTTING).Magnitude < 22 + grain * 4 then
		return if math.noise(x / 9, z / 9, 1.1) > 0 then Enum.Material.Ground else Enum.Material.Grass
	end
	local patches = math.noise(x / 20, z / 20, 7.7) + grain * 0.2
	if patches > 0.35 then
		return Enum.Material.Ground
	elseif patches < -0.3 then
		return Enum.Material.Grass
	end
	return Enum.Material.LeafyGrass
end

local function water(x: number, z: number): number?
	return if riverDistance(x, z) < 9.5 then WATER else nil
end

-- Pieces ----------------------------------------------------------------------------------------------

local function wagonCircle(ctx: Builder.Ctx)
	-- Five vehicles nose to tail round the camp; gaps left for the road and the trails.
	local ring = {
		{ angle = 208, name = "EO_VanWreck", tall = 8 },
		{ angle = 290, name = "EO_PickupWreck", tall = 6.8 },
		{ angle = 20, name = "EO_SedanWreck", tall = 5.6 },
		{ angle = 95, name = "EO_TractorWreck", tall = 7.5 },
		{ angle = 135, name = "EO_PickupWreck", tall = 6.8 },
	}
	for _, slot in ring do
		local a = math.rad(slot.angle)
		local x, z = CIRCLE.X + math.cos(a) * RING, CIRCLE.Y + math.sin(a) * RING
		-- Side-on to the circle: each vehicle's length along the ring's tangent.
		local yaw = -slot.angle - 90 + (ctx.rng:NextNumber() - 0.5) * 10
		Builder.vehicle(ctx, slot.name, x, z, yaw, { height = slot.tall }, true)
	end
	-- The hay the tractor was pulling, spilled behind it.
	Builder.kit(ctx, { "EO_HayBales" }, CIRCLE.X + 4, CIRCLE.Y + 30, 40, { height = 4.4 })
	-- The camp inside: two lean-tos facing a cold fire, stores stacked by the vehicles.
	local campTarp = Builder.leanTo(ctx, "CampTarp", CIRCLE.X - 2, CIRCLE.Y - 9, 190, "tarp")
	Builder.leanTo(ctx, "SleepTarp", CIRCLE.X + 9, CIRCLE.Y + 12, 57, "cloth", 9)
	Builder.kit(ctx, { "EO_CampfireRing" }, CIRCLE.X - 2, CIRCLE.Y + 5, 0)
	local bx, bz = Builder.toLocal(ctx, campTarp * CFrame.new(2.5, 0, -1))
	Builder.container(ctx, "strongbox", bx, bz, 190)
	Builder.kit(ctx, { "EO_BarrelCluster" }, CIRCLE.X - 15, CIRCLE.Y + 9, 60)
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, CIRCLE.X + 13, CIRCLE.Y - 4, 200)
	Builder.kit(ctx, { "EO_StorageCrate" }, CIRCLE.X + 9, CIRCLE.Y - 9, 15)
	Builder.kit(ctx, { "EO_StorageCrate" }, CIRCLE.X + 12.5, CIRCLE.Y - 7, 70)
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, CIRCLE.X - 13, CIRCLE.Y + 15, 110)
	Builder.kit(ctx, { "EO_ScrapHeapClean" }, CIRCLE.X + 30, CIRCLE.Y + 18, 30)
	-- A trestle table with a lantern on it.
	local folder = Builder.model(Builder.folder(ctx, "Dressing"), "CampTable")
	local table_ = Builder.frame(ctx, CIRCLE.X + 4, CIRCLE.Y + 1, 20)
	Builder.part(folder, Vector3.new(6, 0.3, 2.8), table_ * CFrame.new(0, 2.9, 0), "boards", "Top")
	for _, leg in { -2.4, 2.4 } do
		Builder.part(folder, Vector3.new(0.3, 2.8, 2.4), table_ * CFrame.new(leg, 1.4, 0), "trim", "Trestle")
	end
	for _, side in { -1, 1 } do
		Builder.part(folder, Vector3.new(5, 0.3, 1), table_ * CFrame.new(0, 1.6, side * 2.4), "boards", "Bench")
	end
	Builder.lamp(ctx, CIRCLE.X + 4, CIRCLE.Y + 1, 4, true, 18)
	for _, spot in { V2(CIRCLE.X - 16, CIRCLE.Y - 4), V2(CIRCLE.X + 14, CIRCLE.Y + 16) } do
		Builder.kit(ctx, { "EO_LanternPost" }, spot.X, spot.Y, ctx.rng:NextNumber() * 360)
		Builder.lamp(ctx, spot.X, spot.Y, 6.5, true, 20)
	end
end

local function oldBridge(ctx: Builder.Ctx)
	local holder = Builder.model(Builder.folder(ctx, "Buildings"), "OldBridge")
	local deckY = math.max(ctx.groundHeight(BRIDGE_X - 17, BRIDGE_Z), ctx.groundHeight(BRIDGE_X + 17, BRIDGE_Z)) + 0.9
	local base = CFrame.new(ctx.origin + Vector3.new(BRIDGE_X, deckY, BRIDGE_Z))
	local rng = ctx.rng
	-- Stone abutments on both banks.
	for _, side in { -1, 1 } do
		Builder.part(holder, Vector3.new(4, 6, 11), base * CFrame.new(side * 17, -3.2, 0), "concreteDark", "Abutment")
		Builder.part(holder, Vector3.new(4.4, 0.6, 11.4), base * CFrame.new(side * 17, -0.1, 0), "concrete", "Cap")
	end
	-- The deck: planks across three stringers, the middle span fallen into the river.
	local function span(frame: CFrame, from: number, to: number, label: string)
		local length = to - from
		local centre = (from + to) / 2
		for _, sz in { -3, 0, 3 } do
			Builder.part(
				holder,
				Vector3.new(length, 0.8, 0.8),
				frame * CFrame.new(centre, -0.75, sz),
				"trim",
				"Stringer"
			)
		end
		for x = from + 0.6, to - 0.6, 1.25 do
			if rng:NextNumber() < 0.9 then
				local wobble = CFrame.Angles(0, math.rad((rng:NextNumber() - 0.5) * 4), 0)
				Builder.part(holder, Vector3.new(1.1, 0.35, 8.2), frame * CFrame.new(x, 0, 0) * wobble, "boards", label)
			end
		end
	end
	span(base, -15, -3, "Deck")
	span(base, 8, 15, "Deck")
	-- The fallen span hinges down from its west end into the water.
	local fallen = base * CFrame.new(-3, 0, 0.6) * CFrame.Angles(math.rad(4), 0, math.rad(-26)) * CFrame.new(3, 0, 0)
	span(fallen * CFrame.new(-3, 0, 0), 0, 10, "FallenDeck")
	-- Timber trestles under the standing spans.
	for _, px in { -9, 11.5 } do
		local bed = ctx.groundHeight(BRIDGE_X + px, BRIDGE_Z) - 1
		local tall = deckY - 1.1 - bed
		for _, sz in { -3.4, 3.4 } do
			Builder.part(
				holder,
				Vector3.new(0.9, tall, 0.9),
				base * CFrame.new(px, -1.1 - tall / 2, sz),
				"trim",
				"Pile"
			)
		end
		Builder.part(
			holder,
			Vector3.new(0.4, 0.4, 9),
			base * CFrame.new(px, -1.1 - tall * 0.45, 0) * CFrame.Angles(math.rad(34), 0, 0),
			"trim",
			"Brace"
		)
	end
	-- Railings, broken where the span went.
	for _, sz in { -4.3, 4.3 } do
		for _, run in { { -16, -3 }, { 8, 16 } } do
			for post = run[1], run[2], 3.25 do
				Builder.part(holder, Vector3.new(0.4, 3, 0.4), base * CFrame.new(post, 1.5, sz), "trim", "Post")
			end
			local length = run[2] - run[1]
			Builder.part(
				holder,
				Vector3.new(length, 0.3, 0.3),
				base * CFrame.new((run[1] + run[2]) / 2, 2.8, sz),
				"trim",
				"Rail"
			)
		end
	end
	Builder.part(
		holder,
		Vector3.new(6, 0.3, 0.3),
		base * CFrame.new(-0.6, 1.2, 4.3) * CFrame.Angles(0, 0, math.rad(-32)),
		"trim",
		"BrokenRail"
	)
	-- A car that tried it anyway, nose-down by the fallen span; planks drifting downstream.
	Builder.vehicle(ctx, "EO_SedanWreck", BRIDGE_X + 1, BRIDGE_Z + 8, 180, { height = 5.6, pitch = 22, lift = -2.6 })
	for index = 1, 6 do
		local z = BRIDGE_Z + 14 + index * 6 + rng:NextNumber() * 3
		local x = riverX(z) + (rng:NextNumber() - 0.5) * 8
		Builder.part(
			holder,
			Vector3.new(1.1, 0.3, 6 + rng:NextNumber() * 2),
			CFrame.new(ctx.origin + Vector3.new(x, WATER + 0.05, z)) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
			"boards",
			"Drift"
		)
	end
	-- Their last stand on the approach: barrels, sacks and a scrap pile by the abutment.
	Builder.kit(ctx, { "EO_BarrelCluster" }, BRIDGE_X - 22, BRIDGE_Z - 8, 30)
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, BRIDGE_X - 24, BRIDGE_Z + 8, 160)
	Builder.kit(ctx, { "EO_ScrapHeapClean" }, BRIDGE_X - 34, BRIDGE_Z - 10, 80)
end

local function leadWagon(ctx: Builder.Ctx)
	-- The pickup that scouted ahead slid into the ditch; its load is strewn up the bank.
	Builder.vehicle(ctx, "EO_PickupWreck", LEAD_WRECK.X, LEAD_WRECK.Y, 262, { height = 6.8, tilt = 7 }, true)
	Builder.container(ctx, "strongbox", LEAD_WRECK.X - 7, LEAD_WRECK.Y + 3, 120)
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, LEAD_WRECK.X + 6, LEAD_WRECK.Y - 7, 40)
	Builder.kit(ctx, { "EO_StorageCrate" }, LEAD_WRECK.X - 4, LEAD_WRECK.Y - 10, 70, { tilt = 12 })
	Builder.kit(ctx, { "EO_BarrelCluster" }, LEAD_WRECK.X + 9, LEAD_WRECK.Y + 6, 200)
	Builder.kit(ctx, DEAD, LEAD_WRECK.X - 13, LEAD_WRECK.Y - 4, 30, { height = 17 })
	Builder.kit(ctx, DEAD, LEAD_WRECK.X + 15, LEAD_WRECK.Y - 14, 200, { height = 15 })
	Builder.kit(ctx, { "EO_LanternPost" }, LEAD_WRECK.X + 4, LEAD_WRECK.Y + 9, 100)
	Builder.lamp(ctx, LEAD_WRECK.X + 4, LEAD_WRECK.Y + 9, 6.5, true, 18)
end

local function riverCamp(ctx: Builder.Ctx)
	local c = RIVERCAMP
	local tarp = Builder.leanTo(ctx, "FishingTarp", c.X - 2, c.Y, 247, "tarp")
	Builder.kit(ctx, { "EO_CampfireRing" }, c.X + 5, c.Y + 3, 0)
	local bx, bz = Builder.toLocal(ctx, tarp * CFrame.new(-2.5, 0, -1))
	Builder.container(ctx, "strongbox", bx, bz, 247)
	Builder.kit(ctx, { "EO_BarrelCluster" }, c.X - 6, c.Y + 9, 90)
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, c.X - 7, c.Y - 9, 10)
	Builder.kit(ctx, { "EO_RockCluster" }, c.X + 11, c.Y - 10, 80)
	Builder.kit(ctx, { "EO_RockCluster" }, c.X + 9, c.Y + 16, 220)
	-- A drying rack of poles by the water.
	local folder = Builder.model(Builder.folder(ctx, "Dressing"), "DryingRack")
	local rack = Builder.frame(ctx, c.X + 8, c.Y - 3, 70)
	for _, side in { -3, 3 } do
		Builder.part(folder, Vector3.new(0.3, 4.5, 0.3), rack * CFrame.new(side, 2.2, 0), "trim", "Pole")
	end
	Builder.part(folder, Vector3.new(7, 0.25, 0.25), rack * CFrame.new(0, 4.3, 0), "trim", "Bar")
	for hang = -2, 2, 1.3 do
		Builder.part(folder, Vector3.new(0.9, 1.6, 0.1), rack * CFrame.new(hang, 3.4, 0), "cloth", "Hide")
	end
	Builder.kit(ctx, { "EO_LanternPost" }, c.X - 10, c.Y + 2, 300)
	Builder.lamp(ctx, c.X - 10, c.Y + 2, 6.5, true, 18)
end

local function cutting(ctx: Builder.Ctx)
	-- A logging clearing: stumps, branch piles and an abandoned scrap heap.
	local rng = ctx.rng
	for index = 1, 9 do
		local angle = index / 9 * math.pi * 2 + rng:NextNumber() * 0.4
		local r = 8 + rng:NextNumber() * 12
		Builder.kit(
			ctx,
			{ "EO_FatwoodStump" },
			CUTTING.X + math.cos(angle) * r,
			CUTTING.Y + math.sin(angle) * r,
			rng:NextNumber() * 360,
			{ solid = false }
		)
	end
	for _ = 1, 5 do
		local x = CUTTING.X + (rng:NextNumber() - 0.5) * 34
		local z = CUTTING.Y + (rng:NextNumber() - 0.5) * 34
		Builder.kit(ctx, { "EO_BareBranches" }, x, z, rng:NextNumber() * 360, { solid = false })
	end
	Builder.kit(ctx, { "EO_ScrapHeapClean" }, CUTTING.X + 12, CUTTING.Y + 10, 300)
end

-- Fill: woods and undergrowth in every gap --------------------------------------------------------

local function clearOf(x: number, z: number): boolean
	local here = V2(x, z)
	return pathDistance(x, z) < 6.5
		or riverDistance(x, z) < 12
		or (here - CIRCLE).Magnitude < RING + 12
		or (here - V2(BRIDGE_X - 26, BRIDGE_Z)).Magnitude < 16
		or (here - LEAD_WRECK).Magnitude < 16
		or (here - RIVERCAMP).Magnitude < 17
		or (here - CUTTING).Magnitude < 20
end

local function woods(ctx: Builder.Ctx)
	local rng = ctx.rng
	local half = StrandedCaravan.half
	local placed = 0
	for gx = -half + 4, half - 4, 10.5 do
		for gz = -half + 4, half - 4, 10.5 do
			local x = gx + (rng:NextNumber() - 0.5) * 9
			local z = gz + (rng:NextNumber() - 0.5) * 9
			if not clearOf(x, z) and rng:NextNumber() < 0.8 then
				local dead = rng:NextNumber() < 0.12
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
	local under = {
		{ "EO_EmberBushClean" },
		{ "EO_BareBranches" },
		{ "EO_LooseStonesClean" },
		{ "EO_FatwoodStump" },
		{ "EO_EmberBushClean" },
	}
	for count = 1, 230 do
		local x, z = (rng:NextNumber() * 2 - 1) * (half - 4), (rng:NextNumber() * 2 - 1) * (half - 4)
		if roadDistance(x, z) > 4 and riverDistance(x, z) > 10 and (V2(x, z) - CIRCLE).Magnitude > RING - 2 then
			Builder.kit(ctx, under[rng:NextInteger(1, #under)], x, z, rng:NextNumber() * 360, { solid = false })
		end
		if count % 60 == 0 then
			task.wait()
		end
	end
	-- Reeds along both banks.
	for index = 1, 40 do
		local z = (index / 40 * 2 - 1) * (half + 10)
		local side = if index % 2 == 0 then -1 else 1
		local x = riverX(z) + side * (9.5 + rng:NextNumber() * 3)
		if math.abs(z - BRIDGE_Z) > 8 then
			Builder.kit(ctx, { "EO_ReedsClean" }, x, z, rng:NextNumber() * 360, { solid = false })
		end
	end
	for _ = 1, 12 do
		local x, z = (rng:NextNumber() * 2 - 1) * (half - 10), (rng:NextNumber() * 2 - 1) * (half - 10)
		if not clearOf(x, z) then
			Builder.kit(ctx, { "EO_RockCluster" }, x, z, rng:NextNumber() * 360)
		end
	end
end

local function edges(ctx: Builder.Ctx)
	local half = StrandedCaravan.half
	Builder.treeWall(ctx, {
		half = half,
		names = PINES,
		dead = DEAD,
		deadShare = 0.2,
		depth = 80,
		spacing = 8.5,
		height = 22,
		gaps = { V2(-half, 26), V2(-42, -half), V2(42, half), V2(half, -30) },
		clear = function(x: number, z: number): boolean
			return riverDistance(x, z) < 12
		end,
	})
	-- Dense fog's bank: heavier and colder than the Light woods.
	Builder.fogBank(ctx, half, Color3.fromRGB(150, 158, 164), 1.5)
end

local function gatherables(ctx: Builder.Ctx)
	local rng = ctx.rng
	local function near(centre: Vector2, radius: number): Vector2
		local angle = rng:NextNumber() * math.pi * 2
		return centre + V2(math.cos(angle), math.sin(angle)) * radius * (0.5 + rng:NextNumber() * 0.5)
	end
	for _, spot in
		{
			V2(CIRCLE.X + 30, CIRCLE.Y - 8),
			V2(CIRCLE.X - 32, CIRCLE.Y - 14),
			V2(CIRCLE.X + 8, CIRCLE.Y + 34),
			V2(BRIDGE_X - 30, BRIDGE_Z + 12),
			V2(BRIDGE_X - 38, BRIDGE_Z - 2),
			V2(LEAD_WRECK.X + 12, LEAD_WRECK.Y + 14),
		}
	do
		Builder.node(ctx, "node.scrap_heap", spot.X, spot.Y)
	end
	for _ = 1, 4 do
		local p = near(CUTTING, 16)
		Builder.node(ctx, "node.fatwood_stump", p.X, p.Y)
	end
	for _ = 1, 6 do
		local p = near(CUTTING + V2(-6, -26), 14)
		Builder.node(ctx, "node.pine_tree", p.X, p.Y)
	end
	for index = 1, 4 do
		local z = RIVERCAMP.Y - 30 + index * 13
		Builder.node(ctx, "node.reed_patch", riverX(z) - 12, z)
	end
end

local function markers(ctx: Builder.Ctx)
	for index, spawn in { V2(-98, 24), V2(-98, 32), V2(-92, 18), V2(-90, 30), V2(-86, 22), V2(-104, 28) } do
		Builder.marker(ctx, "spawn", spawn.X, spawn.Y, { Index = index })
	end
	local hollows = {
		V2(-50, 0),
		V2(4, -26),
		V2(16, 30),
		V2(-40, 40),
		V2(BRIDGE_X - 30, BRIDGE_Z - 16),
		V2(LEAD_WRECK.X + 10, LEAD_WRECK.Y - 18),
		V2(-24, -96),
		V2(RIVERCAMP.X - 10, RIVERCAMP.Y + 20),
		V2(30, 96),
		V2(-70, 70),
		V2(CUTTING.X + 18, CUTTING.Y - 20),
		V2(48, -70),
		V2(-90, -84),
	}
	for _, at in hollows do
		Builder.marker(ctx, "hollow", at.X, at.Y)
	end
	local half = StrandedCaravan.half
	Builder.exit(ctx, "lead_trail", "Lead Wagon Trail", -41, -half + 8, 9, 0)
	Builder.exit(ctx, "riverbank", "Riverbank", 40, half - 8, 9, 0)
	Builder.exit(ctx, "old_bridge", "Old Bridge", BRIDGE_X - 27, BRIDGE_Z + 1, 9, 90)
end

function StrandedCaravan.build(ctx: Builder.Ctx)
	Builder.terrain(ctx, { extent = StrandedCaravan.half + 140, height = height, surface = surface, water = water })
	wagonCircle(ctx)
	oldBridge(ctx)
	leadWagon(ctx)
	riverCamp(ctx)
	cutting(ctx)
	woods(ctx)
	edges(ctx)
	gatherables(ctx)
	markers(ctx)
end

return StrandedCaravan
