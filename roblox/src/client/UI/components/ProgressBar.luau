--!strict
-- ProgressBar: a rounded track with a fill from 0 to 1 and an optional label.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")

export type Props = {
	progress: number, -- 0..1, clamped
	color: Color3?, -- defaults to the ember accent
	label: string?,
	size: UDim2?,
	position: UDim2?,
	layoutOrder: number?,
}

local function ProgressBar(props: Props)
	local progress = math.clamp(props.progress, 0, 1)

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromOffset(240, 20),
		Position = props.position,
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = Theme.colors.track,
		ClipsDescendants = true,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = Theme.radius }),
		Stroke = React.createElement("UIStroke", {
			Color = Theme.colors.strokeWarm,
			Thickness = Theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Fill = React.createElement("Frame", {
			Size = UDim2.fromScale(progress, 1),
			BackgroundColor3 = props.color or Theme.colors.accent,
			Visible = progress > 0,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.radius }),
		}),
		Label = props.label and React.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.body,
			Text = props.label,
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.text,
			ZIndex = 2,
		}),
	})
end

return ProgressBar
