--!strict
--[[
	All content tables as one frozen bundle.

	Services read content through this module (or the individual children) and must
	never mutate it: everything is deep-frozen at load. The bundle is what the data
	validator checks, both in the Lune test and at server boot.
]]

local Types = require("./Types")
local TableUtil = require("./Util/Table")

local Content: Types.Content = {
	Items = require("@self/Items"),
	Recipes = require("@self/Recipes"),
	Stations = require("@self/Stations"),
	Nodes = require("@self/Nodes"),
	LootTables = require("@self/LootTables"),
	Enemies = require("@self/Enemies"),
	Locations = require("@self/Locations"),
	BuildPieces = require("@self/BuildPieces"),
	Levels = require("@self/Levels"),
	Quests = require("@self/Quests"),
	Products = require("@self/Products"),
	Tuning = require("@self/Tuning"),
}

return TableUtil.deepFreeze(Content)
