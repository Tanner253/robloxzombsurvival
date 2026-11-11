--!strict
--[[
	offers: the shortfall slots the shop fills in later (S3; DECISIONS 2026-11-08). Nothing
	is sold here. Each field is nil until the shop sets it; components show their
	button only when it is set, so the layouts already leave room for:
	- fillUp(stacks): "Fill up" beside have/need in the craft, build and upgrade panels
	- speedUp(uid, index): "Speed up" on a station's queue rows
	- forNotice(text): an offer on the "bag full" toast and on storage/placement limits
	- buyEnergy(shortfall?): the Energy Refill product, for the travel panel when Energy is short
	- energyChip(shortfall): what that slot shows (name, live price, the shortfall)
	- openShop(productId?): the shop, e.g. from the inventory's currency "+"
	- gear(): the Scavenger's Kit, for the death screen and after a weapon breaks
	- gearChip(): what the death screen's chip shows (name, live price)
	- buyEmbers(shortfall): the Ember Pouch, for "Recover all" pressed short of Embers (F-09)
	Controllers/Shop sets them for v0.1 (MVP_LAUNCH Monetization v0.1): Fill up asks to buy
	the shortfall with Embers, forNotice puts "View offer" on the bag-full and broken-weapon
	toasts (once a day each), gear and buyEnergy prompt their product.

	The death screen and the Fog map (the flow review's F-08, screens/RunHud and FogMap) call `gearChip()` and
	`energyChip(shortfall)` while rendering, show nothing when they return nil (not on offer,
	or the shop hasn't synced), and call `gear()` / `buyEnergy(shortfall)` on the press. The
	server's "energyShort" effect puts the latest shortfall in State.ui().energyShort.
]]

export type Offer = { label: string, onActivated: () -> () }

-- A product slot as a screen shows it: the product, its card name, the live price in Robux
-- and a short line ("+100 Energy, 12 short"). `available` is the server's word that it is
-- on offer to this player now.
export type ProductChip = {
	productId: string,
	name: string,
	price: number,
	line: string,
	available: boolean,
}

local offers = {
	fillUp = nil :: ((stacks: { { itemId: string, count: number } }) -> ())?,
	speedUp = nil :: ((uid: string, index: number) -> ())?,
	forNotice = nil :: ((text: string) -> Offer?)?,
	buyEnergy = nil :: ((shortfall: number?) -> ())?,
	energyChip = nil :: ((shortfall: number) -> ProductChip?)?,
	openShop = nil :: ((productId: string?) -> ())?,
	gear = nil :: (() -> ())?,
	gearChip = nil :: (() -> ProductChip?)?,
	buyEmbers = nil :: ((shortfall: number) -> ())?,
}

return offers
