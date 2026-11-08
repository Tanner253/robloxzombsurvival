--!strict
--[[
	InventoryPane: the left half of LDoE's two-pane screen (LDOE_PARITY #13, rec2_04):
	- header: the backpack glyph, "INVENTORY", and the premium balance (its "+" opens the
	  shop once the shop ships, S3);
	- pockets 2 x 5 and the backpack 5 wide, each with its rotated side label;
	- the action bar: the main action, SPLIT, sort and trash.

	The main action follows what the right pane is: PUT IN or ADD FUEL at a station, MOVE
	to an open crate, else USE / EQUIP. Click selects a slot; right click (or the button)
	acts; drag a slot anywhere (Panels' drag layer).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Theme = require("../../theme")
local Glyph = require("../../components/Glyph")
local Layout = require("../../components/Layout")
local Parts = require("./Parts")

local e = React.createElement

export type Action = { text: string, enabled: boolean, run: () -> () }

export type Props = {
	inventory: any,
	selected: { ref: string, index: number }?,
	newItems: { [string]: boolean }?,
	balance: number,
	shopOpen: boolean, -- the "+" shows only once the shop ships
	main: Action, -- the context's main action for the selected slot
	onSelect: (ref: string, index: number) -> (),
	onSecondary: (ref: string, index: number) -> (),
	onSplit: () -> (),
	onSort: () -> (),
	onTrash: () -> (),
}

local function InventoryPane(props: Props)
	local pockets = props.inventory.pockets or {}
	local backpack = props.inventory.backpack or {}
	local selected = props.selected
	local slot = if selected
		then (if selected.ref == "pockets" then pockets[selected.index] else backpack[selected.index])
		else nil
	local hasSlot = slot ~= nil and slot.count > 0
	local splittable = hasSlot and slot.count > 1
	local def = if hasSlot then Content.Items[slot.itemId] else nil

	local header = e(Parts.Header, {
		glyph = "backpack",
		title = "Inventory",
		right = {
			Balance = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.xs,
				alignY = Enum.VerticalAlignment.Center,
				size = UDim2.fromOffset(0, 44),
				autoSize = Enum.AutomaticSize.X,
				children = {
					Coin = e(Glyph, { name = "coin", size = UDim2.fromOffset(28, 28), layoutOrder = 1 }),
					Amount = e("TextLabel", {
						Size = UDim2.fromOffset(0, 28),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						FontFace = Theme.fonts.header,
						Text = tostring(props.balance),
						TextSize = Theme.textSize.body,
						TextColor3 = Theme.colors.text,
						LayoutOrder = 2,
					}),
					Plus = props.shopOpen and e(Parts.BarButton, {
						glyph = "plus",
						tone = "teal",
						layoutOrder = 3,
					}),
				},
			}),
		},
	})

	local body = e(Layout.Stack, {
		gap = Theme.spacing.md,
		children = {
			Pockets = e(Parts.Section, {
				label = "POCKETS",
				height = Parts.slotsHeight(#pockets),
				layoutOrder = 1,
				children = {
					Grid = e(Parts.Slots, {
						ref = "pockets",
						slots = pockets,
						selected = selected,
						newItems = props.newItems,
						onSlot = function(index: number)
							props.onSelect("pockets", index)
						end,
						onSecondary = function(index: number)
							props.onSecondary("pockets", index)
						end,
					}),
				},
			}),
			Rule = e("Frame", {
				Size = UDim2.new(1, 0, 0, 2),
				BackgroundColor3 = Theme.colors.strokeWarm,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				LayoutOrder = 2,
			}),
			Backpack = if #backpack > 0
				then e(Parts.Section, {
					label = "BACKPACK",
					height = Parts.slotsHeight(#backpack),
					layoutOrder = 3,
					children = {
						Grid = e(Parts.Slots, {
							ref = "backpack",
							slots = backpack,
							selected = selected,
							newItems = props.newItems,
							onSlot = function(index: number)
								props.onSelect("backpack", index)
							end,
							onSecondary = function(index: number)
								props.onSecondary("backpack", index)
							end,
						}),
					},
				})
				else e(Parts.Line, {
					text = "Equip a bag for backpack slots (+5, +10 or +15).",
					layoutOrder = 3,
				}),
			Selected = e(Parts.Line, {
				text = if def then def.name .. (if def.description then `: {def.description}` else "") else " ",
				tone = Theme.colors.text,
				layoutOrder = 4,
			}),
		},
	})

	local bar = e(Parts.Bar, {
		children = {
			Main = e(Parts.BarButton, {
				text = props.main.text,
				width = 132,
				disabled = not (hasSlot and props.main.enabled),
				layoutOrder = 1,
				onActivated = props.main.run,
			}),
			Split = e(Parts.BarButton, {
				text = "Split",
				width = 120,
				disabled = not splittable,
				layoutOrder = 2,
				onActivated = props.onSplit,
			}),
			Sort = e(Parts.BarButton, { glyph = "sort", tone = "teal", layoutOrder = 3, onActivated = props.onSort }),
			Trash = e(Parts.BarButton, {
				glyph = "trash",
				disabled = not hasSlot,
				layoutOrder = 4,
				onActivated = props.onTrash,
			}),
		},
	})

	return e(Parts.Pane, { header = header, body = body, bar = bar })
end

return InventoryPane
