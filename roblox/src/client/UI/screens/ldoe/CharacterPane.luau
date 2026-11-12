--!strict
--[[
	CharacterPane: the right pane when the inventory opens alone (LDOE_PARITY #13-14,
	Domain/RightPane): the survivor's 3D model (components/SurvivorView) between the gear
	slots (head, body, legs and feet down the left; backpack, Weapon 1, Weapon 2 and the
	Quick slot down the right), HP, food, water and armor along the foot, and the Inbox tab in
	the header. The weapon slots feed the HUD's weapon circles and the Quick slot its meds
	button.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Slots = require(ReplicatedStorage.Shared.Domain.Slots)
local Theme = require("../../theme")
local Glyph = require("../../components/Glyph")
local ItemSlot = require("../../components/ItemSlot")
local Layout = require("../../components/Layout")
local SurvivorView = require("../../components/SurvivorView")
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
	inboxCount: number?,
	onInbox: (() -> ())?,
	onSelect: (ref: string, index: number) -> (),
	onSecondary: (ref: string, index: number) -> (),
}

local function Stat(props: { glyph: string, value: string, tone: Color3, layoutOrder: number })
	return e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.sm,
		alignY = Enum.VerticalAlignment.Center,
		size = UDim2.fromOffset(26 + Theme.spacing.sm + 54, 32), -- four sit in a row along the foot
		layoutOrder = props.layoutOrder,
		children = {
			Icon = e(
				Glyph,
				{ name = props.glyph, size = UDim2.fromOffset(26, 26), color = props.tone, layoutOrder = 1 }
			),
			Value = e("TextLabel", {
				Size = UDim2.new(0, 54, 1, 0),
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
			layoutOrder = if column == 1 then 1 else 3, -- the survivor stands between (2)
			children = cells,
		})
	end

	-- The worn gear's signature: the model is copied again when it changes.
	local look = {}
	for _, name in Slots.EQUIP_ORDER do
		local slot = equipment[name]
		table.insert(look, if slot and slot.count > 0 then slot.itemId else "")
	end

	-- LDoE: armour slots down the left, the survivor in the middle, bag and weapons down the
	-- right, the values along the foot.
	columns.Model = e(Layout.Fill, {
		direction = "row",
		layoutOrder = 2,
		children = { View = e(SurvivorView, { look = table.concat(look, "|") }) },
	})

	local body = e(Layout.Stack, {
		gap = Theme.spacing.sm,
		children = {
			Gear = e(Layout.Fill, {
				layoutOrder = 1,
				children = {
					Row = e(Layout.Stack, {
						direction = "row",
						gap = Theme.spacing.sm,
						children = columns,
					}),
				},
			}),
			Stats = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.lg,
				alignX = Enum.HorizontalAlignment.Center,
				alignY = Enum.VerticalAlignment.Center,
				size = UDim2.new(1, 0, 0, 32),
				layoutOrder = 2,
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
	})

	-- The inbox is a tab of this pane (Domain/RightPane): it never replaces the survivor.
	local inboxCount = props.inboxCount or 0
	return e(Parts.Pane, {
		header = e(Parts.Header, {
			glyph = "friends",
			title = "Survivor",
			right = if props.onInbox
				then {
					Inbox = e(Parts.BarButton, {
						text = if inboxCount > 0 then `Inbox ({inboxCount})` else "Inbox",
						width = 130,
						tone = if inboxCount > 0 then "teal" else "plain",
						onActivated = props.onInbox,
					}),
				}
				else nil,
		}),
		body = body,
	})
end

return CharacterPane
