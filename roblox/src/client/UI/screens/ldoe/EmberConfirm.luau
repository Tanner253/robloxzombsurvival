--!strict
--[[
	EmberConfirm: the confirm for an Ember purchase that isn't one tap (Fill Up): what it
	buys, the price in Embers with the coin glyph, and the balance. BUY when the balance
	covers it, otherwise GET EMBERS opens the shop's EMBERS tab. Controllers/Shop raises it
	by setting State.ui().emberAsk.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Actions = require("../../../Actions")
local State = require("../../../State")
local Theme = require("../../theme")
local hooks = require("../../hooks")
local Glyph = require("../../components/Glyph")
local Layout = require("../../components/Layout")
local Modal = require("../../components/Modal")
local Parts = require("./Parts")

local e = React.createElement

local function EmberConfirm()
	local ui = hooks.useUi()
	local wallet = hooks.useSection("wallet")
	local ask = ui.emberAsk
	if ask == nil then
		return nil
	end
	local balance = if type(wallet) == "table" then wallet.embers else 0
	local enough = balance >= ask.price
	local function close()
		State.clear("emberAsk")
	end
	return e(Modal, {
		title = ask.title,
		height = 280,
		actions = {
			{ text = "Cancel", variant = "secondary", onActivated = close },
			if enough
				then {
					text = "Buy",
					variant = "primary",
					onActivated = function()
						ask.run()
						close()
					end,
				}
				else {
					text = "Get Embers",
					variant = "primary",
					onActivated = function()
						close()
						Actions.openShop(nil, "embers")
					end,
				},
		},
		children = {
			What = e(
				Parts.Line,
				{ text = ask.text, tone = Theme.colors.text, center = true, wrap = true, layoutOrder = 1 }
			),
			Price = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.xs,
				alignX = Enum.HorizontalAlignment.Center,
				alignY = Enum.VerticalAlignment.Center,
				size = UDim2.new(1, 0, 0, 36),
				layoutOrder = 2,
				children = {
					Coin = e(Glyph, { name = "coin", size = UDim2.fromOffset(30, 30), layoutOrder = 1 }),
					Amount = e("TextLabel", {
						Size = UDim2.fromOffset(0, 30),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						FontFace = Theme.fonts.header,
						Text = tostring(ask.price),
						TextSize = Theme.textSize.title,
						TextColor3 = Theme.colors.text,
						LayoutOrder = 2,
					}),
				},
			}),
			Balance = e(Parts.Line, {
				text = if enough
					then `You have {balance} Embers`
					else `You have {balance} Embers: get more in the shop`,
				center = true,
				layoutOrder = 3,
			}),
		},
	})
end

return EmberConfirm
