--!strict
--[[
	Slots: moves between any two slot containers (pockets, backpack, equipment,
	storage crates, the locked stash). Pure; every function returns new
	containers and never mutates its input.

	Move rules (drag one slot onto another):
	- onto an empty slot: moves `count` (default the whole stack);
	- onto the same item: merges up to the stack size;
	- onto a different item: swaps, but only when moving the whole stack;
	- an equipment slot only takes items whose ItemDef.equipSlot matches it, one at a time.

	Equipment is saved as a record (PlayerSchema.Equipment); `fromEquipment` and
	`toEquipment` convert it to a container in EQUIP_ORDER and back.
]]

local Types = require("../Types")

local Slots = {}

export type Slot = Types.Slot
export type Container = Types.Container

-- The item fields Slots needs; Data/Items satisfies this.
export type ItemLookup = {
	[string]: { stackSize: number, durability: number?, equipSlot: Types.EquipSlot?, category: Types.ItemCategory? },
}

export type Reason = "empty" | "badSlot" | "same" | "wrongSlot" | "noSpace" | "count"

-- Equipment slot order; also the slot indices clients send for "equipment".
-- weapon is the primary and weapon2 the secondary weapon (checklist 4.9: LDoE's two
-- weapon slots); both take items whose equipSlot is "weapon".
Slots.EQUIP_ORDER = { "head", "body", "legs", "feet", "weapon", "weapon2", "bag" } :: { Types.EquipSlot }

-- Categories "Put all" leaves in the inventory: gear, food and ammo stay with you.
Slots.KEEP_ON_PUT_ALL = {
	tool = true,
	weapon = true,
	armor = true,
	bag = true,
	consumable = true,
	ammo = true,
} :: { [string]: boolean }

local function empty(): Slot
	return { itemId = "", count = 0 }
end

local function isEmpty(slot: Slot): boolean
	return slot.count <= 0
end

local function copySlot(slot: Slot): Slot
	return { itemId = slot.itemId, count = slot.count, durability = slot.durability }
end

local function copyContainer(container: Container): Container
	local copy = table.create(#container) :: Container
	for index, slot in container do
		copy[index] = copySlot(slot)
	end
	return copy
end

-- One side of a move: a container and, for equipment, which slot type each index takes.
export type Side = {
	slots: Container,
	accepts: { Types.EquipSlot }?, -- per index; nil means any item
}

local function accepts(side: Side, index: number, slot: Slot, items: ItemLookup): boolean
	if isEmpty(slot) or side.accepts == nil then
		return true
	end
	local wanted = side.accepts[index]
	local def = items[slot.itemId]
	return def ~= nil and def.equipSlot == wanted and slot.count == 1
end

--[[
	Moves `count` units (default all) from `from.slots[fromIndex]` to
	`to.slots[toIndex]`. Pass the same Side twice for a move inside one container.
	Returns the new source and destination containers (the same table when it is
	one container), or nil, nil and a reason.
]]
function Slots.move(
	from: Side,
	fromIndex: number,
	to: Side,
	toIndex: number,
	count: number?,
	items: ItemLookup
): (Container?, Container?, Reason?)
	local source = from.slots[fromIndex]
	local target = to.slots[toIndex]
	if source == nil or target == nil then
		return nil, nil, "badSlot"
	end
	if isEmpty(source) then
		return nil, nil, "empty"
	end
	local sameContainer = from.slots == to.slots
	if sameContainer and fromIndex == toIndex then
		return nil, nil, "same"
	end
	local amount = count or source.count
	if amount < 1 or amount % 1 ~= 0 or amount > source.count then
		return nil, nil, "count"
	end
	local def = items[source.itemId]
	if def == nil then
		return nil, nil, "badSlot"
	end

	local moving: Slot = { itemId = source.itemId, count = amount, durability = source.durability }
	if not accepts(to, toIndex, moving, items) then
		return nil, nil, "wrongSlot"
	end

	local newFrom = copyContainer(from.slots)
	local newTo = if sameContainer then newFrom else copyContainer(to.slots)
	local src = newFrom[fromIndex]
	local dst = newTo[toIndex]

	if isEmpty(dst) then
		newTo[toIndex] = moving
		if amount == src.count then
			newFrom[fromIndex] = empty()
		else
			src.count -= amount
		end
		return newFrom, newTo, nil
	end

	if dst.itemId == src.itemId and def.stackSize > 1 and dst.durability == nil and src.durability == nil then
		local space = def.stackSize - dst.count
		if space <= 0 then
			return nil, nil, "noSpace"
		end
		local moved = math.min(space, amount)
		dst.count += moved
		if moved == src.count then
			newFrom[fromIndex] = empty()
		else
			src.count -= moved
		end
		return newFrom, newTo, nil
	end

	-- Different items (or unstackable): swap whole stacks only.
	if amount ~= src.count then
		return nil, nil, "noSpace"
	end
	if not accepts(from, fromIndex, dst, items) then
		return nil, nil, "wrongSlot"
	end
	newFrom[fromIndex], newTo[toIndex] = copySlot(dst), copySlot(src)
	return newFrom, newTo, nil
end

-- Splits half a stack (rounded down) into the first empty slot of the same container.
function Slots.split(container: Container, index: number): (Container?, Reason?)
	local slot = container[index]
	if slot == nil then
		return nil, "badSlot"
	end
	if slot.count < 2 then
		return nil, "count"
	end
	for target, other in container do
		if isEmpty(other) then
			local result = copyContainer(container)
			local half = math.floor(slot.count / 2)
			result[index].count -= half
			result[target] = { itemId = slot.itemId, count = half, durability = slot.durability }
			return result, nil
		end
	end
	return nil, "noSpace"
end

--[[
	Adds one slot's contents across `containers` in order: first tops up partial
	stacks of the same item in every container, then fills empty slots. Worn
	gear (with durability) only takes an empty slot, keeping its durability.
	Returns the new containers and the units that did not fit.
]]
function Slots.addTo(containers: { Container }, slot: Slot, items: ItemLookup): ({ Container }, number)
	local def = items[slot.itemId]
	assert(def, `unknown item '{slot.itemId}'`)
	local result: { Container } = {}
	for index, container in containers do
		result[index] = copyContainer(container)
	end
	local remaining = slot.count
	if slot.durability == nil and def.stackSize > 1 then
		for _, container in result do
			for _, existing in container do
				if remaining == 0 then
					break
				end
				if existing.itemId == slot.itemId and existing.durability == nil and existing.count < def.stackSize then
					local moved = math.min(remaining, def.stackSize - existing.count)
					existing.count += moved
					remaining -= moved
				end
			end
		end
	end
	for _, container in result do
		for index, existing in container do
			if remaining == 0 then
				break
			end
			if isEmpty(existing) then
				local moved = if slot.durability ~= nil then remaining else math.min(remaining, def.stackSize)
				container[index] = { itemId = slot.itemId, count = moved, durability = slot.durability }
				remaining -= moved
			end
		end
	end
	return result, remaining
end

--[[
	Moves every slot of `sources` that passes `filter` into `targets` (as far as
	it fits; leftovers stay where they were). Returns the new sources, the new
	targets and the number of units moved. Used for Take all and Put all.
]]
function Slots.transfer(
	sources: { Container },
	targets: { Container },
	items: ItemLookup,
	filter: ((slot: Slot) -> boolean)?
): ({ Container }, { Container }, number)
	local newSources: { Container } = {}
	for index, container in sources do
		newSources[index] = copyContainer(container)
	end
	local newTargets = targets
	local moved = 0
	for _, container in newSources do
		for index, slot in container do
			if not isEmpty(slot) and (filter == nil or filter(slot)) then
				local after, left = Slots.addTo(newTargets, slot, items)
				local taken = slot.count - left
				if taken > 0 then
					newTargets = after
					moved += taken
					if left == 0 then
						container[index] = empty()
					else
						slot.count = left
					end
				end
			end
		end
	end
	return newSources, newTargets, moved
end

-- The "Put all" filter: everything except gear, food and ammo.
function Slots.putAllFilter(items: ItemLookup): (slot: Slot) -> boolean
	return function(slot: Slot): boolean
		local def = items[slot.itemId]
		if def == nil then
			return false
		end
		local category: string = def.category or "misc"
		return not Slots.KEEP_ON_PUT_ALL[category]
	end
end

-- Equipment record -> container in EQUIP_ORDER.
-- Category order for Slots.sort: tools and weapons first, junk last.
local SORT_ORDER: { [string]: number } = {
	tool = 1,
	weapon = 2,
	ammo = 3,
	armor = 4,
	bag = 5,
	consumable = 6,
	medical = 7,
	resource = 8,
	component = 9,
	blueprint = 10,
	junk = 11,
}

--[[
	Sorts a container (the Sort button): merges partial stacks of the same item,
	then orders by category, item id and remaining durability, empties last. Worn
	items keep their own durability. Returns a new container of the same size.
]]
function Slots.sort(container: Container, items: ItemLookup): Container
	local merged: { Slot } = {}
	local open: { [string]: Slot } = {}
	for _, slot in container do
		if isEmpty(slot) then
			continue
		end
		local def = items[slot.itemId]
		local stackSize = if def then def.stackSize else 1
		if slot.durability == nil and stackSize > 1 then
			local left = slot.count
			while left > 0 do
				local partial = open[slot.itemId]
				if partial == nil then
					partial = { itemId = slot.itemId, count = 0, durability = nil } :: Slot
					table.insert(merged, partial)
					open[slot.itemId] = partial
				end
				local add = math.min(left, stackSize - partial.count)
				partial.count += add
				left -= add
				if partial.count >= stackSize then
					open[slot.itemId] = nil
				end
			end
		else
			table.insert(merged, copySlot(slot))
		end
	end
	local function rank(slot: Slot): number
		local def = items[slot.itemId] :: any
		return if def and def.category then SORT_ORDER[def.category] or 99 else 99
	end
	table.sort(merged, function(a: Slot, b: Slot): boolean
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		elseif a.itemId ~= b.itemId then
			return a.itemId < b.itemId
		elseif a.count ~= b.count then
			return a.count > b.count
		end
		return (a.durability or 0) > (b.durability or 0)
	end)
	local result: Container = {}
	for index = 1, #container do
		result[index] = merged[index] or empty()
	end
	return result
end

function Slots.fromEquipment(equipment: { [string]: Slot }): Container
	local container: Container = {}
	for index, name in Slots.EQUIP_ORDER do
		container[index] = copySlot(equipment[name] or empty())
	end
	return container
end

-- Container in EQUIP_ORDER -> equipment record.
function Slots.toEquipment(container: Container): { [string]: Slot }
	local equipment: { [string]: Slot } = {}
	for index, name in Slots.EQUIP_ORDER do
		equipment[name] = copySlot(container[index] or empty())
	end
	return equipment
end

-- The `accepts` list for an equipment Side.
function Slots.equipmentAccepts(): { Types.EquipSlot }
	local list = table.clone(Slots.EQUIP_ORDER)
	for index, name in list do
		if name == "weapon2" then
			list[index] = "weapon"
		end
	end
	return list
end

-- Wears a slot by `amount` durability. Returns the new slot and whether it broke
-- (a broken item leaves an empty slot). Items without durability are unchanged.
function Slots.wear(slot: Slot, amount: number): (Slot, boolean)
	if slot.durability == nil or isEmpty(slot) then
		return copySlot(slot), false
	end
	local left = slot.durability - amount
	if left <= 0 then
		return empty(), true
	end
	return { itemId = slot.itemId, count = slot.count, durability = left }, false
end

return Slots
