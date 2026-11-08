--!strict
--[[
	Parts: the pieces every pane of LDoE's two-pane screen is built from (LDOE_PARITY #13,
	#16, #18), so the inventory, storage, station, inbox and parts-checklist panes read as
	one screen:
	- Pane: a column of header, body and action bar (UIListLayout, the body flexes);
	- Header: glyph, title (or a teal name chip), and controls on the right;
	- Section: a vertical side label (LDoE's rotated "POCKETS") beside its content;
	- Slots: a grid of ItemSlots, 5 wide;
	- BarButton: the flat action-bar buttons (USE, SPLIT, TAKE ALL...) and square icon
	  buttons (sort, trash, brush, upgrade).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Theme = require("../../theme")
local Glyph = require("../../components/Glyph")
local ItemSlot = require("../../components/ItemSlot")
local Layout = require("../../components/Layout")
local Sfx = require("../../../Sfx")

local e = React.createElement

local Parts = {}

local P = Theme.panel

-- A pane: header row, flexible body, action bar.
function Parts.Pane(props: { header: any, body: any, bar: any? })
	return e(Layout.Stack, {
		gap = Theme.spacing.sm,
		children = {
			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, P.header),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}, { Content = props.header }),
			Body = e(Layout.Fill, { layoutOrder = 2, children = { Content = props.body } }),
			Bar = props.bar and e("Frame", {
				Size = UDim2.new(1, 0, 0, P.actionBar),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
			}, { Content = props.bar }),
		},
	})
end

-- The header: an icon, the title (plain or on a teal chip) and controls at the right.
-- Header titles longer than this many characters use the smaller section size.
local LONG_TITLE = 18

function Parts.Header(props: { glyph: string, title: string, chip: boolean?, right: { [string]: any }? })
	local children: { [string]: any } = {
		Icon = e(Glyph, {
			name = props.glyph,
			size = UDim2.fromOffset(32, 32),
			color = Theme.colors.text,
			layoutOrder = 1,
		}),
		Title = e(Layout.Fill, {
			direction = "row",
			layoutOrder = 2,
			children = {
				Label = e("TextLabel", {
					Size = UDim2.new(if props.chip then 0 else 1, 0, 1, if props.chip then -8 else 0),
					AutomaticSize = if props.chip then Enum.AutomaticSize.X else nil,
					Position = UDim2.fromScale(0, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Theme.colors.chip,
					BackgroundTransparency = if props.chip then 0 else 1,
					FontFace = Theme.fonts.header,
					Text = string.upper(props.title),
					-- A long name ("WOODWORKING BENCH LVL 1") steps down a size to fit the chip.
					TextSize = if props.chip and #props.title > LONG_TITLE
						then Theme.textSize.section
						else Theme.textSize.title,
					TextColor3 = Theme.colors.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}, {
					Corner = props.chip and e("UICorner", { CornerRadius = UDim.new(0, 4) }),
					Padding = props.chip and Layout.pad(0, { left = 10, right = 10 }),
					Max = props.chip and e("UISizeConstraint", { MaxSize = Vector2.new(P.pane - 150, 60) }),
				}),
			},
		}),
	}
	local order = 3
	local right: { [string]: any } = props.right or {}
	for name, child in right do
		children[name] = e("Frame", {
			Size = UDim2.fromOffset(0, P.header),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = order,
		}, { Content = child })
		order += 1
	end
	return e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.sm,
		alignY = Enum.VerticalAlignment.Center,
		children = children,
	})
end

-- A section with LDoE's rotated side label ("POCKETS", "BACKPACK").
function Parts.Section(props: { label: string, height: number, layoutOrder: number, children: any })
	return e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.xs,
		size = UDim2.new(1, 0, 0, props.height),
		layoutOrder = props.layoutOrder,
		children = {
			Side = e("Frame", {
				Size = UDim2.new(0, 20, 1, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}, {
				Label = e("TextLabel", {
					-- Turned a quarter: its unrotated box runs along the section's height.
					Size = UDim2.fromOffset(props.height, 20),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = -90,
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.header,
					Text = props.label,
					TextSize = Theme.textSize.caption,
					TextColor3 = Theme.colors.textMuted,
				}),
			}),
			Content = e(Layout.Fill, { direction = "row", layoutOrder = 2, children = props.children }),
		},
	})
end

export type SlotsProps = {
	-- Where the slots live: "pockets", "backpack", "storage", "stationOutput"... (not `ref`,
	-- which React reserves: a string there crashed the whole Panels screen).
	place: string,
	slots: { any },
	selected: { ref: string, index: number }?,
	newItems: { [string]: boolean }?,
	onSlot: ((index: number) -> ())?,
	onSecondary: ((index: number) -> ())?,
	layoutOrder: number?,
}

-- Slots in a 5-wide grid.
function Parts.Slots(props: SlotsProps)
	local cells: { [string]: any } = {}
	for index, slot in props.slots do
		local def = if slot.count > 0 then Content.Items[slot.itemId] else nil
		local durability = if def and def.durability and slot.durability then slot.durability / def.durability else nil
		cells[`S{index}`] = e(ItemSlot, {
			itemId = slot.itemId,
			count = slot.count,
			durability = durability,
			size = P.slot,
			selected = props.selected ~= nil and props.selected.ref == props.place and props.selected.index == index,
			isNew = props.newItems ~= nil and slot.count > 0 and props.newItems[slot.itemId] == true,
			slotRef = props.place,
			slotIndex = index,
			layoutOrder = index,
			onActivated = props.onSlot and function()
				(props.onSlot :: (number) -> ())(index)
			end,
			onSecondary = props.onSecondary and function()
				(props.onSecondary :: (number) -> ())(index)
			end,
		})
	end
	return e(Layout.Grid, {
		cell = Vector2.new(P.slot, P.slot),
		gap = P.slotGap,
		columns = P.columns,
		layoutOrder = props.layoutOrder,
		children = cells,
	})
end

-- The pixel height of `count` slots in the 5-wide grid.
function Parts.slotsHeight(count: number): number
	return Layout.gridSize(math.max(count, 1), P.columns, Vector2.new(P.slot, P.slot), P.slotGap).Y
end

export type BarButtonProps = {
	text: string?,
	glyph: string?,
	width: number?,
	tone: ("plain" | "teal" | "green" | "danger")?,
	disabled: boolean?,
	layoutOrder: number?,
	onActivated: (() -> ())?,
}

-- LDoE's flat action-bar buttons: grey outlined (USE, SPLIT), teal (TAKE ALL, sort) and
-- green (upgrade). With only a glyph it is square.
function Parts.BarButton(props: BarButtonProps)
	local tone = props.tone or "plain"
	local disabled = props.disabled == true
	local fill = if disabled
		then Theme.colors.disabled
		elseif tone == "teal" then Theme.colors.chip
		elseif tone == "green" then Theme.colors.upgrade
		elseif tone == "danger" then Theme.colors.danger
		else Theme.colors.panelRaised
	local width = props.width or (if props.text then 120 else Theme.tapTarget)
	return e("TextButton", {
		Size = UDim2.fromOffset(width, Theme.tapTarget),
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = not disabled,
		BackgroundColor3 = fill,
		FontFace = Theme.fonts.header,
		Text = if props.glyph then "" else string.upper(props.text or ""),
		TextSize = Theme.textSize.body,
		TextColor3 = if disabled then Theme.colors.disabledText else Theme.colors.text,
		[React.Event.Activated] = function()
			if disabled then
				Sfx.play("uiError")
			elseif props.onActivated then
				Sfx.play("uiClick")
				props.onActivated()
			end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Stroke = e("UIStroke", {
			Color = if tone == "plain" then Theme.colors.strokeWarm else fill:Lerp(Color3.new(1, 1, 1), 0.2),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Icon = props.glyph and e(Glyph, {
			name = props.glyph,
			size = UDim2.fromScale(0.6, 0.6),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			color = if disabled then Theme.colors.disabledText else Theme.colors.text,
		}),
	})
end

-- A row of bar buttons, left to right.
function Parts.Bar(props: { children: { [string]: any }, alignX: Enum.HorizontalAlignment? })
	return e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.sm,
		alignX = props.alignX or Enum.HorizontalAlignment.Left,
		alignY = Enum.VerticalAlignment.Center,
		children = props.children,
	})
end

-- A plain line of text that fills its row (status lines, hints).
-- One line of text, truncated; `wrap` lets a longer text (a description) run onto more lines.
function Parts.Line(props: {
	text: string,
	tone: Color3?,
	size: number?,
	layoutOrder: number?,
	center: boolean?,
	wrap: boolean?,
})
	local textSize = props.size or Theme.textSize.body
	return e("TextLabel", {
		Size = UDim2.new(1, 0, 0, if props.wrap then 0 else textSize + 6),
		AutomaticSize = if props.wrap then Enum.AutomaticSize.Y else nil,
		TextWrapped = props.wrap == true,
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		Text = props.text,
		TextSize = textSize,
		TextColor3 = props.tone or Theme.colors.textMuted,
		TextXAlignment = if props.center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		TextTruncate = if props.wrap then nil else Enum.TextTruncate.AtEnd,
		LayoutOrder = props.layoutOrder,
	})
end

return Parts
