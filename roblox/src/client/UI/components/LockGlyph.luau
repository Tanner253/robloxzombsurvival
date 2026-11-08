--!strict
--[[
	LockGlyph: the glyph set's padlock (4.17), laid over the icon of anything that is
	locked: recipes, build pieces (checklist 5.1, 5.9).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")
local Glyph = require("./Glyph")

export type Props = {
	size: number?, -- width in pixels
	position: UDim2?,
	anchorPoint: Vector2?,
	color: Color3?,
	zIndex: number?,
}

local function LockGlyph(props: Props)
	local w = props.size or 18
	return React.createElement(Glyph, {
		name = "lock",
		size = UDim2.fromOffset(w, w),
		position = props.position,
		anchorPoint = props.anchorPoint,
		color = props.color or Theme.colors.text,
		zIndex = props.zIndex,
	})
end

return LockGlyph
