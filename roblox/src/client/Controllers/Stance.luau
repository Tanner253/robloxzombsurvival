--!strict
--[[
	Stance: the body while fighting on the move (LDoE: the upper body turns to the target, the
	legs keep running where the stick points). Domain/Facing decides; this applies it each frame.

	- Stance.engage(yaw): an attack toward `yaw` (a shot, a swing, a throw's or a bow's aim).
	  The stance holds LINGER seconds after the last one; Stance.aim(yaw) follows the aim
	  meanwhile without extending it. Stance.pause(seconds): a roll owns the body.
	- The local survivor in stance: Humanoid.AutoRotate is off and the root turns, eased
	  (Facing.turn), to Facing.solve's facing; out of stance AutoRotate is back on.
	- Every survivor this client draws:
	  * the waist joint turns the chest onto the aim (Facing.waistFor), blended in and out over
	    0.15 s, on top of whatever the clips posed (written after the Animator, before physics);
	    another survivor's aim is the yaw of their last shot or swing (Stance.remoteAim);
	  * the legs' cycle from the movement against the facing (Facing.gaitOf): the rig's own run
	    when forward, else the strafe or backpedal cycle at Facing.legRate for the ground speed,
	    cross-faded over 0.15 s. Swings, recoil and reloads stay above the waist (Clips' mask),
	    so the legs never freeze under them.
	- Stance.read(): the local survivor's numbers for scripted checks (Diagnostics "stance").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Facing = require(ReplicatedStorage.Shared.Domain.Facing)
local Clips = require("../Clips")

local Stance = {}

local LINGER = 0.6 -- seconds the stance holds after the last attack
local MOVING = 1.5 -- studs per second: slower is standing
local LEG_PRIORITY = Enum.AnimationPriority.Action -- over the rig's walk, under every action

local player = Players.LocalPlayer

type Body = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	waist: Instance?, -- the Waist AnimationConstraint (or Motor6D)
	gait: Facing.Gait,
	solveGait: Facing.Gait?,
	legName: string?,
	legTrack: AnimationTrack?,
	weight: number, -- the stance blend, 0..1
	twist: number, -- the waist turn written last frame (radians)
	aimYaw: number?,
	aimUntil: number,
	written: CFrame?,
	base: CFrame?,
	speed: number,
	rate: number,
}

local bodies: { [Model]: Body } = {}
local lingerUntil = 0
local pausedUntil = 0
local localAim: number? = nil
local ownsRotate = false

local function yawOfLook(look: Vector3): number
	return Facing.yawOf(look.X, look.Z)
end

local function bodyOf(character: Model?): Body?
	if character == nil then
		return nil
	end
	local found = bodies[character]
	if found and found.root.Parent and found.humanoid.Parent then
		return found
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local upper = character:FindFirstChild("UpperTorso")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	local waist = if upper then upper:FindFirstChild("Waist") else nil
	local made: Body = {
		character = character,
		humanoid = humanoid,
		root = root,
		waist = waist,
		gait = "idle",
		solveGait = nil,
		legName = nil,
		legTrack = nil,
		weight = 0,
		twist = 0,
		aimYaw = nil,
		aimUntil = 0,
		written = nil,
		base = nil,
		speed = 0,
		rate = 0,
	}
	bodies[character] = made
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			bodies[character] = nil
		end
	end)
	return made
end

function Stance.engage(yaw: number)
	localAim = yaw
	lingerUntil = os.clock() + LINGER
end

function Stance.aim(yaw: number)
	if os.clock() < lingerUntil then
		localAim = yaw
	end
end

function Stance.engaged(): boolean
	return os.clock() < lingerUntil and os.clock() >= pausedUntil
end

function Stance.pause(seconds: number)
	pausedUntil = os.clock() + seconds
end

-- Another survivor's shot or swing toward `yaw`: their chest turns to it for a moment.
function Stance.remoteAim(character: Model?, yaw: number)
	local body = bodyOf(character)
	if body then
		body.aimYaw = yaw
		body.aimUntil = os.clock() + LINGER + 0.3
	end
end

-- The legs: the cycle for the movement against the facing, at the ground's speed.
local function stepLegs(body: Body, mine: boolean)
	local velocity = body.root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flat.Magnitude
	local moveYaw = if speed > MOVING then Facing.yawOf(flat.X, flat.Z) else nil
	local gait = Facing.gaitOf(moveYaw, yawOfLook(body.root.CFrame.LookVector), body.gait)
	if body.humanoid.Sit or body.humanoid.Health <= 0 then
		gait = "idle"
	end
	body.speed = speed
	if gait ~= body.gait then
		body.gait = gait
		local name = Facing.LEG_CLIPS[gait]
		if body.legTrack and body.legName ~= name then
			body.legTrack:Stop(Facing.BLEND_SECONDS)
			body.legTrack, body.legName = nil, nil
		end
		if name then
			local track = Clips.track(body.character, name, mine)
			if track then
				track.Priority = LEG_PRIORITY
				track:Play(Facing.BLEND_SECONDS, 1, Facing.legRate(gait, speed) or 1)
				body.legTrack, body.legName = track, name
			end
		end
	end
	local rate = Facing.legRate(gait, speed)
	if body.legTrack and rate then
		body.legTrack:AdjustSpeed(rate)
		body.rate = rate
	else
		body.rate = 0
	end
end

-- The waist: turn the chest by `twist` on top of the clips' pose. When nothing animated the
-- joint since the last write, its Transform is still ours: start again from the clips' pose.
local function writeWaist(body: Body, twist: number)
	local joint = body.waist :: any
	if joint == nil then
		return
	end
	local current: CFrame = joint.Transform
	if body.written and body.base and current:FuzzyEq(body.written, 1e-5) then
		current = body.base
	end
	body.twist = twist
	if math.abs(twist) < 1e-4 then
		if body.written then
			joint.Transform = current -- hand the joint back as the clips posed it
		end
		body.written, body.base = nil, nil
		return
	end
	local out = CFrame.Angles(0, twist, 0) * current
	joint.Transform = out
	body.base, body.written = current, out
end

local function stepLocal(body: Body, dt: number)
	local now = os.clock()
	local engaged = now < lingerUntil and now >= pausedUntil and localAim ~= nil and body.humanoid.Health > 0
	local root = body.root
	local rootYaw = yawOfLook(root.CFrame.LookVector)
	if engaged then
		local move = body.humanoid.MoveDirection
		local moveYaw = if move.Magnitude > 0.1 then Facing.yawOf(move.X, move.Z) else nil
		local solved = Facing.solve(moveYaw, localAim :: number, body.solveGait)
		body.solveGait = solved.gait
		if body.humanoid.AutoRotate then
			body.humanoid.AutoRotate = false
		end
		ownsRotate = true
		rootYaw = Facing.turn(rootYaw, solved.rootYaw, dt)
		local at = root.Position
		root.CFrame = CFrame.lookAt(at, at + Vector3.new(math.sin(rootYaw), 0, math.cos(rootYaw)))
	else
		body.solveGait = nil
		if ownsRotate then
			ownsRotate = false
			body.humanoid.AutoRotate = true
		end
	end
	body.weight = Facing.blend(body.weight, engaged, dt)
	local aimYaw = localAim or rootYaw
	writeWaist(body, Facing.waistFor(rootYaw, aimYaw) * body.weight)
end

local function stepOther(body: Body, dt: number)
	local now = os.clock()
	local engaged = body.aimYaw ~= nil and now < body.aimUntil
	body.weight = Facing.blend(body.weight, engaged, dt)
	local rootYaw = yawOfLook(body.root.CFrame.LookVector)
	writeWaist(body, Facing.waistFor(rootYaw, body.aimYaw or rootYaw) * body.weight)
end

local function step(dt: number)
	for _, other in Players:GetPlayers() do
		local body = bodyOf(other.Character)
		if body then
			local mine = other == player
			if mine then
				stepLocal(body, dt)
			else
				stepOther(body, dt)
			end
			stepLegs(body, mine)
		end
	end
end

-- For scripted checks: the local survivor's facing, waist, legs and speeds (degrees, studs/s).
function Stance.read(): { [string]: any }
	local body = bodyOf(player.Character)
	if body == nil then
		return { error = "no body" }
	end
	local root = body.root
	local rootYaw = yawOfLook(root.CFrame.LookVector)
	local lower = body.character:FindFirstChild("LowerTorso") :: BasePart?
	local upper = body.character:FindFirstChild("UpperTorso") :: BasePart?
	local chest = if lower and upper
		then Facing.diff(yawOfLook(lower.CFrame.LookVector), yawOfLook(upper.CFrame.LookVector))
		else 0
	local speed = Facing.footSpeed(body.gait)
	local legPlaying = body.legTrack ~= nil and body.legTrack.IsPlaying
	local deg = 180 / math.pi
	return {
		engaged = Stance.engaged(),
		autoRotate = body.humanoid.AutoRotate,
		rootYaw = math.round(rootYaw * deg),
		aimYaw = if localAim then math.round(localAim * deg) else nil,
		waist = math.round(body.twist * deg * 10) / 10, -- the turn written on the waist joint
		chest = math.round(chest * deg * 10) / 10, -- measured: upper against lower torso
		weight = math.round(body.weight * 100) / 100,
		gait = body.gait,
		legs = if legPlaying then body.legName else "rig walk/idle",
		legWeight = if legPlaying and body.legTrack then math.round(body.legTrack.WeightCurrent * 100) / 100 else 0,
		groundSpeed = math.round(body.speed * 10) / 10,
		legSpeed = if legPlaying
				and speed
				and body.legTrack
			then math.round(body.legTrack.Speed * speed * 10) / 10
			else nil,
	}
end

function Stance.start()
	RunService.PreSimulation:Connect(step)
end

return Stance
