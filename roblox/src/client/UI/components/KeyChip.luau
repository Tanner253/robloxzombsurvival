--!strict
-- KeyChip: a small keycap showing the PC keybind for an action ("E", "Tab", "LMB").
-- Hidden on touch-only devices, where buttons are the only input.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local State = require("../../State")
local Theme = require("../theme")

export type Props = {
	text: string, -- the key's name (not `key`, which React reserves)
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	accent: boolean?,
}

local function KeyChip(props: Props)
	if State.ui().touch then
		return nil
	end
	local height = Theme.textSize.caption + 8
	return React.createElement("TextLabel", {
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex or 5,
		BackgroundColor3 = if props.accent then Theme.colors.accent else Theme.colors.track,
		BackgroundTransparency = 0.05,
		FontFace = Theme.fonts.header,
		Text = props.text,
		TextSize = Theme.textSize.caption,
		TextColor3 = if props.accent then Theme.colors.textOnAccent else Theme.colors.highlight,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Stroke = React.createElement("UIStroke", {
			Color = Theme.colors.strokeWarm,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		Size = React.createElement("UISizeConstraint", { MinSize = Vector2.new(height, height) }),
	})
end

return KeyChip
