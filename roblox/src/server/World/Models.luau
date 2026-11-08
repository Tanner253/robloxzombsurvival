--!strict
--[[
	Models: builds the world models for build pieces, resource nodes and held
	items (server only; ServerStorage holds the kit).

	Each model is cloned from the kit master named in Shared/Art when one exists
	(scripts stripped, parts anchored). Otherwise a fallback is assembled from
	parts in the art direction's materials and palette. Every returned model is
	pivoted the same way as the kit: foundations at their top centre, everything
	else at its bottom centre, walls running along X.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Art = require(ReplicatedStorage.Shared.Art)
local Types = require(ReplicatedStorage.Shared.Types)

local Models = {}

local CELL = require(ReplicatedStorage.Shared.Domain.Grid).CELL_STUDS
-- Deck slabs reach this far down so uneven ground never shows under them.
local DECK_DEPTH = 2.4

type Style = { material: Enum.Material, color: Color3, trim: Enum.Material, trimColor: Color3 }

-- Per-tier materials for fallback building pieces: Wood, Scrap Metal, Reinforced.
local TIERS: { Style } = {
	{
		material = Enum.Material.WoodPlanks,
		color = Color3.fromRGB(124, 88, 60),
		trim = Enum.Material.Wood,
		trimColor = Color3.fromRGB(84, 60, 42),
	},
	{
		material = Enum.Material.CorrodedMetal,
		color = Color3.fromRGB(118, 100, 88),
		trim = Enum.Material.Metal,
		trimColor = Color3.fromRGB(78, 74, 72),
	},
	{
		material = Enum.Material.Concrete,
		color = Color3.fromRGB(122, 120, 116),
		trim = Enum.Material.DiamondPlate,
		trimColor = Color3.fromRGB(70, 72, 76),
	},
}

local STONE = Color3.fromRGB(104, 100, 94)
local BARK = Color3.fromRGB(78, 58, 42)
local EMBER = Color3.fromRGB(255, 138, 61)

-- Kit lookup -----------------------------------------------------------------------------

local function sources(): { Instance }
	local list: { Instance } = {}
	for _, name in { "EO_Kit", "LT_Gen" } do
		local folder = ServerStorage:FindFirstChild(name)
		if folder then
			table.insert(list, folder)
		end
	end
	return list
end

local function prepare(model: Model)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

-- A clone of the first kit master found under any of `names`, or nil.
function Models.kit(names: { string }): Model?
	for _, folder in sources() do
		for _, name in names do
			if not Art.approved[name] then
				continue -- below grade A: never in the world (checklist §0)
			end
			local found = folder:FindFirstChild(name, true)
			if found and found:IsA("Model") then
				local copy = found:Clone()
				prepare(copy)
				return copy
			end
		end
	end
	return nil
end

-- Fallback builder helpers ----------------------------------------------------------------

local function part(
	model: Model,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function newModel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

-- Pivot the model at the origin (the convention every builder below uses).
-- Models stream in whole, so effects never see half a piece.
local function finish(model: Model): Model
	model.WorldPivot = CFrame.identity
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model
end

-- The campfire's flame and glow (off until fuelled; WorldFx lights them), on an
-- invisible core `height` studs above the model's pivot.
local function addFireCore(model: Model, height: number)
	local core = part(
		model,
		Vector3.new(0.6, 0.6, 0.6),
		model:GetPivot() * CFrame.new(0, height, 0),
		Enum.Material.Neon,
		EMBER,
		Enum.PartType.Ball
	)
	core.Name = "FireCore"
	core.Transparency = 1
	core.CanCollide = false
	core.CanQuery = false
	local fire = Instance.new("Fire")
	fire.Name = "Flame"
	fire.Enabled = false
	fire.Heat = 9
	fire.Size = 4
	fire.Color = EMBER
	fire.SecondaryColor = Color3.fromRGB(255, 181, 71)
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Enabled = false
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 14
	light.Brightness = 1.6
	light.Shadows = true
	light.Parent = core
end

-- Adds metal bands to a kit crate (the banded tier has no kit master yet).
local function band(model: Model)
	local size = model:GetExtentsSize()
	for _, x in { -0.3, 0.3 } do
		local p = part(
			model,
			Vector3.new(0.3, size.Y + 0.05, size.Z + 0.1),
			CFrame.new(x * size.X, size.Y / 2, 0),
			Enum.Material.Metal,
			TIERS[2].trimColor
		)
		p.CanCollide = false
	end
end

-- Build pieces -------------------------------------------------------------------------------

--[[
	The model for a build piece, pivoted per the kit convention. Attributes and
	placement are the Building service's job.
]]
-- A foundation: an exact cell-sized deck slab, pivoted at its top centre. The trim
-- around a group of foundations comes from World/Seams.
function Models.deck(tier: number): Model
	local deck = Art.decks[math.clamp(tier, 1, #Art.decks)]
	local model = newModel("Foundation")
	local slab =
		part(model, Vector3.new(CELL, DECK_DEPTH, CELL), CFrame.new(0, -DECK_DEPTH / 2, 0), deck.base, deck.tint)
	slab.Name = "Deck"
	slab.MaterialVariant = deck.variant
	return finish(model)
end

-- Stretches a wall-layer kit model (authored for the old 12-stud cell) to span exactly one
-- cell and stand WALL_HEIGHT tall, about its pivot (base centre, length along X).
local function fitEdge(model: Model)
	local pivot = model:GetPivot()
	local size = model:GetExtentsSize()
	if size.X < 0.01 or size.Y < 0.01 then
		return
	end
	local sx, sy = CELL / size.X, Art.WALL_HEIGHT / size.Y
	local function along(axis: Vector3): number
		local a = pivot:VectorToObjectSpace(axis)
		return math.abs(a.X) * sx + math.abs(a.Y) * sy + math.abs(a.Z)
	end
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			local local_ = pivot:ToObjectSpace(piece.CFrame)
			local offset = local_.Position
			local moved = Vector3.new(offset.X * sx, offset.Y * sy, offset.Z)
			piece.Size = Vector3.new(
				piece.Size.X * along(piece.CFrame.RightVector),
				piece.Size.Y * along(piece.CFrame.UpVector),
				piece.Size.Z * along(piece.CFrame.LookVector)
			)
			piece.CFrame = pivot * (CFrame.new(moved) * local_.Rotation)
		end
	end
end

-- A build piece's model: the material deck for foundations, else its approved kit
-- model, or nil while it has none (the piece is then hidden from the build menu and
-- can't be placed; there are no stand-in builds, checklist §0).
function Models.piece(def: Types.BuildPieceDef): Model?
	if def.kind == "foundation" then
		local deck = Models.deck(def.tier)
		deck.Name = def.id
		return deck
	end
	local names = Art.pieces[def.id]
	local kit = if names then Models.kit(names) else nil
	if kit == nil then
		return nil
	end
	if
		def.kind == "wall"
		or def.kind == "window"
		or def.kind == "doorway"
		or def.kind == "door"
		or def.kind == "gate"
	then
		fitEdge(kit)
	end
	if def.id == "build.crate_banded" and kit.Name ~= "CrateBanded" then
		band(kit)
	end
	if def.stationId == "station.campfire" and kit:FindFirstChild("FireCore", true) == nil then
		addFireCore(kit, 1)
	end
	kit.Name = def.id
	return kit
end

-- Resource nodes -------------------------------------------------------------------------------

-- Footprint colliders: how much of a node's width blocks movement (0 = walk through).
-- Generated meshes collide by their hull, which for a tree includes the canopy,
-- so nodes never collide by mesh; a simple invisible "Collider" does instead.
local COLLIDER_FRACTION: { [string]: number } = {
	["node.pine_tree"] = 0.14,
	["node.boulder"] = 0.75,
	["node.fatwood_stump"] = 0.6,
	["node.scrap_heap"] = 0.7,
}

local function addCollider(model: Model, nodeId: string)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end
	local fraction = COLLIDER_FRACTION[nodeId]
	if fraction == nil then
		return
	end
	local _, size = model:GetBoundingBox()
	local width = math.max(1, math.min(size.X, size.Z) * fraction)
	local height = math.min(size.Y, 6)
	local pivot = model:GetPivot()
	local collider = Instance.new("Part")
	collider.Name = "Collider"
	collider.Anchored = true
	collider.Transparency = 1
	collider.CanQuery = false
	collider.CastShadow = false
	collider.Shape = Enum.PartType.Cylinder
	collider.Size = Vector3.new(height, width, width)
	collider.CFrame = pivot * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	collider.Parent = model
end

-- The model for a resource node, scaled to Art.nodes[id].height, or nil when the
-- node has no approved model yet (it then doesn't appear; no stand-ins).
function Models.node(def: Types.ResourceNodeDef, _rng: Random): Model?
	local art = Art.nodes[def.id]
	local model = if art then Models.kit(art.names) else nil
	if model == nil or art == nil then
		return nil
	end
	model.Name = def.id
	local height = model:GetExtentsSize().Y
	if height > 0.01 then
		model:ScaleTo(model:GetScale() * art.height / height)
	end
	addCollider(model, def.id)
	return model
end

-- A loot sack on the ground (Drops), or nil while no sack model is approved (then
-- nothing is dropped: overflow goes to the inbox and the Drop action is hidden).
function Models.drop(): Model?
	local drop = Models.kit(Art.dropModels)
	if drop == nil then
		return nil
	end
	local height = drop:GetExtentsSize().Y
	if height > 0.01 then
		drop:ScaleTo(drop:GetScale() * 1.5 / height)
	end
	for _, descendant in drop:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
	return drop
end

-- What a depleted node leaves behind (a stump, rubble), named "Remnant". Gathering
-- places it beside the node and shows it only while the node is down.
function Models.remnant(nodeId: string): Model?
	local art = Art.remnants[nodeId]
	local model = if art then Models.kit(art.names) else nil
	if model == nil or art == nil then
		return nil
	end
	local height = model:GetExtentsSize().Y
	if height > 0.01 then
		model:ScaleTo(model:GetScale() * art.height / height)
	end
	model.Name = "Remnant"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	return model
end

-- Held items --------------------------------------------------------------------------------------

-- A rotation whose lookVector is `look` and whose upVector is as close to `up` as possible.
local function frame(look: Vector3, up: Vector3): CFrame
	local back = -look.Unit
	local right = up:Cross(back)
	if right.Magnitude < 1e-4 then
		right = Vector3.new(1, 0, 0):Cross(back)
	end
	right = right.Unit
	return CFrame.fromMatrix(Vector3.zero, right, back:Cross(right).Unit, back)
end

export type Mount = "hand" | "belt" | "beltLeft" | "back"

-- How an item sits on each mount, in the mount's own frame: the handle points along
-- `look` and the blade faces away from `up`.
local MOUNT_FRAMES: { [string]: CFrame } = {
	-- In the fist, head forward and a little up, blade down (LDoE's carry pose).
	hand = frame(Vector3.new(0, 0.35, -1), Vector3.new(0, 1, 0.35)),
	-- Hung from the belt, head down by the thigh, blade facing back.
	belt = frame(Vector3.new(0.08, -1, 0.1), Vector3.new(0, 0, -1)),
	beltLeft = frame(Vector3.new(-0.08, -1, 0.1), Vector3.new(0, 0, -1)),
	-- Across the back, head over the right shoulder.
	back = frame(Vector3.new(0.55, 1, 0), Vector3.new(0, 0, -1)),
}

export type Held = {
	model: Model,
	rotation: CFrame, -- applied in the mount's frame
	gripPoint: Vector3, -- in the model's pivot space
}

local function weldable(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
end

local function fallbackTool(itemId: string, def: Types.ItemDef): Model?
	if def.tool == nil then
		return nil
	end
	local model = newModel(itemId)
	part(model, Vector3.new(0.28, 2.8, 0.28), CFrame.new(0, 1.4, 0), Enum.Material.Wood, BARK)
	if def.tool.kind == "hatchet" then
		part(model, Vector3.new(0.22, 0.75, 1.1), CFrame.new(0, 2.5, -0.45), Enum.Material.Slate, STONE)
	else
		part(model, Vector3.new(0.3, 0.38, 1.9), CFrame.new(0, 2.6, 0), Enum.Material.Slate, STONE)
	end
	return finish(model)
end

--[[
	The model for an item carried in hand or holstered, with how to mount it, or nil
	for items with nothing to show. Kit models are scaled to Art.held[id].length and
	gripped per its axis/edge/grip data; fallbacks are built handle-up.
]]
function Models.held(itemId: string, def: Types.ItemDef, mount: Mount): Held?
	local art = Art.held[itemId]
	local names = Art.items[itemId]
	local kit = if names and art then Models.kit(names) else nil
	local axis: Vector3, edge: Vector3, grip: number, length: number
	local model: Model
	if kit and art then
		model = kit
		model:PivotTo(CFrame.identity)
		axis, edge, grip, length = art.axis.Unit, art.edge.Unit, art.grip, art.length
		local _, size = model:GetBoundingBox()
		local span = math.abs(axis.X) * size.X + math.abs(axis.Y) * size.Y + math.abs(axis.Z) * size.Z
		if span > 0.01 then
			model:ScaleTo(model:GetScale() * length / span)
		end
	else
		local built = fallbackTool(itemId, def)
		if built == nil then
			return nil
		end
		model = built
		axis, edge, grip, length = Vector3.yAxis, Vector3.new(0, 0, -1), 0.15, 2.8
	end
	weldable(model)
	model:PivotTo(CFrame.identity)
	local centre = model:GetBoundingBox().Position
	local gripPoint = centre - axis * (length / 2) + axis * (grip * length)
	local rotation = MOUNT_FRAMES[mount] * frame(axis, -edge):Inverse()
	model.Name = itemId
	return { model = model, rotation = rotation, gripPoint = gripPoint }
end

-- Places a held model on a mount (a world CFrame) and welds it to `anchorPart`.
function Models.mount(held: Held, mountCFrame: CFrame, anchorPart: BasePart)
	held.model:PivotTo(mountCFrame * held.rotation * CFrame.new(-held.gripPoint))
	for _, descendant in held.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchorPart
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
end

return Models
