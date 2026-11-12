--!strict
--[[
	HoldRules: which class an item in the hand belongs to and what follows from it
	(2.0 batch 1). Pure; the data is Data/Holds.

	- classOf: the item's hold class (Data/Holds.items, else by its kind, so a new item
	  never ends up with no animation); empty hands are "fists".
	- mountOf: how it sits in the fist ("gun": along the forearm; "fist": ahead of it).
	- strikeDelay: seconds from the start of a swing to its hit frame. The server lands a
	  light swing's damage on it, so the number, the flinch and the impact sound arrive
	  when the blade does, not when the button goes down.
	- consumeAction: the action clip for using a consumable (eat, drink or bandage).
]]

local Holds = require("../Data/Holds")

local HoldRules = {}

type ItemLike = {
	tool: { kind: string }?,
	weapon: { kind: string, bow: any?, firearm: { animClass: string? }? }?,
	throw: any?,
}

function HoldRules.classOf(itemId: string?, def: ItemLike?): string
	if itemId == nil or itemId == "" then
		return "fists"
	end
	local listed = Holds.items[itemId]
	if listed then
		return listed
	end
	if def == nil then
		return "fists"
	end
	if def.tool then
		return if def.tool.kind == "pick" then "pick" else "axe"
	end
	if def.throw then
		return "throw"
	end
	local weapon = def.weapon
	if weapon and weapon.kind == "ranged" then
		if weapon.bow then
			return "bow"
		end
		local firearm = weapon.firearm
		return if firearm and firearm.animClass == "pistol" then "pistol" else "long"
	end
	return if weapon then "blunt" else "fists"
end

--[[
	How a held item lies in its icon (components/ModelView): the icon draws Art.held's
	`axis * axisSign` up and to the right and `edge * edgeSign` up and to the left, so the
	item lies as on a table, top up, head or muzzle to the upper right.

	Art.held describes the hand, not the table: a gun's `edge` is its underside, so drawing
	it up-left laid every gun grip up (2026-11-12, the developer: "a lot of the model icons
	are upside down"), and the molotov's `axis` runs from the neck the fist holds to its base.
]]
function HoldRules.iconSigns(itemId: string, def: ItemLike?): (number, number)
	local class = HoldRules.classOf(itemId, def)
	local axisSign = if Holds.heldByTop[itemId] then -1 else 1
	local edgeSign = if class == "pistol" or class == "long" then -1 else 1
	return axisSign, edgeSign
end

function HoldRules.mountOf(itemId: string?, def: ItemLike?): Holds.Mount
	return Holds.classes[HoldRules.classOf(itemId, def)].mount
end

-- The clip a class plays for a use ("carry", "swing", "heavy", "aim", "recoil", "reload").
function HoldRules.clip(class: string, use: string): string?
	local def = Holds.classes[class] :: any
	return def and def[use]
end

function HoldRules.strikeDelay(class: string, heavy: boolean): number
	local name = HoldRules.clip(class, if heavy then "heavy" else "swing")
	local clip = if name then Holds.clips[name] else nil
	return if clip and clip.hit then clip.hit else 0
end

--[[
	The support hand on a long gun (batch 3, batch 5): clients pull the off hand onto the gun
	with an IKControl toward a "Support" attachment the held model carries this far along the
	gun from the grip: SUPPORT_REACH of its length, but no more than SUPPORT_MAX_STUDS.
	Batch 3 reached for the handguard (1.25 studs out); at 1.3x gun scale that put both arms
	through the chest. Measured in Studio against the survivor's meshes (batch 5), the off
	hand clears the body only when it closes on the gun just ahead of the grip, so the cap is
	now 0.12 studs. Returned as a share of the length from the butt; nil for every other class.
	The hand holds on only while aiming (the carry is one-handed, the off arm swinging with the
	walk) and lets go for a reload, when it works the magazine.
]]
HoldRules.SUPPORT_REACH = 0.4
HoldRules.SUPPORT_MAX_STUDS = 0.12
-- How far above the grip's drop the palm sits, as a share of the gun's height.
HoldRules.SUPPORT_LIFT = 0.15

function HoldRules.supportAt(class: string, grip: number, length: number): number?
	if class ~= "long" or length <= 0 then
		return nil
	end
	local reach = math.min(HoldRules.SUPPORT_REACH, HoldRules.SUPPORT_MAX_STUDS / length)
	return math.min(grip + reach, 0.9)
end

function HoldRules.supportWeight(reloading: boolean, aiming: boolean?): number
	return if aiming and not reloading then 1 else 0
end

--[[
	Arm clearance (batch 5): the pose limit every held stance keeps. With a pose's joint angles
	run through the survivor's arm (the StarterCharacter's joint attachments, UpperTorso
	space), the elbow, the wrist and the middle of the forearm must stay out of TORSO_CORE, the
	chest's core box (inside the mesh everywhere, so a point in it is an arm through the body).
	The shoulder and elbow angles that pass are the ones that swing the elbow out to the side
	or ahead of the chest. Pure: tests/Holds.spec checks every gun, bow, throw and reload key.
]]
type Vec = { number }
type Side = {
	shoulder: Vec, -- the shoulder joint in the UpperTorso
	shoulderInArm: Vec, -- the same joint in the upper arm
	restRoll: number, -- the shoulder attachment's roll in the upper arm (degrees, about Z)
	elbowInArm: Vec, -- the elbow joint in the upper arm
	elbowInForearm: Vec, -- the same joint in the forearm
	wristInForearm: Vec, -- the wrist joint in the forearm
}
HoldRules.ARM_RIG = {
	Right = {
		shoulder = { 0.597, 0.223, 0.125 },
		shoulderInArm = { -0.262, 0.174, -0.004 },
		restRoll = 33,
		elbowInArm = { 0.203, -0.342, -0.051 },
		elbowInForearm = { -0.192, 0.237, 0.067 },
		wristInForearm = { 0.212, -0.283, -0.129 },
	},
	Left = {
		shoulder = { -0.614, 0.219, 0.117 },
		shoulderInArm = { 0.256, 0.172, 0.004 },
		restRoll = -33,
		elbowInArm = { -0.193, -0.334, -0.031 },
		elbowInForearm = { 0.197, 0.257, 0.074 },
		wristInForearm = { -0.213, -0.259, -0.114 },
	},
} :: { [string]: Side }
-- UpperTorso space; the chest mesh is 1.53 by 2.02 by 1.28 studs.
HoldRules.TORSO_CORE = { halfX = 0.62, halfZ = 0.5, top = 0.95, bottom = -1.05 }

type Mat = { number } -- row-major 3x3

local function mul(a: Mat, b: Mat): Mat
	local m = table.create(9, 0)
	for r = 0, 2 do
		for c = 0, 2 do
			m[r * 3 + c + 1] = a[r * 3 + 1] * b[c + 1] + a[r * 3 + 2] * b[c + 4] + a[r * 3 + 3] * b[c + 7]
		end
	end
	return m
end

local function apply(m: Mat, v: Vec): Vec
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end

-- CFrame.Angles(x, y, z) in degrees: Rx * Ry * Rz.
local function angles(p: { number }): Mat
	local x, y, z = math.rad(p[1]), math.rad(p[2]), math.rad(p[3])
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	local rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return mul(mul(rx, ry), rz)
end

local function sub(a: Vec, b: Vec): Vec
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function add(a: Vec, b: Vec): Vec
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

-- The elbow and wrist of one arm in UpperTorso space for a pose's shoulder and elbow angles.
function HoldRules.armPoints(poses: { [string]: { number } }, side: string): (Vec, Vec)
	local rig = HoldRules.ARM_RIG[side]
	local zero = { 0, 0, 0 }
	local shoulder = angles(poses[side .. "UpperArm"] or zero)
	local elbow = angles(poses[side .. "LowerArm"] or zero)
	local unroll = angles({ 0, 0, -rig.restRoll })
	-- A point in the upper arm, in UpperTorso space.
	local function fromArm(v: Vec): Vec
		return add(rig.shoulder, apply(shoulder, apply(unroll, sub(v, rig.shoulderInArm))))
	end
	local wristInArm = add(rig.elbowInArm, apply(elbow, sub(rig.wristInForearm, rig.elbowInForearm)))
	return fromArm(rig.elbowInArm), fromArm(wristInArm)
end

local function inCore(p: Vec): boolean
	local core = HoldRules.TORSO_CORE
	return math.abs(p[1]) < core.halfX and math.abs(p[3]) < core.halfZ and p[2] < core.top and p[2] > core.bottom
end

-- True when the arm's elbow, wrist and mid-forearm are all out of the chest's core.
function HoldRules.armClear(poses: { [string]: { number } }, side: string): boolean
	local elbow, wrist = HoldRules.armPoints(poses, side)
	local mid = { (elbow[1] + wrist[1]) / 2, (elbow[2] + wrist[2]) / 2, (elbow[3] + wrist[3]) / 2 }
	return not (inCore(elbow) or inCore(wrist) or inCore(mid))
end

-- Eat, drink or dress a wound: whichever the item mostly does.
function HoldRules.consumeAction(
	consume: { hunger: number?, thirst: number?, health: number?, energy: number? }?
): string
	if consume == nil then
		return "eat"
	end
	local hunger, thirst, health = consume.hunger or 0, consume.thirst or 0, consume.health or 0
	if health > hunger and health > thirst then
		return "bandage"
	end
	-- Tonics (Energy only) are drunk too.
	return if thirst > hunger or (hunger == 0 and health == 0) then "drink" else "eat"
end

return HoldRules
