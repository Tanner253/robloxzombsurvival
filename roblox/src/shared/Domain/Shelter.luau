--!strict
--[[
	Shelter: lays the damaged starter shelter (Data/StarterShelter, LDOE_PARITY #56) onto a
	fresh layout. Pure.

	The data is authored for a plot whose road is on +Z (front = 1). For the facing row
	(front = -1) every piece is mirrored across the plot's middle on Z, so the shelter
	always opens to the road. Pieces go down through Grid.place (so the result is a layout
	the game could have built itself), then lose HP down to their `hp` fraction.
]]

local Types = require("../Types")
local Grid = require("./Grid")

local Shelter = {}

-- One piece mirrored on Z for a plot `depth` cells deep.
function Shelter.mirror(piece: Types.StarterPiece, def: Types.BuildPieceDef, depth: number): Types.StarterPiece
	local layer = Grid.layerOf(def)
	local result = table.clone(piece)
	if layer == "object" then
		local rot = (piece.rot or 0) % 4
		local _, d = Grid.footprint(def, rot)
		result.z = depth * Grid.SUB - piece.z - d
		result.rot = if rot % 2 == 0 then (rot + 2) % 4 else rot
	elseif piece.axis == "h" then
		result.z = depth - piece.z
	else
		result.z = depth - 1 - piece.z
	end
	return result
end

--[[
	The layout of a new plot: the shelter placed for `front` (+1 road on +Z, -1 on -Z).
	Returns the layout, or the empty layout and the first reason a piece could not be
	placed (a data error; the validator spec runs this for both rows).
]]
function Shelter.build(
	pieces: { Types.StarterPiece },
	defs: Grid.Defs,
	plot: Grid.Plot,
	front: number,
	now: number
): (Grid.Layout, string?)
	local ctx: Grid.Context = {
		plot = plot,
		actorUserId = plot.ownerUserId,
		pieces = defs,
		now = now,
	}
	local layout = Grid.new()
	for index, entry in pieces do
		local def = defs[entry.pieceId]
		if def == nil then
			return Grid.new(), `piece {index}: unknown '{entry.pieceId}'`
		end
		local spot = if front < 0 then Shelter.mirror(entry, def, plot.depth) else entry
		local target: Grid.Target = { x = spot.x, z = spot.z, axis = spot.axis, rot = spot.rot }
		local placed, piece, reason = Grid.place(layout, entry.pieceId, target, ctx)
		if placed == nil or piece == nil then
			return Grid.new(), `piece {index} ({entry.pieceId}): {reason}`
		end
		layout = placed
		local fraction = math.clamp(entry.hp, 0.05, 1)
		if fraction < 1 then
			layout = Grid.damage(layout, piece.uid, def.hp * (1 - fraction), defs)
		end
	end
	return layout, nil
end

return Shelter
