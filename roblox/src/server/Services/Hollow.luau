--!strict
--[[
	Hollow (HollowService): the Hollow on a Fog Run (checklist 13.1, 13.2, 13.10).
	Off until Tuning.features.fogRuns.

	Network-light: the server keeps every Hollow as a plain record (position, HP,
	brain state) with no physics body. It runs Domain/HollowAI every
	Tuning.hollow.tickSeconds and sends each lobby's players a compact snapshot
	every syncSeconds (HollowSync); clients draw and interpolate the rigs. Hits are
	tested against these records (Domain/Plane), never against client models.

	- Spawns: the lobby's enemySpawns (Data/Locations) at band 1, and the sets with
	  a minBand as the Fog meter reaches them (HollowAI.spawnsForBand), at the map's
	  "hollow" markers, away from players. Band strength scales HP and damage.
	- Senses: players in sight radius with a server line-of-sight raycast, the
	  loudest noise (Domain/Noise) and flare light (Domain/Flare).
	- The bloater's burst leaves a toxic cloud that hurts players inside it.
	- A kill pays the Hollow's XP to the killer and fires `killed` (Containers drops
	  its loot pile there).

	Movement: straight at the goal while the way is clear; when a wall or a wreck is
	in the way, a path round it (PathfindingService, computed off the tick and
	refreshed as the goal moves). Positions snap to the ground or floor below.
]]

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Content = require(ReplicatedStorage.Shared.Data)
local Features = require(ReplicatedStorage.Shared.Features)
local Types = require(ReplicatedStorage.Shared.Types)
local Signal = require(ReplicatedStorage.Packages.Signal)
local TableUtil = require(ReplicatedStorage.Shared.Util.Table)
local Domain = ReplicatedStorage.Shared.Domain
local FlareMath = require(Domain.Flare)
local HollowAI = require(Domain.HollowAI)
local Noise = require(Domain.Noise)
local Plane = require(Domain.Plane)
local Rng = require(Domain.Rng)
local Net = require("../Net")
local Map = require("../FogRuns/Map")
local Lobby = require("./Lobby")
local Progression = require("./Progression")

local Hollow = {}

local tuning = Content.Tuning
local config = tuning.hollow
local EYE_HEIGHT = 2.5
local DEAD_LINGER_SECONDS = 2

-- Enemy IDs in a fixed order, so snapshots send a small index instead of a string.
Hollow.KINDS = TableUtil.sortedKeys(Content.Enemies)
local kindIndex: { [string]: number } = {}
for index, id in Hollow.KINDS do
	kindIndex[id] = index
end

-- Snapshot state codes (clients map them to animations).
Hollow.STATE_CODES = { idle = 1, wander = 2, alert = 3, chase = 4, attack = 5, flee = 6, dead = 7 }

-- (hosted, position: Vector3, enemy: EnemyDef, killer: Player?) when a Hollow dies.
Hollow.killed = Signal.new()

type Record = {
	id: string,
	enemy: Types.EnemyDef,
	arch: HollowAI.Archetype,
	ai: HollowAI.State,
	position: Vector3,
	home: Plane.Point,
	yaw: number,
	hp: number,
	maxHp: number,
	damage: number,
	burn: FlareMath.Burn?,
	burnOwner: Player?,
	diedAt: number?,
	path: { Vector3 }?, -- waypoints round an obstacle, nearest first
	pathGoal: Plane.Point?,
	pathAt: number,
	pathing: boolean, -- a path is being computed
	progressAt: number, -- the last time it got anywhere while moving (stuck guard)
	progressFrom: Vector3, -- where it stood then
	sidestep: Plane.Point?, -- a clear point beside it, walked to when a path keeps failing
}

type Cloud = { position: Vector3, radius: number, dps: number, endsAt: number }

type World = {
	hosted: Lobby.Hosted,
	hollows: { [string]: Record },
	noises: { Noise.Event },
	flares: { FlareMath.Flare },
	clouds: { Cloud },
	cues: { { any } },
	rng: Rng.Source,
	seq: number,
	lastSync: number,
	strength: number,
}

local worlds: { [string]: World } = {}

-- The nav probe steps virtual Hollows in its own time (Hollow.navProbe; Studio only).
local probeClock: number? = nil

local function now(): number
	return probeClock or workspace:GetServerTimeNow()
end

-- A compact, mixed-type row for the snapshot (an array keeps HollowSync small).
local function row(...: any): { any }
	return { ... }
end

-- Queues a one-shot cue for this lobby's clients: ("alert", id), ("noise", x, z, radius)...
local function cue(world: World, ...: any)
	table.insert(world.cues, row(...))
end

local function characters(world: World): { Instance }
	local list: { Instance } = {}
	for player in world.hosted.players do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function plane(position: Vector3): Plane.Point
	return { x = position.X, z = position.Z }
end

-- Spawning ------------------------------------------------------------------------------------

local function spawnPoints(world: World): { Vector3 }
	local points: { Vector3 } = {}
	local players = characters(world)
	for _, marker in Map.markers(world.hosted.map, "hollow") do
		-- A marker the map build found shut in (Maps.checkSpawns) never spawns anything.
		local clear = marker:GetAttribute("Unreachable") ~= true
		for _, character in players do
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - marker.Position).Magnitude < config.spawnSpreadStuds then
				clear = false
				break
			end
		end
		if clear then
			table.insert(points, marker.Position)
		end
	end
	return points
end

local function count(world: World): number
	local total = 0
	for _, record in world.hollows do
		if record.diedAt == nil then
			total += 1
		end
	end
	return total
end

-- Only kinds with a rig the clients can draw (ReplicatedStorage.EO_Hollow) ever spawn: an
-- unseen enemy would be worse than none (checklist §0). tests/Wildlife.spec checks every spawned or hunted kind has one.
local function drawable(enemyId: string): boolean
	local rigs = ReplicatedStorage:FindFirstChild("EO_Hollow")
	return rigs ~= nil and rigs:FindFirstChild(enemyId) ~= nil
end

local function spawn(world: World, enemyId: string, amount: number)
	local enemy = Content.Enemies[enemyId]
	local points = spawnPoints(world)
	if enemy == nil or #points == 0 or not drawable(enemyId) then
		return -- no map yet, every spot too close to a player, or no rig to draw it
	end
	local hp, damage = HollowAI.scaled(enemy, world.strength, tuning.hollowTierScale, world.hosted.location.fogTier)
	for _ = 1, amount do
		if count(world) >= config.maxActive then
			return
		end
		world.seq += 1
		local at = points[world.rng:NextInteger(1, #points)]
		local id = `h{world.seq}`
		world.hollows[id] = {
			id = id,
			enemy = enemy,
			arch = HollowAI.archetype(enemy, config, tuning.sneak),
			ai = HollowAI.new(now()),
			position = at,
			home = plane(at),
			yaw = world.rng:NextNumber() * 2 * math.pi,
			hp = hp,
			maxHp = hp,
			damage = damage,
			burn = nil,
			burnOwner = nil,
			diedAt = nil,
			path = nil,
			pathGoal = nil,
			pathAt = 0,
			pathing = false,
			progressAt = now(),
			progressFrom = at,
			sidestep = nil,
		}
	end
end

local function spawnBand(world: World, band: number)
	for _, group in HollowAI.spawnsForBand(world.hosted.location.enemySpawns, band, world.rng) do
		spawn(world, group.enemyId, group.count)
	end
end

local function rescale(world: World, strength: number)
	world.strength = strength
	for _, record in world.hollows do
		if record.diedAt == nil then
			local hp, damage =
				HollowAI.scaled(record.enemy, strength, tuning.hollowTierScale, world.hosted.location.fogTier)
			record.hp = record.hp / record.maxHp * hp
			record.maxHp = hp
			record.damage = damage
		end
	end
end

-- Public API for Combat, Containers and Extraction ---------------------------------------------------

local function worldOf(hosted: Lobby.Hosted): World?
	return worlds[hosted.id]
end

-- Makes a noise the Hollow can hear (gunshots carry their gun's firearm stats).
function Hollow.noise(
	hosted: Lobby.Hosted,
	kind: Noise.Kind,
	position: Vector3,
	firearm: Types.FirearmStats?,
	sourceId: string?,
	sneaking: boolean? -- the maker is sneaking: quieter melee and steps (LDOE_PARITY #44)
)
	local world = worldOf(hosted)
	if world == nil then
		return
	end
	world.seq += 1
	local sneak = if sneaking then tuning.sneak else nil
	local event = Noise.new(world.seq, kind, plane(position), now(), tuning.noise, firearm, sourceId, sneak)
	table.insert(world.noises, event)
	cue(world, "noise", position.X, position.Z, event.radius)
end

-- Lights a flare where it landed (the Hollow flee its light).
function Hollow.flare(hosted: Lobby.Hosted, stats: Types.FlareStats, position: Vector3, ownerId: string?)
	local world = worldOf(hosted)
	if world == nil then
		return
	end
	world.seq += 1
	table.insert(world.flares, FlareMath.new(world.seq, stats, plane(position), now(), ownerId))
	cue(world, "flare", position.X, position.Z, stats.seconds)
end

function Hollow.positionOf(hosted: Lobby.Hosted, id: string): Vector3?
	local world = worldOf(hosted)
	local record = world and world.hollows[id]
	return if record and record.diedAt == nil then record.position else nil
end

-- Whether it has noticed anyone (a sneak backstab needs it not to, LDOE_PARITY #44).
function Hollow.isAware(hosted: Lobby.Hosted, id: string): boolean
	local world = worldOf(hosted)
	local record = world and world.hollows[id]
	return record ~= nil and HollowAI.isAware(record.ai)
end

export type Candidate = { id: string, distance: number }

-- Living Hollow inside a melee arc, nearest first.
function Hollow.inArc(
	hosted: Lobby.Hosted,
	origin: Vector3,
	yaw: number,
	range: number,
	arcDegrees: number
): { Candidate }
	local list: { Candidate } = {}
	local world = worldOf(hosted)
	if world == nil then
		return list
	end
	local from = plane(origin)
	for id, record in world.hollows do
		local at = plane(record.position)
		if record.diedAt == nil and Plane.inArc(from, yaw, at, range, arcDegrees, config.hitRadiusStuds) then
			table.insert(list, { id = id, distance = Plane.distance(from, at) })
		end
	end
	table.sort(list, function(a: Candidate, b: Candidate): boolean
		return a.distance < b.distance
	end)
	return list
end

-- The first living Hollow along a shot, within `range` (the caller caps it at walls).
function Hollow.raycast(hosted: Lobby.Hosted, origin: Vector3, yaw: number, range: number): (string?, number)
	local world = worldOf(hosted)
	if world == nil then
		return nil, range
	end
	local from = plane(origin)
	local bestId: string? = nil
	local best = range
	for id, record in world.hollows do
		if record.diedAt == nil then
			local t = Plane.rayCircle(from, yaw, best, plane(record.position), config.hitRadiusStuds)
			if t and t <= best then
				bestId, best = id, t
			end
		end
	end
	return bestId, best
end

local function burst(world: World, record: Record)
	local def = record.enemy.burst
	if def == nil then
		return
	end
	table.insert(world.clouds, {
		position = record.position,
		radius = def.radius,
		dps = def.damagePerSecond,
		endsAt = now() + def.cloudSeconds,
	})
	Hollow.noise(world.hosted, "bloaterBurst", record.position, nil, record.id)
	cue(world, "burst", record.id, record.position.X, record.position.Z, def.radius)
end

local function kill(world: World, record: Record, killer: Player?)
	if record.diedAt then
		return
	end
	record.diedAt = now()
	record.hp = 0
	record.ai = HollowAI.step(record.arch, record.ai, {
		now = now(),
		position = plane(record.position),
		home = record.home,
		hp = 0,
		targets = {},
		noise = nil,
		light = nil,
		rng = world.rng,
	})
	burst(world, record) -- a bloater pops as it dies
	cue(world, "dead", record.id)
	if killer then
		Progression.grantXp(killer, record.enemy.xp, "Hollow")
		Lobby.recordKill(killer)
	end
	Hollow.killed:Fire(world.hosted, record.position, record.enemy, killer)
end

export type DamageOptions = {
	knockbackStuds: number?,
	fromYaw: number?,
	burn: Types.FlareStats?, -- a flare hit sets it burning
	crit: boolean?,
}

--[[
	Damages one Hollow. Returns the damage dealt and whether it died. Knockback
	pushes it along `fromYaw`; any damage makes it notice the attacker.
]]
function Hollow.damage(
	hosted: Lobby.Hosted,
	id: string,
	amount: number,
	source: Player?,
	options: DamageOptions?
): (number, boolean)
	local world = worldOf(hosted)
	local record = world and world.hollows[id]
	if world == nil or record == nil or record.diedAt or amount <= 0 then
		return 0, false
	end
	local opts: DamageOptions = options or {}
	local dealt = math.min(amount, record.hp)
	record.hp -= dealt
	if opts.knockbackStuds and opts.fromYaw then
		local pushed = Plane.offset(plane(record.position), opts.fromYaw, opts.knockbackStuds)
		record.position = Vector3.new(pushed.x, record.position.Y, pushed.z)
	end
	if opts.burn then
		record.burn = FlareMath.ignite(opts.burn, now(), record.burn)
		record.burnOwner = source
	end
	cue(world, "hit", id, math.floor(dealt * 10 + 0.5) / 10, opts.crit == true)
	if record.hp <= 0 then
		kill(world, record, source)
		return dealt, true
	end
	return dealt, false
end

-- AI tick -------------------------------------------------------------------------------------

local STUDIO = RunService:IsStudio()

local function senses(world: World, record: Record, exclude: { Instance }): { HollowAI.Target }
	local targets: { HollowAI.Target } = {}
	local eye = record.position + Vector3.new(0, EYE_HEIGHT, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	for player in world.hosted.players do
		-- Studio captures only: a DevUnseen player is invisible to the Hollow.
		if STUDIO and player:GetAttribute("DevUnseen") == true then
			continue
		end
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if head and humanoid and humanoid.Health > 0 then
			local offset = head.Position - eye
			if offset.Magnitude <= record.arch.sightRadius + 2 then
				local blocked = workspace:Raycast(eye, offset, params)
				table.insert(targets, {
					id = tostring(player.UserId),
					position = plane(head.Position),
					visible = blocked == nil,
					sneaking = player:GetAttribute("Sneaking") == true,
				})
			end
		end
	end
	return targets
end

local function playerById(world: World, id: string?): Player?
	if id == nil then
		return nil
	end
	for player in world.hosted.players do
		if tostring(player.UserId) == id then
			return player
		end
	end
	return nil
end

-- Pathing ------------------------------------------------------------------------------------------

local PATH_REFRESH = 2 -- seconds before a path is recomputed
local PATH_GOAL_MOVED = 6 -- studs the goal may move before the path is recomputed
local PATH_BUDGET = 4 -- path computations started per world per tick
local WAYPOINT_REACHED = 2
local STEP_UP = 2.2 -- the highest ledge a Hollow steps onto (a floor or a sill, never a car)
local PATH_STEP_UP = 4 -- along a navmesh path (a doorway's step, a dock's ramp edge) it climbs a little more
local STUCK_SECONDS = 1.5 -- no headway for this long while moving: re-path at once
local SIDESTEP_SECONDS = 3 -- still none: step aside to a clear spot, then try again
local HEADWAY = 0.6 -- studs that count as getting somewhere

-- Pathfinding agents per archetype (checklist 12.9): a bloater is wide and won't fit a
-- door a runner takes (radius 1.0 is a Hollow's body: the nav probe found 1.2 too wide for a
-- 4.5-stud door on the navmesh). Water is all but impassable, mud slow, undergrowth a little slow.
local COSTS = { Water = 40, Mud = 3, Foliage = 2 }
local AGENTS: { [string]: { [string]: any } } = {
	default = { AgentRadius = 1.0, AgentHeight = 5.5, AgentCanJump = true, WaypointSpacing = 5, Costs = COSTS },
	["enemy.runner"] = {
		AgentRadius = 1.0,
		AgentHeight = 5.5,
		AgentCanJump = true,
		WaypointSpacing = 5,
		Costs = COSTS,
	},
	["enemy.bloater"] = {
		AgentRadius = 1.6,
		AgentHeight = 6.5,
		AgentCanJump = true,
		WaypointSpacing = 6,
		Costs = COSTS,
	},
}

local function agentFor(enemyId: string): { [string]: any }
	return AGENTS[enemyId] or AGENTS.default
end

-- Whether a straight walk to `goal` is clear at chest height (walls, wrecks, fences). The
-- ground itself never counts (QA, the nav probe: a creek bank or a slope read as a wall);
-- a ledge too high to step onto stops it in advance() instead.
local function clearWay(from: Vector3, goal: Vector3, exclude: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = table.clone(exclude)
	table.insert(ignore, workspace.Terrain)
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local origin = from + Vector3.new(0, 2.5, 0)
	local target = Vector3.new(goal.X, origin.Y, goal.Z)
	local offset = target - origin
	if offset.Magnitude < 0.5 then
		return true
	end
	return workspace:Raycast(origin, offset, params) == nil
end

local function requestPath(record: Record, goal: Vector3)
	record.pathing = true
	record.pathAt = now()
	record.pathGoal = plane(goal)
	task.spawn(function()
		local path = PathfindingService:CreatePath(agentFor(record.enemy.id))
		local ok = pcall(function()
			path:ComputeAsync(record.position, goal)
		end)
		record.pathing = false
		if not ok or path.Status ~= Enum.PathStatus.Success or record.diedAt then
			record.path = nil
			return
		end
		local points: { Vector3 } = {}
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, waypoint.Position)
		end
		table.remove(points, 1) -- where it stands
		record.path = points
	end)
end

-- The point to walk toward this tick: the goal itself, or the next waypoint round an obstacle.
local function steer(
	record: Record,
	goal: Plane.Point,
	budget: { n: number },
	exclude: { Instance }
): (Plane.Point, boolean)
	local goal3 = Vector3.new(goal.x, record.position.Y, goal.z)
	if clearWay(record.position, goal3, exclude) then
		record.path = nil
		return goal, false
	end
	local stale = record.pathGoal == nil
		or Plane.distance(record.pathGoal :: Plane.Point, goal) > PATH_GOAL_MOVED
		or now() - record.pathAt > PATH_REFRESH
	if stale and not record.pathing and budget.n > 0 then
		budget.n -= 1
		requestPath(record, goal3)
	end
	local path = record.path
	while path and #path > 0 do
		local nextPoint = path[1]
		if Plane.distance(plane(record.position), plane(nextPoint)) > WAYPOINT_REACHED then
			return plane(nextPoint), true
		end
		table.remove(path, 1)
	end
	return goal, false -- no path yet: it waits at the obstacle (it never walks into it; see advance)
end

-- A clear spot a few studs to one side, for a Hollow that can't get round something.
local function sidestepFrom(record: Record, goal: Plane.Point, exclude: { Instance }, rng: Rng.Source): Plane.Point?
	local here = plane(record.position)
	local heading = math.atan2(goal.x - here.x, goal.z - here.z)
	for _ = 1, 8 do
		local angle = heading + (rng:NextNumber() - 0.5) * math.pi * 1.6
		local reach = 4 + rng:NextNumber() * 4
		local spot = { x = here.x + math.sin(angle) * reach, z = here.z + math.cos(angle) * reach }
		if clearWay(record.position, Vector3.new(spot.x, record.position.Y, spot.z), exclude) then
			return spot
		end
	end
	return nil
end

--[[
	One tick of walking toward `goal` (checklist 12.9): along a path round anything in the
	way, never into a solid (the step ahead is checked at chest height first), stepping up
	at most a sill, and never stuck: no headway for STUCK_SECONDS forces a fresh path, and
	for SIDESTEP_SECONDS a step aside to a clear spot before trying again.
]]
local function advance(
	record: Record,
	goal: Plane.Point,
	speed: number,
	dt: number,
	exclude: { Instance },
	budget: { n: number },
	rng: Rng.Source
)
	local here = plane(record.position)
	local stamp = now()
	local target = goal
	local sidestep = record.sidestep
	if sidestep then
		if Plane.distance(here, sidestep) <= 1 then
			record.sidestep = nil
		else
			target = sidestep
		end
	end
	local towards, onPath = target, false
	if record.sidestep == nil then
		towards, onPath = steer(record, target, budget, exclude)
	end
	local nextPoint = Plane.moveToward(here, towards, speed * dt)
	local ahead = Plane.moveToward(here, towards, speed * dt + 1.2) -- a body's width beyond the step
	local moved = false
	-- A navmesh waypoint is clear for this agent's size already; a straight walk is checked.
	if onPath or clearWay(record.position, Vector3.new(ahead.x, record.position.Y, ahead.z), exclude) then
		local stepUp = if onPath then PATH_STEP_UP else STEP_UP
		local landing = Map.ground(nextPoint.x, nextPoint.z, record.position.Y, exclude, stepUp)
		if landing.Y - record.position.Y <= stepUp then
			record.yaw = Plane.yawTo(here, nextPoint)
			record.position = landing
			moved = true
		end
	end
	if not moved and not record.pathing and budget.n > 0 and record.sidestep == nil and stamp - record.pathAt > 0.5 then
		-- Blocked this step: a path round it now, not at the next refresh.
		budget.n -= 1
		requestPath(record, Vector3.new(target.x, record.position.Y, target.z))
	end
	if (record.position - record.progressFrom).Magnitude >= HEADWAY then
		record.progressAt = stamp
		record.progressFrom = record.position
	elseif stamp - record.progressAt > SIDESTEP_SECONDS and record.sidestep == nil then
		record.sidestep = sidestepFrom(record, goal, exclude, rng)
		record.path = nil
		record.pathGoal = nil
		record.progressAt = stamp
	elseif stamp - record.progressAt > STUCK_SECONDS and not record.pathing then
		record.pathGoal = nil -- stale at once: the next tick asks for a fresh path
	end
end

local function stepHollow(world: World, record: Record, dt: number, exclude: { Instance }, budget: { n: number })
	local stamp = now()
	local here = plane(record.position)
	if record.burn then
		local burnDamage = FlareMath.burnDamage(record.burn, stamp - dt, stamp)
		if burnDamage > 0 then
			Hollow.damage(world.hosted, record.id, burnDamage, record.burnOwner)
			if record.diedAt then
				return
			end
		elseif stamp >= record.burn.endsAt then
			record.burn = nil
		end
	end
	local heard = Noise.loudest(
		world.noises,
		{ id = record.id, position = here, hearing = record.enemy.hearing },
		stamp,
		tuning.noise
	)
	local exposure, source = FlareMath.strongest(world.flares, here, stamp)
	local state, output = HollowAI.step(record.arch, record.ai, {
		now = stamp,
		position = here,
		home = record.home,
		hp = record.hp,
		targets = senses(world, record, exclude),
		noise = if heard then heard.position else nil,
		light = if source and exposure > 0 then { exposure = exposure, source = source } else nil,
		rng = world.rng,
	})
	record.ai = state
	if output.cue then
		cue(world, output.cue, record.id)
	end
	if output.action == "move" and output.moveTo then
		advance(record, output.moveTo, output.speed, dt, exclude, budget, world.rng)
	else
		record.progressAt = stamp -- standing still on purpose is not being stuck
		record.progressFrom = record.position
	end
	if output.action == "attack" then
		local target = playerById(world, output.targetId)
		if target then
			Lobby.hurtPlayer(target, record.damage, "hollow", record.position)
			cue(world, "attack", record.id)
		end
	elseif output.action == "burst" then
		burst(world, record)
		record.diedAt = stamp
		record.hp = 0
		cue(world, "dead", record.id)
	end
end

local function tickClouds(world: World, dt: number)
	local stamp = now()
	local live: { Cloud } = {}
	for _, cloud in world.clouds do
		if stamp < cloud.endsAt then
			table.insert(live, cloud)
			for player in world.hosted.players do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and (root.Position - cloud.position).Magnitude <= cloud.radius then
					Lobby.hurtPlayer(player, cloud.dps * dt, "burst", cloud.position)
				end
			end
		end
	end
	world.clouds = live
end

local function tickWorld(world: World, dt: number)
	local stamp = now()
	world.noises = Noise.prune(world.noises, stamp, tuning.noise)
	world.flares = FlareMath.prune(world.flares, stamp)
	local exclude = characters(world)
	local budget = { n = PATH_BUDGET }
	for id, record in world.hollows do
		if record.diedAt then
			if stamp - record.diedAt > DEAD_LINGER_SECONDS then
				world.hollows[id] = nil
			end
		else
			stepHollow(world, record, dt, exclude, budget)
		end
	end
	tickClouds(world, dt)
end

local function sync(world: World)
	local list: { { any } } = {}
	for id, record in world.hollows do
		table.insert(
			list,
			row(
				id,
				kindIndex[record.enemy.id],
				math.floor(record.position.X * 10) / 10,
				math.floor(record.position.Y * 10) / 10,
				math.floor(record.position.Z * 10) / 10,
				math.floor(record.yaw * 100) / 100,
				Hollow.STATE_CODES[record.ai.name],
				math.floor(record.hp / record.maxHp * 100)
			)
		)
	end
	local payload = { t = now(), hollows = list, cues = world.cues }
	world.cues = {}
	for player in world.hosted.players do
		Net.fireClient("HollowSync", player, payload)
	end
end

--[[
	The nav probe (checklist 12.9; Studio only, through Diagnostics' "navprobe"): virtual
	Hollows of one kind walk from every Hollow spawn marker on a built map to sampled
	places a survivor could stand (open, dry, clear ground inside the bounds), with the
	same advance() the live Hollow uses, in the probe's own clock. A trip succeeds when it
	ends within 3.5 studs of its target in time; a Hollow without headway for 5 s counts
	as stuck. Run it with no lobby open (it borrows the Hollow's clock).
]]
export type ProbeResult = {
	trips: number,
	reached: number,
	stuck: number, -- trips with a 5 s stretch of no headway
	worstStall: number, -- seconds
	failures: { string },
}

local function probeTargets(map: Instance, wanted: number, rng: Rng.Source): { Vector3 }
	local bounds = Map.bounds(map)
	local origin = map:GetAttribute("Origin") :: Vector3
	local half = map:GetAttribute("Half") :: number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	params.RespectCanCollide = true
	params.IgnoreWater = false
	local overlap = OverlapParams.new()
	overlap.RespectCanCollide = true
	local found: { Vector3 } = {}
	-- About a quarter of the targets stand inside buildings (survivors hide in them; the
	-- Hollow must get through the doors).
	local floors: { BasePart } = {}
	local buildings = map:FindFirstChild("Buildings")
	if buildings then
		for _, part in buildings:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Floor" then
				table.insert(floors, part)
			end
		end
	end
	for index = 1, math.min(#floors, math.floor(wanted / 4)) do
		local floor = floors[(index - 1) % #floors + 1]
		table.insert(found, floor.Position + Vector3.new(0, 0.1, 0))
	end
	for _ = 1, wanted * 30 do
		if #found >= wanted then
			break
		end
		local x = origin.X + (rng:NextNumber() * 2 - 1) * (half - 12)
		local z = origin.Z + (rng:NextNumber() * 2 - 1) * (half - 12)
		local hit = workspace:Raycast(Vector3.new(x, origin.Y + 150, z), Vector3.new(0, -300, 0), params)
		if
			hit
			and hit.Instance == workspace.Terrain
			and hit.Material ~= Enum.Material.Water
			and (bounds == nil or Map.insideBy(bounds, hit.Position) > 6)
		then
			local body = workspace:GetPartBoundsInRadius(hit.Position + Vector3.new(0, 2.6, 0), 1.6, overlap)
			if #body == 0 then
				table.insert(found, hit.Position)
			end
		end
	end
	return found
end

function Hollow.navProbe(map: Instance, enemyId: string, trips: number): ProbeResult
	local enemy = Content.Enemies[enemyId]
	assert(enemy, `no enemy {enemyId}`)
	local rng = Rng.new(trips * 7919 + #enemyId)
	local starts: { Vector3 } = {}
	for _, marker in Map.markers(map, "hollow") do
		if marker:GetAttribute("Unreachable") ~= true then
			table.insert(starts, (marker :: BasePart).Position)
		end
	end
	local targets = probeTargets(map, trips, rng)
	local result: ProbeResult = { trips = 0, reached = 0, stuck = 0, worstStall = 0, failures = {} }
	local speed = enemy.moveSpeed
	local dt = 0.1
	local clock = workspace:GetServerTimeNow()
	probeClock = clock
	for index, target in targets do
		local start = starts[(index - 1) % #starts + 1]
		local ground = Map.ground(start.X, start.Z, start.Y + 2, {}, 4)
		local record: Record = {
			id = `probe{index}`,
			enemy = enemy,
			arch = HollowAI.archetype(enemy, config, tuning.sneak),
			ai = HollowAI.new(now()),
			position = ground,
			home = plane(ground),
			yaw = 0,
			hp = 1,
			maxHp = 1,
			damage = 0,
			burn = nil,
			burnOwner = nil,
			diedAt = nil,
			path = nil,
			pathGoal = nil,
			pathAt = 0,
			pathing = false,
			progressAt = now(),
			progressFrom = ground,
			sidestep = nil,
		}
		local goal = plane(target)
		local limit = Plane.distance(plane(ground), goal) / speed * 3 + 20
		local elapsed, stallFrom, stalled = 0, 0, false
		local lastSpot = ground
		while elapsed < limit and Plane.distance(plane(record.position), goal) > 3.5 do
			advance(record, goal, speed, dt, {}, { n = 1 }, rng)
			while record.pathing do
				task.wait()
			end
			elapsed += dt
			clock += dt
			probeClock = clock -- its own clock (another probe may have finished meanwhile)
			if (record.position - lastSpot).Magnitude >= HEADWAY then
				lastSpot = record.position
				stallFrom = elapsed
			elseif elapsed - stallFrom > 5 and not stalled then
				stalled = true
			end
			result.worstStall = math.max(result.worstStall, elapsed - stallFrom)
		end
		result.trips += 1
		local reached = Plane.distance(plane(record.position), goal) <= 3.5
		if reached then
			result.reached += 1
		elseif #result.failures < 6 then
			local origin = map:GetAttribute("Origin") :: Vector3
			local from, to, at = start - origin, target - origin, record.position - origin
			table.insert(
				result.failures,
				string.format(
					"(%d,%d)->(%d,%d) ended (%d,%d)",
					math.round(from.X),
					math.round(from.Z),
					math.round(to.X),
					math.round(to.Z),
					math.round(at.X),
					math.round(at.Z)
				)
			)
		end
		if stalled then
			result.stuck += 1
		end
		if index % 4 == 0 then
			task.wait()
		end
	end
	probeClock = nil
	return result
end

function Hollow.init() end

function Hollow.start()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	Lobby.opened:Connect(function(hosted: Lobby.Hosted)
		local world: World = {
			hosted = hosted,
			hollows = {},
			noises = {},
			flares = {},
			clouds = {},
			cues = {},
			rng = Rng.new(hosted.state.seed),
			seq = 0,
			lastSync = 0,
			strength = 1,
		}
		worlds[hosted.id] = world
	end)
	Lobby.entered:Connect(function(_player: Player, run: Lobby.Run)
		-- The first arrival starts the meter: the band-1 Hollow wake now.
		local world = worlds[run.hosted.id]
		if world and next(world.hollows) == nil and world.seq == 0 then
			spawnBand(world, 1)
		end
	end)
	Lobby.bandChanged:Connect(function(hosted: Lobby.Hosted, band: number)
		local world = worlds[hosted.id]
		if world then
			rescale(world, tuning.lobby.bands[band].hollowStrength)
			spawnBand(world, band)
		end
	end)
	Lobby.closed:Connect(function(hosted: Lobby.Hosted)
		worlds[hosted.id] = nil
	end)
	task.spawn(function()
		local last = now()
		while true do
			task.wait(config.tickSeconds)
			local stamp = now()
			local dt = math.min(stamp - last, config.tickSeconds * 3)
			last = stamp
			for id, world in worlds do
				local ok, err = pcall(tickWorld :: any, world, dt)
				if not ok then
					warn(`Hollow: tick failed in {id}: {err}`)
				end
				if stamp - world.lastSync >= config.syncSeconds then
					world.lastSync = stamp
					sync(world)
				end
			end
		end
	end)
end

return Hollow
