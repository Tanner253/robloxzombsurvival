--!strict
--[[
	Modal: a centred dialog over a full-screen panel (LDoE's storage upgrade, LDOE_PARITY
	#16): a title, a body column and a button row (CANCEL / BUY or CONFIRM). It covers the
	panel on purpose, so it is an overlay for the UI gate, and its own children are laid out
	by UIListLayout.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")
local Button = require("./Button")
local Layout = require("./Layout")
local mark = require("../mark")

local e = React.createElement

export type Action = {
	text: string,
	variant: ("primary" | "secondary")?,
	disabled: boolean?,
	onActivated: () -> (),
}

export type Props = {
	title: string,
	width: number?,
	height: number?,
	actions: { Action },
	children: any?, -- the body, laid out top to bottom
}

local function Modal(props: Props)
	local width = props.width or 440
	local height = props.height or 300
	local buttons: { [string]: any } = {}
	for index, action in props.actions do
		buttons[`A{index}`] = e(Button, {
			text = action.text,
			variant = action.variant or (if index == #props.actions then "primary" else "secondary"),
			disabled = action.disabled,
			onActivated = action.onActivated,
			size = UDim2.fromOffset(150, Theme.tapTarget),
			layoutOrder = index,
		})
	end
	local body: { [string]: any } = table.clone(props.children or {})
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.dim,
		BackgroundTransparency = 0.45,
		ZIndex = Theme.layers.modal,
		Active = true, -- swallows clicks to the panel underneath
		ref = mark.overlay,
	}, {
		Box = e("Frame", {
			Size = UDim2.fromOffset(width, height),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = Theme.colors.panelTransparency,
			ZIndex = Theme.layers.modal + 1,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", {
				Color = Theme.colors.strokeWarm,
				Thickness = Theme.strokeThickness,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Column = e(Layout.Stack, {
				gap = Theme.spacing.md,
				padding = Theme.spacing.lg,
				children = {
					Title = e("TextLabel", {
						Size = UDim2.new(1, 0, 0, Theme.textSize.title + 6),
						BackgroundTransparency = 1,
						FontFace = Theme.fonts.header,
						Text = string.upper(props.title),
						TextSize = Theme.textSize.title,
						TextColor3 = Theme.colors.text,
						LayoutOrder = 1,
					}),
					Body = e(Layout.Fill, {
						layoutOrder = 2,
						children = {
							Column = e(Layout.Stack, {
								gap = Theme.spacing.sm,
								alignX = Enum.HorizontalAlignment.Center,
								children = body,
							}),
						},
					}),
					Buttons = e(Layout.Stack, {
						direction = "row",
						gap = Theme.spacing.md,
						alignX = Enum.HorizontalAlignment.Center,
						size = UDim2.new(1, 0, 0, Theme.tapTarget),
						layoutOrder = 3,
						children = buttons,
					}),
				},
			}),
		}),
	})
end

return Modal
