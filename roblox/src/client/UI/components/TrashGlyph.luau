--!strict
--[[
	TrashGlyph: a waste bin drawn from frames (no image asset), centred in its
	parent. Used on the inventory's destroy button (checklist 4.11).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

export type Props = {
	color: Color3,
	size: number?, -- body width in pixels
}

local function TrashGlyph(props: Props)
	local w = props.size or 16
	local h = math.floor(w * 1.15)
	local e = React.createElement
	local slots: { [string]: any } = {}
	for index = 1, 3 do
		slots[`Slot{index}`] = e("Frame", {
			Size = UDim2.fromOffset(2, h - 6),
			Position = UDim2.fromScale(index / 4, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
		})
	end
	slots.Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) })
	return e("Frame", {
		Size = UDim2.fromOffset(w + 6, h + 6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, {
		Lid = e("Frame", {
			Size = UDim2.fromOffset(w + 6, 3),
			Position = UDim2.fromOffset(0, 1),
			BackgroundColor3 = props.color,
			BorderSizePixel = 0,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		Handle = e("Frame", {
			Size = UDim2.fromOffset(math.floor(w / 2.5), 3),
			Position = UDim2.fromScale(0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = props.color,
			BorderSizePixel = 0,
		}),
		Body = e("Frame", {
			Size = UDim2.fromOffset(w, h),
			Position = UDim2.fromScale(0.5, 1),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = props.color,
			BorderSizePixel = 0,
		}, slots),
	})
end

return TrashGlyph
