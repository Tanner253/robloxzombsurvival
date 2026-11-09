--!strict
--[[
	The v0.1 shop (MVP_LAUNCH Monetization v0.1; docs/research/ldoe-monetization-playbook.md
	§6.1), keyed by permanent ID: eight developer products and two game passes, in LDoE's
	card style.

	- Everything a product gives goes to the inbox (raid-proof, never expires); Embers go to
	  the balance; every receipt is logged (Domain/Receipts, Services/Shop).
	- robloxId is the developer product or game pass on universe 10775267789 (made through
	  Open Cloud). defaultPriceRobux is a display fallback from Tuning.prices: the live price
	  comes from MarketplaceService.
	- Contents follow the playbook's value rule (about 1.5 free grind-hours per 100 Robux for
	  small packs, 1.6 for medium, 1.8 for large; the Firestarter Kit 10-20x), valued against
	  docs/ECONOMY.md's chains: a Scrap Plate or Ironbark Plank about 20 minutes (the
	  Workbench and Saw Bench L2 throttles), a Rivet 12, a Stone Block 4, a Hewn Plank 3, raw
	  materials under a minute. The Firestarter Kit's Scrap room is derived from the build
	  data (Domain/Kits), so it stays complete when building costs change.
	- Guardrails: no shields or raid immunity, never locked-stash capacity, no random boxes,
	  no invented "was" prices (Domain/Offers: sales are real 72 h windows that never
	  restart).
]]

local Types = require("../Types")
local Tuning = require("./Tuning")
local BuildPieces = require("./BuildPieces")
local Kits = require("../Domain/Kits")

local price = Tuning.prices.robux

local function items(list: { Types.ItemStack }): { Types.ProductGrant }
	local grants: { Types.ProductGrant } = {}
	for _, stack in list do
		local grant: Types.ProductGrant = { kind = "item", itemId = stack.itemId, count = stack.count }
		table.insert(grants, grant)
	end
	return grants
end

local function join(...: { Types.ProductGrant }): { Types.ProductGrant }
	local all: { Types.ProductGrant } = {}
	for _, list in { ... } do
		for _, grant in list do
			table.insert(all, grant)
		end
	end
	return all
end

local Products: { [Types.ProductId]: Types.ProductDef } = {
	["product.starter_offer"] = {
		id = "product.starter_offer",
		name = "Firestarter Kit",
		description = "Blade, padded armor, medicine, food, a Scrap room's materials, a Pack Frame, 100 Embers and 5 Rations.",
		kind = "devProduct",
		robloxId = 3729832319,
		icon = "rbxassetid://112249752517773",
		defaultPriceRobux = price["product.starter_offer"],
		limit = 1,
		offer = "firstPurchase",
		tab = "best",
		grants = join(
			items({
				{ itemId = "item.scrapblade", count = 1 },
				{ itemId = "item.padded_hood", count = 1 },
				{ itemId = "item.padded_vest", count = 1 },
				{ itemId = "item.field_dressing", count = 10 },
				{ itemId = "item.hearth_stew", count = 5 },
				{ itemId = "item.ember_tonic", count = 3 },
				{ itemId = "item.pack_frame", count = 1 },
				{ itemId = "item.rations", count = 5 },
			}),
			items(Kits.room(BuildPieces, 2)),
			{ { kind = "embers", amount = 100 } }
		),
	},
	["product.scavenger_kit"] = {
		id = "product.scavenger_kit",
		name = "Scavenger's Kit",
		description = "A Scrapblade, a padded vest, dressings, stew and water: back into the Fog after a bad run.",
		kind = "devProduct",
		robloxId = 3729872993,
		icon = "rbxassetid://103183324723356",
		defaultPriceRobux = price["product.scavenger_kit"],
		tab = "supplies",
		grants = items({
			{ itemId = "item.scrapblade", count = 1 },
			{ itemId = "item.padded_vest", count = 1 },
			{ itemId = "item.field_dressing", count = 5 },
			{ itemId = "item.hearth_stew", count = 5 },
			{ itemId = "item.boiled_water", count = 5 },
		}),
	},
	["product.resource_pack"] = {
		id = "product.resource_pack",
		name = "Supply Bundle",
		description = "Timber, stone, ironstone, planks and two plates: an evening of gathering for a bigger base.",
		kind = "devProduct",
		robloxId = 3729832298,
		icon = "rbxassetid://88547464179013",
		defaultPriceRobux = price["product.resource_pack"],
		tab = "supplies",
		grants = items({ -- about 1.7 grind-hours
			{ itemId = "item.timber", count = 60 },
			{ itemId = "item.stone", count = 60 },
			{ itemId = "item.ironstone", count = 30 },
			{ itemId = "item.plank", count = 10 },
			{ itemId = "item.scrap_plate", count = 2 },
		}),
	},
	["product.builders_crate"] = {
		id = "product.builders_crate",
		name = "Builder's Crate",
		description = "The Timber-to-Scrap climb in one crate, heavy on Rivets: rivets, plates, planks and blocks.",
		kind = "devProduct",
		robloxId = 3729873035,
		icon = "rbxassetid://121572315473616",
		defaultPriceRobux = price["product.builders_crate"],
		tab = "best",
		grants = items({ -- about 6.4 grind-hours, Rivets the star (the Scrap bottleneck)
			{ itemId = "item.rivets", count = 16 },
			{ itemId = "item.scrap_plate", count = 5 },
			{ itemId = "item.plank", count = 30 },
			{ itemId = "item.stone_block", count = 12 },
		}),
	},
	["product.room_kit_reinforced"] = {
		id = "product.room_kit_reinforced",
		name = "Reinforced Room Kit",
		description = "A long start on a Reinforced room: Ironbark Planks, Copper Wire, plates, rivets and blocks.",
		kind = "devProduct",
		robloxId = 3729873052,
		icon = "rbxassetid://111714823062229",
		defaultPriceRobux = price["product.room_kit_reinforced"],
		tab = "supplies",
		grants = items({ -- about 32 grind-hours (the whole 3x3 room is about 145)
			{ itemId = "item.ironbark_plank", count = 30 },
			{ itemId = "item.copper_wire", count = 12 },
			{ itemId = "item.scrap_plate", count = 30 },
			{ itemId = "item.rivets", count = 20 },
			{ itemId = "item.stone_block", count = 60 },
		}),
	},
	["product.energy_refill"] = {
		id = "product.energy_refill",
		name = "Energy Refill",
		description = "100 Energy at once, for one more run into the Fog. Goes past your cap.",
		kind = "devProduct",
		robloxId = 3729832267,
		icon = "rbxassetid://124493550943493",
		defaultPriceRobux = price["product.energy_refill"],
		tab = "supplies",
		grants = { { kind = "energy", amount = 100 } },
	},
	["product.embers_50"] = {
		id = "product.embers_50",
		name = "Ember Pouch",
		description = "50 Embers for Fill Up, speed-ups, Rations and Recover all.",
		kind = "devProduct",
		robloxId = 3729873068,
		icon = "rbxassetid://94850842702164",
		defaultPriceRobux = price["product.embers_50"],
		tab = "embers",
		grants = { { kind = "embers", amount = 50 } },
	},
	["product.embers_300"] = {
		id = "product.embers_300",
		name = "Ember Chest",
		description = "300 Embers: the better rate for a long build.",
		kind = "devProduct",
		robloxId = 3729873080,
		icon = "rbxassetid://76937309861540",
		defaultPriceRobux = price["product.embers_300"],
		tab = "embers",
		grants = { { kind = "embers", amount = 300 } },
	},
	["product.pack_expansion"] = {
		id = "product.pack_expansion",
		name = "Pack Expansion",
		description = "Five more backpack slots, for good, on top of any bag you wear.",
		kind = "gamePass",
		robloxId = 2076082454,
		icon = "rbxassetid://109080673192504", -- square art (Roblox stores pass icons as circles)
		defaultPriceRobux = price["product.pack_expansion"],
		limit = 1,
		tab = "passes",
		grants = { { kind = "backpackSlots", amount = 5 } },
	},
	["product.vip_lounge"] = {
		id = "product.vip_lounge",
		name = "VIP Lounge",
		description = "The Haven Square Lounge for good: its fire, a flame aura, a daily crate and +40 Energy cap.",
		kind = "gamePass",
		robloxId = 2075836390,
		icon = "rbxassetid://131080427617819", -- square art (art/ui/products/vip_lounge.png)
		defaultPriceRobux = price["product.vip_lounge"],
		limit = 1,
		tab = "passes",
		grants = { { kind = "vipLounge" } },
	},
}

return Products
