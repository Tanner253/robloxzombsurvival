--!strict
--[[
	All content tables as one frozen bundle.

	Services read content through this module (or the individual children) and must
	never mutate it: everything is deep-frozen at load. The bundle is what the data
	validator checks, both in the Lune test and at server boot.
]]

local Types = require("./Types")
local DevSpeed = require("./DevSpeed")
local Features = require("./Features")
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
	Haven = require("@self/Haven"),
	Projects = require("@self/Projects"),
	StarterShelter = require("@self/StarterShelter"),
	Tuning = require("@self/Tuning"),
}

-- Studio playtests run the pacing sped up (Tuning.devSpeed; live servers always 1).
-- It has to happen here, before the freeze, so every reader sees the same numbers.
DevSpeed.apply(Content, DevSpeed.factor(Content))

-- Content behind a feature flag that is off (Tuning.features) is left out entirely.
Features.strip(Content)

return TableUtil.deepFreeze(Content)
