--!strict
-- Specs for the shared map format (Domain/MapData), the Neighbourhood's map built from
-- Tuning (Domain/NeighbourhoodMap) and the minimap's projection math (checklist 8.11).
local TestKit = require("./TestKit")
local MapData = require("../src/shared/Domain/MapData")
local NeighbourhoodMap = require("../src/shared/Domain/NeighbourhoodMap")
local Neighbourhood = require("../src/shared/Domain/Neighbourhood")
local Maps = require("../src/shared/Data/Maps")
local Content = require("../src/shared/Data")
local Grid = require("../src/shared/Domain/Grid")

local tuning: any = Content.Tuning.plots
local GRID = Content.Tuning.building.plotCells * Grid.CELL_STUDS

local function near(actual: number, expected: number, label: string, tolerance: number?)
	if math.abs(actual - expected) > (tolerance or 1e-6) then
		error(`{label}: expected {expected}, got {actual}`, 2)
	end
end

local function sample(): any
	return {
		format = MapData.FORMAT,
		id = "loc.sample",
		name = "Sample",
		bounds = { x0 = -150, z0 = -150, x1 = 150, z1 = 150 },
		play = { x0 = -125, z0 = -125, x1 = 125, z1 = 125 },
		ground = "grass",
		edge = "forest",
		zones = {
			{ kind = "water", shape = "ellipse", x = -70, z = 60, w = 40, d = 30, soft = true },
			{ kind = "earth", shape = "rect", x = 0, z = -20, w = 50, d = 40, yaw = 15 },
			{ kind = "rock", shape = "poly", points = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 5, z = 8 } } },
		},
		paths = { { kind = "trail", width = 6, points = { { x = 0, z = 125 }, { x = 0, z = -125 } } } },
		buildings = { { kind = "barn", x = 10, z = -30, w = 24, d = 16, yaw = 90 } },
		fences = { { kind = "rail", points = { { x = 30, z = 30 }, { x = 60, z = 30 } } } },
		trees = { { x = 100, z = 100 } },
		points = { { id = "exit.north", kind = "exit", x = 0, z = -125, label = "North road" } },
	}
end

return function(test: TestKit.Register)
	test("validate accepts a well-formed map and names the first problem otherwise", function()
		local ok, problem = MapData.validate(sample())
		TestKit.truthy(ok, `sample: {problem}`)
		local bad = sample()
		bad.zones[2].w = 0
		local ok2, problem2 = MapData.validate(bad)
		TestKit.equal(ok2, false, "zero width")
		TestKit.equal(problem2, "zones[2]: size", "problem")
		local onePoint = sample()
		onePoint.paths[1].points = { { x = 0, z = 0 } }
		TestKit.equal(select(2, MapData.validate(onePoint)), "paths[1]: points", "one-point path")
		local twin = sample()
		table.insert(twin.points, { id = "exit.north", kind = "exit", x = 1, z = 1 })
		TestKit.equal(select(2, MapData.validate(twin)), "points[2]: id", "duplicate id")
		local oldFormat = sample()
		oldFormat.format = 0
		TestKit.equal(MapData.validate(oldFormat), false, "format")
		local badKind = sample()
		badKind.zones[1].kind = "lava"
		TestKit.equal(select(2, MapData.validate(badKind)), "zones[1]: kind", "unknown kind")
	end)

	test("the Neighbourhood map is valid and generated from the layout", function()
		local map = NeighbourhoodMap.build(tuning, GRID)
		local ok, problem = MapData.validate(map)
		TestKit.truthy(ok, `neighbourhood: {problem}`)
		local plots = 0
		for _, point in map.points do
			if point.kind == "plot" then
				plots += 1
				local index = tonumber(string.match(point.id, "%d+")) :: number
				local x, z = Neighbourhood.plotCentre(tuning, GRID, index)
				near(point.x, x, `plot {index} x`)
				near(point.z, z, `plot {index} z`)
				local play = map.play :: MapData.Bounds
				TestKit.truthy(point.x > play.x0 and point.x < play.x1, `plot {index} inside`)
			elseif point.kind == "trailhead" then
				local x, z = Neighbourhood.trailhead(tuning, GRID)
				near(point.x, x, "trailhead x")
				near(point.z, z, "trailhead z")
				TestKit.truthy(point.z > map.bounds.z0, "trailhead drawn")
			end
		end
		TestKit.equal(plots, tuning.count, "a point per plot")
		-- The road runs the Neighbourhood's width, broken only where Haven Square covers it.
		local west, east = map.paths[1], map.paths[2]
		TestKit.equal(west.kind, "road", "west road")
		TestKit.equal(east.kind, "road", "east road")
		TestKit.truthy(west.points[1].x < -Neighbourhood.halfWidth(tuning, GRID), "road reaches west")
		TestKit.truthy(east.points[2].x > Neighbourhood.halfWidth(tuning, GRID), "road reaches east")
		TestKit.truthy(math.abs(west.points[2].x) < tuning.plazaHalfStuds, "west road ends in the square")
		TestKit.truthy(math.abs(east.points[1].x) < tuning.plazaHalfStuds, "east road starts in the square")
		-- The Lounge's fence leaves its gate open.
		local fence = map.fences[1].points
		near(fence[#fence].x - fence[1].x, Neighbourhood.lounge.gateWidth, "gate gap")
	end)

	test("project puts the camera's view up, and unproject inverts it", function()
		-- Yaw 0 is north up: north (-Z) is straight up.
		local x, y = MapData.project(0, -10, 0, 2)
		near(x, 0, "north x")
		near(y, -20, "north y")
		-- The game camera (yaw 45 degrees) looks north-west: that direction is up.
		local yaw = math.rad(45)
		local fx, fy = MapData.project(-math.sin(yaw), -math.cos(yaw), yaw, 1)
		near(fx, 0, "forward x")
		near(fy, -1, "forward y")
		-- Its right vector is right.
		local rx, ry = MapData.project(math.cos(yaw), -math.sin(yaw), yaw, 1)
		near(rx, 1, "right x")
		near(ry, 0, "right y")
		local sx, sy = MapData.project(13, -7, yaw, 0.76)
		local dx, dz = MapData.unproject(sx, sy, yaw, 0.76)
		near(dx, 13, "round trip x")
		near(dz, -7, "round trip z")
	end)

	test("the map picture's rotation agrees with project", function()
		local yaw = math.rad(45)
		local turn = math.rad(MapData.mapRotation(yaw))
		-- A GUI rotation turns (x, y) clockwise on screen: (x cos - y sin, x sin + y cos).
		local wx, wz = 30, -12
		local gx, gy = wx * math.cos(turn) - wz * math.sin(turn), wx * math.sin(turn) + wz * math.cos(turn)
		local px, py = MapData.project(wx, wz, yaw, 1)
		near(gx, px, "x")
		near(gy, py, "y")
	end)

	test("heading points the arrow along the facing", function()
		local yaw = math.rad(45)
		near(MapData.heading(-math.sin(yaw), -math.cos(yaw), yaw), 0, "facing the camera's way")
		near(MapData.heading(math.cos(yaw), -math.sin(yaw), yaw), 90, "facing right")
		near(math.abs(MapData.heading(math.sin(yaw), math.cos(yaw), yaw)), 180, "facing the camera")
	end)

	test("rim pins far markers to the edge and leaves near ones", function()
		local x, y, inside = MapData.rim(30, 40, 70)
		TestKit.equal(inside, true, "inside")
		near(x, 30, "kept x")
		local px, py, pinned = MapData.rim(300, 400, 70)
		TestKit.equal(pinned, false, "outside")
		near(px, 42, "pinned x")
		near(py, 56, "pinned y")
	end)

	test("easeAngle takes the short way round the seam", function()
		near(MapData.easeAngle(170, -170, 0.5), 180, "across +-180")
		near(MapData.easeAngle(-170, 170, 1), -190, "lands on the target, same heading")
		near(MapData.easeAngle(10, 30, 0.25), 15, "plain")
		near(MapData.ease(10, 0), 0, "no time, no move")
		TestKit.truthy(MapData.ease(10, 1 / 60) < 0.2, "a frame closes a share")
	end)

	test("zoomBy steps the reach and clamps it", function()
		near(MapData.zoomBy(100, 1, 40, 240), 85, "one notch in")
		near(MapData.zoomBy(100, -1, 40, 240), 100 / 0.85, "one notch out")
		near(MapData.zoomBy(45, 3, 40, 240), 40, "clamped in")
		near(MapData.zoomBy(230, -2, 40, 240), 240, "clamped out")
	end)

	test("fit centres the bounds in the area", function()
		local scale, ox, oy = MapData.fit({ x0 = -100, z0 = -50, x1 = 100, z1 = 50 }, 1000, 700, 50)
		near(scale, 4.5, "scale")
		near(ox, 50, "x offset")
		near(oy, 125, "y offset")
	end)

	test("buckets: small features near the view are drawn, big ones always", function()
		local size = MapData.BUCKET
		local key = MapData.bucketOf(MapData.rectBounds(10, 10, 20, 20), size)
		TestKit.truthy(key ~= nil, "small feature bucketed")
		TestKit.equal(MapData.bucketOf(MapData.rectBounds(0, 0, 900, 20), size), nil, "long road always drawn")
		TestKit.truthy(MapData.bucketsNear(60, 40, 110, size)[key :: string], "near the view")
		TestKit.equal(MapData.bucketsNear(1200, 1200, 110, size)[key :: string], nil, "far from the view")
		local turned = MapData.rectBounds(0, 0, 10, 2, 90)
		near(turned.x1 - turned.x0, 2, "a quarter turn swaps width")
		near(turned.z1 - turned.z0, 10, "and depth")
	end)

	test("every supplied location map is valid", function()
		for id, map in Maps do
			local ok, problem = MapData.validate(map)
			TestKit.truthy(ok, `{id}: {problem}`)
			TestKit.equal(map.id, id, `{id} id`)
		end
	end)
end
