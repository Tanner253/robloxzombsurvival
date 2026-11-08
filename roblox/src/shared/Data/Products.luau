--!strict
--[[
	Robux product definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.

	Item grants go into the locked stash and are recorded by receipt ID
	(ARCHITECTURE.md §6), so nothing bought can be raided. Prices here are display
	fallbacks only: the live price comes from MarketplaceService.
	Guardrails: no shields or raid immunity, no random boxes.
]]

local Types = require("../Types")

local Products: { [Types.ProductId]: Types.ProductDef } = {
	["product.resource_pack"] = {
		id = "product.resource_pack",
		name = "Outpost Supply Bundle",
		kind = "devProduct",
		robloxId = 0,
		defaultPriceRobux = 99,
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
		kind = "devProduct",
		robloxId = 0,
		defaultPriceRobux = 49,
		grants = { { kind = "energy", amount = 100 } },
	},
	["product.backpack_upgrade"] = {
		id = "product.backpack_upgrade",
		name = "Pack Expansion",
		kind = "gamePass",
		robloxId = 0,
		defaultPriceRobux = 149,
		limit = 1,
		grants = { { kind = "backpackSlots", amount = 6 } },
	},
	["product.starter_offer"] = {
		id = "product.starter_offer",
		name = "Firestarter Kit",
		kind = "devProduct",
		robloxId = 0,
		defaultPriceRobux = 99,
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
