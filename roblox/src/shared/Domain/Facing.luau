--!strict
--[[
	Facing: where a survivor's body points while fighting on the move (LDoE: the upper body
	turns to the target and the legs keep running where the stick points). Pure; the client's
	Controllers/Stance applies it every frame and tests/Facing.spec holds it.

	Yaws are radians in the game's convention, yaw = atan2(dx, dz): a heading of `yaw` points
	along (sin yaw, 0, cos yaw), a positive turn about the up axis adds to it, and a body's
	left is its yaw + 90 degrees.

	- solve(moveYaw?, aimYaw, previous?): the root's yaw, the waist twist and the leg gait.
	  * Moving within WAIST_LIMIT of the aim ("forward"): the root keeps to the movement (the
	    rig's own run plays) and the waist turns the upper body the rest of the way.
	  * Past the limit the whole body turns toward the aim: the root takes the facing that
	    leaves the movement exactly 45 degrees off ahead ("aheadLeft"/"aheadRight"), 45 off
	    behind ("backLeft"/"backRight") or straight behind ("back"), so the strafe or
	    backpedal cycle runs along the movement and the planted foot never slides. The waist
	    turns the rest. A sideways shuffle is never used: at a 16 studs/s walk it needs five
	    steps a second, and a diagonal stride reads as a strafe from the top-down camera.
	  * Standing: the root faces the aim and the waist is straight ("idle").
	  Each band keeps its gait HYSTERESIS past its edge, so a stick held near a boundary does
	  not flicker between cycles.
	- gaitOf(moveYaw?, rootYaw, previous?): the leg cycle for any body from its movement
	  relative to its facing (other survivors are drawn from their replicated root).
	- legClip(gait): the strafe and backpedal cycles as Data/Holds clips, solved by two-bone IK
	  on the survivor's legs (LEG, measured on the StarterCharacter): the planted foot holds the
	  ground at a constant speed and the hips stay level, a little low, as in a combat run.
	- legRate(gait, groundSpeed): the play rate that makes the planted foot match the ground.
]]

local Facing = {}

-- "idle" | "forward" | "aheadLeft" | "aheadRight" | "backLeft" | "backRight" | "back"
export type Gait = string
export type Solution = { rootYaw: number, waist: number, gait: Gait }
export type Pose = { number }
export type Clip = {
	length: number,
	loop: boolean?,
	partial: boolean?,
	linear: boolean?,
	keys: { { time: number, poses: { [string]: Pose } } },
}

local RAD = math.pi / 180

Facing.WAIST_LIMIT = 65 * RAD -- the waist alone turns the upper body this far
Facing.HYSTERESIS = 6 * RAD
Facing.WAIST_MAX = 75 * RAD -- the hard stop, also while the root is still turning
Facing.TURN_SECONDS = 0.05 -- the root's turn: time constant of its approach
Facing.BLEND_SECONDS = 0.15 -- in and out of the attack stance, and between leg cycles

-- The movement's direction relative to the facing, per gait.
Facing.GAIT_ANGLE = {
	idle = 0,
	forward = 0,
	aheadLeft = math.pi / 4,
	aheadRight = -math.pi / 4,
	backLeft = 3 * math.pi / 4,
	backRight = -3 * math.pi / 4,
	back = math.pi,
} :: { [Gait]: number }

-- The bands of |movement relative to the aim|: forward, ahead, back-diagonal, back.
local BANDS = { Facing.WAIST_LIMIT, 112.5 * RAD, 160 * RAD }

-- The difference b - a, wrapped to (-pi, pi].
function Facing.diff(a: number, b: number): number
	local d = (b - a) % (2 * math.pi)
	if d > math.pi then
		d -= 2 * math.pi
	end
	return d
end

function Facing.wrap(yaw: number): number
	return Facing.diff(0, yaw)
end

function Facing.yawOf(x: number, z: number): number
	return math.atan2(x, z)
end

local function bandIndex(gait: Gait?): number?
	if gait == "forward" then
		return 0
	elseif gait == "aheadLeft" or gait == "aheadRight" then
		return 1
	elseif gait == "backLeft" or gait == "backRight" then
		return 2
	elseif gait == "back" then
		return 3
	end
	return nil
end

-- Which facing serves a movement `rel` (the movement relative to the aim) best.
local function sector(rel: number, previous: Gait?): Gait
	local a = math.abs(rel)
	local band = 0
	for _, edge in BANDS do
		if a > edge then
			band += 1
		end
	end
	local held = bandIndex(previous)
	if held and held ~= band then
		local low = if held > 0 then BANDS[held] - Facing.HYSTERESIS else -math.huge
		local high = if held < #BANDS then BANDS[held + 1] + Facing.HYSTERESIS else math.huge
		if a >= low and a <= high then
			band = held
		end
	end
	local left = rel > 0
	if band == 0 then
		return "forward"
	elseif band == 1 then
		return if left then "aheadLeft" else "aheadRight"
	elseif band == 2 then
		return if left then "backLeft" else "backRight"
	end
	return "back"
end

function Facing.solve(moveYaw: number?, aimYaw: number, previous: Gait?): Solution
	if moveYaw == nil then
		return { rootYaw = Facing.wrap(aimYaw), waist = 0, gait = "idle" }
	end
	local gait = sector(Facing.diff(aimYaw, moveYaw), previous)
	local rootYaw = Facing.wrap(moveYaw - Facing.GAIT_ANGLE[gait])
	return { rootYaw = rootYaw, waist = Facing.diff(rootYaw, aimYaw), gait = gait }
end

local MOVING_GAITS: { Gait } = { "forward", "aheadLeft", "aheadRight", "backLeft", "backRight", "back" }

-- The leg cycle for a body moving along `moveYaw` (nil: standing) while facing `rootYaw`: the
-- nearest gait, keeping the previous one until another is HYSTERESIS nearer.
function Facing.gaitOf(moveYaw: number?, rootYaw: number, previous: Gait?): Gait
	if moveYaw == nil then
		return "idle"
	end
	local rel = Facing.diff(rootYaw, moveYaw)
	local best: Gait = "forward"
	local bestOff = math.huge
	for _, gait in MOVING_GAITS do
		local off = math.abs(Facing.diff(Facing.GAIT_ANGLE[gait], rel))
		if off < bestOff then
			best, bestOff = gait, off
		end
	end
	if previous and previous ~= "idle" and previous ~= best then
		local held = math.abs(Facing.diff(Facing.GAIT_ANGLE[previous], rel))
		if held <= bestOff + Facing.HYSTERESIS then
			return previous
		end
	end
	return best
end

-- The waist twist that keeps the upper body on the aim, inside the hard stop.
function Facing.waistFor(rootYaw: number, aimYaw: number): number
	return math.clamp(Facing.diff(rootYaw, aimYaw), -Facing.WAIST_MAX, Facing.WAIST_MAX)
end

-- One frame of the root's turn toward `target` (an eased approach, no snap).
function Facing.turn(current: number, target: number, dt: number): number
	local k = 1 - math.exp(-math.max(dt, 0) / Facing.TURN_SECONDS)
	return Facing.wrap(current + Facing.diff(current, target) * k)
end

-- One frame of a 0..1 weight moving toward on (1) or off (0) over BLEND_SECONDS.
function Facing.blend(weight: number, on: boolean, dt: number): number
	local step = math.max(dt, 0) / Facing.BLEND_SECONDS
	return if on then math.min(1, weight + step) else math.max(0, weight - step)
end

-- Legs ------------------------------------------------------------------------------------------

--[[
	The survivor's leg, measured on the StarterCharacter in Studio: hip joint to knee 1.04 studs,
	knee to sole 1.6, hips 0.33 either side of the root, 2.632 from hip to ground (HipHeight).
	A cycle is one second at play rate 1; each foot is planted for `duty` of it and swings
	through the rest, so both feet leave the ground for a moment twice a cycle (a run).
]]
Facing.LEG = {
	thigh = 1.04,
	shin = 1.6,
	length = 2.632,
	hipOut = 0.33,
	drop = 0.4, -- the hips sit this much lower than standing: room for the stride
	duty = 0.3,
	samples = 16, -- keys per cycle
}

type GaitShape = {
	move: { number }, -- the body's direction of travel in root space: { x right, f forward }
	reach: number, -- the planted foot starts this far ahead of its centre and ends as far behind
	lift: number, -- the swinging foot's height at mid-swing
	splay: number, -- each foot's centre, out from its hip, so the feet never cross
}

local D = math.sqrt(0.5)
local SHAPES: { [string]: GaitShape } = {
	back = { move = { 0, -1 }, reach = 1.1, lift = 0.55, splay = 0.08 },
	backLeft = { move = { -D, -D }, reach = 0.9, lift = 0.5, splay = 0.5 },
	backRight = { move = { D, -D }, reach = 0.9, lift = 0.5, splay = 0.5 },
	aheadLeft = { move = { -D, D }, reach = 0.9, lift = 0.5, splay = 0.5 },
	aheadRight = { move = { D, D }, reach = 0.9, lift = 0.5, splay = 0.5 },
}

-- The ground speed a cycle covers at play rate 1 (studs per second): the planted foot's
-- slide relative to the hip over its stance.
function Facing.footSpeed(gait: Gait): number?
	local shape = SHAPES[gait]
	if shape == nil then
		return nil
	end
	return 2 * shape.reach / Facing.LEG.duty
end

-- The play rate for a leg cycle at `groundSpeed` studs per second (nil: the rig's own walk).
function Facing.legRate(gait: Gait, groundSpeed: number): number?
	local speed = Facing.footSpeed(gait)
	if speed == nil then
		return nil
	end
	return math.max(groundSpeed, 0) / speed
end

-- Rx(x) * Ry(y) * Rz(z) back out of a row-major 3x3 (CFrame.Angles order), in degrees.
local function eulerXYZ(m: { number }): (number, number, number)
	local y = math.asin(math.clamp(m[3], -1, 1))
	local x = math.atan2(-m[6], m[9])
	local z = math.atan2(-m[2], m[1])
	return x / RAD, y / RAD, z / RAD
end

-- The hip and knee angles that put a sole at (x right, y up, f forward) from its hip joint.
function Facing.solveLeg(x: number, y: number, f: number): (Pose, Pose)
	local a, b = Facing.LEG.thigh, Facing.LEG.shin
	local d = math.sqrt(x * x + y * y)
	local roll = math.atan2(x, -y)
	local r = math.min(math.sqrt(f * f + d * d), (a + b) * 0.999)
	local knee = math.acos(math.clamp((r * r - a * a - b * b) / (2 * a * b), -1, 1))
	local pitch = math.atan2(f, d) + math.acos(math.clamp((a * a + r * r - b * b) / (2 * a * r), -1, 1))
	-- The hip: pitch inside the leg's plane, that plane rolled out to the side: Rz(roll) * Rx(pitch).
	local cr, sr, cp, sp = math.cos(roll), math.sin(roll), math.cos(pitch), math.sin(pitch)
	local hx, hy, hz = eulerXYZ({ cr, -sr * cp, sr * sp, sr, cr * cp, -cr * sp, 0, sp, cp })
	return { hx, hy, hz }, { -knee / RAD, 0, 0 }
end

-- Rx * Ry * Rz (Euler degrees, the CFrame.Angles order) applied to a vector.
local function rotate(p: Pose, v: { number }): { number }
	local x, y, z = p[1] * RAD, p[2] * RAD, p[3] * RAD
	local v1 = { v[1] * math.cos(z) - v[2] * math.sin(z), v[1] * math.sin(z) + v[2] * math.cos(z), v[3] }
	local v2 = { v1[1] * math.cos(y) + v1[3] * math.sin(y), v1[2], -v1[1] * math.sin(y) + v1[3] * math.cos(y) }
	return { v2[1], v2[2] * math.cos(x) - v2[3] * math.sin(x), v2[2] * math.sin(x) + v2[3] * math.cos(x) }
end

-- Where a hip and knee pose put the sole, from the hip joint: { x right, y up, f forward }.
function Facing.footOf(hip: Pose, knee: Pose): { number }
	local shin = rotate(knee, { 0, -Facing.LEG.shin, 0 })
	local leg = rotate(hip, { shin[1], shin[2] - Facing.LEG.thigh, shin[3] })
	return { leg[1], leg[2], -leg[3] } -- root space has forward along -Z
end

-- One foot's target from its hip at its own phase `q` (0..1, planted first). `side` is 1 for
-- the right foot, -1 for the left.
local function footTarget(shape: GaitShape, q: number, side: number): (number, number, number)
	local leg = Facing.LEG
	local ground = -(leg.length - leg.drop)
	local cx = side * shape.splay
	local mx, mf = shape.move[1], shape.move[2]
	if q < leg.duty then
		-- Planted: it slides back along the travel at a constant speed.
		local s = shape.reach - 2 * shape.reach * q / leg.duty
		return cx + mx * s, ground, mf * s
	end
	-- Swinging: from behind back to ahead, lifted.
	local u = (q - leg.duty) / (1 - leg.duty)
	local s = -shape.reach + 2 * shape.reach * (1 - math.cos(math.pi * u)) / 2
	return cx + mx * s, ground + shape.lift * math.sin(math.pi * u), mf * s
end

local legClips: { [string]: Clip } = {}

-- The strafe or backpedal cycle as a Data/Holds clip (the legs and the lowered hips only).
function Facing.legClip(gait: Gait): Clip?
	local shape = SHAPES[gait]
	if shape == nil then
		return nil
	end
	local made = legClips[gait]
	if made then
		return made
	end
	local leg = Facing.LEG
	local keys = {}
	for i = 0, leg.samples do
		local p = i / leg.samples
		local poses: { [string]: Pose } = { LowerTorso = { 0, 0, 0, 0, -leg.drop, 0 } }
		for _, side in { 1, -1 } do
			local q = (p + (if side == 1 then 0 else 0.5)) % 1
			local x, y, f = footTarget(shape, q, side)
			local hip, knee = Facing.solveLeg(x, y, f)
			local name = if side == 1 then "Right" else "Left"
			poses[name .. "UpperLeg"] = hip
			poses[name .. "LowerLeg"] = knee
		end
		table.insert(keys, { time = p, poses = poses })
	end
	local clip: Clip = { length = 1, loop = true, partial = true, linear = true, keys = keys }
	legClips[gait] = clip
	return clip
end

-- The clip each gait plays (none for "forward" and "idle": the rig's own walk and idle).
Facing.LEG_CLIPS = {
	aheadLeft = "legsAheadLeft",
	aheadRight = "legsAheadRight",
	backLeft = "legsBackLeft",
	backRight = "legsBackRight",
	back = "legsBack",
} :: { [string]: string }

function Facing.clipByName(name: string): Clip?
	for gait, clipName in Facing.LEG_CLIPS do
		if clipName == name then
			return Facing.legClip(gait :: Gait)
		end
	end
	return nil
end

return Facing
