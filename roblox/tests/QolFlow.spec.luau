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
end
