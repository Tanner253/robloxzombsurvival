--!strict
--[[
	CharacterPane: the right pane when the inventory opens alone (LDOE_PARITY #13-14): the
	survivor's gear slots (head, body, legs, feet, backpack, Weapon 1, Weapon 2 and the
	Quick slot) beside HP, food, water and armor values. The weapon slots feed the HUD's
	weapon circles and the Quick slot its meds button.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Slots = require(ReplicatedStorage.Shared.Domain.Slots)
local Theme = require("../../theme")
local Glyph = require("../../components/Glyph")
local ItemSlot = require("../../components/ItemSlot")
local Layout = require("../../components/Layout")
local Parts = require("./Parts")

local e = React.createElement

local CAPTIONS: { [string]: string } = {
	head = "Head",
	body = "Body",
	legs = "Legs",
	feet = "Feet",
	bag = "Backpack",
	weapon = "Weapon 1",
	weapon2 = "Weapon 2",
	quick = "Quick",
}

-- Two columns of four: armour on the left, bag, weapons and quick slot on the right.
local COLUMNS = { { "head", "body", "legs", "feet" }, { "bag", "weapon", "weapon2", "quick" } }

export type Props = {
	inventory: any,
	survival: any,
	selected: { ref: string, index: number }?,
	onSelect: (ref: string, index: number) -> (),
	onSecondary: (ref: string, index: number) -> (),
}

local function Stat(props: { glyph: string, value: string, tone: Color3, layoutOrder: number })
	return e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.sm,
		alignY = Enum.VerticalAlignment.Center,
		size = UDim2.new(1, 0, 0, 32),
		layoutOrder = props.layoutOrder,
		children = {
			Icon = e(
				Glyph,
				{ name = props.glyph, size = UDim2.fromOffset(28, 28), color = props.tone, layoutOrder = 1 }
			),
			Value = e("TextLabel", {
				Size = UDim2.new(0, 90, 1, 0),
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = props.value,
				TextSize = Theme.textSize.title,
				TextColor3 = Theme.colors.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}),
		},
	})
end

local function CharacterPane(props: Props)
	local equipment = props.inventory.equipment or {}
	local survival = props.survival
	local armor = 0
	for _, slot in equipment do
		local def = if slot.count > 0 then Content.Items[slot.itemId] else nil
		armor += if def and def.armor then def.armor.defense else 0
	end
	local hp = if survival then math.floor(survival.health) else 0
	local food = if survival then math.floor(survival.hunger) else 0
	local water = if survival then math.floor(survival.thirst) else 0

	local columns: { [string]: any } = {}
	for column, names in COLUMNS do
		local cells: { [string]: any } = {}
		for row, name in names do
			local index = table.find(Slots.EQUIP_ORDER, name :: any) :: number
			local slot = equipment[name] or { itemId = "", count = 0 }
			local def = if slot.count > 0 then Content.Items[slot.itemId] else nil
			cells[name] = e(Layout.Stack, {
				gap = 2,
				alignX = Enum.HorizontalAlignment.Center,
				size = UDim2.fromOffset(Theme.panel.slot + 16, Theme.panel.slot + 22),
				layoutOrder = row,
				children = {
					Slot = e(ItemSlot, {
						itemId = slot.itemId,
						count = slot.count,
						durability = if def
								and def.durability
								and slot.durability
							then slot.durability / def.durability
							else nil,
						size = Theme.panel.slot,
						placeholder = if name == "weapon2" then "weapon" elseif name == "quick" then nil else name,
						slotRef = "equipment",
						slotIndex = index,
						selected = props.selected ~= nil
							and props.selected.ref == "equipment"
							and props.selected.index == index,
						layoutOrder = 1,
						onActivated = function()
							props.onSelect("equipment", index)
						end,
						onSecondary = function()
							props.onSecondary("equipment", index)
						end,
					}),
					Caption = e("TextLabel", {
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						FontFace = Theme.fonts.body,
						Text = CAPTIONS[name],
						TextSize = Theme.textSize.caption,
						TextColor3 = Theme.colors.textMuted,
						LayoutOrder = 2,
					}),
				},
			})
		end
		columns[`C{column}`] = e(Layout.Stack, {
			gap = Theme.spacing.sm,
			size = UDim2.new(0, Theme.panel.slot + 16, 1, 0),
			layoutOrder = column,
			children = cells,
		})
	end

	local body = e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.lg,
		children = {
			Gear = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.md,
				size = UDim2.new(0, (Theme.panel.slot + 16) * 2 + Theme.spacing.md, 1, 0),
				layoutOrder = 1,
				children = columns,
			}),
			Stats = e(Layout.Fill, {
				direction = "row",
				layoutOrder = 2,
				children = {
					List = e(Layout.Stack, {
						gap = Theme.spacing.md,
						padding = Theme.spacing.sm,
						children = {
							Health = e(Stat, {
								glyph = "health",
								value = tostring(hp),
								tone = Theme.meters.health,
								layoutOrder = 1,
							}),
							Food = e(Stat, {
								glyph = "hunger",
								value = tostring(food),
								tone = Theme.meters.hunger,
								layoutOrder = 2,
							}),
							Water = e(Stat, {
								glyph = "thirst",
								value = tostring(water),
								tone = Theme.meters.thirst,
								layoutOrder = 3,
							}),
							Armor = e(Stat, {
								glyph = "defense",
								value = tostring(armor),
								tone = Theme.colors.text,
								layoutOrder = 4,
							}),
						},
					}),
				},
			}),
		},
	})

	return e(Parts.Pane, {
		header = e(Parts.Header, { glyph = "friends", title = "Survivor" }),
		body = body,
	})
end

return CharacterPane
