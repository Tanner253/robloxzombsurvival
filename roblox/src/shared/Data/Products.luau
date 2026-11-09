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
	- The room kits are derived from the build data (Domain/Kits), so they stay complete when
	  the economy retunes building costs.
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
				{ itemId = "item.plank", count = 30 },
				{ itemId = "item.scrap_plate", count = 10 },
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
		description = "Timber, stone, scrap, planks and plates: an evening of gathering for a bigger base.",
		kind = "devProduct",
		robloxId = 3729832298,
		icon = "rbxassetid://88547464179013",
		defaultPriceRobux = price["product.resource_pack"],
		tab = "supplies",
		grants = items({
			{ itemId = "item.timber", count = 60 },
			{ itemId = "item.stone", count = 60 },
			{ itemId = "item.scrap", count = 40 },
			{ itemId = "item.plank", count = 30 },
			{ itemId = "item.scrap_plate", count = 10 },
		}),
	},
	["product.builders_crate"] = {
		id = "product.builders_crate",
		name = "Builder's Crate",
		description = "The Timber-to-Scrap climb in one crate, heavy on Rivets: planks, plates, blocks and more.",
		kind = "devProduct",
		robloxId = 3729873035,
		icon = "rbxassetid://121572315473616",
		defaultPriceRobux = price["product.builders_crate"],
		tab = "best",
		grants = items({
			{ itemId = "item.rivets", count = 40 },
			{ itemId = "item.scrap_plate", count = 30 },
			{ itemId = "item.plank", count = 60 },
			{ itemId = "item.stone_block", count = 30 },
			{ itemId = "item.timber", count = 120 },
			{ itemId = "item.stone", count = 100 },
			{ itemId = "item.rope", count = 20 },
		}),
	},
	["product.room_kit_reinforced"] = {
		id = "product.room_kit_reinforced",
		name = "Reinforced Room Kit",
		description = "Every material for a 3x3 Reinforced room: nine floors, eleven walls, a doorway and its door.",
		kind = "devProduct",
		robloxId = 3729873052,
		icon = "rbxassetid://111714823062229",
		defaultPriceRobux = price["product.room_kit_reinforced"],
		tab = "supplies",
		grants = items(Kits.room(BuildPieces, 3)),
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
