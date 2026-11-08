--!strict
-- Robux product definitions, keyed by permanent ID. M0 placeholders.
-- Grants go into the locked stash and are recorded by receipt ID (ARCHITECTURE.md §6).

local Types = require("../Types")

local Products: { [Types.ProductId]: Types.ProductDef } = {
	["product.resource_pack_small"] = {
		id = "product.resource_pack_small",
		name = "Small Resource Pack",
		kind = "devProduct",
		robloxId = 0,
		grants = {
			{ kind = "item", itemId = "item.wood", count = 100 },
			{ kind = "item", itemId = "item.stone", count = 100 },
		},
	},
	["product.energy_refill"] = {
		id = "product.energy_refill",
		name = "Energy Refill",
		kind = "devProduct",
		robloxId = 0,
		grants = { { kind = "energy", amount = 20 } },
	},
	["product.backpack_upgrade"] = {
		id = "product.backpack_upgrade",
		name = "Backpack Upgrade",
		kind = "gamePass",
		robloxId = 0,
		grants = { { kind = "backpackSlots", amount = 4 } },
	},
}

return Products
