--!strict
--[[
	PriceButton: the shop's price button. Robux (with the Robux mark) or Embers (with the coin
	glyph), on the chip colour; greyed and an error click when not enabled. `label` puts a
	word before the price ("Recover all"); `text` replaces the price ("Owned"). Fills its
	parent's width unless given a size. The shop cards and the moment-of-need offers (the death
	screen, the Fog map's Refill) share it, so every buy button reads the same.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Sfx = require("../../Sfx")
local Theme = require("../theme")
local Glyph = require("./Glyph")
local Layout = require("./Layout")

local e = React.createElement

local ROBUX = "rbxasset://textures/ui/common/robux.png"

export type Props = {
	currency: "robux" | "embers",
	price: number?,
	text: string?,
	label: string?,
	enabled: boolean,
	layoutOrder: number?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	onActivated: () -> (),
}

local function PriceButton(props: Props)
	local textColor = if props.enabled then Theme.colors.text else Theme.colors.disabledText
	return e("TextButton", {
		Size = props.size or UDim2.new(1, 0, 0, Theme.tapTarget),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		AutoButtonColor = props.enabled,
		BackgroundColor3 = if props.enabled then Theme.colors.chip else Theme.colors.disabled,
		Text = "",
		LayoutOrder = props.layoutOrder,
		[React.Event.Activated] = function()
			if props.enabled then
				props.onActivated()
			else
				Sfx.play("uiError")
			end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Row = e(Layout.Stack, {
			direction = "row",
			gap = 6,
			alignX = Enum.HorizontalAlignment.Center,
			alignY = Enum.VerticalAlignment.Center,
			children = {
				Label = props.label and e("TextLabel", {
					Size = UDim2.fromOffset(0, 28),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.header,
					Text = props.label,
					TextSize = Theme.textSize.body,
					TextColor3 = textColor,
					LayoutOrder = 0,
				}),
				Robux = props.price ~= nil and props.currency == "robux" and e("ImageLabel", {
					Size = UDim2.fromOffset(22, 22),
					BackgroundTransparency = 1,
					Image = ROBUX,
					LayoutOrder = 1,
				}),
				Coin = props.price ~= nil
					and props.currency == "embers"
					and e(Glyph, { name = "coin", size = UDim2.fromOffset(24, 24), layoutOrder = 1 }),
				Price = e("TextLabel", {
					Size = UDim2.fromOffset(0, 28),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.header,
					Text = props.text or tostring(props.price),
					TextSize = Theme.textSize.title,
					TextColor3 = textColor,
					LayoutOrder = 2,
				}),
			},
		}),
	})
end

return PriceButton
