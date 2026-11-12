--!strict
--[[
	SurvivorView: the survivor's own model in the inventory's survivor pane, standing between
	the gear slots as LDoE stands its survivor there (LDOE_PARITY #13-14). It is a copy of the
	live character, so worn armour tints, headwear and bags show as they are, playing the
	character's own idle loop in a WorldModel, turned three-quarters toward the key light.
	Copied again when `look` (the worn gear) changes or the character respawns.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

export type Props = {
	look: string, -- the worn gear's signature: a change re-copies the survivor
	size: UDim2?,
	layoutOrder: number?,
}

local FOV = 26
local TURN = math.rad(-22) -- three-quarters, the lit side to the camera
local MARGIN = 1.06
local AMBIENT = Color3.fromRGB(140, 132, 124)
local LIGHT = Color3.fromRGB(255, 246, 232)
-- Key light from the upper left and in front (the icon style's direction, ART_DIRECTION §8).
local LIGHT_DIRECTION = Vector3.new(0.55, -0.7, -0.45).Unit
-- Worn gear reaches the character a moment after the inventory changes (the server welds it).
local SETTLE_SECONDS = 0.35

-- Nothing that runs, sounds, glows or floats a label goes into the copy.
local STRIP = {
	"BaseScript",
	"ModuleScript",
	"Sound",
	"BillboardGui",
	"SurfaceGui",
	"ParticleEmitter",
	"Light",
	"ForceField",
	"Beam",
	"Trail",
	"ProximityPrompt",
	"IKControl",
}

local function copyOf(character: Model): Model?
	local archivable = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function(): Model?
		return character:Clone()
	end)
	character.Archivable = archivable
	if not ok or not copy then
		return nil
	end
	local model: Model = copy
	for _, descendant in model:GetDescendants() do
		for _, class in STRIP do
			if descendant:IsA(class) then
				descendant:Destroy()
				break
			end
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.LocalTransparencyModifier = 0
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	return model
end

-- The character's own idle (its Animate script's "idle" loop), so the copy stands as it does.
local function idleOf(character: Model): Animation?
	local animate = character:FindFirstChild("Animate")
	local idle = animate and animate:FindFirstChild("idle")
	if idle then
		for _, child in idle:GetChildren() do
			if child:IsA("Animation") and child.AnimationId ~= "" then
				return child
			end
		end
	end
	return nil
end

local function SurvivorView(props: Props)
	local frameRef = React.useRef(nil :: ViewportFrame?)
	local player = Players.LocalPlayer
	local character, setCharacter = React.useState(player and player.Character)

	React.useEffect(function()
		if player == nil then
			return function() end
		end
		local added = player.CharacterAdded:Connect(setCharacter)
		return function()
			added:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local frame = frameRef.current
		if frame == nil or character == nil then
			return function() end
		end
		local live = true
		local world: WorldModel? = nil
		local camera: Camera? = nil
		task.delay(SETTLE_SECONDS, function()
			if not live or character.Parent == nil then
				return
			end
			local copy = copyOf(character)
			if copy == nil then
				return
			end
			copy:PivotTo(CFrame.Angles(0, math.pi + TURN, 0))
			local box, size = copy:GetBoundingBox()
			local absolute = frame.AbsoluteSize
			local aspect = if absolute.X > 0 and absolute.Y > 0 then absolute.X / absolute.Y else 0.7
			local tanV = math.tan(math.rad(FOV / 2))
			local distance = size.Z / 2
				+ math.max(size.Y / 2 / tanV, math.max(size.X, size.Z) / 2 / (tanV * aspect)) * MARGIN
			local centre = box.Position
			local cam = Instance.new("Camera")
			cam.FieldOfView = FOV
			cam.CFrame = CFrame.lookAt(centre + Vector3.new(0, size.Y * 0.04, distance), centre)
			cam.Parent = frame
			frame.CurrentCamera = cam
			local made = Instance.new("WorldModel")
			copy.Parent = made
			made.Parent = frame
			world, camera = made, cam
			local idle = idleOf(character)
			local humanoid = copy:FindFirstChildOfClass("Humanoid")
			if idle and humanoid then
				local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
				animator.Parent = humanoid
				local ok, track = pcall(function()
					return animator:LoadAnimation(idle)
				end)
				if ok and track then
					track.Looped = true
					track:Play(0)
				end
			end
		end)
		return function()
			live = false
			if world then
				world:Destroy()
			end
			if camera then
				camera:Destroy()
			end
		end
	end, { character, props.look } :: { any })

	return React.createElement("ViewportFrame", {
		ref = frameRef,
		Size = props.size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = AMBIENT,
		LightColor = LIGHT,
		LightDirection = LIGHT_DIRECTION,
		LayoutOrder = props.layoutOrder,
	})
end

return SurvivorView
