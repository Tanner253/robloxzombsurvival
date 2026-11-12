--!strict
--[[
	Holds: how a survivor holds and uses everything that can be in the hand (2.0 batch 1,
	"hands, animations and feel"). Pure data, read by the client's animation code
	(client/Clips), the server's swing timing (Domain/HoldRules) and the held-model mount
	(World/Models); tests/Holds.spec keeps every holdable item, class and clip in step.

	- `items`: each holdable item's class. One animation set per class, never per item.
	- `classes`: per class, the mount in the fist ("fist": the head points ahead of the
	  hanging arm; "gun": the bore runs along the forearm, so an aimed arm aims the gun) and
	  the clips it plays: `carry` loops while it is in hand (guns and the bow only: a melee
	  weapon hangs from the fist under the walk), `swing` and `heavy` are the light and
	  charged melee attacks, `aim`, `recoil` and `reload` the gun's.
	- `clips`: keyframes. Each pose is { x, y, z } degrees (CFrame.Angles order) on the
	  joint, plus { px, py, pz } studs where a part moves (LowerTorso). `hit` is the hit
	  frame in seconds at play rate 1: the server lands a light swing's damage on it, and the
	  impact sound and sparks play on it. `partial` clips only drive the parts they name, so
	  the legs walk on under them. `ual` names a Universal Animation Library clip
	  (Data/UalClips) that replaces the keys when the rig can take it.

	The gun stances, carries and the bow draw were solved by inverse kinematics against the
	StarterCharacter's joints and meshes in Studio (batch 5 re-solve: no arm inside the torso,
	head or worn bag; see the note above AIM_PISTOL). Melee and gathering keys are hand-keyed, with
	each hit frame's wrist set from the weapon's measured direction there: an axe level or
	a little down into the target, a blade sweeping flat, the stake rising to the chest.
]]

local Holds = {}

export type Class =
	"fists"
	| "blade"
	| "axe"
	| "pick"
	| "blunt"
	| "heavy"
	| "stab"
	| "pistol"
	| "long"
	| "bow"
	| "throw"
export type Mount = "fist" | "gun"
export type Pose = { number } -- { x, y, z } degrees, or { x, y, z, px, py, pz }
export type Key = { time: number, poses: { [string]: Pose } }
export type Clip = {
	length: number,
	hit: number?,
	loop: boolean?,
	partial: boolean?,
	linear: boolean?, -- linear easing between keys (the generated leg cycles)
	ual: string?,
	keys: { Key },
}
export type ClassDef = {
	mount: Mount,
	carry: string?,
	swing: string?,
	heavy: string?,
	aim: string?,
	recoil: string?,
	reload: string?,
}

-- The parts a clip may pose, parents first (the R15 survivor).
Holds.PARENTS = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	Head = "UpperTorso",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
} :: { [string]: string }

Holds.items = {
	-- Tools: in a weapon slot they swing as weak clubs (LDOE_PARITY #34, F-29).
	["item.stone_hatchet"] = "axe",
	["item.forged_hatchet"] = "axe",
	["item.stone_pick"] = "pick",
	["item.forged_pick"] = "pick",
	-- Melee
	["item.sharpened_stake"] = "stab",
	["item.spiked_club"] = "blunt",
	["item.tire_iron"] = "blunt",
	["item.rail_mallet"] = "heavy",
	["item.scrapblade"] = "blade",
	["item.machete"] = "blade",
	["item.fire_axe"] = "axe",
	-- Content 2.0 (ARSENAL §4; `melee.class` in Data/Items says the same).
	["item.hand_axe"] = "axe",
	["item.hardwood_bat"] = "blunt",
	["item.field_knife"] = "stab",
	["item.hay_fork"] = "stab",
	-- Guns (ARSENAL animClass pistol → pistol; shotgun and rifle → long)
	["item.pipe_pistol"] = "pistol",
	["item.flare_pistol"] = "pistol",
	["item.duty_pistol"] = "pistol",
	["item.scrap_shotgun"] = "long",
	["item.pump_shotgun"] = "long",
	["item.hunting_rifle"] = "long",
	["item.assault_rifle"] = "long",
	["item.anti_materiel_rifle"] = "long",
	-- Batch 5. The Hand Cannon is a revolver held out in both hands; both SMGs have stocks and
	-- shoulder like long guns (HoldRules' default for animClass "smg").
	["item.hand_cannon"] = "pistol",
	["item.machine_pistol"] = "long",
	["item.patrol_carbine"] = "long",
	["item.compact_rifle"] = "long",
	["item.tactical_smg"] = "long",
	["item.marksman_rifle"] = "long",
	["item.shortbow"] = "bow",
	-- Throwables: in the fist, thrown overhand (the swing's hit frame is the release).
	["item.frag_grenade"] = "throw",
	["item.molotov"] = "throw",
} :: { [string]: Class }

Holds.classes = {
	fists = { mount = "fist", swing = "punch", heavy = "heavy" },
	blade = { mount = "fist", swing = "slash", heavy = "heavy" },
	axe = { mount = "fist", swing = "chopSwing", heavy = "heavy" },
	blunt = { mount = "fist", swing = "chopSwing", heavy = "heavy" },
	pick = { mount = "fist", swing = "mine", heavy = "heavy" },
	heavy = { mount = "fist", swing = "heavy", heavy = "heavy" },
	stab = { mount = "fist", swing = "thrust", heavy = "lunge" },
	pistol = {
		mount = "gun",
		carry = "carryPistol",
		aim = "aimPistol",
		recoil = "recoilPistol",
		reload = "reload",
	},
	long = { mount = "gun", carry = "carryLong", aim = "aimLong", recoil = "recoilLong", reload = "reload" },
	bow = { mount = "gun", carry = "carryBow", aim = "drawBow" },
	throw = { mount = "fist", swing = "throw", heavy = "throw" },
} :: { [string]: ClassDef }

--[[
	Clearance re-solve (batch 5, 2026-11-12): the stances above clipped. The survivor's arms
	are short against its torso (shoulder to wrist 1.38 studs, the chest 1.53 by 1.28), and
	the batch-3 blade left the gun elbow inside the chest (the forearm 0.47 studs deep). Each
	stance below was solved in Studio against the StarterCharacter's own meshes: the hand
	keeps its rotation (the bore keeps its line), the torso yaw and the hand's place were
	searched, and each elbow was swung out (two-bone IK) until no arm vertex sat inside the
	torso, head or worn bag. The elbows sit out to the side or ahead of the chest, as
	HoldRules.armClear checks. A long gun's off hand closes on the gun just ahead of the grip
	while aiming (HoldRules.SUPPORT_MAX_STUDS) and lets go at the carry, where a two-handed
	hold can't clear the chest at this build.
]]
local AIM_PISTOL: { [string]: Pose } = {
	UpperTorso = { 0, 2, 0 },
	Head = { 0, -4, 0 },
	RightUpperArm = { -40.2, 81.5, 118.3 },
	RightLowerArm = { 37.1, 39.9, 1.2 },
	RightHand = { 134.7, -56.2, 173.8 },
	LeftUpperArm = { -60.1, -79.4, -130.1 },
	LeftLowerArm = { 27.6, -34.5, -3.3 },
	LeftHand = { 118.5, 24.8, -84.2 },
}
-- Shouldered, bladed 30 degrees, the gun elbow out (rec6_05). The off hand lands by IK on the
-- gun just ahead of the grip (client/Controllers/Animations, HoldRules.supportAt); these
-- left-arm keys are where that IK starts from.
local AIM_LONG: { [string]: Pose } = {
	UpperTorso = { 0, -30, 0 },
	Head = { 0, 24, 0 },
	RightUpperArm = { -44.8, 74.3, 118.2 },
	RightLowerArm = { 68.4, 51.2, -16.3 },
	RightHand = { 121.4, -56.8, 150.6 },
	LeftUpperArm = { 45.3, -62.8, -18.5 },
	LeftLowerArm = { 54, -47.2, 9.3 },
	LeftHand = { 104.1, 51.2, -94.1 },
}
-- Low ready in the gun hand, the muzzle down at the ground ahead (rec3_08); the off arm
-- swings with the walk.
local CARRY_LONG: { [string]: Pose } = {
	UpperTorso = { 0, -10, 0 },
	Head = { 0, 6, 0 },
	RightUpperArm = { -83, 49.7, 127.9 },
	RightLowerArm = { 46.3, 44.4, -3.3 },
	RightHand = { 132.7, -46.6, 135 },
}
local CARRY_PISTOL: { [string]: Pose } = {
	UpperTorso = { 0, -10, 0 },
	Head = { 0, 10, 0 },
	RightUpperArm = { -104.3, 41.6, 157.1 },
	RightLowerArm = { 32.5, 37.3, 3.1 },
	RightHand = { 149.9, -31, 147.2 },
}
-- Upright in front of the hip, the string toward the body, both tips clear of the legs.
local CARRY_BOW: { [string]: Pose } = {
	RightUpperArm = { -55.7, 46.3, 89.4 },
	RightLowerArm = { 61.2, 49.5, -11.8 },
	RightHand = { 98.3, -23.7, 121.8 },
}
-- The bow arm out at the target, the string hand drawn back along the arrow.
local DRAW_BOW: { [string]: Pose } = {
	UpperTorso = { 0, 15, 0 },
	Head = { 0, -10, 0 },
	RightUpperArm = { -146.3, 86.5, -127.1 },
	RightLowerArm = { 2.5, 13.7, 8.7 },
	RightHand = { 146, -67.3, 167.8 },
	LeftUpperArm = { -35.6, -65.3, -144.2 },
	LeftLowerArm = { 67.9, -50.8, 17.7 },
	LeftHand = { 17.5, 47.3, -18.9 },
}

local function held(poses: { [string]: Pose }, length: number): Clip
	return {
		length = length,
		loop = true,
		partial = true,
		keys = { { time = 0, poses = poses }, { time = length, poses = poses } },
	}
end

-- The aim stance with the chest rocked back: a kick on each shot.
local function kick(aim: { [string]: Pose }): Clip
	local torso = aim.UpperTorso
	return {
		length = 0.22,
		partial = true,
		keys = {
			{ time = 0, poses = { UpperTorso = torso } },
			{ time = 0.05, poses = { UpperTorso = { torso[1] - 7, torso[2], torso[3] } } },
			{ time = 0.22, poses = { UpperTorso = torso } },
		},
	}
end

Holds.clips = {
	-- Throwables (batch 5): an overhand throw. The off arm points at the target while the
	-- throwing arm winds up behind the head with the right shoulder turned back; the chest
	-- turns through and the hand lets go above the shoulder at `hit` (Services/Throwables
	-- releases it then), then follows through across the body. The hands keep the hand-keyed
	-- path; the elbows were re-solved clear of the body (see the stances), and the clip starts
	-- and ends on what plays beneath it rather than the rig's rest pose, whose arms sit in
	-- the hips.
	throw = {
		length = 0.75,
		hit = 0.3,
		partial = true,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.18,
				poses = {
					UpperTorso = { -8, -40, 0 },
					Head = { 0, 34, 0 },
					RightUpperArm = { 72, -10.8, 112 },
					RightLowerArm = { 53.6, 47.2, -7.3 },
					RightHand = { 150.2, 33.5, 100.2 },
					LeftUpperArm = { 84.4, -37.5, 3.4 },
					LeftLowerArm = { -0.7, -11.7, -7.4 },
					LeftHand = { 37.2, 42.5, -5.1 },
				},
			},
			{
				time = 0.3,
				poses = {
					UpperTorso = { 6, 14, 0 },
					Head = { 0, -10, 0 },
					RightUpperArm = { 124.8, 38.7, 12.8 },
					RightLowerArm = { 5.3, 16.2, 8.8 },
					RightHand = { 47.8, -48.6, 13.6 },
					LeftUpperArm = { 24.7, -57.7, -25.6 },
					LeftLowerArm = { 7.7, -19.1, -7.4 },
					LeftHand = { 89.7, 55.1, -48.4 },
				},
			},
			{
				time = 0.45,
				poses = {
					UpperTorso = { 14, 40, 0 },
					Head = { 0, -34, 0 },
					RightUpperArm = { 75.4, 77.5, 10.9 },
					RightLowerArm = { 14, 23.8, 8.2 },
					RightHand = { 131.6, -48.9, 97.5 },
					LeftUpperArm = { -21.1, -53.8, -46.6 },
					LeftLowerArm = { 19.6, -28.8, -5.6 },
					LeftHand = { 65.5, 69, -27.1 },
				},
			},
			{ time = 0.75, poses = {} },
		},
	},
	-- Melee -----------------------------------------------------------------------------------
	-- A quick diagonal slash: wind back, cut across, recover.
	slash = {
		length = 0.42,
		hit = 0.22,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.12,
				poses = { UpperTorso = { 0, 34, 0 }, RightUpperArm = { 120, 0, 40 }, RightLowerArm = { 40, 0, 0 } },
			},
			{
				time = 0.22,
				poses = {
					UpperTorso = { -8, -30, 0 },
					RightUpperArm = { 70, 0, -45 },
					RightLowerArm = { 5, 0, 0 },
					RightHand = { -100, 0, -30 },
				},
			},
			{ time = 0.42, poses = {} },
		},
	},
	-- Axes and clubs: over the shoulder and down across the body.
	chopSwing = {
		length = 0.5,
		hit = 0.24,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.15,
				poses = {
					UpperTorso = { 6, 28, 0 },
					RightUpperArm = { 165, 0, 25 },
					RightLowerArm = { 35, 0, 0 },
					LeftUpperArm = { 20, 0, -10 },
				},
			},
			{
				time = 0.24,
				poses = {
					UpperTorso = { -12, -22, 0 },
					RightUpperArm = { 62, 0, -30 },
					RightLowerArm = { 8, 0, 0 },
					RightHand = { -100, 0, 0 },
					LeftUpperArm = { -10, 0, -8 },
				},
			},
			{
				time = 0.3,
				poses = { UpperTorso = { -10, -20, 0 }, RightUpperArm = { 58, 0, -28 }, RightHand = { -105, 0, 0 } },
			},
			{ time = 0.5, poses = {} },
		},
	},
	-- The stake: drawn back at the hip, then driven forward with the body behind it.
	thrust = {
		length = 0.46,
		hit = 0.2,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.12,
				poses = {
					UpperTorso = { 0, 30, 0 },
					RightUpperArm = { -28, 0, 8 },
					RightLowerArm = { 40, 0, 0 },
					RightHand = { 10, 0, 0 },
				},
			},
			{
				time = 0.2,
				poses = {
					UpperTorso = { -10, -22, 0 },
					RightUpperArm = { 42, 0, -12 },
					RightLowerArm = { 0, 0, 0 },
					RightHand = { -38, 0, 0 },
					LeftUpperArm = { -20, 0, -10 },
				},
			},
			{ time = 0.46, poses = {} },
		},
	},
	-- The stake's charged blow: a deep lunge.
	lunge = {
		length = 0.78,
		hit = 0.48,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.36,
				poses = {
					UpperTorso = { 4, 38, 0 },
					RightUpperArm = { -35, 0, 10 },
					RightLowerArm = { 50, 0, 0 },
					RightHand = { 12, 0, 0 },
					RightUpperLeg = { -10, 0, 0 },
					LeftUpperLeg = { 14, 0, 0 },
				},
			},
			{
				time = 0.48,
				poses = {
					UpperTorso = { -18, -25, 0 },
					RightUpperArm = { 55, 0, -14 },
					RightLowerArm = { 0, 0, 0 },
					RightHand = { -50, 0, 0 },
					LeftUpperArm = { -25, 0, -10 },
					RightUpperLeg = { -22, 0, 0 },
					LeftUpperLeg = { 20, 0, 0 },
				},
			},
			{ time = 0.78, poses = {} },
		},
	},
	-- Bare hands: a straight right.
	punch = {
		length = 0.34,
		hit = 0.12,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.06,
				poses = { UpperTorso = { 0, 18, 0 }, RightUpperArm = { 40, 0, -20 }, RightLowerArm = { 110, 0, 0 } },
			},
			{
				time = 0.12,
				poses = {
					UpperTorso = { -4, -24, 0 },
					RightUpperArm = { 88, 0, -18 },
					RightLowerArm = { 8, 0, 0 },
					LeftUpperArm = { 30, 0, 20 },
					LeftLowerArm = { 100, 0, 0 },
				},
			},
			{ time = 0.34, poses = {} },
		},
	},
	-- A heavy overhead blow: a long wind-up, a committed chop, a slow recovery.
	heavy = {
		length = 0.78,
		hit = 0.48,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.36,
				poses = {
					UpperTorso = { 14, 20, 0 },
					RightUpperArm = { 175, 0, 10 },
					RightLowerArm = { 50, 0, 0 },
					LeftUpperArm = { 150, 0, -10 },
				},
			},
			{
				time = 0.48,
				poses = {
					UpperTorso = { -22, -10, 0 },
					RightUpperArm = { 40, 0, -20 },
					RightLowerArm = { 10, 0, 0 },
					RightHand = { -90, 0, 0 },
					LeftUpperArm = { 40, 0, 10 },
					RightUpperLeg = { -20, 0, 0 },
					LeftUpperLeg = { 18, 0, 0 },
				},
			},
			{ time = 0.78, poses = {} },
		},
	},

	-- Guns and the bow ---------------------------------------------------------------------------
	aimPistol = held(AIM_PISTOL, 0.3),
	aimLong = held(AIM_LONG, 0.3),
	carryPistol = held(CARRY_PISTOL, 1),
	carryLong = held(CARRY_LONG, 1),
	carryBow = held(CARRY_BOW, 1),
	drawBow = held(DRAW_BOW, 0.6),
	recoilPistol = kick(AIM_PISTOL),
	recoilLong = kick(AIM_LONG),
	-- The gun comes down in front of the chest, the off hand works the magazine, the gun comes
	-- back up. Hand-keyed (the UAL Pistol_Reload put the gun forearm 0.12 studs into the chest
	-- on this rig), each key's elbows solved clear; partial, so the legs walk on under it.
	reload = {
		length = 1.2,
		partial = true,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.25,
				poses = {
					Head = { -20, 0, 0 },
					RightUpperArm = { 41.5, 27, 10.2 },
					RightLowerArm = { 29.1, 35.1, 4.4 },
					RightHand = { 82.6, -48, 48.7 },
				},
			},
			{
				time = 0.6,
				poses = {
					Head = { -24, 0, 0 },
					RightUpperArm = { 41.5, 27, 10.2 },
					RightLowerArm = { 29.1, 35.1, 4.4 },
					RightHand = { 82.6, -48, 48.7 },
					LeftUpperArm = { 13.9, -49.9, -37.4 },
					LeftLowerArm = { 35.7, -39.3, -0.1 },
					LeftHand = { 127.8, 24.1, -87 },
				},
			},
			{
				time = 0.9,
				poses = {
					Head = { -10, 0, 0 },
					RightUpperArm = { 55.1, 30.1, 5.4 },
					RightLowerArm = { 10.9, 21.2, 8.5 },
					RightHand = { 46.5, -46.4, 14.7 },
				},
			},
			{ time = 1.2, poses = {} },
		},
	},

	-- The body ------------------------------------------------------------------------------------
	-- A forward roll: tuck, over the shoulder, back up.
	roll = {
		length = 0.5,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.1,
				poses = {
					LowerTorso = { -60, 0, 0 },
					UpperTorso = { -30, 0, 0 },
					Head = { -20, 0, 0 },
					RightUpperLeg = { 70, 0, 0 },
					LeftUpperLeg = { 70, 0, 0 },
					RightLowerLeg = { -90, 0, 0 },
					LeftLowerLeg = { -90, 0, 0 },
				},
			},
			{
				time = 0.28,
				poses = {
					LowerTorso = { -200, 0, 0 },
					UpperTorso = { -30, 0, 0 },
					Head = { -20, 0, 0 },
					RightUpperLeg = { 80, 0, 0 },
					LeftUpperLeg = { 80, 0, 0 },
					RightLowerLeg = { -100, 0, 0 },
					LeftLowerLeg = { -100, 0, 0 },
				},
			},
			{
				time = 0.42,
				poses = { LowerTorso = { -350, 0, 0 }, RightUpperLeg = { 30, 0, 0 }, LeftUpperLeg = { 30, 0, 0 } },
			},
			{ time = 0.5, poses = {} },
		},
	},
	hitReact = {
		length = 0.35,
		ual = "Hit_Chest",
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.08,
				poses = {
					UpperTorso = { -14, 10, 0 },
					Head = { -16, 0, 8 },
					RightUpperArm = { -10, 0, 20 },
					LeftUpperArm = { -10, 0, -20 },
				},
			},
			{ time = 0.35, poses = {} },
		},
	},
	-- Collapse to the knees and forward (no gore, 1.9).
	collapse = {
		length = 1.1,
		ual = "Death01",
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.35,
				poses = {
					LowerTorso = { -10, 0, 0 },
					UpperTorso = { 20, 0, 0 },
					Head = { 20, 0, 0 },
					RightUpperLeg = { 80, 0, 0 },
					LeftUpperLeg = { 80, 0, 0 },
					RightLowerLeg = { -100, 0, 0 },
					LeftLowerLeg = { -100, 0, 0 },
				},
			},
			{
				time = 1.1,
				poses = {
					LowerTorso = { 70, 0, 0 },
					UpperTorso = { 10, 0, 0 },
					Head = { 10, 0, 0 },
					RightUpperLeg = { 20, 0, 0 },
					LeftUpperLeg = { 20, 0, 0 },
					RightUpperArm = { 150, 0, 20 },
					LeftUpperArm = { 150, 0, -20 },
				},
			},
		},
	},

	-- Gathering and actions (only the parts named move; the walk shows through) -------------------
	-- A diagonal overhead chop into a trunk.
	chop = {
		length = 0.62,
		hit = 0.3,
		partial = true,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.2,
				poses = {
					UpperTorso = { 6, 28, 0 },
					RightUpperArm = { 165, 0, 25 },
					RightLowerArm = { 35, 0, 0 },
					LeftUpperArm = { 20, 0, -10 },
				},
			},
			{
				time = 0.3,
				poses = {
					UpperTorso = { -12, -22, 0 },
					RightUpperArm = { 62, 0, -30 },
					RightLowerArm = { 8, 0, 0 },
					RightHand = { -95, 0, 0 },
					LeftUpperArm = { -10, 0, -8 },
				},
			},
			{
				time = 0.36,
				poses = { UpperTorso = { -10, -20, 0 }, RightUpperArm = { 58, 0, -28 }, RightHand = { -92, 0, 0 } },
			},
			{ time = 0.62, poses = {} },
		},
	},
	-- A vertical overhead swing down into the rock.
	mine = {
		length = 0.66,
		hit = 0.32,
		partial = true,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.22,
				poses = {
					UpperTorso = { 12, 0, 0 },
					RightUpperArm = { 175, 0, 8 },
					RightLowerArm = { 25, 0, 0 },
					LeftUpperArm = { 150, 0, -10 },
					LeftLowerArm = { 25, 0, 0 },
				},
			},
			{
				time = 0.32,
				poses = {
					UpperTorso = { -24, 0, 0 },
					RightUpperArm = { 55, 0, -4 },
					RightLowerArm = { 5, 0, 0 },
					RightHand = { -80, 0, 0 },
					LeftUpperArm = { 40, 0, 6 },
				},
			},
			{
				time = 0.38,
				poses = { UpperTorso = { -22, 0, 0 }, RightUpperArm = { 52, 0, -4 }, RightHand = { -75, 0, 0 } },
			},
			{ time = 0.66, poses = {} },
		},
	},
	-- A quick weapon swap (4.9): the hand drops to the hip and comes back up.
	swap = {
		length = 0.32,
		hit = 0.16,
		partial = true,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.14,
				poses = { RightUpperArm = { -25, 0, 18 }, RightLowerArm = { 35, 0, 0 }, UpperTorso = { 0, -12, 0 } },
			},
			{ time = 0.32, poses = {} },
		},
	},
	-- Crouch, reach and grab.
	pickup = {
		length = 0.7,
		hit = 0.32,
		partial = true,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.25,
				poses = {
					LowerTorso = { -10, 0, 0, 0, -1.1, 0.2 },
					UpperTorso = { -38, 0, 0 },
					RightUpperLeg = { 75, 0, 0 },
					RightLowerLeg = { -95, 0, 0 },
					LeftUpperLeg = { 55, 0, 0 },
					LeftLowerLeg = { -100, 0, 0 },
					RightUpperArm = { 55, 0, -10 },
					RightLowerArm = { 10, 0, 0 },
					Head = { -15, 0, 0 },
				},
			},
			{
				time = 0.38,
				poses = {
					LowerTorso = { -10, 0, 0, 0, -1.1, 0.2 },
					UpperTorso = { -36, 0, 0 },
					RightUpperLeg = { 75, 0, 0 },
					RightLowerLeg = { -95, 0, 0 },
					LeftUpperLeg = { 55, 0, 0 },
					LeftLowerLeg = { -100, 0, 0 },
					RightUpperArm = { 35, 0, -5 },
					RightLowerArm = { 40, 0, 0 },
				},
			},
			{ time = 0.7, poses = {} },
		},
	},
	-- Hand to mouth twice (food).
	eat = {
		length = 1.1,
		hit = 0.35,
		partial = true,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.25,
				poses = { RightUpperArm = { 70, 0, 15 }, RightLowerArm = { 115, 0, 0 }, Head = { -8, 0, 0 } },
			},
			{
				time = 0.5,
				poses = { RightUpperArm = { 60, 0, 15 }, RightLowerArm = { 95, 0, 0 }, Head = { -4, 0, 0 } },
			},
			{
				time = 0.75,
				poses = { RightUpperArm = { 70, 0, 15 }, RightLowerArm = { 115, 0, 0 }, Head = { -8, 0, 0 } },
			},
			{ time = 1.1, poses = {} },
		},
	},
	-- Tip the head back and drink from the raised hand.
	drink = {
		length = 1.1,
		hit = 0.4,
		partial = true,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.3,
				poses = { RightUpperArm = { 85, 0, 20 }, RightLowerArm = { 120, 0, 0 }, Head = { 22, 0, 0 } },
			},
			{
				time = 0.8,
				poses = { RightUpperArm = { 95, 0, 20 }, RightLowerArm = { 115, 0, 0 }, Head = { 30, 0, 0 } },
			},
			{ time = 1.1, poses = {} },
		},
	},
	-- Dressing a wound: both hands to the left forearm.
	bandage = {
		length = 1.2,
		hit = 0.5,
		partial = true,
		keys = {
			{ time = 0, poses = {} },
			{
				time = 0.3,
				poses = {
					LeftUpperArm = { 40, 0, 25 },
					LeftLowerArm = { 80, 0, 0 },
					RightUpperArm = { 45, 0, -25 },
					RightLowerArm = { 95, 0, 0 },
					Head = { -18, 0, 0 },
				},
			},
			{
				time = 0.6,
				poses = {
					LeftUpperArm = { 40, 0, 25 },
					LeftLowerArm = { 80, 0, 0 },
					RightUpperArm = { 35, 0, -30 },
					RightLowerArm = { 105, 0, 0 },
					Head = { -18, 0, 0 },
				},
			},
			{
				time = 0.9,
				poses = {
					LeftUpperArm = { 40, 0, 25 },
					LeftLowerArm = { 80, 0, 0 },
					RightUpperArm = { 45, 0, -25 },
					RightLowerArm = { 95, 0, 0 },
					Head = { -18, 0, 0 },
				},
			},
			{ time = 1.2, poses = {} },
		},
	},
} :: { [string]: Clip }

-- The action clip for a node's tool kind (gathering).
Holds.gather = { hatchet = "chop", pick = "mine" } :: { [string]: string }

return Holds
