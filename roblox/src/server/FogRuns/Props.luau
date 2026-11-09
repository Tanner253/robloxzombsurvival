--!strict
--[[
	Props: the things a Fog Run drops into its map while it runs, so players can see
	them (the kit lives in ServerStorage, out of the clients' reach):
	- a loot pile where a Hollow fell (Containers.spawnPile): a small sack, tagged as
	  a container of kind "pile";
	- a death bag where a survivor fell (Lobby): a sack with a warm lantern glow,
	  tagged EO_RunBag (checklist 12.6).
	Only approved kit models are used (World/Models); with none, nothing is placed.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Art)
local Models = require("../World/Models")

local Props = {}

Props.CONTAINER_TAG = "EO_RunContainer"
Props.BAG_TAG = "EO_RunBag"

local function groundBelow(position: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else position
end

local function sack(parent: Instance, position: Vector3, height: number): Model?
	local model = Models.kit(Art.dropModels)
	if model == nil then
		return nil
	end
	local size = model:GetExtentsSize()
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * height / size.Y)
	end
	local at = groundBelow(position, { model })
	model:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
	model.Parent = parent
	return model
end

-- A loot pile (a Hollow's drop). `ownerUserId` marks a Light-fog pile only its killer may open.
function Props.pile(parent: Instance, position: Vector3, containerId: string, ownerUserId: number?): Model?
	local model = sack(parent, position, 1.3)
	if model == nil then
		return nil
	end
	model.Name = `Pile_{containerId}`
	model:SetAttribute("Kind", "pile")
	model:SetAttribute("ContainerId", containerId)
	model:SetAttribute("Opened", false)
	if ownerUserId then
		model:SetAttribute("OwnerUserId", ownerUserId)
	end
	CollectionService:AddTag(model, Props.CONTAINER_TAG)
	return model
end

-- A survivor's death bag, glowing like a hung lantern so it reads at night and from afar.
function Props.bag(parent: Instance, position: Vector3, bagId: string, ownerUserId: number): Model?
	local model = sack(parent, position, 2)
	if model == nil then
		return nil
	end
	model.Name = `Bag_{bagId}`
	model:SetAttribute("BagId", bagId)
	model:SetAttribute("OwnerUserId", ownerUserId)
	local anchor = model:FindFirstChildWhichIsA("BasePart", true)
	if anchor then
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 186, 120)
		glow.Range = 12
		glow.Brightness = 1.4
		glow.Shadows = false
		glow.Parent = anchor
	end
	CollectionService:AddTag(model, Props.BAG_TAG)
	return model
end

return Props
