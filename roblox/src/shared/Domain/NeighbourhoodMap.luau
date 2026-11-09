--!strict
--[[
	NeighbourhoodMap: the Neighbourhood as MapData (checklist 8.11), generated from the
	same layout the server builds it from (Domain/Neighbourhood, Tuning.plots and the plot
	grid), so the minimap always matches the ground. Pure.

	- The ground: living grass inside, drying out toward the fog; the earth pad under each
	  of the 8 plots with its footpath to the road; the road through the middle; Haven
	  Square's trodden oval, the VIP Lounge's fenced yard and the trail north to the
	  Trailhead.
	- The edges: the pine rows just past the plots and the fog wall beyond them, open
	  where the trail leaves (where Services/Scenery plants and banks them).
	- Points: the plots, Haven Square, its campfire, the Lounge and the Trailhead.
	Haven's stalls aren't in shared data; the client adds them from the world
	(Controllers/Radar).
]]

local MapData = require("./MapData")
local Neighbourhood = require("./Neighbourhood")

local NeighbourhoodMap = {}

-- Where Services/Scenery dresses the edges, past the plots' outer margin (studs).
local TREE_IN, TREE_OUT = 20, 54 -- the three pine rows
local TRAIL_GAP = 16 -- the rows leave the trail open
local FOG_X, FOG_Z = 110, 90 -- the fog banks
local SURROUND = 60 -- drawn past the fog wall
local PAD_GROW = 4 -- each plot's earth pad reaches past its grid
local FOOTPATH = 5
local TRAIL = 8
local ROAD_END = 30 -- past the plots' margin, inside the pine rows

export type PlotsTuning = Neighbourhood.Tuning

local function rect(
	kind: MapData.ZoneKind,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	soft: boolean?
): MapData.Zone
	return {
		kind = kind,
		shape = "rect",
		x = (x0 + x1) / 2,
		z = (z0 + z1) / 2,
		w = x1 - x0,
		d = z1 - z0,
		soft = soft,
	}
end

--[[
	The Neighbourhood for `plots` (Tuning.plots) and `gridStuds` (a plot's build grid
	edge: plotCells x the cell size).
]]
function NeighbourhoodMap.build(plots: PlotsTuning, gridStuds: number): MapData.Map
	local halfW = Neighbourhood.halfWidth(plots, gridStuds)
	local halfD = Neighbourhood.halfDepth(plots, gridStuds)
	local trailX, trailZ = Neighbourhood.trailhead(plots, gridStuds)
	local fogX, fogZ = halfW + FOG_X, halfD + FOG_Z
	local bounds = { x0 = -fogX - SURROUND, z0 = -fogZ - SURROUND, x1 = fogX + SURROUND, z1 = fogZ + SURROUND }
	local roadHalf = plots.rowGapStuds * 0.4

	-- Past the plots' margin the grass dries out toward the fog (the map's `edge`).
	local zones: { MapData.Zone } = {}
	-- The pine rows: north (split by the trail), south, west and east.
	local treeX = halfW + TREE_OUT
	table.insert(zones, rect("forest", -treeX, -halfD - TREE_OUT, trailX - TRAIL_GAP, -halfD - TREE_IN))
	table.insert(zones, rect("forest", trailX + TRAIL_GAP, -halfD - TREE_OUT, treeX, -halfD - TREE_IN))
	table.insert(zones, rect("forest", -treeX, halfD + TREE_IN, treeX, halfD + TREE_OUT))
	table.insert(zones, rect("forest", -treeX, -halfD - TREE_IN, -halfW - TREE_IN, halfD + TREE_IN))
	table.insert(zones, rect("forest", halfW + TREE_IN, -halfD - TREE_IN, treeX, halfD + TREE_IN))
	-- The fog wall and everything past it (each side the full length: they overlap at the corners).
	table.insert(zones, rect("fog", bounds.x0, bounds.z0, bounds.x1, -fogZ, true))
	table.insert(zones, rect("fog", bounds.x0, fogZ, bounds.x1, bounds.z1, true))
	table.insert(zones, rect("fog", bounds.x0, bounds.z0, -fogX, bounds.z1, true))
	table.insert(zones, rect("fog", fogX, bounds.z0, bounds.x1, bounds.z1, true))

	-- The road, west and east of Haven Square (the square's trodden ground covers it
	-- there), running on into the pines at each side (they're drawn over its ends).
	local squareEdge = plots.plazaHalfStuds * 0.9
	local paths: { MapData.Path } = {
		{
			kind = "road",
			width = roadHalf * 2,
			points = { { x = -halfW - ROAD_END, z = 0 }, { x = -squareEdge, z = 0 } },
		},
		{
			kind = "road",
			width = roadHalf * 2,
			points = { { x = squareEdge, z = 0 }, { x = halfW + ROAD_END, z = 0 } },
		},
		{
			kind = "trail",
			width = TRAIL,
			points = {
				{ x = trailX, z = -plots.plazaDepthStuds + 12 },
				{ x = trailX, z = (trailZ - plots.plazaDepthStuds) / 2 },
				{ x = trailX, z = trailZ - 24 },
			},
		},
	}
	local points: { MapData.MapPoint } = {}
	local padSize = gridStuds + PAD_GROW * 2
	for index = 1, plots.count do
		local x, z, front = Neighbourhood.plotCentre(plots, gridStuds, index)
		table.insert(zones, {
			kind = "earth",
			shape = "rect",
			x = x,
			z = z,
			w = padSize,
			d = padSize,
			round = 14,
			soft = true,
		})
		-- The footpath from the pad's road edge to the road.
		local edge = z + front * (padSize / 2)
		table.insert(paths, {
			kind = "path",
			width = FOOTPATH,
			points = { { x = x, z = edge - front * 4 }, { x = x, z = -front * (roadHalf - 2) } },
		})
		table.insert(points, { id = `plot.{index}`, kind = "plot", x = x, z = z, label = `Plot {index}` })
	end
	-- Haven Square: the trodden oval, and the Lounge's yard in its south-east corner.
	table.insert(zones, {
		kind = "plaza",
		shape = "ellipse",
		x = 0,
		z = 0,
		w = plots.plazaHalfStuds * 2,
		d = plots.plazaDepthStuds * 2,
		soft = true,
	})
	local lounge = Neighbourhood.lounge
	table.insert(zones, rect("yard", lounge.x0, lounge.z0, lounge.x1, lounge.z1))
	local gateX = (lounge.x0 + lounge.x1) / 2
	local gateHalf = lounge.gateWidth / 2
	local fences: { MapData.Fence } = {
		{
			kind = "palisade",
			points = {
				{ x = gateX - gateHalf, z = lounge.z0 },
				{ x = lounge.x0, z = lounge.z0 },
				{ x = lounge.x0, z = lounge.z1 },
				{ x = lounge.x1, z = lounge.z1 },
				{ x = lounge.x1, z = lounge.z0 },
				{ x = gateX + gateHalf, z = lounge.z0 },
			},
		},
	}
	table.insert(points, { id = "haven.square", kind = "poi", x = 0, z = 0, label = "Haven Square" })
	table.insert(points, { id = "haven.campfire", kind = "fire", x = 0, z = 0, label = "Campfire" })
	table.insert(points, {
		id = "haven.lounge",
		kind = "poi",
		x = gateX,
		z = (lounge.z0 + lounge.z1) / 2,
		label = "VIP Lounge",
		glyph = "pass",
	})
	table.insert(points, { id = "trailhead", kind = "trailhead", x = trailX, z = trailZ, label = "Trailhead" })

	return {
		format = MapData.FORMAT,
		id = "neighbourhood",
		name = "The Neighbourhood",
		bounds = bounds,
		play = { x0 = -halfW, z0 = -halfD, x1 = halfW, z1 = halfD },
		ground = "grass",
		edge = "dry",
		zones = zones,
		paths = paths,
		buildings = {},
		fences = fences,
		points = points,
	}
end

return NeighbourhoodMap
