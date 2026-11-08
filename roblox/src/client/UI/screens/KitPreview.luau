--!strict
-- KitPreview: a Studio-only gallery of the UI kit, used to check it against ART_DIRECTION.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require("../theme")
local Panel = require("../components/Panel")
local Button = require("../components/Button")
local ItemSlot = require("../components/ItemSlot")
local ProgressBar = require("../components/ProgressBar")

local RARITIES: { Types.Rarity } = { "common", "uncommon", "rare", "epic", "legendary" }

local function row(order: number, children: { [string]: any })
	local content = table.clone(children)
	content.Layout = React.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, Theme.spacing.sm),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, Theme.slotSize),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, content)
end

local function KitPreview()
	local hatchet = Items["item.hatchet"]
	local wood = Items["item.wood"]

	local slots: { [string]: any } = {}
	for index, rarity in RARITIES do
		slots[rarity] = React.createElement(ItemSlot, {
			name = wood.name,
			count = index * 7,
			rarity = rarity,
			layoutOrder = index,
		})
	end
	slots.Tool = React.createElement(ItemSlot, {
		name = hatchet.name,
		rarity = hatchet.rarity,
		durability = 0.6,
		selected = true,
		layoutOrder = 10,
	})
	slots.Empty = React.createElement(ItemSlot, { layoutOrder = 11 })

	return React.createElement(Panel, {
		title = "UI Kit",
		size = UDim2.fromOffset(560, 340),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	}, {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, Theme.spacing.md),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Buttons = row(1, {
			Primary = React.createElement(Button, { text = "Craft", layoutOrder = 1 }),
			Secondary = React.createElement(Button, { text = "Cancel", variant = "secondary", layoutOrder = 2 }),
			Disabled = React.createElement(Button, { text = "Locked", disabled = true, layoutOrder = 3 }),
		}),
		Slots = row(2, slots),
		Progress = React.createElement(ProgressBar, {
			progress = 0.65,
			label = "Planks 0:42",
			size = UDim2.new(1, 0, 0, 24),
			layoutOrder = 3,
		}),
		Danger = React.createElement(ProgressBar, {
			progress = 0.3,
			color = Theme.colors.threat,
			label = "Fog exposure",
			size = UDim2.new(1, 0, 0, 24),
			layoutOrder = 4,
		}),
	})
end

return KitPreview
