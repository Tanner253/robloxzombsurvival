--!strict
--[[
	Outpost build piece definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.

	Three tiers: Wood (1), Scrap Metal (2), Reinforced (3). Each tier doubles HP and
	nothing is unbreachable (DECISIONS.md). Pieces upgrade in place along
	`upgradesTo`. A base-tier piece's `cost` is its placement price; an upgraded
	tier's `cost` is the price of upgrading into it, and demolish refunds walk the
	chain (Domain/Grid). Upgraded tiers are only reached by upgrading.

	Edge pieces set minFoundationTier to their own tier: "wall tier can't exceed
	foundation tier". Stations and storage set it as their floor-tier gate (LDOE_PARITY
	#22): the ghost says "Needs a Timber floor".

	Unlocks (#49): only the Timber Crate (LDoE's Small Box) starts unlocked; every other
	piece unlocks with an Ember Trail quest (Data/Quests), and the reinforced tier with
	its found plans.

	Costs (docs/ECONOMY.md §5.2, binding): Timber is LDoE's log tier. Scrap blends LDoE's
	plank-and-brick L2 with L3's iron-plate floor; Reinforced is LDoE's stone L3 and harsher,
	with Ironbark Planks for oak plus plates, rivets and copper wire. HP and breach costs are
	unchanged.
]]

local Types = require("../Types")

local function quest(questId: string): Types.UnlockGate
	return { kind = "quest", questId = questId }
end

local SCRAP_TIER: Types.UnlockGate = quest("quest.stand_your_ground")
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
		unlock = quest("quest.first_light"),
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
		unlock = quest("quest.first_light"),
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
		unlock = quest("quest.a_place_to_work"),
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
		unlock = quest("quest.claim_the_ground"),
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
		unlock = quest("quest.claim_the_ground"),
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
		unlock = quest("quest.a_place_to_work"),
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
			{ itemId = "item.stone_block", count = 4 },
			{ itemId = "item.scrap_plate", count = 3 },
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
			{ itemId = "item.plank", count = 8 },
			{ itemId = "item.stone_block", count = 4 },
			{ itemId = "item.scrap_plate", count = 2 },
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
			{ itemId = "item.plank", count = 6 },
			{ itemId = "item.stone_block", count = 4 },
			{ itemId = "item.scrap_plate", count = 2 },
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
			{ itemId = "item.plank", count = 6 },
			{ itemId = "item.scrap_plate", count = 3 },
			{ itemId = "item.rivets", count = 4 },
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
			{ itemId = "item.plank", count = 8 },
			{ itemId = "item.stone_block", count = 4 },
			{ itemId = "item.scrap_plate", count = 2 },
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
			{ itemId = "item.stone_block", count = 12 },
			{ itemId = "item.scrap_plate", count = 8 },
			{ itemId = "item.rivets", count = 4 },
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
			{ itemId = "item.stone_block", count = 12 },
			{ itemId = "item.ironbark_plank", count = 7 },
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.rivets", count = 4 },
			{ itemId = "item.copper_wire", count = 2 },
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
			{ itemId = "item.stone_block", count = 10 },
			{ itemId = "item.ironbark_plank", count = 7 },
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.rivets", count = 4 },
			{ itemId = "item.copper_wire", count = 2 },
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
			{ itemId = "item.ironbark_plank", count = 7 },
			{ itemId = "item.scrap_plate", count = 6 },
			{ itemId = "item.rivets", count = 6 },
			{ itemId = "item.copper_wire", count = 4 },
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
			{ itemId = "item.stone_block", count = 12 },
			{ itemId = "item.ironbark_plank", count = 7 },
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.rivets", count = 4 },
			{ itemId = "item.copper_wire", count = 2 },
		},
		breachCost = 3,
		minFoundationTier = 3,
		unlock = REINFORCED_TIER,
	},

	-- Stations (LDOE_PARITY #19): each a building goal with its own floor tier ----------------
	["build.woodworking_bench"] = {
		id = "build.woodworking_bench",
		footprint = { w = 3, d = 2 }, -- quarter cells (2 studs)
		name = "Saw Bench", -- LDoE calls theirs the Woodworking Bench (ECONOMY §1.5)
		kind = "station",
		tier = 1,
		hp = 300,
		cost = {
			{ itemId = "item.timber", count = 10 },
			{ itemId = "item.stone", count = 6 },
			{ itemId = "item.rope", count = 2 },
		},
		breachCost = 1,
		stationId = "station.woodworking_bench",
		minFoundationTier = 1,
		maxPerPlot = 2,
		unlock = quest("quest.claim_the_ground"),
	},
	["build.stonecutter"] = {
		id = "build.stonecutter",
		footprint = { w = 3, d = 2 }, -- quarter cells (2 studs)
		name = "Stonecutter",
		kind = "station",
		tier = 1,
		hp = 350,
		cost = {
			{ itemId = "item.timber", count = 8 },
			{ itemId = "item.stone", count = 10 },
			{ itemId = "item.rope", count = 2 },
		},
		breachCost = 1,
		stationId = "station.stonecutter",
		minFoundationTier = 1,
		maxPerPlot = 2,
		unlock = quest("quest.a_place_to_work"),
	},
	["build.smelter"] = {
		id = "build.smelter",
		footprint = { w = 3, d = 3 }, -- quarter cells (2 studs)
		name = "Smelter",
		kind = "station",
		tier = 1,
		hp = 400,
		cost = {
			{ itemId = "item.stone", count = 12 },
			{ itemId = "item.stone_block", count = 4 },
			{ itemId = "item.sticks", count = 6 },
		},
		breachCost = 1,
		stationId = "station.smelter",
		maxPerPlot = 2,
		unlock = quest("quest.into_the_fog"),
	},
	["build.workbench"] = {
		id = "build.workbench",
		footprint = { w = 3, d = 2 }, -- quarter cells (2 studs)
		name = "Workbench",
		kind = "station",
		tier = 1,
		hp = 300,
		cost = {
			{ itemId = "item.plank", count = 6 },
			{ itemId = "item.stone_block", count = 3 },
			{ itemId = "item.rope", count = 4 },
		},
		breachCost = 1,
		stationId = "station.workbench",
		minFoundationTier = 1,
		maxPerPlot = 2,
		unlock = quest("quest.keep_the_fire"),
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
		unlock = quest("quest.tools_of_survival"),
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
		unlock = quest("quest.scavenger"),
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
		storageSlots = 15, -- LDoE's Small Box
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
		storageSlots = 25, -- LDoE's Chest
		minFoundationTier = 1,
		maxPerPlot = 20,
		unlock = quest("quest.hold_the_door"),
	},
	-- Launch content (docs/research/ldoe-mvp-parity-content.md LB-3, LB-4, LB-5) -----------
	-- Lights: warm pools at night, "light is territory" (checklist 9.9). No fuel in v0.1.
	["build.pitch_torch"] = {
		id = "build.pitch_torch",
		footprint = { w = 1, d = 1 }, -- quarter cells (2 studs)
		name = "Pitch Torch",
		kind = "furniture",
		tier = 1,
		hp = 100,
		cost = {
			{ itemId = "item.sticks", count = 3 },
			{ itemId = "item.pitch_glue", count = 1 },
			{ itemId = "item.cloth", count = 1 },
		},
		breachCost = 1,
		maxPerPlot = 12,
		light = { range = 14, brightness = 1.4 },
		unlock = quest("quest.keep_the_fire"),
	},
	["build.post_lantern"] = {
		id = "build.post_lantern",
		footprint = { w = 2, d = 2 },
		name = "Post Lantern",
		kind = "furniture",
		tier = 1,
		hp = 200,
		cost = {
			{ itemId = "item.plank", count = 2 },
			{ itemId = "item.scrap_plate", count = 1 },
			{ itemId = "item.pitch_glue", count = 1 },
		},
		breachCost = 1,
		maxPerPlot = 8,
		light = { range = 22, brightness = 1.3 },
		unlock = quest("quest.hold_the_door"),
	},
	-- The respawn point (LB-4): lay the Reed Doormat on a floor; you wake there after a bad run.
	["build.doormat"] = {
		id = "build.doormat",
		footprint = { w = 2, d = 2 },
		name = "Reed Doormat",
		kind = "furniture",
		tier = 1,
		hp = 50,
		cost = { { itemId = "item.doormat", count = 1 } },
		breachCost = 1,
		minFoundationTier = 1,
		maxPerPlot = 1,
		respawn = true,
		unlock = quest("quest.scavenger"),
		feature = "fogRuns",
	},
	-- No-fuel stations (LB-5).
	["build.rain_barrel"] = {
		id = "build.rain_barrel",
		footprint = { w = 2, d = 2 },
		name = "Rain Barrel",
		kind = "station",
		tier = 1,
		hp = 200,
		cost = {
			{ itemId = "item.timber", count = 8 },
			{ itemId = "item.cloth", count = 3 },
			{ itemId = "item.scrap", count = 2 },
		},
		breachCost = 1,
		stationId = "station.rain_barrel",
		maxPerPlot = 2,
		unlock = quest("quest.keep_the_fire"),
	},
	["build.smoke_rack"] = {
		id = "build.smoke_rack",
		footprint = { w = 3, d = 2 },
		name = "Smoke Rack",
		kind = "station",
		tier = 1,
		hp = 200,
		cost = {
			{ itemId = "item.plank", count = 5 },
			{ itemId = "item.rope", count = 10 },
			{ itemId = "item.stone", count = 10 },
		},
		breachCost = 1,
		stationId = "station.smoke_rack",
		maxPerPlot = 2,
		unlock = quest("quest.stand_your_ground"),
		feature = "wildlife", -- its venison comes from deer (F-21)
	},
}

return BuildPieces
