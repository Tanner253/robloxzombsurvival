--!strict
--[[
	Bracken Edge (Forest L1, Light fog; LDoE Pine Bushes): the first woods past the
	outpost. A rutted track runs north through pines and bracken; a creek winds down the
	west side to a reed pond. Points of interest: the woodcutters' camp on the track (log
	stacks, a sawhorse, a lean-to), a hunter's stand above the pond, and a berry glade in
	the north-east. Light fog: any edge is a way out; the trail ends are marked.
]]

local Builder = require("./Builder")
local ResourceZone = require("./ResourceZone")
local ZoneDress = require("./ZoneDress")

local V2 = Vector2.new
local HALF = 125

local CAMP = V2(26, 6)
local STAND = V2(-62, 44)
local GLADE = V2(58, -70)
local POND = V2(-70, 78)

local spec: ResourceZone.Spec = {
	locationId = "loc.bracken_edge",
	half = HALF,
	seed = 151,
	biome = "forest",
	trails = {
		{ V2(4, 200), V2(6, 110), V2(14, 60), V2(22, 18), V2(20, -30), V2(8, -80), V2(-6, -200) },
		{ V2(20, 14), V2(-20, 30), V2(-50, 42), V2(STAND.X, STAND.Y) },
		{ V2(22, -20), V2(46, -46), V2(GLADE.X, GLADE.Y), V2(200, -84) },
		{ V2(-50, 42), V2(-66, 64), V2(POND.X + 8, POND.Y - 10) },
	},
	creek = { V2(-96, -200), V2(-92, -90), V2(-100, -10), V2(-88, 50), V2(POND.X, POND.Y), V2(-60, 140), V2(-40, 220) },
	ponds = { { at = POND, radius = 13 } },
	clearings = {
		{ at = CAMP, radius = 22 },
		{ at = STAND, radius = 14 },
		{ at = GLADE, radius = 16 },
	},
	exits = {
		{ id = "edge", name = "South track", at = V2(5, HALF - 8), yaw = 0 },
		{ id = "edge", name = "North track", at = V2(-4, -HALF + 8), yaw = 0 },
		{ id = "edge", name = "Glade path", at = V2(HALF - 8, -82), yaw = 90 },
	},
	entry = V2(6, 104),
	containers = {
		{ kind = "pack", at = V2(CAMP.X - 6, CAMP.Y + 4), yaw = 20 },
		{ kind = "pack", at = V2(STAND.X + 4, STAND.Y + 3), yaw = 200 },
		{ kind = "pack", at = V2(GLADE.X - 3, GLADE.Y + 5), yaw = 80 },
		{ kind = "crate", at = V2(CAMP.X + 11, CAMP.Y - 9), yaw = 15 },
		{ kind = "crate", at = V2(STAND.X - 5, STAND.Y - 6), yaw = 100 },
	},
	hollows = {
		V2(-30, -40),
		V2(40, 40),
		V2(70, -20),
		V2(-80, -60),
		V2(-20, 80),
		V2(90, 70),
		V2(-40, 0),
		V2(30, -100),
		V2(-100, 20),
		V2(60, 100),
	},
	fog = Color3.fromRGB(196, 202, 198),
	deadShare = 0.08,
	woods = 0.8,
	dress = function(ctx: Builder.Ctx)
		ZoneDress.camp(ctx, "WoodcuttersCamp", CAMP.X - 4, CAMP.Y + 2, 200)
		ZoneDress.logStack(ctx, CAMP.X + 8, CAMP.Y + 10, 15, 12)
		ZoneDress.logStack(ctx, CAMP.X + 14, CAMP.Y - 2, 100, 10)
		ZoneDress.sawpit(ctx, CAMP.X - 12, CAMP.Y - 10, 40)
		Builder.vehicle(ctx, "EO_PickupWreck", CAMP.X + 4, CAMP.Y - 16, 75, { height = 6.8, tilt = 2 })
		ZoneDress.tower(ctx, "HuntersStand", STAND.X, STAND.Y, 30, 10)
		Builder.kit(ctx, { "EO_SupplySacksMesh" }, STAND.X + 6, STAND.Y - 4, 60)
		Builder.kit(ctx, { "EO_RockCluster" }, GLADE.X + 8, GLADE.Y - 6, 120)
		Builder.kit(ctx, { "EO_RockCluster" }, GLADE.X - 10, GLADE.Y - 8, 20, { height = 2.6 })
	end,
}

return ResourceZone.layout(spec)
