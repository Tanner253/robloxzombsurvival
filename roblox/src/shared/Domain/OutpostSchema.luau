--!strict
--[[
	OutpostSchema: the saved outpost (the "Outposts" store, one profile per outpost,
	ARCHITECTURE.md §6), with a version and migrations like PlayerSchema.

	It holds what belongs to the plot rather than to a player:
	- layout: the Domain/Grid layout (Grid.serialize);
	- seeded: whether the starter shelter was laid (LDOE_PARITY #56; once per outpost);
	- nodes: home resource nodes that were hit or depleted, by "<nodeId>#<n>"
	  (Domain/Gathering.Saved). Home nodes are finite (#30), so these stay depleted;
	- projects: long-term goals by project id (Domain/Project.State), e.g. the hauler.

	v1 outposts were saved before this schema existed: { layout } with no version.
	`prepare` marks them as version 1 so the migrations can run.
]]

local Nodes = require("../Data/Nodes")
local Grid = require("./Grid")
local Gathering = require("./Gathering")
local Migrations = require("./Migrations")
local Project = require("./Project")

local OutpostSchema = {}

OutpostSchema.VERSION = 3

export type Data = {
	version: number,
	layout: Grid.Saved,
	seeded: boolean,
	nodes: { [string]: Gathering.Saved },
	projects: { [string]: Project.State },
}

function OutpostSchema.template(): Data
	return {
		version = OutpostSchema.VERSION,
		layout = Grid.serialize(Grid.new()),
		seeded = false,
		nodes = {},
		projects = {},
	}
end

-- Marks pre-schema data (a bare { layout }) as version 1. Call before Migrations.run.
function OutpostSchema.prepare(data: { [string]: any })
	if data.version == nil then
		data.version = 1
	end
end

OutpostSchema.migrations = {
	-- v2: home nodes, projects and the starter shelter live on the outpost. An outpost
	-- that already has pieces is never given a shelter on top of its base.
	[1] = function(data)
		local layout = data.layout
		local pieces = if type(layout) == "table" and type(layout.d) == "table" then #layout.d else 0
		data.seeded = pieces > 0
		if type(data.nodes) ~= "table" then
			data.nodes = {}
		end
		if type(data.projects) ~= "table" then
			data.projects = {}
		end
	end,
	-- v3: the economy rescale (docs/ECONOMY.md §11.3): pines and boulders take 3 hits now.
	-- A saved node with more hits left than its node has is clamped (a clamped node with
	-- every hit left is whole again, so its save goes); depleted nodes stay depleted.
	[2] = function(data)
		local nodes: { [string]: any } = if type(data.nodes) == "table" then data.nodes else {}
		for key, saved in nodes do
			local nodeId = if type(key) == "string" then string.match(key, "^(.-)#") else nil
			local def = if nodeId then Nodes[nodeId] else nil
			if def and type(saved) == "table" and type(saved.hitsLeft) == "number" and saved.hitsLeft >= def.hits then
				nodes[key] = nil
			end
		end
		data.nodes = nodes
	end,
} :: Migrations.Steps

return OutpostSchema
