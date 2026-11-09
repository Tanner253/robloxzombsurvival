--!strict
--[[
	HollowAI: the Hollow's brain as a pure state machine (checklist 13.2).

	States: idle, wander, alert, chase, attack, flee, dead.
	Inputs each step: the time, its position and home (spawn point), HP, the
	players around it with a line-of-sight flag the server raycast, the loudest
	noise it hears (Domain/Noise), and the light it stands in (Domain/Flare).
	Outputs: the new state and one action ("move" to a point at a speed, "attack" a
	target, "fuse" to start a bloater's burst, "burst", or "none"), plus a cue for
	the client ("alert" is the "!" read, "flee", "fuse").

	Priorities, highest first:
	1. dead stays dead; HP at 0 dies (a bloater bursts as it dies)
	2. a lit fuse holds still, then bursts
	3. light at or above its lightFear: flee directly away for fleeSeconds
	4. a visible player within sight: chase, attack in range on its attack timer
	   (a bloater starts its fuse at triggerRange instead); after losing sight it
	   keeps chasing the last seen spot for loseTargetSeconds
	5. a heard noise: alert, walk to it, linger alertSeconds (packs form there)
	6. otherwise idle a few seconds, then wander near home

	Movement, pathing and line of sight are the service's job; this only decides.
]]

local Types = require("../Types")
local Plane = require("./Plane")
local Rng = require("./Rng")

local HollowAI = {}

HollowAI.WANDER_SPEED = 0.45 -- of moveSpeed
HollowAI.ALERT_SPEED = 0.75
HollowAI.FLEE_SPEED = 1.1
HollowAI.ARRIVE_STUDS = 1.5

export type StateName = "idle" | "wander" | "alert" | "chase" | "attack" | "flee" | "dead"
export type Action = "none" | "move" | "attack" | "fuse" | "burst"
export type Cue = "alert" | "flee" | "fuse"

export type Archetype = {
	sightRadius: number,
	attackRange: number,
	attackSeconds: number,
	moveSpeed: number,
	lightFear: number,
	burst: Types.BurstDef?,
	alertSeconds: number,
	loseTargetSeconds: number,
	idleSeconds: Types.Range,
	wanderRadius: number,
	fleeSeconds: number,
	-- LDoE parity: #44 sneaking players are seen from sneakDetection x sightRadius;
	-- #35 skittish animals bolt from anyone within spookRadius instead of fighting.
	sneakDetection: number,
	skittish: boolean,
	spookRadius: number,
}

export type State = {
	name: StateName,
	since: number,
	untilAt: number?, -- when idling, alert or flight ends
	goal: Plane.Point?,
	targetId: string?,
	lastSeen: Plane.Point?,
	lastSeenAt: number?,
	lastAttackAt: number,
	fuseAt: number?,
	burst: boolean,
}

export type Target = {
	id: string,
	position: Plane.Point,
	visible: boolean, -- line of sight from the Hollow, raycast by the server
	sneaking: boolean?, -- LDOE_PARITY #44: harder to spot
}

export type Light = {
	exposure: number, -- 0..1 (Flare.exposure)
	source: Plane.Point,
}

export type Inputs = {
	now: number,
	position: Plane.Point,
	home: Plane.Point,
	hp: number,
	targets: { Target },
	noise: Plane.Point?, -- where the loudest noise it hears came from
	light: Light?,
	rng: Rng.Source,
}

export type Output = {
	action: Action,
	moveTo: Plane.Point?,
	speed: number,
	targetId: string?,
	cue: Cue?,
}

-- The brain's numbers for one enemy: its definition plus Tuning.hollow (and Tuning.sneak).
function HollowAI.archetype(enemy: Types.EnemyDef, tuning: Types.HollowTuning, sneak: Types.SneakTuning?): Archetype
	local wildlife = enemy.wildlife
	return {
		sneakDetection = if sneak then sneak.detectionMultiplier else 1,
		skittish = wildlife ~= nil and wildlife.temperament == "skittish",
		spookRadius = if wildlife then wildlife.spookRadius else 0,
		sightRadius = enemy.aggroRadius,
		attackRange = enemy.attackRange,
		attackSeconds = enemy.attackSeconds,
		moveSpeed = enemy.moveSpeed,
		lightFear = enemy.lightFear,
		burst = enemy.burst,
		alertSeconds = tuning.alertSeconds,
		loseTargetSeconds = tuning.loseTargetSeconds,
		idleSeconds = tuning.idleSeconds,
		wanderRadius = tuning.wanderRadius,
		fleeSeconds = tuning.fleeSeconds,
	}
end

function HollowAI.new(now: number): State
	return {
		name = "idle",
		since = now,
		untilAt = now,
		goal = nil,
		targetId = nil,
		lastSeen = nil,
		lastSeenAt = nil,
		lastAttackAt = -math.huge,
		fuseAt = nil,
		burst = false,
	}
end

local function copy(state: State): State
	return table.clone(state)
end

local function enter(state: State, name: StateName, now: number)
	if state.name ~= name then
		state.name = name
		state.since = now
	end
end

local function out(action: Action, moveTo: Plane.Point?, speed: number, targetId: string?, cue: Cue?): Output
	return { action = action, moveTo = moveTo, speed = speed, targetId = targetId, cue = cue }
end

local function calm(name: StateName): boolean
	return name == "idle" or name == "wander"
end

-- Whether it has noticed someone (a backstab needs it not to, LDOE_PARITY #44).
function HollowAI.isAware(state: State): boolean
	return state.name == "alert" or state.name == "chase" or state.name == "attack"
end

-- The nearest visible player within sight (a sneaking one only from closer).
local function spot(arch: Archetype, inputs: Inputs): (Target?, number)
	local best: Target? = nil
	local bestDistance = math.huge
	for _, target in inputs.targets do
		if target.visible then
			local distance = Plane.distance(inputs.position, target.position)
			local reach = arch.sightRadius * (if target.sneaking then arch.sneakDetection else 1)
			if distance <= reach and distance < bestDistance then
				best, bestDistance = target, distance
			end
		end
	end
	return best, bestDistance
end

-- A skittish animal's nearest threat: anyone within its spook radius, seen or heard.
local function spooked(arch: Archetype, inputs: Inputs): Plane.Point?
	if not arch.skittish then
		return nil
	end
	local nearest: Plane.Point? = nil
	local nearestDistance = math.huge
	for _, target in inputs.targets do
		local distance = Plane.distance(inputs.position, target.position)
		local reach = arch.spookRadius * (if target.sneaking then arch.sneakDetection else 1)
		if distance <= reach and distance < nearestDistance then
			nearest, nearestDistance = target.position, distance
		end
	end
	return nearest or inputs.noise
end

-- One decision. Returns the next state (the input is not modified) and the action.
function HollowAI.step(arch: Archetype, state: State, inputs: Inputs): (State, Output)
	local now = inputs.now
	local s = copy(state)
	if state.name == "dead" then
		return s, out("none", nil, 0)
	end

	-- 1. Death (a bloater bursts as it goes).
	if inputs.hp <= 0 then
		enter(s, "dead", now)
		if arch.burst and not state.burst then
			s.burst = true
			return s, out("burst", nil, 0)
		end
		return s, out("none", nil, 0)
	end

	-- 2. A lit fuse.
	if state.fuseAt then
		if now >= state.fuseAt then
			enter(s, "dead", now)
			s.burst = true
			return s, out("burst", nil, 0)
		end
		return s, out("none", nil, 0, state.targetId)
	end

	-- 3. Fear of light.
	local light = inputs.light
	if light and light.exposure >= arch.lightFear then
		local wasFleeing = state.name == "flee"
		local away = Plane.yawTo(light.source, inputs.position)
		s.goal = Plane.offset(inputs.position, away, arch.wanderRadius / 2)
		s.untilAt = now + arch.fleeSeconds
		s.targetId = nil
		enter(s, "flee", now)
		return s, out("move", s.goal, arch.moveSpeed * HollowAI.FLEE_SPEED, nil, if wasFleeing then nil else "flee")
	end
	-- 3b. A skittish animal bolts from players and noise instead of fighting (#35).
	local threat = spooked(arch, inputs)
	if threat then
		local wasFleeing = state.name == "flee"
		s.goal = Plane.offset(inputs.position, Plane.yawTo(threat, inputs.position), arch.wanderRadius)
		s.untilAt = now + arch.fleeSeconds
		s.targetId = nil
		enter(s, "flee", now)
		return s, out("move", s.goal, arch.moveSpeed, nil, if wasFleeing then nil else "flee")
	end
	if state.name == "flee" and state.untilAt and now < state.untilAt then
		return s, out("move", state.goal, arch.moveSpeed * HollowAI.FLEE_SPEED, nil)
	end
	if arch.skittish then
		-- Animals that aren't spooked just graze and wander: skip sight, noise and attacks.
		inputs = table.clone(inputs)
		inputs.targets = {}
		inputs.noise = nil
	end

	-- 4. Sight and memory.
	local seen, distance = spot(arch, inputs)
	if seen then
		s.targetId = seen.id
		s.lastSeen = { x = seen.position.x, z = seen.position.z }
		s.lastSeenAt = now
	end
	local remembered = seen == nil
		and state.targetId ~= nil
		and state.lastSeenAt ~= nil
		and now - state.lastSeenAt <= arch.loseTargetSeconds
	if seen or remembered then
		local cue: Cue? = if calm(state.name) then "alert" else nil
		if seen then
			local burst = arch.burst
			if burst and distance <= burst.triggerRange then
				s.fuseAt = now + burst.fuseSeconds
				enter(s, "attack", now)
				return s, out("fuse", nil, 0, seen.id, "fuse")
			end
			if distance <= arch.attackRange then
				enter(s, "attack", now)
				if now - state.lastAttackAt >= arch.attackSeconds then
					s.lastAttackAt = now
					return s, out("attack", nil, 0, seen.id, cue)
				end
				return s, out("none", nil, 0, seen.id, cue)
			end
		end
		enter(s, "chase", now)
		return s, out("move", s.lastSeen, arch.moveSpeed, s.targetId, cue)
	end
	s.targetId = nil

	-- 5. Noise.
	if inputs.noise then
		local cue: Cue? = if calm(state.name) then "alert" else nil
		s.goal = { x = inputs.noise.x, z = inputs.noise.z }
		s.untilAt = now + arch.alertSeconds
		enter(s, "alert", now)
		return s, out("move", s.goal, arch.moveSpeed * HollowAI.ALERT_SPEED, nil, cue)
	end
	if state.name == "alert" and state.untilAt and now < state.untilAt then
		local goal = state.goal
		if goal and Plane.distance(inputs.position, goal) > HollowAI.ARRIVE_STUDS then
			return s, out("move", goal, arch.moveSpeed * HollowAI.ALERT_SPEED, nil)
		end
		return s, out("none", nil, 0) -- lingers where the noise was
	end

	-- 6. Idle and wander.
	if
		state.name == "wander"
		and state.goal
		and Plane.distance(inputs.position, state.goal) > HollowAI.ARRIVE_STUDS
	then
		return s, out("move", state.goal, arch.moveSpeed * HollowAI.WANDER_SPEED, nil)
	end
	if state.name == "idle" and state.untilAt and now < state.untilAt then
		return s, out("none", nil, 0)
	end
	if state.name ~= "idle" then
		-- Arrived, lost the trail, or calmed down: stand a moment.
		enter(s, "idle", now)
		s.goal = nil
		s.untilAt = now + inputs.rng:NextInteger(arch.idleSeconds.min, arch.idleSeconds.max)
		return s, out("none", nil, 0)
	end
	local yaw = inputs.rng:NextNumber() * 2 * math.pi
	local reach = inputs.rng:NextNumber() * arch.wanderRadius
	s.goal = Plane.offset(inputs.home, yaw, reach)
	s.untilAt = nil
	enter(s, "wander", now)
	return s, out("move", s.goal, arch.moveSpeed * HollowAI.WANDER_SPEED, nil)
end

--[[
	The Fog meter's band makes the Hollow stronger (Tuning.lobby.bands): HP and
	damage scale by `strength`. Returns the scaled HP and damage.
]]
export type TierScale = { health: { number }, damage: { number } }

--[[
	Health and damage at the lobby's Fog-meter `strength`, times the fog tier's scale when
	one is given (ECONOMY §6.4, Tuning.hollowTierScale: Light, Dense, Black). Wildlife
	keeps its stats on every tier.
]]
function HollowAI.scaled(
	enemy: Types.EnemyDef,
	strength: number,
	tierScale: TierScale?,
	fogTier: number?
): (number, number)
	local health, damage = 1, 1
	if tierScale and fogTier and enemy.wildlife == nil then
		health = tierScale.health[fogTier] or 1
		damage = tierScale.damage[fogTier] or 1
	end
	return enemy.hp * strength * health, enemy.damage * strength * damage
end

export type SpawnGroup = { enemyId: Types.EnemyId, count: number }

--[[
	Which Hollow join the lobby when the Fog meter enters `band`: band 1 spawns
	every set without a minBand (or minBand 1); band n spawns the sets whose
	minBand is n. Counts are rolled in each set's range; empty groups are left out.
]]
function HollowAI.spawnsForBand(spawns: { Types.EnemySpawn }, band: number, rng: Rng.Source): { SpawnGroup }
	local groups: { SpawnGroup } = {}
	for _, spawn in spawns do
		local starts = math.max(1, spawn.minBand or 1)
		if starts == band then
			local count = rng:NextInteger(spawn.count.min, spawn.count.max)
			if count > 0 then
				table.insert(groups, { enemyId = spawn.enemyId, count = count })
			end
		end
	end
	return groups
end

return HollowAI
