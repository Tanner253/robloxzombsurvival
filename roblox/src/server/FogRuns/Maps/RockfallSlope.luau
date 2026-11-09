--!strict
--[[
	Rockfall Slope (Mine L1, Light fog; LDoE Limestone Ridge): a broken hillside under a
	grey bluff. The track climbs north from the outpost side to a small quarry cut at the
	foot of the bluff; quarrymen camped beside it. A spur bluff runs down the east, a
	spring pond sits in the west, and pines hold the lower slope. Light fog: any edge is a
	way out; the trail ends are marked.
]]

local Builder = require("./Builder")
local ResourceZone = require("./ResourceZone")
local ZoneDress = require("./ZoneDress")

local V2 = Vector2.new
local HALF = 125

local CUT = V2(-14, -44)
local CAMP = V2(30, 30)
local POND = V2(-74, 46)

local spec: ResourceZone.Spec = {
	locationId = "loc.rockfall_slope",
	half = HALF,
	seed = 409,
	biome = "mine",
	trails = {
		{ V2(2, 200), V2(4, 100), V2(16, 54), V2(CAMP.X - 8, CAMP.Y - 4), V2(10, -10), V2(CUT.X, CUT.Y + 20) },
		{ V2(10, -10), V2(-40, 10), V2(POND.X + 12, POND.Y - 6), V2(-200, 30) },
		{ V2(CAMP.X, CAMP.Y), V2(80, 40), V2(200, 50) },
	},
	creek = nil,
	ponds = { { at = POND, radius = 15 }, { at = V2(70, 96), radius = 9 } },
	clearings = {
		{ at = CAMP, radius = 18 },
		{ at = V2(CUT.X, CUT.Y + 20), radius = 12 },
	},
	ridges = {
		{ points = { V2(-200, -92), V2(-80, -84), V2(0, -96), V2(90, -88), V2(200, -100) }, width = 34, height = 15 },
		{ points = { V2(84, -80), V2(96, -20), V2(90, 30) }, width = 24, height = 9 },
	},
	pits = { { at = CUT, radius = 32, depth = 10 } },
	exits = {
		{ id = "edge", name = "Valley track", at = V2(3, HALF - 8), yaw = 0 },
		{ id = "edge", name = "Pond path", at = V2(-HALF + 8, 29), yaw = 90 },
		{ id = "edge", name = "East path", at = V2(HALF - 8, 50), yaw = 90 },
	},
	entry = V2(4, 104),
	containers = {
		{ kind = "pack", at = V2(CAMP.X + 9, CAMP.Y - 6), yaw = 20 },
		{ kind = "pack", at = V2(CUT.X + 8, CUT.Y + 23), yaw = 160 },
		{ kind = "pack", at = V2(POND.X + 18, POND.Y + 6), yaw = 260 },
		{ kind = "crate", at = V2(CAMP.X - 10, CAMP.Y + 8), yaw = 70 },
		{ kind = "crate", at = V2(CUT.X - 10, CUT.Y + 22), yaw = 10 },
	},
	hollows = {
		V2(-60, -20),
		V2(50, -40),
		V2(-30, 70),
		V2(70, 70),
		V2(-90, -50),
		V2(26, -74),
		V2(-100, 90),
		V2(100, -10),
		V2(-10, 20),
		V2(60, 110),
	},
	fog = Color3.fromRGB(196, 202, 198),
	deadShare = 0.15,
	woods = 0.5,
	dress = function(ctx: Builder.Ctx)
		ZoneDress.camp(ctx, "QuarrymenCamp", CAMP.X, CAMP.Y, 220)
		Builder.vehicle(ctx, "EO_PickupWreck", CAMP.X + 14, CAMP.Y + 12, 60, { height = 6.8, tilt = 2 })
		Builder.kit(ctx, { "EO_StorageCrate" }, CAMP.X - 14, CAMP.Y - 2, 30)
		Builder.kit(ctx, { "EO_SupplySacksMesh" }, CUT.X + 16, CUT.Y + 24, 80)
		Builder.kit(ctx, { "EO_BarrelCluster" }, CUT.X - 4, CUT.Y + 30, 10)
		Builder.kit(ctx, { "EO_LanternPost" }, CUT.X + 6, CUT.Y + 18, 200)
		Builder.lamp(ctx, CUT.X + 6, CUT.Y + 18, 6.5, true, 20)
	end,
}

return ResourceZone.layout(spec)
