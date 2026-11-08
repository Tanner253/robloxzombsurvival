--!strict
--[[
	CostChip: one cost as LDoE draws it (LDOE_PARITY #16, #27, #28): the item's icon and
	"have/need", red when short. Used by upgrade modals, build costs and the parts list.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")
local ItemIcon = require("./ItemIcon")
local Layout = require("./Layout")

local e = React.createElement

export type Props = {
	itemId: string,
	have: number,
	need: number,
	size: number?, -- icon size
	layoutOrder: number?,
}

local function CostChip(props: Props)
	local size = props.size or 32
	local short = props.have < props.need
	return e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.xs,
		alignY = Enum.VerticalAlignment.Center,
		size = UDim2.fromOffset(0, size),
		autoSize = Enum.AutomaticSize.X,
		layoutOrder = props.layoutOrder,
		children = {
			Icon = e("Frame", {
				Size = UDim2.fromOffset(size, size),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}, { Icon = e(ItemIcon, { itemId = props.itemId }) }),
			Count = e("TextLabel", {
				Size = UDim2.fromOffset(0, size),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = `{props.have}/{props.need}`,
				TextSize = Theme.textSize.body,
				TextColor3 = if short then Theme.colors.locked else Theme.colors.text,
				LayoutOrder = 2,
			}),
		},
	})
end

return CostChip
