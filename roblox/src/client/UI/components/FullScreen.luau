--!strict
--[[
	FullScreen: LDoE's full-screen panel (LDOE_PARITY #11, #13): the world dims, the HUD
	hides, two panes sit side by side, and a vertical CLOSE strip runs down the right edge
	(an X above a rotated "CLOSE"; Esc closes too).

	`left` and `right` are the panes' contents; each pane is a column with a header row,
	a body and an action bar, laid out by UIListLayout so nothing is hand-placed. The
	panes and the strip are siblings in one horizontal Stack, so they can't overlap.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")
local Glyph = require("./Glyph")
local Layout = require("./Layout")
local hooks = require("../hooks")
local mark = require("../mark")

local e = React.createElement

export type Props = {
	open: boolean,
	onClose: () -> (),
	left: any?,
	right: any?,
	rightWidth: number?, -- the right pane's width (defaults to Theme.panel.pane)
}

-- How far (design pixels) the dim reaches above the safe area, under the top bar.
local DIM_REACH = 120

local function CloseStrip(props: { onClose: () -> () })
	return e("TextButton", {
		Size = UDim2.new(0, Theme.hud.closeStrip, 1, 0),
		LayoutOrder = 9,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		[React.Event.Activated] = props.onClose,
	}, {
		-- Its backing runs up under the top bar, full height like LDoE's strip.
		Back = e("Frame", {
			ref = mark.backdrop,
			Size = UDim2.new(1, 0, 1, DIM_REACH),
			Position = UDim2.fromOffset(0, -DIM_REACH),
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 0,
		}),
		X = e(Glyph, {
			name = "close",
			size = UDim2.fromOffset(32, 32),
			position = UDim2.new(0.5, 0, 0, 28),
			anchorPoint = Vector2.new(0.5, 0),
			color = Theme.colors.textMuted,
		}),
		Label = e("TextLabel", {
			-- Rotated text: its unrotated box is laid along the strip.
			Size = UDim2.fromOffset(120, 24),
			Position = UDim2.new(0.5, 0, 0, 140),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = -90,
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = "CLOSE",
			TextSize = Theme.textSize.section,
			TextColor3 = Theme.colors.textMuted,
		}),
	})
end

local function FullScreen(props: Props)
	local alpha = hooks.useAnimated(if props.open then 1 else 0, 18, 0)
	if not props.open then
		return nil
	end
	local paneWidth = Theme.panel.pane
	local rightWidth = props.rightWidth or paneWidth
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.layers.panel,
	}, {
		-- The dim covers the world behind; it is drawn on purpose under everything, and runs
		-- up under Roblox's top bar so no bright band is left above it.
		Dim = e("Frame", {
			Size = UDim2.new(1, 0, 1, DIM_REACH),
			Position = UDim2.fromOffset(0, -DIM_REACH),
			BackgroundColor3 = Theme.colors.dim,
			BackgroundTransparency = alpha:map(function(a: number)
				return 1 - (1 - Theme.colors.dimTransparency) * a
			end),
			ref = mark.backdrop,
		}),
		Row = e(Layout.Stack, {
			direction = "row",
			children = {
				-- The panes, centred in what the CLOSE strip leaves.
				Area = e(Layout.Fill, {
					direction = "row",
					layoutOrder = 1,
					children = {
						Panes = e(Layout.Stack, {
							direction = "row",
							gap = Theme.panel.gap,
							alignX = Enum.HorizontalAlignment.Center,
							alignY = Enum.VerticalAlignment.Center,
							padding = Theme.spacing.xl,
							children = {
								Left = e("Frame", {
									Size = UDim2.new(0, paneWidth, 1, 0),
									BackgroundTransparency = 1,
									LayoutOrder = 1,
								}, props.left),
								Right = e("Frame", {
									Size = UDim2.new(0, rightWidth, 1, 0),
									BackgroundTransparency = 1,
									LayoutOrder = 2,
								}, props.right),
							},
						}),
					},
				}),
				Close = e(CloseStrip, { onClose = props.onClose }),
			},
		}),
	})
end

return FullScreen
