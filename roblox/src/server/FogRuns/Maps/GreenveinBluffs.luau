--!strict
--[[
	Greenvein Bluffs (Mine L2, Dense fog; LDoE Limestone Cliffs and Frosty Backwoods):
	tall rust-streaked bluffs with copper-green seams. The haul road comes up from the
	south to the yard (a stalled truck, an ore hopper, a fuel pump); an ore chute drops
	from the central bluff to a hopper; a switchback trail climbs out to the west; the
	malachite cut lies in the north-east. Dense fog: three marked exits (Haul Road, Ore
	Chute, Switchback); the lobby seed closes one.
]]

local Builder = require("./Builder")
local ResourceZone = require("./ResourceZone")
local ZoneDress = require("./ZoneDress")

local V2 = Vector2.new
local HALF = 125

local YARD = V2(-14, 66)
local CHUTE_FOOT = V2(46, -26)
local CUT = V2(56, -78)
local CAMP = V2(-44, -10)

local spec: ResourceZone.Spec = {
	locationId = "loc.greenvein_bluffs",
	half = HALF,
	seed = 503,
	biome = "mine",
	trails = {
		{
			V2(-18, 220),
			V2(-16, 110),
			V2(YARD.X, YARD.Y),
			V2(10, 30),
			V2(CHUTE_FOOT.X - 6, CHUTE_FOOT.Y + 12),
			V2(CUT.X - 8, CUT.Y + 20),
		},
		{ V2(10, 30), V2(CAMP.X + 10, CAMP.Y + 6), V2(-80, -40), V2(-100, -70), V2(-220, -76) },
	},
	creek = nil,
	ponds = { { at = V2(76, 70), radius = 12 }, { at = V2(-80, 92), radius = 10 }, { at = V2(-20, -100), radius = 8 } },
	clearings = {
		{ at = YARD, radius = 22 },
		{ at = CHUTE_FOOT, radius = 13 },
		{ at = CAMP, radius = 13 },
	},
	ridges = {
		{ points = { V2(-110, -200), V2(-100, -110), V2(-112, 10), V2(-104, 200) }, width = 30, height = 18 },
		{ points = { V2(-10, -70), V2(30, -50), V2(70, -36) }, width = 26, height = 15 },
		{ points = { V2(200, -120), V2(104, -100), V2(96, 0), V2(110, 200) }, width = 30, height = 17 },
	},
	pits = { { at = CUT, radius = 26, depth = 11 } },
	exits = {
		{ id = "haul_road", name = "Haul Road", at = V2(-17, HALF - 8), yaw = 0 },
		{ id = "ore_chute", name = "Ore Chute", at = V2(CHUTE_FOOT.X - 10, CHUTE_FOOT.Y + 10), yaw = 90 },
		{ id = "switchback", name = "Switchback", at = V2(-HALF + 8, -74), yaw = 90 },
	},
	entry = V2(60, 106),
	containers = {
		{ kind = "pack", at = V2(YARD.X + 12, YARD.Y + 8), yaw = 30 },
		{ kind = "pack", at = V2(CAMP.X - 6, CAMP.Y + 6), yaw = 200 },
		{ kind = "pack", at = V2(CUT.X - 14, CUT.Y + 18), yaw = 120 },
		{ kind = "crate", at = V2(YARD.X - 14, YARD.Y - 6), yaw = 10 },
		{ kind = "crate", at = V2(CHUTE_FOOT.X + 8, CHUTE_FOOT.Y + 8), yaw = 80 },
		{ kind = "crate", at = V2(CAMP.X + 8, CAMP.Y - 6), yaw = 60 },
	},
	hollows = {
		V2(-60, 40),
		V2(20, 0),
		V2(40, 60),
		V2(-30, -60),
		V2(70, -60),
		V2(-70, -80),
		V2(80, 30),
		V2(-50, 100),
		V2(30, 100),
		V2(0, -100),
		V2(60, -100),
		V2(-80, 10),
	},
	fog = Color3.fromRGB(150, 158, 164),
	deadShare = 0.15,
	woods = 0.45,
	dress = function(ctx: Builder.Ctx)
		-- The haul yard: a stalled truck, the hopper, a fuel pump and stores.
		Builder.vehicle(ctx, "EO_VanWreck", YARD.X + 8, YARD.Y - 10, 100, { height = 8, tilt = 2 })
		Builder.kit(ctx, { "EO_OreHopper" }, YARD.X - 8, YARD.Y + 10, 30, { height = 9 })
		Builder.kit(ctx, { "EO_FuelPump" }, YARD.X + 16, YARD.Y + 2, 270, { height = 6 })
		Builder.kit(ctx, { "EO_BarrelCluster" }, YARD.X + 18, YARD.Y + 12, 60)
		Builder.kit(ctx, { "EO_ScrapHeapClean" }, YARD.X - 18, YARD.Y + 14, 20)
		Builder.kit(ctx, { "EO_LanternPost" }, YARD.X + 2, YARD.Y + 16, 180)
		Builder.lamp(ctx, YARD.X + 2, YARD.Y + 16, 6.5, true, 22)
		-- The ore chute off the central bluff.
		ZoneDress.chute(ctx, V2(30, -52), CHUTE_FOOT, 16)
		-- The miners' camp under the west bluff.
		ZoneDress.camp(ctx, "MinersCamp", CAMP.X, CAMP.Y, 90)
		Builder.kit(ctx, { "EO_StorageCrate" }, CUT.X - 18, CUT.Y + 22, 20)
	end,
}

return ResourceZone.layout(spec)
