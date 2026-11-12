--!strict
--[[
	Receipts: the pure rules behind Robux purchases (ARCHITECTURE.md §6, MVP_LAUNCH v0.1).

	A receipt is granted exactly once. Its ID goes into the profile's receipt log in the
	same change that grants the goods, so a receipt Roblox delivers twice (a retry after
	a crash, a second server) finds its ID and grants nothing. The server confirms the
	receipt to Roblox only after that profile version has saved (Services/Shop).

	Limits gate the offer, never the delivery: once Robux are spent the goods are always
	delivered, even if a race let a capped product through.

	Game passes have no receipts: owning one (checked on join, or a purchase finishing) is
	recorded once with `applyPass`, which is idempotent the same way.
]]

local Types = require("../Types")
local Offers = require("./Offers")
local Unlocks = require("./Unlocks")

local Receipts = {}

export type Purchases = {
	receiptIds: { string }, -- most recent last, capped at the log size
	counts: { [string]: number }, -- purchases per product ID, for limits
	backpackSlots: number, -- backpack slots bought (Backpack Upgrade)
}

-- What a product delivers: items to the inbox, energy, backpack slots, Embers, the Lounge.
export type Delivery = {
	items: { Types.ItemStack },
	energy: number,
	backpackSlots: number,
	embers: number,
	vipLounge: boolean,
}

-- A capped piece on the plot: how many of its chain stand there and its limit now.
export type Placed = { count: number, limit: number }

--[[
	When the shop decides what's on offer: the clock and the first win (the Firestarter Kit),
	and (the flow review's F-12, F-27) the player's progress for a product's unlock gate and
	the capped pieces on their plot, by base piece, for "+1 can be placed" products. Without
	`progress` no gate is checked; without `placed` a capacity product is never offered.
]]
export type OfferContext = {
	now: number,
	firstWinAt: number,
	firstPurchaseHours: number,
	progress: Unlocks.Progress?,
	placed: { [string]: Placed }?,
}

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

--[[
	The inbox rows a purchase's items become. Gear (anything with durability) arrives one
	piece per row at full durability, never merged into a stack, so a second Gunrunner Pack
	is two more guns, each fresh (MVP_LAUNCH: every pack is repurchasable, nothing in one is
	a permanent unlock, and there's no repair).
]]
function Receipts.inboxSlots(items: { Types.ItemStack }, defs: { [string]: Types.ItemDef }): { Types.Slot }
	local slots: { Types.Slot } = {}
	for _, stack in items do
		local def = defs[stack.itemId]
		if def and def.durability then
			for _ = 1, stack.count do
				table.insert(slots, { itemId = stack.itemId, count = 1, durability = def.durability } :: any)
			end
		else
			table.insert(slots, { itemId = stack.itemId, count = stack.count } :: any)
		end
	end
	return slots
end

function Receipts.delivery(product: Types.ProductDef): Delivery
	local result: Delivery = { items = {}, energy = 0, backpackSlots = 0, embers = 0, vipLounge = false }
	for _, grant in product.grants do
		local g: any = grant
		if g.kind == "item" then
			table.insert(result.items, { itemId = g.itemId, count = g.count })
		elseif g.kind == "energy" then
			result.energy += g.amount
		elseif g.kind == "backpackSlots" then
			result.backpackSlots += g.amount
		elseif g.kind == "embers" then
			result.embers += g.amount
		elseif g.kind == "vipLounge" then
			result.vipLounge = true
		end
	end
	return result
end

--[[
	Whether the shop may offer `product` now, and why not: "notListed", "limit", "level", or
	"window" (the Firestarter Kit outside its never-paid, 48 h-after-the-first-win window),
	"locked" (its unlock gate isn't met, F-12) or "notFull" (a capacity product while the plot
	still has room for that piece, F-27).
	Returns when an offer with a countdown ends (0 when it has none).
]]
function Receipts.canOffer(
	product: Types.ProductDef,
	purchases: Purchases,
	level: number,
	context: OfferContext?
): (boolean, string?, number)
	if product.robloxId == 0 then
		return false, "notListed", 0
	end
	local bought = purchases.counts[product.id] or 0
	if product.limit and bought >= product.limit then
		return false, "limit", 0
	end
	if product.offerMaxLevel and level > product.offerMaxLevel then
		return false, "level", 0
	end
	-- F-12: never sell what the player can't use yet (pieces they can't place, parts for
	-- recipes still locked): the card greys with the gate's line instead.
	if product.unlock and context and context.progress and not Unlocks.isMet(product.unlock, context.progress) then
		return false, "locked", 0
	end
	-- F-27: "+1 can be placed" only once the plot holds as many as it may.
	for _, grant in product.grants do
		local g: any = grant
		if g.kind == "pieceSlot" then
			local placed = if context and context.placed then context.placed[g.pieceId] else nil
			if placed == nil or placed.count < placed.limit then
				return false, "notFull", 0
			end
		end
	end
	if product.offer == "firstPurchase" then
		if context == nil then
			return false, "window", 0
		end
		local open, endsAt =
			Offers.firstPurchase(purchases.counts, context.firstWinAt, context.now, context.firstPurchaseHours)
		if not open then
			return false, "window", 0
		end
		return true, nil, endsAt
	end
	return true, nil, 0
end

--[[
	The line a greyed card shows for a product that isn't on offer because of the player's
	progress (F-12, F-27), or nil: "Complete the 'Stand Your Ground' quest" for a gate,
	"Placed 1/2: buy when your plot is full" for a capacity product (or the piece's own
	unlock line while it is still locked).
]]
function Receipts.lockLine(
	product: Types.ProductDef,
	reason: string?,
	context: OfferContext?,
	names: Unlocks.Names,
	pieces: { [string]: { unlock: Types.UnlockGate? } }
): string?
	if reason == "locked" then
		return Unlocks.text(product.unlock, names)
	elseif reason == "notFull" then
		for _, grant in product.grants do
			local g: any = grant
			if g.kind == "pieceSlot" then
				local piece = pieces[g.pieceId]
				local progress = context and context.progress
				if piece and progress and not Unlocks.isMet(piece.unlock, progress) then
					return Unlocks.text(piece.unlock, names)
				end
				local placed = context and context.placed and context.placed[g.pieceId]
				if placed then
					return `Placed {placed.count}/{placed.limit}: buy when your plot is full`
				end
			end
		end
	end
	return nil
end

--[[
	Records a game pass the player owns (bought now, or found on join): counted once, its
	backpack slots added up to `maxBackpackSlots`. Returns the delivery the first time and nil
	when it was already recorded.
]]
function Receipts.applyPass(purchases: Purchases, product: Types.ProductDef, maxBackpackSlots: number): Delivery?
	if (purchases.counts[product.id] or 0) > 0 then
		return nil
	end
	purchases.counts[product.id] = 1
	local delivery = Receipts.delivery(product)
	if delivery.backpackSlots > 0 then
		local before = purchases.backpackSlots
		purchases.backpackSlots = math.min(before + delivery.backpackSlots, maxBackpackSlots)
		delivery.backpackSlots = purchases.backpackSlots - before
	end
	return delivery
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
