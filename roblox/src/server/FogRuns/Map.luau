--!strict
--[[
	Map: reads a location's markers so the Fog Run services know where things go.
	Phase B builds the maps world-as-code; this is the contract they follow.

	Where the map lives:
	- a run server (one location per place): Workspace.FogRun
	- a world server simulating lobbies (Studio): Workspace.FogRuns.<locationId>

	Markers are BaseParts anywhere inside the map with a string attribute RunMarker:
	- "spawn": where players arrive (spread apart)
	- "hollow": Hollow spawn points
	- "container": a container spot; optional attribute Kind ("locker", "crate"...)
	- "extract": an extraction point; attribute PointId matching the location data
	- "bounds": one box around the playable area; Light fog leaves past its edge
	- "node": a gatherable resource node spot; attribute NodeId (Gathering spawns it)

	Everything degrades gracefully when a map is missing: nothing spawns, and the
	edge and points refuse, so Phase A code never acts on a world that isn't there.
]]

local Map = {}

export type Marker = "spawn" | "hollow" | "container" | "extract" | "bounds" | "node"

-- The map folder for a location, or nil when it hasn't been built (FogRuns/Maps builds it).
function Map.of(locationId: string, runServer: boolean): Instance?
	if runServer then
		local map = workspace:FindFirstChild("FogRun")
		return if map and map:GetAttribute("LocationId") == locationId then map else nil
	end
	local all = workspace:FindFirstChild("FogRuns")
	return if all then all:FindFirstChild(locationId) else nil
end

-- Every marker part of one kind, in a stable order (by full name).
function Map.markers(map: Instance?, kind: Marker): { BasePart }
	local parts: { BasePart } = {}
	if map == nil then
		return parts
	end
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("RunMarker") == kind then
			table.insert(parts, descendant)
		end
	end
	table.sort(parts, function(a: BasePart, b: BasePart): boolean
		return a:GetFullName() < b:GetFullName()
	end)
	return parts
end

-- The extraction point marker for `pointId`.
function Map.point(map: Instance?, pointId: string): BasePart?
	for _, part in Map.markers(map, "extract") do
		if part:GetAttribute("PointId") == pointId then
			return part
		end
	end
	return nil
end

-- The playable box, if the map has one.
function Map.bounds(map: Instance?): BasePart?
	return Map.markers(map, "bounds")[1]
end

-- How far `position` is inside the bounds box on the ground plane (negative: outside).
function Map.insideBy(bounds: BasePart, position: Vector3): number
	local here = bounds.CFrame:PointToObjectSpace(position)
	local half = bounds.Size / 2
	return math.min(half.X - math.abs(here.X), half.Z - math.abs(here.Z))
end

-- Converts a world position to a Domain/Plane point.
function Map.plane(position: Vector3): { x: number, z: number }
	return { x = position.X, z = position.Z }
end

-- Snaps a ground-plane point to the terrain or floor below it (for server-side Hollow).
function Map.ground(x: number, z: number, fallbackY: number, exclude: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	-- From just above its feet (a step up at most), so a roof overhead never counts as ground.
	local hit = workspace:Raycast(Vector3.new(x, fallbackY + 4, z), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else Vector3.new(x, fallbackY, z)
end

return Map
