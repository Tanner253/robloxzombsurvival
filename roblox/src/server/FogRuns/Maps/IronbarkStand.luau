--!strict
--[[
	Ironbark Stand (Forest L2, Dense fog; LDoE Pine Grove and Oak Bushes): old woods of
	ironbark among the pines. The logging road comes in from the west to a landing where
	a hauler stalled among stacked logs; a creek crosses the north at a ford; a ranger's
	hut stands in a clearing to the south, and an old grove of the biggest trees lies
	east of the landing. Dense fog: three marked exits (Logging Road, Creek Ford, Ranger
	Hut); the lobby seed closes one.
]]

local Builder = require("./Builder")
local ResourceZone = require("./ResourceZone")
local ZoneDress = require("./ZoneDress")

local V2 = Vector2.new
local HALF = 125

local LANDING = V2(-14, -6)
local HUT = V2(-40, 72)
local GROVE = V2(56, 20)
local FORD = V2(64, -92)
local POND = V2(76, 82)

local spec: ResourceZone.Spec = {
	locationId = "loc.ironbark_stand",
	half = HALF,
	seed = 223,
	biome = "forest",
	trails = {
		{
			V2(-200, -4),
			V2(-110, -2),
			V2(-60, -6),
			V2(LANDING.X, LANDING.Y),
			V2(30, -30),
			V2(FORD.X, FORD.Y),
			V2(80, -200),
		},
		{ V2(LANDING.X, LANDING.Y), V2(-24, 30), V2(HUT.X, HUT.Y), V2(-46, 200) },
		{ V2(10, 0), V2(GROVE.X, GROVE.Y), V2(POND.X - 6, POND.Y - 14) },
	},
	creek = { V2(-200, -82), V2(-80, -96), V2(0, -84), V2(FORD.X, FORD.Y), V2(120, -70), V2(220, -60) },
	ponds = { { at = POND, radius = 11 } },
	clearings = {
		{ at = LANDING, radius = 26 },
		{ at = HUT, radius = 16 },
		{ at = GROVE, radius = 12 },
	},
	exits = {
		{ id = "logging_road", name = "Logging Road", at = V2(-HALF + 8, -3), yaw = 90 },
		{ id = "creek_ford", name = "Creek Ford", at = V2(FORD.X + 4, FORD.Y - 18), yaw = 0 },
		{ id = "ranger_hut", name = "Ranger Hut", at = V2(HUT.X - 4, HUT.Y + 26), yaw = 0 },
	},
	entry = V2(102, 40),
	containers = {
		{ kind = "pack", at = V2(LANDING.X - 10, LANDING.Y + 8), yaw = 40 },
		{ kind = "pack", at = V2(HUT.X + 10, HUT.Y - 6), yaw = 160 },
		{ kind = "pack", at = V2(GROVE.X + 4, GROVE.Y + 6), yaw = 260 },
		{ kind = "crate", at = V2(LANDING.X + 12, LANDING.Y - 12), yaw = 10 },
		{ kind = "crate", at = V2(LANDING.X - 16, LANDING.Y - 10), yaw = 70 },
		{ kind = "crate", at = V2(HUT.X - 9, HUT.Y + 4), yaw = 90 },
	},
	hollows = {
		V2(-80, 40),
		V2(-60, -50),
		V2(20, 40),
		V2(40, -60),
		V2(90, -20),
		V2(-20, 100),
		V2(80, 100),
		V2(-100, 90),
		V2(10, -100),
		V2(100, 60),
		V2(-90, -106),
		V2(30, 80),
	},
	fog = Color3.fromRGB(150, 158, 164),
	deadShare = 0.12,
	woods = 0.84,
	dress = function(ctx: Builder.Ctx)
		-- The landing: a stalled hauler, stacked logs, a sawpit and the crew's camp.
		Builder.vehicle(ctx, "EO_TractorWreck", LANDING.X + 6, LANDING.Y + 4, 20, { height = 7.5 })
		Builder.vehicle(ctx, "EO_PickupWreck", LANDING.X - 4, LANDING.Y - 14, 100, { height = 6.8, tilt = 3 })
		ZoneDress.logStack(ctx, LANDING.X + 16, LANDING.Y + 12, 80, 14)
		ZoneDress.logStack(ctx, LANDING.X + 20, LANDING.Y - 4, 95, 12)
		ZoneDress.logStack(ctx, LANDING.X - 18, LANDING.Y + 14, 30, 11)
		ZoneDress.sawpit(ctx, LANDING.X - 12, LANDING.Y, 160)
		ZoneDress.camp(ctx, "CrewCamp", LANDING.X - 2, LANDING.Y + 18, 180)
		-- The ranger's hut.
		local hut = ZoneDress.cabin(ctx, "RangerHut", HUT.X, HUT.Y, 0, 0)
		local x, z, lift = Builder.inside(ctx, hut, -3, 2)
		Builder.kit(ctx, { "EO_StorageCrate" }, x, z, 20, { lift = lift })
		Builder.kit(ctx, { "EO_BarrelCluster" }, HUT.X + 12, HUT.Y + 2, 40)
		Builder.kit(ctx, { "EO_LanternPost" }, HUT.X + 8, HUT.Y + 9, 190)
		Builder.lamp(ctx, HUT.X + 8, HUT.Y + 9, 6.5, true, 20)
		Builder.railFence(ctx, { V2(HUT.X - 14, HUT.Y + 12), V2(HUT.X - 14, HUT.Y - 10), V2(HUT.X + 4, HUT.Y - 12) })
		Builder.kit(ctx, { "EO_RockCluster" }, GROVE.X - 8, GROVE.Y - 6, 70)
	end,
}

return ResourceZone.layout(spec)
