--!strict
--[[
	StationFallback: where a station's converter lines run while its model waits for an A
	grade (docs/ECONOMY.md §10.1).

	The Smelter and Stonecutter are launch stations, but a station without an approved
	model can't be placed (Art.pieceReady), and without it nobody could make an ingot or a
	block. Tuning.stationFallback names a stand-in for each such station: the Smelter's
	lines move to the fuelled Campfire and the Stonecutter's to the Workbench, keeping
	their ratios, timers and station levels. An empty map leaves every line where
	Data/Recipes puts it.

	Data/init applies this before the bundle is frozen, so every reader (server, client,
	validator) sees the same layout.
]]

local Types = require("./Types")

local StationFallback = {}

-- The station a line on `stationId` runs at now.
function StationFallback.resolve(tuning: Types.TuningDef, stationId: Types.StationId): Types.StationId
	return tuning.stationFallback[stationId] or stationId
end

--[[
	Re-points every recipe on a station in Tuning.stationFallback at its stand-in. Replaces
	content.Recipes with a new table (moved recipes are copies, the rest shared) and returns
	`content`.
]]
function StationFallback.apply(content: Types.Content): Types.Content
	local map = content.Tuning.stationFallback
	if next(map) == nil then
		return content
	end
	local recipes: { [Types.RecipeId]: Types.RecipeDef } = {}
	for id, recipe in content.Recipes do
		local stationId = recipe.stationId
		local target = if stationId then map[stationId] else nil
		if target then
			local moved = table.clone(recipe)
			moved.stationId = target
			recipes[id] = moved
		else
			recipes[id] = recipe
		end
	end
	content.Recipes = recipes
	return content
end

return StationFallback
