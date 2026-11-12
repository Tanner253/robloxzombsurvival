--!strict
--[[
	Build: LDoE's build mode (LDOE_PARITY #25-28; rec2_07, rec2_08).
	- The HUD hides (the Ember Trail tracker stays); a round "hide upper walls" toggle sits
	  at the top left.
	- The tray along the bottom: icon tabs (Building, Stations, Storage, Defense; Furniture
	  & decor and the starred tab join when they have pieces) with the active tab's name, a
	  CLOSE at the right, and a row of cards: the piece's real model, its name, cost chips
	  with have/need, "Installed x/y" on placeables, a NEW ribbon on pieces a quest just
	  unlocked, and the lock text naming the quest. A cost nothing unlocked can make yet adds
	  where it will come from ("Stonecutter: Ember Trail 4", the flow review's F-34).
	- The card being placed, short of materials, puts "Fill up (coin) N" in the tray's
	  header beside CLOSE (F-10, LDOE_PARITY #28: the crafting pane's Fill Up).
	- Click a placed piece (with no card picked) for its floating actions: move (objects),
	  demolish (red) and upgrade (green, with the next tier's have/need, and Fill up when
	  it is short). R, U and X stay.
	- The cursor hint sits above the tray.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local BuildRules = require(ReplicatedStorage.Shared.Domain.BuildRules)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local ItemSources = require(ReplicatedStorage.Shared.Domain.ItemSources)
local Offers = require(ReplicatedStorage.Shared.Domain.Offers)
local Unlocks = require(ReplicatedStorage.Shared.Domain.Unlocks)
local Actions = require("../../../Actions")
local Building = require("../../../Controllers/Building")
local Net = require("../../../Net")
local State = require("../../../State")
local Theme = require("../../theme")
local hooks = require("../../hooks")
local format = require("../../format")
local mark = require("../../mark")
local offers = require("../../offers")
local CostChip = require("../../components/CostChip")
local Glyph = require("../../components/Glyph")
local IconButton = require("../../components/IconButton")
local Layout = require("../../components/Layout")
local ModelView = require("../../components/ModelView")
local PriceButton = require("../../components/PriceButton")

local e = React.createElement
local H = Theme.hud

local TABS: { { id: string, label: string, glyph: string, kinds: { [string]: boolean } } } = {
	{
		id = "building",
		label = "Building",
		glyph = "build",
		kinds = { foundation = true, wall = true, doorway = true, door = true, gate = true, window = true, roof = true },
	},
	{ id = "stations", label = "Stations", glyph = "station", kinds = { station = true } },
	{ id = "storage", label = "Storage", glyph = "storage", kinds = { storage = true } },
	{ id = "furniture", label = "Furniture & decor", glyph = "furniture", kinds = { furniture = true } },
	{ id = "defense", label = "Defense", glyph = "defense", kinds = {} },
}

local CARD = Vector2.new(132, 156)
-- A card with a source line (F-34) is wider, so the line reads at caption size.
local WIDE_CARD = 176
local NAMES = { items = Content.Items :: any, quests = Content.Quests :: any }

local function pieceModel(pieceId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local pieces = assets and assets:FindFirstChild("Pieces")
	local model = pieces and pieces:FindFirstChild(pieceId)
	return if model and model:IsA("Model") then model else nil
end

local function tabOf(def: any): string
	if def.tab then
		return def.tab
	end
	for _, tab in TABS do
		if tab.kinds[def.kind] then
			return tab.id
		end
	end
	return "building"
end

local function progressNow(): Unlocks.Progress
	local p = State.get("progression")
	local unlocks = State.get("unlocks")
	local quests = State.get("quests")
	return {
		level = if p then p.level else 1,
		unlocks = if type(unlocks) == "table" then unlocks else { recipes = {}, blueprints = {} },
		quests = if type(quests) == "table" then quests else nil,
	}
end

-- Pieces a quest unlocked this session, until their card is picked (the NEW ribbon).
local fresh: { [string]: boolean } = {}
State.fx:Connect(function(kind: any, payload: any)
	if kind == "questDone" and type(payload) == "table" then
		for _, pieceId in payload.pieces or {} do
			fresh[pieceId] = true
		end
	end
end)

-- The Fill Up slot for a cost (the flow review's F-10, LDOE_PARITY #28): the missing stacks
-- and their Ember price, or nil when nothing is short or a short item is never sold.
local function fillUpFor(cost: { any }, pooled: any): ({ any }?, number?)
	if offers.fillUp == nil then
		return nil, nil
	end
	return Offers.fillUpFor(cost, function(itemId: string): number
		return format.count(pooled, itemId)
	end, Content.Tuning.embers :: any)
end

-- The crafting pane's Fill Up, as a price button: "Fill up (coin) 12" asks to buy the
-- shortfall (screens/ldoe/EmberConfirm, GET EMBERS when the balance is short).
local function FillUpButton(props: { short: { any }, price: number, size: UDim2, layoutOrder: number })
	return e(PriceButton, {
		currency = "embers",
		label = "Fill up",
		price = props.price,
		enabled = true,
		size = props.size,
		layoutOrder = props.layoutOrder,
		onActivated = function()
			local fillUp = offers.fillUp
			if fillUp then
				fillUp(props.short)
			end
		end,
	})
end

local function Card(props: { def: any, pooled: any, layout: any, selected: boolean, layoutOrder: number })
	local def = props.def
	local progress = progressNow()
	local unlocked = BuildRules.isUnlocked(def, progress)
	local lock = if unlocked
		then nil
		else Unlocks.short(def.unlock, { items = Content.Items :: any, quests = Content.Quests :: any })
	local plot = State.get("plot")
	local limit =
		BuildRules.limitOf(def.id, Content.BuildPieces, if type(plot) == "table" then plot.pieceSlots else nil)
	local installed = if props.layout then BuildRules.countChain(props.layout, def.id, Content.BuildPieces) else 0
	local placeable = def.kind == "station" or def.kind == "storage" or def.kind == "furniture"
	local model = pieceModel(def.id)
	local costs: { [string]: any } = {}
	-- F-34: a cost nothing unlocked can make yet says where it will come from, so an open card
	-- that can't be built yet tells you why ("Stonecutter: Ember Trail 4" under the red chip).
	local source: string? = nil
	if unlocked then
		for _, stack in def.cost do
			local maker = ItemSources.lockedMaker(Content :: any, stack.itemId, progress, NAMES)
			if maker and format.count(props.pooled, stack.itemId) < stack.count then
				source = maker
				break
			end
		end
	end
	for index, stack in def.cost do
		costs[`C{index}`] = e(CostChip, {
			itemId = stack.itemId,
			have = format.count(props.pooled, stack.itemId),
			need = stack.count,
			size = 20,
			layoutOrder = index,
		})
	end
	return e("TextButton", {
		Size = UDim2.fromOffset(if source then WIDE_CARD else CARD.X, CARD.Y),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = if props.selected
			then Theme.colors.panelRaised:Lerp(Theme.colors.chip, 0.35)
			else Theme.colors.panelRaised,
		BackgroundTransparency = if unlocked then 0.05 else 0.4,
		[React.Event.Activated] = function()
			if unlocked then
				fresh[def.id] = nil
				Building.cancelMove()
				Actions.selectPiece(def.id)
			end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = e("UIStroke", {
			Color = if props.selected then Theme.colors.badge else Theme.colors.strokeWarm,
			Thickness = if props.selected then 3 else 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Column = e(Layout.Stack, {
			gap = 2,
			alignX = Enum.HorizontalAlignment.Center,
			padding = 6,
			children = {
				Preview = e("Frame", {
					-- The model gives up a line's height when the card carries a source line.
					Size = UDim2.new(1, 0, 0, if source then 46 else 62),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				}, {
					View = model and e(ModelView, { model = model, size = UDim2.fromScale(1, 1) }),
				}),
				Name = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.header,
					Text = def.name,
					TextSize = Theme.textSize.caption,
					TextColor3 = if unlocked then Theme.colors.text else Theme.colors.disabledText,
					TextWrapped = true,
					LayoutOrder = 2,
				}),
				Costs = unlocked and e(Layout.Stack, {
					direction = "row",
					gap = 4,
					alignX = Enum.HorizontalAlignment.Center,
					wraps = true,
					size = UDim2.new(1, 0, 0, 44),
					layoutOrder = 3,
					children = costs,
				}),
				Lock = lock and e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 44),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.body,
					Text = lock,
					TextSize = Theme.textSize.caption,
					TextColor3 = Theme.colors.locked,
					TextWrapped = true,
					LayoutOrder = 3,
				}),
				Installed = placeable and limit and e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.body,
					Text = `Installed {installed}/{limit}`,
					TextSize = Theme.textSize.caption,
					TextColor3 = if installed >= limit then Theme.colors.locked else Theme.colors.textMuted,
					LayoutOrder = 4,
				}),
				Source = source and e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.body,
					Text = source,
					TextScaled = true,
					TextColor3 = Theme.colors.locked,
					LayoutOrder = 5,
				}, {
					Max = e("UITextSizeConstraint", { MaxTextSize = Theme.textSize.caption }),
				}),
			},
		}),
		New = fresh[def.id] and e("TextLabel", {
			-- LDoE's corner ribbon: a NEW tag over the card's top-right corner.
			Size = UDim2.fromOffset(40, 16),
			Position = UDim2.new(1, -2, 0, 2),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Theme.colors.badge,
			FontFace = Theme.fonts.header,
			Text = "NEW",
			TextSize = Theme.textSize.caption - 2,
			TextColor3 = Theme.colors.text,
			ref = mark.overlay,
		}),
	})
end

-- The floating actions on a selected placed piece (#27): a row that follows the piece on
-- screen, just above its top. It lives in the App (screen space), not on a BillboardGui:
-- S1b found AlwaysOnTop billboards don't draw in Studio's captures, and screen space also
-- keeps the row inside the UI gate and the safe area.
local function PieceActions(props: { uid: string, layout: any, pooled: any })
	local model = Building.pieceModel(props.uid)
	local piece = props.layout and props.layout.pieces[props.uid]
	local holder = React.useRef(nil :: Frame?)
	local position, setPosition = React.useBinding(UDim2.fromScale(-1, -1))
	React.useEffect(function()
		local target = model
		if target == nil then
			return function() end
		end
		local connection = RunService.RenderStepped:Connect(function()
			local camera = workspace.CurrentCamera
			local frame = holder.current
			if camera == nil or frame == nil or target.Parent == nil then
				return
			end
			local box, extents = target:GetBoundingBox()
			local point, onScreen = camera:WorldToViewportPoint(box.Position + Vector3.new(0, extents.Y / 2 + 1, 0))
			if not onScreen or frame.AbsoluteSize.X <= 0 then
				setPosition(UDim2.fromScale(-1, -1))
				return
			end
			-- Viewport pixels -> this frame's share (GUI space starts below the top-bar inset).
			local inset = GuiService:GetGuiInset()
			local gui = Vector2.new(point.X, point.Y) - inset
			local share = (gui - frame.AbsolutePosition) / frame.AbsoluteSize
			setPosition(UDim2.fromScale(share.X, share.Y))
		end)
		return function()
			connection:Disconnect()
		end
	end, { model })
	if model == nil or piece == nil then
		return nil
	end
	local def = Content.BuildPieces[piece.pieceId]
	local nextDef = if def.upgradesTo then Content.BuildPieces[def.upgradesTo] else nil
	local costs: { [string]: any } = {}
	-- F-10: an upgrade short of plates has its buy button beside the costs.
	local upShort, upPrice = nil, nil
	if nextDef and BuildRules.isUnlocked(nextDef, progressNow()) then
		upShort, upPrice = fillUpFor(nextDef.cost, props.pooled)
	end
	if nextDef then
		for index, stack in nextDef.cost do
			costs[`C{index}`] = e(CostChip, {
				itemId = stack.itemId,
				have = format.count(props.pooled, stack.itemId),
				need = stack.count,
				size = 22,
				layoutOrder = index,
			})
		end
	end
	local buttons: { [string]: any } = {
		Move = piece.layer == "object" and e(IconButton, {
			glyph = "move",
			size = 52,
			ring = Theme.colors.badge,
			active = true,
			layoutOrder = 1,
			onPress = function()
				Building.beginMove(props.uid)
			end,
		}),
		Demolish = e(IconButton, {
			glyph = "trash",
			size = 52,
			ring = Theme.colors.danger,
			active = true,
			layoutOrder = 2,
			onPress = function()
				Net.fire("BuildDemolish", props.uid)
				State.clear("pieceActions")
			end,
		}),
		Upgrade = nextDef and e(Layout.Stack, {
			direction = "row",
			gap = 4,
			alignY = Enum.VerticalAlignment.Center,
			size = UDim2.fromOffset(0, 52),
			autoSize = Enum.AutomaticSize.X,
			layoutOrder = 3,
			children = {
				Button = e(IconButton, {
					glyph = "upgrade",
					size = 52,
					ring = Theme.colors.upgrade,
					active = true,
					layoutOrder = 1,
					onPress = function()
						Net.fire("BuildUpgrade", props.uid)
					end,
				}),
				Costs = e(Layout.Stack, {
					gap = 2,
					size = UDim2.fromOffset(70, 52),
					layoutOrder = 2,
					children = costs,
				}),
				FillUp = upShort and upPrice and e(FillUpButton, {
					short = upShort,
					price = upPrice,
					size = UDim2.fromOffset(150, 44),
					layoutOrder = 3,
				}),
			},
		}),
	}
	return e("Frame", {
		ref = holder,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Row = e(Layout.Stack, {
			direction = "row",
			gap = 8,
			alignX = Enum.HorizontalAlignment.Center,
			alignY = Enum.VerticalAlignment.Center,
			size = UDim2.fromOffset(if upShort then 440 else 280, 64),
			position = position,
			anchorPoint = Vector2.new(0.5, 1),
			children = buttons,
		}),
	})
end

local function Build()
	local ui = hooks.useUi()
	local saved = hooks.useSection("layout")
	hooks.useSection("quests")
	local pooled = hooks.usePooled()
	local tab, setTab = React.useState("building")
	local open = ui.panel == "build"
	local layout = React.useMemo(function()
		return if type(saved) == "table" then Grid.deserialize(saved, Content.BuildPieces :: any) else nil
	end, { saved })
	if not open then
		return nil
	end

	local byTab: { [string]: { any } } = {}
	for _, def in BuildRules.catalog(Content.BuildPieces) do
		if Art.pieceReady(def.id, def.kind) then
			local id = tabOf(def)
			byTab[id] = byTab[id] or {}
			table.insert(byTab[id], def)
		end
	end
	local tabs: { [string]: any } = {}
	local order = 0
	for _, entry in TABS do
		local list = byTab[entry.id]
		if list and #list > 0 then
			order += 1
			local active = entry.id == tab
			tabs[entry.id] = e("TextButton", {
				Size = UDim2.fromOffset(if active then 0 else 44, 40),
				AutomaticSize = if active then Enum.AutomaticSize.X else nil,
				BackgroundTransparency = 1,
				Text = "",
				LayoutOrder = order,
				[React.Event.Activated] = function()
					setTab(entry.id)
				end,
			}, {
				Row = e(Layout.Stack, {
					direction = "row",
					gap = 6,
					alignY = Enum.VerticalAlignment.Center,
					size = UDim2.fromScale(0, 1),
					autoSize = Enum.AutomaticSize.X,
					children = {
						Icon = e(Glyph, {
							name = entry.glyph,
							size = UDim2.fromOffset(28, 28),
							color = if active then Theme.colors.text else Theme.colors.textMuted,
							layoutOrder = 1,
						}),
						Label = active and e("TextLabel", {
							Size = UDim2.fromOffset(0, 28),
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							FontFace = Theme.fonts.header,
							Text = string.upper(entry.label),
							TextSize = Theme.textSize.section,
							TextColor3 = Theme.colors.text,
							LayoutOrder = 2,
						}),
					},
				}),
				Underline = active and e("Frame", {
					Size = UDim2.new(1, 0, 0, 3),
					Position = UDim2.fromScale(0, 1),
					AnchorPoint = Vector2.new(0, 1),
					BackgroundColor3 = Theme.colors.badge,
					BorderSizePixel = 0,
				}),
			})
		end
	end

	local cards: { [string]: any } = {}
	local shown: { any } = byTab[tab] or {}
	for index, def in shown do
		cards[def.id] = e(Card, {
			def = def,
			pooled = pooled,
			layout = layout,
			selected = ui.buildPiece == def.id,
			layoutOrder = index,
		})
	end

	-- F-10: the card being placed, short of materials, gets its Fill Up in the tray's header.
	local selected = if ui.buildPiece then Content.BuildPieces[ui.buildPiece] else nil
	local fillShort, fillPrice = nil, nil
	if selected and BuildRules.isUnlocked(selected, progressNow()) then
		fillShort, fillPrice = fillUpFor(selected.cost, pooled)
	end

	local touch = ui.touch or (ui.gate ~= nil and ui.gate.touch)
	local touchRight = if touch then math.ceil(H.touchJumpReserve / (Theme.currentScale or 1)) else 0
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.layers.hud,
	}, {
		HideWalls = e(IconButton, {
			glyph = "hide_walls",
			size = 64,
			active = ui.hideUpperWalls == true,
			position = UDim2.fromOffset(H.edge, H.edge),
			onPress = function()
				State.patch({ hideUpperWalls = not State.ui().hideUpperWalls })
			end,
		}),
		Hint = ui.buildHint and e("TextLabel", {
			Size = UDim2.fromOffset(0, 32),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.new(0.5, 0, 1, -(H.trayHeight + 52 + Theme.spacing.md)),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = 0.15,
			FontFace = Theme.fonts.body,
			Text = ui.buildHint,
			TextSize = Theme.textSize.body,
			TextColor3 = Theme.colors.text,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Padding = Layout.pad(0, { left = 12, right = 12 }),
		}),
		-- On touch the tray runs between Roblox's thumbstick zone and its jump button: you
		-- still walk while building.
		Tray = e(Layout.Stack, {
			size = if touch
				then UDim2.new(1 - H.touchStickShare, -touchRight, 0, H.trayHeight + 52)
				else UDim2.new(1, 0, 0, H.trayHeight + 52),
			position = if touch then UDim2.fromScale(H.touchStickShare, 1) else UDim2.fromScale(0, 1),
			anchorPoint = Vector2.new(0, 1),
			children = {
				Tabs = e("Frame", {
					Size = UDim2.new(1, 0, 0, 48),
					BackgroundColor3 = Theme.colors.panel,
					BackgroundTransparency = 0.25,
					BorderSizePixel = 0,
					LayoutOrder = 1,
				}, {
					Row = e(Layout.Stack, {
						direction = "row",
						gap = Theme.spacing.lg,
						alignY = Enum.VerticalAlignment.Center,
						padding = Theme.spacing.sm,
						children = {
							Tabs = e(Layout.Fill, {
								direction = "row",
								layoutOrder = 1,
								children = {
									Row = e(Layout.Stack, {
										direction = "row",
										gap = Theme.spacing.lg,
										alignY = Enum.VerticalAlignment.Center,
										children = tabs,
									}),
								},
							}),
							FillUp = fillShort and fillPrice and e(FillUpButton, {
								short = fillShort,
								price = fillPrice,
								size = UDim2.fromOffset(170, 40),
								layoutOrder = 2,
							}),
							Close = e("TextButton", {
								Size = UDim2.fromOffset(120, 40),
								BackgroundTransparency = 1,
								Text = "",
								LayoutOrder = 3,
								[React.Event.Activated] = function()
									Building.cancelMove()
									State.clear("pieceActions")
									Actions.toggleBuild()
								end,
							}, {
								Row = e(Layout.Stack, {
									direction = "row",
									gap = 6,
									alignX = Enum.HorizontalAlignment.Right,
									alignY = Enum.VerticalAlignment.Center,
									children = {
										Label = e("TextLabel", {
											Size = UDim2.fromOffset(70, 28),
											BackgroundTransparency = 1,
											FontFace = Theme.fonts.header,
											Text = "CLOSE",
											TextSize = Theme.textSize.section,
											TextColor3 = Theme.colors.text,
											LayoutOrder = 1,
										}),
										X = e(Glyph, {
											name = "close",
											size = UDim2.fromOffset(24, 24),
											layoutOrder = 2,
										}),
									},
								}),
							}),
						},
					}),
				}),
				Cards = e("ScrollingFrame", {
					Size = UDim2.new(1, 0, 0, H.trayHeight + 4),
					CanvasSize = UDim2.fromScale(0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.X,
					ScrollingDirection = Enum.ScrollingDirection.X,
					ScrollBarThickness = 4,
					BackgroundColor3 = Theme.colors.panel,
					BackgroundTransparency = 0.35,
					BorderSizePixel = 0,
					LayoutOrder = 2,
				}, {
					Row = e(Layout.Stack, {
						direction = "row",
						gap = Theme.spacing.sm,
						alignY = Enum.VerticalAlignment.Center,
						padding = Theme.spacing.sm,
						size = UDim2.fromScale(0, 1),
						autoSize = Enum.AutomaticSize.X,
						children = cards,
					}),
				}),
			},
		}),
		Actions = ui.pieceActions and e(PieceActions, { uid = ui.pieceActions, layout = layout, pooled = pooled }),
	})
end

return Build
