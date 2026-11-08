--!strict
--[[
	Panel: the standard container. Charcoal at 92% opacity, 8 px corners, 2 px warm
	stroke and a soft drop shadow, with an optional header title.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")

export type Props = {
	title: string?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	children: { [string]: any }?,
}

local function Panel(props: Props)
	local padding = UDim.new(0, Theme.spacing.lg)
	local headerHeight = if props.title then Theme.textSize.title + Theme.spacing.md else 0

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromOffset(320, 200),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
	}, {
		Shadow = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, Theme.shadowOffset),
			BackgroundColor3 = Theme.colors.shadow,
			BackgroundTransparency = Theme.colors.shadowTransparency,
			ZIndex = 0,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.radius }),
		}),
		Body = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = Theme.colors.panelTransparency,
			ZIndex = 1,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.radius }),
			Stroke = React.createElement("UIStroke", {
				Color = Theme.colors.strokeWarm,
				Thickness = Theme.strokeThickness,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingTop = padding,
				PaddingBottom = padding,
				PaddingLeft = padding,
				PaddingRight = padding,
			}),
			Title = props.title and React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, Theme.textSize.title),
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = props.title,
				TextSize = Theme.textSize.title,
				TextColor3 = Theme.colors.text,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Content = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 1, -headerHeight),
				Position = UDim2.fromOffset(0, headerHeight),
				BackgroundTransparency = 1,
			}, props.children),
		}),
	})
end

return Panel
