--!strict
--[[
	Inbox: the item inbox's pure rules (PLAYER_EXPERIENCE_CHECKLIST 4.15).

	Level-up, quest, purchase and event rewards, and anything that doesn't fit the
	bag, land here instead of being lost or dropped. There is no capacity limit.
	Stackable items (no durability) merge into an existing row with the same item and
	source; items with durability keep a row each. Rows are taken (into the bag) or,
	for consumables, used in place.
]]

local Types = require("../Types")

local Inbox = {}

export type Entry = Types.InboxEntry

-- Adds stacks or slots from `source`. Returns the new rows and the next sequence number.
function Inbox.add(
	entries: { Entry },
	seq: number,
	slots: { Types.Slot },
	source: string,
	now: number
): ({ Entry }, number)
	local result = table.clone(entries)
	for _, slot in slots do
		if slot.count <= 0 or slot.itemId == "" then
			continue
		end
		local merged = false
		if slot.durability == nil then
			for index, entry in result do
				if entry.itemId == slot.itemId and entry.source == source and entry.durability == nil then
					local fresh = table.clone(entry)
					fresh.count += slot.count
					fresh.at = now
					result[index] = fresh
					merged = true
					break
				end
			end
		end
		if not merged then
			seq += 1
			table.insert(result, {
				id = `i{seq}`,
				itemId = slot.itemId,
				count = slot.count,
				durability = slot.durability,
				source = source,
				at = now,
			})
		end
	end
	return result, seq
end

-- The position of a row by id, or nil.
function Inbox.indexOf(entries: { Entry }, id: string): number?
	for index, entry in entries do
		if entry.id == id then
			return index
		end
	end
	return nil
end

-- The rows with row `id` set to `count` (0 removes it). Unknown ids change nothing.
function Inbox.withCount(entries: { Entry }, id: string, count: number): { Entry }
	local index = Inbox.indexOf(entries, id)
	if index == nil then
		return entries
	end
	local result = table.clone(entries)
	if count <= 0 then
		table.remove(result, index)
	else
		local fresh = table.clone(result[index])
		fresh.count = count
		result[index] = fresh
	end
	return result
end

-- Units of each item waiting in the inbox.
function Inbox.totals(entries: { Entry }): { [string]: number }
	local totals: { [string]: number } = {}
	for _, entry in entries do
		totals[entry.itemId] = (totals[entry.itemId] or 0) + entry.count
	end
	return totals
end

-- The rows as slots (for the material pool), in row order.
function Inbox.asSlots(entries: { Entry }): { Types.Slot }
	local slots = {} :: { Types.Slot }
	for index, entry in entries do
		slots[index] = { itemId = entry.itemId, count = entry.count, durability = entry.durability }
	end
	return slots
end

-- Rows updated from slots produced by Inbox.asSlots (same order); emptied rows go.
function Inbox.fromSlots(entries: { Entry }, slots: { Types.Slot }): { Entry }
	local result: { Entry } = {}
	for index, entry in entries do
		local slot = slots[index]
		if slot and slot.count > 0 then
			local fresh = table.clone(entry)
			fresh.count = slot.count
			table.insert(result, fresh)
		end
	end
	return result
end

return Inbox
