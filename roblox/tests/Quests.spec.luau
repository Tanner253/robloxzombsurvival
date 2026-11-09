--!strict
-- Specs for Domain/Quests (the Ember Trail, LDOE_PARITY #48-50) and Domain/Unlocks.
local TestKit = require("./TestKit")
local Quests = require("../src/shared/Domain/Quests")
local Unlocks = require("../src/shared/Domain/Unlocks")
local Flags = require("../src/shared/Flags")
local Types = require("../src/shared/Types")
local Content = require("../src/shared/Data")
local TableUtil = require("../src/shared/Util/Table")

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

	test("with Fog Runs on, the whole trail (quests 1-25) plays through in order", function()
		local flags = { fogRuns = true }
		local state = Quests.open(Quests.newState(), Content.Quests)
		local facts: Quests.Facts = { level = 1, equipped = {} }
		local completed: { string } = {}
		for _ = 1, 40 do
			for id in state.active do
				for _, objective in Quests.objectives(Content.Quests[id], flags) do
					if objective.kind == "equip" then
						facts.equipped[objective.itemId] = true
					elseif objective.kind == "reachLevel" then
						facts.level = math.max(facts.level, objective.level)
					else
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
		TestKit.equal(#completed, 25, "every quest completes")
		TestKit.equal(next(state.active), nil, "nothing left open")
		TestKit.equal(completed[#completed], "quest.hold_the_line", "the chapter 3 capstone comes last")
	end)

	test("chapter 3: each quest's rewards supply what the next one on its line makes or builds", function()
		-- The raw data: Fog Run recipes and pieces are stripped from the bundle while the flag is off.
		local Recipes = require("../src/shared/Data/Recipes")
		local Pieces = require("../src/shared/Data/BuildPieces")
		local Stations = require("../src/shared/Data/Stations")
		local function uses(quest: Types.QuestDef): { [string]: boolean }
			local items: { [string]: boolean } = {}
			for _, objective in quest.objectives do
				if objective.kind == "craft" then
					local recipe = Recipes[objective.recipeId]
					for _, input in recipe.inputs do
						items[input.itemId] = true
					end
					local station = if recipe.stationId then Stations[recipe.stationId] else nil
					for _, fuel in (if station and station.fuel then station.fuel.itemIds else {}) :: { string } do
						items[fuel] = true
					end
				elseif objective.kind == "build" then
					for _, cost in Pieces[objective.pieceId].cost do
						items[cost.itemId] = true
					end
				end
			end
			return items
		end
		for id, quest in Content.Quests do
			if quest.chapter ~= "Hold the Line" and id ~= "quest.into_the_black" then
				continue
			end
			local makers, supplied = 0, false
			for _, nextQuest in Content.Quests do
				if nextQuest.prerequisite == id then
					local needs = uses(nextQuest)
					if next(needs) ~= nil then
						makers += 1
						for _, reward in quest.rewards.items or {} do
							supplied = supplied or needs[reward.itemId] == true
						end
					end
				end
			end
			TestKit.truthy(makers == 0 or supplied, `{id}'s rewards feed none of what follows it`)
		end
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

	test("only the hatchet, pick, stake, satchel, its cord and the small crate start unlocked", function()
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
			"recipe.sharpened_stake",
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

	-- Location quests: the daily Ration cap (the content parity audit's BR-9) --------------------
	local DAY = 24 * 60 * 60
	local DAILY = Content.Tuning.locationQuests
	local CAP: Quests.RationCap = { itemId = "item.rations", perDay = 2 }
	local function stack(itemId: string, count: number): Types.ItemStack
		return { itemId = itemId, count = count }
	end
	local function lq(id: string, rations: number, extra: { Types.ItemStack }?): Types.LocationQuest
		local items = table.clone(extra or {})
		if rations > 0 then
			table.insert(items, 1, stack("item.rations", rations))
		end
		return { id = id, name = id, description = "", objectives = {}, rewards = { xp = 100, items = items } }
	end
	local function countIn(items: { Types.ItemStack }?, itemId: string): number
		local total = 0
		for _, entry in (items or {}) :: { Types.ItemStack } do
			total += if entry.itemId == itemId then entry.count else 0
		end
		return total
	end

	test("location quests pay at most 2 Trail Rations a UTC day in all; the rest of the reward stays", function()
		local big = lq("quest.big", 3, { stack("item.scrap", 4) })
		local small = lq("quest.small", 1, { stack("item.cloth", 2) })
		local plain = lq("quest.plain", 0, { stack("item.coil_spring", 1) })
		local defs = { [big.id] = big, [small.id] = small, [plain.id] = plain }
		local now = 20_000 * DAY + 3600
		local first = Quests.payLocationQuest({}, big, defs, now, DAILY, CAP) :: Quests.LocationPayout
		TestKit.equal(countIn(first.rewards.items, "item.rations"), 2, "3 in the data, 2 paid")
		TestKit.equal(first.withheld, 1)
		TestKit.equal(countIn(first.rewards.items, "item.scrap"), 4, "the rest of the reward is paid")
		TestKit.equal(first.rewards.xp, 100)
		TestKit.equal(Quests.locationRationsPaid(first.log, defs, now, DAILY, CAP), 2)
		local second = Quests.payLocationQuest(first.log, small, defs, now + 600, DAILY, CAP) :: Quests.LocationPayout
		TestKit.equal(countIn(second.rewards.items, "item.rations"), 0, "the day's Rations are spent")
		TestKit.equal(second.withheld, 1)
		TestKit.equal(countIn(second.rewards.items, "item.cloth"), 2, "its cloth still pays")
		local third = Quests.payLocationQuest(second.log, plain, defs, now + 900, DAILY, CAP) :: Quests.LocationPayout
		TestKit.deepEqual(third.rewards.items, { stack("item.coil_spring", 1) }, "no Rations, nothing cut")
		TestKit.equal(third.withheld, 0)
		TestKit.equal(Quests.payLocationQuest(third.log, small, defs, now + 1200, DAILY, CAP), nil, "once a day")
		-- The next UTC day starts a fresh allowance.
		local tomorrow = Quests.payLocationQuest(third.log, small, defs, now + DAY, DAILY, CAP) :: Quests.LocationPayout
		TestKit.equal(countIn(tomorrow.rewards.items, "item.rations"), 1, "a new day")
		TestKit.equal(Quests.locationRationsPaid(tomorrow.log, defs, now + DAY, DAILY, CAP), 1)
		-- A cap of 0 pays none; the data itself is never changed.
		local none = Quests.payLocationQuest({}, big, defs, now, DAILY, { itemId = "item.rations", perDay = 0 })
		TestKit.equal(countIn((none :: Quests.LocationPayout).rewards.items, "item.rations"), 0)
		TestKit.equal(countIn(big.rewards.items, "item.rations"), 3, "data untouched")
	end)

	test("the real dailies pay 2 Rations a day in total, in any order, from what the profile keeps", function()
		local cap = Content.Tuning.energy.locationQuestRations
		TestKit.deepEqual(cap, CAP, "Tuning: 2 Trail Rations a day")
		local defs = Quests.locationQuestDefs(Content.Locations)
		local paying: { Types.LocationQuest } = {}
		local inData = 0
		for _, id in TableUtil.sortedKeys(defs) do
			local rations = countIn(defs[id].rewards.items, cap.itemId)
			if rations > 0 then
				table.insert(paying, defs[id])
				inData += rations
			end
		end
		TestKit.truthy(inData > cap.perDay, `the data pays {inData} a day, over the cap`)
		-- Every order of finishing them in one UTC day pays exactly the cap, and all their XP.
		local function orders(list: { Types.LocationQuest }): { { Types.LocationQuest } }
			if #list <= 1 then
				return { list }
			end
			local result: { { Types.LocationQuest } } = {}
			for index, first in list do
				local rest = table.clone(list)
				table.remove(rest, index)
				for _, tail in orders(rest) do
					table.insert(tail, 1, first)
					table.insert(result, tail)
				end
			end
			return result
		end
		local now = 20_000 * DAY + 60
		for _, order in orders(paying) do
			local log: Quests.LocationQuestLog = {}
			local paid, withheld, xp = 0, 0, 0
			for step, quest in order do
				local payout = Quests.payLocationQuest(log, quest, defs, now + step * 600, DAILY, cap)
				assert(payout, quest.id)
				log = payout.log
				paid += countIn(payout.rewards.items, cap.itemId)
				withheld += payout.withheld
				xp += payout.rewards.xp
			end
			TestKit.equal(paid, cap.perDay, "Rations paid in one day")
			TestKit.equal(paid + withheld, inData, "the rest held back")
			local expectedXp = 0
			for _, quest in order do
				expectedXp += quest.rewards.xp
			end
			TestKit.equal(xp, expectedXp, "XP is never cut")
			-- The tally comes from the saved log alone: no new profile field.
			TestKit.equal(Quests.locationRationsPaid(log, defs, now + DAY - 61, DAILY, cap), cap.perDay)
		end
	end)

	test("flags: defaults on live servers, Workspace overrides only in Studio", function()
		TestKit.equal(Flags.resolve("fogRuns", false, true), false, "live ignores overrides")
		TestKit.equal(Flags.resolve("fogRuns", true, true), true, "Studio override")
		TestKit.equal(Flags.resolve("ldoeStations", true, nil), true, "default on")
		TestKit.equal(Flags.on("ldoeHud"), Flags.DEFAULTS.ldoeHud, "Lune runs the defaults")
		TestKit.equal(Flags.on("vehicleFrame"), false, "the hauler is cut from v0.1")
	end)
end
