--!strict
--[[
	Assets: copies the art the client needs into ReplicatedStorage.Assets at boot,
	since the kit masters live in ServerStorage (ARCHITECTURE.md §2: the place
	owns models, the client can't see ServerStorage).

	- Assets.Pieces[pieceId]: every build piece, as the server builds it, for
	  ghost previews and build-menu thumbnails. The ghost is the real model.
	- Assets.Icons[itemId]: a model per item that has one (Shared/Art.items), for
	  rendered 3D item icons.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Art = require(ReplicatedStorage.Shared.Art)
local Models = require("../World/Models")

local Assets = {}

local function inert(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		elseif descendant:IsA("Light") or descendant:IsA("Fire") or descendant:IsA("ParticleEmitter") then
			descendant:Destroy()
		end
	end
end

local function folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

function Assets.start()
	local root = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
	root.Name = "Assets"

	local pieces = folder(root, "Pieces")
	for id, def in Content.BuildPieces do
		local model = Models.piece(def)
		model.Name = id
		inert(model)
		model.Parent = pieces
	end

	local icons = folder(root, "Icons")
	for itemId, def in Content.Items do
		local names = Art.items[itemId]
		local model = if names then Models.kit(names) else nil
		if model == nil and def.tool then
			model = Models.held(itemId, def)
		end
		if model then
			model.Name = itemId
			inert(model)
			model.Parent = icons
		end
	end

	root.Parent = ReplicatedStorage
end

return Assets
