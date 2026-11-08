--!strict
--[[
	TrashGlyph: the glyph set's bin (4.17), centred in its parent. Used on the
	inventory's destroy button (checklist 4.11).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Glyph = require("./Glyph")

export type Props = {
	color: Color3,
	size: number?, -- width in pixels
}

local function TrashGlyph(props: Props)
	local w = props.size or 20
	return React.createElement(Glyph, {
		name = "trash",
		size = UDim2.fromOffset(w, w),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		color = props.color,
	})
end

return TrashGlyph
