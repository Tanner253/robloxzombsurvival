--!strict
--[[
	StatBar: a HUD meter with a glyph, an eased fill, a trailing "damage" fill
	that catches up slowly, and an optional value label. Pulses when low.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")
local hooks = require("../hooks")

export type Props = {
	value: number,
	max: number,
	color: Color3,
	glyph: string?,
	label: string?,
	lowAt: number?, -- fraction that counts as low (pulses)
	size: UDim2?,
	layoutOrder: number?,
}

local function StatBar(props: Props)
	local fraction = if props.max > 0 then math.clamp(props.value / props.max, 0, 1) else 0
	local fill = hooks.useAnimated(fraction, 10)
	local trail = hooks.useAnimated(fraction, 2.5)
	local low = props.lowAt ~= nil and fraction <= props.lowAt
	local glyphSize = if props.glyph then 22 else 0

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromOffset(220, 18),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Glyph = props.glyph and React.createElement("TextLabel", {
			Size = UDim2.fromOffset(glyphSize, glyphSize),
			Position = UDim2.fromScale(0, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = props.glyph,
			TextScaled = true,
			TextColor3 = props.color,
		}),
		Track = React.createElement("Frame", {
			Size = UDim2.new(1, -glyphSize - 4, 1, 0),
			Position = UDim2.fromOffset(glyphSize + 4, 0),
			BackgroundColor3 = Theme.colors.track,
			ClipsDescendants = true,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = React.createElement("UIStroke", {
				Color = if low then props.color else Theme.colors.shadow,
				Thickness = if low then 2 else 1.5,
				Transparency = if low then 0.1 else 0.3,
			}),
			Trail = React.createElement("Frame", {
				Size = trail:map(function(v: number)
					return UDim2.fromScale(math.max(v, fraction), 1)
				end),
				BackgroundColor3 = Theme.colors.highlight,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			Fill = React.createElement("Frame", {
				Size = fill:map(function(v: number)
					return UDim2.fromScale(v, 1)
				end),
				BackgroundColor3 = props.color,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Sheen = React.createElement("UIGradient", {
					Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 190, 180)),
					Rotation = 90,
				}),
			}),
			Label = props.label and React.createElement("TextLabel", {
				Size = UDim2.new(1, -10, 1, 0),
				Position = UDim2.fromOffset(6, 0),
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = props.label,
				TextSize = Theme.textSize.caption - 1,
				TextColor3 = Theme.colors.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
			}, {
				Stroke = React.createElement("UIStroke", { Color = Theme.colors.shadow, Thickness = 1.2 }),
			}),
		}),
	})
end

return StatBar
