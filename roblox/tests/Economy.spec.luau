--!strict
-- Specs for the home economy (the developer, 2026-11-08: "getting way too many
-- resources... why would someone ever need to leave their base"). Home nodes are LDoE's
-- finite starter supply (LDOE_PARITY #30): they never respawn and survive restarts, so
-- the bulk of a Timber-tier base must come from Fog Runs.
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Gathering = require("../src/shared/Domain/Gathering")
local Rng = require("../src/shared/Domain/Rng")
local Migrations = require("../src/shared/Domain/Migrations")
local PlayerSchema = require("../src/shared/Domain/PlayerSchema")

-- Everything the home plot can ever give of an item (finite nodes, guaranteed yields).
local function homeStock(): { [string]: number }
	local stock: { [string]: number } = {}
	for _, entry in Content.Tuning.home.nodes do
		local def = Content.Nodes[entry.nodeId]
		for _, yield in def.yields do
			if yield.chance == nil then
				stock[yield.itemId] = (stock[yield.itemId] or 0) + yield.perHit * def.hits * entry.count
			end
		end
	end
	return stock
end

-- Timber for a small walled Timber-tier base (GAME_DESIGN pacing: end of day 1 for a
-- free player): a 3 x 3 room (12 edges: 9 walls, a doorway with its door, 2 windows),
-- a Woodworking Bench, a campfire and 2 crates.
local function timberBaseCost(): number
	local plan = {
		["build.foundation_wood"] = 9,
		["build.wall_wood"] = 9,
		["build.doorway_wood"] = 1,
		["build.door_wood"] = 1,
		["build.window_wood"] = 2,
		["build.woodworking_bench"] = 1,
		["build.campfire"] = 1,
		["build.crate_wood"] = 2,
	}
	local total = 0
	for id, count in plan do
		for _, stack in Content.BuildPieces[id].cost do
			if stack.itemId == "item.timber" then
				total += stack.count * count
			end
		end
	end
	return total
end

return function(test: TestKit.Register)
	test("all the home timber there will ever be is below a Timber-tier base (Fog Runs needed)", function()
		local supply, cost = homeStock()["item.timber"] or 0, timberBaseCost()
		TestKit.truthy(supply < cost, `home gives {supply} timber in all, the base needs {cost}`)
	end)

	test("home starts with enough for the hook: tools, the first stations, a patched shelter", function()
		local stock = homeStock()
		-- Hatchet and pick (3 sticks + 3 stone each), a campfire, the Woodworking Bench and
		-- Stonecutter, 2 foundations, 2 walls, a doorway and its door; rope is 2 fiber each.
		TestKit.truthy((stock["item.sticks"] or 0) >= 3 + 3 + 6, "sticks")
		TestKit.truthy((stock["item.stone"] or 0) >= 3 + 3 + 5 + 6 + 10, "stone")
		TestKit.truthy((stock["item.timber"] or 0) >= 10 + 8 + 2 * 10 + 2 * 8 + 6 + 5, "timber")
		TestKit.truthy((stock["item.fiber"] or 0) >= 2 * (2 + 2 + 2 + 1 + 2 + 4) + 2, "fiber")
		TestKit.truthy((stock["item.scrap"] or 0) >= 3, "scrap for the first club")
	end)

	test("LDoE's home set: about 20 pines, 7 rocks, 5 scrap, 7 berry bushes and 20 reeds", function()
		local counts: { [string]: number } = {}
		for _, entry in Content.Tuning.home.nodes do
			counts[entry.nodeId] = (counts[entry.nodeId] or 0) + entry.count
		end
		TestKit.equal(counts["node.pine_tree"], 20)
		TestKit.equal(counts["node.boulder"], 7)
		TestKit.equal(counts["node.scrap_heap"], 5)
		TestKit.equal(counts["node.ember_bush"], 7)
		TestKit.equal(counts["node.reed_patch"], 20)
	end)

	test("home nodes never respawn; only water refills", function()
		local renewing = Content.Tuning.home.renewing
		for _, entry in Content.Tuning.home.nodes do
			local respawn = Gathering.homeRespawn(entry.nodeId, renewing)
			if entry.nodeId == "node.spring_pool" then
				TestKit.equal(respawn, nil, "the spring refills on its own timer")
			else
				TestKit.equal(respawn, Gathering.NEVER, entry.nodeId)
			end
		end
	end)

	test("a depleted home node stays down across save and load, forever", function()
		local def = Content.Nodes["node.pine_tree"]
		local rng = Rng.new(7)
		local now = 1_000_000
		local node = Gathering.new(def)
		for _ = 1, def.hits do
			node = (Gathering.hit(node, def, rng, now, Gathering.NEVER)) :: any
		end
		TestKit.equal(node.hitsLeft, 0, "chopped down")
		TestKit.equal(node.respawnAt, Gathering.NEVER)
		local saved = Gathering.toSave(node, def)
		TestKit.truthy(saved ~= nil, "a depleted node is saved")
		local years = now + 10 * 365 * 24 * 3600
		local loaded = Gathering.fromSave(saved, def, years)
		TestKit.equal(loaded.hitsLeft, 0, "still depleted years later")
		TestKit.equal(Gathering.isStanding(loaded, years), false)
		TestKit.equal(select(4, Gathering.hit(loaded, def, rng, years, Gathering.NEVER)), "depleted")
	end)

	test("a Fog Run node still respawns on its own timer", function()
		local def = Content.Nodes["node.boulder"]
		local node = Gathering.new(def)
		for _ = 1, def.hits do
			node = (Gathering.hit(node, def, Rng.new(1), 100)) :: any
		end
		TestKit.truthy(Gathering.isStanding(node, 100 + def.respawnSeconds), "respawned")
	end)

	test("a half-chopped node keeps its hits across save and load", function()
		local def = Content.Nodes["node.pine_tree"]
		local node = (Gathering.hit(Gathering.new(def), def, Rng.new(3), 100, Gathering.NEVER)) :: any
		local loaded = Gathering.fromSave(Gathering.toSave(node, def), def, 99999)
		TestKit.equal(loaded.hitsLeft, def.hits - 1)
	end)

	test("v7 profiles no longer carry home nodes (they live on the outpost)", function()
		local data: any = PlayerSchema.template()
		data.version = 6
		data.homeNodes = { ["node.pine_tree#1"] = { hitsLeft = 0, respawnAt = 5 } }
		data.inventory.equipment.quick = nil
		local ok = Migrations.run(data, PlayerSchema.migrations, PlayerSchema.VERSION)
		TestKit.truthy(ok, "migrates")
		TestKit.equal(data.homeNodes, nil, "homeNodes")
	end)
end
