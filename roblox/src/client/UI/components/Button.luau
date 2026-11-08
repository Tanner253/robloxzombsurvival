--!strict
--[[
	Button: the standard tap target. "primary" uses the ember accent, "secondary"
	the warm stroke. Never shorter than the 44 px tap target; shrinks slightly
	while pressed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")
local Glyph = require("./Glyph")
local Sfx = require("../../Sfx")

export type Variant = "primary" | "secondary"

export type Props = {
	text: string,
	glyph: string?, -- an icon from the glyph set instead of the text (4.17)
	onActivated: (() -> ())?,
	variant: Variant?,
	disabled: boolean?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
}

local PRESSED_SCALE = 0.95

local function Button(props: Props)
	local pressed, setPressed = React.useState(false)
	local primary = (props.variant or "primary") == "primary"
	local disabled = props.disabled == true

	local size = props.size or UDim2.fromOffset(160, Theme.tapTarget)
	if size.Y.Offset < Theme.tapTarget and size.Y.Scale == 0 then
		size = UDim2.new(size.X, UDim.new(0, Theme.tapTarget))
	end

	return React.createElement("TextButton", {
		Size = size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = false,
		Active = not disabled,
		BackgroundColor3 = if disabled
			then Theme.colors.disabled
			elseif primary then Theme.colors.accent
			else Theme.colors.panelRaised,
		BackgroundTransparency = 0,
		FontFace = Theme.fonts.header,
		Text = if props.glyph then "" else props.text,
		TextSize = Theme.textSize.body,
		TextColor3 = if disabled
			then Theme.colors.disabledText
			elseif primary then Theme.colors.textOnAccent
			else Theme.colors.text,
		[React.Event.Activated] = function()
			if disabled then
				Sfx.play("uiError")
			elseif props.onActivated then
				Sfx.play("uiClick")
				props.onActivated()
			end
		end,
		[React.Event.MouseEnter] = function()
			if not disabled then
				Sfx.play("uiHover")
			end
		end,
		[React.Event.MouseButton1Down] = function()
			setPressed(not disabled)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
		[React.Event.MouseLeave] = function()
			setPressed(false)
		end,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = Theme.radius }),
		Stroke = React.createElement("UIStroke", {
			Color = if disabled
				then Theme.colors.disabledStroke
				elseif primary then Theme.colors.accentSoft
				else Theme.colors.strokeWarm,
			Thickness = Theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Scale = React.createElement("UIScale", {
			Scale = if pressed then PRESSED_SCALE else 1,
		}),
		Glyph = props.glyph and React.createElement(Glyph, {
			name = props.glyph,
			size = UDim2.fromScale(0.55, 0.55),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			color = if disabled
				then Theme.colors.disabledText
				elseif primary then Theme.colors.textOnAccent
				else Theme.colors.text,
		}),
	})
end

return Button
