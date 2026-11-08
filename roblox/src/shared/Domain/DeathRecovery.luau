--!strict
--[[
	DeathRecovery: getting back up, and getting your things back (LDOE_PARITY #46). Pure.

	- Reanimator (the Ember Heart, flags.reanimator): carried when you fall, one is
	  used up and you revive in place at Tuning.deathRecovery.reanimatorHealth;
	  nothing drops.
	- "Recover all" on the death screen: the whole drop goes to the inbox. By
	  rewarded ad recoverAllAdsPerDay times a UTC day, or by premium (S3). Only
	  the owner, and only while the drop still exists (Lobby.recoverAll).
	- Death-milestone gifts: crossing a milestone's death count sends its items to
	  the inbox.
	- The Doormat (flags.respawnPoint) sets where you respawn at home; slice 1b
	  wires the respawn itself.
]]

local Types = require("../Types")
local Inventory = require("./Inventory")

local DeathRecovery = {}

export type Config = Types.DeathRecoveryTuning
export type ItemLookup = { [string]: { flags: { [string]: boolean }? } }
export type DailyState = { day: number, used: number }
export type Method = "ad" | "premium"

local DAY = 24 * 60 * 60

-- The first Reanimator carried, if any.
function DeathRecovery.reanimatorIn(inventory: Types.Inventory, items: ItemLookup): Types.ItemId?
	for _, container in { inventory.pockets, inventory.backpack } do
		for _, slot in container do
			local item = items[slot.itemId]
			if slot.count > 0 and item and item.flags and item.flags.reanimator then
				return slot.itemId
			end
		end
	end
	return nil
end

-- Uses up one Reanimator: the new inventory, or nil when none is carried.
function DeathRecovery.useReanimator(inventory: Types.Inventory, items: ItemLookup): Types.Inventory?
	local itemId = DeathRecovery.reanimatorIn(inventory, items)
	if itemId == nil then
		return nil
	end
	return Inventory.remove(inventory, itemId, 1)
end

-- Whether "Recover all" is allowed by `method` today.
function DeathRecovery.canRecoverAll(state: DailyState, method: Method, now: number, config: Config): boolean
	if method == "premium" then
		return true
	end
	local used = if state.day == now // DAY then state.used else 0
	return used < config.recoverAllAdsPerDay
end

function DeathRecovery.useRecoverAll(state: DailyState, now: number): DailyState
	local today = now // DAY
	return { day = today, used = (if state.day == today then state.used else 0) + 1 }
end

-- The gifts for going from `before` deaths to `after`, in milestone order.
function DeathRecovery.milestoneGifts(before: number, after: number, config: Config): { Types.ItemStack }
	local gifts: { Types.ItemStack } = {}
	for _, milestone in config.milestones do
		if before < milestone.deaths and after >= milestone.deaths then
			for _, stack in milestone.items do
				table.insert(gifts, { itemId = stack.itemId, count = stack.count })
			end
		end
	end
	return gifts
end

return DeathRecovery
