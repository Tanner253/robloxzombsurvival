--!strict
--[[
	RoofFade: walk into a building and its roof lifts away so you can see the room
	(checklist 2.3, LDoE parity; the rules and numbers are in Domain/Interior).

	The server marks every building you can stand in (World/Interiors): its footprint as
	attributes, and tags on its roof, upper parts and eave signs (EO_InteriorRoof) and on
	its walls with their outward normals (EO_InteriorWall). Ten times a second, for the
	buildings near the survivor only:
	- the one they're inside (Domain/Interior.pick, with doorway hysteresis): the roof
	  eases almost out and the walls facing the camera turn to a ghost;
	- one ray from the camera to the survivor against the nearby roofs: a roof that
	  hides them from outside turns to a ghost.
	Each part eases its LocalTransparencyModifier over FADE_SECONDS, every frame while
	something is moving and not at all once everything rests. CastShadow is untouched and
	the roof stops short of fully gone, so the room keeps its shade.

	Owner of what it fades: WorldFx's wall occlusion skips roof-tagged parts always, and
	wall parts while this holds them (`holds`), so the two never write the same part.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Interior = require(ReplicatedStorage.Shared.Domain.Interior)

local RoofFade = {}

local player = Players.LocalPlayer
local CHECK_SECONDS = 0.1
local CHEST = Vector3.new(0, 1.5, 0) -- the ray aims at the survivor's chest

type Wall = { parts: { BasePart }, nx: number, nz: number }
type Entry = {
	footprint: Interior.Footprint?,
	holders: { Instance }, -- the roof-tagged holders and parts, for the ray
	roofs: { BasePart },
	walls: { Wall },
	dirty: boolean,
	connections: { RBXScriptConnection },
}

-- Every marked building the client knows, read lazily (parts stream in and out).
local entries: { [Instance]: Entry } = {}

type Fade = { now: number, target: number }
local fades: { [BasePart]: Fade } = {}

local current: Instance? = nil -- the building the survivor is inside
local active: { [Instance]: boolean } = {} -- buildings with a fade wanted
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

-- Whether this controller is fading the part right now (WorldFx leaves it alone).
function RoofFade.holds(part: BasePart): boolean
	return fades[part] ~= nil
end

-- Reading a building ------------------------------------------------------------------------------

local function partsOf(instance: Instance, into: { BasePart })
	if instance:IsA("BasePart") then
		table.insert(into, instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(into, descendant)
		end
	end
end

local function footprintOf(building: Instance): Interior.Footprint?
	local floor = building:GetAttribute(Interior.FLOOR_ATTR)
	local size = building:GetAttribute(Interior.SIZE_ATTR)
	if typeof(floor) ~= "CFrame" or typeof(size) ~= "Vector3" then
		return nil
	end
	local _, yaw = floor:ToEulerAnglesYXZ()
	local at = floor.Position
	return Interior.footprint(at.X, at.Y, at.Z, yaw, size.X, size.Z, size.Y)
end

-- The building's roof and wall parts, re-read after anything under it changed.
local function refresh(building: Instance, entry: Entry): Entry
	if not entry.dirty then
		return entry
	end
	entry.dirty = false
	entry.footprint = footprintOf(building)
	entry.holders, entry.roofs, entry.walls = {}, {}, {}
	for _, descendant in building:GetDescendants() do
		if CollectionService:HasTag(descendant, Interior.ROOF_TAG) then
			table.insert(entry.holders, descendant)
			partsOf(descendant, entry.roofs)
		elseif CollectionService:HasTag(descendant, Interior.WALL_TAG) then
			local facing = descendant:GetAttribute(Interior.FACING_ATTR)
			if typeof(facing) == "Vector3" then
				local wall: Wall = { parts = {}, nx = facing.X, nz = facing.Z }
				partsOf(descendant, wall.parts)
				table.insert(entry.walls, wall)
			end
		end
	end
	return entry
end

local function forget(building: Instance)
	local entry = entries[building]
	if entry then
		for _, connection in entry.connections do
			connection:Disconnect()
		end
		entries[building] = nil
	end
end

local function learn(building: Instance)
	if entries[building] then
		return
	end
	local entry: Entry = {
		footprint = nil,
		holders = {},
		roofs = {},
		walls = {},
		dirty = true,
		connections = {},
	}
	local function stale()
		entry.dirty = true
	end
	table.insert(entry.connections, building.DescendantAdded:Connect(stale))
	table.insert(entry.connections, building.DescendantRemoving:Connect(stale))
	entries[building] = entry
end

-- The marked building a part belongs to.
local function buildingOf(part: Instance): Instance?
	local node: Instance? = part
	while node and node ~= workspace do
		if entries[node] then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Fading ----------------------------------------------------------------------------------------------

local function fadeTo(part: BasePart, target: number)
	local fade = fades[part]
	if fade then
		fade.target = target
	elseif target > 0 then
		-- Start from where the part stands (a wall WorldFx was ghosting carries on smoothly).
		fades[part] = { now = part.LocalTransparencyModifier, target = target }
	end
end

local function setBuilding(building: Instance, roof: number, walls: number, lookX: number, lookZ: number)
	local entry = entries[building]
	if entry == nil then
		return -- gone (the run map was cleared); its parts left with it
	end
	entry = refresh(building, entry)
	for _, part in entry.roofs do
		fadeTo(part, roof)
	end
	for _, wall in entry.walls do
		local alpha = if walls > 0 and Interior.facesCamera(wall.nx, wall.nz, lookX, lookZ) then walls else 0
		for _, part in wall.parts do
			fadeTo(part, alpha)
		end
	end
end

local function stepFades(dt: number)
	for part, fade in fades do
		if part.Parent == nil then
			fades[part] = nil
			continue
		end
		local now = Interior.step(fade.now, fade.target, dt)
		if now ~= fade.now then
			fade.now = now
			part.LocalTransparencyModifier = now
		end
		if now == 0 and fade.target == 0 then
			fades[part] = nil -- back at rest: released
		end
	end
end

-- The check -------------------------------------------------------------------------------------------

local function check()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	local inside: Instance? = nil
	local shading: Instance? = nil
	local lookX, lookZ = -1, -1
	if root and camera then
		local at = root.Position
		local look = camera.CFrame.LookVector
		lookX, lookZ = look.X, look.Z
		-- Only the buildings near the survivor.
		local nearby: { Instance } = {}
		local footprints: { Interior.Footprint } = {}
		for building, entry in entries do
			local footprint = entry.footprint or footprintOf(building)
			entry.footprint = footprint
			if footprint and Interior.near(footprint, at.X, at.Z, Interior.NEAR) then
				table.insert(nearby, building)
				table.insert(footprints, footprint)
			end
		end
		local index = Interior.pick(footprints, at.X, at.Y, at.Z, if current then table.find(nearby, current) else nil)
		inside = if index then nearby[index] else nil
		-- One ray from the camera to the survivor, against the nearby roofs only.
		local holders: { Instance } = {}
		for _, building in nearby do
			for _, holder in refresh(building, entries[building]).holders do
				table.insert(holders, holder)
			end
		end
		if #holders > 0 then
			rayParams.FilterDescendantsInstances = holders
			local from = camera.CFrame.Position
			local hit = workspace:Raycast(from, at + CHEST - from, rayParams)
			if hit then
				shading = buildingOf(hit.Instance)
			end
		end
	end
	current = inside
	for building in active do
		if building ~= inside and building ~= shading then
			active[building] = nil
			setBuilding(building, 0, 0, lookX, lookZ)
		end
	end
	if inside then
		local roof, walls = Interior.targets(true, false)
		setBuilding(inside, roof, walls, lookX, lookZ)
		active[inside] = true
	end
	if shading and shading ~= inside then
		local roof, walls = Interior.targets(false, true)
		setBuilding(shading, roof, walls, lookX, lookZ)
		active[shading] = true
	end
end

-- Lifecycle -------------------------------------------------------------------------------------------

function RoofFade.start()
	CollectionService:GetInstanceAddedSignal(Interior.TAG):Connect(learn)
	CollectionService:GetInstanceRemovedSignal(Interior.TAG):Connect(forget)
	for _, building in CollectionService:GetTagged(Interior.TAG) do
		learn(building)
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= CHECK_SECONDS then
			elapsed = 0
			check()
		end
		if next(fades) ~= nil then
			stepFades(dt)
		end
	end)
end

return RoofFade
