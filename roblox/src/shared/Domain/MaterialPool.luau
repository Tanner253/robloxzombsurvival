--!strict
--[[
	MaterialPool: where building, crafting and station jobs take materials from at
	home (PLAYER_EXPERIENCE_CHECKLIST 5.13). Pure.

	Sources are drawn in the order given: the server passes pockets, backpack, every
	home storage crate, then the inbox, so a huge resource pack is usable straight
	away without shuffling it into the bag. On Fog Runs only pockets and backpack are
	passed. A draw is all or nothing: if any stack is short, nothing changes.
]]

local Types = require("../Types")

local MaterialPool = {}

export type Source = { key: string, slots: { Types.Slot } }

-- Units of `itemId` across every source.
function MaterialPool.count(sources: { Source }, itemId: string): number
	local total = 0
	for _, source in sources do
		for _, slot in source.slots do
			if slot.itemId == itemId then
				total += slot.count
			end
		end
	end
	return total
end

-- Units of `itemId` per source key (only sources that hold some).
function MaterialPool.breakdown(sources: { Source }, itemId: string): { [string]: number }
	local result: { [string]: number } = {}
	for _, source in sources do
		for _, slot in source.slots do
			if slot.itemId == itemId and slot.count > 0 then
				result[source.key] = (result[source.key] or 0) + slot.count
			end
		end
	end
	return result
end

-- The same stacks with repeated items folded together, first-seen order kept.
local function fold(stacks: { Types.ItemStack }): { Types.ItemStack }
	local result: { Types.ItemStack } = {}
	local at: { [string]: number } = {}
	for _, stack in stacks do
		local index = at[stack.itemId]
		if index then
			result[index] = { itemId = stack.itemId, count = result[index].count + stack.count }
		elseif stack.count > 0 then
			table.insert(result, { itemId = stack.itemId, count = stack.count })
			at[stack.itemId] = #result
		end
	end
	return result
end

--[[
	Takes every stack, drawing from the first source first and, within a source,
	from its first slot first. Returns the changed sources (key -> new slots; sources
	that gave nothing are left out), or nil and how much of the first short item is
	missing.
]]
function MaterialPool.take(
	sources: { Source },
	stacks: { Types.ItemStack }
): ({ [string]: { Types.Slot } }?, Types.ItemStack?)
	local wanted = fold(stacks)
	for _, stack in wanted do
		local have = MaterialPool.count(sources, stack.itemId)
		if have < stack.count then
			return nil, { itemId = stack.itemId, count = stack.count - have }
		end
	end
	local changed: { [string]: { Types.Slot } } = {}
	for _, stack in wanted do
		local left = stack.count
		for _, source in sources do
			if left <= 0 then
				break
			end
			local fresh = changed[source.key] or table.clone(source.slots)
			local touched = false
			for index, slot in fresh do
				if left <= 0 then
					break
				end
				if slot.itemId == stack.itemId and slot.count > 0 then
					local used = math.min(slot.count, left)
					left -= used
					fresh[index] = if slot.count - used > 0
						then { itemId = slot.itemId, count = slot.count - used, durability = slot.durability }
						else { itemId = "", count = 0 }
					touched = true
				end
			end
			if touched then
				changed[source.key] = fresh
			end
		end
	end
	return changed, nil
end

return MaterialPool
