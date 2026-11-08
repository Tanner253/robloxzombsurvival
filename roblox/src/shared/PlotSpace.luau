--!strict
--[[
	PlotSpace: converts between Domain/Grid coordinates and world space, for the
	server (placing models) and the client (ghost preview, cursor snapping).

	A plot's origin is the world position of grid corner (0, 0) at ground level.
	Grid +X is world +X and grid +Z is world +Z (plots are never rotated).
	Foundations sit with their top at Art.FLOOR_HEIGHT; walls and doors stand on
	that height; objects stand on their foundations (the ground if a raid took
	them), centred on their quarter-cell footprint. An object whose back edge
	lies on a wall stands off it by WALL_CLEARANCE so its back sits flush against
	the wall's face instead of inside it.

	An object's back is its +Z side at rotation 0; `rot` quarter turns move it to
	+X, -Z, -X.
]]

local Art = require("./Art")
local Grid = require("./Domain/Grid")
local Types = require("./Types")

local PlotSpace = {}

-- Half a wall's thickness: how far an object stands off a wall behind it.
PlotSpace.WALL_CLEARANCE = 1

-- The unit back direction (x, z) of an object at a rotation.
function PlotSpace.backOf(rot: number?): (number, number)
	local r = (rot or 0) % 4
	if r == 0 then
		return 0, 1
	elseif r == 1 then
		return 1, 0
	elseif r == 2 then
		return 0, -1
	end
	return -1, 0
end

-- World CFrame of a cell centre, at `height` above the plot's ground.
function PlotSpace.cell(origin: Vector3, x: number, z: number, height: number, rot: number?): CFrame
	local cx, cz = Grid.cellCenter(x, z)
	return CFrame.new(origin + Vector3.new(cx, height, cz)) * CFrame.Angles(0, math.rad(90 * (rot or 0)), 0)
end

-- World CFrame of an edge centre on top of the floor, facing along the edge.
function PlotSpace.edge(origin: Vector3, axis: Grid.Axis, x: number, z: number): CFrame
	local ex, ez, yaw = Grid.edgeCenter(axis, x, z)
	return CFrame.new(origin + Vector3.new(ex, Art.FLOOR_HEIGHT, ez)) * CFrame.Angles(0, math.rad(yaw), 0)
end

-- Whether a wall-layer piece stands on the edge behind an object's footprint.
function PlotSpace.wallBehind(layout: Grid.Layout, def: Types.BuildPieceDef, target: Grid.Target): boolean
	local w, d = Grid.footprint(def, target.rot)
	local bx, bz = PlotSpace.backOf(target.rot)
	local sub = Grid.SUB
	if bz ~= 0 then
		local line = if bz > 0 then target.z + d else target.z
		if line % sub ~= 0 then
			return false
		end
		for qx = target.x, target.x + w - 1 do
			if Grid.pieceAt(layout, "frame", qx // sub, line // sub, "h") then
				return true
			end
		end
	else
		local line = if bx > 0 then target.x + w else target.x
		if line % sub ~= 0 then
			return false
		end
		for qz = target.z, target.z + d - 1 do
			if Grid.pieceAt(layout, "frame", line // sub, qz // sub, "v") then
				return true
			end
		end
	end
	return false
end

-- World CFrame of an object's model pivot (bottom centre) on its footprint.
function PlotSpace.object(origin: Vector3, layout: Grid.Layout, def: Types.BuildPieceDef, target: Grid.Target): CFrame
	local cx, cz = Grid.objectCenter(def, target)
	local onFloor = false
	for _, cell in Grid.cellsUnder(def, target) do
		if Grid.pieceAt(layout, "floor", cell.x, cell.z) then
			onFloor = true
			break
		end
	end
	if PlotSpace.wallBehind(layout, def, target) then
		local bx, bz = PlotSpace.backOf(target.rot)
		cx -= bx * PlotSpace.WALL_CLEARANCE
		cz -= bz * PlotSpace.WALL_CLEARANCE
	end
	local height = if onFloor then Art.FLOOR_HEIGHT else 0
	return CFrame.new(origin + Vector3.new(cx, height, cz))
		* CFrame.Angles(0, math.rad(90 * ((target.rot or 0) % 4)), 0)
end

-- Where a piece's model pivot goes. Objects need their definition (`def`).
function PlotSpace.target(
	origin: Vector3,
	layout: Grid.Layout,
	layer: Grid.Layer,
	target: Grid.Target,
	def: Types.BuildPieceDef
): CFrame
	if layer == "frame" or layer == "fill" then
		return PlotSpace.edge(origin, target.axis :: Grid.Axis, target.x, target.z)
	elseif layer == "floor" then
		return PlotSpace.cell(origin, target.x, target.z, Art.FLOOR_HEIGHT)
	elseif layer == "object" then
		return PlotSpace.object(origin, layout, def, target)
	end
	local onFloor = Grid.pieceAt(layout, "floor", target.x, target.z) ~= nil
	return PlotSpace.cell(origin, target.x, target.z, if onFloor then Art.FLOOR_HEIGHT else 0, target.rot)
end

-- Where a placed piece's model pivot goes.
function PlotSpace.piece(origin: Vector3, layout: Grid.Layout, piece: Grid.Piece, def: Types.BuildPieceDef): CFrame
	return PlotSpace.target(
		origin,
		layout,
		piece.layer,
		{ x = piece.x, z = piece.z, axis = piece.axis, rot = piece.rot },
		def
	)
end

-- A world position relative to the plot corner, in studs (X, Z).
function PlotSpace.toLocal(origin: Vector3, world: Vector3): (number, number)
	return world.X - origin.X, world.Z - origin.Z
end

return PlotSpace
