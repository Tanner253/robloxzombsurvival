--!strict
--[[
	Gait: procedural motion for the wildlife rigs (LDOE_PARITY #35). The deer and the
	wolf have no animation clips; each frame this sets their joints' Transform from how
	fast the animal moves and what it is doing (Art.wildlifeRigs):

	- a four-beat walk that blends into a bounding run as the animal speeds up, the body
	  bobbing and the spine flexing with the stride;
	- an idle that breathes, looks about and (deer) drops its head to graze;
	- cues: a bite (lunge, jaw open), a flinch when hit, and a fall onto its side on death.

	Joint frames are the rig's rest axes (X across the body, Y up, -Z forward), so a
	positive pitch swings a leg forward or lifts the head.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Art)

local Gait = {}

local TAU = math.pi * 2
local WALK_SWING, RUN_SWING = 0.32, 0.62 -- radians at the shoulder and hip
local WALK_FOLD, RUN_FOLD = 0.55, 0.95
local RUN_FROM, RUN_FULL = 5, 12 -- studs per second: a walk below, a full run above
local FALL_SECONDS = 0.6

export type Rig = {
	profile: Art.WildlifeRig,
	motors: { [string]: Motor6D },
	coreHeight: number, -- the body joint's height above the feet
	phase: number,
	clock: number,
	speed: number, -- smoothed studs per second
	graze: number, -- 0 head up .. 1 feeding
	grazing: boolean,
	grazeUntil: number,
	cue: string?,
	cueAt: number,
	diedAt: number?,
	side: number, -- which side it falls on
	seed: number,
}

local function motorsOf(model: Model): { [string]: Motor6D }
	local found: { [string]: Motor6D } = {}
	for _, motor in model:GetDescendants() do
		if motor:IsA("Motor6D") then
			local part1 = motor.Part1
			if part1 then
				found[part1.Name] = motor
			end
		end
	end
	return found
end

function Gait.bind(model: Model, enemyId: string): Rig?
	local profile = Art.wildlifeRigs[enemyId]
	if profile == nil then
		return nil
	end
	local motors = motorsOf(model)
	local core = motors[profile.root]
	local coreHeight = 2
	if core and core.Part1 then
		coreHeight = math.max(core.Part1.Position.Y - model:GetPivot().Position.Y, 0.5)
	end
	local seed = math.random() * 100
	return {
		profile = profile,
		motors = motors,
		coreHeight = coreHeight,
		phase = math.random(),
		clock = 0,
		speed = 0,
		graze = 0,
		grazing = false,
		grazeUntil = 0,
		cue = nil,
		cueAt = 0,
		diedAt = nil,
		side = if math.random() < 0.5 then -1 else 1,
		seed = seed,
	}
end

function Gait.cue(rig: Rig, cue: string)
	if cue == "dead" then
		rig.diedAt = rig.clock
		return
	end
	rig.cue = cue
	rig.cueAt = rig.clock
end

local function set(rig: Rig, name: string?, cframe: CFrame)
	local motor = if name then rig.motors[name] else nil
	if motor then
		motor.Transform = cframe
	end
end

local function pitch(rig: Rig, name: string?, angle: number)
	set(rig, name, CFrame.Angles(angle, 0, 0))
end

-- A 0..1 envelope for a cue `length` seconds long: quick in, eased out.
local function envelope(rig: Rig, name: string, length: number): number
	if rig.cue ~= name then
		return 0
	end
	local t = (rig.clock - rig.cueAt) / length
	if t >= 1 then
		rig.cue = nil
		return 0
	end
	return math.sin(math.min(t * 4, 1) * math.pi / 2) * (1 - t * t)
end

local function fall(rig: Rig)
	local profile = rig.profile
	local t = math.clamp((rig.clock - (rig.diedAt :: number)) / FALL_SECONDS, 0, 1)
	local eased = 1 - (1 - t) ^ 3
	-- Onto its side: the body rolls a quarter turn and drops to lie on the ground.
	set(
		rig,
		profile.root,
		CFrame.new(0, -(rig.coreHeight * 0.72) * eased, 0) * CFrame.Angles(0, 0, rig.side * math.pi / 2 * eased)
	)
	for index, leg in profile.legs do
		local limp = (math.noise(index, rig.seed) * 0.3 + 0.25) * eased
		for joint, name in leg.joints do
			pitch(rig, name, if joint == 1 then limp else -limp * 0.4)
		end
	end
	for index, name in profile.neck do
		pitch(rig, name, -0.12 * index * eased)
	end
	pitch(rig, profile.jaw, -0.2 * eased)
end

-- One frame. `speed` is how fast the animal is moving over the ground (studs/s); `state`
-- is the brain's (idle, wander, alert, chase, attack, flee, dead).
function Gait.step(rig: Rig, dt: number, speed: number, state: string)
	rig.clock += dt
	if rig.diedAt then
		fall(rig)
		return
	end
	local profile = rig.profile
	rig.speed += (speed - rig.speed) * math.min(dt * 6, 1)
	local moving = rig.speed > 0.6
	local run = math.clamp((rig.speed - RUN_FROM) / (RUN_FULL - RUN_FROM), 0, 1)
	local stride = profile.stride * (1 + run * 1.4)
	rig.phase = (rig.phase + dt * rig.speed / stride) % 1
	local swingAmp = (WALK_SWING + (RUN_SWING - WALK_SWING) * run) * math.clamp(rig.speed / 2, 0, 1)
	local foldAmp = (WALK_FOLD + (RUN_FOLD - WALK_FOLD) * run) * math.clamp(rig.speed / 2, 0, 1)

	-- Legs: each swings on its own beat and folds while its foot is off the ground.
	for _, leg in profile.legs do
		local offset = leg.walk + (leg.run - leg.walk) * run
		local angle = (rig.phase + offset) * TAU
		local swing = math.sin(angle)
		local lift = math.max(0, math.cos(angle))
		for joint, name in leg.joints do
			local a = (leg.swing[joint] or 0) * swing * swingAmp + (leg.fold[joint] or 0) * lift * foldAmp
			pitch(rig, name, a)
		end
	end

	-- The body: a bob twice a stride at a walk, a rocking bound at a run; a lunge on a
	-- bite and a flinch when hit.
	local bite = envelope(rig, "attack", 0.45)
	local flinch = envelope(rig, "hit", 0.35)
	local bob = math.sin(rig.phase * TAU * 2) * 0.05 * (1 - run) * swingAmp * 3 + math.sin(rig.phase * TAU) * 0.12 * run
	local rock = math.sin(rig.phase * TAU + math.pi / 2) * 0.07 * run
	local breathe = if moving then 0 else math.sin(rig.clock * 1.6) * 0.02
	set(
		rig,
		profile.root,
		CFrame.new(0, bob + breathe, -bite * 0.7)
			* CFrame.Angles(rock - bite * 0.12 - flinch * 0.1, 0, math.sin(rig.clock * 40) * flinch * 0.08)
	)
	pitch(rig, profile.spine, math.sin(rig.phase * TAU + math.pi) * 0.12 * run)

	-- Head and neck: nod with the stride, reach out on the run, look about when idle,
	-- graze now and then (deer), lower to bite (wolf).
	local idle = not moving and state ~= "attack" and state ~= "chase"
	local canGraze = profile.grazes and idle and state ~= "alert"
	if canGraze and rig.clock > rig.grazeUntil then
		-- Feed for a few seconds, look up for a few.
		rig.grazing = not rig.grazing
		rig.grazeUntil = rig.clock + (if rig.grazing then 4 else 3) + (math.noise(rig.clock * 0.1, rig.seed) + 0.5) * 3
	end
	local target = if canGraze and rig.grazing then 1 else 0
	rig.graze += (target - rig.graze) * math.min(dt * 1.8, 1)
	local look = if idle then math.noise(rig.clock * 0.25, rig.seed) * 0.7 else 0
	local alertLift = if state == "alert" then 0.18 else 0
	for index, name in profile.neck do
		local nod = math.sin(rig.phase * TAU * 2 + index * 0.4) * 0.05 * swingAmp * 3
		local reach = -0.12 * run
		local feed = -rig.graze * (if index == 1 then 0.75 elseif index == 2 then 0.35 else 0.15)
		local bow = -bite * (if index == 1 then 0.25 else 0.1)
		local turn = if index == 2 or index == 3 then look * 0.5 else 0
		set(rig, name, CFrame.Angles(nod + reach + feed + bow + alertLift / #profile.neck, turn, 0))
	end
	pitch(rig, profile.jaw, -bite * 0.5 - rig.graze * 0.08 * (math.sin(rig.clock * 5) + 1))

	-- Ears flick now and then; the tail sways, and streams out on the run.
	if profile.ears then
		for index, name in profile.ears do
			local flick = math.max(0, math.noise(rig.clock * 0.9, rig.seed + index * 7) - 0.3) * 1.2
			set(rig, name, CFrame.Angles(0, (if index == 1 then 1 else -1) * flick * 0.5, 0))
		end
	end
	if profile.tail then
		for index, name in profile.tail do
			local sway = math.sin(rig.clock * (1.4 + run * 3) - index * 0.55) * (0.1 + 0.06 * index / #profile.tail)
			local lift = if index == 1 then 0.35 * run else 0.05 * run
			set(rig, name, CFrame.Angles(lift, sway, 0))
		end
	end
end

return Gait
