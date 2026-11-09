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
		-- ECONOMY §5.4's hook: the stone tools, the satchel, a Campfire, 2 Timber
		-- foundations and 2 walls, the Saw Bench, Stonecutter and Workbench, plus First
		-- Light's Sharpened Stake. Planks, blocks and cord are expanded through their recipes.
		-- The trail's rewards on the way count (Claim the Ground's 20 timber and 4 cord, Tools
		-- of Survival's 6 fiber).
		local need: { [string]: number } = {}
		local function add(stacks: { { itemId: string, count: number } }, times: number)
			for _, stack in stacks do
				need[stack.itemId] = (need[stack.itemId] or 0) + stack.count * times
			end
		end
		-- As many stone tools as the home nodes wear through (41 rock and heap hits: 2 picks).
		local hits: { [string]: number } = {}
		for _, entry in Content.Tuning.home.nodes do
			local tool = Content.Nodes[entry.nodeId].tool
			if tool then
				hits[tool.kind] = (hits[tool.kind] or 0) + Content.Nodes[entry.nodeId].hits * entry.count
			end
		end
		for kind, recipeId in { hatchet = "recipe.stone_hatchet", pick = "recipe.stone_pick" } do
			local tool = Content.Items[Content.Recipes[recipeId].outputs[1].itemId]
			add(Content.Recipes[recipeId].inputs, math.ceil((hits[kind] or 0) / (tool.durability :: number)))
		end
		add(Content.Recipes["recipe.satchel"].inputs, 1)
		add(Content.Recipes["recipe.sharpened_stake"].inputs, 1)
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

	test("F-07: the plot's timber and the trail's pays for chapter 1's builds, with fuel to spare", function()
		-- Quests 1-7's build and craft objectives, and the fire line's Stonecutter and
		-- Workbench, with planks expanded through their recipe.
		local plank = Content.Recipes["recipe.plank"]
		local perPlank = plank.inputs[1].count / plank.outputs[1].count
		local function timberIn(stacks: { { itemId: string, count: number } }, times: number): number
			local total = 0
			for _, stack in stacks do
				if stack.itemId == "item.timber" then
					total += stack.count * times
				elseif stack.itemId == "item.plank" then
					total += stack.count * times * perPlank
				end
			end
			return total
		end
		local need, rewards = 0, 0
		for _, quest in Content.Quests do
			if quest.order > 7 then
				continue
			end
			for _, objective in quest.objectives do
				if objective.kind == "build" then
					need += timberIn(Content.BuildPieces[objective.pieceId].cost, objective.count)
				elseif objective.kind == "craft" then
					need += timberIn(Content.Recipes[objective.recipeId].inputs, objective.count)
				end
			end
			for _, stack in quest.rewards.items or {} do
				rewards += if stack.itemId == "item.timber" then stack.count else 0
			end
		end
		for _, id in { "build.stonecutter", "build.workbench" } do
			need += timberIn(Content.BuildPieces[id].cost, 1)
		end
		local supply = (homeStock()["item.timber"] or 0) + rewards
		TestKit.equal(rewards, 20, "Claim the Ground pays 20 timber")
		TestKit.equal(need, 87, "the builds (Data/Quests' header)")
		TestKit.truthy(supply >= need + 10, `{supply} timber against {need}: some left to burn`)
		-- The last tree says so, and the Guide points at the Trailhead.
		local gathering = fs.readFile("src/server/Services/Gathering.luau")
		TestKit.truthy(
			string.find(gathering, "Your plot's trees are gone for good. The Fog has more.", 1, true),
			"the toast"
		)
		local guide = fs.readFile("src/client/Controllers/Guide.luau")
		TestKit.truthy(string.find(guide, "return toTrailhead(`gather:", 1, true), "the Guide's pointer")
	end)

	test("ECONOMY §1.3: the home plot is LDoE's set plus 8 pines (F-07): 84 timber, 21 stone, 40 scrap", function()
		local stock = homeStock()
		TestKit.equal(stock["item.timber"], 84, "timber: LDoE's 60 and 8 more pines")
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

	test("LDoE's home set (20 pines, 7 rocks, 5 scrap, 7 berry bushes, 20 reeds) and F-07's 8 pines", function()
		local counts: { [string]: number } = {}
		for _, entry in Content.Tuning.home.nodes do
			counts[entry.nodeId] = (counts[entry.nodeId] or 0) + entry.count
		end
		TestKit.equal(counts["node.pine_tree"], 20 + 8)
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
