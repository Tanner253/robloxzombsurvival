--!strict
--[[
	ItemSources: where an item comes from, in player words, worked out from content
	(PLAYER_EXPERIENCE_CHECKLIST 5.10: hover or tap an ingredient to see its source).
	Pure. For example:
	- "Chopped from Pine Tree with a hatchet"
	- "Workbench: 4 Timber into 4 Hewn Plank"
	- "Found on Fog Runs"
]]

local Types = require("../Types")
local Unlocks = require("./Unlocks")

local ItemSources = {}

local TOOL_VERB: { [string]: string } = { hatchet = "Chopped from", pick = "Mined from" }
local TOOL_NAME: { [string]: string } = { hatchet = "a hatchet", pick = "a pick" }

local function stackText(content: Types.Content, stack: Types.ItemStack): string
	local def = content.Items[stack.itemId]
	return `{stack.count} {if def then def.name else stack.itemId}`
end

local function listText(content: Types.Content, stacks: { Types.ItemStack }): string
	local parts = {}
	for _, stack in stacks do
		table.insert(parts, stackText(content, stack))
	end
	return table.concat(parts, " + ")
end

-- Up to `limit` (default 3) source lines, gathering first, then crafting, then loot.
function ItemSources.of(content: Types.Content, itemId: string, limit: number?): { string }
	local lines: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(text: string)
		if not seen[text] then
			seen[text] = true
			table.insert(lines, text)
		end
	end

	local nodeIds = {}
	for id in content.Nodes do
		table.insert(nodeIds, id)
	end
	table.sort(nodeIds)
	for _, id in nodeIds do
		local node = content.Nodes[id]
		for _, yield in node.yields do
			if yield.itemId == itemId then
				local kind = if node.tool then node.tool.kind else nil
				if kind then
					add(`{TOOL_VERB[kind] or "Gathered from"} {node.name} with {TOOL_NAME[kind] or `a {kind}`}`)
				else
					add(`Gathered from {node.name} by hand`)
				end
			end
		end
	end

	local recipeIds = {}
	for id in content.Recipes do
		table.insert(recipeIds, id)
	end
	table.sort(recipeIds)
	for _, id in recipeIds do
		local recipe = content.Recipes[id]
		for _, output in recipe.outputs do
			if output.itemId == itemId then
				local station = recipe.stationId and content.Stations[recipe.stationId]
				local where = if station then station.name else "By hand"
				add(`{where}: {listText(content, recipe.inputs)} into {stackText(content, output)}`)
			end
		end
	end

	for _, lootTable in content.LootTables do
		for _, entry in lootTable.entries do
			if entry.itemId == itemId then
				add("Found on Fog Runs")
			end
		end
	end

	local max = limit or 3
	while #lines > max do
		table.remove(lines)
	end
	return lines
end

local function gathered(content: Types.Content, itemId: string): boolean
	for _, node in content.Nodes do
		for _, yield in node.yields do
			if yield.itemId == itemId then
				return true
			end
		end
	end
	return false
end

-- The gate still closed on a recipe: its station's piece first (no Stonecutter, no blocks),
-- then the recipe's own; nil when both are open.
local function closedGate(
	content: Types.Content,
	recipe: Types.RecipeDef,
	progress: Unlocks.Progress
): Types.UnlockGate?
	if recipe.stationId then
		local open = false
		local gate: Types.UnlockGate? = nil
		for _, piece in content.BuildPieces do
			if piece.stationId == recipe.stationId then
				if Unlocks.isMet(piece.unlock, progress) then
					open = true
				elseif gate == nil then
					gate = piece.unlock
				end
			end
		end
		if not open then
			return gate or recipe.unlock
		end
	end
	return if Unlocks.isMet(recipe.unlock, progress) then nil else recipe.unlock
end

local function gateOrder(gate: Types.UnlockGate, content: Types.Content): number
	if gate.kind == "quest" then
		local quest: any = content.Quests[gate.questId]
		return if quest and quest.order then quest.order else math.huge
	end
	return math.huge
end

--[[
	When everything that makes an item is still locked and it can't be gathered, where it will
	come from, short enough for a cost chip: "Stonecutter: Ember Trail 4" (the flow review's
	F-34: the Workbench read unlocked while its Stone Blocks waited on the other branch's
	Stonecutter). A chance find on a run doesn't count: it is luck, not a plan. Nil when the
	player can make or gather it now.
]]
function ItemSources.lockedMaker(
	content: Types.Content,
	itemId: string,
	progress: Unlocks.Progress,
	names: Unlocks.Names
): string?
	if gathered(content, itemId) then
		return nil
	end
	local best: { where: string, gate: Types.UnlockGate, order: number }? = nil
	for _, recipe in content.Recipes do
		local made = false
		for _, output in recipe.outputs do
			made = made or output.itemId == itemId
		end
		if made then
			local gate = closedGate(content, recipe, progress)
			if gate == nil then
				return nil -- one way to make it is open
			end
			local station = recipe.stationId and content.Stations[recipe.stationId]
			local order = gateOrder(gate, content)
			if best == nil or order < best.order then
				best = { where = if station then station.name else "Crafting", gate = gate, order = order }
			end
		end
	end
	if best == nil then
		return nil
	end
	local short = Unlocks.short(best.gate, names)
	return if short then `{best.where}: {short}` else nil
end

-- Whether the player can get an item on purpose now: gathered, or made with what is unlocked
-- (Haven's contract board asks only for these, the flow review's F-35).
function ItemSources.obtainable(content: Types.Content, itemId: string, progress: Unlocks.Progress): boolean
	if gathered(content, itemId) then
		return true
	end
	for _, recipe in content.Recipes do
		for _, output in recipe.outputs do
			if output.itemId == itemId and closedGate(content, recipe, progress) == nil then
				return true
			end
		end
	end
	return false
end

return ItemSources
