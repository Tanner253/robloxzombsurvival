--!strict
--[[
	AssetAudit: rules for the asset ids the game names (batch 3, the boot console's
	"failed to load" lines). Pure; tests/AssetAudit.spec holds every id in the source to
	the known-good list in tests/KnownAssets.luau.

	An id is known-good once it was checked in Studio: its creator is the experience owner
	(or Roblox itself) and it loads in a playtest. An unknown id fails the spec until it is
	checked and listed, so a private, moderated or someone else's asset can't slip in.
]]

local AssetAudit = {}

-- Every rbxassetid number in `text`, once each, in the order first seen.
function AssetAudit.ids(text: string): { number }
	local seen: { [number]: boolean } = {}
	local list: { number } = {}
	for digits in string.gmatch(text, "rbxassetid://(%d+)") do
		local id = tonumber(digits)
		if id and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	return list
end

-- The ids in `ids` that `known` does not list, sorted.
function AssetAudit.unknown(ids: { number }, known: { [number]: any }): { number }
	local missing: { number } = {}
	for _, id in ids do
		if known[id] == nil then
			table.insert(missing, id)
		end
	end
	table.sort(missing)
	return missing
end

--[[
	Whether a model uploaded through Open Cloud (Art.uploaded) is served from the place's
	Studio-built copy (ServerStorage.EO_Uploaded, tools/rebuild_uploaded.luau) rather than
	loaded at run time: only a copy made from the same asset id counts.
]]
function AssetAudit.useStoredCopy(storedAssetId: any, wantedAssetId: number): boolean
	return type(storedAssetId) == "number" and storedAssetId == wantedAssetId
end

return AssetAudit
