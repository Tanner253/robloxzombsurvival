--!strict
--[[
	World/Haven: builds Haven Square, the public safe zone in the middle of every
	Neighbourhood (MVP_LAUNCH; LDoE's Settlement, rec4_01), from grade-A kit models and
	exact geometry in real materials (checklist §0: no stand-ins).

	LDoE's settlement is dense: stacked crates, stalls with goods, string lights and
	candles, tarps, vehicles, people in groups, a lit fire with seats. The square follows
	it: a tight oval inside a palisade, every edge packed with stores.

	Layout (studs from the World origin, north = -Z; Domain/Neighbourhood):
	- the campfire circle in the middle under string lights, two settlers sitting at it;
	- the Trader's stall (west) and the Trail Keeper's stall with the contract board
	  (east): striped awnings over tables of wares, stock stacked behind;
	- the north avenue to the Trail gate, its guard, the notice board, the cook's fire and
	  the mess table (north-west), the pickup and the fuel pump (north-east);
	- the VIP Lounge (south-east): its own fence, a gate only members pass, its own fire
	  and seats, the Lounge Warden at the gate;
	- the guild banner spot, the well and the hay corner (south-west), the van (south);
	- the palisade round the rim, open where the road and the trail pass;
	- stores packed along the inside of the rim and seeded clutter between.

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
local SIT_ANIMATION = "rbxassetid://2506281703" -- the survivor rig's sit (its Animate set)
-- A seated rig's root sits this high over the seat's top: in the sit pose its thighs reach
-- 1.42 studs under the root (measured on the survivor rig).
local SIT_LIFT = 1.44
local WOOD = Art.decks[1]
local POST = Color3.fromRGB(128, 98, 66)
local DARK_WOOD = Color3.fromRGB(78, 58, 42)
local PAPER = Color3.fromRGB(196, 182, 150)
local GOLD = Color3.fromHex("FFD27A")
local GREETING = Color3.fromHex("F0B85A") -- LDoE's floating line over an NPC (rec4_01)
local EMBER = Color3.fromRGB(255, 138, 61)
local WARM = Color3.fromRGB(255, 142, 58)
-- Neon renders about twice its colour, so a deep orange glows warm orange, not yellow.
local BULB = Color3.fromRGB(255, 84, 24)
local WAX = Color3.fromRGB(196, 176, 136)
local WIRE = Color3.fromRGB(34, 28, 24)
local CANVAS = Color3.fromRGB(200, 184, 146)
local TARP_OCHRE = Color3.fromRGB(150, 116, 54) -- LDoE's yellow tarps (rec4_01), weathered
local TARP_RED = Color3.fromRGB(122, 58, 46)
local TARP_OLIVE = Color3.fromRGB(88, 94, 62)
local IRON = Color3.fromRGB(92, 90, 88)
local COPPER = Color3.fromRGB(178, 106, 62)
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

-- Small dressing nobody bumps into, clicks or stands on.
local function inert(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Timber in the wood deck's planks (the same boards the outposts are built from).
local function wood(parent: Instance, size: Vector3, cframe: CFrame, color: Color3?): Part
	local p = solid(parent, size, cframe, WOOD.base, color or POST)
	p.MaterialVariant = WOOD.variant
	return p
end

-- A plank or a stick from `from` to `to`.
local function beam(parent: Instance, from: Vector3, to: Vector3, thickness: number, color: Color3?): Part
	local span = to - from
	return wood(
		parent,
		Vector3.new(thickness, thickness, span.Magnitude),
		CFrame.lookAt((from + to) / 2, to),
		color or DARK_WOOD
	)
end

-- A sheet of canvas or tarp.
local function canvas(parent: Instance, size: Vector3, cframe: CFrame, color: Color3): Part
	local sheet = solid(parent, size, cframe, Enum.Material.Fabric, color)
	sheet.CanTouch = false
	return sheet
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

-- A warm pool of light hung `lift` studs over `part`.
local function pool(part: BasePart, lift: number, range: number, brightness: number)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Pool"
	attachment.Position = Vector3.new(0, lift, 0)
	attachment.Parent = part
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = WARM
	light.Shadows = false
	light.Parent = attachment
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
		-- A warm pool under each of the square's lanterns, dark between them (rec4_01).
		local lamp = Models.lanternGlow(model)
		if lamp then
			lamp.Brightness = 1.1
			lamp.Range = 14
			lamp.Color = Color3.fromRGB(255, 168, 96)
		end
	end
	model.Parent = parent
	return model
end

-- The lowest point of a model in the world (its parts' corners), for laying it on a surface.
local function lowest(model: Model): number
	local low = math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, corner in
				{
					Vector3.new(1, 1, 1),
					Vector3.new(1, 1, -1),
					Vector3.new(1, -1, 1),
					Vector3.new(1, -1, -1),
					Vector3.new(-1, 1, 1),
					Vector3.new(-1, 1, -1),
					Vector3.new(-1, -1, 1),
					Vector3.new(-1, -1, -1),
				}
			do
				low = math.min(low, (part.CFrame * (half * corner)).Y)
			end
		end
	end
	return low
end

-- A kit model laid down flat on a surface (a tool on a table): its longest side `length`
-- studs, turned so its thinnest side is up, its underside resting at `at`.
local function lay(parent: Instance, name: string, length: number, at: CFrame): Model?
	local model = Models.kit({ name })
	if model == nil then
		return nil
	end
	model:PivotTo(CFrame.identity)
	local _, box = model:GetBoundingBox()
	local longest = math.max(box.X, box.Y, box.Z)
	if longest > 0.01 then
		model:ScaleTo(model:GetScale() * length / longest)
		box *= length / longest
	end
	local turn = CFrame.identity
	if box.Z < box.Y and box.Z <= box.X then
		turn = CFrame.Angles(math.rad(90), 0, 0)
	elseif box.X < box.Y and box.X < box.Z then
		turn = CFrame.Angles(0, 0, math.rad(90))
	end
	model:PivotTo(at * turn)
	model:PivotTo(model:GetPivot() + Vector3.new(0, at.Position.Y - lowest(model), 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			inert(part)
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
	inert(core)
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
	-- The warm pool: lit from above the stones so the ring doesn't shadow it, a pool with
	-- blue night past its edge (LDoE rec4_01's warm pools), not a blanket over the square.
	pool(core, 3, size * 3.7, 1.9)
end

-- A cluster of lit candles standing on a surface (`at` is the surface under them), the
-- tallest throwing a small warm pool (rec4_01's candles on every crate).
local function candles(parent: Instance, at: CFrame, count: number)
	local tallest: BasePart? = nil
	for index = 1, count do
		local height = 0.45 + ((index * 7) % 5) * 0.12
		local angle = math.rad(index * 137)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (if index == 1 then 0 else 0.42)
		local base = (at * CFrame.new(offset)).Position
		local wax = solid(
			parent,
			Vector3.new(height, 0.3, 0.3),
			CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.SmoothPlastic,
			WAX
		)
		wax.Shape = Enum.PartType.Cylinder
		inert(wax)
		local flame = solid(
			parent,
			Vector3.new(0.17, 0.17, 0.17),
			CFrame.new(base + Vector3.new(0, height + 0.12, 0)),
			Enum.Material.Neon,
			Color3.fromRGB(255, 92, 28)
		)
		flame.Shape = Enum.PartType.Ball
		inert(flame)
		if index == 1 then
			tallest = flame
		end
	end
	if tallest then
		pool(tallest, 1.2, 7, 1.1)
	end
end

-- A string of bulbs sagging from `from` to `to`, every third bulb lighting the ground.
local function stringLights(parent: Instance, from: Vector3, to: Vector3, bulbs: number, sag: number)
	local model = Instance.new("Model")
	model.Name = "StringLights"
	local steps = bulbs + 1
	local previous = from
	for index = 1, steps do
		local t = index / steps
		local here = from:Lerp(to, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		local span = here - previous
		inert(
			solid(
				model,
				Vector3.new(0.06, 0.06, span.Magnitude),
				CFrame.lookAt((previous + here) / 2, here),
				Enum.Material.SmoothPlastic,
				WIRE
			)
		)
		if index < steps then
			local bulb = solid(
				model,
				Vector3.new(0.36, 0.36, 0.36),
				CFrame.new(here - Vector3.new(0, 0.24, 0)),
				Enum.Material.Neon,
				BULB
			)
			bulb.Shape = Enum.PartType.Ball
			inert(bulb)
			if index % 3 == 2 then
				pool(bulb, -0.4, 9, 0.7)
			end
		end
		previous = here
	end
	model.Parent = parent
end

-- A tall timber pole for string lights; returns where the string ties on.
local function pole(parent: Instance, at: Vector3, height: number): Vector3
	wood(parent, Vector3.new(0.6, height, 0.6), CFrame.new(at + Vector3.new(0, height / 2, 0)), DARK_WOOD)
	return at + Vector3.new(0, height - 0.5, 0)
end

-- A tarp thrown over a load (`top` is its top centre): a sheet a little wider than it,
-- one corner flap hanging down the front.
local function drape(parent: Instance, top: CFrame, size: Vector3, color: Color3)
	canvas(
		parent,
		Vector3.new(size.X + 0.3, 0.08, size.Z + 0.2),
		top * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(3)),
		color
	)
	canvas(
		parent,
		Vector3.new(size.X * 0.7, size.Y, 0.08),
		top * CFrame.new(-size.X * 0.15, -size.Y / 2 + 0.05, -size.Z / 2 - 0.12) * CFrame.Angles(math.rad(-6), 0, 0),
		color
	)
end

-- Two crates side by side, a third on top, sometimes a tarp thrown over (rec4_01).
local function crateStack(parent: Instance, frame: CFrame, tarp: Color3?)
	local first = kit(parent, "EO_StorageCrate", frame * CFrame.new(-1.75, 0, 0) * CFrame.Angles(0, math.rad(4), 0), {
		width = 3.3,
	})
	kit(
		parent,
		"EO_StorageCrate",
		frame * CFrame.new(1.75, 0, 0.2) * CFrame.Angles(0, math.rad(-5), 0),
		{ width = 3.3 }
	)
	if first == nil then
		return
	end
	local low = first:GetExtentsSize().Y
	local top = kit(parent, "EO_StorageCrate", frame * CFrame.new(0.3, low, 0.1) * CFrame.Angles(0, math.rad(9), 0), {
		width = 3.1,
	})
	if top == nil then
		return
	end
	local high = low + top:GetExtentsSize().Y
	if tarp then
		drape(
			parent,
			frame * CFrame.new(0.3, high, 0.1) * CFrame.Angles(0, math.rad(9), 0),
			Vector3.new(3.4, 1.6, 3.3),
			tarp
		)
	else
		candles(parent, frame * CFrame.new(0.3, high, 0.1), 3)
	end
end

-- A washing line between two poles, clothes pegged out along it.
local function washingLine(parent: Instance, from: Vector3, to: Vector3)
	local height = 5.4
	local a = pole(parent, from, height + 0.5)
	local b = pole(parent, to, height + 0.5)
	local span = b - a
	inert(
		solid(
			parent,
			Vector3.new(0.06, 0.06, span.Magnitude),
			CFrame.lookAt((a + b) / 2, b),
			Enum.Material.Fabric,
			WIRE
		)
	)
	local colors = {
		Color3.fromRGB(150, 140, 118),
		Color3.fromRGB(96, 104, 120),
		Color3.fromRGB(128, 72, 58),
		Color3.fromRGB(176, 166, 140),
		Color3.fromRGB(92, 98, 70),
	}
	local count = #colors
	for index, color in colors do
		local t = (index - 0.5) / count
		local at = a:Lerp(b, t) - Vector3.new(0, 0.5 * 4 * t * (1 - t), 0)
		local tall = 1.3 + (index % 3) * 0.3
		inert(
			canvas(
				parent,
				Vector3.new(1.3, tall, 0.05),
				CFrame.lookAt(at, at + span.Unit) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, -tall / 2, 0),
				color
			)
		)
	end
end

-- Iron or copper bars in a little crossed stack on a surface.
local function ingots(parent: Instance, at: CFrame, color: Color3)
	for _, x in { -0.46, 0, 0.46 } do
		solid(parent, Vector3.new(0.4, 0.28, 1), at * CFrame.new(x, 0.14, 0), Enum.Material.Metal, color)
	end
	for _, z in { -0.24, 0.24 } do
		solid(parent, Vector3.new(1, 0.28, 0.4), at * CFrame.new(0, 0.42, z), Enum.Material.Metal, color)
	end
end

-- Bolts of cloth lying on a surface: two side by side, one in the groove on top.
local function clothRolls(parent: Instance, at: CFrame)
	local colors = { Color3.fromRGB(122, 72, 56), Color3.fromRGB(94, 104, 120), Color3.fromRGB(152, 138, 100) }
	for index, spot in { Vector3.new(0, 0.36, -0.37), Vector3.new(0, 0.36, 0.37), Vector3.new(0, 0.96, 0) } do
		local roll =
			solid(parent, Vector3.new(2.1, 0.72, 0.72), at * CFrame.new(spot), Enum.Material.Fabric, colors[index])
		roll.Shape = Enum.PartType.Cylinder
		inert(roll)
	end
end

-- A table of planks on four legs; returns its top surface frame.
local function plankTable(parent: Instance, frame: CFrame, length: number, depth: number): CFrame
	local height = 3
	wood(parent, Vector3.new(length, 0.3, depth), frame * CFrame.new(0, height - 0.15, 0))
	for _, x in { -length / 2 + 0.4, length / 2 - 0.4 } do
		for _, z in { -depth / 2 + 0.3, depth / 2 - 0.3 } do
			wood(parent, Vector3.new(0.32, height - 0.3, 0.32), frame * CFrame.new(x, (height - 0.3) / 2, z), DARK_WOOD)
		end
	end
	return frame * CFrame.new(0, height, 0)
end

-- A plank bench; returns its seat surface frame.
local function bench(parent: Instance, frame: CFrame, length: number): CFrame
	local height = 1.7
	wood(parent, Vector3.new(length, 0.3, 1.1), frame * CFrame.new(0, height - 0.15, 0))
	for _, x in { -length / 2 + 0.5, length / 2 - 0.5 } do
		wood(parent, Vector3.new(0.9, height - 0.3, 0.3), frame * CFrame.new(x, (height - 0.3) / 2, 0), DARK_WOOD)
	end
	return frame * CFrame.new(0, height, 0)
end

-- A crate or a sack of stores to sit on by a fire, facing it (a seat on its top). Returns
-- the seat's surface frame, facing the fire.
local function propSeat(parent: Instance, at: Vector3, toward: Vector3, name: string): CFrame?
	local frame = facing(at, toward)
	local prop = kit(parent, name, frame, { width = if name == "EO_StorageCrate" then 3.2 else 3.6 })
	if prop == nil then
		return nil
	end
	local top = frame + Vector3.new(0, prop:GetExtentsSize().Y, 0)
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(2, 0.2, 1.6)
	seat.CFrame = top + Vector3.new(0, 0.05, 0)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Parent = prop
	return top
end

-- Crates and sacks in a ring around a fire, gaps between them to walk through. Returns
-- each seat's surface frame.
local SEATS = { "EO_StorageCrate", "EO_SupplySacksMesh" }

local function seatRing(parent: Instance, centre: Vector3, radius: number, count: number, offset: number): { CFrame }
	local tops = {}
	for index = 0, count - 1 do
		local angle = math.rad(offset + index * 360 / count)
		local at = centre + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local top = propSeat(parent, at, centre, SEATS[index % #SEATS + 1])
		if top then
			table.insert(tops, top)
		end
	end
	return tops
end

local function interactive(model: Model, havenId: string, label: string, verb: string)
	model:SetAttribute("HavenId", havenId)
	model:SetAttribute("Label", label)
	model:SetAttribute("Verb", verb)
	CollectionService:AddTag(model, Haven.TAG)
end

-- People -------------------------------------------------------------------------------------------

-- The ground's height under a point: the terrain the square is painted on.
local function groundBelow(at: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(at + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else nil
end

-- The lowest point of a rig's feet (their parts' corners), for resting them on the ground.
local FEET = { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }

function Haven.lowestFoot(rig: Model): number?
	local low: number? = nil
	for _, name in FEET do
		local foot = rig:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			local half = foot.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = (foot.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z)).Y
						low = if low then math.min(low, corner) else corner
					end
				end
			end
		end
	end
	return low
end

type Look = { jacket: string, pants: string, keepsPack: boolean? }
type Pose = "idle" | "sit"

--[[
	The survivor rig as a settler: outfit tints, standing in its idle or seated on a seat
	surface. `frame` is where the feet stand (or the seat's top), facing the way the
	settler looks. Returns the rig, parented and posed.
]]
local function figure(parent: Instance, name: string, look: Look, frame: CFrame, pose: Pose): Model?
	local template = StarterPlayer:FindFirstChild("StarterCharacter")
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local rig = template:Clone()
	rig.Name = name
	for _, child in rig:GetChildren() do
		local pack = child:IsA("Accessory") and not look.keepsPack
		if child:IsA("LuaSourceContainer") or child.Name == "InitialPoses" or pack then
			child:Destroy()
		end
	end
	local jacket, trousers = Color3.fromHex(look.jacket), Color3.fromHex(look.pants)
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			local surface = part:FindFirstChildOfClass("SurfaceAppearance")
			if surface and JACKET[part.Name] then
				surface.Color = jacket
			elseif surface and TROUSERS[part.Name] then
				surface.Color = trousers
			end
		end
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		rig:Destroy()
		return nil
	end
	root.Anchored = true
	root.CanCollide = pose == "idle"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	-- Placed by the root (the rig's own pivot is at its feet): standing on the ground, or
	-- seated with the thighs on the seat.
	local lift = if pose == "sit" then SIT_LIFT else humanoid.HipHeight + root.Size.Y / 2
	-- Standing settlers stand on the ground actually under them (the terrain), not on the
	-- frame's height.
	local ground = if pose == "idle" then groundBelow(frame.Position) else nil
	local base = if ground then frame + Vector3.new(0, ground - frame.Position.Y, 0) else frame
	rig:PivotTo((base + Vector3.new(0, lift, 0)) * root.CFrame:ToObjectSpace(rig:GetPivot()))
	-- Then rest the feet exactly on it, whatever the rig's proportions (the root stays anchored).
	local low = if ground then Haven.lowestFoot(rig) else nil
	if ground and low then
		rig:PivotTo(rig:GetPivot() + Vector3.new(0, ground - low, 0))
	end
	rig.Parent = parent
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.AnimationId = if pose == "sit" then SIT_ANIMATION else IDLE_ANIMATION
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = true
		track:Play(0)
		track.TimePosition = (#name % 5) * 0.4 -- not all in step
	end
	return rig
end

-- Gear in a settler's fist or across the back (the same mounts a player's gear uses).
local function carry(rig: Model, itemId: string, mount: Models.Mount)
	local def = Content.Items[itemId]
	local held = if def then Models.held(itemId, def, mount) else nil
	local where, anchor = Models.mountFrame(rig, mount)
	if held and where and anchor then
		Models.mount(held, where, anchor)
		held.model.Parent = rig
	end
end

-- A named NPC (Data/Haven.npcs): a settler tagged for talking to, the greeting floating
-- over the head when you are near (rec4_01).
local function npc(parent: Instance, npcId: string, at: Vector3, toward: Vector3)
	local def = Content.Haven.npcs[npcId]
	if def == nil then
		return
	end
	local rig = figure(
		parent,
		def.name,
		{ jacket = def.jacket, pants = def.pants, keepsPack = def.keepsPack },
		facing(at, toward),
		"idle"
	)
	if rig == nil then
		return
	end
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
end

-- The settlers who live here (not talked to): worn work clothes, each a little different.
local SETTLERS: { [string]: Look } = {
	firesideA = { jacket = "6E7A58", pants = "5A544C" },
	firesideB = { jacket = "8C6A52", pants = "4E4E54", keepsPack = true },
	cook = { jacket = "B8A88A", pants = "6A5E50" },
	diner = { jacket = "5E6E7E", pants = "605A50" },
	mechanic = { jacket = "7A6448", pants = "4A4C50" },
	guard = { jacket = "4E5A44", pants = "4A463E", keepsPack = true },
}

local function settler(parent: Instance, id: string, frame: CFrame, pose: Pose): Model?
	return figure(parent, "Settler", SETTLERS[id], frame, pose)
end

local function collisionGroups()
	for _, group in { Haven.GATE_GROUP, Haven.MEMBER_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(Haven.GATE_GROUP, Haven.MEMBER_GROUP, false)
end

-- Pieces -----------------------------------------------------------------------------------------

-- A market stall in its own frame (front toward -Z, origin at the ground centre): four
-- posts, a roof sloping to the front, a striped canvas awning out over a table of wares,
-- the name on a board over the eave, stock stacked behind and beside it.
local STALL = { width = 16, depth = 10, front = 8.4, back = 10.2 }
-- The awning: out from the front eave and down (studs), in this many stripes.
local AWNING = { reach = 3.8, drop = 1.6, stripes = 9 }

type RoofShape = { width: number, depth: number, front: number, back: number }

-- A roof: two kit wall panels (scrap sheet or timber) laid side by side over the posts,
-- sloping from the back eave (height `back`) down to the front (`front`), overhanging
-- every side. Real textured sheet, never a flat-coloured slab.
local function roof(parent: Instance, frame: CFrame, panelName: string, shape: RoofShape?)
	local dims: RoofShape = shape or STALL
	local w, d = dims.width, dims.depth
	local rise = dims.back - dims.front
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
				* CFrame.new(side * (w / 4 + 0.15), dims.back + 0.35, d / 2 + 0.8)
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

-- An open shed in its own frame (front toward -Z): four posts under a kit-panel roof.
local function shed(parent: Instance, frame: CFrame, panelName: string, shape: RoofShape)
	for _, x in { -shape.width / 2, shape.width / 2 } do
		wood(
			parent,
			Vector3.new(0.5, shape.front, 0.5),
			frame * CFrame.new(x, shape.front / 2, -shape.depth / 2),
			DARK_WOOD
		)
		wood(
			parent,
			Vector3.new(0.5, shape.back, 0.5),
			frame * CFrame.new(x, shape.back / 2, shape.depth / 2),
			DARK_WOOD
		)
	end
	roof(parent, frame, panelName, shape)
end

-- The striped awning hung from the front eave, with a scalloped valance along its edge.
local function awning(parent: Instance, frame: CFrame, accent: Color3)
	local w, d = STALL.width + 1.4, STALL.depth
	local slope = math.atan2(AWNING.drop, AWNING.reach)
	local length = math.sqrt(AWNING.reach ^ 2 + AWNING.drop ^ 2)
	local stripe = w / AWNING.stripes
	local edge = frame * CFrame.new(0, STALL.front + 0.25, -d / 2 - 0.9)
	for index = 1, AWNING.stripes do
		local x = -w / 2 + stripe * (index - 0.5)
		local color = if index % 2 == 1 then accent else CANVAS
		canvas(
			parent,
			Vector3.new(stripe + 0.02, 0.08, length),
			edge * CFrame.new(x, 0, 0) * CFrame.Angles(slope, 0, 0) * CFrame.new(0, 0, -length / 2),
			color
		)
		-- The valance: a short flap hanging from the awning's outer edge.
		canvas(
			parent,
			Vector3.new(stripe + 0.02, 0.62, 0.06),
			edge * CFrame.new(x, -AWNING.drop - 0.3, -AWNING.reach - 0.02),
			color
		)
	end
end

local function stall(parent: Instance, frame: CFrame, roofPanel: string, title: string, accent: Color3): Model
	local folder = Instance.new("Model")
	folder.Name = title
	local w, d = STALL.width, STALL.depth
	for _, x in { -w / 2, w / 2 } do
		wood(folder, Vector3.new(0.7, STALL.front, 0.7), frame * CFrame.new(x, STALL.front / 2, -d / 2), DARK_WOOD)
		wood(folder, Vector3.new(0.7, STALL.back, 0.7), frame * CFrame.new(x, STALL.back / 2, d / 2), DARK_WOOD)
	end
	roof(folder, frame, roofPanel)
	awning(folder, frame, accent)
	-- The name board stands on the front eave, over the awning, readable from the square.
	local sign = wood(
		folder,
		Vector3.new(w * 0.66, 1.7, 0.3),
		frame * CFrame.new(0, STALL.front + 1.55, -d / 2 - 0.55) * CFrame.Angles(math.rad(-8), 0, 0),
		DARK_WOOD
	)
	paint(sign, Enum.NormalId.Front, title, GOLD)
	-- Bulbs along the awning's edge.
	stringLights(
		folder,
		(frame * CFrame.new(-w / 2 - 0.7, STALL.front - AWNING.drop - 0.55, -d / 2 - 0.9 - AWNING.reach)).Position,
		(frame * CFrame.new(w / 2 + 0.7, STALL.front - AWNING.drop - 0.55, -d / 2 - 0.9 - AWNING.reach)).Position,
		8,
		0.35
	)
	-- The back counter: three crates of stock under the roof, sacks on one end, the scrap
	-- wall behind as shelving.
	local crateTop = 0
	for index, x in { -5.4, 0, 5.4 } do
		local crate =
			kit(folder, "EO_StorageCrate", frame * CFrame.new(x, 0, 1.6) * CFrame.Angles(0, math.rad(index * 3 - 6), 0))
		if crate then
			crateTop = crate:GetExtentsSize().Y
		end
	end
	kit(folder, "EO_SupplySacksMesh", frame * CFrame.new(-5.4, crateTop, 1.6) * CFrame.Angles(0, math.rad(20), 0), {
		width = 3,
		solid = false,
	})
	kit(folder, "EO_BarrelCluster", frame * CFrame.new(5.2, crateTop, 1.8) * CFrame.Angles(0, math.rad(-30), 0), {
		width = 2.6,
		solid = false,
	})
	kit(folder, "WallScrap", frame * CFrame.new(0, 0, d / 2 + 1.4))
	candles(folder, frame * CFrame.new(0, crateTop, 1.6), 3)
	kit(folder, "EO_LanternPost", frame * CFrame.new(-w / 2 - 1.4, 0, -d / 2 - 1.2) * CFrame.Angles(0, math.rad(90), 0))
	-- Stock round the outside: barrels by the front post, a tarped stack beside the back.
	kit(folder, "EO_BarrelCluster", frame * CFrame.new(-w / 2 - 2.6, 0, -1.5) * CFrame.Angles(0, math.rad(35), 0))
	crateStack(folder, frame * CFrame.new(w / 2 + 2.6, 0, 2.8) * CFrame.Angles(0, math.rad(90), 0), accent)
	kit(folder, "EO_SupplySacksMesh", frame * CFrame.new(-w / 2 - 2.4, 0, 3.2) * CFrame.Angles(0, math.rad(-30), 0))
	folder.WorldPivot = frame
	folder.Parent = parent
	return folder
end

-- The table of wares under a stall's awning, in the stall's frame; returns its top.
local function wareTable(parent: Instance, frame: CFrame): CFrame
	return plankTable(parent, frame * CFrame.new(0, 0, -STALL.depth / 2 - 1.7), 11, 2.4)
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

-- One length of palisade from `from` to `to`, in the timber or the scrap kit panel.
local function fenceSegment(parent: Instance, from: Vector3, to: Vector3, panelName: string)
	local span = to - from
	local model = Models.kit({ panelName })
	if model == nil or span.Magnitude < 0.5 then
		return
	end
	Models.fitEdgeTo(model, span.Magnitude, FENCE_HEIGHT)
	local mid = (from + to) / 2
	model:PivotTo(CFrame.lookAt(mid, mid + span.Unit) * CFrame.Angles(0, math.rad(90), 0))
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanTouch = false
		end
	end
	model.Parent = parent
end

-- A straight run of palisade from `from` to `to`, in segments of about FENCE_SEGMENT.
local function fenceRun(parent: Instance, from: Vector3, to: Vector3)
	local span = to - from
	local count = math.max(1, math.round(span.Magnitude / FENCE_SEGMENT))
	local step = span / count
	for index = 1, count do
		fenceSegment(parent, from + step * (index - 1), from + step * index, "WallWood")
	end
end

-- The square --------------------------------------------------------------------------------------

-- Ground spots the square keeps clear (offsets from its middle): the road through it, the
-- avenue north to the Trail gate, the spawn, the Lounge.
local function kept(x: number, z: number): boolean
	return math.abs(z) < 9
		or (math.abs(x) < 8 and z < -12)
		or (x * x + (z - 22) ^ 2 < 49)
		or Neighbourhood.inLounge(x, z)
end

local function campfireCircle(folder: Instance, origin: Vector3)
	local circle = Instance.new("Folder")
	circle.Name = "CampfireCircle"
	kit(circle, "EO_CampfireRing", CFrame.new(origin), { width = 7 })
	fire(circle, origin, 5)
	local tops = seatRing(circle, origin, 8.6, 5, 18)
	-- Two settlers warm their hands at it.
	if tops[3] then
		settler(circle, "firesideA", tops[3], "sit")
	end
	if tops[5] then
		settler(circle, "firesideB", tops[5], "sit")
	end
	-- Firewood stacked by the ring.
	kit(circle, "EO_BareBranches", yawed(origin + Vector3.new(-5.2, 0, 3.6), 40), { width = 3.6, solid = false })
	kit(circle, "EO_BareBranches", yawed(origin + Vector3.new(4.8, 0, -4.2), -70), { width = 3.2, solid = false })
	-- String lights over the circle: two poles each side, strung across and out to the stalls.
	local nw = pole(circle, origin + Vector3.new(-13, 0, -11), 10)
	local ne = pole(circle, origin + Vector3.new(13, 0, -11), 10)
	local sw = pole(circle, origin + Vector3.new(-13, 0, 12), 10)
	local se = pole(circle, origin + Vector3.new(13, 0, 12), 10)
	-- Corner to corner high over the fire, and along the north side toward the stalls.
	stringLights(circle, nw, se, 13, 1.8)
	stringLights(circle, ne, sw, 13, 1.8)
	stringLights(circle, nw, ne, 10, 1.3)
	-- Stores either side of the avenue's mouth, candles burning on them.
	crateStack(circle, facing(origin + Vector3.new(-12, 0, -18), origin + Vector3.new(0, 0, -18)), nil)
	crateStack(circle, facing(origin + Vector3.new(12, 0, -18), origin + Vector3.new(0, 0, -18)), nil)
	circle.Parent = folder
end

local function stalls(folder: Instance, origin: Vector3)
	local w, d = STALL.width, STALL.depth
	-- The Trader faces east across the square, the Trail Keeper west.
	local trader = CFrame.new(origin + Vector3.new(-29, 0, -22)) * CFrame.Angles(0, math.rad(-90), 0)
	local tradingPost = stall(folder, trader, "WallScrap", "TRADING POST", TARP_RED)
	-- Her wares: tools, iron and copper bars, bolts of cloth, candles.
	local top = wareTable(tradingPost, trader)
	lay(tradingPost, "EO_StoneHatchet", 1.8, top * CFrame.new(-4.4, 0, 0) * CFrame.Angles(0, math.rad(80), 0))
	lay(tradingPost, "EO_StonePick", 2.2, top * CFrame.new(-2.8, 0, 0.1) * CFrame.Angles(0, math.rad(100), 0))
	ingots(tradingPost, top * CFrame.new(-1, 0, -0.2) * CFrame.Angles(0, math.rad(8), 0), IRON)
	ingots(tradingPost, top * CFrame.new(0.5, 0, 0.3) * CFrame.Angles(0, math.rad(-12), 0), COPPER)
	clothRolls(tradingPost, top * CFrame.new(2.6, 0, 0) * CFrame.Angles(0, math.rad(4), 0))
	candles(tradingPost, top * CFrame.new(4.6, 0, 0.2), 3)
	npc(folder, "npc.trader", (trader * CFrame.new(w / 2 - 0.6, 0, -d / 2 - 2.2)).Position, origin)

	local keeper = CFrame.new(origin + Vector3.new(29, 0, -22)) * CFrame.Angles(0, math.rad(90), 0)
	local trailKeeper = stall(folder, keeper, "WallWood", "TRAIL KEEPER", TARP_OLIVE)
	-- His table: maps of the trail, the ledger of jobs, a bow, candles.
	local desk = wareTable(trailKeeper, keeper)
	for index, spot in { Vector3.new(-3.6, 0.03, 0), Vector3.new(-2, 0.05, 0.2), Vector3.new(-0.6, 0.03, -0.1) } do
		inert(
			solid(
				trailKeeper,
				Vector3.new(1.7, 0.04, 1.3),
				desk * CFrame.new(spot) * CFrame.Angles(0, math.rad(index * 11 - 18), 0),
				Enum.Material.Cardboard,
				PAPER
			)
		)
	end
	local rolled = solid(
		trailKeeper,
		Vector3.new(1.5, 0.26, 0.26),
		desk * CFrame.new(-1.2, 0.13, 0.8) * CFrame.Angles(0, math.rad(12), 0),
		Enum.Material.Cardboard,
		PAPER
	)
	rolled.Shape = Enum.PartType.Cylinder
	inert(rolled)
	inert(
		solid(
			trailKeeper,
			Vector3.new(1, 0.24, 1.3),
			desk * CFrame.new(0.9, 0.12, 0) * CFrame.Angles(0, math.rad(-8), 0),
			Enum.Material.Fabric,
			Color3.fromRGB(70, 46, 34)
		)
	)
	lay(trailKeeper, "EO_Shortbow", 2.8, desk * CFrame.new(3, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
	candles(trailKeeper, desk * CFrame.new(-4.7, 0, 0.3), 2)
	kit(folder, "EO_WorkbenchP2", keeper * CFrame.new(-w / 2 - 3.6, 0, 1.5) * CFrame.Angles(0, math.rad(90), 0))
	npc(folder, "npc.keeper", (keeper * CFrame.new(-w / 2 + 0.6, 0, -d / 2 - 2.2)).Position, origin)
	local contracts = board(folder, keeper * CFrame.new(w / 2 + 4.5, 0, -1.5), "CONTRACTS", 3)
	interactive(contracts, "board.contracts", "Contract Board", "Read")
end

-- North-west: the cook's fire with a pot on a tripod, the mess table, a settler eating.
local function cookhouse(folder: Instance, origin: Vector3)
	local model = Instance.new("Folder")
	model.Name = "Cookhouse"
	local pit = origin + Vector3.new(-26, 0, -44)
	kit(model, "EO_CampfireRing", CFrame.new(pit), { width = 4.4 })
	fire(model, pit, 2.6)
	local apex = pit + Vector3.new(0, 4.4, 0)
	for index = 0, 2 do
		local angle = math.rad(index * 120 + 20)
		beam(model, pit + Vector3.new(math.cos(angle) * 2.2, 0, math.sin(angle) * 2.2), apex, 0.2)
	end
	inert(
		solid(model, Vector3.new(0.05, 1.4, 0.05), CFrame.new(apex - Vector3.new(0, 0.7, 0)), Enum.Material.Metal, WIRE)
	)
	local pot = solid(
		model,
		Vector3.new(1.1, 1.5, 1.5),
		CFrame.new(apex - Vector3.new(0, 1.95, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Metal,
		Color3.fromRGB(46, 43, 40)
	)
	pot.Shape = Enum.PartType.Cylinder
	inert(pot)
	settler(model, "cook", facing(pit + Vector3.new(3.4, 0, 1.6), pit), "idle")
	kit(model, "EO_SupplySacksMesh", yawed(pit + Vector3.new(-2.6, 0, 3.4), 40))
	kit(model, "EO_BarrelCluster", yawed(pit + Vector3.new(1.2, 0, -3.6), -15), { width = 3.2 })

	-- The mess table, east-west, benches either side, a settler at supper.
	local mess = CFrame.new(origin + Vector3.new(-17, 0, -36))
	local top = plankTable(model, mess, 8, 2.6)
	bench(model, mess * CFrame.new(0, 0, -2.3), 8)
	local seat = bench(model, mess * CFrame.new(0, 0, 2.3), 8)
	settler(model, "diner", seat * CFrame.new(1.6, 0, 0.1), "sit")
	candles(model, top * CFrame.new(-2.4, 0, 0), 3)
	local bowl = solid(
		model,
		Vector3.new(0.3, 0.8, 0.8),
		top * CFrame.new(1.6, 0.15, 0.5) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Wood,
		DARK_WOOD
	)
	bowl.Shape = Enum.PartType.Cylinder
	inert(bowl)
	model.Parent = folder
end

-- North: the Trail gate (posts, crossbar, the name, bulbs) with its guard, the notice board
-- by the avenue, the pickup and the fuel pump to the east.
local function trailGate(folder: Instance, origin: Vector3)
	local model = Instance.new("Folder")
	model.Name = "TrailGate"
	local z = -Content.Tuning.plots.plazaDepthStuds + 2
	for _, x in { -8.5, 8.5 } do
		wood(model, Vector3.new(1, 11, 1), CFrame.new(origin + Vector3.new(x, 5.5, z)), DARK_WOOD)
	end
	wood(model, Vector3.new(19, 0.8, 0.8), CFrame.new(origin + Vector3.new(0, 10.4, z)), DARK_WOOD)
	local sign = wood(model, Vector3.new(9, 1.6, 0.4), CFrame.new(origin + Vector3.new(0, 9.1, z + 0.1)), DARK_WOOD)
	paint(sign, Enum.NormalId.Back, "THE TRAIL", GOLD)
	paint(sign, Enum.NormalId.Front, "HAVEN", GOLD)
	stringLights(model, origin + Vector3.new(-8, 10, z + 0.6), origin + Vector3.new(8, 10, z + 0.6), 9, 1.1)
	kit(model, "EO_LanternPost", yawed(origin + Vector3.new(-11.5, 0, z + 2.5), 90))
	kit(model, "EO_LanternPost", yawed(origin + Vector3.new(11.5, 0, z + 2.5), -90))
	-- The guard: an axe in hand, a bow across the back, watching the square.
	local guard = settler(model, "guard", facing(origin + Vector3.new(5.6, 0, z + 5.5), origin), "idle")
	if guard then
		carry(guard, "item.fire_axe", "hand")
		carry(guard, "item.shortbow", "back")
	end
	model.Parent = folder

	local notices = board(
		folder,
		CFrame.new(origin + Vector3.new(-12.5, 0, -50)) * CFrame.Angles(0, math.rad(200), 0),
		"NOTICES",
		5
	)
	interactive(notices, "board.notice", "Notice Board", "Read")

	local yard = Instance.new("Folder")
	yard.Name = "Yard"
	kit(yard, "EO_PickupWreck", yawed(origin + Vector3.new(18, 0, -47), 25))
	kit(yard, "EO_FuelPump", yawed(origin + Vector3.new(27.5, 0, -41), -60), { height = 5.6 })
	kit(yard, "EO_BarrelCluster", yawed(origin + Vector3.new(25, 0, -45.5), 10), { width = 3.4 })
	settler(yard, "mechanic", facing(origin + Vector3.new(11.5, 0, -41.5), origin + Vector3.new(18, 0, -47)), "idle")
	crateStack(yard, yawed(origin + Vector3.new(10.5, 0, -51), 20), TARP_OCHRE)
	yard.Parent = folder
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
	-- Inside: the members' fire with its seats under bulbs, lamps in the corners, stores at
	-- the back.
	local centre = at(gateX, (rect.z0 + rect.z1) / 2 + 1)
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
	-- Bulbs along the fence tops: both sides and the back.
	local lift = Vector3.new(0, FENCE_HEIGHT + 0.6, 0)
	local corners = {
		at(rect.x0 + 0.5, rect.z0 + 0.5) + lift,
		at(rect.x0 + 0.5, rect.z1 - 0.5) + lift,
		at(rect.x1 - 0.5, rect.z1 - 0.5) + lift,
		at(rect.x1 - 0.5, rect.z0 + 0.5) + lift,
	}
	for index = 1, 3 do
		stringLights(model, corners[index], corners[index + 1], 10, 0.9)
	end
	crateStack(model, yawed(at(rect.x1 - 6, rect.z1 - 3.4), 180), TARP_RED)
	kit(model, "EO_SupplySacksMesh", yawed(at(rect.x0 + 7, rect.z1 - 3.6), 30))
	kit(model, "EO_BarrelCluster", yawed(at(rect.x0 + 4, rect.z1 - 8), -20))
	model.Parent = folder
	npc(folder, "npc.warden", at(gateX + half + 4.5, rect.z0 - 4), origin)
end

-- South-west: the guild banner spot (empty until guilds arrive, M3), the well, the hay
-- corner under a lean-to tarp; south: the van parked against the rim.
local function southside(folder: Instance, origin: Vector3)
	local model = Instance.new("Model")
	model.Name = "GuildBanner"
	-- Turned to face south a little east, toward the camera (it always looks north) and
	-- the sun, so the banner reads lit instead of as a dark slab.
	local base = CFrame.new(origin + Vector3.new(-23, 0, 38)) * CFrame.Angles(0, math.rad(200), 0)
	for _, x in { -4.4, 4.4 } do
		wood(model, Vector3.new(0.9, 11, 0.9), base * CFrame.new(x, 5.5, 0), DARK_WOOD)
		kit(model, "EO_LooseStonesClean", base * CFrame.new(x, 0, 0.6) * CFrame.Angles(0, math.rad(x * 20), 0), {
			solid = false,
		})
	end
	wood(model, Vector3.new(10.6, 0.7, 0.7), base * CFrame.new(0, 10.5, 0), DARK_WOOD)
	-- An unclaimed banner: plain weathered canvas until a guild raises its colours (M3).
	local cloth =
		canvas(model, Vector3.new(5.8, 6.6, 0.12), base * CFrame.new(0, 6.9, 0), Color3.fromRGB(170, 154, 122))
	cloth.Name = "Banner"
	cloth.CanCollide = false
	kit(model, "EO_LanternPost", base * CFrame.new(-7.5, 0, -1) * CFrame.Angles(0, math.rad(90), 0))
	kit(model, "EO_LanternPost", base * CFrame.new(7.5, 0, -1) * CFrame.Angles(0, math.rad(-90), 0))
	-- Guilds (M3) hang their banner on the crossbar.
	model:SetAttribute("GuildBannerSpot", true)
	model.WorldPivot = base
	model.Parent = folder

	local yard = Instance.new("Folder")
	yard.Name = "Southside"
	local function at(x: number, z: number): Vector3
		return origin + Vector3.new(x, 0, z)
	end
	-- The well, west of the spawn, its buckets' barrels beside it.
	kit(yard, "EO_SpringBasin", yawed(at(-31, 17), 20), { width = 8 })
	kit(yard, "EO_BarrelCluster", yawed(at(-36.5, 23), 80), { width = 3.4 })
	-- The hay barn: an open timber shed over the bales, more stacked beside it.
	local barn = yawed(at(-10, 49), 0)
	shed(yard, barn, "WallWood", { width = 10, depth = 6, front = 5.4, back = 6.6 })
	kit(yard, "EO_HayBales", barn * CFrame.new(0, 0, 0.4), { width = 7 })
	kit(yard, "EO_HayBales", yawed(at(-21, 48), -14), { width = 6 })
	-- The stores: a scrap-roofed shed over a table of goods south of the spawn, washing
	-- hung out east.
	local stores = yawed(at(-3, 39), 0)
	shed(yard, stores, "WallScrap", { width = 9, depth = 5, front = 6, back = 7 })
	local top = plankTable(yard, stores * CFrame.new(0, 0, -0.4), 7, 2.4)
	kit(yard, "EO_SupplySacksMesh", top * CFrame.new(-2.2, 0, 0) * CFrame.Angles(0, math.rad(15), 0), {
		width = 2.2,
		solid = false,
	})
	clothRolls(yard, top * CFrame.new(0.6, 0, 0))
	candles(yard, top * CFrame.new(2.8, 0, 0.2), 2)
	kit(
		yard,
		"EO_BarrelCluster",
		stores * CFrame.new(-5.6, 0, -1.6) * CFrame.Angles(0, math.rad(30), 0),
		{ width = 3.2 }
	)
	washingLine(yard, at(9, 30), at(9, 44))
	-- The van against the south rim, stores stacked by it.
	kit(yard, "EO_VanWreck", yawed(at(4, 57.5), 4))
	crateStack(yard, yawed(at(-1.5, 52), -6), nil)
	yard.Parent = folder
end

-- The palisade round the rim: an oval of timber panels, open
-- where the road and the trail pass, the Lounge's own fence closing the south-east.
local function palisade(folder: Instance, origin: Vector3)
	local plots = Content.Tuning.plots
	local model = Instance.new("Folder")
	model.Name = "Palisade"
	local a, b = plots.plazaHalfStuds * 1.05, plots.plazaDepthStuds * 1.04
	local steps = 48
	local function point(index: number): Vector3
		local t = index / steps * math.pi * 2
		return Vector3.new(math.cos(t) * a, 0, math.sin(t) * b)
	end
	for index = 0, steps - 1 do
		local from, to = point(index), point(index + 1)
		local mid = (from + to) / 2
		local road = math.abs(mid.Z) < 17
		local trail = mid.Z < 0 and math.abs(mid.X) < 10
		local inLounge = mid.X > 12 and mid.Z > 18
		if not (road or trail or inLounge) then
			fenceSegment(model, origin + from, origin + to, "WallWood")
		end
	end
	-- Lanterns where the road enters and leaves.
	for _, spot in { { -41, -18 }, { -41, 18 }, { 41, -18 } } do
		kit(model, "EO_LanternPost", facing(origin + Vector3.new(spot[1], 0, spot[2]), origin))
	end
	model.Parent = folder
end

-- Stores packed along the inside of the rim: crate stacks with candles burning on them,
-- barrels, sacks and hay, wherever nothing else stands.
local STORES_SEED = 9127

local function edgeStores(folder: Instance, origin: Vector3)
	local random = Random.new(STORES_SEED)
	local plots = Content.Tuning.plots
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local model = Instance.new("Folder")
	model.Name = "Stores"
	model.Parent = folder
	local count = 64
	for index = 0, count - 1 do
		local t = (index + random:NextNumber(-0.3, 0.3)) / count * math.pi * 2
		local reach = random:NextNumber(0.82, 0.95)
		local x, z = math.cos(t) * reach * plots.plazaHalfStuds, math.sin(t) * reach * plots.plazaDepthStuds
		local roll = random:NextNumber()
		local open = math.abs(z) < 17 or (z < 0 and math.abs(x) < 10) or (x > 10 and z > 16) or kept(x, z)
		local at = origin + Vector3.new(x, 0, z)
		if not open and #workspace:GetPartBoundsInRadius(at + Vector3.new(0, 2, 0), 3, params) == 0 then
			local frame = facing(at, origin) * CFrame.Angles(0, math.rad(random:NextInteger(-20, 20)), 0)
			if roll < 0.4 then
				crateStack(model, frame, nil)
			elseif roll < 0.58 then
				kit(model, "EO_BarrelCluster", frame)
			elseif roll < 0.76 then
				kit(model, "EO_SupplySacksMesh", frame)
			elseif roll < 0.9 then
				kit(model, "EO_HayBales", frame, { width = 5.5 })
			else
				local crate = kit(model, "EO_StorageCrate", frame)
				if crate then
					candles(model, frame + Vector3.new(0, crate:GetExtentsSize().Y, 0), 2)
				end
			end
		end
	end
end

-- Both verges of the road through the square lined like a market street: crate stacks
-- with candles, barrels, sacks, hay and firewood, the road itself left clear.
local VERGE_SEED = 5303

local function roadside(folder: Instance, origin: Vector3)
	local random = Random.new(VERGE_SEED)
	local plots = Content.Tuning.plots
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local model = Instance.new("Folder")
	model.Name = "Roadside"
	model.Parent = folder
	for _, side in { -1, 1 } do
		local x = -plots.plazaHalfStuds + 4
		while x < plots.plazaHalfStuds - 4 do
			local z = side * random:NextNumber(11.5, 14)
			local at = origin + Vector3.new(x, 0, z)
			local clear = #workspace:GetPartBoundsInRadius(at + Vector3.new(0, 2, 0), 2.8, params) == 0
			-- Paths into the fire circle stay open.
			if clear and math.abs(x) > 10 and not kept(x, z) then
				local frame = facing(at, Vector3.new(at.X, 0, origin.Z))
					* CFrame.Angles(0, math.rad(random:NextInteger(-25, 25)), 0)
				local roll = random:NextNumber()
				if roll < 0.32 then
					crateStack(model, frame, nil)
				elseif roll < 0.5 then
					kit(model, "EO_BarrelCluster", frame)
				elseif roll < 0.66 then
					kit(model, "EO_SupplySacksMesh", frame)
				elseif roll < 0.8 then
					kit(model, "EO_HayBales", frame, { width = 5.5 })
				else
					kit(model, "EO_BareBranches", frame, { width = 3.6, solid = false })
				end
			end
			x += random:NextNumber(5.5, 8)
		end
	end
end

-- Seeded clutter between the features so the trodden ground never reads empty: fieldstones,
-- stubble tufts toward the rim, rocks and scrap. Nothing lands on a feature, in a kept
-- spot, or on another piece.
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
		if Neighbourhood.inLounge(x, z) or (math.abs(x) < 8 and z < -12) or (x * x + (z - 22) ^ 2 < 49) then
			return false -- the Lounge, the avenue north, the spawn
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
	spread("EO_ScrapHeapClean", 3, { 0.4, 0.85 }, { height = 3 }, 4.5)
	spread("EO_RockCluster", 3, { 0.75, 1 }, { width = 3.6 }, 4.5)
	spread("EO_LooseStonesClean", 20, { 0.2, 0.95 }, { width = 2, solid = false }, 2.5)
	spread("EO_ReedStubbleMesh", 20, { 0.75, 1.02 }, { height = 1.5, solid = false }, 2)
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
	cookhouse(folder, origin)
	trailGate(folder, origin)
	lounge(folder, origin)
	southside(folder, origin)
	palisade(folder, origin)
	edgeStores(folder, origin)
	roadside(folder, origin)
	clutter(folder, origin)
end

return Haven
