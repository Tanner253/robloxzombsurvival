--!strict
--[[
	Guide: the first-session pointer (MVP_LAUNCH v0.1). It follows the Ember Trail's top
	quest's next objective, so a new player is led through chapter 1 to their first Run
	without a tutorial:
	- gather: the nearest standing node of yours that yields the item wears an ember
	  outline (it moves on as nodes are picked);
	- make at a station (boil water, cut planks): your nearest such station is outlined,
	  or the Build button pulses while you have none;
	- craft by hand: the Craft button pulses; build: the Build button pulses;
	- eat, drink or equip: the Inventory button pulses;
	- travel (quest 6, the hand-off to Fog Runs): the Trailhead, where Runs leave from, is
	  outlined.
	It steps aside while a panel is open or AUTO is gathering for you. The HUD reads the
	button from ui.guide.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local State = require("../State")
local questText = require("../UI/questText")

local Guide = {}

local OUTLINE = Color3.fromRGB(255, 170, 70) -- the HUD's ember accent
local CHECK_SECONDS = 0.5

local player = Players.LocalPlayer

-- The top quest's next objective, if any.
local function nextObjective(): any
	local rows = questText.rows(State.get("quests"), 1)
	local row = rows[1]
	if row == nil or row.nextIndex == nil then
		return nil
	end
	for _, entry in row.objectives do
		if entry.index == row.nextIndex then
			return entry.objective
		end
	end
	return nil
end

local function yields(nodeId: string, itemId: string): boolean
	local def = Content.Nodes[nodeId]
	if def == nil then
		return false
	end
	for _, y in def.yields do
		if y.itemId == itemId then
			return true
		end
	end
	return false
end

-- The nearest model of mine tagged `tag` that passes `fits`.
local function nearestTagged(tag: string, fits: (model: Model) -> boolean): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return nil
	end
	local best: Model?, bestDistance = nil, math.huge
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("Model") and instance:GetAttribute("OwnerUserId") == player.UserId and fits(instance) then
			local distance = (instance:GetPivot().Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = instance, distance
			end
		end
	end
	return best
end

-- The nearest standing node of mine that yields `itemId`.
local function nearestNode(itemId: string): Model?
	return nearestTagged("EO_Node", function(model: Model): boolean
		return model:GetAttribute("Standing") ~= false and yields(model:GetAttribute("NodeId") :: string, itemId)
	end)
end

-- Where Fog Runs leave from: every model in the Trailhead (Services/Scenery builds it at
-- the road's west end: its lantern posts today, and whatever S2B puts there to start a Run).
local function trailhead(): { Instance }
	local world = workspace:FindFirstChild("World")
	local found = world and world:FindFirstChild("Trailhead")
	local models: { Instance } = {}
	if found then
		for _, child in found:GetChildren() do
			if child:IsA("Model") then
				table.insert(models, child)
			end
		end
	end
	return models
end

-- What the guide points at for an objective: models to outline, or a HUD button.
local function pointFor(objective: any): ({ Instance }, string?)
	local kind = objective.kind
	if kind == "gather" then
		return { nearestNode(objective.itemId) :: any }, nil
	elseif kind == "craft" then
		local recipe = Content.Recipes[objective.recipeId]
		if recipe and recipe.stationId then
			local station = nearestTagged("EO_Station", function(model: Model): boolean
				return model:GetAttribute("StationId") == recipe.stationId
			end)
			return { station :: any }, if station then nil else "build"
		end
		return {}, "craft"
	elseif kind == "build" then
		return {}, "build"
	elseif kind == "consume" or kind == "equip" then
		return {}, "inventory"
	elseif kind == "travel" then
		return trailhead(), nil
	end
	return {}, nil
end

-- The outlines shown now, by the model they sit on.
local outlines: { [Instance]: Highlight? } = {}

local function point(targets: { Instance })
	local wanted: { [Instance]: boolean } = {}
	for _, target in targets do
		wanted[target] = true
		local existing: Highlight? = outlines[target]
		if existing == nil or existing.Parent ~= target then
			local made = Instance.new("Highlight")
			made.Name = "EO_Guide"
			made.FillTransparency = 1
			made.OutlineColor = OUTLINE
			made.OutlineTransparency = 0.15
			made.DepthMode = Enum.HighlightDepthMode.Occluded
			made.Parent = target
			outlines[target] = made
		end
	end
	for target, highlight in outlines do
		if not wanted[target] then
			if highlight then
				highlight:Destroy()
			end
			outlines[target] = nil
		end
	end
end

function Guide.start()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local ui = State.ui()
			local objective = if ui.panel == "none" and not ui.auto then nextObjective() else nil
			local targets: { Instance }, button: string? = {}, nil
			if objective then
				targets, button = pointFor(objective)
			end
			point(targets)
			if button ~= ui.guide then
				State.patch({ guide = button })
			end
		end
	end)
end

return Guide
