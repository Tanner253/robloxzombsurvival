--!strict
--[[
	PlotSpace: converts between Domain/Grid coordinates and world space, for the
	server (placing models) and the client (ghost preview, cursor snapping).

	A plot's origin is the world position of grid corner (0, 0) at ground level.
	Grid +X is world +X and grid +Z is world +Z (plots are never rotated).
	Foundations sit with their top at Art.FLOOR_HEIGHT; walls and doors stand on
	that height; objects stand on a foundation when there is one, else the ground.
]]

local Art = require("./Art")
local Grid = require("./Domain/Grid")

local PlotSpace = {}

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

-- Where a piece's model pivot goes. `onFloor` says whether an object has a
-- foundation under it.
function PlotSpace.target(origin: Vector3, layer: Grid.Layer, target: Grid.Target, onFloor: boolean): CFrame
	if layer == "frame" or layer == "fill" then
		return PlotSpace.edge(origin, target.axis :: Grid.Axis, target.x, target.z)
	elseif layer == "floor" then
		return PlotSpace.cell(origin, target.x, target.z, Art.FLOOR_HEIGHT)
	end
	return PlotSpace.cell(origin, target.x, target.z, if onFloor then Art.FLOOR_HEIGHT else 0, target.rot)
end

-- The pivot of a placed piece in a layout.
function PlotSpace.piece(origin: Vector3, layout: Grid.Layout, piece: Grid.Piece): CFrame
	local onFloor = Grid.pieceAt(layout, "floor", piece.x, piece.z) ~= nil
	return PlotSpace.target(
		origin,
		piece.layer,
		{ x = piece.x, z = piece.z, axis = piece.axis, rot = piece.rot },
		onFloor
	)
end

-- A world position in plot-local studs (x, z from the grid corner).
function PlotSpace.toLocal(origin: Vector3, world: Vector3): (number, number)
	return world.X - origin.X, world.Z - origin.Z
end

return PlotSpace
