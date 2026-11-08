--!strict
--[[
	Label: every piece of text in the UI. Styles come from the theme only:
	`style` picks the font and size, `tone` the color token.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")

export type Style = "header" | "title" | "section" | "body" | "caption" | "number"
export type Tone =
	"text"
	| "muted"
	| "accent"
	| "highlight"
	| "threat"
	| "onAccent"
	| "good"
	| "warn"
	| "locked"
	| "bonus"

export type Props = {
	text: any, -- string or a binding
	style: Style?,
	tone: Tone?,
	color: Color3?, -- only for rarity colors, which come from Theme.rarity
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	alignX: Enum.TextXAlignment?,
	alignY: Enum.TextYAlignment?,
	wrap: boolean?,
	autoWidth: boolean?,
	layoutOrder: number?,
	zIndex: number?,
	transparency: any?,
	richText: boolean?,
	stroke: boolean?,
}

local TONES: { [string]: Color3 } = {
	text = Theme.colors.text,
	muted = Theme.colors.textMuted,
	accent = Theme.colors.accent,
	highlight = Theme.colors.highlight,
	threat = Theme.colors.threat,
	onAccent = Theme.colors.textOnAccent,
	good = Theme.colors.durability,
	warn = Theme.colors.accentSoft,
	locked = Theme.colors.locked,
	bonus = Theme.colors.bonus,
}

local function Label(props: Props)
	local style = props.style or "body"
	local font = if style == "header"
			or style == "title"
			or style == "section"
			or style == "number"
		then Theme.fonts.header
		else Theme.fonts.body
	local textSize = if style == "number" then Theme.textSize.body else (Theme.textSize :: any)[style]
	return React.createElement("TextLabel", {
		Size = props.size or UDim2.new(1, 0, 0, textSize + 4),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		AutomaticSize = if props.autoWidth then Enum.AutomaticSize.X else nil,
		BackgroundTransparency = 1,
		FontFace = font,
		Text = props.text,
		TextSize = textSize,
		TextColor3 = props.color or TONES[(props.tone or "text") :: string],
		TextTransparency = props.transparency,
		TextXAlignment = props.alignX or Enum.TextXAlignment.Left,
		TextYAlignment = props.alignY or Enum.TextYAlignment.Center,
		TextWrapped = props.wrap == true,
		TextTruncate = if props.wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		RichText = props.richText == true,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		Stroke = props.stroke and React.createElement("UIStroke", {
			Color = Theme.colors.shadow,
			Thickness = 1.5,
			Transparency = 0.35,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),
	})
end

return Label
