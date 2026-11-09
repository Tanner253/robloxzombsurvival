--!strict
--[[
	Deepcut Pit (Mine L3, Black fog; LDoE Limestone Spires): a great open cut stepped
	down in benches, the richest ore in the region at its bottom. A third larger than the
	L1 and L2 mines. The pit ramp spirals in from the south rim yard (trucks, containers,
	the hopper); a conveyor climbs out of the pit to its head on the east rim; a spoil
	heap and its creek-side reeds lie to the west. Black fog: three marked exits (Pit
	Ramp, Conveyor Head, Spoil Heap; the lobby seed closes one) plus the flare extract.
]]

local Builder = require("./Builder")
local ResourceZone = require("./ResourceZone")
local ZoneDress = require("./ZoneDress")

local V2 = Vector2.new
local HALF = 166

local PIT = V2(0, -24)
local YARD = V2(-4, 112)
local HEAD = V2(118, -50)
local SPOIL = V2(-110, 56)

local spec: ResourceZone.Spec = {
	locationId = "loc.deepcut_pit",
	half = HALF,
	seed = 601,
	biome = "mine",
	trails = {
		{
			V2(-6, 240),
			V2(-4, 150),
			V2(YARD.X, YARD.Y),
			V2(30, 70),
			V2(56, 30),
			V2(50, -20),
			V2(20, -40),
			V2(PIT.X, PIT.Y),
		},
		{ V2(YARD.X, YARD.Y), V2(-60, 90), V2(SPOIL.X + 14, SPOIL.Y + 6), V2(-240, 60) },
		{ V2(56, 30), V2(90, -10), V2(HEAD.X - 8, HEAD.Y + 10) },
	},
	creek = { V2(-150, -240), V2(-140, -100), V2(-146, 20), V2(-138, 120), V2(-150, 240) },
	ponds = { { at = V2(120, 110), radius = 12 }, { at = V2(-60, -130), radius = 10 } },
	clearings = {
		{ at = YARD, radius = 26 },
		{ at = HEAD, radius = 16 },
		{ at = SPOIL, radius = 20 },
	},
	ridges = {
		{ points = { V2(-220, -150), V2(-80, -136), V2(40, -150), V2(220, -140) }, width = 38, height = 18 },
		{ points = { V2(150, -140), V2(146, -70), V2(150, 40) }, width = 26, height = 12 },
	},
	pits = { { at = PIT, radius = 92, depth = 30 } },
	exits = {
		{ id = "pit_ramp", name = "Pit Ramp", at = V2(YARD.X + 24, YARD.Y - 12), yaw = 0 },
		{ id = "conveyor_head", name = "Conveyor Head", at = V2(HEAD.X + 4, HEAD.Y + 14), yaw = 0 },
		{ id = "spoil_heap", name = "Spoil Heap", at = V2(SPOIL.X - 6, SPOIL.Y - 26), yaw = 90 },
	},
	entry = V2(-4, 150),
	containers = {
		{ kind = "pack", at = V2(YARD.X + 12, YARD.Y + 10), yaw = 20 },
		{ kind = "pack", at = V2(HEAD.X - 10, HEAD.Y + 6), yaw = 200 },
		{ kind = "pack", at = V2(SPOIL.X + 10, SPOIL.Y - 8), yaw = 100 },
		{ kind = "pack", at = V2(PIT.X + 8, PIT.Y + 6), yaw = 300 },
		{ kind = "crate", at = V2(YARD.X - 16, YARD.Y - 8), yaw = 15 },
		{ kind = "crate", at = V2(HEAD.X + 6, HEAD.Y - 8), yaw = 80 },
		{ kind = "crate", at = V2(SPOIL.X - 12, SPOIL.Y + 10), yaw = 40 },
	},
	hollows = {
		V2(-40, -40),
		V2(40, -60),
		V2(0, 20),
		V2(-60, 30),
		V2(70, 20),
		V2(-100, -80),
		V2(100, -100),
		V2(-120, 120),
		V2(110, 80),
		V2(30, 130),
		V2(-30, -100),
		V2(60, -120),
		V2(-80, 140),
		V2(130, 140),
	},
	fog = Color3.fromRGB(88, 90, 96),
	deadShare = 0.4,
	woods = 0.4,
	dress = function(ctx: Builder.Ctx)
		-- The rim yard: trucks, stacked containers and the hopper.
		Builder.vehicle(ctx, "EO_VanWreck", YARD.X - 14, YARD.Y + 6, 80, { height = 8 })
		Builder.vehicle(ctx, "EO_PickupWreck", YARD.X + 18, YARD.Y - 4, 20, { height = 6.8, tilt = 3 })
		Builder.shippingContainer(ctx, YARD.X - 20, YARD.Y - 14, 0, "corrugatedTeal", true)
		Builder.shippingContainer(ctx, YARD.X + 4, YARD.Y + 18, 90, "rust", false)
		Builder.kit(ctx, { "EO_OreHopper" }, YARD.X + 6, YARD.Y - 14, 0, { height = 9 })
		Builder.kit(ctx, { "EO_BarrelCluster" }, YARD.X - 4, YARD.Y + 4, 20)
		Builder.kit(ctx, { "EO_LanternPost" }, YARD.X + 10, YARD.Y + 2, 160)
		Builder.lamp(ctx, YARD.X + 10, YARD.Y + 2, 6.5, true, 22)
		-- The conveyor climbs out of the pit to its head on the east rim.
		ZoneDress.conveyor(ctx, V2(50, -40), V2(HEAD.X - 4, HEAD.Y - 2), 9)
		Builder.kit(ctx, { "EO_ScrapHeapClean" }, HEAD.X + 14, HEAD.Y - 10, 60)
		-- The spoil heap's camp.
		ZoneDress.camp(ctx, "SpoilCamp", SPOIL.X, SPOIL.Y, 120)
		Builder.vehicle(ctx, "EO_TractorWreck", SPOIL.X + 16, SPOIL.Y + 14, 200, { height = 7.5, tilt = 4 })
	end,
}

return ResourceZone.layout(spec)
