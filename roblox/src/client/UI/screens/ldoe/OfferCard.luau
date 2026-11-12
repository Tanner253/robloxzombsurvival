--!strict
--[[
	OfferCard: the one-time card a limited offer opens with (the flow review's F-11; LDoE's
	travel popup offer with its timer, rec3 34s). The Firestarter Kit's 48 h window starts at
	the first win; the server sends "firstOffer" once (Services/Shop), Controllers/Shop sets
	State.ui().offerCard, and this shows the kit's art, what is in it, the live countdown and
	the shop's price button. LATER closes it; the HUD's offers strip keeps the countdown until
	the window ends. Nothing here invents urgency: the countdown is the real window.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Actions = require("../../../Actions")
local State = require("../../../State")
local Theme = require("../../theme")
local format = require("../../format")
local hooks = require("../../hooks")
local Modal = require("../../components/Modal")
local PriceButton = require("../../components/PriceButton")
local Parts = require("./Parts")

local e = React.createElement

local function OfferCard()
	local ui = hooks.useUi()
	local shop = hooks.useSection("shop")
	local now = hooks.useClock(1)
	local card = ui.offerCard
	local product: any = if card then Content.Products[card.productId] else nil
	local row = if card and type(shop) == "table" then shop[card.productId] else nil
	-- Gone once bought, or once the window has run out.
	if card == nil or product == nil or (row ~= nil and row.available ~= true) or card.endsAt <= now then
		return nil
	end
	local function close()
		State.clear("offerCard")
	end
	return e(Modal, {
		title = product.name,
		width = 460,
		height = 430,
		actions = { { text = "Later", variant = "secondary", onActivated = close } },
		children = {
			Ribbon = e(Parts.Line, {
				text = "You made it through. A survivor's kit, once:",
				tone = Theme.colors.accentSoft,
				center = true,
				layoutOrder = 1,
			}),
			Art = e("ImageLabel", {
				Size = UDim2.fromOffset(150, 120),
				BackgroundTransparency = 1,
				Image = product.icon or "",
				ScaleType = Enum.ScaleType.Fit,
				LayoutOrder = 2,
			}),
			What = e(Parts.Line, {
				text = product.description,
				tone = Theme.colors.text,
				center = true,
				wrap = true,
				layoutOrder = 3,
			}),
			Ends = e(Parts.Line, {
				text = `Ends in {format.duration(card.endsAt - now)}`,
				tone = Theme.colors.accentSoft,
				center = true,
				layoutOrder = 4,
			}),
			Buy = e(PriceButton, {
				currency = "robux",
				price = if row and type(row.price) == "number" then row.price else product.defaultPriceRobux,
				enabled = true,
				size = UDim2.fromOffset(200, Theme.tapTarget),
				layoutOrder = 5,
				onActivated = function()
					close()
					Actions.buyProduct(card.productId)
				end,
			}),
		},
	})
end

return OfferCard
