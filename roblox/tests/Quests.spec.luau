--!strict
-- Specs for Domain/Quests (the Ember Trail, LDOE_PARITY #48-50) and Domain/Unlocks.
local TestKit = require("./TestKit")
local Quests = require("../src/shared/Domain/Quests")
local Unlocks = require("../src/shared/Domain/Unlocks")
local Flags = require("../src/shared/Flags")
local Types = require("../src/shared/Types")
local Content = require("../src/shared/Data")

local T0 = 1_700_000_000

local DEFS: { [string]: Types.QuestDef } = {
	["quest.a"] = {
		id = "quest.a",
		order = 1,
		chapter = "One",
		name = "Alpha",
		description = "",
		objectives = {
			{ kind = "gather", itemId = "item.wood", count = 3 },
			{ kind = "kill", count = 1, flag = "fogRuns" },
		},
		rewards = { xp = 10 },
	},
	["quest.b"] = {
		id = "quest.b",
		order = 2,
		chapter = "One",
		name = "Bravo",
		description = "",
		prerequisite = "quest.a",
		objectives = { { kind = "equip", itemId = "item.bag" } },
		rewards = { xp = 10 },
	},
	["quest.c"] = {
		id = "quest.c",
		order = 3,
		chapter = "One",
		name = "Charlie",
		description = "",
		prerequisite = "quest.a",
		objectives = { { kind = "build", pieceId = "build.wall", count = 2 } },
		rewards = { xp = 10 },
	},
	["quest.d"] = {
		id = "quest.d",
		order = 4,
		chapter = "Two",
		name = "Delta",
		description = "",
		prerequisite = "quest.c",
		objectives = { { kind = "travel", locationId = "loc.x", flag = "fogRuns" } },
		rewards = { xp = 10 },
	},
}

local OFF: Quests.Flags = { fogRuns = false }
local ON: Quests.Flags = { fogRuns = true }
local NOTHING: Quests.Facts = { level = 1, equipped = {} }

return function(test: TestKit.Register)
	test("the first quest opens on a fresh state", function()
		local state = Quests.open(Quests.newState(), DEFS)
		TestKit.truthy(state.active["quest.a"], "quest.a open")
		TestKit.equal(state.active["quest.b"], nil, "quest.b waits on quest.a")
	end)

	test("events add to matching objectives, capped at their count", function()
		local state = Quests.open(Quests.newState(), DEFS)
		state = Quests.record(state, DEFS, OFF, { kind = "gather", itemId = "item.wood", count = 2 })
		state = Quests.record(state, DEFS, OFF, { kind = "gather", itemId = "item.stone", count = 5 })
		state = Quests.record(state, DEFS, OFF, { kind = "gather", itemId = "item.wood", count = 9 })
		TestKit.equal(state.active["quest.a"].progress["1"], 3)
	end)

	test("a quest completes itself on its last objective and opens what follows", function()
		local state = Quests.open(Quests.newState(), DEFS)
		state = Quests.record(state, DEFS, OFF, { kind = "gather", itemId = "item.wood", count = 3 })
		local settled, done = Quests.settle(state, DEFS, OFF, NOTHING, T0)
		TestKit.deepEqual(done, { "quest.a" })
		TestKit.equal(settled.completed["quest.a"], T0)
		TestKit.truthy(settled.active["quest.b"] and settled.active["quest.c"], "both branches open")
	end)

	test("flagged objectives are left out while their flag is off", function()
		local state = Quests.open(Quests.newState(), DEFS)
		state = Quests.record(state, DEFS, ON, { kind = "gather", itemId = "item.wood", count = 3 })
		local _, done = Quests.settle(state, DEFS, ON, NOTHING, T0)
		TestKit.equal(#done, 0, "with Fog Runs on, the kill is still needed")
		local killed = Quests.record(state, DEFS, ON, { kind = "kill", enemyId = "enemy.any" })
		local _, after = Quests.settle(killed, DEFS, ON, NOTHING, T0)
		TestKit.deepEqual(after, { "quest.a" })
	end)

	test("state objectives count what is already true, and chains settle in one call", function()
		local state = Quests.open(Quests.newState(), DEFS)
		state = Quests.record(state, DEFS, OFF, { kind = "gather", itemId = "item.wood", count = 3 })
		local _, done = Quests.settle(state, DEFS, OFF, { level = 1, equipped = { ["item.bag"] = true } }, T0)
		TestKit.deepEqual(done, { "quest.a", "quest.b" }, "the bag was already worn")
	end)

	test("a quest whose every objective waits on a flag stays open and off the tracker", function()
		local state = Quests.open(Quests.newState(), DEFS)
		state.completed["quest.a"] = T0
		state.completed["quest.c"] = T0
		state.active["quest.a"] = nil
		state = Quests.open(state, DEFS)
		local settled, done = Quests.settle(state, DEFS, OFF, NOTHING, T0)
		TestKit.equal(#done, 0)
		TestKit.truthy(settled.active["quest.d"], "open")
		TestKit.truthy(Quests.isDormant(DEFS["quest.d"], OFF), "dormant")
		for _, row in Quests.tracker(settled, DEFS, OFF) do
			TestKit.truthy(row.questId ~= "quest.d", "not tracked")
		end
	end)

	test("the tracker lists up to 3 quests in trail order with the next step", function()
		local state = Quests.open(Quests.newState(), DEFS)
		state = Quests.record(state, DEFS, OFF, { kind = "gather", itemId = "item.wood", count = 3 })
		state = Quests.settle(state, DEFS, OFF, NOTHING, T0)
		state = Quests.record(state, DEFS, OFF, { kind = "build", pieceId = "build.wall" })
		local rows = Quests.tracker(state, DEFS, OFF)
		TestKit.equal(#rows, 2)
		TestKit.equal(rows[1].questId, "quest.b")
		TestKit.equal(rows[2].questId, "quest.c")
		TestKit.equal(rows[2].objectives[1].have, 1)
		TestKit.equal(rows[2].objectives[1].need, 2)
		TestKit.equal(rows[2].nextIndex, 1)
		TestKit.equal(#Quests.tracker(state, DEFS, OFF, 1), 1, "capped")
	end)

	test("the real Ember Trail runs at home from quest 1 to 8 with Fog Runs off", function()
		local flags = { fogRuns = false }
		local state = Quests.open(Quests.newState(), Content.Quests)
		local facts: Quests.Facts = { level = 1, equipped = {} }
		local completed: { string } = {}
		-- Play every open quest's objectives until nothing more completes.
		for _ = 1, 20 do
			for id in state.active do
				for _, objective in Quests.objectives(Content.Quests[id], flags) do
					if objective.kind == "equip" then
						facts.equipped[objective.itemId] = true
					elseif objective.kind ~= "reachLevel" then
						local event: Quests.Event = table.clone(objective :: any)
						state = Quests.record(state, Content.Quests, flags, event)
					end
				end
			end
			local done
			state, done = Quests.settle(state, Content.Quests, flags, facts, T0)
			for _, id in done do
				table.insert(completed, id)
			end
		end
		TestKit.equal(#completed, 8, "home and first-weapon quests complete")
		TestKit.equal(completed[1], "quest.first_light")
		TestKit.truthy(state.active["quest.scavenger"], "the Fog quest waits, open")
		TestKit.truthy(Quests.isDormant(Content.Quests["quest.scavenger"], flags))
	end)

	test("Unlocks: quest gates, lock text and what a quest unlocks", function()
		local progress: Unlocks.Progress = {
			level = 1,
			unlocks = { recipes = {}, blueprints = {} },
			quests = { completed = {} },
		}
		local gate: Types.UnlockGate = { kind = "quest", questId = "quest.keep_the_fire" }
		TestKit.equal(Unlocks.isMet(gate, progress), false);
		(progress.quests :: any).completed["quest.keep_the_fire"] = T0
		TestKit.equal(Unlocks.isMet(gate, progress), true)
		local names = { items = Content.Items :: any, quests = Content.Quests :: any }
		TestKit.equal(Unlocks.text(gate, names), "Complete the 'Keep the Fire' quest")
		TestKit.equal(Unlocks.text({ kind = "default" }, names), nil)
		-- The tile's short form: the quest's place on the trail.
		TestKit.equal(Unlocks.short(gate, names), `Ember Trail {Content.Quests["quest.keep_the_fire"].order}`)
		TestKit.equal(Unlocks.short({ kind = "level", level = 6 }, names), "Level 6")
		local recipes, pieces =
			Unlocks.byQuest("quest.keep_the_fire", Content.Recipes :: any, Content.BuildPieces :: any)
		TestKit.truthy(table.find(recipes, "recipe.cloth") ~= nil, "cloth")
		TestKit.truthy(table.find(pieces, "build.workbench") ~= nil, "workbench")
	end)

	test("only the hatchet, pick, satchel, its cord and the small crate start unlocked", function()
		local starters: { string } = {}
		for id, recipe in Content.Recipes do
			if recipe.unlock.kind == "default" then
				table.insert(starters, id)
			end
		end
		for id, piece in Content.BuildPieces do
			if piece.unlock == nil or piece.unlock.kind == "default" then
				table.insert(starters, id)
			end
		end
		table.sort(starters)
		TestKit.deepEqual(starters, {
			"build.crate_wood",
			"recipe.rope",
			"recipe.satchel",
			"recipe.stone_hatchet",
			"recipe.stone_pick",
		})
	end)

	test("gear is crafted by hand; stations only refine materials", function()
		for id, recipe in Content.Recipes do
			local out = Content.Items[recipe.outputs[1].itemId]
			local gear = out.category == "tool"
				or out.category == "weapon"
				or out.category == "armor"
				or out.category == "bag"
			if gear then
				TestKit.equal(recipe.stationId, nil, `{id} is crafted by hand`)
			end
		end
	end)

	test("flags: defaults on live servers, Workspace overrides only in Studio", function()
		TestKit.equal(Flags.resolve("fogRuns", false, true), false, "live ignores overrides")
		TestKit.equal(Flags.resolve("fogRuns", true, true), true, "Studio override")
		TestKit.equal(Flags.resolve("ldoeStations", true, nil), true, "default on")
		TestKit.equal(Flags.on("ldoeHud"), false, "Lune runs the defaults")
	end)
end
