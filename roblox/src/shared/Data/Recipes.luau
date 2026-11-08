--!strict
-- Recipe definitions, keyed by permanent ID. M0 placeholders.

local Types = require("../Types")

local Recipes: { [Types.RecipeId]: Types.RecipeDef } = {
	["recipe.hatchet"] = {
		id = "recipe.hatchet",
		inputs = {
			{ itemId = "item.wood", count = 5 },
			{ itemId = "item.stone", count = 3 },
		},
		outputs = { { itemId = "item.hatchet", count = 1 } },
		craftSeconds = 5,
		unlock = { kind = "default" },
	},
	["recipe.plank"] = {
		id = "recipe.plank",
		inputs = { { itemId = "item.wood", count = 2 } },
		outputs = { { itemId = "item.plank", count = 1 } },
		stationId = "station.workbench",
		craftSeconds = 20,
		unlock = { kind = "level", level = 2 },
	},
}

return Recipes
