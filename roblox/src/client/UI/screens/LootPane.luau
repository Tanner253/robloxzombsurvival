--!strict
--[[
	LootPane: the inventory's right pane while a Fog Run container, loot pile or death
	bag is open (LDOE_PARITY #45: containers reuse the two-pane storage screen;
	checklist 12.4, 12.6). Click a slot to take it; Take all (F) takes everything that
	fits. A bag shows its gear row (Black fog drops gear too) above the backpack.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Actions = require("../../Actions")
local Net = require("../../Net")
local Theme = require("../theme")
local hooks = require("../hooks")
local Button = require("../components/Button")
local ItemSlot = require("../components/ItemSlot")
local KeyChip = require("../components/KeyChip")
local Label = require("../components/Label")

local e = React.createElement

local SLOT = 60
local GAP = 6

local KIND_TITLES: { [string]: string } = {
	container = "CONTAINER",
	bag = "SURVIVOR'S BAG",
}

local function grid(slots: { any }, onTake: (number) -> (), order: number): any
	local children: { [string]: any } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(SLOT, SLOT),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local shown = 0
	for index, slot in slots do
		if type(slot) == "table" and slot.itemId and (slot.count or 0) > 0 then
			shown += 1
			children[`S{index}`] = e(ItemSlot, {
				itemId = slot.itemId,
				count = slot.count,
				size = SLOT,
				layoutOrder = index,
				onActivated = function()
					onTake(index)
				end,
			})
		end
	end
	local rows = math.max(1, math.ceil(shown / 5))
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, rows * (SLOT + GAP)),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, children)
end

local function LootPane(props: { loot: any })
	local run = hooks.useSection("run")
	local loot = props.loot
	local items: { any } = {}
	local gear: { any } = {}
	local title = KIND_TITLES[loot.kind] or "CONTAINER"
	if loot.kind == "bag" then
		for _, drop in (if type(run) == "table" then run.drops or {} else {}) do
			if drop.id == loot.id then
				items = drop.backpack or {}
				gear = drop.equipment or {}
				title = if drop.mine then "YOUR BAG" else "SURVIVOR'S BAG"
			end
		end
	else
		items = loot.items or {}
	end
	local empty = #items == 0 and #gear == 0
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Title = e(Label, {
			text = title,
			style = "section",
			tone = "accent",
			size = UDim2.new(1, 0, 0, 24),
		}),
		Scroll = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -90),
			Position = UDim2.fromOffset(0, 32),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Theme.colors.strokeWarm,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, {
			Layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			GearTitle = #gear > 0 and e(
				Label,
				{ text = "Gear", style = "caption", tone = "muted", size = UDim2.new(1, 0, 0, 18), layoutOrder = 1 }
			),
			Gear = #gear > 0 and grid(gear, function(index: number)
				Net.fire("BagTake", loot.id, "equipment", index)
			end, 2),
			Items = not empty and grid(items, function(index: number)
				if loot.kind == "bag" then
					Net.fire("BagTake", loot.id, "backpack", index)
				else
					Actions.takeLoot(index)
				end
			end, 3),
			Empty = empty and e(Label, {
				text = "Nothing left.",
				style = "body",
				tone = "muted",
				size = UDim2.new(1, 0, 0, 24),
				layoutOrder = 4,
			}),
		}),
		TakeAll = e(Button, {
			text = "Take all",
			disabled = empty,
			size = UDim2.new(1, 0, 0, 44),
			position = UDim2.new(0, 0, 1, -44),
			onActivated = function()
				Actions.takeLoot(nil)
			end,
		}),
		TakeKey = e(KeyChip, { text = "F", position = UDim2.new(1, -2, 1, -50), anchorPoint = Vector2.new(1, 0) }),
	})
end

return LootPane
