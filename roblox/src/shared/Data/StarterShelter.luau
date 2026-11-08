--!strict
--[[
	The damaged starter shelter every new plot starts with (LDOE_PARITY #56): a timber
	floor, a few broken walls, a cold campfire and a crate, so a new player arrives at
	something to patch up rather than an empty field, as in LDoE.

	Laid out for a plot whose road is on +Z (Domain/Shelter mirrors it for the facing
	row). The plot is Tuning.building.plotCells wide; the shelter sits in the middle,
	open to the road. Missing wall segments are the damage; `hp` is the fraction of full
	HP each piece starts at. Ember Trail quest 3 asks the player to patch it.
]]

local Types = require("../Types")

local StarterShelter: { Types.StarterPiece } = {
	-- A 3 x 3 timber floor.
	{ pieceId = "build.foundation_wood", x = 6, z = 5, hp = 0.7 },
	{ pieceId = "build.foundation_wood", x = 7, z = 5, hp = 0.6 },
	{ pieceId = "build.foundation_wood", x = 8, z = 5, hp = 0.75 },
	{ pieceId = "build.foundation_wood", x = 6, z = 6, hp = 0.65 },
	{ pieceId = "build.foundation_wood", x = 7, z = 6, hp = 0.8 },
	{ pieceId = "build.foundation_wood", x = 8, z = 6, hp = 0.6 },
	{ pieceId = "build.foundation_wood", x = 6, z = 7, hp = 0.7 },
	{ pieceId = "build.foundation_wood", x = 7, z = 7, hp = 0.75 },
	{ pieceId = "build.foundation_wood", x = 8, z = 7, hp = 0.65 },
	-- Back wall with a gap in the middle.
	{ pieceId = "build.wall_wood", x = 6, z = 5, axis = "h", hp = 0.5 },
	{ pieceId = "build.wall_wood", x = 8, z = 5, axis = "h", hp = 0.45 },
	-- Left side, its front segment gone.
	{ pieceId = "build.wall_wood", x = 6, z = 5, axis = "v", hp = 0.55 },
	{ pieceId = "build.wall_wood", x = 6, z = 6, axis = "v", hp = 0.4 },
	-- Right side: one segment left standing.
	{ pieceId = "build.wall_wood", x = 9, z = 5, axis = "v", hp = 0.5 },
	-- A cold campfire in the middle and a crate against the back wall (backs face -Z).
	{ pieceId = "build.campfire", x = 29, z = 25, rot = 2, hp = 0.8 },
	{ pieceId = "build.crate_wood", x = 25, z = 20, rot = 2, hp = 0.7 },
}

return StarterShelter
