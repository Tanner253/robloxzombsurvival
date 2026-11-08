--!strict
-- Item definitions, keyed by permanent ID. M0 placeholders; real items come from docs/ldoe-systems/.

local Types = require("../Types")

local Items: { [Types.ItemId]: Types.ItemDef } = {
	["item.wood"] = {
		id = "item.wood",
		name = "Wood",
		category = "resource",
		tier = 1,
		rarity = "common",
		stackSize = 50,
		icon = "",
	},
	["item.stone"] = {
		id = "item.stone",
		name = "Stone",
		category = "resource",
		tier = 1,
		rarity = "common",
		stackSize = 50,
		icon = "",
	},
	["item.plank"] = {
		id = "item.plank",
		name = "Plank",
		category = "material",
		tier = 1,
		rarity = "uncommon",
		stackSize = 30,
		icon = "",
	},
	["item.hatchet"] = {
		id = "item.hatchet",
		name = "Hatchet",
		category = "tool",
		tier = 1,
		rarity = "common",
		stackSize = 1,
		durability = 100,
		icon = "",
	},
}

return Items
