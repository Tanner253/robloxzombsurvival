--!strict
--[[
	Data/FogRegions, the Fog map screen as data: every pin is a real location, every
	fixed or rotating location has a pin, pictures name uploaded sprites, and everything
	sits on the canvas with room for the pin labels.
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local TestKit = require("./TestKit")

-- The region data uses Vector2; Lune has it in its roblox library, not as a global.
local env: any = getfenv()
env.Vector2 = roblox.Vector2

local Content = require("../src/shared/Data")
local FogRegions = require("../src/shared/Data/FogRegions")

local ART = fs.readFile("src/shared/Art.luau")

local function onCanvas(at: Vector2, margin: number): boolean
	return at.X >= -margin and at.X <= 1 + margin and at.Y >= -margin and at.Y <= 1 + margin
end

local function hasSprite(name: string): boolean
	return string.find(ART, `\n%s*{name} = "rbxassetid://%d+"`) ~= nil
end

return function(test: TestKit.Register)
	test("every pin is a real location, pinned once, inside the canvas", function()
		local seen: { [string]: boolean } = {}
		for _, region in FogRegions.list do
			for _, pin in region.pins do
				TestKit.truthy(Content.Locations[pin.locationId] ~= nil, `{pin.locationId} is a location`)
				TestKit.truthy(not seen[pin.locationId], `{pin.locationId} pinned once`)
				seen[pin.locationId] = true
				TestKit.truthy(onCanvas(pin.at, -0.04), `{pin.locationId} sits inside the canvas`)
			end
		end
	end)

	test("every pinned location has panel and loading art", function()
		for _, region in FogRegions.list do
			for _, pin in region.pins do
				local found = string.find(ART, `["{pin.locationId}"] = "rbxassetid://`, 1, true)
				TestKit.truthy(found ~= nil, `{pin.locationId} has art`)
			end
		end
	end)

	test("every fixed or rotating location has a pin (airdrops are placed live)", function()
		for id, location in Content.Locations do
			local kind = (location :: any).availability.kind
			if kind == "always" or kind == "rotating" then
				local region, pin = FogRegions.pinOf(id)
				TestKit.truthy(region ~= nil and pin ~= nil, `{id} has a pin`)
			end
		end
	end)

	test("event pins are rotating locations, and v0.1 has exactly one", function()
		local events = 0
		for _, region in FogRegions.list do
			for _, pin in region.pins do
				local location = Content.Locations[pin.locationId] :: any
				local rotating = location.availability.kind == "rotating"
				TestKit.equal(pin.event == true, rotating, `{pin.locationId}: event pin iff rotating`)
				if pin.event then
					events += 1
				end
			end
		end
		TestKit.equal(events, 1, "one rotating event location in v0.1")
	end)

	test("pins and the outpost keep room for their labels", function()
		for _, region in FogRegions.list do
			local spots: { { name: string, at: Vector2 } } = { { name = "home", at = region.home } }
			for _, pin in region.pins do
				table.insert(spots, { name = pin.locationId, at = pin.at })
			end
			for i = 1, #spots do
				for j = i + 1, #spots do
					local gap = (spots[i].at - spots[j].at).Magnitude
					TestKit.truthy(gap >= 0.12, `{spots[i].name} and {spots[j].name} are {gap} apart`)
				end
			end
		end
	end)

	test("neighbour slots sit on the canvas, apart, and clear of the pins and the outpost", function()
		for _, region in FogRegions.list do
			TestKit.truthy(#region.neighbourSlots >= 6, "room for a handful of neighbours")
			for index, slot in region.neighbourSlots do
				TestKit.truthy(onCanvas(slot, -0.04), `slot {index} inside the canvas`)
				TestKit.truthy((slot - region.home).Magnitude >= 0.1, `slot {index} clear of the outpost`)
				for _, pin in region.pins do
					local gap = (slot - pin.at).Magnitude
					TestKit.truthy(gap >= 0.1, `slot {index} and {pin.locationId} are {gap} apart`)
				end
				for other = index + 1, #region.neighbourSlots do
					local gap = (slot - region.neighbourSlots[other]).Magnitude
					TestKit.truthy(gap >= 0.1, `slots {index} and {other} are {gap} apart`)
				end
			end
		end
	end)

	test("every picture names an uploaded sprite and every shape is on the canvas", function()
		for _, sprite in { "baseForest", "fog", "trees1", "trees2", "trees3", "trees4" } do
			TestKit.truthy(hasSprite(sprite), `{sprite} is uploaded`)
		end
		for _, region in FogRegions.list do
			for _, landmark in region.landmarks do
				TestKit.truthy(hasSprite(landmark.sprite), `landmark {landmark.sprite} is uploaded`)
				TestKit.truthy(onCanvas(landmark.at, 0.1), `landmark {landmark.sprite} on the canvas`)
			end
			for index, zone in region.zones do
				TestKit.truthy(hasSprite(zone.kind), `zone {index} ({zone.kind}) is uploaded`)
				TestKit.truthy(onCanvas(zone.at, 0.1), `zone {index} on the canvas`)
			end
			for index, path in region.paths do
				TestKit.truthy(#path.points >= 2, `path {index} has two points or more`)
				for _, point in path.points do
					TestKit.truthy(onCanvas(point, 0.05), `path {index} stays near the canvas`)
				end
			end
			for index, patch in region.woods do
				TestKit.truthy(patch.count > 0 and onCanvas(patch.at, 0), `woods {index}`)
			end
		end
	end)
end
