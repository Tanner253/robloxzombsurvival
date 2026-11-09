--!strict
--[[
	MeleeKeys: turns a move's poses (Data/MeleePoses, hand-keyed, or a UAL clip from
	Data/MeleeClips) and its marks (Domain/MeleeTiming) into a plain key list the client
	builds a KeyframeSequence from (Controllers/MeleeAnim) and the offline preview draws
	(tools/anim). Pure: no Roblox types.

	Rotations come out as quaternions { x, y, z, w } per part: the part's turn relative to
	its parent, in the character's rest axes (X right, Y up, -Z forward). The client turns
	each into its joint's frame (J^-1 * q * J). LowerTorso adds { px, py, pz } studs.

	Two variants:
	- "full": every part a move keys, legs included (standing still).
	- "upper": the waist up only, so the walk or run drives the legs (swinging while
	  moving). The hips' turn folds into the waist so the shoulders line up the same.
]]

local MeleeClips = require("../Data/MeleeClips")
local MeleePoses = require("../Data/MeleePoses")
local MeleeTiming = require("./MeleeTiming")

local MeleeKeys = {}

export type Ease = "linear" | "constant" | "in" | "out" | "inOut"
export type Key = { t: number, ease: Ease, poses: { [string]: { number } } }
export type Built = { id: string, length: number, keys: { Key }, parts: { string } }
export type Variant = "full" | "upper"

MeleeKeys.UPPER = {
	"UpperTorso",
	"Head",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
}
MeleeKeys.LOWER = { "LowerTorso", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" }

-- The pose hierarchy of the R15 survivor (Pose instances nest the same way).
MeleeKeys.PARENTS = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
} :: { [string]: string }

local IS_LOWER: { [string]: boolean } = {}
for _, name in MeleeKeys.LOWER do
	IS_LOWER[name] = true
end

-- Quaternions ------------------------------------------------------------------------------------

type Quat = { number }

local function qmul(a: Quat, b: Quat): Quat
	local ax, ay, az, aw = a[1], a[2], a[3], a[4]
	local bx, by, bz, bw = b[1], b[2], b[3], b[4]
	return {
		aw * bx + ax * bw + ay * bz - az * by,
		aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw,
		aw * bw - ax * bx - ay * by - az * bz,
	}
end

local function axis(index: number, degrees: number): Quat
	local half = math.rad(degrees) / 2
	local q = { 0, 0, 0, math.cos(half) }
	q[index] = math.sin(half)
	return q
end

-- CFrame.Angles(x, y, z) as a quaternion: Rx * Ry * Rz.
function MeleeKeys.euler(x: number, y: number, z: number): Quat
	return qmul(qmul(axis(1, x), axis(2, y)), axis(3, z))
end

MeleeKeys.qmul = qmul

local function round(q: Quat): { number }
	local out = table.create(#q)
	for index, value in q do
		out[index] = math.floor(value * 1e5 + 0.5) / 1e5
	end
	return out
end

-- Arms by direction ---------------------------------------------------------------------------------
--[[
	Arms are easier to key by where they point than by joint angles. An arm spec gives
	directions in the torso's axes (X right, Y up, -Z forward):
	- Right = { up = upper arm, fore = forearm, weapon = where the held item points,
	  twist = degrees about the weapon }; fore defaults to up, weapon to the hand's rest.
	- Left = the same without a weapon (hand = { x, y, z } points the knuckles), or
	  { grip = studs }: two-handed, the left fist on the handle that far below the right,
	  reached by two-bone IK; or { reach = { x, y, z } }: the left fist at a torso point.
	Elbows bend forward from the hanging arm (the hinge is the rest X axis). The rest
	geometry is measured from place/kit/StarterCharacter.rbxm
	(`python -P tools/anim/preview.py --measure`): torso space, the arms hanging.
]]

type Vec = { number }
type Mat = { number } -- 3x3 row-major

local function v(x: number, y: number, z: number): Vec
	return { x, y, z }
end
local function add(a: Vec, b: Vec): Vec
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end
local function sub(a: Vec, b: Vec): Vec
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end
local function mul(a: Vec, s: number): Vec
	return { a[1] * s, a[2] * s, a[3] * s }
end
local function dot(a: Vec, b: Vec): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function len(a: Vec): number
	return math.sqrt(dot(a, a))
end
local function unit(a: Vec): Vec
	local l = len(a)
	return if l > 1e-9 then mul(a, 1 / l) else { 0, -1, 0 }
end
-- The part of `a` at right angles to unit `n`, normalised.
local function across(a: Vec, n: Vec): Vec
	return unit(sub(a, mul(n, dot(a, n))))
end

local function apply(m: Mat, a: Vec): Vec
	return {
		m[1] * a[1] + m[2] * a[2] + m[3] * a[3],
		m[4] * a[1] + m[5] * a[2] + m[6] * a[3],
		m[7] * a[1] + m[8] * a[2] + m[9] * a[3],
	}
end
local function mmul(a: Mat, b: Mat): Mat
	local out = table.create(9, 0)
	for r = 0, 2 do
		for c = 1, 3 do
			out[r * 3 + c] = a[r * 3 + 1] * b[c] + a[r * 3 + 2] * b[3 + c] + a[r * 3 + 3] * b[6 + c]
		end
	end
	return out
end
local function transpose(m: Mat): Mat
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end
local IDENTITY_M: Mat = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
-- Columns a, b, c.
local function columns(a: Vec, b: Vec, c: Vec): Mat
	return { a[1], b[1], c[1], a[2], b[2], c[2], a[3], b[3], c[3] }
end
local function axisAngle(n: Vec, angle: number): Mat
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	local x, y, z = n[1], n[2], n[3]
	return {
		t * x * x + c,
		t * x * y - s * z,
		t * x * z + s * y,
		t * x * y + s * z,
		t * y * y + c,
		t * y * z - s * x,
		t * x * z - s * y,
		t * y * z + s * x,
		t * z * z + c,
	}
end
-- The shortest turn taking unit `a` onto unit `b`.
local function arc(a: Vec, b: Vec): Mat
	local axis3 = cross(a, b)
	local s = len(axis3)
	local c = dot(a, b)
	if s < 1e-6 then
		if c > 0 then
			return IDENTITY_M
		end
		local other = if math.abs(a[1]) < 0.9 then v(1, 0, 0) else v(0, 0, 1)
		return axisAngle(across(other, a), math.pi)
	end
	return axisAngle(mul(axis3, 1 / s), math.atan2(s, c))
end
-- A rotation matrix as a quaternion { x, y, z, w }.
local function quat(m: Mat): Quat
	local trace = m[1] + m[5] + m[9]
	local x, y, z, w
	if trace > 0 then
		local s = math.sqrt(trace + 1) * 2
		w, x, y, z = 0.25 * s, (m[8] - m[6]) / s, (m[3] - m[7]) / s, (m[4] - m[2]) / s
	elseif m[1] > m[5] and m[1] > m[9] then
		local s = math.sqrt(1 + m[1] - m[5] - m[9]) * 2
		w, x, y, z = (m[8] - m[6]) / s, 0.25 * s, (m[2] + m[4]) / s, (m[3] + m[7]) / s
	elseif m[5] > m[9] then
		local s = math.sqrt(1 + m[5] - m[1] - m[9]) * 2
		w, x, y, z = (m[3] - m[7]) / s, (m[2] + m[4]) / s, 0.25 * s, (m[6] + m[8]) / s
	else
		local s = math.sqrt(1 + m[9] - m[1] - m[5]) * 2
		w, x, y, z = (m[4] - m[2]) / s, (m[3] + m[7]) / s, (m[6] + m[8]) / s, 0.25 * s
	end
	return { x, y, z, w }
end

type ArmRest = { shoulder: Vec, elbow: Vec, wrist: Vec, grip: Vec, weapon: Vec, pole: Vec }

MeleeKeys.ARM_REST = {
	Right = {
		shoulder = v(0.5968, 0.2227, 0.1248),
		elbow = v(0.7054, -0.4636, 0.0779),
		wrist = v(0.7608, -1.1198, -0.1177),
		grip = v(0.6921, -1.4552, -0.2947),
		weapon = v(0.1799, 0.2771, -0.9439), -- Models.held's "hand" mount on the resting fist
		pole = v(0.5, -1, 0.3), -- where an IK elbow points
	},
	Left = {
		shoulder = v(-0.6139, 0.2193, 0.1171),
		elbow = v(-0.7144, -0.4487, 0.0819),
		wrist = v(-0.7772, -1.1054, -0.1063),
		grip = v(-0.7186, -1.4812, -0.306),
		weapon = v(-0.1799, 0.2771, -0.9439),
		pole = v(-0.5, -1, 0.3),
	},
} :: { [string]: ArmRest }

local HINGE = v(1, 0, 0)

-- The upper arm's turn putting the bone along `u` with the elbow hinge across (u, f).
local function upperTurn(rest: Vec, u: Vec, f: Vec): Mat
	local e1 = rest
	local e2 = across(HINGE, e1)
	local hinge = cross(u, f)
	local t2: Vec
	if len(hinge) > 1e-3 then
		t2 = across(hinge, u)
	else
		t2 = across(apply(arc(e1, u), e2), u)
	end
	return mmul(columns(u, t2, cross(u, t2)), transpose(columns(e1, e2, cross(e1, e2))))
end

-- The elbow's bend (about the hinge, in rest axes) that puts the forearm along `f`.
local function elbowTurn(restUpper: Vec, restFore: Vec, upper: Mat, f: Vec): Mat
	local hinge = across(HINGE, restUpper)
	local goal = apply(transpose(upper), f)
	local a = across(restFore, hinge)
	local b = across(goal, hinge)
	local angle = math.atan2(dot(cross(a, b), hinge), dot(a, b))
	return axisAngle(hinge, angle)
end

type Solved = { quats: { [string]: Quat }, grip: Vec, weapon: Vec? }

local function solveArm(side: string, spec: { [string]: any }): Solved
	local rest = MeleeKeys.ARM_REST[side]
	local restUpper = unit(sub(rest.elbow, rest.shoulder))
	local restFore = unit(sub(rest.wrist, rest.elbow))
	local u = unit(spec.up or { 0, -1, 0 })
	local f = unit(spec.fore or spec.up or { 0, -1, 0 })
	local upper = upperTurn(restUpper, u, f)
	local elbow = elbowTurn(restUpper, restFore, upper, f)
	local fore = mmul(upper, elbow)
	local hand = IDENTITY_M
	local weapon: Vec? = nil
	local aim = spec.weapon or spec.hand
	if aim then
		local goal = unit(aim)
		local localGoal = apply(transpose(fore), goal)
		hand = arc(rest.weapon, localGoal)
		if spec.twist then
			hand = mmul(axisAngle(localGoal, math.rad(spec.twist)), hand)
		end
		weapon = goal
	end
	local handWorld = mmul(fore, hand)
	local grip = add(
		add(add(rest.shoulder, apply(upper, sub(rest.elbow, rest.shoulder))), apply(fore, sub(rest.wrist, rest.elbow))),
		apply(handWorld, sub(rest.grip, rest.wrist))
	)
	return {
		quats = { [`{side}UpperArm`] = quat(upper), [`{side}LowerArm`] = quat(elbow), [`{side}Hand`] = quat(hand) },
		grip = grip,
		weapon = weapon or apply(handWorld, rest.weapon),
	}
end

-- Two-bone IK: the fist (its grip point) at `target`, the elbow toward the rest pole.
local function reachArm(side: string, target: Vec): Solved
	local rest = MeleeKeys.ARM_REST[side]
	local restUpper = unit(sub(rest.elbow, rest.shoulder))
	local restFore = unit(sub(rest.grip, rest.elbow)) -- the forearm and fist as one segment
	local a = len(sub(rest.elbow, rest.shoulder))
	local b = len(sub(rest.grip, rest.elbow))
	local toward = sub(target, rest.shoulder)
	local distance = math.clamp(len(toward), math.abs(a - b) + 0.01, a + b - 0.001)
	local dir = unit(toward)
	local cosA = math.clamp((a * a + distance * distance - b * b) / (2 * a * distance), -1, 1)
	local perp = across(rest.pole, dir)
	local elbowAt = add(rest.shoulder, mul(add(mul(dir, cosA), mul(perp, math.sqrt(1 - cosA * cosA))), a))
	local u = unit(sub(elbowAt, rest.shoulder))
	local f = unit(sub(add(rest.shoulder, mul(dir, distance)), elbowAt))
	local upper = upperTurn(restUpper, u, f)
	local elbow = elbowTurn(restUpper, restFore, upper, f)
	return {
		quats = { [`{side}UpperArm`] = quat(upper), [`{side}LowerArm`] = quat(elbow), [`{side}Hand`] = { 0, 0, 0, 1 } },
		grip = add(elbowAt, mul(f, b)),
		weapon = nil,
	}
end

-- A rotation matrix from a quaternion.
local function matrix(q: Quat): Mat
	local x, y, z, w = q[1], q[2], q[3], q[4]
	return {
		1 - 2 * (y * y + z * z),
		2 * (x * y - z * w),
		2 * (x * z + y * w),
		2 * (x * y + z * w),
		1 - 2 * (x * x + z * z),
		2 * (y * z - x * w),
		2 * (x * z - y * w),
		2 * (y * z + x * w),
		1 - 2 * (x * x + y * y),
	}
end

-- An arm spec with its directions turned from the character's axes into the torso's.
local function toTorso(spec: { [string]: any }, torso: Mat): { [string]: any }
	local inverse = transpose(torso)
	local out = table.clone(spec)
	for _, key in { "up", "fore", "weapon", "hand" } do
		if spec[key] then
			out[key] = apply(inverse, unit(spec[key]))
		end
	end
	return out
end

--[[
	Solves a key's Right and Left arm specs into part quaternions (added to `poses`). Arm
	directions are in the character's axes (the root's facing), so a torso twist carries
	the shoulders but the authored aim holds; `reach` points are in the torso's space.
]]
local function solveArms(pose: { [string]: any }, poses: { [string]: { number } })
	local hips = poses.LowerTorso
	local waist = poses.UpperTorso
	local torso = mmul(
		if hips then matrix({ hips[1], hips[2], hips[3], hips[4] }) else IDENTITY_M,
		if waist then matrix({ waist[1], waist[2], waist[3], waist[4] }) else IDENTITY_M
	)
	local right: Solved? = nil
	if pose.Right then
		right = solveArm("Right", toTorso(pose.Right, torso))
		for part, q in (right :: Solved).quats do
			poses[part] = q
		end
	end
	local left = pose.Left
	if left then
		local solved: Solved
		if left.grip and right then
			local r = right :: Solved
			solved = reachArm("Left", sub(r.grip, mul(unit(r.weapon :: Vec), left.grip)))
		elseif left.reach then
			solved = reachArm("Left", left.reach)
		else
			solved = solveArm("Left", toTorso(left, torso))
		end
		for part, q in solved.quats do
			poses[part] = q
		end
	end
end

-- Sources ------------------------------------------------------------------------------------------

local function markTime(marks: MeleeTiming.Marks, at: string | number): number
	if type(at) == "number" then
		return at
	end
	local value = (marks :: any)[at]
	assert(type(value) == "number", `MeleeKeys: unknown mark '{at}'`)
	return value
end

-- A part's pose ({ x, y, z } degrees, LowerTorso may add px, py, pz) as quat (+ position).
local function fromDegrees(spec: { number }): { number }
	local q = MeleeKeys.euler(spec[1] or 0, spec[2] or 0, spec[3] or 0)
	if spec[4] then
		return { q[1], q[2], q[3], q[4], spec[4], spec[5] or 0, spec[6] or 0 }
	end
	return q
end

type RawKey = { t: number, ease: Ease, poses: { [string]: { number } } }

local function handKeys(spec: MeleePoses.MoveSpec, marks: MeleeTiming.Marks): { RawKey }
	local raw: { RawKey } = {}
	for _, key in spec.keys or {} do
		local merged: { [string]: any } = table.clone(spec.base or {})
		for part, value in key.pose do
			merged[part] = value
		end
		local poses: { [string]: { number } } = {}
		for part, value in merged do
			if part ~= "Right" and part ~= "Left" then
				poses[part] = fromDegrees(value)
			end
		end
		solveArms(merged, poses)
		table.insert(raw, { t = markTime(marks, key.at), ease = (key.ease or "inOut") :: Ease, poses = poses })
	end
	return raw
end

-- Piecewise-linear time warp through { source, target } points.
local function warp(points: { { number } }, t: number): number
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		if t <= b[1] or index == #points - 1 then
			local span = b[1] - a[1]
			local alpha = if span > 0 then (t - a[1]) / span else 0
			return a[2] + (b[2] - a[2]) * alpha
		end
	end
	return points[#points][2]
end

local function ualKeys(spec: MeleePoses.MoveSpec, marks: MeleeTiming.Marks): { RawKey }
	local source = spec.ual :: MeleePoses.UalSource
	local clip = MeleeClips.clips[source.clip]
	assert(clip, `MeleeKeys: no UAL clip '{source.clip}'`)
	local from, to = source.from or 0, source.to or clip.length
	local points: { { number } } = { { from, 0 } }
	for _, pair in source.map or {} do
		table.insert(points, { pair[1], markTime(marks, pair[2]) })
	end
	table.insert(points, { to, marks.length })
	local offsets: { [string]: Quat } = {}
	for part, value in source.offsets or {} do
		offsets[part] = MeleeKeys.euler(value[1], value[2], value[3])
	end
	local raw: { RawKey } = {}
	for _, key in clip.keys do
		if key.t >= from - 1e-6 and key.t <= to + 1e-6 then
			local poses: { [string]: { number } } = {}
			for index, part in MeleeClips.PARTS do
				local value = key.p[index]
				local q: Quat = { value[1], value[2], value[3], value[4] }
				local offset = offsets[part]
				if offset then
					q = qmul(q, offset)
				end
				if value[5] then
					poses[part] = { q[1], q[2], q[3], q[4], value[5], value[6], value[7] }
				else
					poses[part] = q
				end
			end
			table.insert(raw, { t = warp(points, key.t), ease = "linear", poses = poses })
		end
	end
	return raw
end

-- Building -----------------------------------------------------------------------------------------

local IDENTITY = { 0, 0, 0, 1 }

-- Whether a move keys anything below the waist.
local function hasLegs(raw: { RawKey }, spec: MeleePoses.MoveSpec): boolean
	if spec.ual then
		return spec.ual.legs == true
	end
	for _, key in raw do
		for part in key.poses do
			if IS_LOWER[part] then
				return true
			end
		end
	end
	return false
end

function MeleeKeys.build(id: string, variant: Variant): Built
	local spec = MeleePoses.moves[id]
	assert(spec, `MeleeKeys: no poses for '{id}'`)
	local marks = MeleeTiming.marksOf(id)
	local raw = if spec.ual then ualKeys(spec, marks) else handKeys(spec, marks)
	table.sort(raw, function(a: RawKey, b: RawKey): boolean
		return a.t < b.t
	end)
	local legs = variant == "full" and hasLegs(raw, spec)
	local parts: { string } = table.clone(MeleeKeys.UPPER)
	if legs then
		for _, name in MeleeKeys.LOWER do
			table.insert(parts, name)
		end
	end
	local keys: { Key } = {}
	for _, key in raw do
		local poses: { [string]: { number } } = {}
		for _, part in parts do
			poses[part] = round(key.poses[part] or IDENTITY)
		end
		if not legs then
			-- The hips' turn moves into the waist; their offset and the legs stay the walk's.
			local hips = key.poses.LowerTorso
			if hips then
				local waist = key.poses.UpperTorso or IDENTITY
				poses.UpperTorso = round(qmul({ hips[1], hips[2], hips[3], hips[4] }, waist))
			end
		end
		table.insert(keys, { t = math.floor(key.t * 1e4 + 0.5) / 1e4, ease = key.ease, poses = poses })
	end
	return { id = id, length = marks.length, keys = keys, parts = parts }
end

-- Every move that has poses, sorted.
function MeleeKeys.ids(): { string }
	local list: { string } = {}
	for id in MeleePoses.moves do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

return MeleeKeys
