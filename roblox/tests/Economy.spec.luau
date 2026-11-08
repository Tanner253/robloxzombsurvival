--!strict
-- Specs for the home economy (the developer, 2026-11-08: "getting way too many
-- resources... why would someone ever need to leave their base"). Home nodes are a
-- starter supply that regrows slowly on real time and survives restarts; the bulk of a
-- Timber-tier base must come from Fog Runs.
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Gathering = require("../src/shared/Domain/Gathering")
local Rng = require("../src/shared/Domain/Rng")
local Migrations = require("../src/shared/Domain/Migrations")
local PlayerSchema = require("../src/shared/Domain/PlayerSchema")

local DAY = 24 * 3600

-- Timber a home plot can give in one real day at most: every node whole at the start,
-- then regrowing as fast as its span allows (the shortest time, every time).
local function homeTimberPerDay(): number
	local total = 0
	for _, entry in Content.Tuning.home.nodes do
		local def = Content.Nodes[entry.nodeId]
		local perNode = 0
		for _, yield in def.yields do
			if yield.itemId == "item.timber" then
				perNode += yield.perHit * def.hits * (yield.chance or 1)
			end
		end
		if perNode > 0 then
			local span = Content.Tuning.home.regrowHours[entry.nodeId]
			local regrow = if span then span.min * 3600 else def.respawnSeconds
			local harvests = 1 + math.floor(DAY / regrow)
			total += entry.count * perNode * harvests
		end
	end
	return total
end

-- Timber for a small walled Timber-tier base (GAME_DESIGN pacing: end of day 1 for a
-- free player): a 3 x 3 room (12 edges: 9 walls, a doorway with its door, 2 windows),
-- a workbench, a campfire and 2 crates.
local function timberBaseCost(): number
	local plan = {
		["build.foundation_wood"] = 9,
		["build.wall_wood"] = 9,
		["build.doorway_wood"] = 1,
		["build.door_wood"] = 1,
		["build.window_wood"] = 2,
		["build.workbench"] = 1,
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
	test("home timber in a real day is well below a Timber-tier base (Fog Runs needed)", function()
		local supply, cost = homeTimberPerDay(), timberBaseCost()
		TestKit.truthy(supply < cost, `home gives {supply} timber a day, the base needs {cost}`)
	end)

	test("home starts with enough for the hook: hatchet, pick, workbench, campfire, first walls", function()
		local stock: { [string]: number } = {}
		for _, entry in Content.Tuning.home.nodes do
			local def = Content.Nodes[entry.nodeId]
			for _, yield in def.yields do
				if yield.chance == nil then
					stock[yield.itemId] = (stock[yield.itemId] or 0) + yield.perHit * def.hits * entry.count
				end
			end
		end
		-- Hatchet and pick (3 sticks + 3 stone each), workbench, campfire, 2 foundations
		-- and 2 walls; rope is 2 fiber each.
		TestKit.truthy((stock["item.sticks"] or 0) >= 3 + 3 + 6, "sticks")
		TestKit.truthy((stock["item.stone"] or 0) >= 3 + 3 + 6 + 5, "stone")
		TestKit.truthy((stock["item.timber"] or 0) >= 10 + 2 * 10 + 2 * 8, "timber")
		TestKit.truthy((stock["item.fiber"] or 0) >= 2 * (2 + 2) + 2, "fiber")
	end)

	test("every home node regrows over hours, not minutes", function()
		for _, entry in Content.Tuning.home.nodes do
			local span = Content.Tuning.home.regrowHours[entry.nodeId]
			TestKit.truthy(span ~= nil, `{entry.nodeId} has a regrow span`)
			TestKit.truthy((span :: any).min >= 1, `{entry.nodeId} regrows in at least an hour`)
		end
	end)

	test("a depleted node survives save and load until its regrow time", function()
		local def = Content.Nodes["node.pine_tree"]
		local rng = Rng.new(7)
		local now = 1_000_000
		local node = Gathering.new(def)
		local regrow = Gathering.regrowSeconds(Content.Tuning.home.regrowHours[def.id], 0.5) :: number
		for _ = 1, def.hits do
			node = (Gathering.hit(node, def, rng, now, regrow)) :: any
		end
		TestKit.equal(node.hitsLeft, 0, "chopped down")
		local saved = Gathering.toSave(node, def)
		TestKit.truthy(saved ~= nil, "a depleted node is saved")
		-- A restart an hour later: still down.
		local loaded = Gathering.fromSave(saved, def, now + 3600)
		TestKit.equal(loaded.hitsLeft, 0, "still depleted after a restart")
		TestKit.equal(Gathering.isStanding(loaded, now + 3600), false)
		-- After its regrow time it is whole again, and a whole node saves as nothing.
		local regrown = Gathering.fromSave(saved, def, now + regrow + 1)
		TestKit.equal(regrown.hitsLeft, def.hits, "regrown")
		TestKit.equal(Gathering.toSave(regrown, def), nil)
	end)

	test("a half-chopped node keeps its hits across save and load", function()
		local def = Content.Nodes["node.pine_tree"]
		local node = (Gathering.hit(Gathering.new(def), def, Rng.new(3), 100, 3600)) :: any
		local loaded = Gathering.fromSave(Gathering.toSave(node, def), def, 99999)
		TestKit.equal(loaded.hitsLeft, def.hits - 1)
	end)

	test("profiles from v4 gain an empty homeNodes table", function()
		local data: any = PlayerSchema.template()
		data.version = 4
		data.homeNodes = nil
		local ok = Migrations.run(data, PlayerSchema.migrations, PlayerSchema.VERSION)
		TestKit.truthy(ok, "migrates")
		TestKit.deepEqual(data.homeNodes, {}, "homeNodes")
	end)
end
