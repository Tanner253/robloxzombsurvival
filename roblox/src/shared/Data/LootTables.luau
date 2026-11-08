--!strict
-- Loot table definitions, keyed by permanent ID. M0 placeholders.

local Types = require("../Types")

local LootTables: { [Types.LootTableId]: Types.LootTableDef } = {
	["loot.pine_grove_crate"] = {
		id = "loot.pine_grove_crate",
		rolls = { min = 1, max = 3 },
		entries = {
			{ itemId = "item.wood", weight = 60, min = 2, max = 6 },
			{ itemId = "item.stone", weight = 30, min = 1, max = 4 },
			{ itemId = "item.plank", weight = 10, min = 1, max = 2 },
		},
	},
	["loot.quarry_cache"] = {
		id = "loot.quarry_cache",
		rolls = { min = 2, max = 3 },
		entries = {
			{ itemId = "item.stone", weight = 70, min = 3, max = 8 },
			{ itemId = "item.hatchet", weight = 5, min = 1, max = 1 },
		},
		guaranteed = { { itemId = "item.stone", count = 2 } },
	},
}

return LootTables
