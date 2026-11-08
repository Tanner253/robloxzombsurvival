--!strict
-- Crafting station definitions, keyed by permanent ID. M0 placeholders.

local Types = require("../Types")

local Stations: { [Types.StationId]: Types.StationDef } = {
	["station.workbench"] = {
		id = "station.workbench",
		name = "Workbench",
		levels = {
			{ level = 1, upgradeCost = {}, queueSlots = 2, speedMultiplier = 1 },
			{
				level = 2,
				upgradeCost = { { itemId = "item.plank", count = 10 } },
				queueSlots = 3,
				speedMultiplier = 1.25,
			},
		},
	},
	["station.campfire"] = {
		id = "station.campfire",
		name = "Campfire",
		levels = {
			{ level = 1, upgradeCost = {}, queueSlots = 1, speedMultiplier = 1 },
		},
		fuel = { itemIds = { "item.wood", "item.plank" }, secondsPerUnit = 60 },
	},
}

return Stations
