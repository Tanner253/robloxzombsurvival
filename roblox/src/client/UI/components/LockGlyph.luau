--!strict
--[[
	LockGlyph: a small padlock drawn from frames (no image asset), laid over the
	icon of anything that is locked: recipes, build pieces (checklist 5.1, 5.9).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")

export type Props = {
	size: number?, -- width in pixels; the glyph is drawn to that scale
	position: UDim2?,
	anchorPoint: Vector2?,
	color: Color3?,
	zIndex: number?,
}

local function LockGlyph(props: Props)
	local w = props.size or 18
	local color = props.color or Theme.colors.text
	local bodyH = math.floor(w * 0.72)
	local ring = math.floor(w * 0.66)
	local stroke = math.max(2, math.floor(w / 8))
	return React.createElement("Frame", {
		Size = UDim2.fromOffset(w, bodyH + math.floor(ring / 2)),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, {
		Shackle = React.createElement("Frame", {
			Size = UDim2.fromOffset(ring, ring),
			Position = UDim2.fromScale(0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			ZIndex = props.zIndex,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = React.createElement("UIStroke", { Color = color, Thickness = stroke }),
		}),
		Body = React.createElement("Frame", {
			Size = UDim2.fromOffset(w, bodyH),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = (props.zIndex or 1) + 1,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, math.max(2, math.floor(w / 6))) }),
			Hole = React.createElement("Frame", {
				Size = UDim2.fromOffset(math.max(2, math.floor(w / 6)), math.floor(bodyH * 0.45)),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.colors.panel,
				BorderSizePixel = 0,
				ZIndex = (props.zIndex or 1) + 2,
			}),
		}),
	})
end

return LockGlyph
