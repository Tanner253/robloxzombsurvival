--!strict
--[[
	Death: the dropped backpack (GAME_DESIGN.md "Structure": "your backpack drops
	where you fell and you can go back for it. Equipped gear is kept.").

	On death, the carried items (backpack, and pockets unless `keepPockets`) move
	into a DroppedBackpack record at the location where the player fell. Equipment
	is not part of Types.Inventory, so it is kept by construction. The record
	expires at `despawnAt`; services may pass an earlier time (for example the
	location's next reset).

	Recovery rules: only the owner, only at that location, only before it
	despawns. Recovery takes what fits; the rest stays in the backpack, which
	disappears once empty.
]]

local Types = require("../Types")
local Inventory = require("./Inventory")

local Death = {}

export type Position = { x: number, y: number, z: number }

export type DroppedBackpack = {
	id: string,
	ownerUserId: number,
	locationId: Types.LocationId,
	position: Position?,
	droppedAt: number,
	despawnAt: number,
	contents: Types.Container, -- non-empty slots only, durability kept
}

export type Config = {
	despawnSeconds: number,
	keepPockets: boolean?, -- true keeps pocket items on death (LDoE drops them)
}

export type DropContext = {
	id: string, -- unique record ID chosen by the service
	ownerUserId: number,
	locationId: Types.LocationId,
	now: number,
	position: Position?,
	despawnAt: number?, -- overrides now + despawnSeconds when earlier
}

export type Reason = "notOwner" | "wrongLocation" | "expired"

local function takeAll(container: Types.Container, into: Types.Container): Types.Container
	local emptied = Inventory.newContainer(#container)
	for _, slot in container do
		if not Inventory.isEmpty(slot) then
			table.insert(into, { itemId = slot.itemId, count = slot.count, durability = slot.durability })
		end
	end
	return emptied
end

--[[
	Empties the carried containers into a dropped backpack. Returns the new
	inventory (same capacities) and the record, or nil when nothing was carried.
]]
function Death.drop(inventory: Types.Inventory, ctx: DropContext, config: Config): (Types.Inventory, DroppedBackpack?)
	local contents: Types.Container = {}
	local pockets: Types.Container
	if config.keepPockets then
		pockets = table.clone(inventory.pockets)
	else
		pockets = takeAll(inventory.pockets, contents)
	end
	local backpack = takeAll(inventory.backpack, contents)
	local result: Types.Inventory = { pockets = pockets, backpack = backpack }
	if #contents == 0 then
		return result, nil
	end

	local despawnAt = ctx.now + config.despawnSeconds
	if ctx.despawnAt then
		despawnAt = math.min(despawnAt, ctx.despawnAt)
	end
	return result,
		{
			id = ctx.id,
			ownerUserId = ctx.ownerUserId,
			locationId = ctx.locationId,
			position = ctx.position,
			droppedAt = ctx.now,
			despawnAt = despawnAt,
			contents = contents,
		}
end

function Death.isExpired(drop: DroppedBackpack, now: number): boolean
	return now >= drop.despawnAt
end

-- Whether `userId`, standing in `locationId`, may open the backpack now.
function Death.canRecover(drop: DroppedBackpack, userId: number, locationId: string, now: number): (boolean, Reason?)
	if userId ~= drop.ownerUserId then
		return false, "notOwner"
	end
	if locationId ~= drop.locationId then
		return false, "wrongLocation"
	end
	if Death.isExpired(drop, now) then
		return false, "expired"
	end
	return true, nil
end

--[[
	Moves as much as fits from the backpack into the inventory. Returns the new
	inventory and the leftover backpack (nil once emptied), or nil, nil and a
	reason when recovery is not allowed.
]]
function Death.recover(
	drop: DroppedBackpack,
	inventory: Types.Inventory,
	items: Inventory.ItemLookup,
	userId: number,
	locationId: string,
	now: number
): (Types.Inventory?, DroppedBackpack?, Reason?)
	local allowed: boolean, reason: Reason? = Death.canRecover(drop, userId, locationId, now)
	if not allowed then
		return nil, nil, reason
	end

	local result = inventory
	local leftover: Types.Container = {}
	for _, slot in drop.contents do
		local nextInventory, notFitted = Inventory.addSlot(result, slot, items)
		result = nextInventory
		if notFitted > 0 then
			table.insert(leftover, { itemId = slot.itemId, count = notFitted, durability = slot.durability })
		end
	end

	if #leftover == 0 then
		return result, nil, nil
	end
	local remaining = table.clone(drop)
	remaining.contents = leftover
	return result, remaining, nil
end

-- Drops expired backpacks and keeps at most `maxCount` (newest first kept).
function Death.prune(drops: { DroppedBackpack }, now: number, maxCount: number?): { DroppedBackpack }
	local live: { DroppedBackpack } = {}
	for _, drop in drops do
		if not Death.isExpired(drop, now) then
			table.insert(live, drop)
		end
	end
	table.sort(live, function(a: DroppedBackpack, b: DroppedBackpack): boolean
		return a.droppedAt > b.droppedAt
	end)
	local limit = maxCount or #live
	while #live > limit do
		table.remove(live)
	end
	return live
end

return Death
