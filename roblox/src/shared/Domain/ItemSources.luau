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

return ItemSources
