--!strict
--[[
	ResourceZone: the shared builder for the Forest and Mine maps (ECONOMY §6.2). Each map
	is a fixed, handcrafted layout written as a spec (Maps/<Name>.luau): its trails, creek,
	ponds, clearings, rock bluffs and quarry cuts, its points of interest, exits and entry.
	The builder turns the spec into terrain and dressing, then places the location's
	resource nodes by kind (trees in the woods, ore along the bluffs, reeds at the water,
	fatwood in the cuttings...) from a fixed seed, so every visit is the same place and the
	map's node markers equal the data's counts exactly (Maps.build checks).

	Resource zones are farms, not dungeons (LDoE): nodes first, a few weak containers at
	the points of interest, woods and undergrowth in every gap, a tree wall and a fog
	bank at every edge with the land running on beyond.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Builder = require("./Builder")

local ResourceZone = {}

local V2 = Vector2.new

export type Clearing = { at: Vector2, radius: number }
export type Pond = { at: Vector2, radius: number }
export type Ridge = { points: { Vector2 }, width: number, height: number } -- a rock bluff
export type Pit = { at: Vector2, radius: number, depth: number } -- a quarry cut in benches
export type Exit = { id: string, name: string, at: Vector2, yaw: number, landmark: Builder.ExitLandmark? }
export type Spot = { kind: string, at: Vector2, yaw: number }

export type Spec = {
	locationId: string,
	half: number,
	seed: number,
	biome: "forest" | "mine",
	trails: { { Vector2 } }, -- worn paths; the first is the main track (rutted)
	creek: { Vector2 }?, -- a shallow stream across the map
	ponds: { Pond },
	clearings: { Clearing }, -- points of interest and cuttings: kept free of woods
	ridges: { Ridge }?,
	pits: { Pit }?,
	scorch: { Pond }?, -- burnt ground: ash and charred earth
	exits: { Exit }, -- Dense and Black: marked points; Light: "edge" exits at trail ends
	entry: Vector2, -- where survivors arrive
	containers: { Spot }, -- fixed container spots (the lobby stocks some)
	hollows: { Vector2 }, -- Hollow spawn markers
	fog: Color3,
	deadShare: number, -- share of dead trees in the woods and the wall
	woods: number, -- decorative woods density, 0-1
	dress: (ctx: Builder.Ctx) -> (), -- the map's own points of interest
}

local PINES = { "EO_PineTree" }
local DEAD = { "EO_DeadTree" }

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Shape queries -----------------------------------------------------------------------------------------

local function trailDistance(spec: Spec, x: number, z: number): number
	local best = math.huge
	for _, trail in spec.trails do
		best = math.min(best, Builder.distanceToPath(x, z, trail))
	end
	return best
end

local function creekDistance(spec: Spec, x: number, z: number): number
	local creek = spec.creek
	if creek == nil then
		return math.huge
	end
	-- A slow meander plus a ragged bank (QA: one octave left the banks ruler-straight; the
	-- bank's wobble must beat the 4-stud terrain voxel or the grid smooths it away).
	local wobble = math.noise(x / 30, z / 30, 4.4) * 4 + math.noise(x / 15, z / 15, 5.1) * 4
	return Builder.distanceToPath(x, z, creek) + wobble
end

local function ridgeLift(spec: Spec, x: number, z: number): (number, number)
	-- The height a bluff adds here, and how close to its face (0 on the face, 1 inside).
	local lift, inside = 0, 0
	local ridges: { Ridge } = spec.ridges or {}
	for _, ridge in ridges do
		local d = Builder.distanceToPath(x, z, ridge.points) + math.noise(x / 14, z / 14, 2.6) * 3
		local core = 1 - smoothstep(ridge.width * 0.55, ridge.width, d)
		local h = core * ridge.height * (0.85 + math.noise(x / 22, z / 22, 8.8) * 0.3)
		if h > lift then
			lift, inside = h, core
		end
	end
	return lift, inside
end

local function pitDepth(spec: Spec, x: number, z: number): (number, boolean)
	-- How far a cut drops the ground here, and whether this is a bench's face (not its tread).
	local deepest, onFace = 0, false
	local pits: { Pit } = spec.pits or {}
	for _, pit in pits do
		local d = (V2(x, z) - pit.at).Magnitude + math.noise(x / 16, z / 16, 6.4) * 5
		if d < pit.radius then
			local t = 1 - d / pit.radius
			local steps = 4
			local scaled = t * steps
			local bench = math.floor(scaled)
			local face = math.clamp((scaled - bench - 0.7) / 0.3, 0, 1)
			local level = math.min(bench + face, steps) / steps
			if -level * pit.depth < deepest then
				deepest = -level * pit.depth
				onFace = bench < steps and scaled - bench > 0.62
			end
		end
	end
	return deepest, onFace
end

local function inClearing(spec: Spec, x: number, z: number, margin: number): boolean
	local here = V2(x, z)
	for _, clearing in spec.clearings do
		if (here - clearing.at).Magnitude < clearing.radius + margin then
			return true
		end
	end
	return false
end

local function nearPond(spec: Spec, x: number, z: number, margin: number): boolean
	local here = V2(x, z)
	for _, pond in spec.ponds do
		if (here - pond.at).Magnitude < pond.radius + margin then
			return true
		end
	end
	return false
end

local function nearExit(spec: Spec, x: number, z: number, margin: number): boolean
	local here = V2(x, z)
	for _, exit in spec.exits do
		if (here - exit.at).Magnitude < 9 + margin then
			return true
		end
	end
	return (here - spec.entry).Magnitude < 12 + margin
end

local function nearContainer(spec: Spec, at: Vector2, margin: number): boolean
	for _, spot in spec.containers do
		if (spot.at - at).Magnitude < margin then
			return true
		end
	end
	return false
end

-- Terrain -------------------------------------------------------------------------------------------------

local function heightFor(spec: Spec): (number, number) -> number
	local mine = spec.biome == "mine"
	return function(x: number, z: number): number
		local outside = math.max(math.abs(x), math.abs(z)) - (spec.half - 15)
		local rim = smoothstep(0, 110, outside) * (if mine then 30 else 24)
		local roll = math.noise(x / 46, z / 46, 4.1) * (if mine then 3.4 else 2.4)
			+ math.noise(x / 16, z / 16, 7.3) * 0.8
		local here = V2(x, z)
		local flat = 0
		for _, clearing in spec.clearings do
			flat = math.max(
				flat,
				1 - smoothstep(clearing.radius * 0.6, clearing.radius + 8, (here - clearing.at).Magnitude)
			)
		end
		local dip = 0
		for _, pond in spec.ponds do
			dip = math.min(dip, -(1 - smoothstep(pond.radius * 0.5, pond.radius + 4, (here - pond.at).Magnitude)) * 4)
		end
		local creek = (1 - smoothstep(4, 11, creekDistance(spec, x, z))) * -5
		local ridge = ridgeLift(spec, x, z)
		local pit = pitDepth(spec, x, z)
		local path = 1 - smoothstep(3, 8, trailDistance(spec, x, z))
		return (roll * (1 - flat * 0.8) + rim + ridge) * (1 - path * 0.5) + dip + creek + pit
	end
end

local function surfaceFor(spec: Spec): (number, number, number) -> Enum.Material
	local mine = spec.biome == "mine"
	local main = spec.trails[1]
	return function(x: number, z: number, _y: number): Enum.Material
		local grain = math.noise(x / 6, z / 6, 2.2)
		if creekDistance(spec, x, z) < 6 + grain then
			return Enum.Material.Mud
		end
		if nearPond(spec, x, z, 2 + grain * 2) then
			return Enum.Material.Mud
		end
		local track = if main then Builder.distanceToPath(x, z, main) else math.huge
		if track < 2.6 + grain * 0.8 then
			return if track < 1 and grain > -0.1 then Enum.Material.LeafyGrass else Enum.Material.Mud
		end
		if trailDistance(spec, x, z) < 2.3 + grain * 0.9 then
			return Enum.Material.Ground
		end
		local _, inside = ridgeLift(spec, x, z)
		if inside > 0.06 and inside < 0.9 then
			-- A bluff's faces: bare rock, scree at its foot. Its top stays grassed.
			return if inside < 0.2 and grain > 0.1 then Enum.Material.Cobblestone else Enum.Material.Rock
		end
		local cut, onFace = pitDepth(spec, x, z)
		if cut < -0.5 then
			-- The cut: bare rock on the bench faces; the treads are packed spoil, scree and a
			-- little rock (QA: all-rock floors read as one cold grey sheet under Black fog).
			if onFace then
				return if grain > 0.45 then Enum.Material.Cobblestone else Enum.Material.Rock
			end
			local spoil = math.noise(x / 14, z / 14, 4.1) + grain * 0.3
			return if spoil > 0.3
				then Enum.Material.Cobblestone
				elseif spoil < -0.35 then Enum.Material.Rock
				else Enum.Material.Ground
		end
		local burnt: { Pond } = spec.scorch or {}
		for _, scorch in burnt do
			local d = (V2(x, z) - scorch.at).Magnitude + math.noise(x / 9, z / 9, 7.3) * 5
			if d < scorch.radius then
				-- Charred earth (QA: Basalt "ash" rendered pale blue, like frost, under Black fog).
				return if d < scorch.radius * 0.7 and grain > -0.3 then Enum.Material.Mud else Enum.Material.Ground
			end
		end
		if inClearing(spec, x, z, grain * 4) then
			local worn = math.noise(x / 12, z / 12, 9.9)
			return if worn + grain * 0.25 > 0.15 then Enum.Material.Ground else Enum.Material.LeafyGrass
		end
		local patches = math.noise(x / 20, z / 20, 1.9) + grain * 0.2
		if mine then
			if patches > 0.5 then
				return Enum.Material.Cobblestone
			elseif patches > -0.1 then
				return Enum.Material.Ground
			end
			return Enum.Material.Grass
		end
		if patches > 0.35 then
			return Enum.Material.Ground
		elseif patches < -0.3 then
			return Enum.Material.Grass
		end
		return Enum.Material.LeafyGrass
	end
end

local function waterFor(spec: Spec): (number, number) -> number?
	return function(x: number, z: number): number?
		if creekDistance(spec, x, z) < 5 then
			return -2.6
		end
		for _, pond in spec.ponds do
			if (V2(x, z) - pond.at).Magnitude < pond.radius * 0.8 then
				return -1.6
			end
		end
		return nil
	end
end

-- Node placement -------------------------------------------------------------------------------------------

type Rule = {
	spacing: number, -- from other placed nodes
	accept: (x: number, z: number) -> boolean,
}

local function rulesFor(spec: Spec): { [string]: Rule }
	local mine = spec.biome == "mine"
	local function open(x: number, z: number, trail: number): boolean
		return trailDistance(spec, x, z) > trail
			and creekDistance(spec, x, z) > 8
			and not nearPond(spec, x, z, 3)
			and not nearExit(spec, x, z, 2)
	end
	local function woods(x: number, z: number): boolean
		local _, inside = ridgeLift(spec, x, z)
		return open(x, z, 6) and not inClearing(spec, x, z, 4) and inside < 0.1 and pitDepth(spec, x, z) > -0.5
	end
	local function rocky(x: number, z: number): boolean
		-- At the foot of a bluff or on a bench of a cut (mines); scattered (forests).
		if not open(x, z, 4) or inClearing(spec, x, z, -6) then
			return false
		end
		local _, inside = ridgeLift(spec, x, z)
		local pit, onFace = pitDepth(spec, x, z)
		if mine then
			-- The foot of a bluff or a bench's tread, never the steep face itself (QA: about
			-- two thirds of the old area was steeper than 50 degrees; ore hung off cliffs).
			return (inside > 0.02 and inside < 0.3) or (pit < -2 and not onFace)
		end
		return inside < 0.1
	end
	local function verge(x: number, z: number): boolean
		local t = trailDistance(spec, x, z)
		return (t > 3 and t < 14 or inClearing(spec, x, z, 6) and not inClearing(spec, x, z, -4))
			and creekDistance(spec, x, z) > 7
			and not nearPond(spec, x, z, 2) -- QA: branches and stones floated on ponds
			and not nearExit(spec, x, z, 0)
	end
	local function water(x: number, z: number): boolean
		local creek = creekDistance(spec, x, z)
		return (creek > 5.5 and creek < 11) or (nearPond(spec, x, z, 6) and not nearPond(spec, x, z, 0))
	end
	local function cutting(x: number, z: number): boolean
		return inClearing(spec, x, z, 10) and not inClearing(spec, x, z, -3) and open(x, z, 4)
	end
	local function camp(x: number, z: number): boolean
		return inClearing(spec, x, z, 8) and open(x, z, 4)
	end
	local function face(x: number, z: number): boolean
		local _, inside = ridgeLift(spec, x, z)
		return (inside > 0.05 and inside < 0.45 or pitDepth(spec, x, z) < -3) and open(x, z, 4)
	end
	return {
		["node.pine_tree"] = {
			spacing = 7,
			accept = if mine
				then function(x, z)
					return woods(x, z) and math.noise(x / 40, z / 40, 3.3) > -0.15
				end
				else woods,
		},
		["node.ironbark_tree"] = { spacing = 9, accept = woods },
		["node.boulder"] = { spacing = 5, accept = rocky },
		["node.ironstone_rock"] = { spacing = 5, accept = rocky },
		["node.malachite_vein"] = {
			spacing = 6,
			accept = function(x, z)
				return rocky(x, z) and (pitDepth(spec, x, z) < -2 or select(2, ridgeLift(spec, x, z)) > 0.1)
			end,
		},
		["node.niter_seam"] = { spacing = 6, accept = face },
		["node.fallen_branches"] = { spacing = 4, accept = verge },
		["node.loose_stones"] = { spacing = 4, accept = verge },
		["node.reed_patch"] = { spacing = 3.5, accept = water },
		["node.ember_bush"] = {
			spacing = 5,
			accept = function(x, z)
				return woods(x, z) or verge(x, z)
			end,
		},
		["node.ashroot_mound"] = { spacing = 6, accept = woods },
		["node.fatwood_stump"] = { spacing = 5, accept = cutting },
		["node.scrap_heap"] = { spacing = 7, accept = camp },
		["node.spring_pool"] = {
			spacing = 10,
			accept = function(x, z)
				return (nearPond(spec, x, z, 9) and not nearPond(spec, x, z, 3)) or camp(x, z)
			end,
		},
	}
end

-- Places every node the location's data lists, exactly its count, from the map's seed.
local function placeNodes(ctx: Builder.Ctx, spec: Spec): { Vector2 }
	local location = Content.Locations[spec.locationId]
	local rules = rulesFor(spec)
	local random = Random.new(spec.seed * 31 + 7)
	local placed: { Vector2 } = {}
	local half = spec.half - 8
	local function free(at: Vector2, spacing: number): boolean
		for _, other in placed do
			if (other - at).Magnitude < spacing then
				return false
			end
		end
		return true
	end
	for _, entry in location.nodes do
		local rule = rules[entry.nodeId]
		local spacing = if rule then rule.spacing else 5
		local function always(_x: number, _z: number): boolean
			return true
		end
		local accept: (number, number) -> boolean = if rule then rule.accept else always
		local count = 0
		local tries = 0
		while count < entry.count do
			tries += 1
			-- Rules relax as tries mount, so the count is always met.
			local relax = if tries > 6000 then 2 elseif tries > 3000 then 1 else 0
			local at = V2((random:NextNumber() * 2 - 1) * half, (random:NextNumber() * 2 - 1) * half)
			local ok = (relax >= 2 or accept(at.X, at.Y))
				and free(at, spacing / (1 + relax))
				and not nearExit(spec, at.X, at.Y, 0)
				and not nearContainer(spec, at, 4.5)
			if ok then
				Builder.node(ctx, entry.nodeId, at.X, at.Y)
				table.insert(placed, at)
				count += 1
			end
			if tries % 400 == 0 then
				task.wait()
			end
		end
	end
	return placed
end

-- Dressing -------------------------------------------------------------------------------------------------

local function woodsAndUndergrowth(ctx: Builder.Ctx, spec: Spec, nodes: { Vector2 })
	local rng = ctx.rng
	local half = spec.half
	local mine = spec.biome == "mine"
	local function clear(x: number, z: number): boolean
		local here = V2(x, z)
		for _, at in nodes do
			if (at - here).Magnitude < 4.5 then
				return false
			end
		end
		local _, inside = ridgeLift(spec, x, z)
		return trailDistance(spec, x, z) > 6
			and creekDistance(spec, x, z) > 9
			and not nearPond(spec, x, z, 4)
			and not inClearing(spec, x, z, 3)
			and not nearExit(spec, x, z, 3)
			and inside < (if mine then 0.3 else 1)
			and pitDepth(spec, x, z) > -1
	end
	local placed = 0
	local step = if mine then 13 else 11
	for gx = -half + 4, half - 4, step do
		for gz = -half + 4, half - 4, step do
			local x = gx + (rng:NextNumber() - 0.5) * step * 0.8
			local z = gz + (rng:NextNumber() - 0.5) * step * 0.8
			if clear(x, z) and rng:NextNumber() < spec.woods then
				local dead = rng:NextNumber() < spec.deadShare
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
	local under = if mine
		then { { "EO_LooseStonesClean" }, { "EO_BareBranches" }, { "EO_EmberBushClean" }, { "EO_LooseStonesClean" } }
		else { { "EO_EmberBushClean" }, { "EO_BareBranches" }, { "EO_LooseStonesClean" }, { "EO_FatwoodStump" } }
	for index = 1, math.floor(half * 1.6) do
		local x, z = (rng:NextNumber() * 2 - 1) * (half - 4), (rng:NextNumber() * 2 - 1) * (half - 4)
		if trailDistance(spec, x, z) > 3.5 and creekDistance(spec, x, z) > 7 and not nearExit(spec, x, z, 0) then
			-- Only scree down in a cut: no brush on the worked rock.
			local kind = if pitDepth(spec, x, z) < -1
				then { "EO_LooseStonesClean" }
				else under[rng:NextInteger(1, #under)]
			Builder.kit(ctx, kind, x, z, rng:NextNumber() * 360, { solid = false })
		end
		if index % 60 == 0 then
			task.wait()
		end
	end
	for _ = 1, if mine then 26 else 12 do
		local x, z = (rng:NextNumber() * 2 - 1) * (half - 10), (rng:NextNumber() * 2 - 1) * (half - 10)
		if clear(x, z) then
			Builder.kit(
				ctx,
				{ "EO_RockCluster" },
				x,
				z,
				rng:NextNumber() * 360,
				{ height = 2.4 + rng:NextNumber() * 3 }
			)
		end
	end
	-- Reeds line the water's edge.
	for _, pond in spec.ponds do
		for index = 1, 14 do
			local angle = index / 14 * math.pi * 2 + rng:NextNumber() * 0.3
			local r = pond.radius + rng:NextNumber() * 3
			Builder.kit(
				ctx,
				{ "EO_ReedsClean" },
				pond.at.X + math.cos(angle) * r,
				pond.at.Y + math.sin(angle) * r,
				rng:NextNumber() * 360,
				{ solid = false }
			)
		end
	end
end

local function edges(ctx: Builder.Ctx, spec: Spec)
	local half = spec.half
	local gaps: { Vector2 } = {}
	for _, exit in spec.exits do
		local at = exit.at
		-- An exit near the edge leaves its trail open through the wall.
		if math.max(math.abs(at.X), math.abs(at.Y)) > half - 25 then
			-- Straight out to the nearest edge, keeping the other coordinate (QA: scaling both
			-- slid a corner exit's gap along the edge, away from its trail).
			if math.abs(at.X) >= math.abs(at.Y) then
				table.insert(gaps, V2(math.sign(at.X) * half, at.Y))
			else
				table.insert(gaps, V2(at.X, math.sign(at.Y) * half))
			end
		end
	end
	Builder.treeWall(ctx, {
		half = half,
		names = PINES,
		dead = DEAD,
		deadShare = spec.deadShare,
		depth = 80,
		spacing = 8.5,
		height = 22,
		gaps = gaps,
		clear = function(x: number, z: number): boolean
			return creekDistance(spec, x, z) < 9
		end,
	})
	Builder.fogBank(ctx, half, spec.fog, if spec.biome == "mine" then 1.4 else 1.3)
end

local function markers(ctx: Builder.Ctx, spec: Spec)
	for index = 1, 6 do
		local angle = index / 6 * math.pi * 2
		Builder.marker(
			ctx,
			"spawn",
			spec.entry.X + math.cos(angle) * 5,
			spec.entry.Y + math.sin(angle) * 5,
			{ Index = index }
		)
	end
	for _, at in spec.hollows do
		Builder.marker(ctx, "hollow", at.X, at.Y)
	end
	for _, exit in spec.exits do
		Builder.exit(ctx, exit.id, exit.name, exit.at.X, exit.at.Y, 9, exit.yaw, exit.landmark)
	end
	for _, spot in spec.containers do
		Builder.container(ctx, spot.kind, spot.at.X, spot.at.Y, spot.yaw)
	end
end

-- Builds a resource zone from its spec.
function ResourceZone.build(ctx: Builder.Ctx, spec: Spec)
	Builder.terrain(ctx, {
		extent = spec.half + 140,
		height = heightFor(spec),
		surface = surfaceFor(spec),
		water = waterFor(spec),
	})
	spec.dress(ctx)
	local nodes = placeNodes(ctx, spec)
	woodsAndUndergrowth(ctx, spec, nodes)
	edges(ctx, spec)
	markers(ctx, spec)
end

-- A layout for Maps.layouts from a spec.
function ResourceZone.layout(spec: Spec): { half: number, seed: number, build: (ctx: Builder.Ctx) -> () }
	return {
		half = spec.half,
		seed = spec.seed,
		build = function(ctx: Builder.Ctx)
			ResourceZone.build(ctx, spec)
		end,
	}
end

return ResourceZone
