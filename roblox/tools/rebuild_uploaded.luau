--[[
	rebuild_uploaded.luau: keeps a Studio-built copy of every uploaded family model
	(Shared/Art.uploaded) in the place, at ServerStorage.EO_Uploaded, which
	server/World/Models uses instead of loading the asset at run time.

	Why: a Model uploaded through Open Cloud (GLB import) carries SurfaceAppearances whose
	hidden texture pack the game may not read. Every such model logged
	"ContentId: rbxassethash://... failed due to: Requester does not have permission for
	Asset" on the server and on each client (about 48 lines a boot; batch 3 found it by
	placing one model at a time: a model with its SurfaceAppearance logged one, the same
	model without it none, and the same model with the SurfaceAppearance rebuilt none).
	A SurfaceAppearance made in Studio from the same four maps has no such pack. Its maps
	are plain image assets the experience owner holds.

	How (Roblox Studio MCP, Edit mode, the place "Ember"):
	1. execute_luau (Edit) with this file's body. It starts the work and returns at once.
	2. Poll `return _G.EO_REBUILD` (Edit) until `done` is true; `failed` lists any asset
	   that would not load.
	3. save_place, so the copies stay in the cloud place. EO_Uploaded is not in
	   default.project.json: Rojo leaves an unknown ServerStorage child alone. To put it in
	   the repo, save the place to place/ember.rbxl and run
	   `lune run tools/syncback.luau place/ember.rbxl EO_Uploaded`, then add the entry.

	Run it again after adding or re-uploading an Art.uploaded model: a copy whose AssetId
	attribute matches is kept, the rest are (re)built.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Art = require(ReplicatedStorage.Shared.Art) :: any

local status = { done = false, built = {}, kept = 0, failed = {} }
_G.EO_REBUILD = status

local folder = ServerStorage:FindFirstChild("EO_Uploaded")
if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = "EO_Uploaded"
	folder.Parent = ServerStorage
end

local function rebuild(model: Instance): number
	local count = 0
	for _, old in model:GetDescendants() do
		if old:IsA("SurfaceAppearance") then
			local fresh = Instance.new("SurfaceAppearance")
			fresh.Name = old.Name
			fresh.ColorMap = old.ColorMap
			fresh.NormalMap = old.NormalMap
			fresh.RoughnessMap = old.RoughnessMap
			fresh.MetalnessMap = old.MetalnessMap
			fresh.AlphaMode = old.AlphaMode
			fresh.Color = old.Color
			local parent = old.Parent
			old:Destroy()
			fresh.Parent = parent
			count += 1
		end
	end
	return count
end

task.spawn(function()
	local names = {}
	for name in Art.uploaded do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local entry = Art.uploaded[name]
		local existing = folder:FindFirstChild(name)
		if existing and existing:GetAttribute("AssetId") == entry.id and existing:GetAttribute("Rebuilt") then
			status.kept += 1
			continue
		end
		local ok, container = pcall(InsertService.LoadAsset, InsertService, entry.id)
		local model = if ok then container:FindFirstChildWhichIsA("Model") else nil
		if model == nil then
			table.insert(status.failed, `{name} {entry.id}`)
			continue
		end
		local rebuilt = rebuild(model)
		model.Name = name
		model:SetAttribute("AssetId", entry.id)
		model:SetAttribute("Rebuilt", rebuilt)
		if existing then
			existing:Destroy()
		end
		model.Parent = folder
		container:Destroy()
		table.insert(status.built, `{name}:{rebuilt}`)
	end
	status.done = true
end)

return "rebuilding; poll _G.EO_REBUILD"
