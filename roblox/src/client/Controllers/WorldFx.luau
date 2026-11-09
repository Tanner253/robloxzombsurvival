--!strict
--[[
	WorldFx: the world's game feel (ART_DIRECTION.md §1, "juice"). Everything
	here is local and cosmetic; the server already decided the outcome.

	- Gathering: a camera jolt and chips on every swing; the node wobbles; "+1
	  Timber" and "+10 XP" float up; a depleted tree topples, rocks crumble,
	  bushes shrink; respawned nodes grow back with a bounce.
	- Building: a placed piece drops into place with a bounce and a dust puff;
	  demolished pieces burst into debris.
	- Stations: the Campfire burns while fuelled; a station with finished jobs
	  shows a bobbing ready badge.
	- Doors on your own plot swing open as you approach (and let only you through).
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Content = require(ReplicatedStorage.Shared.Data)
local Sfx = require("../Sfx")
local flyIcon = require("../UI/flyIcon")
local State = require("../State")
local Theme = require("../UI/theme")
local format = require("../UI/format")
local Camera = require("./Camera")

local WorldFx = {}

local player = Players.LocalPlayer

local CHIP_COLORS: { [string]: Color3 } = {
	hatchet = Color3.fromRGB(176, 128, 82),
	pick = Color3.fromRGB(150, 146, 138),
	hand = Color3.fromRGB(112, 128, 72),
}
-- Per node: the sound of each hit and of the node breaking (Art.sounds names).
local NODE_SOUNDS: { [string]: { hit: string, gone: string } } = {
	["node.fallen_branches"] = { hit = "pluck", gone = "bushBreak" },
	["node.loose_stones"] = { hit = "mine", gone = "rockBreak" },
	["node.reed_patch"] = { hit = "pluckGrass", gone = "bushBreak" },
	["node.ember_bush"] = { hit = "pluckGrass", gone = "bushBreak" },
	["node.ashroot_mound"] = { hit = "pluckGrass", gone = "bushBreak" },
	["node.spring_pool"] = { hit = "drink", gone = "bushBreak" },
	["node.pine_tree"] = { hit = "chop", gone = "treeFall" },
	["node.fatwood_stump"] = { hit = "chop", gone = "demolish" },
	["node.boulder"] = { hit = "mine", gone = "rockBreak" },
	["node.scrap_heap"] = { hit = "upgrade", gone = "rockBreak" },
}
local TOOL_SOUNDS: { [string]: { hit: string, gone: string } } = {
	hatchet = { hit = "chop", gone = "treeFall" },
	pick = { hit = "mine", gone = "rockBreak" },
	hand = { hit = "pluckGrass", gone = "bushBreak" },
}
local SNAP_SECONDS = 3 -- pieces placed within this long ago animate in
local DOOR_RADIUS = 7

-- Helpers ------------------------------------------------------------------------------------------

local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- Drives a model's scale and pivot from a 0..1 alpha (models can't be tweened directly).
local function animateModel(
	model: Model,
	seconds: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection,
	apply: (alpha: number) -> ()
): Tween
	local value = Instance.new("NumberValue")
	value.Value = 0
	value.Changed:Connect(function(alpha: number)
		if model.Parent then
			apply(alpha)
		end
	end)
	local t = TweenService:Create(value, TweenInfo.new(seconds, style, direction), { Value = 1 })
	t.Completed:Once(function()
		value:Destroy()
	end)
	t:Play()
	return t
end

local function chips(at: Vector3, color: Color3, count: number, material: Enum.Material?)
	for _ = 1, count do
		local chip = Instance.new("Part")
		chip.Size = Vector3.new(0.3, 0.18, 0.3) * (0.7 + math.random() * 0.8)
		chip.Color = color:Lerp(Color3.new(), math.random() * 0.25)
		chip.Material = material or Enum.Material.Wood
		chip.CanQuery = false
		chip.CastShadow = false
		chip.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		chip.Parent = workspace
		local spread = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit * (6 + math.random() * 8)
		chip.AssemblyLinearVelocity = spread + Vector3.new(0, 14 + math.random() * 10, 0)
		chip.AssemblyAngularVelocity = Vector3.new(math.random() * 20, math.random() * 20, math.random() * 20)
		task.delay(0.7, function()
			if chip.Parent then
				tween(chip, 0.5, { Transparency = 1, Size = chip.Size * 0.3 })
			end
		end)
		Debris:AddItem(chip, 1.3)
	end
end

local function puff(at: Vector3, color: Color3, amount: number, radius: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(radius * 2, 0.2, radius * 2)
	holder.Position = at
	holder.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.05
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 3.4),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(3, 7)
	emitter.SpreadAngle = Vector2.new(80, 80)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(amount)
	Debris:AddItem(holder, 1.5)
end

local function floatText(at: Vector3, text: string, color: Color3, delay: number?)
	task.delay(delay or 0, function()
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Position = at
		holder.Parent = workspace
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(200, 40)
		gui.StudsOffset = Vector3.new(0, 1, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = Theme.fonts.header
		label.Text = text
		label.TextSize = Theme.textSize.title
		label.TextColor3 = color
		label.TextStrokeColor3 = Theme.colors.shadow
		label.TextStrokeTransparency = 0.2
		local scale = Instance.new("UIScale")
		scale.Scale = 0.4
		scale.Parent = label
		label.Parent = gui
		gui.Parent = holder
		tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(gui, 1.2, { StudsOffset = Vector3.new(0, 4.5, 0) }, Enum.EasingStyle.Quad)
		task.delay(0.7, function()
			tween(label, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end)
		Debris:AddItem(holder, 1.3)
	end)
end

-- Nodes ---------------------------------------------------------------------------------------------

type NodeFx = { pivot: CFrame, scale: number, standing: boolean }
local nodeFx: { [Model]: NodeFx } = {}

local function setLocalVisible(model: Model, visible: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if visible then 0 else 1
		end
	end
end

local function fell(model: Model, info: NodeFx)
	local nodeId = model:GetAttribute("NodeId") :: string
	local def = Content.Nodes[nodeId]
	local tool = if def and def.tool then def.tool.kind else "hand"
	local base = info.pivot.Position
	Sfx.play((NODE_SOUNDS[nodeId] or TOOL_SOUNDS[tool] or TOOL_SOUNDS.hand).gone, base)
	if tool == "hatchet" then
		local axis = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
		local topple = CFrame.fromAxisAngle(axis:Cross(Vector3.yAxis), math.rad(84))
		animateModel(model, 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(alpha)
			model:PivotTo(info.pivot * CFrame.new():Lerp(topple, alpha))
		end).Completed:Once(function()
			puff(base + axis * 6, Color3.fromRGB(150, 132, 104), 18, 4)
			Camera.shake(0.35)
			task.delay(0.6, function()
				if model:GetAttribute("Standing") == false then
					setLocalVisible(model, false)
					model:PivotTo(info.pivot)
				end
			end)
		end)
	else
		puff(base + Vector3.new(0, 1, 0), CHIP_COLORS[tool] or CHIP_COLORS.hand, 14, 2)
		animateModel(model, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In, function(alpha)
			model:ScaleTo(info.scale * math.max(0.05, 1 - alpha))
			model:PivotTo(info.pivot)
		end).Completed:Once(function()
			if model:GetAttribute("Standing") == false then
				setLocalVisible(model, false)
				model:ScaleTo(info.scale)
				model:PivotTo(info.pivot)
			end
		end)
	end
end

local function regrow(model: Model, info: NodeFx)
	setLocalVisible(model, true)
	model:ScaleTo(info.scale * 0.05)
	model:PivotTo(info.pivot)
	animateModel(model, 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function(alpha)
		model:ScaleTo(info.scale * math.max(0.05, alpha))
		model:PivotTo(info.pivot)
	end)
end

local function watchNode(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	local info: NodeFx = {
		pivot = model:GetPivot(),
		scale = model:GetScale(),
		standing = model:GetAttribute("Standing") ~= false,
	}
	nodeFx[model] = info
	-- A well (Drains) keeps its basin while it refills; only its water goes.
	local water = if model:GetAttribute("Drains") then model:FindFirstChild("Water", true) :: BasePart? else nil
	if not info.standing then
		if water then
			water.LocalTransparencyModifier = 1
		else
			setLocalVisible(model, false)
		end
	end
	model:GetAttributeChangedSignal("Standing"):Connect(function()
		local standing = model:GetAttribute("Standing") ~= false
		if standing == info.standing then
			return
		end
		info.standing = standing
		if water then
			water.LocalTransparencyModifier = if standing then 0 else 1
		elseif standing then
			regrow(model, info)
		else
			fell(model, info)
		end
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			nodeFx[model] = nil
		end
	end)
end

local function wobble(model: Model)
	local info = nodeFx[model]
	if info == nil or not info.standing then
		return
	end
	local tilt = CFrame.Angles(math.rad(math.random(-6, 6)), 0, math.rad(math.random(-6, 6)))
	animateModel(model, 0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, function(alpha)
		if info.standing then
			model:PivotTo(info.pivot * CFrame.new():Lerp(tilt, math.sin(alpha * math.pi)))
		end
	end)
end

local function nodeByKey(key: string): Model?
	for _, instance in CollectionService:GetTagged("EO_Node") do
		if instance:GetAttribute("NodeKey") == key and instance:IsA("Model") then
			return instance
		end
	end
	return nil
end

local function onGather(payload: any)
	local model = nodeByKey(payload.key)
	if model == nil then
		return
	end
	if payload.personal then
		-- A personal lobby node: only this player's copy changed, so the attributes the
		-- server leaves untouched are set here, locally (a felled copy goes for us alone).
		model:SetAttribute("HitsLeft", payload.hitsLeft or 0)
		if payload.depleted then
			model:SetAttribute("Standing", false)
		end
	end
	local def = Content.Nodes[payload.nodeId]
	local tool = if def and def.tool then def.tool.kind else "hand"
	local top = model:GetPivot().Position + Vector3.new(0, math.min(model:GetExtentsSize().Y * 0.5, 4), 0)
	Sfx.play((NODE_SOUNDS[payload.nodeId] or TOOL_SOUNDS[tool] or TOOL_SOUNDS.hand).hit, top)
	if payload.broke then
		-- The tool snaps: a splinter burst at the survivor's hand.
		Sfx.play("toolBreak")
		local character = player.Character
		local hand = character and character:FindFirstChild("RightHand") :: BasePart?
		if hand then
			chips(hand.Position, CHIP_COLORS.hatchet, 10, Enum.Material.Wood)
			puff(hand.Position, Color3.fromRGB(150, 132, 104), 8, 1.2)
		end
	end
	for index, stack in payload.items or {} do
		flyIcon(stack.itemId, top, (index - 1) * 0.12)
	end
	chips(
		top,
		CHIP_COLORS[tool] or CHIP_COLORS.hand,
		if tool == "hand" then 4 else 7,
		if tool == "pick" then Enum.Material.Slate else Enum.Material.Wood
	)
	Camera.shake(if tool == "hand" then 0.08 else 0.18)
	if not payload.depleted then
		wobble(model)
	end
	for index, stack in payload.items or {} do
		local item = Content.Items[stack.itemId]
		local color = if item then Theme.rarity[item.rarity] or Theme.colors.text else Theme.colors.text
		floatText(
			top + Vector3.new(0, 1, 0),
			`+{stack.count} {if item then item.name else stack.itemId}`,
			color,
			(index - 1) * 0.12
		)
	end
	if (payload.xp or 0) > 0 then
		floatText(top + Vector3.new(1.5, 0, 0), `+{payload.xp} XP`, Theme.colors.accentSoft, 0.2)
	end
end

-- Pieces --------------------------------------------------------------------------------------------

local function snapIn(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	local placedAt = model:GetAttribute("PlacedAt")
	if type(placedAt) ~= "number" or placedAt <= 0 or State.now() - placedAt > SNAP_SECONDS then
		return
	end
	local final = model:GetPivot()
	local scale = model:GetScale()
	local _, size = model:GetBoundingBox()
	animateModel(model, 0.38, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, function(alpha)
		model:ScaleTo(scale * (1.06 - 0.06 * alpha))
		model:PivotTo(final * CFrame.new(0, (1 - alpha) * 3.5, 0))
	end).Completed:Once(function()
		model:ScaleTo(scale)
		model:PivotTo(final)
	end)
	task.delay(0.12, function()
		puff(final.Position + Vector3.new(0, 0.4, 0), Color3.fromRGB(168, 150, 120), 16, math.max(size.X, size.Z) / 2)
		Camera.shake(0.12)
	end)
	Sfx.play("place", final.Position)
end

local function onDebris(payload: any)
	for _, piece in payload.pieces or {} do
		local def = Content.BuildPieces[piece.pieceId]
		local tier = if def then def.tier else 1
		local color = if tier == 1
			then Color3.fromRGB(124, 88, 60)
			elseif tier == 2 then Color3.fromRGB(118, 100, 88)
			else Color3.fromRGB(122, 120, 116)
		local at = (piece.cframe :: CFrame).Position + Vector3.new(0, (piece.size :: Vector3).Y / 2, 0)
		chips(at, color, 14, if tier == 1 then Enum.Material.WoodPlanks else Enum.Material.CorrodedMetal)
		puff(at, Color3.fromRGB(150, 138, 120), 20, 3)
	end
	Sfx.play("demolish")
	Camera.shake(0.3)
end

-- Stations ------------------------------------------------------------------------------------------

local stations: { [Model]: boolean } = {}
local badges: { [Model]: BillboardGui } = {}
local progressBars: { [Model]: BillboardGui } = {}

-- A small bar with the time left above a station that is working (checklist 5.4).
local function progressBar(model: Model): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "JobProgress"
	gui.Size = UDim2.fromOffset(160, 36)
	gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y * 0.5 + 2.5, 0)
	-- Depth-sorted, not AlwaysOnTop: the camera looks down, so walls rarely hide it.
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, 0, 0, 12)
	track.Position = UDim2.fromOffset(0, 22)
	track.BackgroundColor3 = Theme.colors.track
	track.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.colors.shadow
	stroke.Thickness = 1.5
	stroke.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.colors.accent
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	fill.Parent = track
	track.Parent = gui
	local label = Instance.new("TextLabel")
	label.Name = "Time"
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.fonts.header
	label.TextSize = Theme.textSize.body
	label.TextColor3 = Theme.colors.text
	label.TextStrokeColor3 = Theme.colors.shadow
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Adornee = (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) :: any
	gui.Parent = model
	return gui
end

local function readyBadge(model: Model): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "ReadyBadge"
	gui.Size = UDim2.fromOffset(48, 48)
	gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y + 1.5, 0)
	gui.AlwaysOnTop = false -- above the station, clear of walls from the gameplay camera
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	local badge = Instance.new("TextLabel")
	badge.Size = UDim2.fromScale(1, 1)
	badge.BackgroundColor3 = Theme.colors.badge -- LDoE's teal ready-count badge (LDOE_PARITY #23)
	badge.FontFace = Theme.fonts.header
	badge.Name = "Count"
	badge.Text = ""
	badge.TextSize = Theme.textSize.title
	badge.TextColor3 = Theme.colors.text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = badge
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.colors.highlight
	stroke.Thickness = 2
	stroke.Parent = badge
	badge.Parent = gui
	gui.Adornee = (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) :: any
	gui.Parent = model
	return gui
end

local function updateStations(_now: number)
	for model in stations do
		if not model:IsDescendantOf(workspace) then
			stations[model] = nil
			badges[model] = nil
			progressBars[model] = nil
			continue
		end
		local burning = model:GetAttribute("Burning") == true
		local core = model:FindFirstChild("FireCore", true)
		if core then
			local flame = core:FindFirstChild("Flame") :: Fire?
			local glow = core:FindFirstChild("Glow") :: PointLight?
			if flame then
				flame.Enabled = burning
			end
			if glow then
				glow.Enabled = burning
				glow.Brightness = 1.4 + math.noise(os.clock() * 3) * 0.5
			end
		end
		local mine = model:GetAttribute("OwnerUserId") == player.UserId
		local readyCount = model:GetAttribute("Ready")
		local ready = mine and type(readyCount) == "number" and readyCount > 0
		local badge: BillboardGui? = badges[model]
		if ready and badge == nil then
			badges[model] = readyBadge(model)
		elseif not ready and badge then
			badge:Destroy()
			badges[model] = nil
		end
		if badge then
			-- How many are waiting in the output, e.g. "3" (checklist 5.12, LDOE_PARITY #23).
			local label = badge:FindFirstChild("Count") :: TextLabel?
			if label then
				label.Text = tostring(readyCount)
			end
			badge.StudsOffsetWorldSpace =
				Vector3.new(0, model:GetExtentsSize().Y + 1.5 + math.sin(os.clock() * 3) * 0.3, 0)
		end
		local progress = model:GetAttribute("BatchProgress")
		local remaining = model:GetAttribute("BatchRemaining")
		local bar: BillboardGui? = progressBars[model]
		if mine and type(progress) == "number" and type(remaining) == "number" then
			local shown = bar or progressBar(model)
			progressBars[model] = shown
			local track = shown:FindFirstChild("Track")
			local fill = track and track:FindFirstChild("Fill") :: Frame?
			if fill then
				fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
			end
			local label = shown:FindFirstChild("Time") :: TextLabel?
			if label then
				label.Text = format.duration(remaining)
			end
		elseif bar then
			bar:Destroy()
			progressBars[model] = nil
		end
	end
end

-- Crates show the icon of what they hold most of (checklist 4.13) -----------------------------------

local function crateIcon(model: Model)
	local old = model:FindFirstChild("EO_CrateIcon")
	if old then
		old:Destroy()
	end
	local itemId = model:GetAttribute("MainItem")
	local def = if type(itemId) == "string" then Content.Items[itemId] else nil
	if def == nil or def.icon == "" then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "EO_CrateIcon"
	gui.Size = UDim2.fromOffset(48, 48)
	gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y + 0.9, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 70
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Theme.colors.panel
	back.BackgroundTransparency = 0.15
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.colors.strokeWarm
	stroke.Thickness = 1.5
	stroke.Parent = back
	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromScale(0.8, 0.8)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.BackgroundTransparency = 1
	image.Image = def.icon
	image.Parent = back
	back.Parent = gui
	gui.Adornee = (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) :: any
	gui.Parent = model
end

local function watchCrate(instance: Instance)
	if not instance:IsA("Model") or instance:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	crateIcon(instance)
	instance:GetAttributeChangedSignal("MainItem"):Connect(function()
		crateIcon(instance)
	end)
end

-- Doors -----------------------------------------------------------------------------------------------

type DoorFx = { leaf: Model, closed: CFrame, open: boolean }
local doors: { [Model]: DoorFx } = {}

local function watchDoor(instance: Instance)
	if not instance:IsA("Model") or instance:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	local leaf = instance:FindFirstChild("Leaf")
	if leaf and leaf:IsA("Model") then
		task.delay(0.5, function()
			doors[instance] = { leaf = leaf, closed = leaf:GetPivot(), open = false }
		end)
	end
end

local function updateDoors()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for model, door in doors do
		if not model:IsDescendantOf(workspace) then
			doors[model] = nil
			continue
		end
		local near = root ~= nil and (root.Position - door.closed.Position).Magnitude < DOOR_RADIUS
		if near ~= door.open then
			door.open = near
			for _, descendant in door.leaf:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.CanCollide = not near
				end
			end
			local from = door.leaf:GetPivot()
			Sfx.play("door", door.closed.Position, if near then 1 else 0.7)
			local to = if near then door.closed * CFrame.Angles(0, math.rad(-100), 0) else door.closed
			animateModel(door.leaf, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha)
				door.leaf:PivotTo(from:Lerp(to, alpha))
			end)
		end
	end
end

-- Canopy fade ---------------------------------------------------------------------------------------
-- A tree's canopy fades only when it really sits between the camera and the survivor: rays
-- from the camera to the survivor's head, chest and feet that hit a tree (S1b brief,
-- leftover 2; LDoE does the same). Only the canopy fades, partially (CANOPY_ALPHA), eased
-- over FADE_SECONDS; the trunk stays solid, and the tree you're targeting or chopping
-- never fades. A tree made as one mesh fades as a whole, still partially.

local CANOPY_ALPHA = 0.55
local FADE_SECONDS = 0.2
-- The share of a tree's height below which parts count as trunk.
local TRUNK_SHARE = 0.3

-- Parts easing toward a wanted LocalTransparencyModifier: `rest` is where they go back to
-- (0, or 1 for a felled node that is hidden).
type Fade = { now: number, target: number, rest: number }
local fades: { [BasePart]: Fade } = {}

local function fadeTo(part: BasePart, target: number, rest: number)
	local fade = fades[part]
	if fade == nil then
		fades[part] = { now = part.LocalTransparencyModifier, target = target, rest = rest }
	else
		fade.target = target
		fade.rest = rest
	end
end

-- Eases every fading part; parts back at rest are released.
local function stepFades(dt: number)
	local step = dt / FADE_SECONDS
	for part, fade in fades do
		if part.Parent == nil then
			fades[part] = nil
			continue
		end
		local diff = fade.target - fade.now
		fade.now = if math.abs(diff) <= step then fade.target else fade.now + math.sign(diff) * step
		part.LocalTransparencyModifier = fade.now
		if fade.now == fade.target and fade.target == fade.rest then
			fades[part] = nil
		end
	end
end

-- Each tree's canopy parts, read once.
local canopyCache: { [Model]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any

local function canopyOf(model: Model): { BasePart }
	local cached = canopyCache[model]
	if cached then
		return cached
	end
	local box, size = model:GetBoundingBox()
	local cut = box.Position.Y - size.Y / 2 + size.Y * TRUNK_SHARE
	local canopy: { BasePart } = {}
	local all: { BasePart } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Collider" then
			table.insert(all, part)
			local name = string.lower(part.Name)
			local leafy = string.find(name, "leaf") or string.find(name, "canopy") or string.find(name, "needle")
			if leafy or part.Position.Y - part.Size.Y / 2 >= cut then
				table.insert(canopy, part)
			end
		end
	end
	local result = if #canopy > 0 and #canopy < #all then canopy else all
	canopyCache[model] = result
	return result
end

-- The edge pines (World.Dressing.Edges) never move; they are read again when more arrive.
local edgeModels: { Model } = {}
local edgeCount = -1

local function readEdgeTrees()
	local world = workspace:FindFirstChild("World")
	local dressing = world and world:FindFirstChild("Dressing")
	local edges = dressing and dressing:FindFirstChild("Edges")
	if edges == nil then
		return
	end
	local children = edges:GetChildren()
	if #children == edgeCount then
		return
	end
	edgeCount = #children
	table.clear(edgeModels)
	for _, model in children do
		if model:IsA("Model") then
			table.insert(edgeModels, model)
		end
	end
end

-- The tree model a hit part belongs to (a standing tree node or an edge tree), if any.
local function treeOf(part: Instance, trees: { [Model]: boolean }): Model?
	local current: Instance? = part
	while current and current ~= workspace do
		if current:IsA("Model") and trees[current] then
			return current
		end
		current = current.Parent
	end
	return nil
end

local shading: { [Model]: boolean } = {}

local function updateCanopy()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local wanted: { [Model]: boolean } = {}
	if camera and root then
		readEdgeTrees()
		local target = State.ui().target
		local spared: Model? = if target then target.model else nil
		local trees: { [Model]: boolean } = {}
		local list: { Instance } = {}
		for model, info in nodeFx do
			local nodeId = model:GetAttribute("NodeId")
			if info.standing and nodeId == "node.pine_tree" and model ~= spared then
				trees[model] = true
				table.insert(list, model)
			end
		end
		for _, model in edgeModels do
			if model.Parent then
				trees[model] = true
				table.insert(list, model)
			end
		end
		local from = camera.CFrame.Position
		for _, offset in { Vector3.new(0, 2.5, 0), Vector3.zero, Vector3.new(0, -2.2, 0) } do
			local aim = root.Position + offset
			local cast = RaycastParams.new()
			cast.FilterType = Enum.RaycastFilterType.Include
			cast.FilterDescendantsInstances = list
			for _ = 1, 4 do
				local hit = workspace:Raycast(from, aim - from, cast)
				if hit == nil then
					break
				end
				local tree = treeOf(hit.Instance, trees)
				if tree == nil then
					break
				end
				if hit.Instance.Name ~= "Collider" then
					wanted[tree] = true
				end
				-- Look past this tree for another behind it.
				local index = table.find(list, tree)
				if index then
					table.remove(list, index)
				end
				cast.FilterDescendantsInstances = list
			end
		end
	end
	for model in wanted do
		if not shading[model] then
			shading[model] = true
			for _, part in canopyOf(model) do
				fadeTo(part, CANOPY_ALPHA, 0)
			end
		end
	end
	for model in shading do
		if not wanted[model] then
			shading[model] = nil
			local info = nodeFx[model]
			local rest = if info and not info.standing then 1 else 0
			for _, part in canopyOf(model) do
				fadeTo(part, rest, rest)
			end
		end
	end
end

-- Occlusion fade ------------------------------------------------------------------------------------
-- Walls, doors and windows between the camera and the survivor fade (with the
-- corner posts at their ends), so you can always see yourself inside a base.

local OCCLUDE_ALPHA = 0.6 -- partial and eased, like the canopy (S1b leftover 2)
local OCCLUDE_LAYERS: { [string]: boolean } = { frame = true, fill = true, roof = true }
local occluded: { [BasePart]: boolean } = {}

local function pieceOf(part: Instance): Model?
	local current: Instance? = part
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("Layer") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function updateOcclusion()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hidden: { [BasePart]: boolean } = {}
	if camera and root and character then
		local from = camera.CFrame.Position
		local walls: { [Model]: boolean } = {}
		for _, offset in { Vector3.new(0, 2.5, 0), Vector3.zero, Vector3.new(0, -2.2, 0) } do
			local target = root.Position + offset
			local skip: { Instance } = { character }
			for _ = 1, 6 do
				local cast = RaycastParams.new()
				cast.FilterType = Enum.RaycastFilterType.Exclude
				cast.FilterDescendantsInstances = skip
				local hit = workspace:Raycast(from, target - from, cast)
				if hit == nil then
					break
				end
				-- Look past anything that isn't a wall (trees, props) for walls behind it.
				local piece = pieceOf(hit.Instance)
				if piece and OCCLUDE_LAYERS[piece:GetAttribute("Layer") :: string] then
					walls[piece] = true
					table.insert(skip, piece)
				else
					table.insert(skip, hit.Instance)
				end
			end
		end
		for wall in walls do
			for _, descendant in wall:GetDescendants() do
				if descendant:IsA("BasePart") then
					hidden[descendant] = true
				end
			end
			-- The corner posts at both ends of the wall (World/Seams).
			local seams = wall.Parent and wall.Parent:FindFirstChild("Seams")
			if seams then
				local pivot = wall:GetPivot()
				local ends = { (pivot * CFrame.new(-6, 0, 0)).Position, (pivot * CFrame.new(6, 0, 0)).Position }
				for _, partInSeams in seams:GetChildren() do
					if partInSeams:IsA("BasePart") then
						for _, at in ends do
							local d = partInSeams.Position - at
							if Vector2.new(d.X, d.Z).Magnitude < 1.6 then
								hidden[partInSeams] = true
							end
						end
					end
				end
			end
		end
	end
	for part in hidden do
		if not occluded[part] then
			occluded[part] = true
			fadeTo(part, OCCLUDE_ALPHA, 0)
		end
	end
	for part in occluded do
		if not hidden[part] then
			occluded[part] = nil
			fadeTo(part, 0, 0)
		end
	end
end

-- Level-ups ----------------------------------------------------------------------------------------------

local function levelBurst()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Theme.colors.accent, Theme.colors.highlight)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 6, 0)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(60)
	Debris:AddItem(attachment, 2)
	Camera.shake(0.25)
end

-- Lifecycle ------------------------------------------------------------------------------------------------

local function eachTagged(tag: string, fn: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(tag):Connect(fn)
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(fn, instance)
	end
end

function WorldFx.start()
	eachTagged("EO_Node", watchNode)
	eachTagged("EO_Piece", snapIn)
	eachTagged("EO_Station", function(instance)
		if instance:IsA("Model") then
			stations[instance] = true
		end
	end)
	eachTagged("EO_Door", watchDoor)
	eachTagged("EO_Storage", watchCrate)

	State.fx:Connect(function(kind: any, payload: any)
		if kind == "gather" then
			onGather(payload)
		elseif kind == "swing" then
			Camera.shake(0.05)
		elseif kind == "debris" then
			onDebris(payload)
		elseif kind == "levelUp" then
			levelBurst()
		elseif kind == "upgraded" then
			Sfx.play("upgrade")
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		updateDoors()
		stepFades(dt)
		if elapsed >= 0.1 then
			elapsed = 0
			updateCanopy()
			updateStations(State.now())
			updateOcclusion()
		end
	end)
end

return WorldFx
