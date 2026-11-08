--!strict
--[[
	Crafting: hand recipes, the crafting catalogue's side of LDOE_PARITY #20. Pure.

	Every tool, weapon, armor piece, bag and food mix is crafted by hand, instantly, from
	the inventory (at home the services pass a pooled view of pockets, backpack, crates
	and inbox, checklist 5.13). Stations only refine materials: their recipes run in
	Domain/Converter, never here. Unlock gates are Domain/Unlocks'.

	Every function is pure and atomic: it returns new state or nil and a reason, and
	never half-applies a change. Inventory changes use Domain/Inventory.
]]

local Types = require("../Types")
local Inventory = require("./Inventory")
local Unlocks = require("./Unlocks")

local Crafting = {}

-- The parts of PlayerData that gate recipes (Domain/Unlocks).
export type Progress = Unlocks.Progress

export type Recipes = { [Types.RecipeId]: Types.RecipeDef }

export type Reason = "locked" | "wrongStation" | "missingInputs" | "inventoryFull"

local function assertCount(count: number)
	assert(count >= 1 and count % 1 == 0, "count must be a positive integer")
end

local function scaled(stacks: { Types.ItemStack }, times: number): { Types.ItemStack }
	local result: { Types.ItemStack } = {}
	for index, stack in stacks do
		result[index] = { itemId = stack.itemId, count = stack.count * times }
	end
	return result
end

-- Adds every stack or nothing. Returns nil when something would not fit.
local function addAll(
	inventory: Types.Inventory,
	stacks: { Types.ItemStack },
	items: Inventory.ItemLookup
): Types.Inventory?
	local result = inventory
	for _, stack in stacks do
		local nextInventory, left = Inventory.add(result, stack.itemId, stack.count, items)
		if left > 0 then
			return nil
		end
		result = nextInventory
	end
	return result
end

-- Whether the player has unlocked `recipe` (by its gate, or an explicit unlock).
function Crafting.isUnlocked(recipe: Types.RecipeDef, progress: Progress): boolean
	if progress.unlocks.recipes[recipe.id] then
		return true
	end
	return Unlocks.isMet(recipe.unlock, progress)
end

--[[
	Checks that `count` crafts of a hand recipe can happen now. Station recipes are refused
	("wrongStation"): they convert at their station. Returns true, or false and a reason.
]]
function Crafting.check(
	recipe: Types.RecipeDef,
	inventory: Types.Inventory,
	progress: Progress,
	count: number?
): (boolean, Reason?)
	local times = count or 1
	assertCount(times)
	if recipe.stationId then
		return false, "wrongStation"
	end
	if not Crafting.isUnlocked(recipe, progress) then
		return false, "locked"
	end
	if not Inventory.hasAll(inventory, scaled(recipe.inputs, times)) then
		return false, "missingInputs"
	end
	return true, nil
end

--[[
	Crafts a hand recipe instantly: inputs out, outputs in. Returns the new
	inventory, or nil and a reason ("inventoryFull" when the outputs would not fit
	after the inputs are taken).
]]
function Crafting.craftByHand(
	inventory: Types.Inventory,
	recipe: Types.RecipeDef,
	progress: Progress,
	items: Inventory.ItemLookup,
	count: number?
): (Types.Inventory?, Reason?)
	local times = count or 1
	local ok: boolean, reason: Reason? = Crafting.check(recipe, inventory, progress, times)
	if not ok then
		return nil, reason
	end
	local taken = Inventory.removeAll(inventory, scaled(recipe.inputs, times)) :: Types.Inventory
	local result = addAll(taken, scaled(recipe.outputs, times), items)
	if not result then
		return nil, "inventoryFull"
	end
	return result, nil
end

-- How many crafts the inventory can pay for right now (the catalogue's Max button).
function Crafting.maxCrafts(recipe: Types.RecipeDef, inventory: Types.Inventory): number
	local best = math.huge
	for _, stack in recipe.inputs do
		best = math.min(best, Inventory.count(inventory, stack.itemId) // stack.count)
	end
	return if best == math.huge then 0 else best
end

return Crafting
