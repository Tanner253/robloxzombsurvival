--!strict
--[[
	questText: one line per Ember Trail objective, for the tracker and the quest screen
	("Chop timber", "Build a Woodworking Bench", "Reach the crash site"), and the tracker's
	rows from the synced quest state (Domain/Quests.tracker).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Flags = require(ReplicatedStorage.Shared.Flags)
local Quests = require(ReplicatedStorage.Shared.Domain.Quests)
local format = require("./format")

local questText = {}

local function article(name: string): string
	local first = string.lower(string.sub(name, 1, 1))
	return if string.find("aeiou", first, 1, true) then `an {name}` else `a {name}`
end

function questText.objective(objective: any): string
	local kind = objective.kind
	if kind == "gather" then
		return `Gather {format.itemName(objective.itemId)}`
	elseif kind == "craft" then
		local recipe = Content.Recipes[objective.recipeId]
		local name = if recipe then format.itemName(recipe.outputs[1].itemId) else "something"
		return if recipe and recipe.stationId then `Make {name}` else `Craft {article(name)}`
	elseif kind == "build" then
		local piece = Content.BuildPieces[objective.pieceId]
		return `Build {article(if piece then piece.name else "piece")}`
	elseif kind == "travel" then
		local location = Content.Locations[objective.locationId]
		return `Reach {if location then location.name else "the place"}`
	elseif kind == "loot" then
		return "Search containers"
	elseif kind == "lootBody" then
		return "Search the body"
	elseif kind == "kill" then
		return "Put down the Hollow"
	elseif kind == "equip" then
		return `Equip the {format.itemName(objective.itemId)}`
	elseif kind == "consume" then
		return `Drink or eat {format.itemName(objective.itemId)}`
	elseif kind == "reachLevel" then
		return `Reach level {objective.level}`
	end
	return "Keep going"
end

-- The tracker rows (up to `limit`) for the synced quest state, or {} before it arrives.
function questText.rows(state: any, limit: number?): { Quests.Row }
	if type(state) ~= "table" then
		return {}
	end
	return Quests.tracker(state, Content.Quests, Flags.snapshot(), limit)
end

return questText
