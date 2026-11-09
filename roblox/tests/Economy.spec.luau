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
local TableUtil = require("../src/shared/Util/Table")
local fs = require("@lune/fs")

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
		-- ECONOMY §5.4's hook: the hatchet and pick, the satchel, a Campfire, 2 Timber
		-- foundations and 2 walls, the Saw Bench, Stonecutter and Workbench. Planks, blocks
		-- and cord are expanded through their recipes. The trail's rewards on the way count
		-- (Claim the Ground's 10 timber and 4 cord, Tools of Survival's 6 fiber).
		local need: { [string]: number } = {}
		local function add(stacks: { { itemId: string, count: number } }, times: number)
			for _, stack in stacks do
				need[stack.itemId] = (need[stack.itemId] or 0) + stack.count * times
			end
		end
		add(Content.Recipes["recipe.stone_hatchet"].inputs, 1)
		add(Content.Recipes["recipe.stone_pick"].inputs, 1)
		add(Content.Recipes["recipe.satchel"].inputs, 1)
		for id, count in
			{
				["build.campfire"] = 1,
				["build.foundation_wood"] = 2,
				["build.wall_wood"] = 2,
				["build.woodworking_bench"] = 1,
				["build.stonecutter"] = 1,
				["build.workbench"] = 1,
			}
		do
			add(Content.BuildPieces[id].cost, count)
		end
		TestKit.equal((need["item.timber"] or 0), 54, "ECONOMY §11.4: 54 timber for the hook's pieces before planks")
		for _, recipeId in { "recipe.plank", "recipe.stone_block", "recipe.rope" } do
			local recipe = Content.Recipes[recipeId]
			local output = recipe.outputs[1]
			local made = need[output.itemId] or 0
			need[output.itemId] = nil
			add(recipe.inputs, math.ceil(made / output.count))
		end
		local stock = homeStock()
		for _, questId in { "quest.tools_of_survival", "quest.claim_the_ground" } do
			for _, stack in Content.Quests[questId].rewards.items or {} do
				stock[stack.itemId] = (stock[stack.itemId] or 0) + stack.count
			end
		end
		for _, itemId in TableUtil.sortedKeys(need) do
			TestKit.truthy(
				(stock[itemId] or 0) >= need[itemId],
				`{itemId}: home gives {stock[itemId] or 0}, the hook needs {need[itemId]}`
			)
		end
		TestKit.truthy((stock["item.scrap"] or 0) >= 3, "scrap for the first club")
	end)

	test("ECONOMY §1.3: the home plot is LDoE's set, exactly: 60 timber, 21 stone, 40 scrap", function()
		local stock = homeStock()
		TestKit.equal(stock["item.timber"], 60, "timber")
		TestKit.equal(stock["item.scrap"], 40, "scrap")
		local boulders = 0
		for _, entry in Content.Tuning.home.nodes do
			if entry.nodeId == "node.boulder" then
				boulders += entry.count * Content.Nodes["node.boulder"].hits
			end
		end
		TestKit.equal(boulders, 21, "stone from the boulders")
	end)

	test("Tuning.stationFallback lists exactly the converter stations with no approved model", function()
		-- Art.luau uses Roblox enums, so read Art.pieces from its source.
		local source = fs.readFile("src/shared/Art.luau")
		for _, piece in Content.BuildPieces do
			local stationId = piece.stationId
			if stationId == nil then
				continue
			end
			local escaped = (string.gsub(piece.id, "%.", "%%."))
			local models = string.match(source, '%["' .. escaped .. '"%] = (%b{})')
			if models == nil then
				continue -- not a kit-model piece
			end
			local pending = models == "{}"
			TestKit.equal(
				Content.Tuning.stationFallback[stationId] ~= nil,
				pending,
				`{stationId}: a fallback exactly while Art.pieces has no model for {piece.id}`
			)
		end
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
