--!strict
--[[
	Pool: the client's view of the home material pool (PLAYER_EXPERIENCE_CHECKLIST
	5.13). At home, have/need counts add up what the player carries, every home
	crate (the "pool" sync section) and the inbox (the "inbox" section), the same
	sources Services/Materials draws from. On Fog Runs only what is carried counts.
]]

local State = require("./State")

local Pool = {}

local function homeExtras(): ({ [string]: number }, { [string]: number })
	local pool = State.get("pool")
	if type(pool) ~= "table" or pool.home ~= true then
		return {}, {}
	end
	local inbox: { [string]: number } = {}
	local rows = State.get("inbox")
	if type(rows) == "table" then
		for _, row in rows do
			inbox[row.itemId] = (inbox[row.itemId] or 0) + row.count
		end
	end
	return pool.crates or {}, inbox
end

--[[
	The carried inventory plus one extra backpack slot per item in crates and the
	inbox, for the shared have/need checks (BuildRules, Crafting.check). Only for
	counting: never render its slots.
]]
function Pool.inventory(inventory: any): any
	if not inventory then
		return nil
	end
	local crates, inbox = homeExtras()
	local backpack = table.clone(inventory.backpack or {})
	for _, extra in { crates, inbox } do
		for itemId, count in extra do
			if count > 0 then
				table.insert(backpack, { itemId = itemId, count = count })
			end
		end
	end
	return { pockets = inventory.pockets, backpack = backpack }
end

-- Where an item would come from: "Bag 3 · Crates 10 · Inbox 50" (sources that hold some).
function Pool.sourcesText(inventory: any, itemId: string): string
	local carried = 0
	for _, container in { inventory and inventory.pockets or {}, inventory and inventory.backpack or {} } do
		for _, slot in container do
			if slot.itemId == itemId then
				carried += slot.count
			end
		end
	end
	local crates, inbox = homeExtras()
	local parts = {}
	if carried > 0 then
		table.insert(parts, `Bag {carried}`)
	end
	if (crates[itemId] or 0) > 0 then
		table.insert(parts, `Crates {crates[itemId]}`)
	end
	if (inbox[itemId] or 0) > 0 then
		table.insert(parts, `Inbox {inbox[itemId]}`)
	end
	return table.concat(parts, " · ")
end

return Pool
