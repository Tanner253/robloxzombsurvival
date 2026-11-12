--!strict
--[[
	Radar: what the minimap and the full-screen map show (checklist 8.11). The
	components (UI/components/Minimap, UI/screens/AreaMap) draw; this keeps the data.

	- The map: at home the Neighbourhood (Domain/NeighbourhoodMap, from Tuning) plus what
	  the world adds that shared data doesn't carry (Haven's stalls, read once each
	  streams in); on a Fog Run the location's picture from Data/Maps, or, until that is
	  supplied, one derived from the built map the client can see: its bounds, the ground
	  from the terrain, building footprints, trees and the exits. `Radar.current()` and
	  the `changed` signal.
	- Features drawn on the map that change now and then: every outpost's floors and walls,
	  and the plots' standing trees and rocks (`Radar.features()`, re-read every 2 s).
	- Blips, re-gathered 5 times a second, read every frame by the minimap: the Hollow
	  (only alerted ones or ones in sight), Fog Run containers (searched ones dimmed), your
	  stations (a badge when output is ready), bags (yours red), party members, other
	  survivors at home, Haven's people, and the exits and the Trailhead (kept on the
	  rim when off the radar).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Content = require(ReplicatedStorage.Shared.Data)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Converter = require(ReplicatedStorage.Shared.Domain.Converter)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local MapData = require(ReplicatedStorage.Shared.Domain.MapData)
local NeighbourhoodMap = require(ReplicatedStorage.Shared.Domain.NeighbourhoodMap)
local State = require("../State")
local HollowView = require("./HollowView")

local Radar = {}

export type BlipKind =
	"hollow"
	| "container"
	| "station"
	| "bag"
	| "party"
	| "survivor"
	| "exit"
	| "npc"
	| "fire"
	| "noise"

export type Blip = {
	key: string,
	kind: BlipKind,
	instance: Instance?, -- a moving thing: its position is read every frame
	at: Vector3?, -- or a fixed world position
	dim: boolean?, -- a searched container, a closed exit
	mine: boolean?, -- your bag
	ready: boolean?, -- a station with output waiting
	pin: boolean?, -- kept on the rim when off the radar
	glyph: string?,
	label: string?,
	radius: number?, -- a noise ring's reach (studs)
	born: number?, -- when a noise ring was heard (os.clock)
}

-- How long a noise ring shows on the minimap (seconds).
Radar.NOISE_SECONDS = 1.5

export type Current = {
	map: MapData.Map,
	origin: Vector3, -- the world position of the map's (0, 0)
	kind: "home" | "run",
	version: number,
}

-- A drawn rectangle in map-local studs (an outpost floor or wall).
export type Rect = { x: number, z: number, w: number, d: number, yaw: number, kind: string, mine: boolean }
export type Features = { outposts: { Rect }, trees: { MapData.Point }, rocks: { MapData.Point }, version: number }

Radar.changed = Signal.new() -- the map changed (a new map, or features learned)
Radar.featuresChanged = Signal.new()

local player = Players.LocalPlayer
local GATHER_SECONDS = 0.2
local FEATURE_SECONDS = 2
local SIGHT = 46 -- a Hollow this close and in plain view shows even when it hasn't noticed you
local ALERT_STATES = { alert = true, chase = true, attack = true }
local NPC_GLYPHS: { [string]: string } = { ["npc.trader"] = "coin", ["npc.keeper"] = "quests", ["npc.warden"] = "pass" }

local current: Current? = nil
local version = 0
local blips: { Blip } = {}
local features: Features = { outposts = {}, trees = {}, rocks = {}, version = 0 }
local party: { [number]: boolean } = {}

local gridStuds = Content.Tuning.building.plotCells * Grid.CELL_STUDS
local homeBase: MapData.Map = NeighbourhoodMap.build(Content.Tuning.plots :: any, gridStuds)
local learned: { [string]: MapData.Building } = {} -- Haven stalls by name
local runKey: string? = nil -- the run map in use (its folder's full name and what it held)

-- A blip key per instance. Full names collide (a map holds many "Container_crate"
-- siblings), and colliding keys made the minimap rebuild those icons 5 times a second
-- and show one of each name.
local instanceKeys: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any
local lastInstanceKey = 0
local function keyOf(prefix: string, instance: Instance): string
	local key = instanceKeys[instance]
	if key == nil then
		lastInstanceKey += 1
		key = tostring(lastInstanceKey)
		instanceKeys[instance] = key
	end
	return prefix .. key
end

function Radar.current(): Current?
	return current
end

function Radar.blips(): { Blip }
	return blips
end

function Radar.features(): Features
	return features
end

-- Whether `userId` is in your party.
function Radar.inParty(userId: number): boolean
	return party[userId] == true
end

local function setCurrent(map: MapData.Map, origin: Vector3, kind: "home" | "run")
	version += 1
	current = { map = map, origin = origin, kind = kind, version = version }
	Radar.changed:Fire()
end

local function onRun(): boolean
	return type(State.get("run")) == "table"
end

-- Home ---------------------------------------------------------------------------------------------

local function worldOrigin(): Vector3?
	local world = workspace:FindFirstChild("World")
	local origin = world and world:GetAttribute("Origin")
	return if typeof(origin) == "Vector3" then origin else nil
end

local function flatYaw(frame: CFrame): number
	local look = frame.LookVector
	return math.deg(math.atan2(-look.X, -look.Z))
end

-- Haven's stalls stream in when you come near: each is read once and kept.
local function learnHaven(origin: Vector3): boolean
	local world = workspace:FindFirstChild("World")
	local haven = world and world:FindFirstChild("Haven")
	if haven == nil then
		return false
	end
	local grew = false
	for _, child in haven:GetChildren() do
		if child:IsA("Model") and learned[child.Name] == nil and string.upper(child.Name) == child.Name then
			-- The stalls are the upper-case named models (TRADING POST, TRAIL KEEPER).
			-- The box is in the model's own axes (its pivot): width along X, depth along Z.
			local ok, frame, size = pcall(function()
				return child:GetBoundingBox()
			end)
			if ok and #child:GetChildren() >= 4 and size.X > 4 and size.Z > 4 then
				-- The box takes in the stall's dressing; its roof is a little smaller.
				learned[child.Name] = {
					kind = "stall",
					x = frame.Position.X - origin.X,
					z = frame.Position.Z - origin.Z,
					w = math.min(size.X, 18),
					d = math.min(size.Z, 12),
					yaw = flatYaw(frame),
				}
				grew = true
			end
		end
	end
	return grew
end

local function buildHome(origin: Vector3)
	local list: { MapData.Building } = {}
	for _, building in learned do
		table.insert(list, building)
	end
	table.sort(list, function(a, b)
		return (a.label or "") < (b.label or "")
	end)
	setCurrent(MapData.with(homeBase, { buildings = list }), origin, "home")
end

-- Fog Runs: the location's map, supplied or derived ----------------------------------------------------

local function runFolder(): Instance?
	local single = workspace:FindFirstChild("FogRun")
	if single then
		return single
	end
	local run = State.get("run")
	local all = workspace:FindFirstChild("FogRuns")
	if type(run) == "table" and all and type(run.locationId) == "string" then
		return all:FindFirstChild(run.locationId)
	end
	return nil
end

-- What a terrain material paints on the minimap (grass is the ground itself).
local GROUND: { [Enum.Material]: MapData.ZoneKind } = {
	[Enum.Material.Mud] = "mud",
	[Enum.Material.Ground] = "earth",
	[Enum.Material.Sand] = "dry",
	[Enum.Material.Rock] = "rock",
	[Enum.Material.Slate] = "rock",
	[Enum.Material.Basalt] = "rock",
	[Enum.Material.Concrete] = "rock",
	[Enum.Material.Pavement] = "rock",
	[Enum.Material.Asphalt] = "rock",
	[Enum.Material.Cobblestone] = "rock",
	[Enum.Material.Water] = "water",
}
local CELL = 4

-- The ground of a built run map, read from its terrain once: rows of runs of one kind.
local function deriveGround(origin: Vector3, half: number): { MapData.Zone }
	local zones: { MapData.Zone } = {}
	local reach = half + 24
	local lo = Vector3.new(origin.X - reach, origin.Y - 28, origin.Z - reach)
	local slabs = 4
	local depth = reach * 2 / slabs
	for slab = 0, slabs - 1 do
		local from = lo + Vector3.new(0, 0, slab * depth)
		local region = Region3.new(from, from + Vector3.new(reach * 2, 72, depth)):ExpandToGrid(CELL)
		local ok, materials = pcall(function()
			return (workspace.Terrain:ReadVoxels(region, CELL)) :: any
		end)
		if ok then
			local size: Vector3 = materials.Size
			local corner = region.CFrame.Position - region.Size / 2
			for iz = 1, size.Z do
				local z = corner.Z + (iz - 0.5) * CELL - origin.Z
				local runKind: MapData.ZoneKind? = nil
				local runStart = 0
				local function close(ix: number)
					if runKind then
						local x0 = corner.X + (runStart - 1) * CELL - origin.X
						local x1 = corner.X + (ix - 1) * CELL - origin.X
						-- Rounded and overlapping the next row, so the runs read as worn
						-- ground rather than a grid of cells.
						table.insert(zones, {
							kind = runKind,
							shape = "rect",
							x = (x0 + x1) / 2,
							z = z,
							w = x1 - x0 + CELL * 0.6,
							d = CELL * 1.8,
							round = CELL * 0.9,
						})
					end
				end
				for ix = 1, size.X do
					local kind: MapData.ZoneKind? = nil
					for iy = size.Y, 1, -1 do
						local material = materials[ix][iy][iz]
						if material ~= Enum.Material.Air then
							kind = GROUND[material]
							break
						end
					end
					if kind ~= runKind then
						close(ix)
						runKind, runStart = kind, ix
					end
				end
				close(size.X + 1)
			end
		end
		task.wait()
	end
	return zones
end

local function deriveRun(folder: Instance, origin: Vector3, half: number, ground: { MapData.Zone }): MapData.Map
	local buildings: { MapData.Building } = {}
	local seen: { [Instance]: boolean } = {}
	for _, roof in CollectionService:GetTagged("EO_Roof") do
		local building = roof.Parent
		if building and not seen[building] and building:IsDescendantOf(folder) then
			seen[building] = true
			local box = building:GetAttribute("Interior")
			local frame = building:GetAttribute("InteriorCFrame")
			if typeof(box) == "Vector3" and typeof(frame) == "CFrame" then
				table.insert(buildings, {
					kind = "house",
					x = frame.Position.X - origin.X,
					z = frame.Position.Z - origin.Z,
					w = box.X + 2,
					d = box.Z + 2,
					yaw = flatYaw(frame),
				})
			end
		end
	end
	local trees: { MapData.Point } = {}
	for _, canopy in CollectionService:GetTagged("EO_Canopy") do
		if canopy:IsA("Model") and canopy:IsDescendantOf(folder) then
			local at = canopy:GetPivot().Position
			table.insert(trees, { x = at.X - origin.X, z = at.Z - origin.Z })
		end
	end
	local points: { MapData.MapPoint } = {}
	for _, exit in CollectionService:GetTagged("EO_RunExit") do
		if exit:IsA("Model") and exit:IsDescendantOf(folder) then
			local at = exit:GetPivot().Position
			local id = exit:GetAttribute("PointId")
			local name = exit:GetAttribute("ExitName")
			table.insert(points, {
				id = if type(id) == "string" then id else exit:GetFullName(),
				kind = "exit",
				x = at.X - origin.X,
				z = at.Z - origin.Z,
				label = if type(name) == "string" then name else nil,
			})
		end
	end
	local margin = 70
	local location = Content.Locations[folder:GetAttribute("LocationId") :: any]
	return {
		format = MapData.FORMAT,
		id = tostring(folder:GetAttribute("LocationId") or "run"),
		name = if location then location.name else "Fog Run",
		bounds = { x0 = -half - margin, z0 = -half - margin, x1 = half + margin, z1 = half + margin },
		play = { x0 = -half, z0 = -half, x1 = half, z1 = half },
		ground = "grass",
		edge = "forest",
		zones = ground,
		paths = {},
		buildings = buildings,
		fences = {},
		trees = trees,
		points = points,
	}
end

-- The ground read from a run map's terrain, and when. It is read again once a few seconds
-- after arriving, when the terrain around has streamed in.
type Ground = { zones: { MapData.Zone }, at: number, reads: number }
local derivedGround: { [string]: Ground } = {}
local GROUND_REREAD = 5

local function refreshRun()
	local folder = runFolder()
	if folder == nil or folder:GetAttribute("Ready") == false then
		return
	end
	local origin = folder:GetAttribute("Origin")
	local half = folder:GetAttribute("Half")
	local locationId = folder:GetAttribute("LocationId")
	if typeof(origin) ~= "Vector3" then
		return
	end
	local supplied = if type(locationId) == "string" then Maps[locationId] else nil
	if supplied then
		local key = `{folder:GetFullName()}|supplied`
		if runKey ~= key then
			runKey = key
			setCurrent(supplied, origin, "run")
		end
		return
	end
	local size = if type(half) == "number" then half else 125
	-- Re-derive when more of the map has streamed in (or been built).
	local groundKey = folder:GetFullName()
	local ground = derivedGround[groundKey]
	if ground == nil or (ground.reads < 2 and os.clock() - ground.at > GROUND_REREAD) then
		ground = { zones = deriveGround(origin, size), at = os.clock(), reads = if ground then ground.reads + 1 else 1 }
		derivedGround[groundKey] = ground
	end
	local signature =
		`{groundKey}|{(ground :: Ground).reads}|{#CollectionService:GetTagged("EO_Roof")}|{#CollectionService:GetTagged(
			"EO_Canopy"
		)}|{#CollectionService:GetTagged("EO_RunExit")}`
	if runKey == signature then
		return
	end
	runKey = signature
	setCurrent(deriveRun(folder, origin, size, (ground :: Ground).zones), origin, "run")
end

-- Features: outposts and plot nodes -----------------------------------------------------------------

local featureKey = ""

local function refreshFeatures()
	local map = current
	if map == nil or map.kind ~= "home" then
		if #features.outposts > 0 or #features.trees > 0 then
			features = { outposts = {}, trees = {}, rocks = {}, version = features.version + 1 }
			Radar.featuresChanged:Fire()
		end
		return
	end
	local origin = map.origin
	local pieces = CollectionService:GetTagged("EO_Piece")
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	local nodes: { Instance } = {}
	for _, plot in (if plots then plots:GetChildren() else {}) do
		local folder = plot:FindFirstChild("Nodes")
		for _, node in (if folder then folder:GetChildren() else {}) do
			if node:IsA("Model") and node:GetAttribute("Standing") ~= false then
				table.insert(nodes, node)
			end
		end
	end
	local key = `{#pieces}|{#nodes}`
	for _, piece in pieces do
		key ..= piece.Name
	end
	if key == featureKey then
		return
	end
	featureKey = key
	local outposts: { Rect } = {}
	for _, piece in pieces do
		if not piece:IsA("Model") then
			continue
		end
		local layer = piece:GetAttribute("Layer")
		if layer ~= "floor" and layer ~= "frame" and layer ~= "fill" then
			continue
		end
		local ok, frame, size = pcall(function()
			return piece:GetBoundingBox()
		end)
		if not ok then
			continue
		end
		local w, d = size.X, size.Z -- in the piece's own axes, turned by its yaw
		table.insert(outposts, {
			x = frame.Position.X - origin.X,
			z = frame.Position.Z - origin.Z,
			w = if layer == "floor" then w else math.max(w, 1.6),
			d = if layer == "floor" then d else math.max(d, 1.6),
			yaw = flatYaw(frame),
			kind = if layer == "floor" then "floor" else "wall",
			mine = piece:GetAttribute("OwnerUserId") == player.UserId,
		})
	end
	-- Floors first, walls over them.
	table.sort(outposts, function(a, b)
		return a.kind == "floor" and b.kind ~= "floor"
	end)
	local trees: { MapData.Point } = {}
	local rocks: { MapData.Point } = {}
	for _, node in nodes do
		local at = (node :: Model):GetPivot().Position - origin
		local id = node:GetAttribute("NodeId")
		-- Trees mark the plots; stones, sticks and fibre would only speckle the map.
		if type(id) == "string" and string.find(id, "tree") then
			table.insert(trees, { x = at.X, z = at.Z })
		end
	end
	features = { outposts = outposts, trees = trees, rocks = rocks, version = features.version + 1 }
	Radar.featuresChanged:Fire()
end

-- Blips -------------------------------------------------------------------------------------------------

-- Only buildings hide a Hollow from you: from the camera's height trees and props don't.
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Include

local function rootPart(): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function inSight(from: Vector3, to: Vector3, walls: { Instance }): boolean
	local offset = to - from
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > SIGHT then
		return false
	end
	if #walls == 0 then
		return true
	end
	sightParams.FilterDescendantsInstances = walls
	-- Chest height to chest height.
	local rise = Vector3.new(0, 2, 0)
	local hit = workspace:Raycast(from + rise, (to + rise * 1.5) - (from + rise), sightParams)
	return hit == nil
end

-- The buildings of the run map in view (the parents of tagged roofs).
local function buildingsOf(folder: Instance?): { Instance }
	local list: { Instance } = {}
	local seen: { [Instance]: boolean } = {}
	for _, roof in CollectionService:GetTagged("EO_Roof") do
		local building = roof.Parent
		if building and not seen[building] and (folder == nil or building:IsDescendantOf(folder)) then
			seen[building] = true
			table.insert(list, building)
		end
	end
	return list
end

local function openExits(): { [string]: boolean }?
	local run = State.get("run")
	local exits = if type(run) == "table" then run.extraction else nil
	if type(exits) ~= "table" or exits.kind ~= "points" or type(exits.open) ~= "table" then
		return nil
	end
	local open: { [string]: boolean } = {}
	for _, id in exits.open do
		open[id] = true
	end
	return open
end

local function gather()
	local list: { Blip } = {}
	local root = rootPart()
	local here = if root then root.Position else nil
	local map = current
	local running = onRun()
	-- Other survivors: your party always, anyone else only at home.
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local character = other.Character
			local otherRoot = character and character:FindFirstChild("HumanoidRootPart")
			local friend = party[other.UserId] == true
			if otherRoot and (friend or not running) then
				table.insert(
					list,
					{ key = `p{other.UserId}`, kind = if friend then "party" else "survivor", instance = otherRoot }
				)
			end
		end
	end
	if running then
		-- The Hollow: alerted ones, or ones in plain sight.
		local walls = buildingsOf(runFolder())
		for _, blip in HollowView.blips() do
			local position = blip.model:GetPivot().Position
			if ALERT_STATES[blip.state] or (here and inSight(here :: Vector3, position, walls)) then
				local entry: Blip = { key = `h{blip.id}`, kind = "hollow", instance = blip.model }
				table.insert(list, entry)
			end
		end
		for _, holder in CollectionService:GetTagged("EO_RunContainer") do
			if holder:IsA("Model") and holder:GetAttribute("Kind") ~= "pile" then
				local body = holder.PrimaryPart or holder:FindFirstChild("Body", true)
				if body and body:IsA("BasePart") then
					local stocked = body:GetAttribute("ContainerId") ~= nil
					local opened = body:GetAttribute("Opened") == true
					table.insert(list, {
						key = keyOf("c", holder),
						kind = "container",
						at = body.Position,
						dim = opened or not stocked,
					})
				end
			end
		end
		local run = State.get("run")
		for index, drop in (if type(run) == "table" and type(run.drops) == "table" then run.drops else {}) do
			if type(drop.at) == "table" and here then
				table.insert(list, {
					key = `b{drop.id or index}`,
					kind = "bag",
					at = Vector3.new(drop.at[1], (here :: Vector3).Y, drop.at[2]),
					mine = drop.mine == true,
				})
			end
		end
		-- The last loud noise (a gunshot, a bloater) as a fading ring.
		local noise = State.get("noise")
		if type(noise) == "table" and os.clock() - noise.at < Radar.NOISE_SECONDS and here then
			table.insert(list, {
				key = `z{noise.at}`,
				kind = "noise",
				at = Vector3.new(noise.x, (here :: Vector3).Y, noise.z),
				radius = noise.radius,
				born = noise.at,
			})
		end
		local open = openExits()
		for _, exit in CollectionService:GetTagged("EO_RunExit") do
			if exit:IsA("Model") then
				local id = exit:GetAttribute("PointId")
				table.insert(list, {
					key = keyOf("x", exit),
					kind = "exit",
					at = exit:GetPivot().Position,
					dim = open ~= nil and type(id) == "string" and not open[id],
					pin = true,
					label = exit:GetAttribute("ExitName") :: string?,
				})
			end
		end
	else
		local stations = State.get("stations")
		for _, model in CollectionService:GetTagged("EO_Station") do
			if model:IsA("Model") and model:GetAttribute("OwnerUserId") == player.UserId then
				local uid = model:GetAttribute("Uid")
				local record = if type(stations) == "table" and type(uid) == "string" then stations[uid] else nil
				local ready = type(record) == "table" and type(record.output) == "table" and Converter.ready(record) > 0
				table.insert(list, {
					key = keyOf("s", model),
					kind = "station",
					at = model:GetPivot().Position,
					ready = ready,
				})
			end
		end
		for _, drop in CollectionService:GetTagged("EO_Drop") do
			if drop:IsA("Model") then
				table.insert(list, {
					key = keyOf("d", drop),
					kind = "bag",
					at = drop:GetPivot().Position,
					mine = drop:GetAttribute("OwnerUserId") == player.UserId,
				})
			end
		end
		for _, model in CollectionService:GetTagged("EO_Haven") do
			local id = model:GetAttribute("HavenId")
			local glyph = if type(id) == "string" then NPC_GLYPHS[id] else nil
			if glyph and model:IsA("Model") then
				local def = Content.Haven.npcs[id :: string]
				table.insert(list, {
					key = `n{id}`,
					kind = "npc",
					at = model:GetPivot().Position,
					glyph = glyph,
					label = if def then def.title else nil,
				})
			end
		end
		if map and map.kind == "home" then
			for _, point in map.map.points do
				if point.kind == "trailhead" or point.kind == "fire" then
					table.insert(list, {
						key = `m{point.id}`,
						kind = if point.kind == "fire" then "fire" else "exit",
						at = map.origin + Vector3.new(point.x, 0, point.z),
						pin = point.kind == "trailhead",
						label = point.label,
					})
				end
			end
		end
	end
	blips = list
end

-- Start ----------------------------------------------------------------------------------------------------

local function refreshMap()
	if onRun() then
		refreshRun()
		return
	end
	runKey = nil
	local origin = worldOrigin()
	if origin == nil then
		return
	end
	local grew = learnHaven(origin)
	if current == nil or current.kind ~= "home" or grew then
		buildHome(origin)
	end
end

function Radar.start()
	State.fx:Connect(function(kind: string, payload: any)
		if kind ~= "party" then
			return
		end
		party = {}
		if type(payload) == "table" and type(payload.members) == "table" then
			for _, userId in payload.members do
				party[userId] = true
			end
		end
	end)
	task.spawn(function()
		local sinceFeatures = math.huge
		while true do
			local ok, err = pcall(refreshMap :: any)
			if not ok then
				warn(`[Radar] map: {err}`)
			end
			sinceFeatures += GATHER_SECONDS
			if sinceFeatures >= FEATURE_SECONDS then
				sinceFeatures = 0
				local fine, problem = pcall(refreshFeatures :: any)
				if not fine then
					warn(`[Radar] features: {problem}`)
				end
			end
			local done, failure = pcall(gather :: any)
			if not done then
				warn(`[Radar] blips: {failure}`)
			end
			task.wait(GATHER_SECONDS)
		end
	end)
end

return Radar
