--!strict
--[[
	World/Haven: builds Haven Square, the public safe zone in the middle of every
	Neighbourhood (MVP_LAUNCH; LDoE's Settlement, rec4_01), from grade-A kit models and
	exact geometry in real materials (checklist §0: no stand-ins).

	Layout (studs from the World origin, north = -Z; Domain/Neighbourhood):
	- the campfire circle in the middle: a lit stone ring and stump seats;
	- the Trader's stall (north-west) and the Trail Keeper's stall with the contract board
	  (north-east); the notice board where the trail leaves north;
	- the VIP Lounge (south-east): a palisade fence, a gate only members pass, its own fire
	  and seats, the Lounge Warden at the gate;
	- the guild banner spot (south-west), empty until guilds arrive (M3);
	- lanterns around the edge and dense camp dressing.

	Everything the player can talk to or read carries the EO_Haven tag and the HavenId,
	Label and Verb attributes (Controllers/Interaction). Services/Haven runs it.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local Neighbourhood = require(ReplicatedStorage.Shared.Domain.Neighbourhood)
local Models = require("./Models")

local Haven = {}

Haven.TAG = "EO_Haven"
-- The Lounge gate blocks everyone but members: their characters join MEMBER_GROUP,
-- which does not collide with GATE_GROUP (Services/Haven).
Haven.GATE_GROUP = "HavenGate"
Haven.MEMBER_GROUP = "HavenMember"

local IDLE_ANIMATION = "rbxassetid://16562317918" -- the survivor rig's own idle
local WOOD = Art.decks[1]
local POST = Color3.fromRGB(128, 98, 66)
local DARK_WOOD = Color3.fromRGB(78, 58, 42)
local PAPER = Color3.fromRGB(196, 182, 150)
local GOLD = Color3.fromHex("FFD27A")
local GREETING = Color3.fromHex("F0B85A") -- LDoE's floating line over an NPC (rec4_01)
local EMBER = Color3.fromRGB(255, 138, 61)
local FENCE_HEIGHT = 5.2
local FENCE_SEGMENT = 8

-- The survivor rig's parts that wear the jacket and the trousers tints.
local JACKET =
	{ UpperTorso = true, LeftUpperArm = true, RightUpperArm = true, LeftLowerArm = true, RightLowerArm = true }
local TROUSERS =
	{ LowerTorso = true, LeftUpperLeg = true, RightUpperLeg = true, LeftLowerLeg = true, RightLowerLeg = true }

-- Geometry -----------------------------------------------------------------------------------------

local function solid(parent: Instance, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Timber in the wood deck's planks (the same boards the outposts are built from).
local function wood(parent: Instance, size: Vector3, cframe: CFrame, color: Color3?): Part
	local p = solid(parent, size, cframe, WOOD.base, color or POST)
	p.MaterialVariant = WOOD.variant
	return p
end

-- Painted words on one face of a board, lit by the scene.
local function paint(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromName("BuilderSans", Enum.FontWeight.ExtraBold)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = gui
	gui.Parent = part
end

type KitOptions = { height: number?, width: number?, solid: boolean? }

-- A grade-A kit model standing at `at` (its pivot is its base centre), optionally sized to a
-- height or a width. Nil while the model is missing (it is then simply left out).
local function kit(parent: Instance, name: string, at: CFrame, options: KitOptions?): Model?
	local model = Models.kit({ name })
	if model == nil then
		return nil
	end
	local opts: KitOptions = options or {}
	local size = model:GetExtentsSize()
	if opts.height and size.Y > 0.01 then
		model:ScaleTo(model:GetScale() * opts.height / size.Y)
	elseif opts.width and size.X > 0.01 then
		model:ScaleTo(model:GetScale() * opts.width / size.X)
	end
	model:PivotTo(at)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = opts.solid ~= false
			descendant.CanTouch = false
		end
	end
	if name == "EO_LanternPost" then
		-- The square's lanterns burn brighter than the plots': a warm pool under each.
		local lamp = Models.lanternGlow(model)
		if lamp then
			lamp.Brightness = 2
			lamp.Range = 20
			lamp.Color = Color3.fromRGB(255, 168, 96)
		end
	end
	model.Parent = parent
	return model
end

-- Turned toward a point on the ground.
local function facing(at: Vector3, toward: Vector3): CFrame
	local flat = Vector3.new(toward.X, at.Y, toward.Z)
	if (flat - at).Magnitude < 0.01 then
		return CFrame.new(at)
	end
	return CFrame.lookAt(at, flat)
end

local function yawed(at: Vector3, degrees: number): CFrame
	return CFrame.new(at) * CFrame.Angles(0, math.rad(degrees), 0)
end

-- A burning fire over a stone ring: flame, sparks and a warm flickerless glow.
local function fire(parent: Instance, at: Vector3, size: number)
	-- An invisible core (Neon, like the station campfire's: effects on an Air part never draw).
	local core = solid(parent, Vector3.one, CFrame.new(at + Vector3.new(0, size * 0.22, 0)), Enum.Material.Neon, EMBER)
	core.Name = "FireCore"
	core.Transparency = 1
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	local flame = Instance.new("Fire")
	flame.Size = size
	flame.Heat = 9
	flame.Color = EMBER
	flame.SecondaryColor = Color3.fromRGB(255, 181, 71)
	flame.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(EMBER)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.18, 0)
	sparks.Lifetime = NumberRange.new(1, 1.8)
	sparks.Rate = 10
	sparks.Speed = NumberRange.new(3, 6)
	sparks.SpreadAngle = Vector2.new(18, 18)
	sparks.Acceleration = Vector3.new(0, 1.5, 0)
	sparks.Parent = core
	-- The flame body: bright tongues that keep their colour by night (the legacy Fire flickers
	-- on top).
	local flames = Instance.new("ParticleEmitter")
	flames.Name = "Flames"
	flames.Texture = "rbxasset://textures/particles/fire_main.dds"
	flames.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 50, 20)),
	})
	flames.LightEmission = 1
	flames.LightInfluence = 0
	flames.Brightness = 2
	flames.Size = NumberSequence.new(size * 0.36, size * 0.06)
	flames.Transparency = NumberSequence.new(0.15, 1)
	flames.Lifetime = NumberRange.new(0.5, 0.9)
	flames.Rate = 45
	flames.Speed = NumberRange.new(2.5, 4.5)
	flames.SpreadAngle = Vector2.new(12, 12)
	flames.Acceleration = Vector3.new(0, 3, 0)
	flames.Parent = core
	-- The warm pool: lit from above the stones so the ring doesn't shadow it, strong enough
	-- to stay orange through the blue night grade (LDoE rec4_01's warm pools).
	local lift = Instance.new("Attachment")
	lift.Name = "Pool"
	lift.Position = Vector3.new(0, 3, 0)
	lift.Parent = core
	local glow = Instance.new("PointLight")
	glow.Range = size * 6
	glow.Brightness = 3.2
	glow.Color = Color3.fromRGB(255, 150, 70)
	glow.Shadows = false
	glow.Parent = lift
end

-- A felled log to sit on, lying across the line to `toward` (a seat on its middle).
-- A crate or a sack of stores to sit on by a fire, facing it (a seat on its top).
local function propSeat(parent: Instance, at: Vector3, toward: Vector3, name: string)
	local frame = facing(at, toward)
	local prop = kit(parent, name, frame, { width = if name == "EO_StorageCrate" then 3.2 else 3.6 })
	if prop == nil then
		return
	end
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(2, 0.2, 1.6)
	seat.CFrame = frame + Vector3.new(0, prop:GetExtentsSize().Y + 0.05, 0)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Parent = prop
end

-- Log benches in a ring around a fire, the gaps between them left to walk through.
-- Crates and sacks in a ring around a fire, gaps between them to walk through.
local SEATS = { "EO_StorageCrate", "EO_SupplySacksMesh" }

local function seatRing(parent: Instance, centre: Vector3, radius: number, count: number, offset: number)
	for index = 0, count - 1 do
		local angle = math.rad(offset + index * 360 / count)
		local at = centre + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		propSeat(parent, at, centre, SEATS[index % #SEATS + 1])
	end
end

local function interactive(model: Model, havenId: string, label: string, verb: string)
	model:SetAttribute("HavenId", havenId)
	model:SetAttribute("Label", label)
	model:SetAttribute("Verb", verb)
	CollectionService:AddTag(model, Haven.TAG)
end

-- Pieces -----------------------------------------------------------------------------------------

-- A market stall in its own frame (front toward -Z, origin at the ground centre): four
-- posts, a canvas awning sloping to the front with a painted trim valance, a counter of
-- storage crates with goods on and around it, a scrap windbreak behind.
local STALL = { width = 16, depth = 10, front = 8.4, back = 10.2 }

-- The roof: two kit wall panels (scrap sheet or timber) laid side by side over the posts,
-- sloping from the back eave down to the front, overhanging every side.
local function roof(parent: Instance, frame: CFrame, panelName: string)
	local w, d = STALL.width, STALL.depth
	local rise = STALL.back - STALL.front
	local slope = math.atan2(rise, d)
	local length = math.sqrt(d * d + rise * rise) + 1.8
	for _, side in { -1, 1 } do
		local panel = Models.kit({ panelName })
		if panel == nil then
			return
		end
		Models.fitEdgeTo(panel, w / 2 + 0.7, length)
		-- A standing panel's height runs up +Y; laid down, it runs from the back eave toward
		-- the front, falling with the slope.
		panel:PivotTo(
			frame
				* CFrame.new(side * (w / 4 + 0.15), STALL.back + 0.35, d / 2 + 0.8)
				* CFrame.Angles(-(math.pi / 2 + slope), 0, 0)
		)
		for _, piece in panel:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.CanTouch = false
			end
		end
		panel.Parent = parent
	end
end

local function stall(parent: Instance, frame: CFrame, roofPanel: string, title: string)
	local folder = Instance.new("Model")
	folder.Name = title
	local w, d = STALL.width, STALL.depth
	for _, x in { -w / 2, w / 2 } do
		wood(folder, Vector3.new(0.7, STALL.front, 0.7), frame * CFrame.new(x, STALL.front / 2, -d / 2), DARK_WOOD)
		wood(folder, Vector3.new(0.7, STALL.back, 0.7), frame * CFrame.new(x, STALL.back / 2, d / 2), DARK_WOOD)
	end
	roof(folder, frame, roofPanel)
	-- The signboard hangs under the roof's front edge with the stall's name painted on it.
	local sign = wood(
		folder,
		Vector3.new(w * 0.62, 1.5, 0.3),
		frame * CFrame.new(0, STALL.front - 0.95, -d / 2 - 0.3),
		DARK_WOOD
	)
	paint(sign, Enum.NormalId.Front, title, GOLD)
	-- The counter: three crates along the front, sacks of goods on one end.
	local crateTop = 0
	for index, x in { -5.4, 0, 5.4 } do
		local crate = kit(
			folder,
			"EO_StorageCrate",
			frame * CFrame.new(x, 0, -2.6) * CFrame.Angles(0, math.rad(index * 3 - 6), 0)
		)
		if crate then
			crateTop = crate:GetExtentsSize().Y
		end
	end
	kit(folder, "EO_SupplySacksMesh", frame * CFrame.new(-5.4, crateTop, -2.6) * CFrame.Angles(0, math.rad(20), 0), {
		width = 3,
		solid = false,
	})
	-- Stock around it: barrels by the front post, a crate stack in the back corner.
	kit(folder, "EO_BarrelCluster", frame * CFrame.new(-w / 2 - 2.6, 0, -1.5) * CFrame.Angles(0, math.rad(35), 0))
	local stack = kit(
		folder,
		"EO_StorageCrate",
		frame * CFrame.new(w / 2 - 3.2, 0, d / 2 - 2.4) * CFrame.Angles(0, math.rad(8), 0)
	)
	if stack then
		kit(
			folder,
			"EO_StorageCrate",
			frame * CFrame.new(w / 2 - 3.4, stack:GetExtentsSize().Y, d / 2 - 2.2) * CFrame.Angles(0, math.rad(-14), 0),
			{ width = 4.4 }
		)
	end
	kit(
		folder,
		"EO_SupplySacksMesh",
		frame * CFrame.new(-w / 2 + 2.6, 0, d / 2 - 1.8) * CFrame.Angles(0, math.rad(-30), 0)
	)
	kit(folder, "WallScrap", frame * CFrame.new(0, 0, d / 2 + 1.4))
	kit(folder, "EO_LanternPost", frame * CFrame.new(-w / 2 - 1.4, 0, -d / 2 - 1.6) * CFrame.Angles(0, math.rad(90), 0))
	folder.WorldPivot = frame
	folder.Parent = parent
end

-- A notice board in its own frame (front toward -Z): two posts, a plank face under a
-- little roof, the title painted on a header board, paper notes pinned below.
local function board(parent: Instance, frame: CFrame, title: string, notes: number): Model
	local model = Instance.new("Model")
	model.Name = title
	for _, x in { -3.7, 3.7 } do
		wood(model, Vector3.new(0.55, 7.6, 0.55), frame * CFrame.new(x, 3.8, 0), DARK_WOOD)
	end
	wood(model, Vector3.new(7.4, 4.4, 0.3), frame * CFrame.new(0, 4.3, 0))
	local header = wood(model, Vector3.new(7.8, 1.1, 0.4), frame * CFrame.new(0, 7.05, -0.05), DARK_WOOD)
	paint(header, Enum.NormalId.Front, title, GOLD)
	wood(
		model,
		Vector3.new(8.6, 0.25, 1.5),
		frame * CFrame.new(0, 7.8, 0.1) * CFrame.Angles(math.rad(14), 0, 0),
		DARK_WOOD
	)
	local columns = math.min(notes, 3)
	for index = 1, notes do
		local column = (index - 1) % columns
		local row = (index - 1) // columns
		local x = (column - (columns - 1) / 2) * 2.2
		local tilt = math.rad(((index * 37) % 11) - 5)
		solid(
			model,
			Vector3.new(1.7, 2, 0.06),
			frame * CFrame.new(x, 5.15 - row * 2.1, -0.19) * CFrame.Angles(0, 0, tilt),
			Enum.Material.Cardboard,
			PAPER
		)
	end
	model.WorldPivot = frame
	model.Parent = parent
	return model
end

-- A straight run of palisade from `from` to `to`, in segments of about FENCE_SEGMENT.
local function fenceRun(parent: Instance, from: Vector3, to: Vector3)
	local span = to - from
	local count = math.max(1, math.round(span.Magnitude / FENCE_SEGMENT))
	local length = span.Magnitude / count
	for index = 1, count do
		local model = Models.kit({ "WallWood" })
		if model == nil then
			return
		end
		Models.fitEdgeTo(model, length, FENCE_HEIGHT)
		local mid = from + span.Unit * (length * (index - 0.5))
		model:PivotTo(CFrame.lookAt(mid, mid + span.Unit) * CFrame.Angles(0, math.rad(90), 0))
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanTouch = false
			end
		end
		model.Parent = parent
	end
end

-- The survivor rig as an NPC (Data/Haven.npcs): outfit tints, the idle animation, the
-- greeting floating over the head when you are near (rec4_01), tagged for talking to.
local function npc(parent: Instance, npcId: string, at: Vector3, toward: Vector3)
	local def = Content.Haven.npcs[npcId]
	local template = StarterPlayer:FindFirstChild("StarterCharacter")
	if def == nil or template == nil or not template:IsA("Model") then
		return
	end
	local rig = template:Clone()
	rig.Name = def.name
	for _, child in rig:GetChildren() do
		local pack = child:IsA("Accessory") and not def.keepsPack
		if child:IsA("LuaSourceContainer") or child.Name == "InitialPoses" or pack then
			child:Destroy()
		end
	end
	local jacket, trousers = Color3.fromHex(def.jacket), Color3.fromHex(def.pants)
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			local look = part:FindFirstChildOfClass("SurfaceAppearance")
			if look and JACKET[part.Name] then
				look.Color = jacket
			elseif look and TROUSERS[part.Name] then
				look.Color = trousers
			end
		end
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		rig:Destroy()
		return
	end
	root.Anchored = true
	root.CanCollide = true
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	local lift = humanoid.HipHeight + root.Size.Y / 2
	rig:PivotTo(facing(at + Vector3.new(0, lift, 0), toward + Vector3.new(0, lift, 0)))
	interactive(rig, def.id, def.name, "Talk")

	local head = rig:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local bubble = Instance.new("BillboardGui")
		bubble.Name = "Greeting"
		bubble.Size = UDim2.fromOffset(380, 34)
		bubble.StudsOffsetWorldSpace = Vector3.new(0, 2.1, 0)
		bubble.Enabled = false -- Controllers/Interaction shows it while you are near
		bubble.LightInfluence = 0
		local line = Instance.new("TextLabel")
		line.Size = UDim2.fromScale(1, 1)
		line.BackgroundTransparency = 1
		line.FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold)
		line.Text = def.greeting
		line.TextSize = 20
		line.TextColor3 = GREETING
		line.TextStrokeColor3 = Color3.new(0, 0, 0)
		line.TextStrokeTransparency = 0.35
		line.Parent = bubble
		bubble.Parent = head
	end

	rig.Parent = parent
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.AnimationId = IDLE_ANIMATION
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = true
		track:Play(0)
		track.TimePosition = (#def.name % 5) * 0.4 -- not all in step
	end
end

local function collisionGroups()
	for _, group in { Haven.GATE_GROUP, Haven.MEMBER_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(Haven.GATE_GROUP, Haven.MEMBER_GROUP, false)
end

-- The square --------------------------------------------------------------------------------------

local function campfireCircle(folder: Instance, origin: Vector3)
	local circle = Instance.new("Folder")
	circle.Name = "CampfireCircle"
	kit(circle, "EO_CampfireRing", CFrame.new(origin), { width = 7 })
	fire(circle, origin, 5)
	seatRing(circle, origin, 8.6, 5, 18)
	-- Firewood stacked by the ring.
	kit(circle, "EO_BareBranches", yawed(origin + Vector3.new(-5.2, 0, 3.6), 40), { width = 3.6, solid = false })
	kit(circle, "EO_BareBranches", yawed(origin + Vector3.new(4.8, 0, -4.2), -70), { width = 3.2, solid = false })
	circle.Parent = folder
end

local function stalls(folder: Instance, origin: Vector3)
	local w, d = STALL.width, STALL.depth
	-- The Trader faces east across the square, the Trail Keeper west.
	local trader = CFrame.new(origin + Vector3.new(-30, 0, -22)) * CFrame.Angles(0, math.rad(-90), 0)
	stall(folder, trader, "WallScrap", "TRADING POST")
	npc(folder, "npc.trader", (trader * CFrame.new(w / 2 - 1, 0, -d / 2 - 5.5)).Position, origin)
	local keeper = CFrame.new(origin + Vector3.new(30, 0, -22)) * CFrame.Angles(0, math.rad(90), 0)
	stall(folder, keeper, "WallWood", "TRAIL KEEPER")
	kit(folder, "EO_WorkbenchP2", keeper * CFrame.new(-w / 2 - 3.6, 0, 1.5) * CFrame.Angles(0, math.rad(90), 0))
	npc(folder, "npc.keeper", (keeper * CFrame.new(-w / 2 + 1, 0, -d / 2 - 5.5)).Position, origin)
	local contracts = board(folder, keeper * CFrame.new(w / 2 + 4.5, 0, -1.5), "CONTRACTS", 3)
	interactive(contracts, "board.contracts", "Contract Board", "Read")
end

local function lounge(folder: Instance, origin: Vector3)
	local rect = Neighbourhood.lounge
	local model = Instance.new("Folder")
	model.Name = "VipLounge"
	local function at(x: number, z: number): Vector3
		return origin + Vector3.new(x, 0, z)
	end
	local gateX = (rect.x0 + rect.x1) / 2
	local half = rect.gateWidth / 2
	fenceRun(model, at(rect.x0, rect.z0), at(gateX - half, rect.z0))
	fenceRun(model, at(gateX + half, rect.z0), at(rect.x1, rect.z0))
	fenceRun(model, at(rect.x1, rect.z0), at(rect.x1, rect.z1))
	fenceRun(model, at(rect.x1, rect.z1), at(rect.x0, rect.z1))
	fenceRun(model, at(rect.x0, rect.z1), at(rect.x0, rect.z0))
	-- The gate: an arch with the Lounge's name, and the barrier only members pass.
	for _, side in { -1, 1 } do
		wood(
			model,
			Vector3.new(0.9, 8.4, 0.9),
			CFrame.new(at(gateX + side * (half + 0.45), rect.z0) + Vector3.new(0, 4.2, 0)),
			DARK_WOOD
		)
	end
	local sign = wood(
		model,
		Vector3.new(rect.gateWidth + 2.6, 1.4, 0.5),
		CFrame.new(at(gateX, rect.z0) + Vector3.new(0, 7.7, 0)),
		DARK_WOOD
	)
	paint(sign, Enum.NormalId.Front, "VIP LOUNGE", GOLD)
	paint(sign, Enum.NormalId.Back, "VIP LOUNGE", GOLD)
	local gate = solid(
		model,
		Vector3.new(rect.gateWidth, 8, 0.6),
		CFrame.new(at(gateX, rect.z0) + Vector3.new(0, 4, 0)),
		Enum.Material.SmoothPlastic,
		Color3.new()
	)
	gate.Name = "Gate"
	gate.Transparency = 1
	gate.CanQuery = false
	gate.CanTouch = false
	gate.CollisionGroup = Haven.GATE_GROUP
	kit(model, "EO_LanternPost", yawed(at(gateX - half - 2.2, rect.z0 - 1.6), 90))
	kit(model, "EO_LanternPost", yawed(at(gateX + half + 2.2, rect.z0 - 1.6), -90))
	-- Inside: the members' fire with its seats, lamps in the corners, supplies at the back.
	local centre = at(gateX, (rect.z0 + rect.z1) / 2 + 2)
	kit(model, "EO_CampfireRing", CFrame.new(centre), { width = 6 })
	fire(model, centre, 4.4)
	seatRing(model, centre, 6.6, 4, 45)
	for _, corner in
		{
			{ rect.x0 + 3, rect.z1 - 3 },
			{ rect.x1 - 3, rect.z1 - 3 },
			{ rect.x0 + 3, rect.z0 + 4 },
			{ rect.x1 - 3, rect.z0 + 4 },
		}
	do
		kit(model, "EO_LanternPost", facing(at(corner[1], corner[2]), centre))
	end
	kit(model, "EO_StorageCrate", yawed(at(rect.x1 - 8, rect.z1 - 4), 6))
	kit(model, "EO_StorageCrate", yawed(at(rect.x1 - 13.6, rect.z1 - 4.2), -4))
	kit(model, "EO_SupplySacksMesh", yawed(at(rect.x0 + 8, rect.z1 - 4), 30))
	kit(model, "EO_BarrelCluster", yawed(at(rect.x0 + 5, rect.z1 - 9), -20))
	model.Parent = folder
	npc(folder, "npc.warden", at(gateX + half + 4.5, rect.z0 - 4), origin)
end

local function guildSpot(folder: Instance, origin: Vector3)
	local model = Instance.new("Model")
	model.Name = "GuildBanner"
	local base = origin + Vector3.new(-30, 0, 44)
	for _, x in { -4.4, 4.4 } do
		wood(model, Vector3.new(0.9, 11, 0.9), CFrame.new(base + Vector3.new(x, 5.5, 0)), DARK_WOOD)
		kit(model, "EO_LooseStonesClean", yawed(base + Vector3.new(x, 0, 0.6), x * 20), { solid = false })
	end
	wood(model, Vector3.new(10.6, 0.7, 0.7), CFrame.new(base + Vector3.new(0, 10.5, 0)), DARK_WOOD)
	-- An unclaimed banner: plain weathered canvas until a guild raises its colours (M3).
	local cloth = solid(
		model,
		Vector3.new(6.4, 7.2, 0.12),
		CFrame.new(base + Vector3.new(0, 6.6, 0)),
		Enum.Material.Fabric,
		Color3.fromRGB(116, 104, 88)
	)
	cloth.Name = "Banner"
	cloth.CanCollide = false
	kit(model, "EO_LanternPost", yawed(base + Vector3.new(-8.5, 0, 1), 90))
	kit(model, "EO_LanternPost", yawed(base + Vector3.new(8.5, 0, 1), -90))
	kit(model, "EO_RockCluster", yawed(base + Vector3.new(-2, -0.2, 5), 40), { width = 4.5 })
	-- Guilds (M3) hang their banner on the crossbar.
	model:SetAttribute("GuildBannerSpot", true)
	model.WorldPivot = CFrame.new(base)
	model.Parent = folder
end

-- Lanterns around the edge and camp dressing in the corners and along the sides.
local function dressing(folder: Instance, origin: Vector3)
	local model = Instance.new("Folder")
	model.Name = "Dressing"
	local function at(x: number, z: number): Vector3
		return origin + Vector3.new(x, 0, z)
	end
	for _, spot in
		{
			{ -48, -46 },
			{ 48, -46 },
			{ -52, 4 },
			{ 54, 8 },
			{ -46, 60 },
			{ 4, 70 },
			{ -9, -62 },
			{ 9, -62 },
		}
	do
		kit(model, "EO_LanternPost", facing(at(spot[1], spot[2]), origin))
	end
	-- North-west: a supply corner behind the Trading Post.
	local crate = kit(model, "EO_StorageCrate", yawed(at(-44, -38), 12))
	if crate then
		kit(
			model,
			"EO_StorageCrate",
			yawed(at(-43.6, -38.2) + Vector3.new(0, crate:GetExtentsSize().Y, 0), 34),
			{ width = 4.6 }
		)
	end
	kit(model, "EO_StorageCrate", yawed(at(-38, -42), -8))
	kit(model, "EO_BarrelCluster", yawed(at(-33, -46), 50))
	kit(model, "EO_RockCluster", yawed(at(-50, -52), 15), { width = 5.5 })
	-- North-east: the scrap corner past the contract board.
	kit(model, "EO_RecyclerStation", yawed(at(42, -48), 200))
	kit(model, "EO_ScrapHeapClean", yawed(at(34, -52), 30))
	kit(model, "EO_BarrelCluster", yawed(at(48, -38), -25))
	-- Along the sides of the road.
	kit(model, "EO_SupplySacksMesh", yawed(at(-46, -10), 70))
	kit(model, "EO_StorageCrate", yawed(at(-48, 14), -12))
	kit(model, "EO_BarrelCluster", yawed(at(48, 20), 10))
	kit(model, "EO_SupplySacksMesh", yawed(at(46, -8), -60))
	-- The well, south-west of the fire.
	kit(model, "EO_SpringBasin", yawed(at(-22, 20), 20))
	kit(model, "EO_BarrelCluster", yawed(at(-15, 25), 80))
	-- South: stores by the edge, rocks and a dead pine on the square's rim.
	kit(model, "EO_StorageCrate", yawed(at(-6, 60), 4))
	kit(model, "EO_SupplySacksMesh", yawed(at(0, 63), -40))
	kit(model, "EO_RockCluster", yawed(at(-48, 66), 60), { width = 6 })
	kit(model, "EO_DeadTree", yawed(at(-54, 72), 0), { height = 20, solid = false })
	kit(model, "EO_RockCluster", yawed(at(10, 74), -20), { width = 4 })
	model.Parent = folder
end

-- Seeded clutter between the features so the trodden ground never reads empty: fieldstones,
-- stubble tufts toward the rim, rocks, scrap piles and stores. Nothing lands on a feature,
-- in the Lounge, on the trail or on the road, or on another piece.
local CLUTTER_SEED = 4417

local function clutter(folder: Instance, origin: Vector3)
	local random = Random.new(CLUTTER_SEED)
	local plots = Content.Tuning.plots
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local model = Instance.new("Folder")
	model.Name = "Clutter"
	model.Parent = folder
	local function free(x: number, z: number, gap: number, solidPiece: boolean): boolean
		if Neighbourhood.inLounge(x, z) or (math.abs(x) < 7 and z < -40) or (x * x + (z - 22) ^ 2 < 36) then
			return false -- the Lounge, the trail north, the spawn
		end
		if solidPiece and math.abs(z) < 9 then
			return false -- keep the road through the square walkable
		end
		local near = workspace:GetPartBoundsInRadius(origin + Vector3.new(x, 2, z), gap, params)
		return #near == 0
	end
	local function spread(name: string, count: number, band: { number }, size: KitOptions, gap: number)
		local done, tries = 0, 0
		while done < count and tries < count * 40 do
			tries += 1
			local angle = random:NextNumber(0, math.pi * 2)
			local reach = random:NextNumber(band[1], band[2])
			local x = math.cos(angle) * reach * plots.plazaHalfStuds
			local z = math.sin(angle) * reach * plots.plazaDepthStuds
			if free(x, z, gap, size.solid ~= false) then
				local grow = random:NextNumber(0.8, 1.2)
				kit(model, name, yawed(origin + Vector3.new(x, 0, z), random:NextInteger(0, 359)), {
					height = if size.height then size.height * grow else nil,
					width = if size.width then size.width * grow else nil,
					solid = size.solid,
				})
				done += 1
			end
		end
	end
	spread("EO_RockCluster", 5, { 0.72, 1 }, { width = 4.2 }, 6)
	spread("EO_ScrapHeapClean", 3, { 0.4, 0.85 }, { height = 3 }, 6)
	spread("EO_BarrelCluster", 3, { 0.45, 0.9 }, {}, 5)
	spread("EO_SupplySacksMesh", 3, { 0.45, 0.9 }, {}, 5)
	spread("EO_LooseStonesClean", 16, { 0.2, 0.95 }, { width = 2, solid = false }, 3.5)
	spread("EO_ReedStubbleMesh", 24, { 0.7, 1.06 }, { height = 1.5, solid = false }, 2.5)
end

-- Builds Haven Square once (a server's World is built at start; Scenery calls this).
function Haven.build(world: Instance, origin: Vector3)
	if world:FindFirstChild("Haven") then
		return
	end
	collisionGroups()
	local folder = Instance.new("Folder")
	folder.Name = "Haven"
	folder:SetAttribute("SafeZone", true)
	folder.Parent = world
	campfireCircle(folder, origin)
	stalls(folder, origin)
	lounge(folder, origin)
	guildSpot(folder, origin)
	local notices =
		board(folder, CFrame.new(origin + Vector3.new(-14, 0, -56)) * CFrame.Angles(0, math.rad(180), 0), "NOTICES", 5)
	interactive(notices, "board.notice", "Notice Board", "Read")
	dressing(folder, origin)
	clutter(folder, origin)
end

return Haven
