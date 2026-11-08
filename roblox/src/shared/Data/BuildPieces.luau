--!strict
--[[
	Outpost build piece definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.

	Three tiers: Wood (1), Scrap Metal (2), Reinforced (3). Each tier doubles HP and
	nothing is unbreachable (DECISIONS.md). Pieces upgrade in place along
	`upgradesTo`. A base-tier piece's `cost` is its placement price; an upgraded
	tier's `cost` is the price of upgrading into it, and demolish refunds walk the
	chain (Domain/Grid). Upgraded tiers are only reached by upgrading.

	Edge pieces set minFoundationTier to their own tier: "wall tier can't exceed
	foundation tier".
]]

local Types = require("../Types")

local SCRAP_TIER: Types.UnlockGate = { kind = "level", level = 6 }
local REINFORCED_TIER: Types.UnlockGate = { kind = "blueprint", itemId = "item.bp_reinforced" }

local BuildPieces: { [Types.BuildPieceId]: Types.BuildPieceDef } = {
	-- Wood (tier 1): placed directly ----------------------------------------------------
	["build.foundation_wood"] = {
		id = "build.foundation_wood",
		name = "Timber Foundation",
		kind = "foundation",
		tier = 1,
		hp = 600,
		cost = { { itemId = "item.timber", count = 10 } },
		breachCost = 2,
		upgradesTo = "build.foundation_scrap",
	},
	["build.wall_wood"] = {
		id = "build.wall_wood",
		name = "Timber Wall",
		kind = "wall",
		tier = 1,
		hp = 400,
		cost = {
			{ itemId = "item.timber", count = 8 },
			{ itemId = "item.rope", count = 1 },
		},
		breachCost = 1,
		minFoundationTier = 1,
		upgradesTo = "build.wall_scrap",
	},
	-- The sharpened-stake palisade reads as an outdoor fence, not a room wall: it's a Defense
	-- piece of its own. The Timber Wall gets a solid plank wall with a top cap.
	["build.fence_wood"] = {
		id = "build.fence_wood",
		name = "Palisade Fence",
		kind = "wall",
		tab = "defense",
		tier = 1,
		hp = 300,
		cost = {
			{ itemId = "item.timber", count = 6 },
			{ itemId = "item.rope", count = 1 },
		},
		breachCost = 1,
		minFoundationTier = 1,
	},
	["build.doorway_wood"] = {
		id = "build.doorway_wood",
		name = "Timber Doorway",
		kind = "doorway",
		tier = 1,
		hp = 350,
		cost = {
			{ itemId = "item.timber", count = 6 },
			{ itemId = "item.rope", count = 1 },
		},
		breachCost = 1,
		minFoundationTier = 1,
		upgradesTo = "build.doorway_scrap",
	},
	["build.door_wood"] = {
		id = "build.door_wood",
		name = "Timber Door",
		kind = "door",
		tier = 1,
		hp = 300,
		cost = {
			{ itemId = "item.timber", count = 5 },
			{ itemId = "item.rope", count = 2 },
		},
		breachCost = 1,
		minFoundationTier = 1,
		upgradesTo = "build.door_scrap",
	},
	["build.window_wood"] = {
		id = "build.window_wood",
		name = "Timber Window Wall",
		kind = "window",
		tier = 1,
		hp = 350,
		cost = {
			{ itemId = "item.timber", count = 7 },
			{ itemId = "item.rope", count = 1 },
		},
		breachCost = 1,
		minFoundationTier = 1,
		upgradesTo = "build.window_scrap",
	},

	-- Scrap Metal (tier 2): cost is the upgrade from Wood ----------------------------------
	["build.foundation_scrap"] = {
		id = "build.foundation_scrap",
		name = "Scrap Metal Foundation",
		kind = "foundation",
		tier = 2,
		hp = 1200,
		cost = {
			{ itemId = "item.plank", count = 6 },
			{ itemId = "item.scrap_plate", count = 4 },
		},
		breachCost = 4,
		unlock = SCRAP_TIER,
		upgradesTo = "build.foundation_reinforced",
	},
	["build.wall_scrap"] = {
		id = "build.wall_scrap",
		name = "Scrap Metal Wall",
		kind = "wall",
		tier = 2,
		hp = 800,
		cost = {
			{ itemId = "item.plank", count = 4 },
			{ itemId = "item.scrap_plate", count = 3 },
		},
		breachCost = 2,
		minFoundationTier = 2,
		unlock = SCRAP_TIER,
		upgradesTo = "build.wall_reinforced",
	},
	["build.doorway_scrap"] = {
		id = "build.doorway_scrap",
		name = "Scrap Metal Doorway",
		kind = "doorway",
		tier = 2,
		hp = 700,
		cost = {
			{ itemId = "item.plank", count = 3 },
			{ itemId = "item.scrap_plate", count = 3 },
		},
		breachCost = 2,
		minFoundationTier = 2,
		unlock = SCRAP_TIER,
		upgradesTo = "build.doorway_reinforced",
	},
	["build.door_scrap"] = {
		id = "build.door_scrap",
		name = "Scrap Metal Door",
		kind = "door",
		tier = 2,
		hp = 600,
		cost = {
			{ itemId = "item.plank", count = 2 },
			{ itemId = "item.scrap_plate", count = 3 },
			{ itemId = "item.rivets", count = 1 },
		},
		breachCost = 2,
		minFoundationTier = 2,
		unlock = SCRAP_TIER,
		upgradesTo = "build.door_reinforced",
	},
	["build.window_scrap"] = {
		id = "build.window_scrap",
		name = "Scrap Metal Window Wall",
		kind = "window",
		tier = 2,
		hp = 700,
		cost = {
			{ itemId = "item.plank", count = 3 },
			{ itemId = "item.scrap_plate", count = 3 },
		},
		breachCost = 2,
		minFoundationTier = 2,
		unlock = SCRAP_TIER,
		upgradesTo = "build.window_reinforced",
	},

	-- Reinforced (tier 3): cost is the upgrade from Scrap Metal ---------------------------
	["build.foundation_reinforced"] = {
		id = "build.foundation_reinforced",
		name = "Reinforced Foundation",
		kind = "foundation",
		tier = 3,
		hp = 2400,
		cost = {
			{ itemId = "item.stone_block", count = 10 },
			{ itemId = "item.scrap_plate", count = 6 },
			{ itemId = "item.rivets", count = 2 },
		},
		breachCost = 8,
		unlock = REINFORCED_TIER,
	},
	["build.wall_reinforced"] = {
		id = "build.wall_reinforced",
		name = "Reinforced Wall",
		kind = "wall",
		tier = 3,
		hp = 1600,
		cost = {
			{ itemId = "item.stone_block", count = 8 },
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.rivets", count = 2 },
		},
		breachCost = 4,
		minFoundationTier = 3,
		unlock = REINFORCED_TIER,
	},
	["build.doorway_reinforced"] = {
		id = "build.doorway_reinforced",
		name = "Reinforced Doorway",
		kind = "doorway",
		tier = 3,
		hp = 1400,
		cost = {
			{ itemId = "item.stone_block", count = 6 },
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.rivets", count = 2 },
		},
		breachCost = 4,
		minFoundationTier = 3,
		unlock = REINFORCED_TIER,
	},
	["build.door_reinforced"] = {
		id = "build.door_reinforced",
		name = "Reinforced Door",
		kind = "door",
		tier = 3,
		hp = 1200,
		cost = {
			{ itemId = "item.scrap_plate", count = 6 },
			{ itemId = "item.rivets", count = 3 },
			{ itemId = "item.coil_spring", count = 1 },
		},
		breachCost = 3,
		minFoundationTier = 3,
		unlock = REINFORCED_TIER,
	},
	["build.window_reinforced"] = {
		id = "build.window_reinforced",
		name = "Reinforced Window Wall",
		kind = "window",
		tier = 3,
		hp = 1400,
		cost = {
			{ itemId = "item.stone_block", count = 6 },
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.rivets", count = 2 },
		},
		breachCost = 3,
		minFoundationTier = 3,
		unlock = REINFORCED_TIER,
	},

	-- Stations -----------------------------------------------------------------------------
	["build.workbench"] = {
		id = "build.workbench",
		footprint = { w = 3, d = 2 }, -- quarter cells (2 studs)
		name = "Workbench",
		kind = "station",
		tier = 1,
		hp = 300,
		cost = {
			{ itemId = "item.timber", count = 10 },
			{ itemId = "item.stone", count = 6 },
			{ itemId = "item.rope", count = 2 },
		},
		breachCost = 1,
		stationId = "station.workbench",
		minFoundationTier = 1,
		maxPerPlot = 2,
	},
	["build.campfire"] = {
		id = "build.campfire",
		footprint = { w = 3, d = 3 }, -- quarter cells (2 studs)
		name = "Campfire",
		kind = "station",
		tier = 1,
		hp = 200,
		cost = {
			{ itemId = "item.sticks", count = 6 },
			{ itemId = "item.stone", count = 5 },
			{ itemId = "item.fiber", count = 2 },
		},
		breachCost = 1,
		stationId = "station.campfire",
		maxPerPlot = 2,
	},
	["build.recycler"] = {
		id = "build.recycler",
		footprint = { w = 3, d = 3 }, -- quarter cells (2 studs)
		name = "Recycler",
		kind = "station",
		tier = 2,
		hp = 500,
		cost = {
			{ itemId = "item.plank", count = 15 },
			{ itemId = "item.scrap_plate", count = 6 },
			{ itemId = "item.rivets", count = 6 },
			{ itemId = "item.coil_spring", count = 2 },
		},
		breachCost = 2,
		stationId = "station.recycler",
		minFoundationTier = 2,
		maxPerPlot = 1,
		unlock = { kind = "level", level = 7 },
	},

	-- Storage --------------------------------------------------------------------------------
	["build.crate_wood"] = {
		id = "build.crate_wood",
		footprint = { w = 3, d = 2 }, -- quarter cells (2 studs)
		name = "Timber Crate",
		kind = "storage",
		tier = 1,
		hp = 250,
		cost = {
			{ itemId = "item.timber", count = 8 },
			{ itemId = "item.rope", count = 4 },
		},
		breachCost = 1,
		storageSlots = 16,
		minFoundationTier = 1,
		maxPerPlot = 20,
		upgradesTo = "build.crate_banded",
	},
	["build.crate_banded"] = {
		id = "build.crate_banded",
		footprint = { w = 2, d = 3 }, -- quarter cells (2 studs)
		name = "Banded Crate",
		kind = "storage",
		tier = 2,
		hp = 500,
		cost = {
			{ itemId = "item.plank", count = 6 },
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.rivets", count = 2 },
		},
		breachCost = 2,
		storageSlots = 28,
		minFoundationTier = 1,
		maxPerPlot = 20,
		unlock = { kind = "level", level = 9 },
	},
	-- Fog Runs (slice 2): hidden until Tuning.features.fogRuns and its model grades A.
	["build.ammo_press"] = {
		id = "build.ammo_press",
		footprint = { w = 3, d = 2 }, -- quarter cells (2 studs)
		name = "Ammo Press",
		kind = "station",
		tier = 2,
		hp = 450,
		cost = {
			{ itemId = "item.plank", count = 10 },
			{ itemId = "item.scrap_plate", count = 8 },
			{ itemId = "item.rivets", count = 6 },
			{ itemId = "item.coil_spring", count = 2 },
		},
		breachCost = 2,
		stationId = "station.ammo_press",
		minFoundationTier = 2,
		maxPerPlot = 1,
		unlock = { kind = "level", level = 10 }, -- day 2, with Workbench level 2 (Scrap tier)
		feature = "fogRuns",
	},
}

return BuildPieces
