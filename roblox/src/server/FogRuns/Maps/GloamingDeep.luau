--!strict
--[[
	Gloaming Deep (Forest L3, Black fog; LDoE Pine Wood and Oak Grove): the old forest
	where the fire went through. A third larger than the L1 and L2 woods. An old trail
	comes in from the west past a burnt-out cabin; a fire lookout stands on a rise to the
	north; a black creek runs down the east, crossed by a burnt bridge; a bog lies in the
	south and a logging cut in the north-west. Black fog: three marked exits (Old Trail,
	Fire Lookout, Burnt Bridge; the lobby seed closes one) plus the flare extract.
]]

local Builder = require("./Builder")
local ResourceZone = require("./ResourceZone")
local ZoneDress = require("./ZoneDress")

local V2 = Vector2.new
local HALF = 166

local CABIN = V2(-74, 30)
local LOOKOUT = V2(50, -96)
local BRIDGE = V2(112, 34)
local BOG = V2(10, 104)
local CUT = V2(-70, -94)

local spec: ResourceZone.Spec = {
	locationId = "loc.gloaming_deep",
	half = HALF,
	seed = 307,
	biome = "forest",
	trails = {
		{ V2(-240, 18), V2(-120, 24), V2(CABIN.X, CABIN.Y), V2(-20, 18), V2(40, 30), V2(BRIDGE.X - 16, BRIDGE.Y) },
		{ V2(-20, 18), V2(10, -40), V2(LOOKOUT.X, LOOKOUT.Y + 14) },
		{ V2(-20, 18), V2(-6, 70), V2(BOG.X - 14, BOG.Y - 10), V2(0, 240) },
		{ V2(10, -40), V2(-40, -76), V2(CUT.X, CUT.Y) },
	},
	creek = { V2(150, -240), V2(124, -120), V2(BRIDGE.X, BRIDGE.Y), V2(120, 120), V2(140, 240) },
	ponds = { { at = BOG, radius = 18 }, { at = V2(-120, 110), radius = 10 } },
	clearings = {
		{ at = CABIN, radius = 18 },
		{ at = LOOKOUT, radius = 16 },
		{ at = CUT, radius = 22 },
		{ at = V2(BRIDGE.X - 24, BRIDGE.Y), radius = 12 },
	},
	exits = {
		{ id = "old_trail", name = "Old Trail", at = V2(-HALF + 8, 21), yaw = 90 },
		{ id = "fire_lookout", name = "Fire Lookout", at = V2(LOOKOUT.X - 18, LOOKOUT.Y + 6), yaw = 0 },
		{ id = "burnt_bridge", name = "Burnt Bridge", at = V2(BRIDGE.X - 26, BRIDGE.Y), yaw = 90 },
	},
	entry = V2(2, 146),
	containers = {
		{ kind = "pack", at = V2(CABIN.X + 12, CABIN.Y + 6), yaw = 30 },
		{ kind = "pack", at = V2(LOOKOUT.X + 7, LOOKOUT.Y + 8), yaw = 210 },
		{ kind = "pack", at = V2(CUT.X + 10, CUT.Y - 6), yaw = 120 },
		{ kind = "pack", at = V2(BOG.X + 20, BOG.Y - 12), yaw = 300 },
		{ kind = "crate", at = V2(CUT.X - 12, CUT.Y + 8), yaw = 15 },
		{ kind = "crate", at = V2(LOOKOUT.X - 8, LOOKOUT.Y - 6), yaw = 80 },
		{ kind = "crate", at = V2(BRIDGE.X - 30, BRIDGE.Y + 10), yaw = 200 },
	},
	hollows = {
		V2(-120, -40),
		V2(-90, 80),
		V2(-30, -120),
		V2(20, -20),
		V2(60, 60),
		V2(90, -40),
		V2(-40, 120),
		V2(130, -120),
		V2(-140, 140),
		V2(90, 130),
		V2(-130, -130),
		V2(40, -140),
		V2(-60, -10),
		V2(140, 80),
	},
	fog = Color3.fromRGB(88, 90, 96),
	deadShare = 0.35,
	woods = 0.86,
	dress = function(ctx: Builder.Ctx)
		-- The burnt-out cabin: a charred shell with its roof fallen in.
		local cabin = ZoneDress.cabin(ctx, "BurntCabin", CABIN.X, CABIN.Y, 90, 0.6)
		Builder.rubble(ctx, CABIN.X + 10, CABIN.Y + 8, 3.5, "brickDark")
		for _, beam in { { -3, -2, 30, 11 }, { 3, 2, -40, 9 } } do
			Builder.part(
				cabin.model,
				Vector3.new(0.8, 0.8, beam[4]),
				cabin.frame
					* CFrame.new(beam[1], 1.1, beam[2])
					* CFrame.Angles(math.rad(6), math.rad(beam[3]), math.rad(4)),
				"darkMetal",
				"CharredBeam"
			)
		end
		-- The fire lookout on its rise.
		ZoneDress.tower(ctx, "FireLookout", LOOKOUT.X, LOOKOUT.Y, 15, 14)
		Builder.kit(ctx, { "EO_SupplySacksMesh" }, LOOKOUT.X + 8, LOOKOUT.Y - 4, 40)
		Builder.kit(ctx, { "EO_BarrelCluster" }, LOOKOUT.X - 6, LOOKOUT.Y + 10, 120)
		-- The logging cut: stacked ironbark and a crew's camp.
		ZoneDress.logStack(ctx, CUT.X + 6, CUT.Y + 12, 20, 14)
		ZoneDress.logStack(ctx, CUT.X - 14, CUT.Y - 8, 110, 12)
		ZoneDress.sawpit(ctx, CUT.X + 14, CUT.Y - 2, 70)
		ZoneDress.camp(ctx, "CutCamp", CUT.X - 4, CUT.Y + 2, 150)
		-- The burnt bridge: two charred stringers over the creek and a fallen post.
		local holder = Builder.model(Builder.folder(ctx, "Buildings"), "BurntBridge")
		local base = Builder.frame(ctx, BRIDGE.X, BRIDGE.Y, 90, 0.5)
		for _, side in { -2.5, 2.5 } do
			Builder.part(
				holder,
				Vector3.new(0.9, 0.9, 26),
				base * CFrame.new(side, 0, 0) * CFrame.Angles(math.rad(side * 2), 0, 0),
				"darkMetal",
				"Stringer"
			)
		end
		for z = -10, 10, 1.4 do
			if math.noise(z, 1.7) > -0.15 then
				Builder.part(holder, Vector3.new(6, 0.3, 1.1), base * CFrame.new(0, 0.55, z), "darkMetal", "Plank")
			end
		end
		Builder.vehicle(ctx, "EO_SedanWreck", BRIDGE.X - 30, BRIDGE.Y - 12, 20, { height = 5.6, tilt = 5 })
	end,
}

return ResourceZone.layout(spec)
