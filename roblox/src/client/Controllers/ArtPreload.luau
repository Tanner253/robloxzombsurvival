--!strict
--[[
	ArtPreload: loads the art the UI draws in ViewportFrames (ReplicatedStorage.Assets: item
	icons and build-menu previews) as soon as the client has it (2.0 batch 4b).

	Why: a freshly uploaded or generated texture may not have every representation yet. The
	3D world then falls back to the baseline image, but a ViewportFrame does not ("No asset
	content representation found while do_not_fallback_to_baseline is set to true"), so an
	item never seen in the world drew grey in the inventory (the Hidebound Leggings and Boots,
	the new melee, the Riveted set, the Plate Carrier). Preloading the models first puts the
	baseline in the cache, and every icon draws textured (checked in Studio, capture C26).
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtPreload = {}

function ArtPreload.start()
	local assets = ReplicatedStorage:WaitForChild("Assets", 60)
	if assets == nil then
		return
	end
	local folders: { Instance } = {}
	for _, name in { "Icons", "Pieces" } do
		local folder = assets:WaitForChild(name, 30)
		if folder then
			table.insert(folders, folder)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(folders)
	end)
end

return ArtPreload
