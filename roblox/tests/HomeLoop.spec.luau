--!strict
-- Specs for the home-loop domain modules: Slots, Progression, Gathering,
-- BuildRules, Salvage, and Crafting's per-item fuel burn times.
local TestKit = require("./TestKit")
local Slots = require("../src/shared/Domain/Slots")
local Progression = require("../src/shared/Domain/Progression")
local Gathering = require("../src/shared/Domain/Gathering")
local BuildRules = require("../src/shared/Domain/BuildRules")
local Salvage = require("../src/shared/Domain/Salvage")
local Crafting = require("../src/shared/Domain/Crafting")
local Grid = require("../src/shared/Domain/Grid")
local Inventory = require("../src/shared/Domain/Inventory")
local Rng = require("../src/shared/Domain/Rng")
local Content = require("../src/shared/Data")

local T0 = 1_700_000_000

local ITEMS: any = {
	["item.wood"] = { stackSize = 20, category = "resource" },
	["item.stone"] = { stackSize = 20, category = "resource" },
	["item.axe"] = { stackSize = 1, durability = 50, category = "tool", tool = { kind = "hatchet", tier = 1 } },
	["item.axe2"] = { stackSize = 1, durability = 80, category = "tool", tool = { kind = "hatchet", tier = 2 } },
	["item.pick"] = { stackSize = 1, durability = 50, category = "tool", tool = { kind = "pick", tier = 1 } },
	["item.hood"] = { stackSize = 1, durability = 100, category = "armor", equipSlot = "head" },
	["item.bag"] = { stackSize = 1, category = "bag", equipSlot = "bag" },
	["item.tin"] = { stackSize = 10, category = "consumable" },
}

local function slot(itemId: string, count: number, durability: number?): any
	return { itemId = itemId, count = count, durability = durability }
end

local function container(...: any): any
	return { ... }
end

local E = slot("", 0)

return function(test: TestKit.Register)
	-- Slots -------------------------------------------------------------------------
	test("Slots.move moves, merges and swaps whole stacks", function()
		local side = { slots = container(slot("item.wood", 5), E, slot("item.wood", 18), slot("item.stone", 3)) }
		local a = Slots.move(side, 1, side, 2, 2, ITEMS)
		TestKit.equal((a :: any)[1].count, 3, "split move leaves the rest")
		TestKit.equal((a :: any)[2].count, 2, "moved part")

		local b = Slots.move(side, 1, side, 3, nil, ITEMS)
		TestKit.equal((b :: any)[3].count, 20, "merge fills the stack")
		TestKit.equal((b :: any)[1].count, 3, "overflow stays")

		local c = Slots.move(side, 1, side, 4, nil, ITEMS)
		TestKit.equal((c :: any)[1].itemId, "item.stone", "swap")
		TestKit.equal((c :: any)[4].itemId, "item.wood", "swap back")

		local _, _, reason = Slots.move(side, 1, side, 4, 2, ITEMS)
		TestKit.equal(reason, "noSpace", "partial onto a different item")
		TestKit.equal(side.slots[1].count, 5, "input untouched")
	end)

	test("Slots.move respects equipment slot types", function()
		local pockets = { slots = container(slot("item.hood", 1, 70), slot("item.wood", 3)) }
		local equipment = {
			slots = Slots.fromEquipment({}),
			accepts = Slots.equipmentAccepts(),
		}
		local _, _, wrong = Slots.move(pockets, 2, equipment, 1, nil, ITEMS)
		TestKit.equal(wrong, "wrongSlot", "wood is not a hat")
		local _, _, wrongSlot = Slots.move(pockets, 1, equipment, 2, nil, ITEMS)
		TestKit.equal(wrongSlot, "wrongSlot", "a hood goes on the head")
		local newPockets, newEquipment = Slots.move(pockets, 1, equipment, 1, nil, ITEMS)
		TestKit.equal((newEquipment :: any)[1].durability, 70, "durability kept")
		TestKit.equal((newPockets :: any)[1].count, 0, "pocket emptied")
		TestKit.equal(Slots.toEquipment(newEquipment :: any).head.itemId, "item.hood", "record round trip")
	end)

	test("Slots.split, addTo and transfer", function()
		local split = Slots.split(container(slot("item.wood", 7), E), 1)
		TestKit.equal((split :: any)[1].count, 4)
		TestKit.equal((split :: any)[2].count, 3)
		TestKit.equal(select(2, Slots.split(container(slot("item.wood", 1)), 1)), "count", "single item")

		local targets, left = Slots.addTo(
			{ container(slot("item.wood", 19), E), container(slot("item.wood", 10)) },
			slot("item.wood", 15),
			ITEMS
		)
		TestKit.equal(left, 0)
		TestKit.equal(targets[1][1].count, 20, "tops up first")
		TestKit.equal(targets[2][1].count, 20, "then the other container's stack")
		TestKit.equal(targets[1][2].count, 4, "then empty slots")

		local sources, crates, moved = Slots.transfer(
			{ container(slot("item.wood", 5), slot("item.axe", 1, 40), slot("item.tin", 2)) },
			{ container(E, E) },
			ITEMS,
			Slots.putAllFilter(ITEMS)
		)
		TestKit.equal(moved, 5, "only materials move on Put all")
		TestKit.equal(crates[1][1].itemId, "item.wood")
		TestKit.equal(sources[1][2].itemId, "item.axe", "tools stay")
		TestKit.equal(sources[1][3].itemId, "item.tin", "food stays")
	end)

	test("Slots.wear breaks items at zero", function()
		local worn, broke = Slots.wear(slot("item.axe", 1, 2), 1)
		TestKit.equal(worn.durability, 1)
		TestKit.equal(broke, false)
		local gone, broken = Slots.wear(worn, 1)
		TestKit.equal(gone.count, 0)
		TestKit.equal(broken, true)
	end)

	-- Progression -----------------------------------------------------------------------
	test("Progression levels up through several levels and reports each", function()
		local levels = Content.Levels
		local state, reached = Progression.addXp({ level = 1, xp = 0 }, 1500, levels)
		TestKit.equal(state.level, 3)
		TestKit.equal(#reached, 2, "levels 2 and 3")
		TestKit.equal(reached[1].level, 2)
		local into, span, fraction = Progression.progress({ level = 2, xp = 1050 }, levels)
		TestKit.equal(into, 450)
		TestKit.equal(span, 900)
		TestKit.equal(fraction, 0.5)
		local _, _, capped = Progression.progress({ level = #levels, xp = 1e9 }, levels)
		TestKit.equal(capped, 1, "cap")
	end)

	-- Gathering -----------------------------------------------------------------------------
	test("Gathering picks the right tool and depletes and respawns nodes", function()
		local tree = Content.Nodes["node.pine_tree"]
		local pockets = container(slot("item.pick", 1, 50), slot("item.axe", 1, 50), slot("item.axe2", 1, 80))
		TestKit.equal((Gathering.pickTool(tree, pockets, 2, ITEMS)), 2, "held axe works")
		TestKit.equal((Gathering.pickTool(tree, pockets, 1, ITEMS)), 3, "best axe when holding a pick")
		local none, why = Gathering.pickTool(tree, container(slot("item.pick", 1, 50)), 1, ITEMS)
		TestKit.equal(none, nil)
		TestKit.equal(why, "needsTool")
		TestKit.equal((Gathering.pickTool(Content.Nodes["node.fallen_branches"], {}, 0, ITEMS)), 0, "by hand")

		local rng = Rng.new(7)
		local node = Gathering.new(tree)
		local total = 0
		local depleted = false
		for _ = 1, tree.hits do
			local nextNode, yields, done = Gathering.hit(node, tree, rng, T0)
			node = nextNode :: any
			total += yields[1].count
			depleted = done
		end
		TestKit.equal(total, tree.hits, "one timber per hit")
		TestKit.truthy(depleted, "last hit depletes")
		TestKit.equal(select(4, Gathering.hit(node, tree, rng, T0 + 1)), "depleted")
		TestKit.truthy(Gathering.isStanding(node, T0 + tree.respawnSeconds), "respawned")
		TestKit.equal(Gathering.refresh(node, tree, T0 + tree.respawnSeconds).hitsLeft, tree.hits)
	end)

	-- BuildRules ----------------------------------------------------------------------------------
	local function ctx(): Grid.Context
		return {
			plot = { ownerUserId = 1, width = 10, depth = 10 },
			actorUserId = 1,
			pieces = Content.BuildPieces,
			now = T0,
		}
	end
	local starter = { level = 1, unlocks = { recipes = {}, blueprints = {} } }

	test("BuildRules refuses upgraded tiers, locked pieces and plot limits", function()
		local layout = Grid.new()
		local _, notBase = BuildRules.canPlace(layout, "build.wall_scrap", { x = 0, z = 0, axis = "h" }, ctx(), starter)
		TestKit.equal(notBase, "notBase", "the wood-tier price can't be skipped")
		local _, locked = BuildRules.canPlace(layout, "build.recycler", { x = 0, z = 0 }, ctx(), starter)
		TestKit.equal(locked, "locked", "recycler is level 7")
		local _, bare = BuildRules.canPlace(layout, "build.workbench", { x = 0, z = 0 }, ctx(), starter)
		TestKit.equal(bare, "needsFoundation", "workbench needs a floor")
		local _, ground = BuildRules.canPlace(layout, "build.campfire", { x = 0, z = 0 }, ctx(), starter)
		TestKit.equal(ground, "needsFoundation", "furniture stands on foundations")

		local poor = Inventory.new(10, 0)
		local _, broke = BuildRules.canPlace(layout, "build.foundation_wood", { x = 1, z = 1 }, ctx(), starter, poor)
		TestKit.equal(broke, "cantAfford")

		for _, x in { 0, 1, 3 } do
			layout = (Grid.place(layout, "build.foundation_wood", { x = x, z = 5 }, ctx())) :: any
		end
		for index = 0, 1 do
			-- Quarter cells: cell (index, 5) starts at quarter (index * 4, 20).
			layout = (Grid.place(layout, "build.campfire", { x = index * 4, z = 20 }, ctx())) :: any
		end
		local _, limit = BuildRules.canPlace(layout, "build.campfire", { x = 12, z = 20 }, ctx(), starter)
		TestKit.equal(limit, "limit", "maxPerPlot")
		TestKit.equal(BuildRules.rootOf("build.wall_reinforced", Content.BuildPieces), "build.wall_wood")
	end)

	test("BuildRules gates upgrades by the next tier's unlock", function()
		local layout = Grid.new()
		layout = (Grid.place(layout, "build.foundation_wood", { x = 0, z = 0 }, ctx())) :: any
		local ok, nextDef, reason = BuildRules.canUpgrade(layout, "1", ctx(), starter)
		TestKit.equal(ok, false)
		TestKit.equal(reason, "locked")
		TestKit.equal((nextDef :: any).id, "build.foundation_scrap")
		TestKit.truthy((BuildRules.canUpgrade(layout, "1", ctx(), { level = 6, unlocks = starter.unlocks })), "level 6")
		local catalog = BuildRules.catalog(Content.BuildPieces)
		for _, def in catalog do
			TestKit.truthy(BuildRules.isBase(def.id, Content.BuildPieces), def.id)
		end
	end)

	-- Salvage ---------------------------------------------------------------------------------------
	test("Salvage queues, collects with rolls and cancels with the input's condition", function()
		local recycler = Content.Stations["station.recycler"]
		local station = Crafting.newStation("station.recycler")
		local vest = Content.Items["item.padded_vest"]
		local queued = Salvage.start(
			station,
			recycler,
			slot("item.padded_vest", 1, vest.durability :: number / 2),
			Content.Items,
			T0
		)
		TestKit.truthy(queued, "queued")
		local itemId, condition = Salvage.parse((queued :: any).queue[1].id)
		TestKit.equal(itemId, "item.padded_vest")
		TestKit.equal(condition, 0.5)
		TestKit.equal(
			select(2, Salvage.start(station, recycler, slot("item.timber", 1), Content.Items, T0)),
			"notSalvageable"
		)

		local _, refund = Salvage.cancel(queued :: any, 1, Content.Items, T0 + 5)
		TestKit.equal((refund :: any).durability, math.floor(vest.durability :: number * 0.5), "refund keeps condition")

		local inventory = Inventory.new(10, 0)
		local done = (queued :: any).queue[1].endsAt
		local after, newInventory, collected = Salvage.collect(
			queued :: any,
			recycler,
			inventory,
			Content.Items,
			Rng.new(3),
			done,
			{ durabilityScalesChance = true }
		)
		TestKit.equal(#after.queue, 0, "collected")
		TestKit.truthy(#collected >= 1, "cloth always drops")
		TestKit.truthy(Inventory.count(newInventory, "item.cloth") >= 2, "guaranteed output")
	end)

	test("Crafting burns each fuel for its own time", function()
		local campfire = Content.Stations["station.campfire"]
		local stocked = (Inventory.add(Inventory.new(10, 0), "item.fatwood", 2, Content.Items))
		local lit = Crafting.addFuel(Crafting.newStation("station.campfire"), campfire, stocked, "item.fatwood", 2, T0)
		TestKit.equal((lit :: any).fuelEndsAt, T0 + 2 * 6 * 60, "fatwood burns 6 minutes")
		TestKit.equal(Crafting.burnSeconds(campfire, "item.timber"), campfire.fuel.secondsPerUnit, "default")
	end)

	test("the progression ladder: hands -> sticks + stone -> hatchet -> timber -> planks", function()
		local nodes, recipes = Content.Nodes, Content.Recipes
		TestKit.equal(nodes["node.fallen_branches"].yields[1].itemId, "item.sticks", "branches give sticks")
		TestKit.equal(nodes["node.fallen_branches"].tool, nil, "by hand")
		for _, id in { "recipe.stone_hatchet", "recipe.stone_pick" } do
			local uses = {}
			for _, stack in recipes[id].inputs do
				uses[stack.itemId] = true
			end
			TestKit.truthy(uses["item.sticks"] and uses["item.stone"] and not uses["item.timber"], id)
		end
		-- Timber only from nodes that need a hatchet.
		for id, def in nodes do
			for _, yield in def.yields do
				if yield.itemId == "item.timber" then
					TestKit.truthy(def.tool and def.tool.kind == "hatchet", `{id} gives timber without a hatchet`)
				end
			end
		end
		TestKit.equal(recipes["recipe.plank"].inputs[1].itemId, "item.timber", "planks from timber")
	end)

	test("BuildRules.explain names what is missing, with have/need", function()
		local wall = Content.BuildPieces["build.wall_wood"]
		local inv = (Inventory.add(Inventory.new(10, 0), "item.timber", 3, Content.Items))
		local text = BuildRules.explain("cantAfford", wall, inv, Content.Items :: any, Content.BuildPieces :: any)
		TestKit.truthy(string.find(text, "Timber 3/", 1, true) ~= nil, text)
		local reinforced = Content.BuildPieces["build.wall_reinforced"]
		local locked = BuildRules.explain("locked", reinforced, inv, Content.Items :: any, Content.BuildPieces :: any)
		TestKit.truthy(string.find(locked, "blueprint", 1, true) ~= nil, locked)
		TestKit.equal(BuildRules.explain("occupied", wall, inv, Content.Items :: any), "Something is already there")
		local cost = BuildRules.costText(wall.cost, inv, Content.Items :: any)
		TestKit.truthy(string.find(cost, "Timber 3/", 1, true) ~= nil, cost)
	end)

	test("Slots.sort merges partial stacks, groups by category and keeps durability", function()
		local sorted = Slots.sort(
			container(slot("item.stone", 5), E, slot("item.axe", 1, 12), slot("item.stone", 18), slot("item.wood", 3)),
			ITEMS
		)
		TestKit.equal(sorted[1].itemId, "item.axe", "tools first")
		TestKit.equal(sorted[1].durability, 12, "worn tool keeps its durability")
		TestKit.equal(sorted[2].itemId, "item.stone")
		TestKit.equal(sorted[2].count, 20, "stones merged up to the stack size")
		TestKit.equal(sorted[3].itemId, "item.stone")
		TestKit.equal(sorted[3].count, 3, "the rest")
		TestKit.equal(sorted[4].itemId, "item.wood")
		TestKit.equal(sorted[5].count, 0, "empties last; same size")
		TestKit.equal(#sorted, 5)
	end)
end
