--!strict
--[[
	Guide: the first-session pointer (MVP_LAUNCH v0.1). While the Ember Trail's top quest
	waits on a "gather" objective, the nearest standing node on your own plot that yields
	that item wears a soft ember outline, so a new player sees where Gather Sticks or
	Gather Fieldstone happens without a tutorial. It moves to the next nearest node as
	nodes are picked, and goes away when the objective is done, a panel is open, or AUTO
	is gathering for you.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local State = require("../State")
local questText = require("../UI/questText")

local Guide = {}

local OUTLINE = Color3.fromRGB(255, 170, 70) -- the HUD's ember accent
local CHECK_SECONDS = 0.5

local player = Players.LocalPlayer

-- The item the top quest's next objective wants gathered, if that objective is a gather.
local function wantedItem(): string?
	local rows = questText.rows(State.get("quests"), 1)
	local row = rows[1]
	if row == nil or row.nextIndex == nil then
		return nil
	end
	for _, entry in row.objectives do
		if entry.index == row.nextIndex then
			local objective: any = entry.objective
			return if objective.kind == "gather" then objective.itemId else nil
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

-- The nearest standing node of mine that yields `itemId`.
local function nearest(itemId: string): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return nil
	end
	local best: Model?, bestDistance = nil, math.huge
	for _, model in game:GetService("CollectionService"):GetTagged("EO_Node") do
		if
			model:IsA("Model")
			and model:GetAttribute("OwnerUserId") == player.UserId
			and model:GetAttribute("Standing") ~= false
			and yields(model:GetAttribute("NodeId") :: string, itemId)
		then
			local distance = (model:GetPivot().Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

local outline: Highlight? = nil

local function point(model: Model?)
	if model == nil then
		if outline then
			outline:Destroy()
			outline = nil
		end
		return
	end
	if outline and outline.Parent == model then
		return
	end
	if outline then
		outline:Destroy()
	end
	local made = Instance.new("Highlight")
	made.Name = "EO_Guide"
	made.FillTransparency = 1
	made.OutlineColor = OUTLINE
	made.OutlineTransparency = 0.15
	made.DepthMode = Enum.HighlightDepthMode.Occluded
	made.Parent = model
	outline = made
end

function Guide.start()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local ui = State.ui()
			local itemId = if ui.panel == "none" and not ui.auto then wantedItem() else nil
			point(if itemId then nearest(itemId) else nil)
		end
	end)
end

return Guide
