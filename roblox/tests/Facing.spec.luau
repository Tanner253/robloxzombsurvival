--!strict
-- Domain/Facing: the waist twist against the full turn, the leg cycle for each movement
-- relative to the facing, and the cycles themselves (planted feet hold the ground at the
-- speed the play rate promises, and never cross).
local TestKit = require("./TestKit")
local Facing = require("../src/shared/Domain/Facing")

local RAD = math.pi / 180

local function near(a: number, b: number, eps: number): boolean
	return math.abs(a - b) <= eps
end

-- The sole in root space for one side of a clip key: hip offset, lowered hips, the leg.
local function sole(poses: { [string]: { number } }, side: string): { number }
	local foot = Facing.footOf(poses[side .. "UpperLeg"], poses[side .. "LowerLeg"])
	local out = if side == "Right" then Facing.LEG.hipOut else -Facing.LEG.hipOut
	local drop = poses.LowerTorso[5]
	return { foot[1] + out, foot[2] + drop, foot[3] }
end

return function(test: TestKit.Register)
	test("inside the waist limit the legs keep the movement and the waist turns", function()
		for _, deg in { 0, 20, -40, 60, -64 } do
			local aim = 1.3
			local move = aim + deg * RAD
			local s = Facing.solve(move, aim, nil)
			TestKit.equal(s.gait, "forward", `{deg} degrees`)
			TestKit.truthy(near(Facing.diff(s.rootYaw, move), 0, 1e-9), "the root keeps to the movement")
			TestKit.truthy(near(s.waist, -deg * RAD, 1e-9), "the waist takes the difference")
		end
	end)

	test("eight directions against a fixed target: the body turns past the limit", function()
		local aim = -0.4
		local expected = {
			[0] = "forward",
			[45] = "forward",
			[90] = "aheadLeft",
			[135] = "backLeft",
			[180] = "back",
			[-135] = "backRight",
			[-90] = "aheadRight",
			[-45] = "forward",
		}
		for deg, gait in expected do
			local move = aim + deg * RAD
			local s = Facing.solve(move, aim, nil)
			TestKit.equal(s.gait, gait, `moving {deg} degrees off the aim`)
			TestKit.truthy(math.abs(s.waist) <= Facing.WAIST_MAX + 1e-9, `{deg}: waist inside the stop`)
			-- The legs run exactly along the movement: no slide.
			local rel = Facing.diff(s.rootYaw, move)
			TestKit.truthy(
				near(Facing.diff(rel, Facing.GAIT_ANGLE[gait]), 0, 1e-9),
				`{deg}: movement matches the cycle`
			)
			-- The upper body ends on the aim.
			TestKit.truthy(near(Facing.diff(s.rootYaw + s.waist, aim), 0, 1e-9), `{deg}: chest on the aim`)
		end
		TestKit.equal(Facing.solve(aim + math.pi, aim, nil).gait, "back", "moving away from the target backpedals")
	end)

	test("a full sweep never breaks the waist stop and never flickers", function()
		local aim = 0.7
		for _, direction in { 1, -1 } do
			local previous: Facing.Gait? = nil
			local changes = 0
			local maxWaist = 0
			-- Out from the aim to behind, back again, with a jittering stick.
			for step = 0, 720 do
				local deg = if step <= 360 then step / 2 else (720 - step) / 2
				local jitter = (if step % 2 == 0 then 1 else -1) * 2
				local s = Facing.solve(aim + direction * (deg + jitter) * RAD, aim, previous)
				if previous and s.gait ~= previous then
					changes += 1
				end
				previous = s.gait
				maxWaist = math.max(maxWaist, math.abs(s.waist))
			end
			TestKit.truthy(maxWaist <= Facing.WAIST_MAX + 1e-9, `waist {maxWaist / RAD} under the stop`)
			-- forward, ahead, back-diagonal, back and the same way home: six changes.
			TestKit.equal(changes, 6, "one change per band edge each way")
		end
	end)

	test("hysteresis holds the gait near an edge", function()
		local aim = 0
		TestKit.equal(Facing.solve(68 * RAD, aim, "forward").gait, "forward", "forward holds to 71")
		TestKit.equal(Facing.solve(68 * RAD, aim, nil).gait, "aheadLeft", "a fresh read turns")
		TestKit.equal(Facing.solve(61 * RAD, aim, "aheadLeft").gait, "aheadLeft", "the turn holds to 59")
		TestKit.equal(Facing.solve(57 * RAD, aim, "aheadLeft").gait, "forward", "and lets go under it")
	end)

	test("standing: the body faces the aim with a straight waist", function()
		local s = Facing.solve(nil, 2.5, "back")
		TestKit.equal(s.gait, "idle")
		TestKit.truthy(near(s.rootYaw, 2.5, 1e-9) and s.waist == 0, "faces the aim")
	end)

	test("gaitOf reads any body's legs from its movement against its facing", function()
		local root = -1.1
		for gait, angle in Facing.GAIT_ANGLE do
			if gait ~= "idle" then
				TestKit.equal(Facing.gaitOf(root + angle, root, nil), gait, gait)
			end
		end
		TestKit.equal(Facing.gaitOf(nil, root, "back"), "idle", "standing")
		-- Halfway between two cycles, the one already playing stays.
		TestKit.equal(Facing.gaitOf(root + 90 * RAD, root, "backLeft"), "backLeft", "holds backLeft")
		TestKit.equal(Facing.gaitOf(root + 90 * RAD, root, "aheadLeft"), "aheadLeft", "holds aheadLeft")
	end)

	test("the leg IK puts the sole where it was asked", function()
		for _, target in { { 0, -2.3, 1 }, { -0.7, -2.2, -0.7 }, { 0.9, -2.33, 0.4 }, { 0.2, -1.9, -0.9 } } do
			local hip, knee = Facing.solveLeg(target[1], target[2], target[3])
			local foot = Facing.footOf(hip, knee)
			for i = 1, 3 do
				TestKit.truthy(near(foot[i], target[i], 1e-3), `axis {i}: {foot[i]} vs {target[i]}`)
			end
		end
	end)

	test("planted feet hold the ground at the promised speed (no slide)", function()
		local leg = Facing.LEG
		for gait in Facing.LEG_CLIPS do
			local clip = Facing.legClip(gait :: Facing.Gait) :: Facing.Clip
			local speed = Facing.footSpeed(gait :: Facing.Gait) :: number
			for _, side in { "Right", "Left" } do
				local offset = if side == "Right" then 0 else 0.5
				local previous: { number }? = nil
				local previousT = 0
				for _, key in clip.keys do
					local q = (key.time + offset) % 1
					local at = sole(key.poses, side)
					if q < leg.duty - 1e-9 then
						TestKit.truthy(near(at[2], -leg.length, 0.02), `{gait} {side}: sole on the ground ({at[2]})`)
						if previous then
							local dt = key.time - previousT
							local moved = math.sqrt((at[1] - previous[1]) ^ 2 + (at[3] - previous[3]) ^ 2)
							TestKit.truthy(
								near(moved / dt, speed, speed * 0.02),
								`{gait} {side}: {moved / dt} vs {speed}`
							)
						end
						previous, previousT = at, key.time
					else
						previous = nil
						TestKit.truthy(at[2] >= -leg.length - 0.02, `{gait} {side}: a swinging foot clears the ground`)
					end
				end
			end
		end
	end)

	test("the feet never cross", function()
		for gait in Facing.LEG_CLIPS do
			local clip = Facing.legClip(gait :: Facing.Gait) :: Facing.Clip
			local closest = math.huge
			for _, key in clip.keys do
				local r, l = sole(key.poses, "Right"), sole(key.poses, "Left")
				closest = math.min(closest, math.sqrt((r[1] - l[1]) ^ 2 + (r[3] - l[3]) ^ 2))
				-- Side by side (within a foot's length fore and aft), the right stays on the right.
				if math.abs(r[3] - l[3]) < 1.1 then
					TestKit.truthy(r[1] - l[1] >= 0.5, `{gait}: side by side, {r[1] - l[1]} studs apart`)
				end
			end
			TestKit.truthy(closest >= 0.55, `{gait}: soles {closest} studs apart at the closest`)
		end
	end)

	test("the play rate matches the ground speed", function()
		for gait in Facing.LEG_CLIPS do
			local rate = Facing.legRate(gait :: Facing.Gait, 16) :: number
			TestKit.truthy(near(rate * (Facing.footSpeed(gait :: Facing.Gait) :: number), 16, 1e-9), gait)
			TestKit.truthy(rate > 1.5 and rate < 3.5, `{gait}: {rate} cycles a second at a walk`)
		end
		TestKit.equal(Facing.legRate("forward", 16), nil, "forward is the rig's own walk")
	end)

	test("turns and blends settle in about 0.15 s, without a snap", function()
		local yaw = 0
		local firstStep = 0
		for frame = 1, 9 do
			local before = yaw
			yaw = Facing.turn(yaw, math.pi / 2, 1 / 60)
			if frame == 1 then
				firstStep = yaw - before
			end
		end
		TestKit.truthy(math.abs(Facing.diff(yaw, math.pi / 2)) < 5 * RAD, "within 5 degrees after 0.15 s")
		TestKit.truthy(firstStep < 0.3 * math.pi / 2, "the first frame takes under a third")
		local weight = 0
		for _ = 1, 9 do
			weight = Facing.blend(weight, true, 1 / 60)
		end
		TestKit.truthy(near(weight, 1, 1e-6), "the stance is in after 0.15 s")
		TestKit.truthy(Facing.blend(1, false, 1 / 60) > 0.85, "and leaves gradually")
	end)
end
