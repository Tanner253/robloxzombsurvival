--!strict
--[[
	Clips: builds the survivor's animation clips from Data/Holds and plays them on any
	character (ART_DIRECTION §6: custom keyframes, never Roblox defaults). Each clip is a
	KeyframeSequence registered at runtime with AnimationClipProvider, so no animation
	asset has to be published. A clip that names a Universal Animation Library clip (CC0,
	Data/UalClips) is retargeted onto the rig's joints instead, once they are known.

	- Clips.play(character, name, speed?, priority?) -> the track (or nil)
	- Clips.stop(character, name, fade?)
	- Clips.hit(name): seconds to the clip's hit frame at play rate 1.

	Carry clips loop under everything (Action); swings, stances and the rest play over them
	(Action2) unless the caller asks for more.
]]

local AnimationClipProvider = game:GetService("AnimationClipProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Holds = require(ReplicatedStorage.Shared.Data.Holds)
local UalClips = require(ReplicatedStorage.Shared.Data.UalClips)

local Clips = {}

local PARENTS = Holds.PARENTS
local UAL_PARENTS: { [string]: string } = table.clone(PARENTS)
UAL_PARENTS.RightFoot = "RightLowerLeg"
UAL_PARENTS.LeftFoot = "LeftLowerLeg"

local function toCFrame(p: Holds.Pose): CFrame
	local turn = CFrame.Angles(math.rad(p[1]), math.rad(p[2]), math.rad(p[3]))
	if p[4] then
		return CFrame.new(p[4], p[5], p[6]) * turn
	end
	return turn
end

--[[
	Each joint's rest frame in character space, read from the rig (AnimationConstraint
	attachments, or Motor6D C0 and C1). UAL rotations are in character space; a joint
	takes one as J^-1 * D * J. nil when the rig lacks a part UAL drives.
]]
local function jointFrames(character: Model): { [string]: CFrame }?
	local parentOf: { [string]: string } = {}
	local near: { [string]: CFrame } = {}
	local far: { [string]: CFrame } = {}
	for _, joint in character:GetDescendants() do
		if joint:IsA("AnimationConstraint") then
			local a0, a1 = joint.Attachment0, joint.Attachment1
			if a0 and a1 and a0.Parent and a1.Parent then
				local child = (a1.Parent :: Instance).Name
				parentOf[child] = (a0.Parent :: Instance).Name
				near[child] = a0.CFrame.Rotation
				far[child] = a1.CFrame.Rotation
			end
		elseif joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			local child = (joint.Part1 :: BasePart).Name
			parentOf[child] = (joint.Part0 :: BasePart).Name
			near[child] = joint.C0.Rotation
			far[child] = joint.C1.Rotation
		end
	end
	local rest: { [string]: CFrame } = { HumanoidRootPart = CFrame.identity }
	local frames: { [string]: CFrame } = {}
	local function restOf(name: string, depth: number): CFrame?
		if rest[name] then
			return rest[name]
		end
		local parentName = parentOf[name]
		local parentRest = if parentName and depth < 12 then restOf(parentName, depth + 1) else nil
		if parentRest == nil then
			return nil
		end
		frames[name] = parentRest * near[name]
		rest[name] = frames[name] * far[name]:Inverse()
		return rest[name]
	end
	for _, part in UalClips.PARTS do
		if restOf(part, 0) == nil then
			return nil
		end
	end
	return frames
end

local function buildUal(name: string, loop: boolean, frames: { [string]: CFrame }): KeyframeSequence
	local source = UalClips.clips[name]
	local sequence = Instance.new("KeyframeSequence")
	sequence.Loop = loop
	sequence.Priority = Enum.AnimationPriority.Action2
	for _, key in source.keys do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = key.t
		local made: { [string]: Pose } = {}
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		root.Parent = keyframe
		made.HumanoidRootPart = root
		local values: { [string]: { number } } = {}
		for index, part in UalClips.PARTS do
			values[part] = key.p[index]
		end
		local function poseFor(part: string): Pose
			if made[part] then
				return made[part]
			end
			local v = values[part]
			local frame = frames[part]
			local turn = CFrame.new(0, 0, 0, v[1], v[2], v[3], v[4])
			local cframe = frame:Inverse() * turn * frame
			if v[5] then
				cframe = CFrame.new(frame:Inverse() * Vector3.new(v[5], v[6], v[7])) * cframe
			end
			local pose = Instance.new("Pose")
			pose.Name = part
			pose.CFrame = cframe
			pose.Parent = poseFor(UAL_PARENTS[part])
			made[part] = pose
			return pose
		end
		for _, part in UalClips.PARTS do
			poseFor(part)
		end
		keyframe.Parent = sequence
	end
	return sequence
end

-- Keyed clips. A partial clip leaves every part it doesn't name to what plays beneath;
-- a full one holds those parts at rest.
local function build(clip: Holds.Clip): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Loop = clip.loop == true
	sequence.Priority = Enum.AnimationPriority.Action2
	for _, key in clip.keys do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = key.time
		local made: { [string]: Pose } = {}
		local function poseFor(name: string): Pose
			if made[name] then
				return made[name]
			end
			local pose = Instance.new("Pose")
			pose.Name = name
			local posed = key.poses[name]
			pose.CFrame = if posed then toCFrame(posed) else CFrame.identity
			if clip.partial and not posed then
				pose.Weight = 0
			end
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

local animations: { [string]: Animation } = {}
local ualFrames: { [string]: CFrame }? = nil

local function animation(name: string, character: Model?): Animation?
	if animations[name] then
		return animations[name]
	end
	local clip = Holds.clips[name]
	if clip == nil then
		return nil
	end
	if clip.ual and ualFrames == nil and character then
		ualFrames = jointFrames(character)
	end
	local sequence = if clip.ual
			and ualFrames
			and UalClips.clips[clip.ual]
		then buildUal(clip.ual, clip.loop == true, ualFrames)
		else build(clip)
	local ok, id = pcall(AnimationClipProvider.RegisterAnimationClip, AnimationClipProvider, sequence)
	if not ok then
		warn(`Clips: could not register '{name}': {id}`)
		return nil
	end
	local made = Instance.new("Animation")
	made.AnimationId = id
	animations[name] = made
	return made
end

local loaded: { [Animator]: { [string]: AnimationTrack } } = {}

local function animatorOf(character: Model?, make: boolean?): Animator?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil and make then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end
	return animator
end

local function trackOf(character: Model?, name: string, make: boolean?): AnimationTrack?
	local animator = animatorOf(character, make)
	if animator == nil then
		return nil
	end
	local tracks = loaded[animator]
	if tracks == nil then
		tracks = {}
		loaded[animator] = tracks
		animator.AncestryChanged:Connect(function()
			if not animator:IsDescendantOf(game) then
				loaded[animator] = nil
			end
		end)
	end
	local track: AnimationTrack? = tracks[name]
	if not track then
		local source = animation(name, character)
		if source == nil then
			return nil
		end
		local ok, made = pcall(animator.LoadAnimation, animator, source)
		if not ok then
			return nil
		end
		track = made
		tracks[name] = made
	end
	return track
end

function Clips.play(
	character: Model?,
	name: string,
	speed: number?,
	priority: Enum.AnimationPriority?,
	make: boolean?
): AnimationTrack?
	local track = trackOf(character, name, make)
	if track == nil then
		return nil
	end
	local clip = Holds.clips[name]
	track.Priority = priority
		or (if string.sub(name, 1, 5) == "carry" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Action2)
	track:Play(if clip and clip.loop then 0.2 else 0.06, 1, speed or 1)
	return track
end

function Clips.stop(character: Model?, name: string, fade: number?)
	local animator = animatorOf(character)
	local tracks = animator and loaded[animator]
	local track = tracks and tracks[name]
	if track and track.IsPlaying then
		track:Stop(fade or 0.15)
	end
end

function Clips.playing(character: Model?, name: string): boolean
	local animator = animatorOf(character)
	local tracks = animator and loaded[animator]
	local track = tracks and tracks[name]
	return track ~= nil and track.IsPlaying
end

function Clips.hit(name: string): number
	local clip = Holds.clips[name]
	return if clip and clip.hit then clip.hit else 0
end

return Clips
