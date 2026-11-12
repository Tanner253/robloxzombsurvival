--!strict
--[[
	Gear: what worn armor and the equipped bag add up to (docs/CONTENT_2_0.md §4). Pure.

	- Defense sums over the four armor slots (head, body, legs, feet); the hit's reduction is
	  LDoE's defense / (defense + armorConstant) (Domain/Combat.armorReduction). A helmet, a
	  gas mask and a set cap all sit in the head slot, so the head is a choice: defense
	  (Combat Helmet 7) or fog (Gas Mask 0.35).
	- The backpack holds the base slots, the equipped bag's slots and any bought, never more
	  than Tuning.inventory.maxBackpackSlots.
	- Armor level is the item's tier: Reedweave 1, Padded 2, Hidebound 3, Riveted and the
	  Plate Carrier 4.
]]

local Types = require("../Types")
local Combat = require("./Combat")

local Gear = {}

export type ItemLookup = { [string]: Types.ItemDef }
export type Equipment = { [string]: Types.Slot }

Gear.ARMOR_SLOTS = { "head", "body", "legs", "feet" } :: { string }

-- The armor item worn in `key`, if any.
local function worn(equipment: Equipment, items: ItemLookup, key: string): Types.ItemDef?
	local slot = equipment[key]
	local item = if slot and slot.count > 0 then items[slot.itemId] else nil
	return if item and item.armor then item else nil
end

-- Total defense of the armor worn.
function Gear.defense(equipment: Equipment, items: ItemLookup): number
	local total = 0
	for _, key in Gear.ARMOR_SLOTS do
		local item = worn(equipment, items, key)
		if item then
			total += (item.armor :: Types.ArmorStats).defense
		end
	end
	return total
end

-- The share of a hit the worn armor takes off.
function Gear.reduction(equipment: Equipment, items: ItemLookup, armorConstant: number): number
	return Combat.armorReduction(Gear.defense(equipment, items), armorConstant)
end

-- The armor level shown on a piece: its tier (nil for anything that isn't armor).
function Gear.armorLevel(item: Types.ItemDef): number?
	return if item.armor then item.tier else nil
end

-- Backpack slots: the base, the equipped bag and the slots bought, capped at `maxSlots`.
function Gear.backpackSlots(base: number, bag: Types.ItemDef?, bought: number, maxSlots: number): number
	local fromBag = if bag and bag.bagSlots then bag.bagSlots else 0
	return math.min(base + fromBag + bought, maxSlots)
end

return Gear
