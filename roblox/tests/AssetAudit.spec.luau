--!strict
-- Specs for 2.0 batch 3 (performance and asset loading): the asset ids the source names
-- (Domain/AssetAudit against tests/KnownAssets), and needles that hold the load-time fixes.
local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local AssetAudit = require("../src/shared/Domain/AssetAudit")
local Art = require("../src/shared/Art")
local Known = require("./KnownAssets")

local function sources(dir: string, into: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			sources(path, into)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(into, path)
		end
	end
end

return function(test: TestKit.Register)
	test("ids: every rbxassetid once, in order", function()
		local text = 'a = "rbxassetid://12", b = "rbxassetid://7", c = "rbxassetid://12", d = "rbxasset://x"'
		TestKit.deepEqual(AssetAudit.ids(text), { 12, 7 })
		TestKit.deepEqual(AssetAudit.unknown({ 12, 7, 3 }, { [7] = "owner" }), { 3, 12 })
		TestKit.truthy(AssetAudit.useStoredCopy(5, 5))
		TestKit.equal(AssetAudit.useStoredCopy(nil, 5), false, "no copy")
		TestKit.equal(AssetAudit.useStoredCopy(4, 5), false, "a copy of another upload")
	end)

	test("every asset id in the source was checked (tests/KnownAssets)", function()
		local files: { string } = {}
		sources("src", files)
		local missing: { string } = {}
		for _, path in files do
			for _, id in AssetAudit.unknown(AssetAudit.ids(fs.readFile(path)), Known) do
				table.insert(missing, `{path}: {id}`)
			end
		end
		TestKit.deepEqual(missing, {}, "check each in Studio (creator, loads), then list it in tests/KnownAssets")
	end)

	test("every uploaded model is a known asset", function()
		for name, entry in Art.uploaded do
			TestKit.truthy(Known[entry.id] ~= nil, `{name} ({entry.id})`)
		end
	end)

	test("uploaded models come from the place's Studio-built copies first", function()
		local models = fs.readFile("src/server/World/Models.luau")
		local stored = string.find(models, "storedCopy(name, entry.id)", 1, true)
		local insert = string.find(models, ":LoadAsset(entry.id)", 1, true)
		TestKit.truthy(stored and insert and stored < insert, "EO_Uploaded before InsertService")
		TestKit.truthy(fs.isFile("tools/rebuild_uploaded.luau"), "the Studio tool that builds the copies")
	end)

	test("a map is Ready before its Hollow spawn checks, and Hollow wait for them", function()
		local maps = fs.readFile("src/server/FogRuns/Maps/init.luau")
		local ready = string.find(maps, 'root:SetAttribute("Ready", true)', 1, true)
		local checks = string.find(maps, "Maps.checkSpawns(root, locationId)", 1, true)
		TestKit.truthy(ready and checks and ready < checks, "Ready first, checks in the background")
		TestKit.truthy(string.find(maps, 'SetAttribute("SpawnsChecked", true)', 1, true) ~= nil)
		local hollow = fs.readFile("src/server/Services/Hollow.luau")
		TestKit.truthy(string.find(hollow, '"SpawnsChecked"', 1, true) ~= nil, "the first spawn waits")
		local travel = fs.readFile("src/server/Services/Travel.luau")
		TestKit.truthy(string.find(travel, "RunWorld.prepare(", 1, true) ~= nil, "Studio builds during the trip")
		TestKit.truthy(string.find(travel, "record.trip.departedAt)", 1, true) ~= nil, "the trip counts as waiting")
	end)

	test("the off hand's handguard point on a long gun stays within the arm's reach", function()
		local HoldRules = require("../src/shared/Domain/HoldRules")
		TestKit.equal(HoldRules.supportAt("pistol", 0.3, 1.2), nil, "pistols: no support point")
		TestKit.equal(HoldRules.supportAt("long", 0.31, 0.2), 0.31 + 0.4, "a tiny gun: 0.4 of its length")
		local amr = HoldRules.supportAt("long", 0.22, 4.7) :: number
		TestKit.truthy(math.abs((amr - 0.22) * 4.7 - HoldRules.SUPPORT_MAX_STUDS) < 1e-6, "a long one: capped in studs")
		TestKit.equal(HoldRules.supportWeight(true, true), 0, "lets go for a reload")
		TestKit.equal(HoldRules.supportWeight(false, true), 1, "holds on while aiming")
		TestKit.equal(HoldRules.supportWeight(false, false), 0, "a one-handed carry")
		for itemId, art in Art.held do
			local at = HoldRules.supportAt(HoldRules.classOf(itemId, nil), art.grip, art.length)
			if at then
				TestKit.truthy((at - art.grip) * art.length <= HoldRules.SUPPORT_MAX_STUDS + 1e-6, itemId)
			end
		end
	end)

	test("minimap blip keys are per instance, not full names", function()
		local radar = fs.readFile("src/client/Controllers/Radar.luau")
		TestKit.equal(string.find(radar, "{holder:GetFullName()}", 1, true), nil, "containers")
		TestKit.equal(string.find(radar, "{exit:GetFullName()}`,", 1, true), nil, "exits")
		TestKit.truthy(string.find(radar, 'keyOf("c", holder)', 1, true) ~= nil)
	end)
end
