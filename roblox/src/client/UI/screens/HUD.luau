--!strict
--[[
	HUD: always on screen while playing (PC-first 16:9 layout, corners on touch).
	- top left: level badge, health, hunger and thirst, XP, Energy with its regen timer
	- left: the Survivor's Path quest tracker (placeholder until Quests land)
	- bottom centre: the 1-9 hotbar (pockets 1-9), with the held item's name
	- bottom right: action buttons with keybind hints (E, Tab, B; Shift on touch)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Art = require(ReplicatedStorage.Shared.Art)
local EnergyMath = require(ReplicatedStorage.Shared.Domain.Energy)
local Clock = require(ReplicatedStorage.Shared.Clock)
local Progression = require(ReplicatedStorage.Shared.Domain.Progression)
local Crafting = require(ReplicatedStorage.Shared.Domain.Crafting)
local DevSpeed = require(ReplicatedStorage.Shared.DevSpeed)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local Actions = require("../../Actions")
local Theme = require("../theme")
local hooks = require("../hooks")
local format = require("../format")
local ItemSlot = require("../components/ItemSlot")
local KeyChip = require("../components/KeyChip")
local Label = require("../components/Label")
local StatBar = require("../components/StatBar")

local e = React.createElement

local HOTBAR_SLOTS = 9
local HOTBAR_SIZE = 60

local function card(props: { size: UDim2, position: UDim2, anchorPoint: Vector2?, children: any })
	return e("Frame", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = Theme.colors.panelTransparency + 0.02,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = Theme.colors.strokeWarm,
			Thickness = Theme.strokeThickness,
			Transparency = 0.25,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, Theme.spacing.sm),
			PaddingBottom = UDim.new(0, Theme.spacing.sm),
			PaddingLeft = UDim.new(0, Theme.spacing.md),
			PaddingRight = UDim.new(0, Theme.spacing.md),
		}),
		Content = e(React.Fragment, nil, props.children),
	})
end

-- Status ----------------------------------------------------------------------------------------

local function LevelBadge(props: { level: number, fraction: number })
	local fill = hooks.useAnimated(props.fraction, 6)
	return e("Frame", {
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = Theme.colors.panelRaised,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Ring = e("UIStroke", { Color = Theme.colors.accent, Thickness = 3 }),
		Glow = e("UIGradient", {
			Color = ColorSequence.new(Theme.colors.accent:Lerp(Theme.colors.panelRaised, 0.6), Theme.colors.panel),
			Rotation = 90,
		}),
		Caption = e(Label, {
			text = "LEVEL",
			style = "caption",
			tone = "muted",
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.fromOffset(0, 12),
			alignX = Enum.TextXAlignment.Center,
		}),
		Number = e(Label, {
			text = tostring(props.level),
			style = "header",
			size = UDim2.new(1, 0, 0, 32),
			position = UDim2.fromOffset(0, 26),
			alignX = Enum.TextXAlignment.Center,
			stroke = true,
		}),
		-- XP progress as a thin arc substitute: a bar under the number.
		Track = e("Frame", {
			Size = UDim2.new(0.6, 0, 0, 4),
			Position = UDim2.new(0.2, 0, 1, -14),
			BackgroundColor3 = Theme.colors.track,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = e("Frame", {
				Size = fill:map(function(v: number)
					return UDim2.fromScale(v, 1)
				end),
				BackgroundColor3 = Theme.meters.xp,
				BorderSizePixel = 0,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		}),
	})
end

local function Status()
	local survival = hooks.useSection("survival")
	local progression = hooks.useSection("progression")
	local energy = hooks.useSection("energy")
	local now = hooks.useClock(1)
	-- Studio's pinned hour (ClockOverride) shows on the chip too, so captures agree.
	local pinned = if RunService:IsStudio() then workspace:GetAttribute("ClockOverride") else nil
	local hours = if type(pinned) == "number" then pinned else Clock.hoursAt(now)

	local level = if progression then progression.level else 1
	local into, span, fraction = 0, 0, 0
	if progression then
		into, span, fraction = Progression.progress(progression, Content.Levels)
	end

	-- Meters drain between server ticks; draw them where they are now.
	local hunger, thirst, health = 100, 100, 100
	local hungerMax, thirstMax, maxHealth = 100, 100, 100
	if survival then
		local dt = math.max(0, now - survival.updatedAt)
		hunger = math.max(0, survival.hunger - survival.hungerDecay * dt)
		thirst = math.max(0, survival.thirst - survival.thirstDecay * dt)
		health = survival.health
		hungerMax, thirstMax, maxHealth = survival.hungerMax, survival.thirstMax, survival.maxHealth
	end

	local energyValue, energyCap, nextIn, bonus = 0, 100, 0, 0
	if energy then
		local config = { cap = energy.cap, secondsPerPoint = energy.secondsPerPoint }
		local state = EnergyMath.current({ value = energy.value, updatedAt = energy.updatedAt }, now, config)
		energyValue, energyCap = state.value, energy.cap
		bonus = math.max(0, state.value - energy.cap)
		nextIn = if state.value < energy.cap then state.updatedAt + energy.secondsPerPoint - now else 0
	end

	return card({
		size = UDim2.fromOffset(352, 116),
		position = UDim2.fromOffset(16, 16),
		children = {
			Badge = e("Frame", { Size = UDim2.fromOffset(76, 76), BackgroundTransparency = 1 }, {
				Inner = e(LevelBadge, { level = level, fraction = fraction }),
			}),
			Bars = e("Frame", {
				Size = UDim2.new(1, -88, 0, 76),
				Position = UDim2.fromOffset(88, 0),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Health = e(StatBar, {
					value = health,
					max = maxHealth,
					color = Theme.meters.health,
					glyph = Art.meterGlyphs.health,
					label = `{math.ceil(health)} / {maxHealth}`,
					lowAt = 0.3,
					size = UDim2.new(1, 0, 0, 20),
					layoutOrder = 1,
				}),
				Hunger = e(StatBar, {
					value = hunger,
					max = hungerMax,
					color = Theme.meters.hunger,
					glyph = Art.meterGlyphs.hunger,
					lowAt = 0.15,
					size = UDim2.new(1, 0, 0, 16),
					layoutOrder = 2,
				}),
				Thirst = e(StatBar, {
					value = thirst,
					max = thirstMax,
					color = Theme.meters.thirst,
					glyph = Art.meterGlyphs.thirst,
					lowAt = 0.15,
					size = UDim2.new(1, 0, 0, 16),
					layoutOrder = 3,
				}),
			}),
			Xp = e(Label, {
				text = if span > 0 then `{into} / {span} XP` else "Max level",
				style = "caption",
				tone = "muted",
				size = UDim2.fromOffset(150, 16),
				position = UDim2.new(0, 0, 1, -16),
			}),
			Clock = e("Frame", {
				Size = UDim2.fromOffset(96, 28),
				Position = UDim2.new(1, 12, 0, 4),
				BackgroundColor3 = Theme.colors.panel,
				BackgroundTransparency = Theme.colors.panelTransparency,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = 1, Transparency = 0.4 }),
				Text = e(Label, {
					text = `{if Clock.daylight(hours) > 0.5 then "☀" else "☾"}  {Clock.label(hours)}`,
					style = "caption",
					tone = if Clock.daylight(hours) > 0.5 then "highlight" else "muted",
					size = UDim2.fromScale(1, 1),
					alignX = Enum.TextXAlignment.Center,
				}),
			}),
			Energy = e("Frame", {
				Size = UDim2.fromOffset(170, 22),
				Position = UDim2.new(1, 0, 1, -20),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Theme.colors.track,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Stroke = e("UIStroke", {
					Color = if bonus > 0 then Theme.colors.bonus else Theme.meters.energy,
					Thickness = if bonus > 0 then 2 else 1,
					Transparency = if bonus > 0 then 0 else 0.5,
				}),
				-- Above the cap (level-up refills, rewards) the extra shows as an amber bonus.
				Text = e(Label, {
					text = if bonus > 0
						then `{Art.meterGlyphs.energy} {energyCap} / {energyCap}  <font color="#{Theme.colors.bonus:ToHex()}">+{bonus}</font>`
						elseif
							nextIn > 0
						then `{Art.meterGlyphs.energy} {energyValue} / {energyCap}  ·  +1 in {format.duration(
							nextIn
						)}`
						else `{Art.meterGlyphs.energy} {energyValue} / {energyCap}`,
					richText = true,
					style = "caption",
					tone = "highlight",
					size = UDim2.fromScale(1, 1),
					alignX = Enum.TextXAlignment.Center,
				}),
			}),
		},
	})
end

-- Quest tracker (placeholder) ------------------------------------------------------------------------

local function starterQuest(): any
	for _, quest in Content.Quests do
		if quest.prerequisite == nil then
			return quest
		end
	end
	return nil
end

local function objectiveText(objective: any, inventory: any): (string, number, number)
	if objective.kind == "gather" then
		local have = format.count(inventory, objective.itemId)
		return `Gather {format.itemName(objective.itemId)}`, math.min(have, objective.count), objective.count
	elseif objective.kind == "craft" then
		return "Craft a recipe", 0, objective.count
	elseif objective.kind == "build" then
		local piece = Content.BuildPieces[objective.pieceId]
		return `Build {if piece then piece.name else "a piece"}`, 0, objective.count
	end
	return objective.kind, 0, 1
end

local function foldButton(collapsed: boolean): any
	return e("TextButton", {
		Size = UDim2.fromOffset(32, 28),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.colors.panelRaised,
		FontFace = Theme.fonts.header,
		Text = if collapsed then "»" else "«",
		TextSize = Theme.textSize.section,
		TextColor3 = Theme.colors.text,
		ZIndex = 3,
		[React.Event.Activated] = Actions.toggleQuests,
	}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) })
end

local function QuestTracker()
	local ui = hooks.useUi()
	local inventory = hooks.useSection("inventory")
	local quest = starterQuest()
	if quest == nil then
		return nil
	end
	-- Folded to one line with the « button (8.9): the quest name and how far along it is.
	if ui.questCollapsed then
		local done = 0
		for _, objective in quest.objectives do
			local _, have, need = objectiveText(objective, inventory)
			done += if have >= need then 1 else 0
		end
		return card({
			size = UDim2.fromOffset(300, 46),
			position = UDim2.fromOffset(16, 146),
			children = {
				Name = e(Label, {
					text = `{quest.name}  {done}/{#quest.objectives}`,
					style = "section",
					size = UDim2.new(1, -40, 0, 28),
				}),
				Fold = foldButton(true),
			},
		})
	end
	local rows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		-- The header row carries the « fold button (8.9); the list layout places rows only.
		Header = e("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 0 }, {
			Title = e(
				Label,
				{ text = "SURVIVOR'S PATH", style = "section", tone = "accent", size = UDim2.new(1, -40, 1, 0) }
			),
			Fold = foldButton(false),
		}),
		Name = e(Label, { text = quest.name, style = "title", layoutOrder = 1 }),
	}
	for index, objective in quest.objectives do
		local text, have, need = objectiveText(objective, inventory)
		local done = have >= need
		rows[`Objective{index}`] = e("Frame", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			LayoutOrder = 1 + index,
		}, {
			Box = e("Frame", {
				Size = UDim2.fromOffset(14, 14),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = if done then Theme.colors.durability else Theme.colors.track,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
				Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = 1 }),
			}),
			Text = e(Label, {
				text = `{text}  {have}/{need}`,
				style = "caption",
				tone = if done then "good" else "text",
				size = UDim2.new(1, -22, 1, 0),
				position = UDim2.fromOffset(22, 0),
			}),
		})
	end
	return card({
		size = UDim2.fromOffset(300, 60 + #quest.objectives * 24),
		position = UDim2.fromOffset(16, 146),
		children = rows,
	})
end

-- Level bar along the bottom edge (8.9) -----------------------------------------------------------------

local function LevelBar()
	local progression = hooks.useSection("progression")
	if not progression then
		return nil
	end
	local _, _, fraction = Progression.progress(progression, Content.Levels)
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.colors.track,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, {
		Fill = e("Frame", {
			Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
			BackgroundColor3 = Theme.meters.xp,
			BorderSizePixel = 0,
		}),
	})
end

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
	children.You = e("TextLabel", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(MAP_SIZE / 2, MAP_SIZE / 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.header,
		Text = "▲",
		TextSize = 18,
		TextColor3 = Theme.colors.highlight,
		TextStrokeColor3 = Theme.colors.shadow,
		TextStrokeTransparency = 0,
		Rotation = math.deg(math.atan2(look.X, -look.Z)),
		ZIndex = 6,
	})
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

-- Hotbar ---------------------------------------------------------------------------------------------------

local function Hotbar()
	local inventory = hooks.useSection("inventory")
	local held = if inventory then inventory.held else 0
	local slots: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	}
	for index = 1, HOTBAR_SLOTS do
		local slot = if inventory then inventory.pockets[index] else nil
		local def = if slot and slot.count > 0 then Content.Items[slot.itemId] else nil
		slots[`Slot{index}`] = e(ItemSlot, {
			itemId = if slot then slot.itemId else nil,
			count = if slot then slot.count else 0,
			durability = if def
					and def.durability
					and slot
					and slot.durability
				then slot.durability / def.durability
				else nil,
			selected = held == index,
			hotkey = tostring(index),
			size = HOTBAR_SIZE,
			layoutOrder = index,
			onActivated = function()
				Actions.hotbar(index)
			end,
		})
	end
	local heldSlot = if inventory and held > 0 then inventory.pockets[held] else nil
	local heldName = if heldSlot and heldSlot.count > 0 then format.itemName(heldSlot.itemId) else nil
	return e("Frame", {
		Size = UDim2.fromOffset(HOTBAR_SLOTS * (HOTBAR_SIZE + 6), HOTBAR_SIZE + 34),
		Position = UDim2.new(0.5, 0, 1, -14),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
	}, {
		Held = heldName and e(Label, {
			text = heldName,
			style = "body",
			tone = "highlight",
			size = UDim2.new(1, 0, 0, 22),
			alignX = Enum.TextXAlignment.Center,
			stroke = true,
		}),
		Row = e("Frame", {
			Size = UDim2.new(1, 0, 0, HOTBAR_SIZE),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
		}, slots),
	})
end

-- Action buttons ---------------------------------------------------------------------------------------------

local function ActionButton(
	props: {
		label: string,
		keyName: string?, -- not `key`: React reserves it
		glyph: string,
		primary: boolean?,
		size: number,
		layoutOrder: number,
		onPress: () -> (),
		onRelease: (() -> ())?,
		dot: boolean?, -- something new inside (NEW badge, checklist 8.4)
		alertAt: number?, -- os.clock() of an alert: the button flashes red briefly
		badge: number?, -- a count in a red circle, e.g. unclaimed inbox rows (4.15)
	}
)
	local pressed, setPressed = React.useState(false)
	local now = hooks.useClock(0.1)
	local alerting = props.alertAt ~= nil and os.clock() - props.alertAt < 1.2
	local flash = alerting and math.floor((os.clock() - (props.alertAt :: number)) * 6) % 2 == 0
	local _ = now
	local scale = hooks.useAnimated(if pressed then 0.92 else 1, 24)
	return e("TextButton", {
		Size = UDim2.fromOffset(props.size, props.size),
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = if props.primary then Theme.colors.accent else Theme.colors.panelRaised,
		BackgroundTransparency = if props.primary then 0 else 0.1,
		[React.Event.InputBegan] = function(_rbx: any, input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				setPressed(true)
				props.onPress()
			end
		end,
		[React.Event.InputEnded] = function(_rbx: any, input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				setPressed(false)
				if props.onRelease then
					props.onRelease()
				end
			end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Stroke = e("UIStroke", {
			Color = if props.primary then Theme.colors.accentSoft else Theme.colors.strokeWarm,
			Thickness = Theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Scale = e("UIScale", { Scale = scale }),
		Glyph = e("TextLabel", {
			Size = UDim2.fromScale(0.46, 0.46),
			Position = UDim2.fromScale(0.5, 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = props.glyph,
			TextScaled = true,
			TextColor3 = if props.primary then Theme.colors.textOnAccent else Theme.colors.text,
		}),
		Label = e(Label, {
			text = props.label,
			style = "caption",
			tone = if props.primary then "onAccent" else "muted",
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.new(0, 0, 1, -18),
			alignX = Enum.TextXAlignment.Center,
		}),
		Key = props.keyName and e(KeyChip, {
			text = props.keyName,
			position = UDim2.new(1, 2, 0, -2),
			anchorPoint = Vector2.new(1, 0),
			accent = props.primary,
		}),
		Badge = (props.badge or 0) > 0 and e("TextLabel", {
			Size = UDim2.fromOffset(22, 22),
			-- On this button's top-left rim: opposite its own key chip and clear of the
			-- neighbour's (QA2: mid-height badges looked like the neighbour's).
			Position = UDim2.fromOffset(-2, -2),
			-- A solid red count with light digits: dark digits on salmon read as a blot.
			BackgroundColor3 = Color3.fromHex("C8473A"),
			FontFace = Theme.fonts.header,
			Text = if (props.badge or 0) > 99 then "99+" else tostring(props.badge),
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.text,
			ZIndex = 4,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 1.5 }),
		}),
		Dot = (props.badge or 0) == 0 and props.dot and e("Frame", {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(4, 4),
			BackgroundColor3 = Theme.colors.accent,
			ZIndex = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 1.5 }),
		}),
		Alert = flash and e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.colors.threat,
			BackgroundTransparency = 0.35,
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		}),
	})
end

local function ActionBar()
	local ui = hooks.useUi()
	local inbox = hooks.useSection("inbox")
	local marks = hooks.useSection("recipeMarks")
	local progression = hooks.useSection("progression")
	local unlocks = hooks.useSection("unlocks")
	-- Recipes unlocked since the catalogue was last closed: the Craft button's count (8.10).
	local newRecipes = 0
	if type(marks) == "table" and progression then
		local progress =
			{ level = progression.level, unlocks = if unlocks then unlocks else { recipes = {}, blueprints = {} } }
		for id, recipe in Content.Recipes do
			if marks.seen[id] ~= true and Crafting.isUnlocked(recipe, progress) then
				newRecipes += 1
			end
		end
	end
	local target = ui.target
	local interactLabel = if ui.panel == "build" then "Place" elseif target then target.verb else "Use"
	local glyph = if target and target.kind == "node"
		then (if target.verb == "Chop" then "🪓" elseif target.verb == "Mine" then "⛏" else "✋")
		else "✋"
	return e("Frame", {
		Size = UDim2.fromOffset(420, 110),
		Position = UDim2.new(1, -16, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Sprint = ui.touch and e(ActionButton, {
			label = "Sprint",
			glyph = "»",
			size = 64,
			layoutOrder = 1,
			onPress = function()
				Actions.setSprint(not ui.sprinting)
			end,
		}),
		Auto = ui.panel == "none" and e(ActionButton, {
			label = if ui.auto then "Auto on" else "Auto",
			keyName = "Q",
			glyph = "🔁",
			primary = ui.auto,
			size = 64,
			layoutOrder = 0,
			onPress = Actions.toggleAuto,
		}),
		Craft = e(ActionButton, {
			label = "Craft",
			keyName = "C",
			glyph = "⚒",
			size = 64,
			layoutOrder = 2,
			onPress = Actions.toggleCrafting,
			badge = newRecipes,
		}),
		Build = e(ActionButton, {
			label = "Build",
			keyName = "B",
			glyph = "🔨",
			size = 64,
			layoutOrder = 3,
			onPress = Actions.toggleBuild,
		}),
		Bag = e(ActionButton, {
			label = "Bag",
			keyName = "Tab",
			glyph = "🎒",
			size = 64,
			layoutOrder = 4,
			onPress = if type(inbox) == "table"
					and #inbox > 0
					and ui.panel ~= "inventory"
				then Actions.openInbox
				else Actions.toggleInventory,
			dot = next(ui.newItems) ~= nil,
			alertAt = ui.bagFullAt,
			badge = if type(inbox) == "table" then #inbox else 0,
		}),
		Interact = e(ActionButton, {
			label = interactLabel,
			keyName = "E",
			glyph = glyph,
			primary = target ~= nil or ui.panel == "build",
			size = 96,
			layoutOrder = 5,
			onPress = function()
				Actions.interact()
				if ui.panel == "none" then
					Actions.setGathering(true)
				end
			end,
			onRelease = function()
				Actions.setGathering(false)
			end,
		}),
	})
end

local function HUD()
	local ui = hooks.useUi()
	local playing = ui.panel == "none"
	return e(React.Fragment, nil, {
		Gear = playing and e("TextButton", {
			Size = UDim2.fromOffset(52, 52),
			Position = UDim2.new(1, -16, 0, 16),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = Theme.colors.panelTransparency,
			FontFace = Theme.fonts.header,
			Text = "⚙",
			TextSize = 28,
			TextColor3 = Theme.colors.text,
			AutoButtonColor = true,
			[React.Event.Activated] = Actions.toggleSettings,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = e("UIStroke", {
				Color = Theme.colors.strokeWarm,
				Thickness = Theme.strokeThickness,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Key = e(KeyChip, { text = "O", position = UDim2.new(1, 2, 0, -2), anchorPoint = Vector2.new(1, 0) }),
		}),
		Status = e(Status),
		Quest = playing and e(QuestTracker),
		Minimap = playing and e(Minimap),
		LevelBar = e(LevelBar),
		-- Studio playtests run sped up (Tuning.devSpeed): say so, never on live servers.
		Dev = DevSpeed.factor(Content) > 1 and e("TextLabel", {
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.new(0.5, 0, 0, 8),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Theme.colors.threat,
			FontFace = Theme.fonts.header,
			Text = `  DEV ×{DevSpeed.factor(Content)}  `,
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.textOnAccent,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
		Hotbar = ui.panel ~= "build" and e(Hotbar),
		Actions = (playing or ui.panel == "build") and e(ActionBar),
	})
end

return HUD
