--!strict
-- Fog map location definitions, keyed by permanent ID. M0 placeholders.

local Types = require("../Types")

local Locations: { [Types.LocationId]: Types.LocationDef } = {
	["loc.pine_grove"] = {
		id = "loc.pine_grove",
		name = "Pine Grove",
		fogTier = 1,
		levelGate = 1,
		energyCost = 2,
		walkSeconds = 90,
		lootTableIds = { "loot.pine_grove_crate" },
	},
	["loc.old_quarry"] = {
		id = "loc.old_quarry",
		name = "Old Quarry",
		fogTier = 2,
		levelGate = 3,
		energyCost = 5,
		walkSeconds = 300,
		resetSeconds = 4 * 60 * 60,
		lootTableIds = { "loot.quarry_cache", "loot.pine_grove_crate" },
	},
}

return Locations
