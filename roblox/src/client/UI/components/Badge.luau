--!strict
--[[
	Badge: LDoE's corner badges (LDOE_PARITY #4, #23): a teal count ("8") or a red NEW.
	It sits on its host's top-right corner and is declared an overlay for the UI gate
	(checklist 4.19): covering the host's corner is the point.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")
local mark = require("../mark")

export type Props = {
	count: number?, -- shown when > 0
	new: boolean?, -- a red NEW instead of a count
	zIndex: number?,
}

local function Badge(props: Props)
	local count = props.count or 0
	if not props.new and count <= 0 then
		return nil
	end
	local text = if props.new then "NEW" else (if count > 99 then "99+" else tostring(count))
	local width = if props.new then 38 else math.max(22, 10 + #text * 9)
	return React.createElement("TextLabel", {
		Size = UDim2.fromOffset(width, 22),
		Position = UDim2.new(1, 4, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = if props.new then Theme.colors.badgeNew else Theme.colors.badge,
		FontFace = Theme.fonts.header,
		Text = text,
		TextSize = Theme.textSize.caption,
		TextColor3 = Theme.colors.text,
		ZIndex = props.zIndex or 5,
		ref = mark.overlay,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
end

return Badge
