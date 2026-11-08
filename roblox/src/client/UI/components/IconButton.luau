--!strict
--[[
	IconButton: LDoE's round HUD and menu buttons (LDOE_PARITY #1-4): a dark disc with a
	ring, a glyph from the set (never emoji, checklist 4.17), an optional caption under it
	("AUTO"), a count or NEW badge on its corner, and the PC keybind chip on its lower
	corner. Everything it shows is its own child, so the UI gate sees one element.

	`active` lights the ring (AUTO on, sprinting); `disabled` greys it (context button with
	nothing in range). Touch targets are never under Theme.tapTarget.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")
local Badge = require("./Badge")
local Glyph = require("./Glyph")
local KeyChip = require("./KeyChip")
local Sfx = require("../../Sfx")
local mark = require("../mark")

export type Props = {
	glyph: string,
	size: number,
	caption: string?, -- drawn inside the disc, under the glyph (LDoE's "AUTO")
	key: string?, -- keybind chip text; hidden on touch
	badge: number?,
	new: boolean?,
	active: boolean?,
	disabled: boolean?,
	ring: Color3?, -- ring colour when active (default ember)
	square: boolean?, -- the menu bar's square icons
	layoutOrder: number?,
	position: UDim2?,
	anchorPoint: Vector2?,
	onPress: (() -> ())?,
	onDown: (() -> ())?, -- pressed (held actions: gather, attack)
	onRelease: (() -> ())?,
	children: any?,
}

local function IconButton(props: Props)
	local pressed, setPressed = React.useState(false)
	local size = math.max(props.size, Theme.tapTarget)
	local disabled = props.disabled == true
	local ringColor = if props.active
		then (props.ring or Theme.colors.accent)
		elseif disabled then Theme.colors.disabledStroke
		else Theme.colors.strokeWarm
	local glyphColor = if disabled then Theme.colors.disabledText else Theme.colors.text
	local glyphScale = if props.caption then 0.46 else 0.56

	local children: { [string]: any } = {
		Corner = React.createElement("UICorner", {
			CornerRadius = if props.square then Theme.radius else UDim.new(0.5, 0),
		}),
		Ring = React.createElement("UIStroke", {
			Color = ringColor,
			Thickness = if props.active then 3 else Theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Scale = React.createElement("UIScale", { Scale = if pressed then 0.94 else 1 }),
		Icon = React.createElement(Glyph, {
			name = props.glyph,
			size = UDim2.fromScale(glyphScale, glyphScale),
			position = UDim2.fromScale(0.5, if props.caption then 0.4 else 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			color = glyphColor,
		}),
		Caption = props.caption and React.createElement("TextLabel", {
			Size = UDim2.new(0.9, 0, 0, Theme.textSize.caption + 2),
			Position = UDim2.fromScale(0.5, 0.82),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = props.caption,
			TextSize = Theme.textSize.caption,
			TextColor3 = glyphColor,
		}),
		Badge = React.createElement(Badge, { count = props.badge, new = props.new }),
		Key = props.key and React.createElement(KeyChip, {
			text = props.key,
			position = UDim2.new(1, 2, 1, 2),
			anchorPoint = Vector2.new(1, 1),
		}),
	}
	for name, child in props.children or {} do
		children[name] = child
	end

	return React.createElement("TextButton", {
		Size = UDim2.fromOffset(size, size),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = false,
		BackgroundColor3 = if props.active then Theme.colors.panelRaised else Theme.colors.panel,
		BackgroundTransparency = 0.12,
		Text = "",
		ref = mark.composite, -- the glyph, caption, badge and key chip sit on the disc
		[React.Event.MouseButton1Down] = function()
			if disabled then
				return
			end
			setPressed(true)
			if props.onDown then
				props.onDown()
			end
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
			if props.onRelease then
				props.onRelease()
			end
		end,
		[React.Event.MouseLeave] = function()
			setPressed(false)
		end,
		[React.Event.Activated] = function()
			if disabled then
				Sfx.play("uiError")
				return
			end
			if props.onPress then
				Sfx.play("uiClick")
				props.onPress()
			end
		end,
	}, children)
end

return IconButton
