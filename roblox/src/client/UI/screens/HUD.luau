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
	local into, span, fraction = Progression.progress(progression, Content.Levels)
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
		Level = e("TextLabel", {
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.fromOffset(12, -4),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Theme.colors.panel,
			FontFace = Theme.fonts.header,
			Text = ` Lv {progression.level}  ·  {into}/{span} XP `,
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.text,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
	})
end

-- Home minimap (8.11): your outpost from above, north up, with you on it -------------------------------

local MAP_SIZE = 168

local function Minimap()
	local plot = hooks.useSection("plot")
	local saved = hooks.useSection("layout")
	hooks.useClock(0.25)
	if type(plot) ~= "table" or type(saved) ~= "table" then
		return nil
	end
	local cells = plot.cells
	local scale = MAP_SIZE / (cells * 12)
	local layout = Grid.deserialize(saved, Content.BuildPieces :: any)
	if layout == nil then
		return nil
	end
	local children: { [string]: any } = {
		Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = Theme.strokeThickness }),
	}
	for uid, piece in layout.pieces do
		local def = Content.BuildPieces[piece.pieceId]
		if def == nil then
			continue
		end
		if piece.layer == "floor" then
			children[`F{uid}`] = e("Frame", {
				Size = UDim2.fromOffset(12 * scale, 12 * scale),
				Position = UDim2.fromOffset(piece.x * 12 * scale, piece.z * 12 * scale),
				BackgroundColor3 = Color3.fromRGB(122, 96, 70),
				BorderSizePixel = 0,
			})
		elseif piece.layer == "frame" then
			local horizontal = piece.axis == "h"
			children[`W{uid}`] = e("Frame", {
				Size = if horizontal then UDim2.fromOffset(12 * scale, 3) else UDim2.fromOffset(3, 12 * scale),
				Position = UDim2.fromOffset(piece.x * 12 * scale - 1, piece.z * 12 * scale - 1),
				BackgroundColor3 = Theme.colors.text,
				BorderSizePixel = 0,
				ZIndex = 2,
			})
		elseif piece.layer == "object" then
			local cx, cz = Grid.objectCenter(def, piece :: any)
			children[`O{uid}`] = e("Frame", {
				Size = UDim2.fromOffset(6, 6),
				Position = UDim2.fromOffset(cx * scale, cz * scale),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = if def.kind == "station" then Theme.colors.accent else Theme.colors.highlight,
				ZIndex = 3,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
	end
	-- Resource nodes and trees standing on your plot (8.11).
	local nodesFolder: Instance? = nil
	local world = workspace:FindFirstChild("World")
	local plotsFolder = world and world:FindFirstChild("Plots")
	for _, plotModel in (if plotsFolder then plotsFolder:GetChildren() else {}) do
		local nodes = plotModel:FindFirstChild("Nodes")
		local sample = nodes and nodes:FindFirstChildWhichIsA("Model")
		if sample and sample:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			nodesFolder = nodes
		end
	end
	local nodeList: { Instance } = if nodesFolder then (nodesFolder :: Instance):GetChildren() else {}
	for index, node in nodeList do
		local id = node:GetAttribute("NodeId")
		if node:IsA("Model") and id then
			local at = node:GetPivot().Position - plot.origin
			if at.X >= 0 and at.Z >= 0 and at.X <= cells * 12 and at.Z <= cells * 12 then
				children[`N{index}`] = e("Frame", {
					Size = UDim2.fromOffset(5, 5),
					Position = UDim2.fromOffset(at.X * scale, at.Z * scale),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = if id == "node.pine_tree"
						then Color3.fromRGB(70, 110, 64)
						else Theme.colors.textMuted,
					ZIndex = 2,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
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
		ZIndex = 5,
	})
	-- You: an arrow that turns with the survivor; off the plot it waits on the rim.
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local rel = root.Position - plot.origin
		local look = root.CFrame.LookVector
		children.You = e("TextLabel", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.fromOffset(math.clamp(rel.X * scale, 0, MAP_SIZE), math.clamp(rel.Z * scale, 0, MAP_SIZE)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = "▲",
			TextSize = 20,
			TextColor3 = Theme.colors.highlight,
			TextStrokeColor3 = Theme.colors.shadow,
			TextStrokeTransparency = 0,
			Rotation = math.deg(math.atan2(look.X, -look.Z)),
			ZIndex = 4,
		})
	end
	return e(
		"Frame",
		{
			Size = UDim2.fromOffset(MAP_SIZE, MAP_SIZE),
			Position = UDim2.new(1, -16, 0, 80),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Color3.fromRGB(46, 58, 44),
			BackgroundTransparency = 0.1,
			ClipsDescendants = true,
		},
		(function()
			children.Round = e("UICorner", { CornerRadius = UDim.new(1, 0) })
			return children
		end)()
	)
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
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.fromOffset(6, -12), -- above the icon, clear of the neighbour's key chip and the label
			BackgroundColor3 = Theme.colors.locked,
			FontFace = Theme.fonts.header,
			Text = if (props.badge or 0) > 99 then "99+" else tostring(props.badge),
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.textOnAccent,
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
