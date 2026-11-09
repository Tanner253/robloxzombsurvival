--!strict
--[[
	World/Haven: builds Haven Square, the public safe zone in the middle of every
	Neighbourhood (MVP_LAUNCH; LDoE's Settlement, rec4_01), from grade-A kit models and
	exact geometry in real materials (checklist §0: no stand-ins).

	Layout (studs from the World origin, north = -Z; Domain/Neighbourhood):
	- the campfire circle in the middle: a lit stone ring and stump seats;
	- the Trader's stall (north-west) and the Trail Keeper's stall with the contract board
	  (north-east); the notice board where the trail leaves north;
	- the VIP Lounge (south-east), the best-dressed spot in Haven: a wrought-iron fence on a
	  stone plinth (see-through: non-members watch the traders from outside), a stone gate
	  with the lit brass Members plaque, a velvet rope (members see it unhooked) and gold
	  banners; inside, a plank deck with rugs, a large brazier, the leather seating under a
	  striped awning, the bar with the Fence behind it, the Quartermaster's table, string
	  lanterns. The Gatekeeper stands at the rope;
	- the public comforts (south-west, by the spawn): the Well (clean water) and the Soup
	  Kitchen (a stall, the stew pot over its fire, the cook);
	- the guild banner spot (south-west), empty until guilds arrive (M3);
	- lanterns around the edge and dense camp dressing.

	Everything the player can talk to or read carries the EO_Haven tag and the HavenId,
	Label and Verb attributes (Controllers/Interaction). Members-only NPCs carry MembersOnly.
	Services/Haven runs it. Props come from kit models graded A (Art.approved); one not yet
	approved is left out and the piece that needs it falls back to an approved one.
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
-- The velvet rope across the Lounge gate: members' clients hide it (it reads unhooked).
Haven.ROPE_TAG = "EO_VelvetRope"
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
-- The Lounge's dressing: wrought iron, brass, dressed stone, velvet, rugs and canvas.
local IRON = Color3.fromRGB(46, 41, 38)
local BRASS = Color3.fromRGB(196, 152, 78)
local STONE = Color3.fromRGB(150, 138, 122)
local CAP_STONE = Color3.fromRGB(118, 110, 100)
local VELVET = Color3.fromRGB(128, 24, 34)
local OXBLOOD = Color3.fromRGB(104, 34, 32)
local CREAM = Color3.fromRGB(206, 188, 150)
local BULB = Color3.fromRGB(255, 196, 120)
local LOUNGE_FLOOR = 0.35 -- the plank deck's top above the ground
local FENCE_PICKET = 0.9 -- studs between iron pickets
local FENCE_POST = 4.4 -- studs between iron posts
local PLINTH = 0.9 -- the stone plinth's height under the iron
local IRON_HEIGHT = 4.8 -- the pickets above the plinth

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

-- A detail part: no collision, no queries, optionally no shadow (thin iron, bulbs, cloth).
local function trim(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	shadow: boolean?
): Part
	local p = solid(parent, size, cframe, material, color)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = shadow ~= false
	return p
end

-- A round bar from `a` to `b` (iron pickets, poles, rope).
local function bar(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	diameter: number,
	material: Enum.Material,
	color: Color3,
	shadow: boolean?
): Part
	local length = (b - a).Magnitude
	local p = trim(
		parent,
		Vector3.new(length, diameter, diameter),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
		material,
		color,
		shadow
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, at: Vector3, diameter: number, material: Enum.Material, color: Color3): Part
	local p = trim(parent, Vector3.one * diameter, CFrame.new(at), material, color, false)
	p.Shape = Enum.PartType.Ball
	return p
end

-- An invisible wall from `from` to `to` (the fence's collision: nothing squeezes between
-- pickets or hops the iron). Not queried, so clicks and the camera pass through.
local function barrier(parent: Instance, from: Vector3, to: Vector3, height: number): Part
	local span = to - from
	local wall = solid(
		parent,
		Vector3.new(0.8, height, span.Magnitude),
		CFrame.lookAt((from + to) / 2 + Vector3.new(0, height / 2, 0), to + Vector3.new(0, height / 2, 0)),
		Enum.Material.SmoothPlastic,
		IRON
	)
	wall.Name = "Barrier"
	wall.Transparency = 1
	wall.CanQuery = false
	wall.CanTouch = false
	wall.CastShadow = false
	return wall
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

-- The VIP Lounge's pieces ---------------------------------------------------------------------------

-- A straight run of wrought-iron fence from `from` to `to` (ground points): a dressed-stone
-- plinth with a capping course, square posts with ball finials every FENCE_POST, two flat
-- rails, round pickets every FENCE_PICKET with spear tips, and the invisible wall that
-- keeps everyone but members out (see-through: the traders show from the road).
local function ironFence(parent: Instance, from: Vector3, to: Vector3)
	local model = Instance.new("Model")
	model.Name = "IronFence"
	local span = to - from
	local length = span.Magnitude
	local dir = span.Unit
	local frame = CFrame.lookAt(from, to) -- -Z runs along the fence
	local function along(distance: number, height: number): Vector3
		return (frame * CFrame.new(0, height, -distance)).Position
	end
	local plinth = solid(
		model,
		Vector3.new(0.9, PLINTH, length + 0.9),
		CFrame.lookAt(from:Lerp(to, 0.5) + Vector3.new(0, PLINTH / 2 - 0.2, 0), to + Vector3.new(0, PLINTH / 2 - 0.2, 0)),
		Enum.Material.Cobblestone,
		STONE
	)
	plinth.Name = "Plinth"
	solid(
		model,
		Vector3.new(1.1, 0.22, length + 1.1),
		CFrame.lookAt(from:Lerp(to, 0.5) + Vector3.new(0, PLINTH - 0.09, 0), to + Vector3.new(0, PLINTH - 0.09, 0)),
		Enum.Material.Slate,
		CAP_STONE
	)
	local base = PLINTH + 0.02
	local posts = math.max(1, math.round(length / FENCE_POST))
	for index = 0, posts do
		local at = along(length * index / posts, base)
		trim(model, Vector3.new(0.42, IRON_HEIGHT + 0.5, 0.42), CFrame.lookAt(at, at + dir) + Vector3.new(0, (IRON_HEIGHT + 0.5) / 2, 0), Enum.Material.Metal, IRON)
		ball(model, at + Vector3.new(0, IRON_HEIGHT + 0.72, 0), 0.6, Enum.Material.Metal, IRON)
	end
	for _, height in { 0.45, IRON_HEIGHT - 0.6 } do
		trim(
			model,
			Vector3.new(0.12, 0.22, length),
			CFrame.lookAt(from:Lerp(to, 0.5), to) + Vector3.new(0, base + height, 0),
			Enum.Material.Metal,
			IRON,
			false
		)
	end
	local pickets = math.max(1, math.floor(length / FENCE_PICKET))
	for index = 1, pickets - 1 do
		local distance = length * index / pickets
		local foot = along(distance, base)
		local top = foot + Vector3.new(0, IRON_HEIGHT, 0)
		bar(model, foot, top, 0.16, Enum.Material.Metal, IRON, false)
		-- The spear tip: a small iron diamond.
		trim(
			model,
			Vector3.new(0.12, 0.3, 0.3),
			CFrame.lookAt(top, top + dir) * CFrame.new(0, 0.18, 0) * CFrame.Angles(math.rad(45), 0, 0),
			Enum.Material.Metal,
			IRON,
			false
		)
	end
	barrier(model, from, to, 10)
	model.Parent = parent
end

-- A tall ember-gold banner on an iron pole, its face toward `look`: the cloth with an
-- oxblood border, the campfire emblem, a brass finial.
local function banner(parent: Instance, at: Vector3, look: Vector3)
	local model = Instance.new("Model")
	model.Name = "Banner"
	local frame = facing(at, look)
	bar(model, at, at + Vector3.new(0, 11, 0), 0.32, Enum.Material.Metal, IRON)
	ball(model, at + Vector3.new(0, 11.2, 0), 0.5, Enum.Material.Metal, BRASS)
	bar(model, (frame * CFrame.new(-1.7, 10.4, -0.3)).Position, (frame * CFrame.new(1.7, 10.4, -0.3)).Position, 0.18, Enum.Material.Metal, BRASS)
	local cloth = trim(model, Vector3.new(3, 6.2, 0.1), frame * CFrame.new(0, 7.2, -0.32), Enum.Material.Fabric, GOLD)
	cloth.Name = "Cloth"
	for _, x in { -1.38, 1.38 } do
		trim(model, Vector3.new(0.24, 6.2, 0.2), frame * CFrame.new(x, 7.2, -0.37), Enum.Material.Fabric, OXBLOOD)
	end
	trim(model, Vector3.new(3, 0.5, 0.2), frame * CFrame.new(0, 4.35, -0.37), Enum.Material.Fabric, OXBLOOD)
	-- The emblem: the campfire glyph, stitched in oxblood (a decal on a clear plate just
	-- proud of the cloth).
	local plate = trim(model, Vector3.new(2, 2, 0.02), frame * CFrame.new(0, 7.6, -0.43), Enum.Material.SmoothPlastic, GOLD, false)
	plate.Transparency = 1
	local emblem = Instance.new("Decal")
	emblem.Face = Enum.NormalId.Front
	emblem.Texture = Art.glyphs.campfire
	emblem.Color3 = OXBLOOD
	emblem.Parent = plate
	model.Parent = parent
end

-- A rug lying on the floor (`frame` at floor level): a gold border, an oxblood field, a
-- dark inner panel, each layer's top 0.06 above the one under it (no z-fighting).
local function rug(parent: Instance, frame: CFrame, width: number, depth: number)
	local layers = {
		{ inset = 0, color = BRASS },
		{ inset = 0.6, color = OXBLOOD },
		{ inset = 2.4, color = Color3.fromRGB(70, 30, 30) },
	}
	for index, layer in layers do
		local top = 0.06 * index
		local p = trim(
			parent,
			Vector3.new(width - layer.inset, top, depth - layer.inset),
			frame * CFrame.new(0, top / 2, 0),
			Enum.Material.Fabric,
			layer.color,
			false
		)
		p.Name = "Rug"
	end
end

-- A striped canvas awning on four dark posts over (x0..x1, z0..z1), sloping from `back`
-- studs high at z1 down to `front` at z0, with a scalloped valance along the front.
local function awning(parent: Instance, base: Vector3, x0: number, x1: number, z0: number, z1: number, front: number, back: number)
	local model = Instance.new("Model")
	model.Name = "Awning"
	for _, corner in { { x0, z0, front }, { x1, z0, front }, { x0, z1, back }, { x1, z1, back } } do
		wood(model, Vector3.new(0.6, corner[3], 0.6), CFrame.new(base + Vector3.new(corner[1], corner[3] / 2, corner[2])), DARK_WOOD)
	end
	local rise = back - front
	local depth = z1 - z0
	local slope = math.atan2(rise, depth)
	local length = math.sqrt(depth * depth + rise * rise) + 1.6
	local stripes = math.max(2, math.round((x1 - x0 + 1.6) / 1.8))
	local stripe = (x1 - x0 + 1.6) / stripes
	local centre = base + Vector3.new(0, (front + back) / 2 + 0.35, (z0 + z1) / 2)
	for index = 1, stripes do
		local x = x0 - 0.8 + stripe * (index - 0.5)
		trim(
			model,
			Vector3.new(stripe, 0.12, length),
			CFrame.new(Vector3.new(base.X + x, centre.Y, centre.Z)) * CFrame.Angles(-slope, 0, 0),
			Enum.Material.Fabric,
			if index % 2 == 0 then CREAM else OXBLOOD
		)
		-- The valance: a tab per stripe hanging off the front edge.
		trim(
			model,
			Vector3.new(stripe - 0.08, 0.8, 0.1),
			CFrame.new(base + Vector3.new(x, front - 0.05, z0 - 0.75)),
			Enum.Material.Fabric,
			if index % 2 == 0 then CREAM else OXBLOOD,
			false
		)
	end
	model.Parent = parent
end

-- String lanterns hung between points, sagging between each pair: warm bulbs every ~2.2
-- studs on a dark wire, every fourth one lighting the floor.
local function stringLights(parent: Instance, points: { Vector3 })
	local model = Instance.new("Model")
	model.Name = "StringLights"
	local count = 0
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local span = (b - a).Magnitude
		local steps = math.max(2, math.round(span / 2.2))
		local sag = span * 0.08
		local previous = a
		for step = 1, steps do
			local t = step / steps
			local at = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
			bar(model, previous, at, 0.06, Enum.Material.SmoothPlastic, IRON, false)
			previous = at
			if step < steps then
				count += 1
				local bulb = ball(model, at - Vector3.new(0, 0.2, 0), 0.34, Enum.Material.Neon, BULB)
				if count % 4 == 0 then
					local light = Instance.new("PointLight")
					light.Range = 9
					light.Brightness = 0.9
					light.Color = Color3.fromRGB(255, 176, 104)
					light.Shadows = false
					light.Parent = bulb
				end
			end
		end
	end
	model.Parent = parent
end

-- A brass stanchion: weighted base, post, ball top; returns the rope's anchor point.
local function stanchion(parent: Instance, at: Vector3): Vector3
	local foot = trim(parent, Vector3.new(0.18, 0.9, 0.9), CFrame.new(at + Vector3.new(0, 0.09, 0)) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, BRASS)
	foot.Shape = Enum.PartType.Cylinder
	foot.CanCollide = true
	bar(parent, at, at + Vector3.new(0, 3.1, 0), 0.2, Enum.Material.Metal, BRASS)
	ball(parent, at + Vector3.new(0, 3.2, 0), 0.38, Enum.Material.Metal, BRASS)
	return at + Vector3.new(0, 2.95, 0)
end

-- The velvet rope between two stanchions, sagging. Members see it unhooked: the client
-- hides "VelvetRope" for them (Controllers/Interaction).
local function velvetRope(parent: Instance, a: Vector3, b: Vector3)
	local model = Instance.new("Model")
	model.Name = "VelvetRope"
	local steps = 8
	local previous = a
	for step = 1, steps do
		local t = step / steps
		local at = a:Lerp(b, t) - Vector3.new(0, 0.9 * 4 * t * (1 - t), 0)
		bar(model, previous, at, 0.22, Enum.Material.Fabric, VELVET, false)
		previous = at
	end
	model.Parent = parent
end

-- The survivor rig as an NPC (Data/Haven.npcs): outfit tints, the idle animation, the
-- greeting floating over the head when you are near (rec4_01), tagged for talking to (or,
-- for the cook, for using her comfort). Members-only NPCs carry the MembersOnly attribute.
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
	local comfort = if def.uses then Content.Haven.comforts[def.uses] else nil
	if comfort then
		interactive(rig, comfort.id, `at the {comfort.name}`, comfort.verb)
	else
		interactive(rig, def.id, def.name, "Talk")
	end
	rig:SetAttribute("NpcId", def.id)
	if def.membersOnly then
		rig:SetAttribute("MembersOnly", true)
	end

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

-- Sets a model down so its lowest point rests at height `y` (no prop hovers or sinks).
local function restOn(model: Model, y: number)
	local lowest = math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, corner in
				{
					Vector3.new(-1, -1, -1),
					Vector3.new(1, -1, -1),
					Vector3.new(-1, -1, 1),
					Vector3.new(1, -1, 1),
					Vector3.new(-1, 1, -1),
					Vector3.new(1, 1, -1),
					Vector3.new(-1, 1, 1),
					Vector3.new(1, 1, 1),
				}
			do
				lowest = math.min(lowest, (part.CFrame * (half * corner)).Y)
			end
		end
	end
	if lowest < math.huge then
		model:PivotTo(model:GetPivot() + Vector3.new(0, y - lowest, 0))
	end
end

-- Moves a model across so its bounding box is centred on (x, z).
local function centreOn(model: Model, x: number, z: number)
	local box = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(x - box.Position.X, 0, z - box.Position.Z))
end

-- A gun laid on its side on a table top at `top`, its barrel along `yaw` (the
-- Quartermaster's display: the real held models, so the table shows what he sells).
local function displayGun(parent: Instance, name: string, top: Vector3, yaw: number, length: number)
	local gun = kit(parent, name, CFrame.new(top) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(90), 0, 0), {
		height = length,
		solid = false,
	})
	if gun then
		restOn(gun, top.Y + 0.02)
		centreOn(gun, top.X, top.Z)
	end
end

-- A water splash or a steam puff for a comfort's moment (Haven.burst emits it).
local function burstEmitter(holder: Instance, kind: "water" | "steam")
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Enabled = false
	if kind == "water" then
		burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		burst.Color = ColorSequence.new(Color3.fromRGB(196, 222, 230))
		burst.Size = NumberSequence.new(0.35, 0.1)
		burst.Lifetime = NumberRange.new(0.4, 0.7)
		burst.Speed = NumberRange.new(5, 8)
		burst.SpreadAngle = Vector2.new(30, 30)
		burst.Acceleration = Vector3.new(0, -30, 0)
	else
		burst.Texture = "rbxasset://textures/particles/smoke_main.dds"
		burst.Color = ColorSequence.new(Color3.fromRGB(226, 220, 210))
		burst.Transparency = NumberSequence.new(0.45, 1)
		burst.Size = NumberSequence.new(1, 2.6)
		burst.Lifetime = NumberRange.new(1, 1.6)
		burst.Speed = NumberRange.new(2, 3.5)
		burst.SpreadAngle = Vector2.new(20, 20)
	end
	burst.Parent = holder
end

local function lounge(folder: Instance, origin: Vector3)
	local rect = Neighbourhood.lounge
	local model = Instance.new("Folder")
	model.Name = "VipLounge"
	local function at(x: number, z: number): Vector3
		return origin + Vector3.new(x, 0, z)
	end
	-- Inside the fence everything stands on the plank deck.
	local function on(x: number, z: number): Vector3
		return origin + Vector3.new(x, LOUNGE_FLOOR, z)
	end
	local gateX = (rect.x0 + rect.x1) / 2
	local half = rect.gateWidth / 2
	local pillarX = half + 0.8

	-- The deck: dark stained planks over the whole yard, a slate threshold at the gate.
	local deck = wood(
		model,
		Vector3.new(rect.x1 - rect.x0 - 1.2, 1, rect.z1 - rect.z0 - 1.2),
		CFrame.new(origin + Vector3.new(gateX, LOUNGE_FLOOR - 0.5, (rect.z0 + rect.z1) / 2)),
		Color3.fromRGB(150, 106, 72)
	)
	deck.Name = "Deck"
	local threshold = solid(
		model,
		Vector3.new(rect.gateWidth, LOUNGE_FLOOR, 1.8),
		CFrame.new(at(gateX, rect.z0 - 0.2) + Vector3.new(0, LOUNGE_FLOOR / 2, 0)),
		Enum.Material.Slate,
		CAP_STONE
	)
	threshold.Name = "Threshold"

	-- The fence: iron on a stone plinth, corner piers, runs ending in the gate pillars.
	ironFence(model, at(rect.x0, rect.z0), at(gateX - pillarX, rect.z0))
	ironFence(model, at(gateX + pillarX, rect.z0), at(rect.x1, rect.z0))
	ironFence(model, at(rect.x1, rect.z0), at(rect.x1, rect.z1))
	ironFence(model, at(rect.x1, rect.z1), at(rect.x0, rect.z1))
	ironFence(model, at(rect.x0, rect.z1), at(rect.x0, rect.z0))
	for _, corner in { { rect.x0, rect.z0 }, { rect.x1, rect.z0 }, { rect.x1, rect.z1 }, { rect.x0, rect.z1 } } do
		local foot = at(corner[1], corner[2])
		solid(model, Vector3.new(1.3, 1.6, 1.3), CFrame.new(foot + Vector3.new(0, 0.6, 0)), Enum.Material.Cobblestone, STONE)
		solid(model, Vector3.new(1.5, 0.24, 1.5), CFrame.new(foot + Vector3.new(0, 1.52, 0)), Enum.Material.Slate, CAP_STONE)
	end

	-- The gate: dressed-stone pillars with lamps, the brass VIP LOUNGE board across them, the
	-- lit Members plaque on each pillar, the barrier only members pass.
	for _, side in { -1, 1 } do
		local foot = at(gateX + side * pillarX, rect.z0)
		solid(model, Vector3.new(1.6, 7.6, 1.6), CFrame.new(foot + Vector3.new(0, 3.6, 0)), Enum.Material.Cobblestone, STONE)
		solid(model, Vector3.new(2, 0.4, 2), CFrame.new(foot + Vector3.new(0, 7.6, 0)), Enum.Material.Slate, CAP_STONE)
		local lamp = ball(model, foot + Vector3.new(0, 10.15, 0), 0.8, Enum.Material.Neon, BULB)
		local glow = Instance.new("PointLight")
		glow.Range = 14
		glow.Brightness = 1.6
		glow.Color = Color3.fromRGB(255, 176, 104)
		glow.Shadows = false
		glow.Parent = lamp
		-- The plaque: brass on the pillar's road face, lit from its own lamp above.
		local plaque = trim(
			model,
			Vector3.new(1.3, 0.85, 0.12),
			CFrame.new(foot + Vector3.new(0, 4.6, -0.92)),
			Enum.Material.Metal,
			BRASS
		)
		plaque.Name = "MembersPlaque"
		paint(plaque, Enum.NormalId.Front, "MEMBERS", Color3.fromRGB(46, 30, 18))
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 70
		light.Range = 5
		light.Brightness = 2.4
		light.Color = Color3.fromRGB(255, 196, 132)
		light.Shadows = false
		light.Parent = trim(
			model,
			Vector3.new(0.5, 0.18, 0.3),
			CFrame.new(foot + Vector3.new(0, 5.35, -0.98)) * CFrame.Angles(math.rad(-50), 0, 0),
			Enum.Material.Metal,
			BRASS
		)
	end
	for _, side in { -1, 1 } do
		-- Iron struts from the pillar caps up to the board.
		bar(
			model,
			at(gateX + side * pillarX, rect.z0) + Vector3.new(0, 7.8, 0),
			at(gateX + side * pillarX, rect.z0) + Vector3.new(0, 8.4, 0),
			0.28,
			Enum.Material.Metal,
			IRON
		)
	end
	local loungeBoard = solid(
		model,
		Vector3.new(rect.gateWidth + 3.6, 1.4, 0.3),
		CFrame.new(at(gateX, rect.z0) + Vector3.new(0, 9.05, 0)),
		Enum.Material.Metal,
		BRASS
	)
	loungeBoard.Name = "LoungeBoard"
	paint(loungeBoard, Enum.NormalId.Front, "VIP LOUNGE", Color3.fromRGB(46, 30, 18))
	paint(loungeBoard, Enum.NormalId.Back, "VIP LOUNGE", Color3.fromRGB(46, 30, 18))
	local gate = solid(
		model,
		Vector3.new(rect.gateWidth, 10, 0.6),
		CFrame.new(at(gateX, rect.z0) + Vector3.new(0, 5, 0)),
		Enum.Material.SmoothPlastic,
		Color3.new()
	)
	gate.Name = "Gate"
	gate.Transparency = 1
	gate.CanQuery = false
	gate.CanTouch = false
	gate.CollisionGroup = Haven.GATE_GROUP

	-- The rope across the gate, the lamps and the banners on the road side.
	local ropeA = stanchion(model, at(gateX - 3.1, rect.z0 - 1.5))
	local ropeB = stanchion(model, at(gateX + 3.1, rect.z0 - 1.5))
	local rope = Instance.new("Folder")
	rope.Name = "Rope"
	velvetRope(rope, ropeA, ropeB)
	CollectionService:AddTag(rope, Haven.ROPE_TAG)
	rope.Parent = model
	kit(model, "EO_LanternPost", yawed(at(gateX - pillarX - 2, rect.z0 - 1.8), 90))
	kit(model, "EO_LanternPost", yawed(at(gateX + pillarX + 2, rect.z0 - 1.8), -90))
	local road = at(gateX, rect.z0 - 30)
	banner(model, at(gateX - 10, rect.z0 - 1.2), road)
	banner(model, at(gateX + 10, rect.z0 - 1.2), road)

	-- Inside: the runner from the gate to the brazier.
	rug(model, CFrame.new(on(gateX, rect.z0 + 6)), 3.4, 10)
	local brazierAt = on(gateX, rect.z0 + 17.5)
	local brazier = kit(model, "EO_Brazier", CFrame.new(brazierAt))
	if brazier then
		fire(model, brazierAt + Vector3.new(0, brazier:GetExtentsSize().Y * 0.7, 0), 3.4)
	else
		kit(model, "EO_CampfireRing", CFrame.new(brazierAt), { width = 5 })
		fire(model, brazierAt, 4.2)
	end

	-- The seating under the awning, on the big rug, facing the brazier.
	local seatsAt = on(gateX, rect.z0 + 27)
	rug(model, CFrame.new(seatsAt), 15, 10)
	kit(model, "EO_LoungeSeating", CFrame.new(seatsAt + Vector3.new(0, 0.18, 0)))
	awning(model, origin + Vector3.new(0, LOUNGE_FLOOR, 0), gateX - 8.5, gateX + 8.5, rect.z0 + 21.5, rect.z0 + 34, 7.4, 8.6)

	-- The bar along the east fence, the Fence behind it; barrels and a crate at its ends.
	local barAt = on(rect.x1 - 4.8, rect.z0 + 16)
	kit(model, "EO_BarCounter", CFrame.new(barAt))
	npc(model, "npc.fence", on(rect.x1 - 1.8, rect.z0 + 16), on(gateX, rect.z0 + 16))
	kit(model, "EO_BarrelCluster", yawed(on(rect.x1 - 3, rect.z0 + 8.6), 30))
	kit(model, "EO_StorageCrate", yawed(on(rect.x1 - 3.6, rect.z0 + 24.4), 84))

	-- The Quartermaster's table on the west side: two crates under oiled cloth with his guns
	-- laid out, more stock behind.
	local tableTop = 0
	local tableX = rect.x0 + 5.6
	for index, z in { rect.z0 + 13.2, rect.z0 + 18.8 } do
		local crate = kit(model, "EO_StorageCrate", yawed(on(tableX, z), 90 + index * 2))
		if crate then
			local size = crate:GetExtentsSize()
			tableTop = size.Y
			trim(
				model,
				Vector3.new(size.X - 0.6, 0.06, size.Z - 0.6),
				crate:GetPivot() * CFrame.new(0, size.Y + 0.03, 0),
				Enum.Material.Fabric,
				Color3.fromRGB(70, 74, 58),
				false
			)
		end
	end
	if tableTop > 0 then
		local top = LOUNGE_FLOOR + tableTop + 0.06
		displayGun(model, "EO_ScrapShotgun", origin + Vector3.new(tableX, top, rect.z0 + 18.8), 0, 3.4)
		displayGun(model, "EO_WornPistol", origin + Vector3.new(tableX + 0.4, top, rect.z0 + 12.4), 20, 1.4)
		displayGun(model, "EO_Shortbow", origin + Vector3.new(tableX - 0.5, top, rect.z0 + 14.2), -10, 3.2)
	end
	npc(model, "npc.quartermaster", on(rect.x0 + 2.2, rect.z0 + 16), on(gateX, rect.z0 + 16))
	kit(model, "EO_StorageCrate", yawed(on(rect.x0 + 3.6, rect.z0 + 24.6), -6))
	kit(model, "EO_BarrelCluster", yawed(on(rect.x0 + 3.5, rect.z0 + 30), -20))
	kit(model, "EO_SupplySacksMesh", yawed(on(rect.x1 - 4, rect.z0 + 31), 30))

	-- Lamps in the corners, banners on the back fence above the awning.
	for _, corner in
		{
			{ rect.x0 + 3, rect.z0 + 4 },
			{ rect.x1 - 3, rect.z0 + 4 },
			{ rect.x0 + 3, rect.z1 - 3 },
			{ rect.x1 - 3, rect.z1 - 3 },
		}
	do
		kit(model, "EO_LanternPost", facing(on(corner[1], corner[2]), on(gateX, rect.z0 + 16)))
	end
	banner(model, on(gateX - 6, rect.z1 - 1.4), on(gateX, rect.z0))
	banner(model, on(gateX + 6, rect.z1 - 1.4), on(gateX, rect.z0))

	-- String lanterns: gate pillars to the awning, and across the front of the yard.
	local awningFront = rect.z0 + 21.5
	stringLights(model, {
		at(gateX - pillarX, rect.z0) + Vector3.new(0, 9.6, 0),
		on(gateX - 8.5, awningFront) + Vector3.new(0, 7.3, 0),
	})
	stringLights(model, {
		at(gateX + pillarX, rect.z0) + Vector3.new(0, 9.6, 0),
		on(gateX + 8.5, awningFront) + Vector3.new(0, 7.3, 0),
	})
	stringLights(model, {
		on(rect.x0 + 3, rect.z0 + 4) + Vector3.new(0, 8.4, 0),
		on(gateX, rect.z0 + 9) + Vector3.new(0, 9.4, 0),
		on(rect.x1 - 3, rect.z0 + 4) + Vector3.new(0, 8.4, 0),
	})
	model.Parent = folder

	-- The Gatekeeper at the rope, turned to the road.
	npc(folder, "npc.gatekeeper", at(gateX + 5.6, rect.z0 - 4.2), at(gateX - 2, rect.z0 - 16))
end

-- The public comforts ----------------------------------------------------------------------------

-- The Well (comfort.well), south-west of the fire: the stone basin with water in it under a
-- timber frame with a windlass, rope and bucket, and a little gabled roof.
local WELL_WIDTH = 6.4

local function well(folder: Instance, origin: Vector3)
	local base = origin + Vector3.new(-14, 0, 33)
	local model = Instance.new("Model")
	model.Name = "Well"
	local frame = CFrame.new(base) * CFrame.Angles(0, math.rad(20), 0)
	local basin = kit(model, "EO_SpringBasin", frame, { width = WELL_WIDTH })
	if basin == nil then
		return
	end
	-- The water: Art.springWater is in the 9-stud conformed frame; this basin is smaller.
	local spec = Art.springWater
	local scale = WELL_WIDTH / 9
	local water = trim(
		model,
		Vector3.new(0.1, spec.diameter * scale, spec.diameter * scale),
		frame * CFrame.new(spec.offset * scale) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Glass,
		spec.color,
		false
	)
	water.Name = "Water"
	water.Shape = Enum.PartType.Cylinder
	water.Reflectance = spec.reflectance
	local span = WELL_WIDTH / 2 + 0.5
	for _, side in { -1, 1 } do
		wood(model, Vector3.new(0.55, 6.85, 0.55), frame * CFrame.new(side * span, 3.425, 0), DARK_WOOD)
	end
	-- The windlass, its crank, the rope and the bucket above the water.
	local axle = bar(
		model,
		(frame * CFrame.new(-span, 4.7, 0)).Position,
		(frame * CFrame.new(span, 4.7, 0)).Position,
		0.55,
		WOOD.base,
		POST
	)
	axle.MaterialVariant = WOOD.variant
	bar(
		model,
		(frame * CFrame.new(span, 4.7, 0)).Position,
		(frame * CFrame.new(span + 0.7, 4.7, 0)).Position,
		0.16,
		Enum.Material.Metal,
		IRON
	)
	bar(
		model,
		(frame * CFrame.new(span + 0.7, 4.7, 0)).Position,
		(frame * CFrame.new(span + 0.7, 4.0, 0)).Position,
		0.16,
		Enum.Material.Metal,
		IRON
	)
	bar(model, (frame * CFrame.new(0, 4.45, 0)).Position, (frame * CFrame.new(0, 3.0, 0)).Position, 0.1, Enum.Material.Fabric, Color3.fromRGB(150, 128, 92), false)
	local bucket = trim(
		model,
		Vector3.new(0.9, 0.95, 0.95),
		frame * CFrame.new(0, 2.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
		WOOD.base,
		POST
	)
	bucket.Shape = Enum.PartType.Cylinder
	bucket.MaterialVariant = WOOD.variant
	bucket.Name = "Bucket"
	for _, y in { 2.3, 2.85 } do
		local hoop = trim(
			model,
			Vector3.new(0.1, 1.02, 1.02),
			frame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Metal,
			IRON,
			false
		)
		hoop.Shape = Enum.PartType.Cylinder
	end
	-- The roof: two boards meeting over the windlass.
	for _, side in { -1, 1 } do
		wood(
			model,
			Vector3.new(span * 2 + 1.4, 0.22, 2.4),
			frame * CFrame.new(0, 6.4, side * 0.95) * CFrame.Angles(side * math.rad(32), 0, 0),
			DARK_WOOD
		)
	end
	burstEmitter(water, "water")
	model.WorldPivot = frame
	model.Parent = folder
	local def = Content.Haven.comforts["comfort.well"]
	interactive(model, def.id, `at the {def.name}`, def.verb)
	kit(folder, "EO_BarrelCluster", yawed(base + Vector3.new(6, 0, 3), 80))
end

-- The Soup Kitchen (comfort.kitchen), on the west side facing the square: a stall full of
-- stores, the stew pot hanging over its fire in front, steam rising, the cook beside it.
local function kitchen(folder: Instance, origin: Vector3)
	local d = STALL.depth
	local frame = CFrame.new(origin + Vector3.new(-34, 0, 22)) * CFrame.Angles(0, math.rad(-90), 0)
	stall(folder, frame, "WallWood", "SOUP KITCHEN")
	local model = Instance.new("Model")
	model.Name = "StewPot"
	local potAt = (frame * CFrame.new(0, 0, -d / 2 - 4.2)).Position
	local pot = kit(model, "EO_StewPot", CFrame.new(potAt) * CFrame.Angles(0, math.rad(10), 0))
	local height = if pot then pot:GetExtentsSize().Y else 0
	if pot == nil then
		kit(model, "EO_CampfireRing", CFrame.new(potAt), { width = 4 })
	end
	fire(model, potAt, 2.4)
	-- Steam off the stew, and the puff when a bowl is taken.
	local steam = Instance.new("Attachment")
	steam.Name = "Steam"
	steam.Position = Vector3.new(0, math.max(height * 0.55, 2.4), 0)
	local rising = Instance.new("ParticleEmitter")
	rising.Texture = "rbxasset://textures/particles/smoke_main.dds"
	rising.Color = ColorSequence.new(Color3.fromRGB(226, 220, 210))
	rising.Transparency = NumberSequence.new(0.7, 1)
	rising.Size = NumberSequence.new(0.6, 2)
	rising.Lifetime = NumberRange.new(2, 3)
	rising.Rate = 4
	rising.Speed = NumberRange.new(1, 1.8)
	rising.SpreadAngle = Vector2.new(10, 10)
	rising.Parent = steam
	burstEmitter(steam, "steam")
	local holder = model:FindFirstChild("FireCore")
	steam.Parent = if holder then holder else model
	if holder and holder:IsA("BasePart") then
		steam.WorldPosition = potAt + Vector3.new(0, math.max(height * 0.55, 2.4), 0)
	end
	model.WorldPivot = CFrame.new(potAt)
	model.Parent = folder
	local def = Content.Haven.comforts["comfort.kitchen"]
	interactive(model, def.id, `at the {def.name}`, def.verb)
	-- Bess stands between her stall and the pot, ladling for whoever comes.
	local cookAt = (frame * CFrame.new(2.6, 0, -d / 2 - 2.2)).Position
	npc(folder, "npc.cook", cookAt, cookAt + frame.LookVector * 8)
	kit(folder, "EO_SupplySacksMesh", frame * CFrame.new(-4.6, 0, -d / 2 - 2.4) * CFrame.Angles(0, math.rad(40), 0))
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
	well(folder, origin)
	kitchen(folder, origin)
	guildSpot(folder, origin)
	local notices =
		board(folder, CFrame.new(origin + Vector3.new(-14, 0, -56)) * CFrame.Angles(0, math.rad(180), 0), "NOTICES", 5)
	interactive(notices, "board.notice", "Notice Board", "Read")
	dressing(folder, origin)
	clutter(folder, origin)
end

-- Plays a comfort's moment (the Well's splash, the stew's steam) for everyone near it.
function Haven.burst(havenId: string)
	for _, model in CollectionService:GetTagged(Haven.TAG) do
		if model:GetAttribute("HavenId") == havenId then
			for _, emitter in model:GetDescendants() do
				if emitter:IsA("ParticleEmitter") and emitter.Name == "Burst" then
					emitter:Emit(14)
				end
			end
		end
	end
end

-- Studio check (Diagnostics "npcfeet"): each Haven NPC's gap between the soles of its feet
-- and whatever is under them, in studs (0 = standing on it; the bar is within 0.15).
function Haven.npcFeet(): { [string]: number }
	local result: { [string]: number } = {}
	for _, model in CollectionService:GetTagged(Haven.TAG) do
		local npcId = model:GetAttribute("NpcId")
		if model:IsA("Model") and type(npcId) == "string" then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { model }
			local worst = 0
			for _, name in { "LeftFoot", "RightFoot" } do
				local foot = model:FindFirstChild(name, true)
				if foot and foot:IsA("BasePart") then
					local sole = math.huge
					local half = foot.Size / 2
					for _, x in { -1, 1 } do
						for _, y in { -1, 1 } do
							for _, z in { -1, 1 } do
								sole = math.min(sole, (foot.CFrame * Vector3.new(x * half.X, y * half.Y, z * half.Z)).Y)
							end
						end
					end
					local hit = workspace:Raycast(foot.Position + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
					if hit then
						local gap = sole - hit.Position.Y
						if math.abs(gap) > math.abs(worst) then
							worst = gap
						end
					end
				end
			end
			result[npcId] = math.round(worst * 100) / 100
		end
	end
	return result
end

return Haven
