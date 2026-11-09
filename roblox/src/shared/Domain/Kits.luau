--!strict
--[[
	Kits: material sets derived from the build data, so a kit stays right when the economy
	retunes costs (Data/Products' room kits; MVP_LAUNCH Monetization v0.1).

	A 3x3 room is 9 foundations and its 12 edges: 11 walls, a doorway and its door. Building
	it at a tier means placing every piece at the base tier and upgrading it up the
	`upgradesTo` chain, so the kit holds every one of those costs.
]]

local Types = require("../Types")

local Kits = {}

-- The base-tier pieces of a 3x3 room and how many of each.
Kits.ROOM_3X3 = {
	["build.foundation_wood"] = 9,
	["build.wall_wood"] = 11,
	["build.doorway_wood"] = 1,
	["build.door_wood"] = 1,
} :: { [string]: number }

-- Every material to place `baseId` and upgrade it to `tier`; nil when the chain never gets there.
function Kits.chainCost(pieces: { [string]: Types.BuildPieceDef }, baseId: string, tier: number): { Types.ItemStack }?
	local totals: { [string]: number } = {}
	local id: string? = baseId
	while id do
		local def = pieces[id]
		if def == nil then
			return nil
		end
		for _, stack in def.cost do
			totals[stack.itemId] = (totals[stack.itemId] or 0) + stack.count
		end
		if def.tier >= tier then
			local list: { Types.ItemStack } = {}
			for itemId, count in totals do
				table.insert(list, { itemId = itemId, count = count })
			end
			return list
		end
		id = def.upgradesTo
	end
	return nil
end

-- Every material for a 3x3 room built up to `tier`, merged and sorted by item.
function Kits.room(pieces: { [string]: Types.BuildPieceDef }, tier: number): { Types.ItemStack }
	local totals: { [string]: number } = {}
	for baseId, count in Kits.ROOM_3X3 do
		local chain: { Types.ItemStack } = Kits.chainCost(pieces, baseId, tier) or {}
		for _, stack in chain do
			totals[stack.itemId] = (totals[stack.itemId] or 0) + stack.count * count
		end
	end
	local list: { Types.ItemStack } = {}
	for itemId, count in totals do
		table.insert(list, { itemId = itemId, count = count })
	end
	table.sort(list, function(a: Types.ItemStack, b: Types.ItemStack): boolean
		return a.itemId < b.itemId
	end)
	return list
end

return Kits
