--!strict
--[[
	BuildMenu (B): a bottom tray in build mode (GAME_DESIGN.md "Building").
	Tabs: Foundations, Walls, Doors, Windows, Stations, Storage. Each card shows
	the piece's real model, name, HP, cost (have / need) and lock state. The
	mode bar switches between Place, Upgrade (U) and Demolish (X), with R to
	rotate and B to leave. The cursor hint above it says why a spot is invalid
	or what the piece costs. On touch, a Place button confirms the ghost.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local BuildRules = require(ReplicatedStorage.Shared.Domain.BuildRules)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local Actions = require("../../Actions")
local Theme = require("../theme")
local hooks = require("../hooks")
local format = require("../format")
local Button = require("../components/Button")
local ItemIcon = require("../components/ItemIcon")
local KeyChip = require("../components/KeyChip")
local Label = require("../components/Label")
local LockGlyph = require("../components/LockGlyph")
local ModelView = require("../components/ModelView")
local Sheet = require("../components/Sheet")

local e = React.createElement

local TABS: { { id: string, label: string, kinds: { [string]: boolean } } } = {
	{ id = "foundation", label = "Foundations", kinds = { foundation = true } },
	{ id = "wall", label = "Walls", kinds = { wall = true } },
	{ id = "door", label = "Doors", kinds = { doorway = true, door = true, gate = true } },
	{ id = "window", label = "Windows", kinds = { window = true } },
	{ id = "station", label = "Stations", kinds = { station = true } },
	{ id = "storage", label = "Storage", kinds = { storage = true } },
}

local CARD_W, CARD_H = 124, 146 -- compact, like LDoE's build strip

local function pieceModel(pieceId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local pieces = assets and assets:FindFirstChild("Pieces")
	local model = pieces and pieces:FindFirstChild(pieceId)
	return if model and model:IsA("Model") then model else nil
end

local function lockText(def: any, progress: BuildRules.Progress): string?
	if BuildRules.isUnlocked(def, progress) then
		return nil
	end
	local gate = def.unlock
	if gate and gate.kind == "level" then
		return `Level {gate.level}`
	end
	return "Blueprint"
end

local function Card(props: {
	def: any,
	selected: boolean,
	inventory: any,
	progress: BuildRules.Progress,
	placed: number,
	limit: number?,
	layoutOrder: number,
})
	local def = props.def
	local hovering, setHovering = React.useState(false)
	local lift = hooks.useAnimated(if hovering or props.selected then 1 else 0, 18)
	local locked = lockText(def, props.progress)
	local model = pieceModel(def.id)
	local costs: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	}
	for index, stack in def.cost do
		local have = format.count(props.inventory, stack.itemId)
		costs[`C{index}`] = e(
			"Frame",
			{ Size = UDim2.fromOffset(44, 26), BackgroundTransparency = 1, LayoutOrder = index },
			{
				Icon = e(
					"Frame",
					{ Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(0, 2), BackgroundTransparency = 1 },
					{
						Inner = e(ItemIcon, { itemId = stack.itemId, size = UDim2.fromScale(1, 1) }),
					}
				),
				Count = e(Label, {
					text = tostring(stack.count),
					style = "caption",
					tone = if have >= stack.count then "text" else "accent",
					size = UDim2.new(1, -24, 1, 0),
					position = UDim2.fromOffset(24, 0),
				}),
			}
		)
	end
	return e("TextButton", {
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = if props.selected
			then Theme.colors.panelRaised:Lerp(Theme.colors.accent, 0.18)
			else Theme.colors.panelRaised,
		BackgroundTransparency = if locked then 0.4 else 0,
		[React.Event.Activated] = function()
			if locked == nil then
				Actions.selectPiece(def.id)
			end
		end,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = if props.selected then Theme.colors.accent else Theme.colors.strokeWarm,
			Thickness = if props.selected then 3 else Theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Scale = e("UIScale", {
			Scale = lift:map(function(v: number)
				return 1 + v * 0.04
			end),
		}),
		Preview = model and e(ModelView, {
			model = model,
			size = UDim2.new(1, -12, 0, 70),
			position = UDim2.fromOffset(6, 4),
			yaw = 40,
			pitch = 32,
		}),
		Name = e(Label, {
			text = def.name,
			style = "caption",
			size = UDim2.new(1, -12, 0, 18),
			position = UDim2.fromOffset(6, 74),
			alignX = Enum.TextXAlignment.Center,
		}),
		-- Placement limits are shown where they apply (5.11): "Placed 1/2".
		Hp = e(Label, {
			text = if props.limit then `Placed {props.placed}/{props.limit}` else `{def.hp} HP · Tier {def.tier}`,
			style = "caption",
			tone = if props.limit and props.placed >= props.limit then "locked" else "muted",
			size = UDim2.new(1, -12, 0, 16),
			position = UDim2.fromOffset(6, 92),
			alignX = Enum.TextXAlignment.Center,
		}),
		Costs = e("Frame", {
			Size = UDim2.new(1, -8, 0, 26),
			Position = UDim2.new(0, 4, 1, -34),
			BackgroundTransparency = 1,
		}, costs),
		Lock = locked and e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.colors.shadow,
			BackgroundTransparency = 0.35,
			ZIndex = 5,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Glyph = e(LockGlyph, {
				size = 22,
				position = UDim2.new(0.5, 0, 0.5, -18),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 6,
			}),
			Text = e(Label, {
				text = locked,
				style = "caption",
				tone = "locked",
				wrap = true,
				size = UDim2.new(1, -10, 0, 40),
				position = UDim2.new(0.5, 0, 0.5, 6),
				anchorPoint = Vector2.new(0.5, 0),
				alignX = Enum.TextXAlignment.Center,
				alignY = Enum.TextYAlignment.Top,
				zIndex = 6,
			}),
		}),
	})
end

local function ModeButton(props: {
	label: string,
	keyName: string,
	active: boolean,
	onActivated: () -> (),
	layoutOrder: number,
})
	return e(
		"Frame",
		{ Size = UDim2.fromOffset(120, 44), BackgroundTransparency = 1, LayoutOrder = props.layoutOrder },
		{
			Button = e(Button, {
				text = props.label,
				variant = if props.active then "primary" else "secondary",
				size = UDim2.fromOffset(120, 44),
				onActivated = props.onActivated,
			}),
			Key = e(KeyChip, {
				text = props.keyName,
				position = UDim2.new(1, 4, 0, -6),
				anchorPoint = Vector2.new(1, 0),
				accent = props.active,
			}),
		}
	)
end

local function BuildMenu()
	local ui = hooks.useUi()
	local inventory = hooks.usePooled() -- costs count the whole home pool (5.13)
	local saved = hooks.useSection("layout")
	local layout = React.useMemo(function()
		return if saved then Grid.deserialize(saved, Content.BuildPieces :: any) else nil
	end, { saved })
	local progression = hooks.useSection("progression")
	local unlocks = hooks.useSection("unlocks")
	local tab, setTab = React.useState("foundation")
	local open = ui.panel == "build"
	local progress: BuildRules.Progress = {
		level = if progression then progression.level else 1,
		unlocks = if unlocks then unlocks else { recipes = {}, blueprints = {} },
	}

	local current = TABS[1]
	for _, entry in TABS do
		if entry.id == tab then
			current = entry
		end
	end

	local tabs: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, entry in TABS do
		local active = entry.id == tab
		tabs[entry.id] = e("TextButton", {
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = string.upper(entry.label),
			TextSize = Theme.textSize.caption + 1,
			TextColor3 = if active then Theme.colors.accent else Theme.colors.textMuted,
			LayoutOrder = index,
			[React.Event.Activated] = function()
				setTab(entry.id)
			end,
		}, {
			Underline = active and e("Frame", {
				Size = UDim2.new(1, 0, 0, 2),
				Position = UDim2.fromScale(0, 1),
				BackgroundColor3 = Theme.colors.accent,
				BorderSizePixel = 0,
			}),
		})
	end

	local cards: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, def in BuildRules.catalog(Content.BuildPieces) do
		if current.kinds[def.kind] then
			cards[def.id] = e(Card, {
				def = def,
				selected = ui.buildPiece == def.id and ui.buildMode == "place",
				inventory = inventory,
				placed = if layout then BuildRules.countChain(layout, def.id, Content.BuildPieces :: any) else 0,
				limit = BuildRules.limitOf(def.id, Content.BuildPieces :: any),
				progress = progress,
				layoutOrder = index,
			})
		end
	end

	local hint = ui.buildHint
	return e(React.Fragment, nil, {
		Hint = open and hint and e("Frame", {
			Size = UDim2.fromOffset(0, 36),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.new(0.5, 0, 1, -302),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = 0.1,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = 1 }),
			Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
			Text = e(Label, { text = hint, style = "body", autoWidth = true, size = UDim2.fromOffset(0, 36) }),
		}),
		Tray = e(Sheet, {
			open = open,
			title = "Build",
			subtitle = "LMB place · drag to paint floors and walls",
			closeKey = "B",
			onClose = Actions.toggleBuild,
			size = UDim2.fromOffset(1180, 250),
			position = UDim2.new(0.5, 0, 1, -8),
			anchorPoint = Vector2.new(0.5, 1),
			rise = 40,
		}, {
			Tabs = e("Frame", { Size = UDim2.new(1, -420, 0, 30), BackgroundTransparency = 1 }, tabs),
			Modes = e("Frame", {
				Size = UDim2.fromOffset(400, 44),
				Position = UDim2.new(1, 0, 0, -6),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Rotate = e(
					ModeButton,
					{ label = "Rotate", keyName = "R", active = false, onActivated = Actions.rotate, layoutOrder = 0 }
				),
				Upgrade = e(ModeButton, {
					label = "Upgrade",
					keyName = "U",
					active = ui.buildMode == "upgrade",
					layoutOrder = 1,
					onActivated = function()
						Actions.buildMode("upgrade")
					end,
				}),
				Demolish = e(ModeButton, {
					label = "Demolish",
					keyName = "X",
					active = ui.buildMode == "demolish",
					layoutOrder = 2,
					onActivated = function()
						Actions.buildMode("demolish")
					end,
				}),
			}),
			Cards = e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 0, CARD_H + 12),
				Position = UDim2.fromOffset(0, 40),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollingDirection = Enum.ScrollingDirection.X,
				ScrollBarThickness = 4,
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				CanvasSize = UDim2.new(),
			}, {
				Padding = e("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4) }),
				List = e(React.Fragment, nil, cards),
			}),
			Place = ui.touch and ui.buildMode == "place" and ui.buildPiece and e(Button, {
				text = "Place",
				size = UDim2.fromOffset(140, 48),
				position = UDim2.new(1, 0, 1, -48),
				anchorPoint = Vector2.new(1, 0),
				onActivated = Actions.interact,
			}),
		}),
	})
end

return BuildMenu
