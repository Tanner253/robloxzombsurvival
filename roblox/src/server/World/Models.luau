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

local CELL = 12
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
local PINE = Color3.fromRGB(52, 78, 54)
local LEAF = Color3.fromRGB(70, 92, 56)
local REED = Color3.fromRGB(128, 132, 78)
local EMBER = Color3.fromRGB(255, 138, 61)
local WATER = Color3.fromRGB(64, 104, 124)

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

-- A wall panel spanning x0..x1 (along X) and y0..y1.
local function panel(model: Model, style: Style, x0: number, x1: number, y0: number, y1: number, thickness: number)
	if x1 - x0 <= 0.05 or y1 - y0 <= 0.05 then
		return
	end
	part(
		model,
		Vector3.new(x1 - x0, y1 - y0, thickness),
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0),
		style.material,
		style.color
	)
end

local function posts(model: Model, style: Style, height: number)
	for _, x in { -CELL / 2 + 0.45, CELL / 2 - 0.45 } do
		part(
			model,
			Vector3.new(0.9, height + 0.4, 0.9),
			CFrame.new(x, (height + 0.4) / 2, 0),
			style.trim,
			style.trimColor
		)
	end
end

local function rail(model: Model, style: Style, y: number)
	part(model, Vector3.new(CELL - 0.4, 0.45, 1.05), CFrame.new(0, y, 0), style.trim, style.trimColor)
end

local function wall(style: Style): Model
	local model = newModel("Wall")
	local h = Art.WALL_HEIGHT
	panel(model, style, -CELL / 2, CELL / 2, 0, h, 0.8)
	posts(model, style, h)
	rail(model, style, 1.2)
	rail(model, style, h - 0.6)
	return finish(model)
end

local DOOR_WIDTH = 5
local DOOR_HEIGHT = 6.6

local function doorway(style: Style): Model
	local model = newModel("Doorway")
	local h = Art.WALL_HEIGHT
	panel(model, style, -CELL / 2, -DOOR_WIDTH / 2, 0, h, 0.8)
	panel(model, style, DOOR_WIDTH / 2, CELL / 2, 0, h, 0.8)
	panel(model, style, -DOOR_WIDTH / 2, DOOR_WIDTH / 2, DOOR_HEIGHT, h, 0.8)
	posts(model, style, h)
	-- Door frame.
	for _, x in { -DOOR_WIDTH / 2 - 0.2, DOOR_WIDTH / 2 + 0.2 } do
		part(model, Vector3.new(0.4, DOOR_HEIGHT, 1.1), CFrame.new(x, DOOR_HEIGHT / 2, 0), style.trim, style.trimColor)
	end
	part(
		model,
		Vector3.new(DOOR_WIDTH + 0.8, 0.5, 1.1),
		CFrame.new(0, DOOR_HEIGHT + 0.25, 0),
		style.trim,
		style.trimColor
	)
	rail(model, style, h - 0.6)
	return finish(model)
end

-- The door leaf is a separate Model named "Leaf" so the client can swing it open.
local function door(style: Style): Model
	local model = newModel("Door")
	local leaf = newModel("Leaf")
	local w, h = DOOR_WIDTH - 0.2, DOOR_HEIGHT - 0.1
	part(leaf, Vector3.new(w, h, 0.35), CFrame.new(0, h / 2, 0), style.material, style.color)
	for _, y in { 1.2, h - 1.2 } do
		part(leaf, Vector3.new(w - 0.3, 0.4, 0.5), CFrame.new(0, y, 0), style.trim, style.trimColor)
	end
	part(
		leaf,
		Vector3.new(0.35, math.sqrt(w * w + h * h) * 0.82, 0.45),
		CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.atan2(w, h)),
		style.trim,
		style.trimColor
	)
	leaf.WorldPivot = CFrame.new(-w / 2, 0, 0) -- the hinge
	leaf.Parent = model
	return finish(model)
end

local function window(style: Style): Model
	local model = newModel("Window")
	local h = Art.WALL_HEIGHT
	local w, sill, top = 4.4, 3.2, 6.4
	panel(model, style, -CELL / 2, -w / 2, 0, h, 0.8)
	panel(model, style, w / 2, CELL / 2, 0, h, 0.8)
	panel(model, style, -w / 2, w / 2, 0, sill, 0.8)
	panel(model, style, -w / 2, w / 2, top, h, 0.8)
	posts(model, style, h)
	part(model, Vector3.new(w + 0.6, 0.35, 1.2), CFrame.new(0, sill, 0), style.trim, style.trimColor)
	part(model, Vector3.new(0.3, top - sill, 0.4), CFrame.new(0, (sill + top) / 2, 0), style.trim, style.trimColor)
	part(model, Vector3.new(w, 0.3, 0.4), CFrame.new(0, (sill + top) / 2, 0), style.trim, style.trimColor)
	return finish(model)
end

local function stoneRing(model: Model, radius: number, count: number, size: number)
	for index = 1, count do
		local angle = index / count * math.pi * 2
		local s = size * (0.85 + (index % 3) * 0.12)
		part(
			model,
			Vector3.new(s, s * 0.7, s * 0.9),
			CFrame.new(math.cos(angle) * radius, s * 0.3, math.sin(angle) * radius) * CFrame.Angles(0, angle, 0),
			Enum.Material.Slate,
			STONE,
			Enum.PartType.Ball
		)
	end
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

-- Campfire: a stone ring and crossed logs, with a Fire, light and embers the
-- client switches on while fuel burns ("FuelEndsAt" attribute).
local function campfire(): Model
	local model = newModel("Campfire")
	stoneRing(model, 1.9, 9, 1.1)
	for index = 0, 2 do
		local log = part(
			model,
			Vector3.new(3.4, 0.55, 0.55),
			CFrame.new(0, 0.55, 0) * CFrame.Angles(0, index * math.pi / 3, math.rad(18)),
			Enum.Material.Wood,
			BARK,
			Enum.PartType.Cylinder
		)
		log.Name = "Log"
	end
	addFireCore(model, 0.9)
	return finish(model)
end

local function recycler(): Model
	local model = newModel("Recycler")
	local body = TIERS[2]
	part(model, Vector3.new(4.4, 3, 3.4), CFrame.new(0, 1.5, 0), body.material, body.color)
	part(
		model,
		Vector3.new(3, 1.4, 2.4),
		CFrame.new(0, 3.7, 0) * CFrame.Angles(math.rad(-12), 0, 0),
		body.trim,
		body.trimColor
	)
	part(
		model,
		Vector3.new(1, 1, 1),
		CFrame.new(1.6, 3.4, 1.2),
		Enum.Material.Metal,
		Color3.fromRGB(140, 82, 52),
		Enum.PartType.Cylinder
	)
	return finish(model)
end

local function workbench(): Model
	local model = newModel("Workbench")
	local wood = TIERS[1]
	part(model, Vector3.new(5, 0.5, 2.6), CFrame.new(0, 3, 0), wood.material, wood.color)
	for _, x in { -2.2, 2.2 } do
		for _, z in { -1, 1 } do
			part(model, Vector3.new(0.4, 2.8, 0.4), CFrame.new(x, 1.4, z), wood.trim, wood.trimColor)
		end
	end
	return finish(model)
end

local function crate(banded: boolean): Model
	local model = newModel("Crate")
	local wood = TIERS[1]
	part(model, Vector3.new(4.6, 2.8, 2.8), CFrame.new(0, 1.4, 0), wood.material, wood.color)
	part(model, Vector3.new(4.8, 0.3, 3), CFrame.new(0, 2.85, 0), wood.trim, wood.trimColor)
	if banded then
		for _, x in { -1.6, 1.6 } do
			part(model, Vector3.new(0.35, 2.9, 2.95), CFrame.new(x, 1.45, 0), Enum.Material.Metal, TIERS[2].trimColor)
		end
	end
	return finish(model)
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

function Models.piece(def: Types.BuildPieceDef): Model
	if def.kind == "foundation" then
		local deck = Models.deck(def.tier)
		deck.Name = def.id
		return deck
	end
	local names = Art.pieces[def.id]
	local kit = if names then Models.kit(names) else nil
	if kit then
		if def.id == "build.crate_banded" and kit.Name ~= "CrateBanded" then
			band(kit)
		end
		if def.stationId == "station.campfire" and kit:FindFirstChild("FireCore", true) == nil then
			addFireCore(kit, 1)
		end
		kit.Name = def.id
		return kit
	end
	local style = TIERS[math.clamp(def.tier, 1, #TIERS)]
	local model: Model
	if def.kind == "wall" then
		model = wall(style)
	elseif def.kind == "doorway" then
		model = doorway(style)
	elseif def.kind == "door" or def.kind == "gate" then
		model = door(style)
	elseif def.kind == "window" then
		model = window(style)
	elseif def.stationId == "station.campfire" then
		model = campfire()
	elseif def.stationId == "station.recycler" then
		model = recycler()
	elseif def.kind == "station" then
		model = workbench()
	elseif def.kind == "storage" then
		model = crate(def.tier > 1)
	else
		model = newModel("Piece")
		part(model, Vector3.new(4, 4, 4), CFrame.new(0, 2, 0), style.material, style.color)
		model = finish(model)
	end
	model.Name = def.id
	return model
end

-- Resource nodes -------------------------------------------------------------------------------

local function ball(model: Model, size: Vector3, at: CFrame, material: Enum.Material, color: Color3): Part
	return part(model, size, at, material, color, Enum.PartType.Ball)
end

local function fallbackNode(nodeId: string, rng: Random): Model
	local model = newModel(nodeId)
	if nodeId == "node.pine_tree" then
		part(
			model,
			Vector3.new(6, 1.3, 1.3),
			CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Wood,
			BARK,
			Enum.PartType.Cylinder
		)
		local layers = { { 7.5, 4.2, 6.2 }, { 5.8, 3.8, 9 }, { 3.9, 3.2, 11.6 }, { 2, 2.4, 13.6 } }
		for _, layer in layers do
			local w, h, y = layer[1], layer[2], layer[3]
			ball(
				model,
				Vector3.new(w, h, w),
				CFrame.new(0, y, 0) * CFrame.Angles(0, rng:NextNumber() * 6, 0),
				Enum.Material.LeafyGrass,
				PINE
			)
		end
	elseif nodeId == "node.boulder" then
		ball(model, Vector3.new(5.2, 3.8, 4.4), CFrame.new(0, 1.6, 0), Enum.Material.Slate, STONE)
		ball(model, Vector3.new(3, 2.4, 2.8), CFrame.new(2, 1, 1.2), Enum.Material.Slate, STONE:Lerp(Color3.new(), 0.1))
		ball(
			model,
			Vector3.new(2.4, 1.8, 2.2),
			CFrame.new(-1.8, 0.8, -1.4),
			Enum.Material.Slate,
			STONE:Lerp(Color3.new(1, 1, 1), 0.06)
		)
	elseif nodeId == "node.loose_stones" then
		for index = 1, 5 do
			local s = 0.7 + rng:NextNumber() * 0.6
			ball(
				model,
				Vector3.new(s * 1.2, s * 0.7, s),
				CFrame.new(rng:NextNumber() * 2.4 - 1.2, s * 0.3, rng:NextNumber() * 2.4 - 1.2)
					* CFrame.Angles(0, index, 0),
				Enum.Material.Slate,
				STONE
			)
		end
	elseif nodeId == "node.fallen_branches" then
		for index = 1, 4 do
			part(
				model,
				Vector3.new(3.6 + rng:NextNumber() * 1.6, 0.35, 0.35),
				CFrame.new(0, 0.25 + index * 0.12, 0) * CFrame.Angles(0, index * 1.1 + rng:NextNumber(), 0),
				Enum.Material.Wood,
				BARK,
				Enum.PartType.Cylinder
			)
		end
	elseif nodeId == "node.reed_patch" then
		for _ = 1, 9 do
			local h = 2.2 + rng:NextNumber() * 1.4
			part(
				model,
				Vector3.new(0.22, h, 0.22),
				CFrame.new(rng:NextNumber() * 2 - 1, h / 2, rng:NextNumber() * 2 - 1)
					* CFrame.Angles(rng:NextNumber() * 0.4 - 0.2, 0, rng:NextNumber() * 0.4 - 0.2),
				Enum.Material.Grass,
				REED
			)
		end
	elseif nodeId == "node.ember_bush" then
		for index = 1, 3 do
			local angle = index * 2.1
			ball(
				model,
				Vector3.new(2.8, 2.4, 2.8),
				CFrame.new(math.cos(angle) * 0.9, 1.3, math.sin(angle) * 0.9),
				Enum.Material.LeafyGrass,
				LEAF
			)
		end
		for index = 1, 7 do
			local angle = index * 0.9
			local berry = ball(
				model,
				Vector3.new(0.42, 0.42, 0.42),
				CFrame.new(math.cos(angle) * 1.6, 1.2 + (index % 3) * 0.55, math.sin(angle) * 1.6),
				Enum.Material.Neon,
				EMBER
			)
			berry.Name = "Berry"
			berry.CanCollide = false
		end
	elseif nodeId == "node.spring_pool" then
		local pool = part(
			model,
			Vector3.new(0.4, 6, 6),
			CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Glass,
			WATER,
			Enum.PartType.Cylinder
		)
		pool.Transparency = 0.25
		pool.Reflectance = 0.15
		stoneRing(model, 3.2, 12, 1)
	else
		ball(model, Vector3.new(3, 2, 3), CFrame.new(0, 1, 0), Enum.Material.Ground, STONE)
	end
	return finish(model)
end

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

-- The model for a resource node, scaled to Art.nodes[id].height.
function Models.node(def: Types.ResourceNodeDef, rng: Random): Model
	local art = Art.nodes[def.id]
	local kit = if art then Models.kit(art.names) else nil
	local model = kit or fallbackNode(def.id, rng)
	model.Name = def.id
	if kit and art then
		local height = model:GetExtentsSize().Y
		if height > 0.01 then
			model:ScaleTo(model:GetScale() * art.height / height)
		end
	end
	addCollider(model, def.id)
	return model
end

-- A loot sack on the ground (Drops): the satchel model, or a cloth bundle without the kit.
function Models.drop(): Model
	local kit = Models.kit({ "Gen_backpack", "EO_Satchel" })
	local drop: Model
	if kit then
		drop = kit
		local height = drop:GetExtentsSize().Y
		if height > 0.01 then
			drop:ScaleTo(drop:GetScale() * 1.5 / height)
		end
	else
		drop = newModel("Drop")
		local cloth = Color3.fromRGB(122, 98, 70)
		part(drop, Vector3.new(1.6, 1.2, 1.4), CFrame.new(0, 0.6, 0), Enum.Material.Fabric, cloth, Enum.PartType.Ball)
		part(drop, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 1.25, 0), Enum.Material.Fabric, cloth, Enum.PartType.Ball)
		finish(drop)
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
