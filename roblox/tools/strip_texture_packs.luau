--!strict
--[[
	strip_texture_packs: clears the hidden texture pack from every SurfaceAppearance and
	MaterialVariant in the place's kit files (place/kit/*.rbxm), keeping their four maps.

	Why (2.0 batch 4b): a SurfaceAppearance or MaterialVariant made by an Open Cloud import or
	Studio's generators carries a `TexturePackContent` asset beside its ColorMap, NormalMap,
	RoughnessMap and MetalnessMap. A game client can't read that pack ("ContentId:
	rbxassethash://... failed due to: Requester does not have permission for Asset", about 50
	lines a play start), though the maps are plain images the owner holds. Batch 3 fixed the
	uploaded models by rebuilding their SurfaceAppearances in Studio (tools/rebuild_uploaded);
	the kit files Rojo serves (the survivor rig, the Hollow, EO_Kit, the generated materials)
	are fixed here, in the repo, the same way: the pack is set to none.

	Usage (from roblox/): lune run tools/strip_texture_packs.luau [File ...]
	With no names it does every place/kit/*.rbxm. Prints what it cleared per file and writes
	only files that changed. Run it again after syncing new art back from the place.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Content = (roblox :: any).Content

local CLASSES = { SurfaceAppearance = true, MaterialVariant = true }

local function hasPack(item: any): boolean
	local ok, value = pcall(function()
		return item.TexturePackContent
	end)
	return ok and value ~= nil and tostring(value) ~= tostring(Content.none)
end

local names: { string } = {}
if #process.args > 0 then
	names = process.args
else
	for _, file in fs.readDir("place/kit") do
		if string.sub(file, -5) == ".rbxm" then
			table.insert(names, string.sub(file, 1, -6))
		end
	end
	table.sort(names)
end

local total = 0
for _, name in names do
	local path = `place/kit/{name}.rbxm`
	local roots = roblox.deserializeModel(fs.readFile(path))
	local cleared = 0
	for _, root in roots do
		local items = root:GetDescendants()
		table.insert(items, root)
		for _, item in items do
			if CLASSES[item.ClassName] and hasPack(item) then
				(item :: any).TexturePackContent = Content.none
				cleared += 1
			end
		end
	end
	if cleared > 0 then
		fs.writeFile(path, roblox.serializeModel(roots))
	end
	total += cleared
	print(`{name}: {cleared} texture packs cleared`)
end
print(`total: {total}`)
