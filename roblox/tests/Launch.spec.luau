--!strict
--[[
	Launch specs (the flow review's F-01 and F-02): the publish build has Fog Runs on, no
	Ember Trail quest sits dormant, and every objective kind the trail and the location
	quests use has something on the server that reports it. A quest whose objective nothing
	reports soft-locks the trail behind it, which is how "Search the body" shipped unfinishable.
]]
local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local Quests = require("../src/shared/Domain/Quests")
local Flags = require("../src/shared/Flags")
local Types = require("../src/shared/Types")
local Content = require("../src/shared/Data")

-- Where each objective kind is reported from: the file, and the text that reports it.
-- Event kinds fire Events.played; state kinds ("equip", "reachLevel") are read from facts.
local EMITTERS: { [string]: { { file: string, text: string } } } = {
	gather = { { file = "src/server/Services/Gathering.luau", text = 'Events.played:Fire(player, { kind = "gather"' } },
	craft = { { file = "src/server/Services/Stations.luau", text = 'Events.played:Fire(player, { kind = "craft"' } },
	build = { { file = "src/server/Services/Building.luau", text = 'Events.played:Fire(player, { kind = "build"' } },
	consume = {
		{ file = "src/server/Services/Inventory.luau", text = 'Events.played:Fire(player, { kind = "consume"' },
	},
	travel = { { file = "src/server/Services/LocationQuests.luau", text = 'report(player, { kind = "travel"' } },
	kill = { { file = "src/server/Services/LocationQuests.luau", text = 'report(killer, { kind = "kill"' } },
	-- Containers says what was looted (a finished search on a container; a take from the pile a
	-- Hollow left), Domain/Quests.lootEvent names the event (specced below) and LocationQuests
	-- reports it. These lines only prove the wiring exists: the scripted Fog Run playtest
	-- (EO_Dev "kill", then ContainerTakeAll, then "queststate") proves it fires.
	loot = {
		{
			file = "src/server/Services/Containers.luau",
			text = 'Containers.looted:Fire(player, world.hosted, if state.kind == "pile" then "pile" else "container")',
		},
		{ file = "src/server/Services/LocationQuests.luau", text = "QuestsMath.lootEvent(source" },
	},
	lootBody = {
		{ file = "src/server/Services/Containers.luau", text = "if killer then killer.UserId else nil, true)" },
		{
			file = "src/server/Services/Containers.luau",
			text = 'Containers.looted:Fire(player, home.hosted, "hollowDrop")',
		},
		{ file = "src/server/Services/LocationQuests.luau", text = "QuestsMath.lootEvent(source" },
	},
	equip = { { file = "src/shared/Domain/Quests.luau", text = 'objective.kind == "equip" and facts.equipped[' } },
	reachLevel = { { file = "src/shared/Domain/Quests.luau", text = 'objective.kind == "reachLevel" and facts.level' } },
}

-- The moment-of-need offers (F-08, F-09): each hook a screen calls, the server effect a client
-- handles and the remotes a client sends. Domain/MomentOffers (its own spec) holds the rules;
-- these needles hold the wiring, which the specs can't run.
local OFFER_WIRING: { { file: string, text: string, why: string } } = {
	{ file = "src/client/UI/screens/RunHud.luau", text = "offers.gear", why = "the death screen's kit chip" },
	{ file = "src/client/UI/screens/RunHud.luau", text = "offers.buyEnergy", why = "the death screen's Refill" },
	{ file = "src/client/UI/screens/FogMap.luau", text = "offers.buyEnergy", why = "the Refill beside a greyed Run" },
	{ file = "src/client/Controllers/Shop.luau", text = 'kind == "energyShort"', why = "a client handles energyShort" },
	{ file = "src/client/UI/screens/FogMap.luau", text = "ui.energyShort", why = "the map shows the refusal" },
	{
		file = "src/client/UI/screens/RunHud.luau",
		text = 'Net.fire("RecoverAll", info.bagId, "premium")',
		why = "a client sends RecoverAll",
	},
	{ file = "src/client/UI/screens/RunHud.luau", text = "offers.buyEmbers", why = "short of Embers: the Pouch" },
	{ file = "src/client/UI/screens/RunHud.luau", text = 'Net.fire("DeathChoice"', why = "the screen's choice" },
	{
		file = "src/server/Services/Lobby.luau",
		text = 'Net.onEvent("DeathChoice"',
		why = "the run side waits for the choice",
	},
	{
		file = "src/server/Services/Lobby.luau",
		text = 'release(player, "lobbyClosed")',
		why = "the lobby ending counts as Continue",
	},
	{ file = "src/server/Services/Travel.luau", text = "Lobby.wantsReentry:Connect(reenter)", why = "Go back in" },
}

return function(test: TestKit.Register)
	test("F-08, F-09: the moment-of-need offers are wired end to end", function()
		for _, needle in OFFER_WIRING do
			local source = fs.readFile(needle.file)
			TestKit.truthy(string.find(source, needle.text, 1, true), `{needle.why}: {needle.file} has {needle.text}`)
		end
		local lobby = fs.readFile("src/server/Services/Lobby.luau")
		TestKit.truthy(
			not string.find(lobby, "DEATH_LINGER_SECONDS", 1, true),
			"no timer sends the dead home before they choose"
		)
	end)

	test("Studio checks run in god mode, and only in Studio", function()
		local lobby = fs.readFile("src/server/Services/Lobby.luau")
		TestKit.truthy(
			string.find(lobby, 'RunService:IsStudio() and player:GetAttribute("DevGod") == true', 1, true),
			"Lobby.hurtPlayer skips damage for a Studio tester in god mode"
		)
		local dev = fs.readFile("src/server/Services/Diagnostics.luau")
		TestKit.truthy(
			string.find(dev, 'player:SetAttribute("DevGod", true)', 1, true),
			"EO_Dev turns god mode on by default"
		)
	end)

	test("the inventory pane scrolls, so every backpack row can be reached", function()
		local pane = fs.readFile("src/client/UI/screens/ldoe/InventoryPane.luau")
		TestKit.truthy(
			string.find(pane, "local body = e(Parts.ScrollBody", 1, true),
			"InventoryPane's body is a ScrollBody"
		)
		local parts = fs.readFile("src/client/UI/screens/ldoe/Parts.luau")
		TestKit.truthy(
			string.find(parts, "AutomaticCanvasSize = Enum.AutomaticSize.Y", 1, true),
			"ScrollBody grows its canvas"
		)
	end)

	test("F-01: Fog Runs are on for the launch build", function()
		TestKit.equal((Content.Tuning.features :: any).fogRuns, true, "Tuning.features.fogRuns")
		TestKit.equal(Flags.DEFAULTS.fogRuns, true, "Flags follows the one switch")
	end)

	test("F-01: no Ember Trail quest is dormant under the launch flags", function()
		local flags = Flags.DEFAULTS
		for id, def in Content.Quests do
			TestKit.truthy(not Quests.isDormant(def, flags), `{id} has a live objective`)
			TestKit.truthy(next(Quests.objectives(def, flags)) ~= nil, `{id} has objectives`)
		end
	end)

	test("F-01: every objective kind in use has a server emitter", function()
		local used: { [string]: string } = {} -- kind -> a quest that uses it
		for id, def in Content.Quests do
			for _, objective in def.objectives do
				used[objective.kind] = id
			end
		end
		for _, location in Content.Locations :: { [string]: Types.LocationDef } do
			for _, quest in (if location.run and location.run.quests then location.run.quests else {}) :: { any } do
				for _, objective in quest.objectives do
					used[objective.kind] = quest.id
				end
			end
		end
		local sources: { [string]: string } = {}
		for kind, questId in used do
			local emitters = EMITTERS[kind]
			TestKit.truthy(
				emitters ~= nil,
				`"{kind}" ({questId}) has no emitter listed: add one, or the quest can't finish`
			)
			for _, emitter in emitters or {} do
				local source = sources[emitter.file] or fs.readFile(emitter.file)
				sources[emitter.file] = source
				TestKit.truthy(
					string.find(source, emitter.text, 1, true),
					`"{kind}" ({questId}): {emitter.file} no longer has {emitter.text}`
				)
			end
		end
	end)

	test("F-02: a Hollow's drop is the body search; other piles report nothing", function()
		TestKit.deepEqual(
			Quests.lootEvent("container", "loc.pine_hollow"),
			{ kind = "loot", locationId = "loc.pine_hollow", count = 1 }
		)
		TestKit.deepEqual(
			Quests.lootEvent("hollowDrop", "loc.pine_hollow"),
			{ kind = "lootBody", locationId = "loc.pine_hollow", count = 1 }
		)
		TestKit.equal(Quests.lootEvent("pile", "loc.pine_hollow"), nil, "a craft overflow or a spent arrow")
	end)

	test("F-02: Into the Fog finishes from the events a first run reports", function()
		local flags = Flags.DEFAULTS
		local def = Content.Quests["quest.into_the_fog"]
		TestKit.truthy(def ~= nil, "quest 6 exists")
		-- Quest 6 open, as it is once Keep the Fire is done.
		local state: Quests.State = { active = { [def.id] = { progress = {} } }, completed = {} }
		local facts: Quests.Facts = { level = 1, equipped = { ["item.satchel"] = true } }
		local events: { Quests.Event } = {
			{ kind = "craft", recipeId = "recipe.satchel", count = 1 },
			{ kind = "travel", locationId = "loc.pine_hollow", fogTier = 1 },
			{ kind = "kill", enemyId = "enemy.shambler", locationId = "loc.pine_hollow", count = 1 },
			Quests.lootEvent("hollowDrop", "loc.pine_hollow") :: Quests.Event,
		}
		for _, event in events do
			state = Quests.record(state, Content.Quests, flags, event)
		end
		TestKit.truthy(not Quests.isComplete(def, state.active[def.id], flags), "the satchel isn't worn yet")
		state = Quests.observe(state, Content.Quests, flags, facts)
		TestKit.truthy(Quests.isComplete(def, state.active[def.id], flags), "all five objectives met")
	end)
end
