--!strict
--[[
	Minimap: the round home minimap (checklist 8.11, LDOE_PARITY #6-7), centred on you,
	north up: the terrain tint, your outpost, the plots' nodes, the edge pines and your
	arrow. Shared by the slice-1 HUD and the LDoE HUD.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local Theme = require("../theme")
local hooks = require("../hooks")

local e = React.createElement

-- Home minimap (8.11): your outpost from above, north up, with you on it -------------------------------

local MAP_SIZE = 168

-- The map is centred on you and reaches MAP_RADIUS studs; the terrain under it is sampled
-- (top voxel per TILE-stud tile) and re-sampled only after you move RESAMPLE studs, so the
-- tint layer re-renders rarely while the rest follows you every tick.
local MAP_RADIUS = 110
local TILE = 8
local RESAMPLE = 40
local TERRAIN_TINT: { [Enum.Material]: Color3 } = {
	[Enum.Material.Grass] = Color3.fromRGB(86, 102, 64),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(64, 86, 54),
	[Enum.Material.Ground] = Color3.fromRGB(110, 98, 80),
	[Enum.Material.Mud] = Color3.fromRGB(84, 72, 58),
	[Enum.Material.Sand] = Color3.fromRGB(124, 116, 82),
	[Enum.Material.Basalt] = Color3.fromRGB(52, 48, 46),
}

type Tile = { x: number, z: number, color: Color3 }
local terrainCentre: Vector3? = nil
local terrainTiles: { Tile } = {}

local function sampleTerrain(centre: Vector3)
	local reach = MAP_RADIUS + TILE * 2
	local lo = Vector3.new(centre.X - reach, -8, centre.Z - reach)
	local region = Region3.new(lo, lo + Vector3.new(reach * 2, 28, reach * 2)):ExpandToGrid(4)
	local ok, materials = pcall(function()
		return (workspace.Terrain:ReadVoxels(region, 4)) :: any
	end)
	if not ok then
		return
	end
	local size: Vector3 = materials.Size
	local corner = region.CFrame.Position - region.Size / 2
	local tiles: { Tile } = {}
	local step = TILE // 4
	for ix = 1, size.X, step do
		for iz = 1, size.Z, step do
			for iy = size.Y, 1, -1 do
				local material = materials[ix][iy][iz]
				if material ~= Enum.Material.Air then
					local tint = TERRAIN_TINT[material]
					if tint then
						table.insert(tiles, {
							x = corner.X + (ix - 1) * 4,
							z = corner.Z + (iz - 1) * 4,
							color = tint,
						})
					end
					break
				end
			end
		end
	end
	terrainTiles = tiles
	terrainCentre = centre
end

-- The tint tiles, in world studs relative to `anchor`; memoised so it re-renders only on a resample.
local TerrainLayer = React.memo(function(props: { tiles: { Tile }, anchor: Vector3, scale: number })
	local children: { [string]: any } = {}
	local px = math.ceil(TILE * props.scale) + 1
	for index, tile in props.tiles do
		children[`T{index}`] = e("Frame", {
			Size = UDim2.fromOffset(px, px),
			Position = UDim2.fromOffset(
				(tile.x - props.anchor.X) * props.scale,
				(tile.z - props.anchor.Z) * props.scale
			),
			BackgroundColor3 = tile.color,
			BorderSizePixel = 0,
		})
	end
	return e("Folder", {}, children)
end)

-- Tree and node positions: the edge pines never move (read once); nodes are re-read each tick.
local edgeTreeSpots: { Vector3 }? = nil
local function edgeTrees(): { Vector3 }
	if edgeTreeSpots then
		return edgeTreeSpots
	end
	local world = workspace:FindFirstChild("World")
	local dressing = world and world:FindFirstChild("Dressing")
	local edges = dressing and dressing:FindFirstChild("Edges")
	if edges == nil or #edges:GetChildren() == 0 then
		return {}
	end
	local spots = {}
	for _, tree in edges:GetChildren() do
		if tree:IsA("Model") then
			table.insert(spots, tree:GetPivot().Position)
		end
	end
	edgeTreeSpots = spots
	return spots
end

local function Minimap()
	local plot = hooks.useSection("plot")
	local saved = hooks.useSection("layout")
	hooks.useClock(0.25)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if type(plot) ~= "table" or type(saved) ~= "table" or root == nil then
		return nil
	end
	local you = (root :: BasePart).Position
	if terrainCentre == nil or (Vector3.new(you.X, 0, you.Z) - (terrainCentre :: Vector3)).Magnitude > RESAMPLE then
		sampleTerrain(Vector3.new(you.X, 0, you.Z))
	end
	local scale = (MAP_SIZE / 2) / MAP_RADIUS
	local function at(world: Vector3): UDim2
		return UDim2.fromOffset(MAP_SIZE / 2 + (world.X - you.X) * scale, MAP_SIZE / 2 + (world.Z - you.Z) * scale)
	end
	local children: { [string]: any } = {
		Round = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}
	-- Terrain tint (grass, litter, earth, the road, dry grass), moving with you.
	local anchor = terrainCentre :: Vector3
	children.Terrain = e("Frame", {
		Size = UDim2.fromOffset(0, 0),
		Position = at(anchor),
		BackgroundTransparency = 1,
	}, { Tiles = e(TerrainLayer, { tiles = terrainTiles, anchor = anchor, scale = scale }) })
	-- Your outpost: floors, walls and objects.
	local layout = Grid.deserialize(saved, Content.BuildPieces :: any)
	local origin: Vector3 = plot.origin
	local cell = Grid.CELL_STUDS
	local pieces: { [string]: any } = if layout then layout.pieces else {}
	for uid, piece in pieces do
		local def = Content.BuildPieces[piece.pieceId]
		if def == nil then
			continue
		end
		local corner = origin + Vector3.new(piece.x * cell, 0, piece.z * cell)
		if piece.layer == "floor" then
			children[`F{uid}`] = e("Frame", {
				Size = UDim2.fromOffset(cell * scale + 1, cell * scale + 1),
				Position = at(corner),
				BackgroundColor3 = Color3.fromRGB(196, 160, 104),
				BorderSizePixel = 0,
				ZIndex = 2,
			})
		elseif piece.layer == "frame" then
			local horizontal = piece.axis == "h"
			children[`W{uid}`] = e("Frame", {
				Size = if horizontal
					then UDim2.fromOffset(cell * scale + 1, 2)
					else UDim2.fromOffset(2, cell * scale + 1),
				Position = at(corner),
				AnchorPoint = if horizontal then Vector2.new(0, 0.5) else Vector2.new(0.5, 0),
				BackgroundColor3 = Theme.colors.text,
				BorderSizePixel = 0,
				ZIndex = 3,
			})
		elseif piece.layer == "object" then
			local cx, cz = Grid.objectCenter(def, piece :: any)
			children[`O{uid}`] = e("Frame", {
				Size = UDim2.fromOffset(4, 4),
				Position = at(origin + Vector3.new(cx, 0, cz)),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = if def.kind == "station" then Theme.colors.accent else Theme.colors.highlight,
				ZIndex = 4,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
	end
	-- Trees and resource nodes within reach (8.11): every plot's nodes and the edge pines.
	local function dot(key: string, world: Vector3, size: number, color: Color3)
		if (Vector3.new(world.X, 0, world.Z) - Vector3.new(you.X, 0, you.Z)).Magnitude > MAP_RADIUS then
			return
		end
		children[key] = e("Frame", {
			Size = UDim2.fromOffset(size, size),
			Position = at(world),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			ZIndex = 3,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	for index, spot in edgeTrees() do
		dot(`E{index}`, spot, 6, Color3.fromRGB(38, 66, 40))
	end
	local world = workspace:FindFirstChild("World")
	local plotsFolder = world and world:FindFirstChild("Plots")
	for _, plotModel in (if plotsFolder then plotsFolder:GetChildren() else {}) do
		local nodes = plotModel:FindFirstChild("Nodes")
		for index, node in (if nodes then nodes:GetChildren() else {}) do
			local id = node:GetAttribute("NodeId")
			if node:IsA("Model") and id and node:GetAttribute("Standing") ~= false then
				local tree = id == "node.pine_tree"
				dot(
					`N{plotModel.Name}{index}`,
					node:GetPivot().Position,
					if tree then 5 else 3,
					if tree then Color3.fromRGB(46, 84, 48) else Color3.fromRGB(196, 186, 160)
				)
			end
		end
	end
	children.North = e("TextLabel", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0.5, 0, 0, 4),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.header,
		Text = "N",
		TextSize = Theme.textSize.caption,
		TextColor3 = Theme.colors.highlight,
		TextStrokeColor3 = Theme.colors.shadow,
		TextStrokeTransparency = 0.3,
		ZIndex = 6,
	})
	-- You: the arrow at the centre, turning with the survivor.
	local look = (root :: BasePart).CFrame.LookVector
	-- You: a chevron drawn from two bars, turning with the survivor (no Unicode arrow, 4.17).
	local function bar(side: number): any
		return e("Frame", {
			Size = UDim2.fromOffset(3, 11),
			Position = UDim2.new(0.5, side * 3, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.colors.highlight,
			BorderSizePixel = 0,
			Rotation = -side * 32, -- tops lean in: a ^ pointing ahead
		}, { Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 1 }) })
	end
	children.You = e("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(MAP_SIZE / 2, MAP_SIZE / 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Rotation = math.deg(math.atan2(look.X, -look.Z)),
		ZIndex = 6,
	}, { Left = bar(-1), Right = bar(1) })
	-- A CanvasGroup clips its children to the round corner (a Frame clips only to its box).
	return e("Frame", {
		Size = UDim2.fromOffset(MAP_SIZE, MAP_SIZE),
		Position = UDim2.new(1, -16, 0, 80),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
	}, {
		Map = e("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(46, 58, 44),
			BorderSizePixel = 0,
		}, children),
		Ring = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 7,
		}, {
			Round = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = Theme.strokeThickness }),
		}),
	})
end

return Minimap
