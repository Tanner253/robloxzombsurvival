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

	Movement is straight-line with ground snapping in Phase A; Phase B adds
	pathing around the handcrafted maps.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function now(): number
	return workspace:GetServerTimeNow()
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
		local clear = true
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

local function spawn(world: World, enemyId: string, amount: number)
	local enemy = Content.Enemies[enemyId]
	local points = spawnPoints(world)
	if enemy == nil or #points == 0 then
		return -- no map yet (Phase A) or every spot is too close to a player
	end
	local hp, damage = HollowAI.scaled(enemy, world.strength)
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
			arch = HollowAI.archetype(enemy, config),
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
			local hp, damage = HollowAI.scaled(record.enemy, strength)
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
	sourceId: string?
)
	local world = worldOf(hosted)
	if world == nil then
		return
	end
	world.seq += 1
	table.insert(world.noises, Noise.new(world.seq, kind, plane(position), now(), tuning.noise, firearm, sourceId))
	cue(world, "noise", position.X, position.Z, Noise.radius(kind, tuning.noise, firearm))
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

local function senses(world: World, record: Record, exclude: { Instance }): { HollowAI.Target }
	local targets: { HollowAI.Target } = {}
	local eye = record.position + Vector3.new(0, EYE_HEIGHT, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	for player in world.hosted.players do
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

local function stepHollow(world: World, record: Record, dt: number, exclude: { Instance })
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
		local nextPoint = Plane.moveToward(here, output.moveTo, output.speed * dt)
		record.yaw = Plane.yawTo(here, nextPoint)
		record.position = Map.ground(nextPoint.x, nextPoint.z, record.position.Y, exclude)
	elseif output.action == "attack" then
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
	for id, record in world.hollows do
		if record.diedAt then
			if stamp - record.diedAt > DEAD_LINGER_SECONDS then
				world.hollows[id] = nil
			end
		else
			stepHollow(world, record, dt, exclude)
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
