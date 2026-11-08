--!strict
-- Outpost build piece definitions, keyed by permanent ID. M0 placeholders.
-- Tiers follow DECISIONS.md: each tier roughly doubles HP, nothing is unbreachable.

local Types = require("../Types")

local BuildPieces: { [Types.BuildPieceId]: Types.BuildPieceDef } = {
	["build.foundation_wood"] = {
		id = "build.foundation_wood",
		name = "Wooden Foundation",
		kind = "foundation",
		tier = 1,
		hp = 500,
		cost = { { itemId = "item.wood", count = 10 } },
		breachCost = 2,
	},
	["build.wall_wood"] = {
		id = "build.wall_wood",
		name = "Wooden Wall",
		kind = "wall",
		tier = 1,
		hp = 300,
		cost = { { itemId = "item.wood", count = 6 } },
		breachCost = 1,
		upgradesTo = "build.wall_stone",
	},
	["build.wall_stone"] = {
		id = "build.wall_stone",
		name = "Stone Wall",
		kind = "wall",
		tier = 2,
		hp = 600,
		cost = { { itemId = "item.stone", count = 10 } },
		breachCost = 2,
	},
	["build.workbench"] = {
		id = "build.workbench",
		name = "Workbench",
		kind = "station",
		tier = 1,
		hp = 200,
		cost = { { itemId = "item.plank", count = 5 } },
		breachCost = 1,
		stationId = "station.workbench",
	},
}

return BuildPieces
