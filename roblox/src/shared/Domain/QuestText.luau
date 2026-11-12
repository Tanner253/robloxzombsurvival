--!strict
--[[
	QuestText: one line per Ember Trail objective, for the tracker and the quest screen. Pure:
	pass the content bundle.

	Every line says where (the flow review's F-22): a station recipe names its station and
	that the batch counts once taken out ("Make a Hewn Plank at the Saw Bench and take it
	out"), a search names its location ("Search containers in Pine Hollow"), and a level
	step says where XP comes from. The count ("0/1") is the tracker's, not part of the line.
]]

local Types = require("../Types")

local QuestText = {}

QuestText.LEVEL_HINT = "gather, fight and extract for XP"

local function article(name: string): string
	local first = string.lower(string.sub(name, 1, 1))
	return if string.find("aeiou", first, 1, true) then `an {name}` else `a {name}`
end

local function itemName(content: Types.Content, itemId: string): string
	local def = content.Items[itemId]
	return if def then def.name else itemId
end

function QuestText.objective(objective: any, content: Types.Content): string
	local kind = objective.kind
	if kind == "gather" then
		return `Gather {itemName(content, objective.itemId)}`
	elseif kind == "craft" then
		local recipe = content.Recipes[objective.recipeId]
		local name = if recipe then itemName(content, recipe.outputs[1].itemId) else "something"
		local station = recipe and recipe.stationId and content.Stations[recipe.stationId]
		if station then
			return `Make {article(name)} at the {station.name} and take it out`
		elseif recipe and recipe.stationId then
			return `Make {name}`
		end
		return `Craft {article(name)}`
	elseif kind == "build" then
		local piece = content.BuildPieces[objective.pieceId]
		return `Build {article(if piece then piece.name else "piece")}`
	elseif kind == "travel" then
		if objective.locationId == nil and objective.fogTier then
			local tier = content.Tuning.travel.fogTierNames[objective.fogTier]
			return `Enter the {if tier then tier else "deep"} fog`
		end
		local location = content.Locations[objective.locationId]
		return `Reach {if location then location.name else "the place"}`
	elseif kind == "loot" then
		local location = objective.locationId and content.Locations[objective.locationId]
		return if location then `Search containers in {location.name}` else "Search containers in the Fog"
	elseif kind == "lootBody" then
		return "Take what a Hollow drops"
	elseif kind == "kill" then
		return if objective.count and objective.count > 1 then "Put down the Hollow" else "Put down a Hollow"
	elseif kind == "equip" then
		return `Equip the {itemName(content, objective.itemId)}`
	elseif kind == "consume" then
		return `Drink or eat {itemName(content, objective.itemId)}`
	elseif kind == "reachLevel" then
		return `Reach level {objective.level}: {QuestText.LEVEL_HINT}`
	end
	return "Keep going"
end

return QuestText
