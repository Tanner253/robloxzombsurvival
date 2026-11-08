--!strict
--[[
	Inventory: pure slot-container math for pockets and backpack (ARCHITECTURE.md §1.3).

	A container is a dense array of slots; an empty slot is { itemId = "", count = 0 }.
	Every function is pure: it returns a new state and never mutates its input, so a
	service can compute a change, check it, and commit it in one step.

	Fill order for `add`: top up existing stacks (pockets, then backpack), then fill
	empty slots (pockets, then backpack).
	Take order for `remove`: backpack first, then pockets, last slot first, so the
	quick-use pocket items are spent last.
]]

local Types = require("../Types")

export type Slot = Types.Slot
export type Container = Types.Container
export type Inventory = Types.Inventory

-- The item fields Inventory needs; Data/Items satisfies this.
export type ItemLookup = { [string]: { stackSize: number, durability: number? } }

local Inventory = {}

local EMPTY_ID = ""

local function assertCount(count: number)
	assert(count >= 1 and count % 1 == 0, "count must be a positive integer")
end

local function copyContainer(container: Container): Container
	local copy = table.create(#container) :: Container
	for index, slot in container do
		copy[index] = { itemId = slot.itemId, count = slot.count, durability = slot.durability }
	end
	return copy
end

local function copyInventory(inventory: Inventory): Inventory
	return { pockets = copyContainer(inventory.pockets), backpack = copyContainer(inventory.backpack) }
end

function Inventory.emptySlot(): Slot
	return { itemId = EMPTY_ID, count = 0 }
end

function Inventory.isEmpty(slot: Slot): boolean
	return slot.count <= 0
end

function Inventory.newContainer(capacity: number): Container
	local container = table.create(capacity) :: Container
	for index = 1, capacity do
		container[index] = Inventory.emptySlot()
	end
	return container
end

function Inventory.new(pocketSlots: number, backpackSlots: number): Inventory
	return { pockets = Inventory.newContainer(pocketSlots), backpack = Inventory.newContainer(backpackSlots) }
end

-- Total units of `itemId` across pockets and backpack.
function Inventory.count(inventory: Inventory, itemId: string): number
	local total = 0
	for _, container: Container in { inventory.pockets, inventory.backpack } do
		for _, slot in container do
			if slot.itemId == itemId then
				total += slot.count
			end
		end
	end
	return total
end

-- How many more units of `itemId` would fit.
function Inventory.spaceFor(inventory: Inventory, itemId: string, items: ItemLookup): number
	local def = items[itemId]
	assert(def, `unknown item '{itemId}'`)
	local space = 0
	for _, container: Container in { inventory.pockets, inventory.backpack } do
		for _, slot in container do
			if Inventory.isEmpty(slot) then
				space += def.stackSize
			elseif slot.itemId == itemId then
				space += math.max(0, def.stackSize - slot.count)
			end
		end
	end
	return space
end

--[[
	Adds `count` units of `itemId`. Returns the new inventory and the number of
	units that did not fit (0 when everything fit). The input is not modified.
]]
function Inventory.add(inventory: Inventory, itemId: string, count: number, items: ItemLookup): (Inventory, number)
	assertCount(count)
	local def = items[itemId]
	assert(def, `unknown item '{itemId}'`)

	local result = copyInventory(inventory)
	local remaining = count
	local sections: { Container } = { result.pockets, result.backpack }

	-- Pass 1: top up partial stacks of the same item.
	if def.stackSize > 1 then
		for _, container in sections do
			for _, slot in container do
				if remaining == 0 then
					break
				end
				if slot.itemId == itemId and slot.count < def.stackSize then
					local moved = math.min(remaining, def.stackSize - slot.count)
					slot.count += moved
					remaining -= moved
				end
			end
		end
	end

	-- Pass 2: fill empty slots.
	for _, container in sections do
		for index, slot in container do
			if remaining == 0 then
				break
			end
			if Inventory.isEmpty(slot) then
				local moved = math.min(remaining, def.stackSize)
				container[index] = { itemId = itemId, count = moved, durability = def.durability }
				remaining -= moved
			end
		end
	end

	return result, remaining
end

--[[
	Adds the contents of an existing slot, keeping its durability. Stackable items
	go through `add`; an item with its own durability (worn gear) takes the first
	empty slot as-is, so moving it never repairs it. Returns the new inventory and
	the number of units that did not fit.
]]
function Inventory.addSlot(inventory: Inventory, slot: Slot, items: ItemLookup): (Inventory, number)
	if slot.durability == nil then
		return Inventory.add(inventory, slot.itemId, slot.count, items)
	end
	assertCount(slot.count)
	local result = copyInventory(inventory)
	for _, container: Container in { result.pockets, result.backpack } do
		for index, existing in container do
			if Inventory.isEmpty(existing) then
				container[index] = { itemId = slot.itemId, count = slot.count, durability = slot.durability }
				return result, 0
			end
		end
	end
	return inventory, slot.count
end

--[[
	Removes exactly `count` units of `itemId`. Returns the new inventory, or nil
	if there are not enough (the input is never partially changed).
]]
function Inventory.remove(inventory: Inventory, itemId: string, count: number): Inventory?
	assertCount(count)
	if Inventory.count(inventory, itemId) < count then
		return nil
	end

	local result = copyInventory(inventory)
	local remaining = count
	for _, container: Container in { result.backpack, result.pockets } do
		for index = #container, 1, -1 do
			if remaining == 0 then
				break
			end
			local slot = container[index]
			if slot.itemId == itemId then
				local taken = math.min(remaining, slot.count)
				remaining -= taken
				if taken == slot.count then
					container[index] = Inventory.emptySlot()
				else
					slot.count -= taken
				end
			end
		end
	end
	return result
end

-- Sums a list of stacks by item, so duplicate entries are counted together.
local function totals(stacks: { Types.ItemStack }): { [string]: number }
	local sums: { [string]: number } = {}
	for _, stack in stacks do
		sums[stack.itemId] = (sums[stack.itemId] or 0) + stack.count
	end
	return sums
end

-- True when the inventory holds every stack in `stacks` (for example recipe inputs).
function Inventory.hasAll(inventory: Inventory, stacks: { Types.ItemStack }): boolean
	for itemId, needed in totals(stacks) do
		if Inventory.count(inventory, itemId) < needed then
			return false
		end
	end
	return true
end

-- Removes every stack in `stacks` atomically. Returns nil if any is missing.
function Inventory.removeAll(inventory: Inventory, stacks: { Types.ItemStack }): Inventory?
	if not Inventory.hasAll(inventory, stacks) then
		return nil
	end
	local result = inventory
	for itemId, needed in totals(stacks) do
		result = Inventory.remove(result, itemId, needed) :: Inventory
	end
	return result
end

--[[
	Changes the backpack size. Growing always works. Shrinking only works when the
	removed slots are empty; otherwise returns nil.
]]
function Inventory.setBackpackCapacity(inventory: Inventory, capacity: number): Inventory?
	assert(capacity >= 0 and capacity % 1 == 0, "capacity must be a non-negative integer")
	local result = copyInventory(inventory)
	local backpack = result.backpack
	for index = #backpack, capacity + 1, -1 do
		if not Inventory.isEmpty(backpack[index]) then
			return nil
		end
		backpack[index] = nil :: any
	end
	for index = #backpack + 1, capacity do
		backpack[index] = Inventory.emptySlot()
	end
	return result
end

return Inventory
