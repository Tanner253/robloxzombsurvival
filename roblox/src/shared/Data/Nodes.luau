--!strict
-- Resource node definitions (trees, boulders, scrap heaps...), keyed by permanent ID.
-- MVP content; see docs/CONTENT_MVP.md. Locations place them by count.
-- XP is about 10 per resource unit, as in LDoE.

local Types = require("../Types")

local Nodes: { [Types.NodeId]: Types.ResourceNodeDef } = {
	-- Hand pickups: how a new player gets the timber and stone for their first tools.
	["node.fallen_branches"] = {
		id = "node.fallen_branches",
		name = "Fallen Branches",
		hits = 1,
		yields = { { itemId = "item.sticks", perHit = 2 } },
		xpPerHit = 20,
		respawnSeconds = 3 * 60,
	},
	["node.loose_stones"] = {
		id = "node.loose_stones",
		name = "Loose Stones",
		hits = 1,
		yields = { { itemId = "item.stone", perHit = 2 } },
		xpPerHit = 20,
		respawnSeconds = 3 * 60,
	},
	["node.reed_patch"] = {
		id = "node.reed_patch",
		name = "Reed Patch",
		hits = 1,
		yields = { { itemId = "item.fiber", perHit = 3 } },
		xpPerHit = 20,
		respawnSeconds = 2 * 60,
	},
	["node.ember_bush"] = {
		id = "node.ember_bush",
		name = "Emberberry Bush",
		hits = 1,
		yields = { { itemId = "item.emberberry", perHit = 3 } },
		xpPerHit = 20,
		respawnSeconds = 5 * 60,
	},
	["node.ashroot_mound"] = {
		id = "node.ashroot_mound",
		name = "Ashroot Mound",
		hits = 2,
		yields = { { itemId = "item.ashroot", perHit = 1 } },
		xpPerHit = 10,
		respawnSeconds = 4 * 60,
	},
	["node.spring_pool"] = {
		id = "node.spring_pool",
		name = "Spring Pool",
		hits = 3,
		yields = { { itemId = "item.murky_water", perHit = 1 } },
		xpPerHit = 5,
		respawnSeconds = 3 * 60,
	},

	-- Tool nodes. Each hit costs the tool one durability.
	["node.pine_tree"] = {
		id = "node.pine_tree",
		name = "Pine",
		tool = { kind = "hatchet", tier = 1 },
		hits = 4,
		yields = { { itemId = "item.timber", perHit = 1 } },
		xpPerHit = 10,
		respawnSeconds = 4 * 60,
	},
	["node.fatwood_stump"] = {
		id = "node.fatwood_stump",
		name = "Fatwood Stump",
		tool = { kind = "hatchet", tier = 1 },
		hits = 3,
		yields = {
			{ itemId = "item.fatwood", perHit = 1 },
			{ itemId = "item.timber", perHit = 1, chance = 0.3 },
		},
		xpPerHit = 12,
		respawnSeconds = 6 * 60,
	},
	["node.boulder"] = {
		id = "node.boulder",
		name = "Boulder",
		tool = { kind = "pick", tier = 1 },
		hits = 5,
		yields = { { itemId = "item.stone", perHit = 1 } },
		xpPerHit = 10,
		respawnSeconds = 5 * 60,
	},
	["node.scrap_heap"] = {
		id = "node.scrap_heap",
		name = "Scrap Heap",
		tool = { kind = "pick", tier = 1 },
		hits = 4,
		yields = {
			{ itemId = "item.scrap", perHit = 2 },
			{ itemId = "item.snarled_wire", perHit = 1, chance = 0.08 },
			{ itemId = "item.rivets", perHit = 1, chance = 0.04 },
		},
		xpPerHit = 12,
		respawnSeconds = 6 * 60,
	},
}

return Nodes
