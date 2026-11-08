--!strict
--[[
	Glyph: one icon from the UI glyph set (Art.glyphs, checklist 4.17), tinted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Art = require(ReplicatedStorage.Shared.Art)

export type Props = {
	name: string,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	color: Color3?,
	transparency: number?,
	rotation: number?,
	zIndex: number?,
	layoutOrder: number?,
}

local function Glyph(props: Props)
	return React.createElement("ImageLabel", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		Image = Art.glyphs[props.name] or "",
		ImageColor3 = props.color or Color3.new(1, 1, 1),
		ImageTransparency = props.transparency or 0,
		ScaleType = Enum.ScaleType.Fit,
		Rotation = props.rotation or 0,
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
	})
end

return Glyph
