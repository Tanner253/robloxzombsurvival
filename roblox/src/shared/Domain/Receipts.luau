--!strict
--[[
	Receipts: the pure rules behind Robux purchases (ARCHITECTURE.md §6, MVP_LAUNCH v0.1).

	A receipt is granted exactly once. Its ID goes into the profile's receipt log in the
	same change that grants the goods, so a receipt Roblox delivers twice (a retry after
	a crash, a second server) finds its ID and grants nothing. The server confirms the
	receipt to Roblox only after that profile version has saved (Services/Shop).

	Limits gate the offer, never the delivery: once Robux are spent the goods are always
	delivered, even if a race let a capped product through.
]]

local Types = require("../Types")

local Receipts = {}

export type Purchases = {
	receiptIds: { string }, -- most recent last, capped at the log size
	counts: { [string]: number }, -- purchases per product ID, for limits
	backpackSlots: number, -- backpack slots bought (Backpack Upgrade)
}

-- What a product delivers: items to the inbox, energy, backpack slots.
export type Delivery = { items: { Types.ItemStack }, energy: number, backpackSlots: number }

export type Decision = "granted" | "duplicate"

function Receipts.seen(purchases: Purchases, receiptId: string): boolean
	return table.find(purchases.receiptIds, receiptId) ~= nil
end

-- The product with this Roblox product ID, if any.
function Receipts.productByRobloxId(products: { [string]: Types.ProductDef }, robloxId: number): Types.ProductDef?
	if robloxId == 0 then
		return nil
	end
	for _, product in products do
		if product.robloxId == robloxId then
			return product
		end
	end
	return nil
end

function Receipts.delivery(product: Types.ProductDef): Delivery
	local result: Delivery = { items = {}, energy = 0, backpackSlots = 0 }
	for _, grant in product.grants do
		local g: any = grant
		if g.kind == "item" then
			table.insert(result.items, { itemId = g.itemId, count = g.count })
		elseif g.kind == "energy" then
			result.energy += g.amount
		elseif g.kind == "backpackSlots" then
			result.backpackSlots += g.amount
		end
	end
	return result
end

-- Whether the shop may offer `product` now, and why not.
function Receipts.canOffer(product: Types.ProductDef, purchases: Purchases, level: number): (boolean, string?)
	if product.robloxId == 0 then
		return false, "notListed"
	end
	local bought = purchases.counts[product.id] or 0
	if product.limit and bought >= product.limit then
		return false, "limit"
	end
	if product.offerMaxLevel and level > product.offerMaxLevel then
		return false, "level"
	end
	return true, nil
end

--[[
	Applies a receipt to the purchase record: logs its ID (keeping the newest `logSize`),
	counts the product and adds bought backpack slots (up to `maxBackpackSlots`).
	Returns "duplicate" and no delivery for a receipt already logged.
]]
function Receipts.apply(
	purchases: Purchases,
	product: Types.ProductDef,
	receiptId: string,
	logSize: number,
	maxBackpackSlots: number
): (Decision, Delivery?)
	if Receipts.seen(purchases, receiptId) then
		return "duplicate", nil
	end
	table.insert(purchases.receiptIds, receiptId)
	while #purchases.receiptIds > logSize do
		table.remove(purchases.receiptIds, 1)
	end
	purchases.counts[product.id] = (purchases.counts[product.id] or 0) + 1
	local delivery = Receipts.delivery(product)
	if delivery.backpackSlots > 0 then
		local before = purchases.backpackSlots
		purchases.backpackSlots = math.min(before + delivery.backpackSlots, maxBackpackSlots)
		delivery.backpackSlots = purchases.backpackSlots - before
	end
	return "granted", delivery
end

return Receipts
