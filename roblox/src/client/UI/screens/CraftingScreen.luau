--!strict
--[[
	CraftingScreen (C): the crafting catalogue (PLAYER_EXPERIENCE_CHECKLIST 5.9, 5.10).

	Left: category tabs (All, Tools, Weapons, Clothing, Building, Supplies,
	Favourites) over a grid of every recipe. NEW badges mark recipes unlocked since
	the catalogue was last closed; locked recipes are greyed under a padlock with the
	unlock condition in red; available ones sort first.

	Right: the recipe card. The item on a blueprint-style card, stat chips, a
	description and the ingredients with have/need (red when short; counts include
	the home pool, 5.13). Hovering an ingredient says where it comes from (the first
	missing one is shown by default). A quantity bar with -, + and Max, then Craft.
	Station recipes say where they are made instead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local Unlocks = require(ReplicatedStorage.Shared.Domain.Unlocks)
local Crafting = require(ReplicatedStorage.Shared.Domain.Crafting)
local ItemSources = require(ReplicatedStorage.Shared.Domain.ItemSources)
local Actions = require("../../Actions")
local Net = require("../../Net")
local Sfx = require("../../Sfx")
local Theme = require("../theme")
local offers = require("../offers")
local format = require("../format")
local hooks = require("../hooks")
local Button = require("../components/Button")
local ItemIcon = require("../components/ItemIcon")
local Label = require("../components/Label")
local Glyph = require("../components/Glyph")
local LockGlyph = require("../components/LockGlyph")
local Sheet = require("../components/Sheet")
local mark = require("../mark")
local StatPairs = require("../components/StatPairs")

local e = React.createElement

local MAX_BATCH = 10 -- Remotes.MAX_BATCH
local BLUEPRINT = Color3.fromHex("1D2A38")
local BLUEPRINT_LINE = Color3.fromHex("33506B")

local TABS = { "all", "tools", "weapons", "clothing", "building", "supplies", "favourites" }
local TAB_TEXT: { [string]: string } = {
	all = "All",
	tools = "Tools",
	weapons = "Weapons",
	clothing = "Clothing",
	building = "Building",
	supplies = "Supplies",
	favourites = "Favourites",
}
local CATEGORY_TAB: { [string]: string } = {
	tool = "tools",
	weapon = "weapons",
	armor = "clothing",
	bag = "clothing",
	resource = "building",
	material = "building",
	part = "building",
	consumable = "supplies",
}

local function outputDef(recipe: any): any
	return Content.Items[recipe.outputs[1].itemId]
end

local function lockText(recipe: any): string
	return Unlocks.text(recipe.unlock, { items = Content.Items :: any, quests = Content.Quests :: any }) or ""
end

-- The short form under a locked tile ("Ember Trail 4", "Level 6"); the card says it in full.
local function lockShort(recipe: any): string
	return Unlocks.short(recipe.unlock, { items = Content.Items :: any, quests = Content.Quests :: any }) or ""
end

-- Stations the player can build (their piece has an approved model, checklist §0).
local function stationBuildable(stationId: string): boolean
	for id, piece in Content.BuildPieces do
		if piece.stationId == stationId and Art.pieceReady(id, piece.kind) then
			return true
		end
	end
	return false
end

-- Every recipe the player could ever make now: hand recipes, and station recipes whose
-- station can be built (a missing station hides its recipes rather than teasing them).
local function allRecipes(): { any }
	local list = {}
	for _, recipe in Content.Recipes do
		if recipe.stationId == nil or stationBuildable(recipe.stationId) then
			table.insert(list, recipe)
		end
	end
	return list
end

-- Left: one recipe card -------------------------------------------------------------------------------

local function RecipeCard(props: {
	recipe: any,
	unlocked: boolean,
	isNew: boolean,
	favourite: boolean,
	selected: boolean,
	affordable: boolean,
	layoutOrder: number,
	onSelect: () -> (),
})
	local recipe = props.recipe
	local output = recipe.outputs[1]
	local station = recipe.stationId and Content.Stations[recipe.stationId]
	return e("TextButton", {
		Size = UDim2.fromOffset(124, 138),
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = if not props.unlocked then Theme.colors.disabled else Theme.colors.panelRaised,
		[React.Event.Activated] = function()
			props.onSelect()
			Sfx.play("uiClick")
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = if props.selected then Theme.colors.accent else Theme.colors.strokeWarm,
			Thickness = if props.selected then 2 else 1,
			Transparency = if props.selected then 0 else 0.4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Icon = e("Frame", {
			ref = mark.composite, -- the icon, its dim veil and the lock overlap on purpose
			Size = UDim2.fromOffset(72, 72),
			Position = UDim2.new(0.5, 0, 0, 10),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
		}, {
			Inner = e(ItemIcon, { itemId = output.itemId, size = UDim2.fromScale(1, 1) }),
			Dim = not props.unlocked and e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.colors.shadow,
				BackgroundTransparency = 0.45,
				ZIndex = 3,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }) }),
			Lock = not props.unlocked and e(LockGlyph, {
				size = 22,
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 4,
			}),
		}),
		Name = e(Label, {
			text = format.itemName(output.itemId),
			style = "caption",
			tone = if props.unlocked then "text" else "muted",
			wrap = true,
			size = UDim2.new(1, -10, 0, 36),
			position = UDim2.new(0.5, 0, 0, 84),
			anchorPoint = Vector2.new(0.5, 0),
			alignX = Enum.TextXAlignment.Center,
			alignY = Enum.TextYAlignment.Top,
		}),
		Under = e(Label, {
			text = if not props.unlocked then lockShort(recipe) elseif station then station.name else "",
			style = "caption",
			tone = if not props.unlocked then "locked" else "muted",
			size = UDim2.new(1, -8, 0, 16),
			position = UDim2.new(0.5, 0, 1, -18),
			anchorPoint = Vector2.new(0.5, 0),
			alignX = Enum.TextXAlignment.Center,
		}),
		New = props.isNew and e("TextLabel", {
			Size = UDim2.fromOffset(40, 18),
			Position = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Theme.colors.accent,
			FontFace = Theme.fonts.header,
			Text = "NEW",
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.textOnAccent,
			ZIndex = 5,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
		Star = props.favourite and e(Glyph, {
			name = "xp", -- the filled star
			size = UDim2.fromOffset(20, 20),
			position = UDim2.new(1, -6, 0, 4),
			anchorPoint = Vector2.new(1, 0),
			color = Theme.colors.bonus,
			zIndex = 5,
		}),
		Ready = props.unlocked and props.affordable and e("Frame", {
			Size = UDim2.fromOffset(10, 10),
			Position = UDim2.new(1, -8, 1, -8),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor3 = Theme.colors.durability,
			ZIndex = 5,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
	})
end

-- Right: the recipe card -----------------------------------------------------------------------------

local function Ingredient(props: {
	stack: any,
	have: number,
	layoutOrder: number,
	onHover: (string?) -> (),
})
	local short = props.have < props.stack.count
	return e("TextButton", {
		Size = UDim2.fromOffset(86, 104),
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.colors.panelRaised,
		[React.Event.MouseEnter] = function()
			props.onHover(props.stack.itemId)
		end,
		[React.Event.MouseLeave] = function()
			props.onHover(nil)
		end,
		[React.Event.Activated] = function()
			props.onHover(props.stack.itemId) -- tap shows the source on touch
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = if short then Theme.colors.locked else Theme.colors.strokeWarm,
			Thickness = if short then 2 else 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Icon = e(ItemIcon, {
			itemId = props.stack.itemId,
			size = UDim2.fromOffset(54, 54),
			position = UDim2.new(0.5, 0, 0, 6),
			anchorPoint = Vector2.new(0.5, 0),
		}),
		Count = e(Label, {
			text = `{props.have}/{props.stack.count}`,
			style = "number",
			tone = if short then "locked" else "good",
			size = UDim2.new(1, 0, 0, 22),
			position = UDim2.fromOffset(0, 60),
			alignX = Enum.TextXAlignment.Center,
		}),
		Name = e(Label, {
			text = format.itemName(props.stack.itemId),
			style = "caption",
			tone = "muted",
			size = UDim2.new(1, -4, 0, 18),
			position = UDim2.new(0.5, 0, 0, 82),
			anchorPoint = Vector2.new(0.5, 0),
			alignX = Enum.TextXAlignment.Center,
		}),
	})
end

local function QuantityBar(props: { count: number, max: number, onChange: (number) -> () })
	local max = math.max(1, props.max)
	local function step(by: number)
		props.onChange(math.clamp(props.count + by, 1, max))
		Sfx.play("uiClick")
	end
	return e("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, {
		Minus = e(Button, {
			text = "-",
			glyph = "minus",
			variant = "secondary",
			disabled = props.count <= 1,
			size = UDim2.fromOffset(44, 44),
			onActivated = function()
				step(-1)
			end,
		}),
		Track = e("Frame", {
			Size = UDim2.new(1, -204, 0, 12),
			Position = UDim2.new(0, 54, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Theme.colors.track,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = e("Frame", {
				Size = UDim2.fromScale(props.count / max, 1),
				BackgroundColor3 = Theme.colors.accent,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
			Count = e(Label, {
				text = `x{props.count}`,
				style = "section",
				size = UDim2.fromOffset(60, 24),
				position = UDim2.new(0.5, 0, 0, -26),
				anchorPoint = Vector2.new(0.5, 0),
				alignX = Enum.TextXAlignment.Center,
			}),
		}),
		Plus = e(Button, {
			text = "+",
			glyph = "plus",
			variant = "secondary",
			disabled = props.count >= max,
			size = UDim2.fromOffset(44, 44),
			position = UDim2.new(1, -96, 0, 0),
			anchorPoint = Vector2.new(1, 0),
			onActivated = function()
				step(1)
			end,
		}),
		Max = e(Button, {
			text = "Max",
			variant = "secondary",
			disabled = props.count >= max,
			size = UDim2.fromOffset(86, 44),
			position = UDim2.fromScale(1, 0),
			anchorPoint = Vector2.new(1, 0),
			onActivated = function()
				props.onChange(max)
				Sfx.play("uiClick")
			end,
		}),
	})
end

local function Detail(props: { recipe: any, pooled: any, progress: any, unlocked: boolean, favourite: boolean })
	local recipe = props.recipe
	local def = outputDef(recipe)
	local output = recipe.outputs[1]
	local hovered, setHovered = React.useState(nil :: string?)
	local count, setCount = React.useState(1)
	React.useEffect(function()
		setCount(1)
		setHovered(nil)
	end, { recipe.id })

	local station = recipe.stationId and Content.Stations[recipe.stationId]
	local maxRuns = 0
	if props.unlocked and props.pooled then
		for runs = 1, MAX_BATCH do
			local enough = true
			for _, stack in recipe.inputs do
				enough = enough and format.count(props.pooled, stack.itemId) >= stack.count * runs
			end
			if not enough then
				break
			end
			maxRuns = runs
		end
	end
	local runs = math.clamp(count, 1, math.max(1, maxRuns))

	local ingredients: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local firstShort: string? = nil
	for index, stack in recipe.inputs do
		local need = { itemId = stack.itemId, count = stack.count * runs }
		local have = format.count(props.pooled, stack.itemId)
		if have < need.count and firstShort == nil then
			firstShort = stack.itemId
		end
		ingredients[`I{index}`] =
			e(Ingredient, { stack = need, have = have, layoutOrder = index, onHover = setHovered })
	end
	local about = hovered or firstShort
	local sourceLines: { string } = if about then ItemSources.of(Content :: any, about) else {}
	local sourceText = if about
		then `{format.itemName(about)}: {if #sourceLines > 0
			then table.concat(sourceLines, ";  ")
			else "found in the world"}`
		else "Hover an ingredient to see where it comes from."

	local action: any
	if not props.unlocked then
		action = e(Label, {
			text = lockText(recipe),
			style = "section",
			tone = "locked",
			size = UDim2.new(1, 0, 0, 44),
			alignX = Enum.TextXAlignment.Center,
		})
	elseif station then
		action = e(Label, {
			text = `Made at the {station.name}`,
			style = "section",
			tone = "muted",
			size = UDim2.new(1, 0, 0, 44),
			alignX = Enum.TextXAlignment.Center,
		})
	else
		action = e(Button, {
			text = if runs > 1 then `Craft x{runs}` else "Craft",
			disabled = maxRuns == 0,
			size = UDim2.new(1, 0, 0, 52),
			onActivated = function()
				Net.fire("HandCraft", recipe.id, runs)
			end,
		})
	end

	-- Grows to its content; the column scrolls it when a phone's sheet is shorter.
	return e("Frame", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Card = e("Frame", {
			Size = UDim2.new(1, 0, 0, 150),
			BackgroundColor3 = BLUEPRINT,
			LayoutOrder = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = BLUEPRINT_LINE, Thickness = 2 }),
			-- Blueprint grid lines.
			Grid = e(
				"Frame",
				{ ref = mark.decor, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true },
				(function()
					local lines: { [string]: any } = {}
					for i = 1, 11 do
						lines[`V{i}`] = e("Frame", {
							Size = UDim2.new(0, 1, 1, 0),
							Position = UDim2.fromScale(i / 12, 0),
							BackgroundColor3 = BLUEPRINT_LINE,
							BackgroundTransparency = 0.55,
							BorderSizePixel = 0,
						})
					end
					for i = 1, 5 do
						lines[`H{i}`] = e("Frame", {
							Size = UDim2.new(1, 0, 0, 1),
							Position = UDim2.fromScale(0, i / 6),
							BackgroundColor3 = BLUEPRINT_LINE,
							BackgroundTransparency = 0.55,
							BorderSizePixel = 0,
						})
					end
					return lines
				end)()
			),
			Icon = e("Frame", {
				Size = UDim2.fromOffset(120, 120),
				Position = UDim2.fromOffset(16, 15),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, {
				Inner = e(ItemIcon, { itemId = output.itemId, size = UDim2.fromScale(1, 1) }),
			}),
			Name = e(Label, {
				text = if output.count > 1
					then format.stack(output.itemId, output.count)
					else format.itemName(output.itemId),
				style = "title",
				color = if def then Theme.rarity[def.rarity] else nil,
				size = UDim2.new(1, -210, 0, 30),
				position = UDim2.fromOffset(150, 14),
			}),
			Stats = e(StatPairs, {
				itemId = output.itemId,
				size = UDim2.new(1, -166, 0, 66),
				position = UDim2.fromOffset(150, 52),
			}),
			Star = e("TextButton", {
				Size = UDim2.fromOffset(44, 44),
				Position = UDim2.new(1, -8, 0, 8),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = "",
				TextSize = 30,
				TextColor3 = if props.favourite then Theme.colors.bonus else Theme.colors.textMuted,
				[React.Event.Activated] = function()
					Net.fire("RecipeFavourite", recipe.id, not props.favourite)
					Sfx.play("uiClick")
				end,
			}, {
				Glyph = e(Glyph, {
					name = if props.favourite then "xp" else "favourite",
					size = UDim2.fromScale(0.7, 0.7),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					color = if props.favourite then Theme.colors.bonus else Theme.colors.textMuted,
				}),
			}),
		}),
		Description = e(Label, {
			text = if def and def.description then def.description else "",
			style = "body",
			tone = "muted",
			wrap = true,
			size = UDim2.new(1, 0, 0, 48),
			alignY = Enum.TextYAlignment.Top,
			layoutOrder = 2,
		}),
		NeedsTitle = e("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 3 }, {
			Title = e(Label, { text = "NEEDS", style = "section", tone = "accent", size = UDim2.fromScale(0.5, 1) }),
			-- S3 slot (UI/offers): "Fill up" the missing ingredients, only once the shop sets it.
			FillUp = firstShort ~= nil and offers.fillUp ~= nil and e(Button, {
				text = "Fill up",
				variant = "secondary",
				size = UDim2.fromOffset(100, 30),
				position = UDim2.fromScale(1, 0),
				anchorPoint = Vector2.new(1, 0),
				onActivated = function()
					local fillUp = offers.fillUp
					if fillUp then
						fillUp(recipe.inputs)
					end
				end,
			}),
		}),
		Ingredients = e(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 104), BackgroundTransparency = 1, LayoutOrder = 4 },
			ingredients
		),
		Source = e(Label, {
			text = sourceText,
			style = "caption",
			tone = if about then "highlight" else "muted",
			wrap = true,
			size = UDim2.new(1, 0, 0, 38),
			alignY = Enum.TextYAlignment.Top,
			layoutOrder = 5,
		}),
		Quantity = props.unlocked and station == nil and e("Frame", {
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundTransparency = 1,
			LayoutOrder = 6,
		}, {
			Bar = e(QuantityBar, { count = runs, max = maxRuns, onChange = setCount }),
		}),
		Action = e("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = 7 }, {
			Inner = action,
		}),
	})
end

-- Screen --------------------------------------------------------------------------------------------------

local function CraftingScreen()
	local ui = hooks.useUi()
	local open = ui.panel == "crafting"
	local pooled = hooks.usePooled()
	local progression = hooks.useSection("progression")
	local unlocks = hooks.useSection("unlocks")
	local questsState = hooks.useSection("quests")
	local marks = hooks.useSection("recipeMarks")
	local tab, setTab = React.useState("all")
	local selectedId, setSelected = React.useState(nil :: string?)
	local progress = {
		level = if progression then progression.level else 1,
		unlocks = if unlocks then unlocks else { recipes = {}, blueprints = {} },
		quests = if type(questsState) == "table" then questsState else nil,
	}
	local favourites = if type(marks) == "table" then marks.favourites or {} else {}
	local seen = if type(marks) == "table" then marks.seen or {} else {}

	local function affordable(recipe: any): boolean
		if not pooled then
			return false
		end
		for _, stack in recipe.inputs do
			if format.count(pooled, stack.itemId) < stack.count then
				return false
			end
		end
		return true
	end

	-- Available first (can make now, then unlocked), locked last; then by name.
	local list = {}
	for _, recipe in allRecipes() do
		local def = outputDef(recipe)
		local inTab = tab == "all"
			or (tab == "favourites" and favourites[recipe.id] == true)
			or (def ~= nil and CATEGORY_TAB[def.category] == tab)
		if inTab then
			table.insert(list, recipe)
		end
	end
	local rank: { [any]: number } = {}
	for _, recipe in list do
		local unlocked = Crafting.isUnlocked(recipe, progress)
		rank[recipe] = if not unlocked then 3 elseif recipe.stationId then 2 elseif affordable(recipe) then 0 else 1
	end
	table.sort(list, function(a: any, b: any)
		if rank[a] ~= rank[b] then
			return rank[a] < rank[b]
		end
		return format.itemName(a.outputs[1].itemId) < format.itemName(b.outputs[1].itemId)
	end)

	local selected = nil
	for _, recipe in list do
		if recipe.id == selectedId then
			selected = recipe
		end
	end
	selected = selected or list[1]

	local cards: { [string]: any } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(124, 138),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, recipe in list do
		local unlocked = Crafting.isUnlocked(recipe, progress)
		cards[recipe.id] = e(RecipeCard, {
			recipe = recipe,
			unlocked = unlocked,
			isNew = unlocked and seen[recipe.id] ~= true,
			favourite = favourites[recipe.id] == true,
			selected = selected ~= nil and recipe.id == selected.id,
			affordable = affordable(recipe) and recipe.stationId == nil,
			layoutOrder = index,
			onSelect = function()
				setSelected(recipe.id)
			end,
		})
	end

	local tabs: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, key in TABS do
		tabs[key] = e("TextButton", {
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = index,
			AutoButtonColor = false,
			BackgroundColor3 = if tab == key then Theme.colors.accent else Theme.colors.panelRaised,
			FontFace = Theme.fonts.header,
			Text = TAB_TEXT[key],
			TextSize = Theme.textSize.caption,
			TextColor3 = if tab == key then Theme.colors.textOnAccent else Theme.colors.text,
			[React.Event.Activated] = function()
				setTab(key)
				Sfx.play("uiClick")
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
		})
	end

	return e(Sheet, {
		open = open,
		title = "Crafting",
		subtitle = "Everything you can make, and what it takes",
		closeKey = "C",
		onClose = Actions.closePanel,
		size = UDim2.fromOffset(1180, 640),
	}, {
		Tabs = e("Frame", { Size = UDim2.new(0.58, 0, 0, 34), BackgroundTransparency = 1 }, tabs),
		Grid = e("ScrollingFrame", {
			Size = UDim2.new(0.58, 0, 1, -46),
			Position = UDim2.fromOffset(0, 46),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, cards),
		Detail = e("ScrollingFrame", {
			Size = UDim2.new(0.42, -20, 1, 0),
			Position = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, {
			Inner = selected and e(Detail, {
				recipe = selected,
				pooled = pooled,
				progress = progress,
				unlocked = Crafting.isUnlocked(selected, progress),
				favourite = favourites[selected.id] == true,
			}),
		}),
	})
end

return CraftingScreen
