--!strict
--[[
	Animations: the survivor's action animations, as custom keyframes built in code
	(ART_DIRECTION §6: never Roblox defaults). Each is a KeyframeSequence registered at
	runtime with AnimationClipProvider, so no animation asset has to be published.

	- chop: a diagonal overhead swing (anticipation, hit, recovery)
	- mine: a vertical overhead swing
	- pickup: crouch, reach and grab
	- eat: hand to mouth twice

	The local player's swings start immediately on input; everyone else's play when
	the server's "act" effect arrives, so all players see each other work.
	`Animations.hitDelay(kind)` is when the hit frame lands, for timing impacts.
]]

local Players = game:GetService("Players")
local AnimationClipProvider = game:GetService("AnimationClipProvider")

local State = require("../State")

local Animations = {}

type Spec = {
	length: number,
	hit: number, -- seconds to the hit frame
	keys: { { time: number, poses: { [string]: CFrame } } },
}

local function deg(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
end

-- Pose hierarchy of the R15 survivor (parents first).
local PARENTS: { [string]: string } = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	Head = "UpperTorso",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
}

local SPECS: { [string]: Spec } = {
	chop = {
		length = 0.62,
		hit = 0.3,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.2,
				poses = {
					UpperTorso = deg(6, 28, 0),
					RightUpperArm = deg(165, 0, 25),
					RightLowerArm = deg(35),
					LeftUpperArm = deg(20, 0, -10),
				},
			},
			{
				time = 0.3,
				poses = {
					UpperTorso = deg(-12, -22, 0),
					RightUpperArm = deg(62, 0, -30),
					RightLowerArm = deg(8),
					RightHand = deg(-70),
					LeftUpperArm = deg(-10, 0, -8),
				},
			},
			{
				time = 0.36,
				poses = { UpperTorso = deg(-10, -20, 0), RightUpperArm = deg(58, 0, -28), RightHand = deg(-65) },
			},
			{ time = 0.62, poses = {} },
		},
	},
	mine = {
		length = 0.66,
		hit = 0.32,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.22,
				poses = {
					UpperTorso = deg(12, 0, 0),
					RightUpperArm = deg(175, 0, 8),
					RightLowerArm = deg(25),
					LeftUpperArm = deg(150, 0, -10),
					LeftLowerArm = deg(25),
				},
			},
			{
				time = 0.32,
				poses = {
					UpperTorso = deg(-24, 0, 0),
					RightUpperArm = deg(55, 0, -4),
					RightLowerArm = deg(5),
					RightHand = deg(-80),
					LeftUpperArm = deg(40, 0, 6),
				},
			},
			{
				time = 0.38,
				poses = { UpperTorso = deg(-22, 0, 0), RightUpperArm = deg(52, 0, -4), RightHand = deg(-75) },
			},
			{ time = 0.66, poses = {} },
		},
	},
	pickup = {
		length = 0.7,
		hit = 0.32,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.25,
				poses = {
					LowerTorso = CFrame.new(0, -1.1, 0.2) * deg(-10),
					UpperTorso = deg(-38),
					RightUpperLeg = deg(75),
					RightLowerLeg = deg(-95),
					LeftUpperLeg = deg(55),
					LeftLowerLeg = deg(-100),
					RightUpperArm = deg(55, 0, -10),
					RightLowerArm = deg(10),
					Head = deg(-15),
				},
			},
			{
				time = 0.38,
				poses = {
					LowerTorso = CFrame.new(0, -1.1, 0.2) * deg(-10),
					UpperTorso = deg(-36),
					RightUpperLeg = deg(75),
					RightLowerLeg = deg(-95),
					LeftUpperLeg = deg(55),
					LeftLowerLeg = deg(-100),
					RightUpperArm = deg(35, 0, -5),
					RightLowerArm = deg(40),
				},
			},
			{ time = 0.7, poses = {} },
		},
	},
	eat = {
		length = 1.1,
		hit = 0.35,
		keys = {
			{ time = 0, poses = {} },
			{ time = 0.25, poses = { RightUpperArm = deg(70, 0, 15), RightLowerArm = deg(115), Head = deg(-8) } },
			{ time = 0.5, poses = { RightUpperArm = deg(60, 0, 15), RightLowerArm = deg(95), Head = deg(-4) } },
			{ time = 0.75, poses = { RightUpperArm = deg(70, 0, 15), RightLowerArm = deg(115), Head = deg(-8) } },
			{ time = 1.1, poses = {} },
		},
	},
}

local clips: { [string]: Animation } = {}
local tracks: { [Animator]: { [string]: AnimationTrack } } = {}

local function build(spec: Spec): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Loop = false
	sequence.Priority = Enum.AnimationPriority.Action4
	for _, key in spec.keys do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = key.time
		local made: { [string]: Pose } = {}
		local function poseFor(name: string): Pose
			local existing = made[name]
			if existing then
				return existing
			end
			local pose = Instance.new("Pose")
			pose.Name = name
			pose.Weight = if key.poses[name] then 1 else 0
			pose.CFrame = key.poses[name] or CFrame.identity
			pose.EasingStyle = Enum.PoseEasingStyle.Cubic
			pose.EasingDirection = Enum.PoseEasingDirection.Out
			local parentName = PARENTS[name]
			pose.Parent = if parentName then poseFor(parentName) else keyframe
			made[name] = pose
			return pose
		end
		poseFor("HumanoidRootPart").Weight = 0
		for name in PARENTS do
			poseFor(name)
		end
		keyframe.Parent = sequence
	end
	return sequence
end

local function clip(name: string): Animation?
	local existing = clips[name]
	if existing then
		return existing
	end
	local spec = SPECS[name]
	if spec == nil then
		return nil
	end
	local ok, id = pcall(AnimationClipProvider.RegisterAnimationClip, AnimationClipProvider, build(spec))
	if not ok then
		warn(`Animations: could not register '{name}': {id}`)
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	clips[name] = animation
	return animation
end

local function animatorOf(character: Model?): Animator?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil and character == Players.LocalPlayer.Character then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	return animator
end

-- Plays an action on a character. Returns seconds until its hit frame.
function Animations.play(character: Model?, name: string, speed: number?): number
	local animator = animatorOf(character)
	local animation = clip(name)
	local spec = SPECS[name]
	if animator == nil or animation == nil or spec == nil then
		return 0
	end
	local perAnimator = tracks[animator]
	if perAnimator == nil then
		perAnimator = {}
		tracks[animator] = perAnimator
		animator.AncestryChanged:Connect(function()
			if not animator:IsDescendantOf(game) then
				tracks[animator] = nil
			end
		end)
	end
	local track: AnimationTrack? = perAnimator[name]
	if track == nil then
		local loaded = animator:LoadAnimation(animation)
		loaded.Priority = Enum.AnimationPriority.Action4
		perAnimator[name] = loaded
		track = loaded
	end
	local rate = speed or 1
	(track :: AnimationTrack):Play(0.06, 1, rate)
	return spec.hit / rate
end

-- Seconds from the start of an action to its hit frame.
function Animations.hitDelay(name: string): number
	local spec = SPECS[name]
	return if spec then spec.hit else 0
end

-- The action for a node's tool kind.
function Animations.forTool(kind: string?): string
	return if kind == "hatchet" then "chop" elseif kind == "pick" then "mine" else "pickup"
end

function Animations.start()
	-- Other players' actions arrive from the server; the local player's play on input.
	State.fx:Connect(function(kind: any, payload: any)
		if kind == "act" and payload.userId ~= Players.LocalPlayer.UserId then
			local other = Players:GetPlayerByUserId(payload.userId)
			Animations.play(if other then other.Character else nil, payload.action)
		end
	end)
end

return Animations
