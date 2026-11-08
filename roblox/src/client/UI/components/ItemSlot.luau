--!strict
--[[
	ItemSlot: one inventory cell. Shows the icon (or the item name until icons
	exist), a rarity-colored border, the stack count and a durability bar.
	An empty slot is a quiet frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require("../theme")

export type Props = {
	name: string?, -- nil for an empty slot
	icon: string?,
	count: number?,
	rarity: Types.Rarity?,
	durability: number?, -- 0..1 of max; nil hides the bar
	selected: boolean?,
	onActivated: (() -> ())?,
	layoutOrder: number?,
}

local function ItemSlot(props: Props)
	local empty = props.name == nil
	local borderColor = if props.selected
		then Theme.colors.accent
		elseif props.rarity then Theme.rarity[props.rarity]
		else Theme.colors.strokeWarm
	local hasIcon = props.icon ~= nil and props.icon ~= ""

	return React.createElement("TextButton", {
		Size = UDim2.fromOffset(Theme.slotSize, Theme.slotSize),
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.colors.panelRaised,
		BackgroundTransparency = if empty then 0.4 else 0,
		[React.Event.Activated] = props.onActivated,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = Theme.radius }),
		Stroke = React.createElement("UIStroke", {
			Color = borderColor,
			Thickness = Theme.strokeThickness,
			Transparency = if empty then 0.5 else 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Icon = not empty and hasIcon and React.createElement("ImageLabel", {
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.icon,
			ScaleType = Enum.ScaleType.Fit,
		}),
		Label = not empty and not hasIcon and React.createElement("TextLabel", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.body,
			Text = props.name,
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.textMuted,
			TextWrapped = true,
		}),
		Count = not empty and (props.count or 0) > 1 and React.createElement("TextLabel", {
			Size = UDim2.new(1, -6, 0, Theme.textSize.caption),
			Position = UDim2.new(0, 0, 1, -Theme.textSize.caption - 4),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = tostring(props.count),
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.text,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Durability = not empty and props.durability ~= nil and React.createElement("Frame", {
			Size = UDim2.new(math.clamp(props.durability, 0, 1), -8, 0, 3),
			Position = UDim2.new(0, 4, 1, -6),
			BackgroundColor3 = Theme.colors.durability,
			BorderSizePixel = 0,
		}),
	})
end

return ItemSlot
