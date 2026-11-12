--!strict
--[[
	Feature flags: content behind an off flag is left out of the bundle, and the full
	bundle (every flag on) is valid too, so turning Fog Runs on is a one-line change.
]]

local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local DataValidator = require("../src/shared/Domain/DataValidator")
local Features = require("../src/shared/Features")
local TableUtil = require("../src/shared/Util/Table")

-- The raw content modules (nothing stripped), as a fresh mutable copy.
local function rawContent(): any
	return TableUtil.deepCopy({
		Items = require("../src/shared/Data/Items"),
		Recipes = require("../src/shared/Data/Recipes"),
		Stations = require("../src/shared/Data/Stations"),
		Nodes = require("../src/shared/Data/Nodes"),
		LootTables = require("../src/shared/Data/LootTables"),
		Enemies = require("../src/shared/Data/Enemies"),
		Locations = require("../src/shared/Data/Locations"),
		BuildPieces = require("../src/shared/Data/BuildPieces"),
		Levels = require("../src/shared/Data/Levels"),
		Quests = require("../src/shared/Data/Quests"),
		Products = require("../src/shared/Data/Products"),
		Projects = require("../src/shared/Data/Projects"),
		StarterShelter = require("../src/shared/Data/StarterShelter"),
		Tuning = require("../src/shared/Data/Tuning"),
	})
end

local function withFeatures(on: boolean): any
	local content = rawContent()
	for name in content.Tuning.features do
		content.Tuning.features[name] = on
	end
	return Features.strip(content)
end

local function report(errors: { string })
	if #errors > 0 then
		error(`{#errors} content error(s):\n        ` .. table.concat(errors, "\n        "), 0)
	end
end

return function(test: TestKit.Register)
	test("Fog Runs ship on (F-01): its recipes, station and build piece are in the game", function()
		TestKit.equal(Content.Tuning.features.fogRuns, true, "flag")
		TestKit.truthy(Content.Recipes["recipe.pipe_pistol"], "gun recipe")
		TestKit.truthy(Content.Recipes["recipe.cooked_meat"], "the campfire's venison (Raw Venison is a quest reward)")
		TestKit.truthy(Content.BuildPieces["build.doormat"], "build piece")
	end)

	test("F-21: the Smoke Rack waits for wildlife: no station, piece or line, and no quest asks", function()
		TestKit.equal(Content.Tuning.features.wildlife, false, "deer and wolves are deferred")
		TestKit.equal(Content.Stations["station.smoke_rack"], nil, "station")
		TestKit.equal(Content.BuildPieces["build.smoke_rack"], nil, "build piece")
		TestKit.equal(Content.Recipes["recipe.smoked_meat"], nil, "recipe")
		local Quests = require("../src/shared/Domain/Quests")
		local Flags = require("../src/shared/Flags")
		for id, quest in Content.Quests do
			for _, objective in Quests.objectives(quest, Flags.DEFAULTS) do
				local o: any = objective
				TestKit.truthy(o.pieceId ~= "build.smoke_rack", `{id} doesn't ask for the rack`)
				TestKit.truthy(o.recipeId ~= "recipe.smoked_meat", `{id} doesn't ask for smoked venison`)
			end
		end
		-- Nothing spawns deer while they are deferred, so nothing else may need venison.
		for id, enemy in Content.Enemies do
			if enemy.wildlife then
				TestKit.truthy(enemy.deferred ~= nil, `{id} still deferred: switch features.wildlife on with it`)
			end
		end
	end)

	test("with Fog Runs switched off, its recipes, station and build piece are left out", function()
		local content = rawContent()
		content.Tuning.features.fogRuns = false
		content = Features.strip(content)
		TestKit.equal(content.Recipes["recipe.pipe_pistol"], nil, "gun recipe")
		TestKit.equal(content.Stations["station.smoke_rack"], nil, "station")
		TestKit.equal(content.BuildPieces["build.doormat"], nil, "build piece")
		TestKit.truthy(content.Recipes["recipe.plank"], "untagged recipes stay")
		TestKit.truthy(content.Items["item.pipe_pistol"], "items stay (only Fog Run loot drops them)")
	end)

	test("the full bundle with every feature on is valid", function()
		local content = withFeatures(true)
		TestKit.truthy(content.Recipes["recipe.scrap_shotgun"], "tagged recipe kept")
		TestKit.truthy(content.Stations["station.smoke_rack"], "tagged station kept")
		report(DataValidator.validate(content))
	end)

	test("the bundle with every feature off is valid", function()
		report(DataValidator.validate(withFeatures(false)))
	end)

	test("untagged content that needs stripped content fails validation", function()
		local content = rawContent()
		content.Recipes["recipe.plank"].stationId = "station.smoke_rack"
		content.Tuning.features.fogRuns = false
		local errors = DataValidator.validate(Features.strip(content))
		TestKit.anyContains(errors, "Recipes['recipe.plank']: unknown station 'station.smoke_rack'")
	end)

	test("a tag must name a real flag", function()
		local content = rawContent()
		content.Recipes["recipe.plank"].feature = "jetpacks"
		local errors = DataValidator.validate(content)
		TestKit.anyContains(errors, "Recipes['recipe.plank']: unknown feature 'jetpacks'")
	end)

	test("Features.on reads Tuning.features", function()
		local tuning = rawContent().Tuning
		tuning.features.fogRuns = true
		TestKit.equal(Features.on(tuning, "fogRuns"), true)
		TestKit.equal(Features.on(tuning, "aiRaiders"), false)
	end)
end
