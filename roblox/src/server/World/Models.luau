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
local StarterPlayer = game:GetService("StarterPlayer")

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
-- Loads an uploaded family model (Art.uploaded) into EO_Kit when the place lacks it, and
-- conforms it: turned by yaw, scaled so its world axis measures `size`, pivot at the base
-- centre. Yields once per model per server; nil if the asset can't load.
-- A lookup made while another thread is loading the same model waits for that load (S1b:
-- the starter shelter's campfire rendered mid-load, found nothing and stayed invisible).
local LOAD_WAIT_SECONDS = 20
local loading: { [string]: boolean } = {}
local failed: { [string]: boolean } = {}
local function loadUploaded(name: string): Model?
	local entry = Art.uploaded[name]
	local kit = ServerStorage:FindFirstChild("EO_Kit")
	if entry == nil or kit == nil or failed[name] then
		return nil
	end
	if loading[name] then
		local waited = 0
		while loading[name] and waited < LOAD_WAIT_SECONDS do
			waited += task.wait(0.1)
		end
		return nil -- the caller finds the loaded model in EO_Kit
	end
	loading[name] = true
	local ok, container = pcall(function()
		return game:GetService("InsertService"):LoadAsset(entry.id)
	end)
	local model = if ok then container:FindFirstChildWhichIsA("Model") else nil
	if model == nil then
		warn(`[Models] couldn't load {name} ({entry.id})`)
		failed[name] = true
		loading[name] = nil
		return nil
	end
	local box = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position)
	model:PivotTo(CFrame.new(box.Position) * CFrame.Angles(0, math.rad(entry.yaw), 0))
	model.WorldPivot = CFrame.new(model.WorldPivot.Position) -- axis-aligned: measure in world axes
	local _, size = model:GetBoundingBox()
	local current = if entry.axis == "X" then size.X elseif entry.axis == "Y" then size.Y else size.Z
	model:ScaleTo(model:GetScale() * entry.size / current)
	local centre, fitted = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(centre.Position - Vector3.new(0, fitted.Y / 2, 0))
	model:PivotTo(CFrame.new())
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	model.Name = name
	model.Parent = kit
	container:Destroy()
	loading[name] = nil
	return model
end

function Models.kit(names: { string }): Model?
	for _, name in names do
		if Art.approved[name] and Art.uploaded[name] then
			local kit = ServerStorage:FindFirstChild("EO_Kit")
			if kit and kit:FindFirstChild(name, true) == nil then
				loadUploaded(name)
			end
		end
	end
	for _, folder in sources() do
		for _, name in names do
			if not Art.approved[name] then
				continue -- below grade A: never in the world (checklist §0)
			end
			local found = folder:FindFirstChild(name, true)
			if found and found:IsA("Model") then
				local copy = found:Clone()
				prepare(copy)
				local tint = Art.tints[name]
				if tint then
					for _, look in copy:GetDescendants() do
						if look:IsA("SurfaceAppearance") then
							look.Color = tint
						end
					end
				end
				return copy
			end
		end
	end
	return nil
end

-- The family lantern post's warm glow: the lantern hangs from the arm about two thirds up.
-- Returns the light (nil when the model has no part to hold it).
function Models.lanternGlow(model: Model): PointLight?
	local mesh = model:FindFirstChildWhichIsA("BasePart", true)
	if mesh == nil then
		return nil
	end
	local _, size = model:GetBoundingBox()
	local glow = Instance.new("Attachment")
	glow.Name = "Glow"
	glow.WorldPosition = model:GetPivot().Position + Vector3.new(0, size.Y * 0.62, 0)
	glow.Parent = mesh
	local lamp = Instance.new("PointLight")
	lamp.Range = 18
	lamp.Brightness = 0.9
	lamp.Color = Color3.fromRGB(255, 196, 140)
	lamp.Shadows = false
	lamp.Parent = glow
	return lamp
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

-- A fuelled station's flame and glow (off until fuelled; WorldFx lights them), on an
-- invisible core at `at` from the model's pivot, the flame `size` tall.
local function addFireCore(model: Model, at: Vector3, size: number?)
	local core = part(
		model,
		Vector3.new(0.6, 0.6, 0.6),
		model:GetPivot() * CFrame.new(at),
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
	fire.Size = size or 4
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
-- A foundation: a deck slab DECK_SEAM short of its cell (a thin dark seam on the grid),
-- pivoted at its top centre. The trim around a group of foundations comes from World/Seams.
function Models.deck(tier: number): Model
	local deck = Art.decks[math.clamp(tier, 1, #Art.decks)]
	local model = newModel("Foundation")
	local slab = part(
		model,
		Vector3.new(CELL - Art.DECK_SEAM, DECK_DEPTH, CELL - Art.DECK_SEAM),
		CFrame.new(0, -DECK_DEPTH / 2, 0),
		deck.base,
		deck.tint
	)
	slab.Name = "Deck"
	slab.MaterialVariant = deck.variant
	return finish(model)
end

-- Stretches a wall-layer kit model to span `length` studs and stand `height` tall, about
-- its pivot (base centre, length along X). Haven Square's lounge fence uses it directly.
function Models.fitEdgeTo(model: Model, length: number, height: number)
	local pivot = model:GetPivot()
	local size = model:GetExtentsSize()
	if size.X < 0.01 or size.Y < 0.01 then
		return
	end
	local sx, sy = length / size.X, height / size.Y
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

-- A wall-layer kit model (authored for the old 12-stud cell) spanning exactly one cell
-- and standing WALL_HEIGHT tall.
local function fitEdge(model: Model)
	Models.fitEdgeTo(model, CELL, Art.WALL_HEIGHT)
end

-- Structure (ART_DIRECTION §4, one material per tier): walls, doorways, windows and doors
-- are exact geometry in the tier's deck material, built here, never generated meshes.
-- A piece spans one cell edge, pivot at its base centre, length along X, thickness along Z.
-- Its ends stop half a post short of the cell's corners, where Seams stands a post.
local STRUCTURE = {
	thickness = 0.8,
	cap = 0.35, -- the top cap's height; it is a little thicker than the panel
	post = 1.0,
	doorWidth = 3.6,
	doorHeight = 6.6,
	windowWidth = 3.4,
	windowSill = 3.0,
	windowTop = 5.8,
}

local function slab(model: Model, size: Vector3, centre: Vector3, tier: number): Part
	local deck = Art.decks[math.clamp(tier, 1, #Art.decks)]
	local p = part(model, size, CFrame.new(centre), deck.base, deck.tint)
	p.MaterialVariant = deck.variant
	return p
end

-- One panel of plank wall from x0 to x1 (piece-local), y0 to y1.
local function panel(model: Model, x0: number, x1: number, y0: number, y1: number, tier: number)
	if x1 - x0 < 0.05 or y1 - y0 < 0.05 then
		return
	end
	slab(model, Vector3.new(x1 - x0, y1 - y0, STRUCTURE.thickness), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, 0), tier)
end

function Models.structure(def: Types.BuildPieceDef): Model?
	local tier = def.tier
	local model = newModel(def.id)
	local half = (CELL - STRUCTURE.post) / 2
	local top = Art.WALL_HEIGHT - STRUCTURE.cap
	if def.kind == "door" then
		-- A plank leaf in the doorway's opening, hinged at its left edge (WorldFx swings it).
		local leaf = newModel("Leaf")
		local w, h = STRUCTURE.doorWidth - 0.2, STRUCTURE.doorHeight - 0.15
		slab(leaf, Vector3.new(w, h, 0.4), Vector3.new(0, 0.05 + h / 2, 0), tier)
		leaf.WorldPivot = CFrame.new(-w / 2, 0, 0)
		leaf.Parent = model
		return finish(model)
	end
	if def.kind == "doorway" then
		local d = STRUCTURE.doorWidth / 2
		panel(model, -half, -d, 0, top, tier)
		panel(model, d, half, 0, top, tier)
		panel(model, -d, d, STRUCTURE.doorHeight, top, tier)
	elseif def.kind == "window" then
		local w = STRUCTURE.windowWidth / 2
		panel(model, -half, -w, 0, top, tier)
		panel(model, w, half, 0, top, tier)
		panel(model, -w, w, 0, STRUCTURE.windowSill, tier)
		panel(model, -w, w, STRUCTURE.windowTop, top, tier)
	elseif def.kind == "wall" then
		panel(model, -half, half, 0, top, tier)
	else
		return nil
	end
	-- The top cap along the whole run.
	slab(
		model,
		Vector3.new(half * 2, STRUCTURE.cap, STRUCTURE.thickness + 0.25),
		Vector3.new(0, top + STRUCTURE.cap / 2, 0),
		tier
	)
	return finish(model)
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
	if Art.exactPiece(def.id, def.kind) then
		local built = Models.structure(def)
		if built then
			built.Name = def.id
		end
		return built
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
		addFireCore(kit, Vector3.new(0, 1, 0))
	elseif def.stationId == "station.smelter" and kit:FindFirstChild("FireCore", true) == nil then
		-- The Smelter burns out of its chimney (off the model's centre: the bellows widen it),
		-- so the flame shows over the dome from the camera above.
		addFireCore(kit, Vector3.new(-0.44, kit:GetExtentsSize().Y - 0.3, 0.38), 2.2)
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
	["node.spring_pool"] = 0.8, -- the stone well
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

-- `count` stems of a thin plant grown as one bush (Art.CLUMP). Gathering turns the whole
-- node at random when it places it.
local function clump(stem: Model, count: number): Model
	local bush = Instance.new("Model")
	bush.Name = stem.Name
	local width = math.max(stem:GetExtentsSize().X, stem:GetExtentsSize().Z)
	local origin = stem:GetPivot()
	for index = 1, math.min(count, #Art.CLUMP) do
		local spec = Art.CLUMP[index]
		local copy = if index == 1 then stem else stem:Clone()
		copy:ScaleTo(copy:GetScale() * spec[4])
		copy:PivotTo(origin * CFrame.new(spec[1] * width, 0, spec[2] * width) * CFrame.Angles(0, math.rad(spec[3]), 0))
		for _, child in copy:GetChildren() do
			child.Parent = bush
		end
		copy:Destroy()
	end
	bush.WorldPivot = origin
	bush.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return bush
end

-- The well's water disc (Art.springWater), added in the conformed basin's frame before
-- the node is scaled. The model is marked Drains: a drained well keeps its basin and only
-- the water goes (WorldFx).
local function addWater(model: Model)
	local spec = Art.springWater
	local water = Instance.new("Part")
	water.Name = "Water"
	water.Shape = Enum.PartType.Cylinder
	water.Anchored = true
	water.CanCollide = false
	water.CanTouch = false
	water.CastShadow = false
	water.Material = Enum.Material.Glass
	water.Color = spec.color
	water.Reflectance = spec.reflectance
	water.Size = Vector3.new(0.1, spec.diameter, spec.diameter)
	water.CFrame = model:GetPivot() * CFrame.new(spec.offset) * CFrame.Angles(0, 0, math.rad(90))
	water.Parent = model
	model:SetAttribute("Drains", true)
end

-- The model for a resource node, scaled to Art.nodes[id].height, or nil when the
-- node has no approved model yet (it then doesn't appear; no stand-ins).
function Models.node(def: Types.ResourceNodeDef, _rng: Random): Model?
	local art = Art.nodes[def.id]
	local model = if art then Models.kit(art.names) else nil
	if model == nil or art == nil then
		return nil
	end
	if def.id == "node.spring_pool" then
		addWater(model)
	end
	if art.clump and art.clump > 1 then
		model = clump(model, art.clump)
	end
	model.Name = def.id
	local height = model:GetExtentsSize().Y
	if height > 0.01 then
		model:ScaleTo(model:GetScale() * art.height / height)
	end
	if art.sink then
		model.WorldPivot = model.WorldPivot * CFrame.new(0, art.sink, 0)
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
	local centreFrame, box = model:GetBoundingBox()
	local centre = centreFrame.Position
	local gripPoint = centre - axis * (length / 2) + axis * (grip * length)
	-- A gun's grip hangs below its barrel line (Art.held `drop`).
	local drop = if art then art.drop else nil
	if drop then
		local along = math.abs(edge.X) * box.X + math.abs(edge.Y) * box.Y + math.abs(edge.Z) * box.Z
		gripPoint += edge * (drop * along)
	end
	local rotation = MOUNT_FRAMES[mount] * frame(axis, -edge):Inverse()
	model.Name = itemId
	return { model = model, rotation = rotation, gripPoint = gripPoint }
end

-- A body part's rest rotation relative to the root, from the StarterCharacter, so a
-- mount is laid out in the character's frame (forward, up) whatever the custom
-- rig's part axes are, and still follows the part when it animates.
local restRotations: { [string]: CFrame } = {}
local function restRotation(partName: string): CFrame
	local cached = restRotations[partName]
	if cached then
		return cached
	end
	local rig = StarterPlayer:FindFirstChild("StarterCharacter")
	local root = rig and rig:FindFirstChild("HumanoidRootPart")
	local body = rig and rig:FindFirstChild(partName)
	local rotation = CFrame.identity
	if root and body and root:IsA("BasePart") and body:IsA("BasePart") then
		rotation = root.CFrame:ToObjectSpace(body.CFrame).Rotation
	end
	restRotations[partName] = rotation
	return rotation
end

-- The mount's frame on `part`: the part's live rotation with its rest rotation removed.
local function bodyFrame(body: BasePart, at: Vector3): CFrame
	return CFrame.new(at) * body.CFrame.Rotation * restRotation(body.Name):Inverse()
end

-- Where a mount sits on a survivor rig (a player's character or a Haven NPC) and the
-- part it rides on: the right fist, across the back, or either hip.
function Models.mountFrame(character: Model, mount: Mount): (CFrame?, BasePart?)
	local function partNamed(name: string): BasePart?
		local found = character:FindFirstChild(name)
		return if found and found:IsA("BasePart") then found else nil
	end
	if mount == "hand" then
		local hand = partNamed("RightHand") or partNamed("Right Arm")
		if hand == nil then
			return nil, nil
		end
		local grip = hand:FindFirstChild("RightGripAttachment") :: Attachment?
		local at = if grip then grip.WorldPosition else hand.Position
		return bodyFrame(hand, at), hand
	elseif mount == "back" then
		local torso = partNamed("UpperTorso") or partNamed("Torso")
		if torso == nil then
			return nil, nil
		end
		local back = bodyFrame(torso, torso.Position)
		return back * CFrame.new(-0.35, 0.1, 0.78), torso
	end
	local hips = partNamed("LowerTorso") or partNamed("Torso")
	if hips == nil then
		return nil, nil
	end
	local side = if mount == "belt" then 1 else -1
	return bodyFrame(hips, hips.Position) * CFrame.new(0.78 * side, -0.25, 0.1), hips
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
