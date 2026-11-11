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

local BuildPieces = require("../Data/BuildPieces")
local Nodes = require("../Data/Nodes")
local StarterShelter = require("../Data/StarterShelter")
local Grid = require("./Grid")
local Gathering = require("./Gathering")
local Migrations = require("./Migrations")
local Project = require("./Project")

local OutpostSchema = {}

OutpostSchema.VERSION = 5

-- The base piece an upgraded piece was first placed as.
local function rootOf(pieceId: string): string
	local current = pieceId
	for _ = 1, 32 do
		local below: string? = nil
		for id, def in BuildPieces do
			if def.upgradesTo == current then
				below = id
				break
			end
		end
		if below == nil then
			return current
		end
		current = below
	end
	return current
end

--[[
	Stamps the starter shelter's pieces in a saved layout (Grid.serialize's fields) with
	Grid.STARTER_AT. The shelter went down first into an empty layout, all in one second, so
	its pieces are uids 1..#StarterShelter, each placed as that entry's piece, at one time.
	A piece the player moved or upgraded still matches; anything that doesn't is left alone.
]]
function OutpostSchema.markStarter(layout: any)
	if type(layout) ~= "table" or type(layout.d) ~= "table" or type(layout.p) ~= "table" then
		return
	end
	if type(layout.t) ~= "number" then
		return
	end
	local fields = 8
	local data: { number } = layout.d
	local batch: number? = nil
	for offset = 0, #data - fields, fields do
		local uid, palette = data[offset + 1], data[offset + 2]
		local entry = StarterShelter[uid]
		local pieceId = layout.p[palette]
		if entry == nil or type(pieceId) ~= "string" or BuildPieces[pieceId] == nil then
			continue
		end
		local placedAt = layout.t + data[offset + 7]
		if placedAt == Grid.STARTER_AT or rootOf(pieceId) ~= entry.pieceId then
			continue
		end
		batch = batch or placedAt
		if placedAt == batch then
			local upgradedAt = placedAt + data[offset + 8]
			data[offset + 7] = Grid.STARTER_AT - layout.t
			data[offset + 8] = if upgradedAt > placedAt then upgradedAt - Grid.STARTER_AT else 0
		end
	end
end

--[[
	Takes every piece whose id is no longer a build piece out of a saved layout
	(Grid.serialize's fields), so Grid.deserialize (which calls an unknown piece corrupt)
	still loads the outpost. v5 uses it for the Ammo Press (F-13). Returns how many went.
]]
function OutpostSchema.dropUnknownPieces(layout: any): number
	if type(layout) ~= "table" or type(layout.d) ~= "table" or type(layout.p) ~= "table" then
		return 0
	end
	local fields = 8
	local data: { number } = layout.d
	local kept: { number } = {}
	local dropped = 0
	for offset = 0, #data - fields, fields do
		local pieceId = layout.p[data[offset + 2]]
		if type(pieceId) == "string" and BuildPieces[pieceId] == nil then
			dropped += 1
			continue
		end
		for field = 1, fields do
			table.insert(kept, data[offset + field])
		end
	end
	layout.d = kept
	return dropped
end

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
	-- v4: the starter shelter's pieces are stamped Grid.STARTER_AT (the flow review's F-06
	-- and F-30): they count toward no build objective and refund nothing. Only a seeded
	-- outpost has them.
	[3] = function(data)
		if data.seeded == true then
			OutpostSchema.markStarter(data.layout)
		end
	end,
	-- v5: no ammo (the flow review's F-13): a placed Ammo Press is taken off the plot. Its
	-- station record and contents are settled by PlayerSchema v11.
	[4] = function(data)
		OutpostSchema.dropUnknownPieces(data.layout)
	end,
} :: Migrations.Steps

return OutpostSchema
