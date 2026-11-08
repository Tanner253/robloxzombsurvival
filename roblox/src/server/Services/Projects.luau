--!strict
--[[
	Projects: long-term goals on the plot, restored by handing in parts (Domain/Project,
	Data/Projects; LDOE_PARITY #56). The wrecked hauler is the first: its parts checklist
	screen shows have/need per part, FILL UP hands in as much of a part as the home pool
	holds (pockets, backpack, crates and inbox, checklist 5.13) and FINALIZE restores it.

	Progress is saved on the outpost (OutpostSchema `projects`) and synced as "projects".
	The wreck's model only appears once it grades A (Shared/Flags vehicleFrame); until then
	the screen is unreachable, but the save already exists.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local InventoryMath = require(ReplicatedStorage.Shared.Domain.Inventory)
local Project = require(ReplicatedStorage.Shared.Domain.Project)
local Net = require("../Net")
local Analytics = require("./Analytics")
local Inbox = require("./Inbox")
local Materials = require("./Materials")
local Plots = require("./Plots")
local Sync = require("./Sync")

local Projects = {}

local function stateOf(player: Player, projectId: string): (any?, Project.State?)
	local outpost = Plots.outpost(player) :: any
	if outpost == nil or Content.Projects[projectId] == nil then
		return nil, nil
	end
	local projects = outpost.projects
	local state = projects[projectId]
	if state == nil then
		state = Project.new()
		projects[projectId] = state
	end
	return projects, state
end

local function deliver(player: Player, projectId: string, itemId: string)
	local projects, state = stateOf(player, projectId)
	local pool = Materials.virtual(player)
	if projects == nil or state == nil or pool == nil then
		return
	end
	local def = Content.Projects[projectId]
	local _, taken = Project.deliver(def, state, itemId, InventoryMath.count(pool, itemId))
	if taken <= 0 then
		Sync.notice(
			player,
			if Project.missing(def, state, itemId) > 0 then "You have none of that part" else "That part is done"
		)
		return
	end
	if not Materials.take(player, { { itemId = itemId, count = taken } }, "Project") then
		return
	end
	projects[projectId] = (Project.deliver(def, state, itemId, taken))
	Sync.mark(player, "projects")
	Sync.fx(player, "projectPart", { projectId = projectId, itemId = itemId, count = taken })
end

local function finalize(player: Player, projectId: string)
	local projects, state = stateOf(player, projectId)
	if projects == nil or state == nil then
		return
	end
	local def = Content.Projects[projectId]
	local finished, reason = Project.finalize(def, state, os.time())
	if finished == nil then
		Sync.notice(player, if reason == "finished" then "Already restored" else "Hand in every part first")
		return
	end
	projects[projectId] = finished
	Inbox.grant(player, (def.rewards or {}) :: any, "Project", true)
	Sync.mark(player, "projects")
	Sync.fx(player, "projectDone", { projectId = projectId, rewards = def.rewards or {} })
	Analytics.progression(player, projectId, "complete", 1)
end

function Projects.init()
	Net.onEvent("ProjectDeliver", deliver)
	Net.onEvent("ProjectFinalize", finalize)
	Sync.provide("projects", function(player: Player)
		local outpost = Plots.outpost(player) :: any
		return if outpost then outpost.projects else false
	end)
end

function Projects.start()
	Plots.claimed:Connect(function(player: Player)
		Sync.mark(player, "projects")
	end)
end

return Projects
