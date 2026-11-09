--!strict
--[[
	Wildlife rigs (LDOE_PARITY #35): every animal the data can spawn has a rig in
	place/kit/EO_Hollow.rbxm and a gait profile (Art.wildlifeRigs), and every joint the
	profile drives is a real Motor6D of that rig. The Hollow service spawns only kinds
	with a rig, so a missing or misnamed rig would silently empty the woods.
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
	test("every wildlife kind has a rig and a gait profile", function()
		local count = 0
		for enemyId, enemy in Content.Enemies do
			if enemy.wildlife then
				count += 1
				TestKit.truthy(kit:FindFirstChild(enemyId) ~= nil, `{enemyId} has a rig in EO_Hollow`)
				TestKit.truthy(Art.wildlifeRigs[enemyId] ~= nil, `{enemyId} has a gait profile`)
			end
		end
		TestKit.truthy(count >= 2, "the deer and the wolf are wildlife")
	end)

	test("every joint a gait profile drives is a Motor6D of its rig", function()
		for enemyId, profile in Art.wildlifeRigs do
			local rig = kit:FindFirstChild(enemyId)
			TestKit.truthy(rig ~= nil, `{enemyId} rig`)
			local driven = drivenParts(rig)
			local names = { profile.root }
			if profile.spine then
				table.insert(names, profile.spine)
			end
			if profile.jaw then
				table.insert(names, profile.jaw)
			end
			for _, name in profile.neck do
				table.insert(names, name)
			end
			for _, name in profile.ears or {} do
				table.insert(names, name)
			end
			for _, name in profile.tail or {} do
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

	test("rigs stand on their pivot, face -Z, and only the root is anchored", function()
		-- Lune keeps a part's CFrame, not its derived Position.
		for enemyId, profile in Art.wildlifeRigs do
			local rig = kit:FindFirstChild(enemyId)
			local root = rig.PrimaryPart
			TestKit.truthy(root ~= nil and root.Name == "HumanoidRootPart", `{enemyId} root`)
			local pivot = root.CFrame * root.PivotOffset
			local head = rig:FindFirstChild(profile.neck[#profile.neck])
			local tail = rig:FindFirstChild(profile.legs[1].joints[1]) -- a hind leg
			TestKit.truthy(pivot:PointToObjectSpace(head.CFrame.Position).Z < 0, `{enemyId} head is forward (-Z)`)
			TestKit.truthy(pivot:PointToObjectSpace(tail.CFrame.Position).Z > 0, `{enemyId} hind leg is behind`)
			local lowest = math.huge
			for _, part in rig:GetDescendants() do
				if part:IsA("BasePart") then
					TestKit.equal(part.Anchored, part == root, `{enemyId}.{part.Name} anchoring`)
					lowest = math.min(lowest, part.CFrame.Position.Y - part.Size.Y / 2)
				end
			end
			TestKit.truthy(math.abs(lowest - pivot.Position.Y) < 0.6, `{enemyId} feet at the pivot`)
		end
	end)
end
