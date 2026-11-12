--!strict
--[[
	2.0 batch 2: the flow review's quality-of-life and UX findings (docs/research/
	flow-mechanics-review.md). The rules live in pure Domain modules, specced here; where a
	finding is wiring (a screen must call a rule, a service must report an event), a needle
	holds it the way tests/Launch.spec does. Shop findings (F-10, F-11, F-12, F-26, F-27,
	F-28) are in Shop.spec, F-34 in ItemSources.spec, F-30 in Grid.spec, F-32 in Death.spec.
]]
local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local AutoClear = require("../src/shared/Domain/AutoClear")
local TravelMath = require("../src/shared/Domain/Travel")

local function has(file: string, text: string, why: string)
	TestKit.truthy(string.find(fs.readFile(file), text, 1, true), `{why}: {file} has {text}`)
end

return function(test: TestKit.Register)
	test("F-20: the AUTO button is priced from data, Rations and the Run's Energy", function()
		local config: any = Content.Tuning.autoClear
		TestKit.equal(AutoClear.label(AutoClear.price(1, 0, config)), "AUTO: 1 Ration")
		TestKit.equal(AutoClear.label(AutoClear.price(2, 22, config)), "AUTO: 2 Rations + 22 Energy")
		TestKit.equal(AutoClear.label(AutoClear.price(3, 30, config)), "AUTO: 3 Rations + 30 Energy")
		local price = AutoClear.price(2, 22, config)
		TestKit.equal(AutoClear.shortText(price, 1, 100), "AUTO needs 2 Trail Rations: you carry 1")
		TestKit.equal(AutoClear.shortText(price, 5, 10.6), "AUTO needs 22 Energy: you have 10")
		TestKit.equal(AutoClear.shortText(price, 5, 100), nil)
		-- Every location's button matches what the server charges (the same two functions).
		for _, location in Content.Locations do
			local run = TravelMath.plan(location :: any, "run", Content.Tuning.travel :: any).energyCost
			local label = AutoClear.label(AutoClear.price(location.fogTier, run, config))
			TestKit.truthy(
				string.find(label, tostring(AutoClear.rationsCost(location.fogTier, config)), 1, true),
				label
			)
		end
		has("src/client/UI/screens/FogMap.luau", "AutoClear.label(", "the button")
		has("src/server/Services/Travel.luau", "AutoClear.shortText(price", "the refusal")
		TestKit.equal(
			string.find(fs.readFile("src/client/UI/screens/FogMap.luau"), "clear it for 1 Ration", 1, true),
			nil,
			"no fixed price"
		)
	end)

	test("F-21: run deaths count toward the milestone gifts; the 20th sends the Ember Heart", function()
		local DeathRecovery = require("../src/shared/Domain/DeathRecovery")
		local config: any = Content.Tuning.deathRecovery
		local function gifts(before: number, after: number): { [string]: number }
			local result: { [string]: number } = {}
			for _, stack in DeathRecovery.milestoneGifts(before, after, config) do
				result[stack.itemId] = (result[stack.itemId] or 0) + stack.count
			end
			return result
		end
		TestKit.truthy(next(gifts(0, 1)) ~= nil, "the first death sends something")
		TestKit.equal(next(gifts(1, 2)), nil, "the second, nothing")
		TestKit.equal(gifts(19, 20)["item.reanimator"], 1, "the 20th: the Ember Heart")
		TestKit.equal(Content.Items["item.reanimator"].name, "Ember Heart")
		has("src/server/Services/Lobby.luau", "DeathRecovery.milestoneGifts(before, data.deaths", "run deaths count")
		has(
			"src/server/Services/Lobby.luau",
			"\tcountDeath(player)\n\tlocal result = applyDeath(",
			"on every run death"
		)
		TestKit.equal(
			string.find(fs.readFile("src/server/Services/Deaths.luau"), "milestoneGifts", 1, true),
			nil,
			"home deaths (a Reset) don't farm it"
		)
		-- The Rain Barrel's station screen has no input to fill (Converter.spec runs the barrel).
		has("src/client/UI/screens/ldoe/StationPane.luau", "Input = not passive and e(DropSlot", "no input slot")
	end)

	test("F-22: every quest line says where, and every step kind has a Guide pointer", function()
		local QuestText = require("../src/shared/Domain/QuestText")
		local Flags = require("../src/shared/Flags")
		local Quests = require("../src/shared/Domain/Quests")
		local content: any = Content
		local kinds: { [string]: boolean } = {}
		for id, quest in Content.Quests do
			for _, objective in Quests.objectives(quest, Flags.DEFAULTS) do
				local o: any = objective
				kinds[o.kind] = true
				local line = QuestText.objective(o, content)
				local recipe = o.recipeId and Content.Recipes[o.recipeId]
				if recipe and recipe.stationId then
					local station = Content.Stations[recipe.stationId]
					TestKit.truthy(string.find(line, `at the {station.name} and take it out`, 1, true), `{id}: {line}`)
				elseif o.kind == "loot" and o.locationId then
					TestKit.equal(line, `Search containers in {Content.Locations[o.locationId].name}`, id)
				elseif o.kind == "reachLevel" then
					TestKit.truthy(string.find(line, "XP", 1, true), `{id}: {line} says where XP comes from`)
				end
			end
		end
		TestKit.equal(
			QuestText.objective({ kind = "craft", recipeId = "recipe.plank", count = 1 }, content),
			`Make a {Content.Items["item.plank"].name} at the {Content.Stations[Content.Recipes["recipe.plank"].stationId :: string].name} and take it out`
		)
		-- The Guide has a pointer for every kind the trail uses.
		local guide = fs.readFile("src/client/Controllers/Guide.luau")
		for kind in kinds do
			TestKit.truthy(string.find(guide, `"{kind}"`, 1, true), `the Guide points somewhere for "{kind}"`)
		end
		has("src/client/UI/questText.luau", "QuestText.objective(objective, Content", "the tracker uses it")
		-- Water drunk from the inbox counts for a consume step, like water from the bag.
		has("src/server/Services/Inbox.luau", 'Events.played:Fire(player, { kind = "consume"', "InboxUse reports")
	end)

	test("F-33: the daily food and water gift ships on, for new survivors only", function()
		TestKit.equal(Content.Tuning.features.dailyGift, true, "LDOE_PARITY #58, on for launch")
		TestKit.truthy(Content.Tuning.dailyGift.untilLevel > 1, "until a level")
		TestKit.equal(
			string.find(fs.readFile("src/shared/Data/Tuning.luau"), "cut from v0.1", 1, true),
			nil,
			"no false reason left"
		)
	end)

	test("F-35: Haven asks only for what you can get, and takes it from the home pool", function()
		local Contracts = require("../src/shared/Domain/Contracts")
		local ItemSources = require("../src/shared/Domain/ItemSources")
		local fresh: any = { level = 1, unlocks = { recipes = {}, blueprints = {} }, quests = { completed = {} } }
		local pool: { Contracts.Contract } = Content.Haven.contracts.pool :: any
		local early = Contracts.eligible(pool, function(itemId: string): boolean
			return ItemSources.obtainable(Content :: any, itemId, fresh)
		end)
		local asked: { [string]: boolean } = {}
		for _, contract in early do
			asked[contract.itemId] = true
		end
		TestKit.truthy(asked["item.timber"], "timber is chopped from day one")
		TestKit.equal(asked["item.plank"], nil, "no Planks before the Saw Bench")
		TestKit.truthy(#early >= Content.Haven.contracts.perDay, "still a full board on day one")
		local everything: any = { level = 99, unlocks = { recipes = {}, blueprints = {} }, quests = { completed = {} } }
		for id in Content.Quests do
			everything.quests.completed[id] = 1
		end
		local late = Contracts.eligible(pool, function(itemId: string): boolean
			return ItemSources.obtainable(Content :: any, itemId, everything)
		end)
		TestKit.equal(#late, #pool, "the whole pool once the trail is done")
		local haven = "src/server/Services/Haven.luau"
		has(haven, 'Materials.take(player, { { itemId = itemId, count = count } }, "Trader")', "the Trader")
		has(
			haven,
			'Materials.take(player, { { itemId = contract.itemId, count = contract.count } }, "Contract")',
			"contracts"
		)
		has(haven, "Contracts.eligible(havenData.contracts.pool", "the board")
		has("src/client/UI/screens/ldoe/HavenPane.luau", "format.count(props.pooled, contract.itemId)", "have counts")
		has("src/client/UI/screens/ldoe/Panels.luau", "pooled = pooled,", "the pane gets the pool")
	end)

	test("F-38: every Ember Trail chapter, Into the Fog too, has a Trail Keeper reward", function()
		for _, quest in Content.Quests do
			local reward = Content.Haven.chapterRewards[quest.chapter]
			TestKit.truthy(reward ~= nil and (reward.coins > 0 or #reward.items > 0), quest.chapter)
		end
		TestKit.truthy(Content.Haven.chapterRewards["Into the Fog"] ~= nil, "chapter 2")
	end)

	test("F-36: a Walk is saved in the profile and resumes on the next visit", function()
		local trip: TravelMath.Trip = {
			destinationId = "loc.pine_hollow",
			mode = "walk",
			departedAt = 1000,
			arrivesAt = 1600,
			energySpent = 0,
		}
		local saved = TravelMath.saveWalk(trip) :: TravelMath.SavedWalk
		TestKit.deepEqual(
			saved,
			{ locationId = "loc.pine_hollow", departedAt = 1000, arrivesAt = 1600, energySpent = 0 }
		)
		local function exists(id: string): boolean
			return id == "loc.pine_hollow"
		end
		TestKit.deepEqual(TravelMath.resumeWalk(saved, exists), trip, "the same trip, same clock")
		TestKit.truthy(TravelMath.hasArrived(TravelMath.resumeWalk(saved, exists) :: any, 2000), "arrived while away")
		local run = table.clone(trip)
		run.mode = "run"
		TestKit.equal(TravelMath.saveWalk(run), nil, "a Run isn't kept")
		local back = table.clone(trip)
		back.reentry = true
		TestKit.equal(TravelMath.saveWalk(back), nil, "nor a trip back for a bag")
		TestKit.equal(TravelMath.resumeWalk({ locationId = "loc.gone", departedAt = 1, arrivesAt = 2 }, exists), nil)
		TestKit.equal(TravelMath.resumeWalk({ locationId = "loc.pine_hollow" }, exists), nil, "malformed")
		local travel = "src/server/Services/Travel.luau"
		has(travel, "data.travel.walk = if record and #record.members == 1 then TravelMath.saveWalk", "saved")
		has(travel, "TravelMath.resumeWalk(data.travel.walk", "resumed")
		has(travel, "trips[member] = record\n\t\tremember(member, record)", "saved when it starts")
	end)
end
