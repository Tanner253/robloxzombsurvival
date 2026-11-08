--!strict
--[[
	Sheet: an animated Panel for full screens (inventory, stations, build menu).
	Opening eases it in (a small rise and scale); closing eases it out and then
	hides it. No CanvasGroup: a CanvasGroup renders its content through an
	offscreen texture, which blurs text and icons (checklist 4.1), so motion
	comes from position and UIScale only and the content is always crisp. Children render only while it is open or animating, so closed
	screens cost nothing. Header shows a title, an optional subtitle and a close
	button with its keybind.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("../theme")
local Glyph = require("./Glyph")
local hooks = require("../hooks")
local KeyChip = require("./KeyChip")
local mark = require("../mark")

export type Props = {
	open: boolean,
	title: string?,
	subtitle: string?,
	closeKey: string?,
	onClose: (() -> ())?,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	rise: number?, -- studs of slide-in in pixels, default 18
	children: any?,
}

local HEADER = 40
-- The least gap kept between a sheet and the design frame's edge.
local FRAME_MARGIN = 8

local function Sheet(props: Props)
	local alpha = hooks.useAnimated(if props.open then 1 else 0, 16, 0)
	local visible, setVisible = React.useState(props.open)

	React.useEffect(function()
		if props.open then
			setVisible(true)
			return function() end
		end
		local thread = task.delay(0.3, function()
			setVisible(false)
		end)
		return function()
			task.cancel(thread)
		end
	end, { props.open })

	if not visible and not props.open then
		return nil
	end
	local rise = props.rise or 18
	local base = props.position or UDim2.fromScale(0.5, 0.5)
	local headerHeight = if props.title then HEADER else 0
	-- A sheet never outgrows the design frame (a phone's is shorter than 768).
	local frame = Theme.currentFrame
	local size = UDim2.new(
		props.size.X.Scale,
		math.min(props.size.X.Offset, frame.X - FRAME_MARGIN * 2),
		props.size.Y.Scale,
		math.min(props.size.Y.Offset, frame.Y - FRAME_MARGIN * 2)
	)

	return React.createElement("Frame", {
		Size = size,
		Position = alpha:map(function(a: number)
			return base + UDim2.fromOffset(0, math.round((1 - a) * rise))
		end),
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = alpha:map(function(a: number)
			return a > 0.02
		end),
		ZIndex = 10,
	}, {
		Scale = React.createElement("UIScale", {
			Scale = alpha:map(function(a: number)
				-- Exactly 1 at rest, so nothing is resampled while the screen is open.
				return if a > 0.995 then 1 else 0.94 + 0.06 * a
			end),
		}),
		Shadow = React.createElement("Frame", {
			ref = mark.decor,
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4 + Theme.shadowOffset),
			BackgroundColor3 = Theme.colors.shadow,
			BackgroundTransparency = Theme.colors.shadowTransparency,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.radius }),
		}),
		Body = React.createElement("Frame", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = Theme.colors.panelTransparency,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.radius }),
			Stroke = React.createElement("UIStroke", {
				Color = Theme.colors.strokeWarm,
				Thickness = Theme.strokeThickness,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Glow = React.createElement("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(255, 240, 225), Color3.new(1, 1, 1)),
				Rotation = 90,
			}),
			Header = props.title
				and React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, HEADER),
					BackgroundTransparency = 1,
				}, {
					Title = React.createElement("TextLabel", {
						Size = UDim2.new(1, -120, 1, -2), -- the rule runs under it
						Position = UDim2.fromOffset(Theme.spacing.lg, 0),
						BackgroundTransparency = 1,
						FontFace = Theme.fonts.header,
						RichText = true,
						Text = if props.subtitle
							then `{string.upper(props.title)}  <font size="{Theme.textSize.caption + 2}" color="#{Theme.colors.textMuted:ToHex()}">{props.subtitle}</font>`
							else string.upper(props.title),
						TextSize = Theme.textSize.title,
						TextColor3 = Theme.colors.text,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Rule = React.createElement("Frame", {
						Size = UDim2.new(1, -Theme.spacing.lg * 2, 0, 2),
						Position = UDim2.new(0, Theme.spacing.lg, 1, -1),
						BackgroundColor3 = Theme.colors.accent,
						BackgroundTransparency = 0.6,
						BorderSizePixel = 0,
					}, {
						Fade = React.createElement("UIGradient", {
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(1, 1),
							}),
						}),
					}),
					Close = props.onClose and React.createElement("TextButton", {
						Size = UDim2.fromOffset(Theme.tapTarget, Theme.tapTarget - 8),
						Position = UDim2.new(1, -Theme.spacing.sm, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundColor3 = Theme.colors.panelRaised,
						AutoButtonColor = true,
						FontFace = Theme.fonts.header,
						Text = "",
						TextSize = Theme.textSize.body,
						TextColor3 = Theme.colors.text,
						[React.Event.Activated] = props.onClose,
					}, {
						Glyph = React.createElement(Glyph, {
							name = "close",
							size = UDim2.fromScale(0.5, 0.5),
							position = UDim2.fromScale(0.5, 0.5),
							anchorPoint = Vector2.new(0.5, 0.5),
							color = Theme.colors.text,
						}),
						Corner = React.createElement("UICorner", { CornerRadius = Theme.radius }),
						Stroke = React.createElement("UIStroke", {
							Color = Theme.colors.strokeWarm,
							Thickness = 1,
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						}),
					}),
					CloseKey = props.closeKey and React.createElement(KeyChip, {
						text = props.closeKey,
						position = UDim2.new(1, -Theme.spacing.sm - Theme.tapTarget - 6, 0.5, 0),
						anchorPoint = Vector2.new(1, 0.5),
					}),
				}),
			Content = React.createElement("Frame", {
				Size = UDim2.new(1, -Theme.spacing.lg * 2, 1, -headerHeight - Theme.spacing.lg),
				Position = UDim2.fromOffset(Theme.spacing.lg, headerHeight + Theme.spacing.sm),
				BackgroundTransparency = 1,
			}, props.children),
		}),
	})
end

return Sheet
