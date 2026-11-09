--!strict
--[[
	Enemy rigs: the Hollow service only spawns kinds with a rig in
	place/kit/EO_Hollow.rbxm (checklist §0: nothing unseen), so every kind a location
	spawns, or a quest asks you to kill, must have one. A wildlife kind (deer, wolf) with a
	rig must also have a gait profile (Art.wildlifeRigs) whose every joint is a Motor6D of
	that rig. Wildlife is post-launch until our own rigs exist; no free models.
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local TestKit = require("./TestKit")

-- Art uses Roblox datatypes; Lune has them in its roblox library, not as globals.
local env: any = getfenv()
env.Color3 = roblox.Color3
env.Vector3 = roblox.Vector3
env.Vector2 = roblox.Vector2
env.CFrame = roblox.CFrame
env.UDim2 = roblox.UDim2
env.UDim = roblox.UDim
env.Enum = roblox.Enum
env.NumberRange = roblox.NumberRange

local Art = require("../src/shared/Art")
local Content = require("../src/shared/Data")

local kit = roblox.deserializeModel(fs.readFile("place/kit/EO_Hollow.rbxm"))[1]

local function drivenParts(rig: any): { [string]: boolean }
	local driven: { [string]: boolean } = {}
	for _, motor in rig:GetDescendants() do
		if motor.ClassName == "Motor6D" and motor.Part1 then
			driven[motor.Part1.Name] = true
		end
	end
	return driven
end

return function(test: TestKit.Register)
	test("every kind a location spawns or a quest hunts has a rig", function()
		for locationId, location in Content.Locations do
			for _, group in location.enemySpawns do
				TestKit.truthy(kit:FindFirstChild(group.enemyId) ~= nil, `{locationId} spawns {group.enemyId}: rigged`)
			end
			local quests = if location.run then location.run.quests else nil
			for _, quest in quests or {} do
				for _, objective in quest.objectives do
					local enemyId = (objective :: any).enemyId
					if enemyId then
						TestKit.truthy(kit:FindFirstChild(enemyId) ~= nil, `{quest.id} hunts {enemyId}: rigged`)
					end
				end
			end
		end
	end)

	test("the rig kit carries no scripts and no sounds", function()
		for _, item in kit:GetDescendants() do
			TestKit.truthy(not item:IsA("LuaSourceContainer"), `{item:GetFullName()} is a script`)
			TestKit.truthy(item.ClassName ~= "Sound", `{item:GetFullName()} is a sound`)
		end
	end)

	test("a rigged wildlife kind has a gait profile and every joint it drives", function()
		for enemyId, enemy in Content.Enemies do
			local rig = kit:FindFirstChild(enemyId)
			if enemy.wildlife == nil or rig == nil then
				continue
			end
			local profile = Art.wildlifeRigs[enemyId]
			TestKit.truthy(profile ~= nil, `{enemyId} has a gait profile`)
			local driven = drivenParts(rig)
			local names = { profile.root }
			for _, name in profile.neck do
				table.insert(names, name)
			end
			for index, leg in profile.legs do
				TestKit.equal(#leg.swing, #leg.joints, `{enemyId} leg {index} swing weights`)
				TestKit.equal(#leg.fold, #leg.joints, `{enemyId} leg {index} fold weights`)
				for _, name in leg.joints do
					table.insert(names, name)
				end
			end
			for _, name in names do
				TestKit.truthy(driven[name] == true, `{enemyId}: {name} is jointed`)
			end
		end
	end)
end
