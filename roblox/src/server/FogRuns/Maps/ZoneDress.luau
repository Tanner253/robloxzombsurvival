--!strict
--[[
	ZoneDress: the set pieces the resource zones share (Maps/ResourceZone), built from the
	approved kit and Builder's painted parts: a work camp, stacked logs, a cabin or its
	burnt shell, a lookout tower, an ore chute and a conveyor.
]]

local Interiors = require("../../World/Interiors")
local Builder = require("./Builder")

local ZoneDress = {}

local V2 = Vector2.new

-- A work camp: a tarp lean-to over a cold fire, stores and a lantern on a post.
function ZoneDress.camp(ctx: Builder.Ctx, name: string, x: number, z: number, yaw: number)
	local tarp = Builder.leanTo(ctx, name, x, z, yaw, "tarp")
	local fire = tarp * CFrame.new(0, 0, -8)
	local fx, fz = Builder.toLocal(ctx, fire)
	Builder.kit(ctx, { "EO_CampfireRing" }, fx, fz, 0)
	local bx, bz = Builder.toLocal(ctx, tarp * CFrame.new(-8, 0, 1))
	Builder.kit(ctx, { "EO_BarrelCluster" }, bx, bz, yaw + 30)
	local sx, sz = Builder.toLocal(ctx, tarp * CFrame.new(8, 0, 0))
	Builder.kit(ctx, { "EO_SupplySacksMesh" }, sx, sz, yaw + 70)
	local lx, lz = Builder.toLocal(ctx, tarp * CFrame.new(6, 0, -12))
	Builder.kit(ctx, { "EO_LanternPost" }, lx, lz, yaw + 200)
	Builder.lamp(ctx, lx, lz, 6.5, true, 20)
end

-- Felled logs stacked in a pyramid, held by stakes.
function ZoneDress.logStack(ctx: Builder.Ctx, x: number, z: number, yaw: number, length: number?)
	local holder = Builder.model(Builder.folder(ctx, "Dressing"), "LogStack")
	local base = Builder.frame(ctx, x, z, yaw)
	local long = length or 12
	local rows = { 4, 3, 2 }
	local d = 1.6
	for row, count in rows do
		for index = 1, count do
			local offset = (index - (count + 1) / 2) * d
			local log = base
				* CFrame.new(0, d / 2 + (row - 1) * d * 0.86, offset)
				* CFrame.Angles(0, math.rad((index * 7 + row * 3) % 9 - 4), math.rad(90))
			-- Logs differ a little in length and girth; each shows its sawn ends.
			local girth = d * (0.9 + ((index * 5 + row * 11) % 7) / 60)
			local span = long - ((index + row) % 3) * 0.6
			Builder.cylinder(holder, span, girth, log, "bark")
			for _, tip in { -1, 1 } do
				Builder.cylinder(holder, 0.12, girth - 0.18, log * CFrame.new(0, tip * span / 2, 0), "endGrain")
			end
		end
	end
	for _, side in { -1, 1 } do
		for _, end_ in { -1, 1 } do
			Builder.part(
				holder,
				Vector3.new(0.4, 4.6, 0.4),
				base * CFrame.new(end_ * (long / 2 - 1), 2.2, side * 3.8),
				"trim",
				"Stake"
			)
		end
	end
end

-- A small timber cabin, or its burnt shell (ruin 0..1).
function ZoneDress.cabin(
	ctx: Builder.Ctx,
	name: string,
	x: number,
	z: number,
	yaw: number,
	ruin: number?,
	wall: string?
): Builder.Building
	local broken = ruin or 0
	return Builder.building(ctx, {
		name = name,
		x = x,
		z = z,
		yaw = yaw,
		width = 16,
		depth = 12,
		height = 9.5,
		wall = wall or if broken > 0 then "boards" else "siding",
		trim = "trim",
		floor = "boards",
		roof = if broken > 0.4 then "none" else "gable",
		roofPaint = "shingle",
		ruin = broken,
		chimney = broken == 0,
		openings = {
			{ side = "S", at = -2, kind = "door" },
			{ side = "S", at = 4.5, kind = "window" },
			{ side = "E", at = 0, kind = "window" },
			{ side = "N", at = 2, kind = "window" },
		},
	})
end

-- A timber lookout on four legs: braces, a railed deck, a ladder and a plank roof.
function ZoneDress.tower(ctx: Builder.Ctx, name: string, x: number, z: number, yaw: number, deck: number)
	local holder = Builder.model(Builder.folder(ctx, "Buildings"), name)
	holder:SetAttribute("Layer", "frame")
	local base = Builder.frame(ctx, x, z, yaw)
	local span = 7
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Builder.part(
				holder,
				Vector3.new(0.9, deck + 7, 0.9),
				base * CFrame.new(sx * span / 2, (deck + 7) / 2, sz * span / 2),
				"trim",
				"Leg"
			)
		end
	end
	for level = 1, 3 do
		local y = deck * level / 3.2
		for _, sz in { -1, 1 } do
			Builder.part(
				holder,
				Vector3.new(span + 0.6, 0.4, 0.4),
				base * CFrame.new(0, y, sz * span / 2),
				"trim",
				"Brace"
			)
			Builder.part(
				holder,
				Vector3.new(0.4, 0.4, span + 0.6),
				base * CFrame.new(sz * span / 2, y, 0),
				"trim",
				"Brace"
			)
		end
	end
	Builder.part(holder, Vector3.new(span + 2, 0.5, span + 2), base * CFrame.new(0, deck, 0), "boards", "Deck")
	for _, sz in { -1, 1 } do
		Builder.part(
			holder,
			Vector3.new(span + 2, 0.3, 0.3),
			base * CFrame.new(0, deck + 3, sz * (span / 2 + 1)),
			"trim",
			"Rail"
		)
		Builder.part(
			holder,
			Vector3.new(0.3, 0.3, span + 2),
			base * CFrame.new(sz * (span / 2 + 1), deck + 3, 0),
			"trim",
			"Rail"
		)
	end
	local roof =
		Builder.part(holder, Vector3.new(span + 3, 0.4, span + 3), base * CFrame.new(0, deck + 7, 0), "shingle", "Roof")
	-- Up on the deck, the plank roof lifts so the climber stays in view (roof fade).
	Interiors.roof(roof)
	Interiors.mark(holder, base * CFrame.new(0, deck + 0.25, 0), span + 2, span + 2, 6.5)
	for rung = 1, deck, 1.4 do
		Builder.part(holder, Vector3.new(1.6, 0.2, 0.2), base * CFrame.new(0, rung, span / 2 + 0.7), "trim", "Rung")
	end
	for _, sx in { -0.8, 0.8 } do
		Builder.part(
			holder,
			Vector3.new(0.25, deck, 0.25),
			base * CFrame.new(sx, deck / 2, span / 2 + 0.7),
			"trim",
			"Rail"
		)
	end
end

-- An ore chute: a plank trough on trestles from a bluff top down into a hopper.
function ZoneDress.chute(ctx: Builder.Ctx, from: Vector2, to: Vector2, top: number)
	local holder = Builder.model(Builder.folder(ctx, "Buildings"), "OreChute")
	local a = Builder.at(ctx, from.X, from.Y, top)
	local b = Builder.at(ctx, to.X, to.Y, 6)
	local mid = (a + b) / 2
	local frame = CFrame.lookAt(mid, b)
	local length = (b - a).Magnitude
	Builder.part(holder, Vector3.new(3, 0.4, length), frame, "boards", "Trough")
	for _, side in { -1.5, 1.5 } do
		Builder.part(holder, Vector3.new(0.3, 1.4, length), frame * CFrame.new(side, 0.6, 0), "boards", "Side")
	end
	for t = 0.2, 0.85, 0.22 do
		local p = a:Lerp(b, t)
		local ground = Builder.at(ctx, p.X - ctx.origin.X, p.Z - ctx.origin.Z, 0)
		local tall = p.Y - ground.Y
		if tall > 1 then
			Builder.part(
				holder,
				Vector3.new(0.8, tall, 0.8),
				CFrame.new(ground + Vector3.new(0, tall / 2, 0)),
				"trim",
				"Trestle"
			)
		end
	end
	Builder.kit(ctx, { "EO_OreHopper" }, to.X, to.Y, math.deg(math.atan2(from.X - to.X, from.Y - to.Y)), { height = 8 })
end

-- A belt conveyor on roller stands between two points (lifted `high` at the far end).
function ZoneDress.conveyor(ctx: Builder.Ctx, from: Vector2, to: Vector2, high: number)
	local holder = Builder.model(Builder.folder(ctx, "Buildings"), "Conveyor")
	local a = Builder.at(ctx, from.X, from.Y, 2.5)
	local b = Builder.at(ctx, to.X, to.Y, high)
	local frame = CFrame.lookAt((a + b) / 2, b)
	local length = (b - a).Magnitude
	Builder.part(holder, Vector3.new(3.2, 0.3, length), frame, "darkMetal", "Belt")
	for _, side in { -1.8, 1.8 } do
		Builder.part(holder, Vector3.new(0.4, 0.8, length), frame * CFrame.new(side, 0.2, 0), "rust", "Frame")
	end
	local steps = math.max(2, math.floor(length / 9))
	for index = 0, steps do
		local p = a:Lerp(b, index / steps)
		local ground = Builder.at(ctx, p.X - ctx.origin.X, p.Z - ctx.origin.Z, 0)
		local tall = p.Y - ground.Y
		if tall > 0.8 then
			for _, side in { -1.5, 1.5 } do
				local foot = ground + frame.RightVector * side
				Builder.part(
					holder,
					Vector3.new(0.5, tall, 0.5),
					CFrame.new(foot + Vector3.new(0, tall / 2, 0)),
					"rust",
					"Stand"
				)
			end
		end
	end
	-- The head: a rusted drum housing on its own legs, a sloped lid over the drum (QA: a
	-- corrugated cube here read as a striped crate).
	local level = CFrame.new(b) * CFrame.Angles(0, math.atan2(-frame.LookVector.X, -frame.LookVector.Z), 0)
	local headGround = Builder.at(ctx, b.X - ctx.origin.X, b.Z - ctx.origin.Z, 0)
	local legs = math.max(b.Y - headGround.Y - 1.4, 0.5)
	for _, corner in { { -2, -1.6 }, { 2, -1.6 }, { -2, 1.6 }, { 2, 1.6 } } do
		Builder.part(
			holder,
			Vector3.new(0.6, legs, 0.6),
			level * CFrame.new(corner[1], -1.4 - legs / 2, corner[2]),
			"rust",
			"HeadLeg"
		)
	end
	Builder.part(holder, Vector3.new(4.8, 0.4, 4), level * CFrame.new(0, -1.2, 0), "rust", "HeadDeck")
	for _, side in { -2.3, 2.3 } do
		Builder.part(holder, Vector3.new(0.3, 2.4, 3.6), level * CFrame.new(side, 0, 0), "rust", "HeadCheek")
	end
	Builder.cylinder(holder, 4.2, 2.2, level * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), "darkMetal")
	Builder.part(
		holder,
		Vector3.new(5.4, 0.25, 4.6),
		level * CFrame.new(0, 1.55, 0.3) * CFrame.Angles(math.rad(-12), 0, 0),
		"darkMetal",
		"HeadLid"
	)
	-- The chute it tips into, down to the spoil.
	Builder.part(
		holder,
		Vector3.new(2.6, 0.3, 3.4),
		level * CFrame.new(0, -0.8, -3) * CFrame.Angles(math.rad(34), 0, 0),
		"rust",
		"HeadChute"
	)
end

-- A sawhorse with a half-cut log, and an axe-chopped stump block.
function ZoneDress.sawpit(ctx: Builder.Ctx, x: number, z: number, yaw: number)
	local holder = Builder.model(Builder.folder(ctx, "Dressing"), "Sawpit")
	local base = Builder.frame(ctx, x, z, yaw)
	for _, side in { -2.4, 2.4 } do
		Builder.part(
			holder,
			Vector3.new(0.4, 3.2, 0.4),
			base * CFrame.new(side, 1.4, -0.8) * CFrame.Angles(math.rad(-14), 0, 0),
			"trim"
		)
		Builder.part(
			holder,
			Vector3.new(0.4, 3.2, 0.4),
			base * CFrame.new(side, 1.4, 0.8) * CFrame.Angles(math.rad(14), 0, 0),
			"trim"
		)
	end
	Builder.cylinder(holder, 9, 1.4, base * CFrame.new(0, 3.1, 0) * CFrame.Angles(0, 0, math.rad(90)), "trim")
	local sx, sz = Builder.toLocal(ctx, base * CFrame.new(5, 0, 3))
	Builder.kit(ctx, { "EO_FatwoodStump" }, sx, sz, yaw, { solid = false })
end

ZoneDress.V2 = V2

return ZoneDress
