--!strict
--[[
	Maps: each Fog Run location's minimap picture in the shared map format
	(Domain/MapData, docs/MINIMAP_FORMAT.md), keyed by location id. The minimap and the
	full-screen map draw whatever is here; a location missing from this table is drawn
	from what the client can see of its built map (Controllers/Radar) until it is added.

	Add a location as its own module beside this one (Data/Maps/PineHollow.luau returning
	a MapData.Map) and list it below: ["loc.pine_hollow"] = require("@self/PineHollow").
	The layout module that builds the map can read the same paths and footprints, so the
	picture and the ground never drift apart. The Lune spec validates every entry.
	The Neighbourhood isn't listed: it is generated from Tuning (Domain/NeighbourhoodMap).
]]

local MapData = require("../Domain/MapData")

local Maps: { [string]: MapData.Map } = {}

return Maps
