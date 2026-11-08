--!strict
--[[
	Hands: the two weapon slots, LDoE-style (GAME_DESIGN "PC controls"; checklist
	4.9). There is no 1-9 hotbar.

	- Two slots, filled from the equipment paper-doll (primary and secondary).
	  1 and 2 select a slot, F (or the swap button) swaps. Tools never take a slot:
	  gathering auto-equips them from the bag.
	- A swap raises the other weapon over its swapSeconds (WeaponStats.swapSeconds,
	  else Tuning.hands.swapSeconds). Nothing fires or swings until it is up, and
	  swapping away cancels a reload in progress.
	- Each slot keeps its own magazine: rounds stay in a gun you swap away from.
	  When the paper-doll changes what a slot holds, the old gun's rounds go back
	  to the bag (`sync` returns them) and a newly slotted gun starts empty.
	- The meds button (H) uses the best healing item carried (`bestMeds`): the
	  smallest heal that covers the missing health, else the biggest there is.
	  "Meds" are consumables whose health restore is their largest effect, so the
	  button never eats your stew.

	The state is a plain record the Combat service keeps per player. Pure.
]]

local Types = require("../Types")
local Combat = require("./Combat")

local Hands = {}

export type Config = Types.HandsTuning

export type Hand = {
	itemId: string, -- "" when the slot is empty (fists)
	gun: Combat.Gun?, -- firearms only: this slot's magazine
}

export type State = {
	active: number, -- 1 or 2
	hands: { Hand },
	swapEndsAt: number?, -- set while the active weapon is coming up
}

export type ItemLookup = {
	[string]: {
		category: Types.ItemCategory,
		weapon: Types.WeaponStats?,
		consume: Types.ConsumeEffect?,
		tool: Types.ToolStats?,
	},
}
export type SelectReason = "badSlot" | "same"

local function handFor(itemId: string?, items: ItemLookup): Hand
	local id = itemId or ""
	local item = items[id]
	local weapon = item and item.weapon
	return { itemId = id, gun = if weapon and weapon.firearm then Combat.newGun(0) else nil }
end

-- Fresh hands for the slotted weapon IDs (index 1 and 2; nil or "" for empty).
function Hands.new(itemIds: { string? }, items: ItemLookup, config: Config): State
	local hands: { Hand } = {}
	for index = 1, config.slots do
		hands[index] = handFor(itemIds[index], items)
	end
	return { active = 1, hands = hands, swapEndsAt = nil }
end

--[[
	Matches the hands to what the paper-doll holds now. A slot whose weapon
	changed gives its loaded rounds back (as ammo stacks for the bag) and starts
	over. Returns the new state and the rounds to return.
]]
function Hands.sync(state: State, itemIds: { string? }, items: ItemLookup, config: Config): (State, { Types.ItemStack })
	local returned: { Types.ItemStack } = {}
	local hands: { Hand } = {}
	for index = 1, config.slots do
		local id = itemIds[index] or ""
		local current = state.hands[index]
		if current and current.itemId == id then
			hands[index] = current
		else
			if current and current.gun and current.gun.loaded > 0 then
				local old = items[current.itemId]
				local ammo = old and old.weapon and old.weapon.ammoItemId
				if ammo then
					table.insert(returned, { itemId = ammo, count = current.gun.loaded })
				end
			end
			hands[index] = handFor(id, items)
		end
	end
	return { active = state.active, hands = hands, swapEndsAt = state.swapEndsAt }, returned
end

-- The active slot's hand.
function Hands.active(state: State): Hand
	return state.hands[state.active]
end

--[[
	The active weapon's stats, or nil for bare fists. A tool in the slot swings as
	weak melee (LDOE_PARITY #34) when `melee` (Tuning.melee) is given.
]]
function Hands.weapon(state: State, items: ItemLookup, melee: Types.MeleeTuning?): Types.WeaponStats?
	local item = items[Hands.active(state).itemId]
	if item and item.weapon then
		return item.weapon
	end
	if item and melee then
		return Combat.toolWeapon(item, melee)
	end
	return nil
end

--[[
	LDOE_PARITY #45: the active weapon just broke. Switches to the other slot if it
	holds anything, else stays on bare fists. Returns the new state and the slot
	switched to (nil when it fell back to fists).
]]
function Hands.onBreak(state: State, now: number, items: ItemLookup, config: Config): (State, number?)
	local hands = table.clone(state.hands)
	hands[state.active] = { itemId = "", gun = nil }
	local broken: State = { active = state.active, hands = hands, swapEndsAt = state.swapEndsAt }
	local other = if state.active == 1 then 2 else 1
	local spare = hands[other]
	if spare and spare.itemId ~= "" then
		local switched = Hands.select(broken, other, now, items, config)
		return switched, other
	end
	return broken, nil
end

-- Seconds to raise a weapon (bare fists come up at the default).
function Hands.swapSeconds(weapon: Types.WeaponStats?, config: Config): number
	if weapon and weapon.swapSeconds ~= nil then
		return weapon.swapSeconds
	end
	return config.swapSeconds
end

-- Whether the active weapon is up (not mid-swap).
function Hands.ready(state: State, now: number): boolean
	return state.swapEndsAt == nil or now >= state.swapEndsAt
end

--[[
	Selects slot `index` (the 1 and 2 keys). Raising it takes its swapSeconds, and
	the slot being lowered drops any reload in progress. Selecting the active slot
	changes nothing.
]]
function Hands.select(
	state: State,
	index: number,
	now: number,
	items: ItemLookup,
	config: Config
): (State, SelectReason?)
	if index % 1 ~= 0 or index < 1 or index > config.slots then
		return state, "badSlot"
	end
	if index == state.active then
		return state, "same"
	end
	local hands = table.clone(state.hands)
	local lowered = hands[state.active]
	if lowered and lowered.gun and lowered.gun.reloadEndsAt then
		hands[state.active] = { itemId = lowered.itemId, gun = Combat.cancelReload(lowered.gun) }
	end
	local raised = items[hands[index].itemId]
	local seconds = Hands.swapSeconds(raised and raised.weapon, config)
	return { active = index, hands = hands, swapEndsAt = now + seconds }, nil
end

-- F or the swap button: the other slot.
function Hands.swap(state: State, now: number, items: ItemLookup, config: Config): (State, SelectReason?)
	local other = if state.active == 1 then 2 else 1
	return Hands.select(state, other, now, items, config)
end

-- Replaces the active slot's magazine state (after a shot or a reload).
function Hands.setGun(state: State, gun: Combat.Gun): State
	local hands = table.clone(state.hands)
	local hand = hands[state.active]
	hands[state.active] = { itemId = hand.itemId, gun = gun }
	return { active = state.active, hands = hands, swapEndsAt = state.swapEndsAt }
end

-- Every loaded round across both slots, as ammo stacks (unloaded when a run ends).
function Hands.loadedRounds(state: State, items: ItemLookup): { Types.ItemStack }
	local stacks: { Types.ItemStack } = {}
	for _, hand in state.hands do
		local item = items[hand.itemId]
		local ammo = item and item.weapon and item.weapon.ammoItemId
		if hand.gun and hand.gun.loaded > 0 and ammo then
			table.insert(stacks, { itemId = ammo, count = hand.gun.loaded })
		end
	end
	return stacks
end

-- Meds button ------------------------------------------------------------------------------

-- Whether an item is a healing item for the meds button.
function Hands.isMeds(item: { category: Types.ItemCategory, consume: Types.ConsumeEffect? }?): boolean
	if item == nil or item.category ~= "consumable" or item.consume == nil then
		return false
	end
	local effect = item.consume
	local health = effect.health or 0
	return health > 0 and health >= math.max(effect.hunger or 0, effect.thirst or 0, effect.energy or 0)
end

-- How many healing items are carried (the count on the meds button).
function Hands.medsCount(inventory: Types.Inventory, items: ItemLookup): number
	local total = 0
	for _, container in { inventory.pockets, inventory.backpack } do
		for _, slot in container do
			if slot.count > 0 and Hands.isMeds(items[slot.itemId]) then
				total += slot.count
			end
		end
	end
	return total
end

--[[
	The healing item the meds button uses for `missing` health: the smallest heal
	that covers it, else the biggest one carried. Nil when there are none (or
	nothing is missing).
]]
function Hands.bestMeds(inventory: Types.Inventory, items: ItemLookup, missing: number): Types.ItemId?
	if missing <= 0 then
		return nil
	end
	local covering: Types.ItemId?, coveringHeal = nil, math.huge
	local biggest: Types.ItemId?, biggestHeal = nil, 0
	for _, container in { inventory.pockets, inventory.backpack } do
		for _, slot in container do
			local item = items[slot.itemId]
			if slot.count > 0 and Hands.isMeds(item) then
				local heal = ((item :: any).consume.health or 0) :: number
				if heal >= missing and heal < coveringHeal then
					covering, coveringHeal = slot.itemId, heal
				end
				if heal > biggestHeal then
					biggest, biggestHeal = slot.itemId, heal
				end
			end
		end
	end
	return covering or biggest
end

return Hands
