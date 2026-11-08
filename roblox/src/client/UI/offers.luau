--!strict
--[[
	offers: the shortfall slots the shop fills in later (S3; DECISIONS 2026-11-08). Nothing
	is sold here. Each field is nil until the shop sets it; components show their
	button only when it is set, so the layouts already leave room for:
	- fillUp(stacks): "Fill up" beside have/need in the craft, build and upgrade panels
	- speedUp(uid, index): "Speed up" on a station's queue rows
	- forNotice(text): an offer on the "bag full" toast and on storage/placement limits
	- buyEnergy(): the Energy Refill product, for the travel panel when Energy is short
	- openShop(productId?): the shop, e.g. from the inventory's currency "+"
	Controllers/Shop sets fillUp (it opens the shop on the Resource Pack), buyEnergy and
	openShop for v0.1 (MVP_LAUNCH).
]]

export type Offer = { label: string, onActivated: () -> () }

local offers = {
	fillUp = nil :: ((stacks: { { itemId: string, count: number } }) -> ())?,
	speedUp = nil :: ((uid: string, index: number) -> ())?,
	forNotice = nil :: ((text: string) -> Offer?)?,
	buyEnergy = nil :: (() -> ())?,
	openShop = nil :: ((productId: string?) -> ())?,
}

return offers
