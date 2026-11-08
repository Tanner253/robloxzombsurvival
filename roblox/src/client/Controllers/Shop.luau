--!strict
--[[
	Shop (client): fills the moment-of-need slots (UI/offers) for the v0.1 shop
	(MVP_LAUNCH): "Fill up" in the craft, build and station panels opens the shop on the
	Resource Pack; the travel panel's Energy Refill prompts that product; the inventory's
	currency "+" opens the shop. The server decides what is on offer (Services/Shop).
]]

local Actions = require("../Actions")
local offers = require("../UI/offers")

local Shop = {}

function Shop.init()
	offers.fillUp = function(_stacks: { { itemId: string, count: number } })
		Actions.openShop("product.resource_pack")
	end
	offers.buyEnergy = function()
		Actions.buyProduct("product.energy_refill")
	end
	offers.openShop = function(productId: string?)
		Actions.openShop(productId)
	end
end

function Shop.start() end

return Shop
