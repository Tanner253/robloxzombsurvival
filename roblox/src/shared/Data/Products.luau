--!strict
--[[
	Robux product definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.

	The v0.1 shop (MVP_LAUNCH, LDoE shop style): four developer products. Item grants go
	to the inbox (never raidable) and every receipt is logged in the profile
	(Domain/Receipts, Services/Shop). robloxId is the developer product on universe
	10775267789 (made through Open Cloud); defaultPriceRobux is the price it was made with
	and the display fallback: the live price comes from MarketplaceService.
	Guardrails: no shields or raid immunity, no random boxes, no invented "was" prices.
]]

local Types = require("../Types")

local Products: { [Types.ProductId]: Types.ProductDef } = {
	["product.resource_pack"] = {
		id = "product.resource_pack",
		name = "Resource Pack",
		description = "Timber, stone, scrap, planks and plates: a week of gathering for a bigger base.",
		kind = "devProduct",
		robloxId = 3729832298,
		icon = "rbxassetid://88547464179013", -- the product icon (art/ui/products)
		defaultPriceRobux = 199,
		grants = {
			{ kind = "item", itemId = "item.timber", count = 60 },
			{ kind = "item", itemId = "item.stone", count = 60 },
			{ kind = "item", itemId = "item.scrap", count = 40 },
			{ kind = "item", itemId = "item.plank", count = 30 },
			{ kind = "item", itemId = "item.scrap_plate", count = 10 },
		},
	},
	["product.energy_refill"] = {
		id = "product.energy_refill",
		name = "Energy Refill",
		description = "100 Energy at once, for one more run into the Fog. Goes past your cap.",
		kind = "devProduct",
		robloxId = 3729832267,
		icon = "rbxassetid://124493550943493", -- the product icon (art/ui/products)
		defaultPriceRobux = 49,
		grants = { { kind = "energy", amount = 100 } },
	},
	["product.backpack_upgrade"] = {
		id = "product.backpack_upgrade",
		name = "Backpack Upgrade",
		description = "Five more backpack slots, for good, on top of any bag you wear.",
		kind = "devProduct",
		robloxId = 3729832309,
		icon = "rbxassetid://109080673192504", -- the product icon (art/ui/products)
		defaultPriceRobux = 149,
		limit = 1,
		grants = { { kind = "backpackSlots", amount = 5 } },
	},
	["product.starter_offer"] = {
		id = "product.starter_offer",
		name = "Starter Pack",
		description = "A blade, padded armor, medicine and food, and the planks and plates to build on. Once, until level 10.",
		kind = "devProduct",
		robloxId = 3729832319,
		icon = "rbxassetid://112249752517773", -- the product icon (art/ui/products)
		defaultPriceRobux = 149,
		limit = 1,
		offerMaxLevel = 10,
		grants = {
			{ kind = "item", itemId = "item.scrapblade", count = 1 },
			{ kind = "item", itemId = "item.padded_hood", count = 1 },
			{ kind = "item", itemId = "item.padded_vest", count = 1 },
			{ kind = "item", itemId = "item.field_dressing", count = 10 },
			{ kind = "item", itemId = "item.hearth_stew", count = 5 },
			{ kind = "item", itemId = "item.ember_tonic", count = 3 },
			{ kind = "item", itemId = "item.plank", count = 30 },
			{ kind = "item", itemId = "item.scrap_plate", count = 10 },
		},
	},
}

return Products
