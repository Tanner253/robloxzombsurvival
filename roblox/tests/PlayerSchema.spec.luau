--!strict
local TestKit = require("./TestKit")
local Migrations = require("../src/shared/Domain/Migrations")
local PlayerSchema = require("../src/shared/Domain/PlayerSchema")
local Tuning = require("../src/shared/Data/Tuning")

-- DataStores store JSON: only strings, finite numbers, booleans and tables whose keys
-- are either all strings or a dense 1..n array. Returns a problem path or nil.
local function dataStoreProblem(value: any, path: string): string?
	local kind = type(value)
	if kind == "number" then
		return if value == value and math.abs(value) ~= math.huge then nil else `{path}: non-finite number`
	elseif kind == "string" or kind == "boolean" then
		return nil
	elseif kind ~= "table" then
		return `{path}: {kind} cannot be saved`
	end
	local count, stringKeys = 0, 0
	for key, child in value do
		count += 1
		if type(key) == "string" then
			stringKeys += 1
		elseif type(key) ~= "number" then
			return `{path}: unsupported key type`
		end
		local problem = dataStoreProblem(child, `{path}.{tostring(key)}`)
		if problem then
			return problem
		end
	end
	if stringKeys > 0 and stringKeys < count then
		return `{path}: mixes string and number keys`
	end
	if stringKeys == 0 and count ~= #value then
		return `{path}: array has holes`
	end
	return nil
end

return function(test: TestKit.Register)
	test("template is at the current version", function()
		TestKit.equal(PlayerSchema.template().version, PlayerSchema.VERSION)
	end)

	test("every older version has a migration step", function()
		for version = 1, PlayerSchema.VERSION - 1 do
			TestKit.truthy(PlayerSchema.migrations[version], `missing migration {version} -> {version + 1}`)
		end
	end)

	test("template is DataStore-safe", function()
		local problem = dataStoreProblem(PlayerSchema.template(), "data")
		TestKit.equal(problem, nil, "problem")
	end)

	test("template uses Tuning for sizes and has every ARCHITECTURE section", function()
		local data = PlayerSchema.template()
		TestKit.equal(#data.inventory.pockets, Tuning.inventory.pocketSlots, "pockets")
		TestKit.equal(#data.inventory.backpack, Tuning.inventory.backpackSlots, "backpack")
		TestKit.equal(data.energy.value, Tuning.energy.cap, "energy")
		for _, section in
			{ "storage", "lockedStash", "stations", "crops", "progression", "quests", "unlocks", "purchases", "raid" }
		do
			TestKit.truthy((data :: any)[section], section)
		end
		TestKit.deepEqual(data.purchases.receiptIds, {}, "receipt log")
	end)

	test("template returns a fresh table each call", function()
		local a = PlayerSchema.template()
		a.inventory.pockets[1].count = 5
		TestKit.equal(PlayerSchema.template().inventory.pockets[1].count, 0)
	end)

	test("migrations run in order and stamp each version", function()
		local data: { [string]: any } = { version = 1, gold = 5 }
		local steps: Migrations.Steps = {
			[1] = function(d)
				d.coins = d.gold
				d.gold = nil
			end,
			[2] = function(d)
				d.coins *= 10
			end,
		}
		local ok, reason = Migrations.run(data, steps, 3)
		TestKit.truthy(ok, reason)
		TestKit.equal(data.version, 3, "version")
		TestKit.equal(data.coins, 50, "coins")
	end)

	test("migrations refuse newer, unversioned or unmigratable data", function()
		local newer = { version = 9 }
		local ok, reason = Migrations.run(newer, {}, 1)
		TestKit.equal(ok, false)
		TestKit.truthy(string.find(reason :: string, "newer", 1, true), reason)
		TestKit.equal(newer.version, 9, "newer data untouched")

		TestKit.equal((Migrations.run({}, {}, 1)), false, "unversioned")
		TestKit.equal((Migrations.run({ version = 1 }, {}, 2)), false, "missing step")
	end)

	test("a failing migration step is reported, not thrown", function()
		local ok, reason = Migrations.run({ version = 1 }, {
			[1] = function()
				error("boom")
			end,
		}, 2)
		TestKit.equal(ok, false)
		TestKit.truthy(string.find(reason :: string, "boom", 1, true), reason)
	end)
end
