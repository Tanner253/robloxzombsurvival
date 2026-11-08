--!strict
--[[
	Maps: the Fog Run locations built from code (world-as-code, MVP_LAUNCH v0.1).

	One layout module per location. A run server (a reserved server hosting one
	lobby) builds its location as Workspace.FogRun at the world origin. A world
	server simulating lobbies (Studio) builds every location as
	Workspace.FogRuns.<locationId>, each far from the Neighbourhood. Either way the
	folder carries Ready = true once it is finished, and FogRuns/Map reads it.

	Locations without a layout (the rotating event spot, the airdrop) can't be
	travelled to yet: Travel refuses them and the Fog map leaves them off.
]]

local Builder = require("@self/Builder")

local Maps = {}

export type Layout = {
	half: number, -- playable half-size (studs)
	seed: number,
	build: (ctx: Builder.Ctx) -> (),
}

Maps.layouts = {
	["loc.pine_hollow"] = require("@self/PineHollow") :: Layout,
	["loc.sunken_quarry"] = require("@self/Rustwater") :: Layout,
	["loc.ashfall_depot"] = require("@self/AshfallDepot") :: Layout,
} :: { [string]: Layout }

-- Where each map sits when they share a server with the Neighbourhood (Studio).
local SIMULATED_ORIGINS: { [string]: Vector3 } = {
	["loc.pine_hollow"] = Vector3.new(3200, 2, -400),
	["loc.sunken_quarry"] = Vector3.new(3200, 2, 800),
	["loc.ashfall_depot"] = Vector3.new(3200, 2, 2000),
}
local RUN_ORIGIN = Vector3.new(0, 2, 0)

local building: { [string]: boolean } = {}

function Maps.has(locationId: string): boolean
	return Maps.layouts[locationId] ~= nil
end

-- The map's folder if it has been built (or is being built).
function Maps.folder(locationId: string, runServer: boolean): Instance?
	if runServer then
		local map = workspace:FindFirstChild("FogRun")
		return if map and map:GetAttribute("LocationId") == locationId then map else nil
	end
	local all = workspace:FindFirstChild("FogRuns")
	return if all then all:FindFirstChild(locationId) else nil
end

-- The world origin a location's map is built at.
function Maps.origin(locationId: string, runServer: boolean): Vector3
	return if runServer then RUN_ORIGIN else (SIMULATED_ORIGINS[locationId] or RUN_ORIGIN)
end

--[[
	Builds a location's map once (yields while it builds; other callers wait for
	it). Returns the finished folder, or nil for a location with no layout.
]]
function Maps.build(locationId: string, runServer: boolean): Instance?
	local layout = Maps.layouts[locationId]
	if layout == nil then
		return nil
	end
	local existing = Maps.folder(locationId, runServer)
	if existing and existing:GetAttribute("Ready") then
		return existing
	end
	if building[locationId] then
		return Maps.await(locationId, runServer, 120)
	end
	building[locationId] = true
	if existing then
		existing:Destroy() -- a half-built map from a failed build
	end
	local root = Instance.new("Folder")
	root.Name = if runServer then "FogRun" else locationId
	root:SetAttribute("LocationId", locationId)
	root:SetAttribute("Ready", false)
	if runServer then
		root.Parent = workspace
	else
		local all = workspace:FindFirstChild("FogRuns")
		if all == nil then
			local made = Instance.new("Folder")
			made.Name = "FogRuns"
			made.Parent = workspace
			all = made
		end
		root.Parent = all
	end
	local origin = Maps.origin(locationId, runServer)
	root:SetAttribute("Origin", origin)
	root:SetAttribute("Half", layout.half)
	local ctx = Builder.new(locationId, root, origin, layout.half, layout.seed)
	local started = os.clock()
	local ok, err = pcall(layout.build :: any, ctx)
	building[locationId] = nil
	if not ok then
		warn(`[Maps] {locationId} failed to build: {err}`)
		return nil
	end
	Builder.bounds(ctx)
	root:SetAttribute("Ready", true)
	print(`[Maps] built {locationId} in {math.floor((os.clock() - started) * 10) / 10} s`)
	return root
end

-- Waits for a map another thread is building. nil after `timeout` seconds.
function Maps.await(locationId: string, runServer: boolean, timeout: number): Instance?
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local map = Maps.folder(locationId, runServer)
		if map and map:GetAttribute("Ready") then
			return map
		end
		task.wait(0.25)
	end
	return nil
end

return Maps
