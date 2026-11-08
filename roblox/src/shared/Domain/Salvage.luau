--!strict
--[[
	Salvage: the Recycler's breakdown table (StationDef.salvage). Pure.

	The Recycler is a converter like every other station (Domain/Converter); this module
	only looks up what an item breaks into and rolls a batch. An output with chance 1
	always drops; the others roll chance x condition (when Tuning.salvage.
	durabilityScalesChance and the item has durability) + the level's salvageChanceBonus.
]]

local Types = require("../Types")
local Rng = require("./Rng")

local Salvage = {}

-- The salvage definition for an input item, if the station breaks it down.
function Salvage.find(stationDef: Types.StationDef, itemId: Types.ItemId): Types.SalvageDef?
	local list = stationDef.salvage
	if list == nil then
		return nil
	end
	for _, def in list do
		if def.inputItemId == itemId then
			return def
		end
	end
	return nil
end

-- Rolls one batch's outputs.
function Salvage.roll(
	def: Types.SalvageDef,
	condition: number,
	bonus: number,
	scales: boolean,
	rng: Rng.Source
): { Types.ItemStack }
	local result: { Types.ItemStack } = {}
	for _, output in def.outputs do
		local chance = output.chance
		if chance < 1 then
			chance = (if scales then chance * condition else chance) + bonus
		end
		if chance >= 1 or rng:NextNumber() < chance then
			local count = rng:NextInteger(output.min, output.max)
			if count > 0 then
				table.insert(result, { itemId = output.itemId, count = count })
			end
		end
	end
	return result
end

return Salvage
