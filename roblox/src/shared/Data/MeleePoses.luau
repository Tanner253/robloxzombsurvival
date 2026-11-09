--!strict
--[[
	MeleePoses: the survivor's melee, tool and action poses (checklist 13.4), keyed on
	Domain/MeleeTiming's marks and built by Domain/MeleeKeys. Pure data.

	A move is either hand-keyed (`keys`) or a UAL clip (`ual`: Quaternius's Universal
	Animation Library, CC0, retargeted into Data/MeleeClips) time-warped onto the marks.

	Hand-keyed keys: `at` is a mark name (prep, windup, contact, follow, cycle, length) or
	seconds; `ease` shapes the motion to the next key ("in" accelerates into it, "out"
	decelerates out of it, "inOut", "linear"); `pose` sets parts:
	- Right / Left: arms by direction in the character's axes (X right, Y up, -Z forward):
	  { up = upper arm, fore = forearm, weapon = the held item }, or Left = { grip = studs }
	  to put the left fist on the handle (negative: toward the head), via IK.
	- UpperTorso, Head, legs: { x, y, z } degrees relative to the parent part; LowerTorso
	  may add { px, py, pz } studs (crouch, step). +X pitches back (so lean forward is
	  negative), +Y turns left, +Z rolls the left shoulder down.
	  Thighs flex forward with +X, knees bend with -X, feet point their toes up with +X.
	A move that keys no leg plays waist-up everywhere; one that keys legs plays them when
	standing still and waist-up while moving (MeleeKeys variants).

	Swings read from the 55 degree camera: big arcs, a clear cock before the strike, the
	weapon past the target on the follow-through, and the torso turning into the blow.
]]

local MeleePoses = {}

export type KeySpec = { at: string | number, ease: string?, pose: { [string]: any } }
export type UalSource = {
	clip: string,
	from: number?,
	to: number?,
	map: { { any } }?, -- { source seconds, mark name } pairs for the time warp
	offsets: { [string]: { number } }?, -- degrees added on top of a part's UAL turn
	legs: boolean?, -- play the clip's hips and legs when standing still
}
export type MoveSpec = { base: { [string]: any }?, keys: { KeySpec }?, ual: UalSource? }

type Pose = { [string]: any }

local function with(...: Pose): Pose
	local out: Pose = {}
	for index = 1, select("#", ...) do
		for key, value in (select(index, ...) :: Pose) do
			out[key] = value
		end
	end
	return out
end

local function R(up: { number }, fore: { number }, weapon: { number }?): Pose
	return { up = up, fore = fore, weapon = weapon }
end

local function L(up: { number }, fore: { number }): Pose
	return { up = up, fore = fore }
end

local function GRIP(studs: number): Pose
	return { grip = studs }
end

-- Legs: the hips ({ pitch, turn, roll, x, y, z }) and each leg's thigh, knee and foot pitch.
local function legs(hips: { number }, lu: number, ll: number, lf: number, ru: number, rl: number, rf: number): Pose
	return {
		LowerTorso = hips,
		LeftUpperLeg = { lu, 0, 0 },
		LeftLowerLeg = { ll, 0, 0 },
		LeftFoot = { lf, 0, 0 },
		RightUpperLeg = { ru, 0, 0 },
		RightLowerLeg = { rl, 0, 0 },
		RightFoot = { rf, 0, 0 },
	}
end

local STAND = legs({ 0, 0, 0, 0, 0, 0 }, 0, 0, 0, 0, 0, 0)
local READY = legs({ 0, 0, 0, 0, -0.08, 0 }, 12, -20, 8, 8, -16, 8)
local COIL = legs({ 4, -16, 0, 0, -0.22, 0.12 }, 18, -28, 10, 26, -48, 22) -- weight back on the right
local LUNGE = legs({ -6, 12, 0, 0, -0.32, -0.25 }, 42, -52, 10, -18, -24, 10) -- left foot forward
local CROUCH = legs({ -10, 4, 0, 0, -0.6, -0.12 }, 55, -85, 30, 30, -72, 42) -- deep, both knees

-- Carry poses: one hand, two hands (the left fist up the handle), the spear grip.
local CARRY_R = R({ 0.12, -1, -0.2 }, { 0.05, -0.5, -1 }, { 0.1, 0.35, -1 })
local CARRY_L = L({ -0.12, -1, 0.05 }, { -0.05, -0.85, -0.45 })
local CARRY2_R = R({ 0.3, -1, -0.15 }, { -0.25, -0.45, -1 }, { -0.45, 0.55, -1 })
local SPEAR_R = R({ 0.35, -1, 0.35 }, { 0.05, -0.2, -1 }, { -0.12, -0.08, -1 })
local GUARD_L = L({ -0.25, -0.35, -1 }, { 0.3, -0.15, -1 }) -- the free hand toward the target
local BACK_L = L({ -0.45, -1, 0.45 }, { -0.25, -0.6, 0.7 }) -- pulled back for balance
local TUCK_L = L({ -0.2, -1, -0.1 }, { 0.35, -0.2, -1 }) -- across the belly (backhands)

local ONE: Pose = { Right = CARRY_R, Left = CARRY_L }
local TWO: Pose = { Right = CARRY2_R, Left = GRIP(-0.55) }
local SPEAR: Pose = { Right = SPEAR_R, Left = GRIP(-0.85) }

MeleePoses.moves = {
	-- One-handed blade (Scrapblade, Machete) ---------------------------------------------------
	["blade.light1"] = { -- forehand diagonal: high right to low left
		keys = {
			{ at = 0, pose = ONE },
			{
				at = "prep",
				pose = {
					UpperTorso = { 0, -12, 0 },
					Right = R({ 0.55, -0.55, 0.25 }, { 0.35, 0.5, -0.2 }, { 0.25, 1, 0.2 }),
					Left = CARRY_L,
				},
			},
			{
				at = "windup",
				ease = "in",
				pose = {
					UpperTorso = { 4, -38, 0 },
					Right = R({ 0.75, 0.5, 0.3 }, { 0.15, 0.85, 0.45 }, { -0.25, 0.35, 1 }),
					Left = GUARD_L,
				},
			},
			{
				at = "contact",
				ease = "out",
				pose = {
					UpperTorso = { -8, 22, 0 },
					Right = R({ 0.05, -0.05, -1 }, { -0.35, -0.25, -1 }, { -0.75, -0.3, -0.6 }),
					Left = BACK_L,
				},
			},
			{
				at = "follow",
				pose = {
					UpperTorso = { -12, 42, 0 },
					Right = R({ -0.45, -0.7, -0.55 }, { -0.85, -0.5, -0.1 }, { -0.55, -0.65, 0.55 }),
					Left = BACK_L,
				},
			},
			{
				at = "cycle",
				pose = {
					UpperTorso = { -4, 16, 0 },
					Right = R({ -0.1, -1, -0.3 }, { -0.35, -0.55, -0.8 }, { -0.4, 0.4, -1 }),
					Left = CARRY_L,
				},
			},
			{ at = "length", pose = ONE },
		},
	},
	["blade.light2"] = { -- backhand: left to right across the chest
		keys = {
			{ at = 0, pose = { UpperTorso = { -4, 16, 0 }, Right = CARRY_R, Left = CARRY_L } },
			{
				at = "prep",
				pose = {
					UpperTorso = { 0, 24, 0 },
					Right = R({ -0.3, -0.45, -0.85 }, { -0.85, 0.1, -0.5 }, { -0.9, 0.25, 0.3 }),
					Left = TUCK_L,
				},
			},
			{
				at = "windup",
				ease = "in",
				pose = {
					UpperTorso = { 2, 48, 0 },
					Right = R({ -0.45, -0.1, -0.9 }, { -0.9, 0.2, 0.15 }, { -0.2, 0.2, 1 }),
					Left = TUCK_L,
				},
			},
			{
				at = "contact",
				ease = "out",
				pose = {
					UpperTorso = { -6, -14, 0 },
					Right = R({ 0.3, -0.05, -1 }, { 0.6, -0.05, -0.85 }, { 0.9, -0.08, -0.45 }),
					Left = BACK_L,
				},
			},
			{
				at = "follow",
				pose = {
					UpperTorso = { -6, -42, 0 },
					Right = R({ 0.9, -0.2, -0.15 }, { 0.85, -0.1, 0.5 }, { 0.25, -0.1, 1 }),
					Left = GUARD_L,
				},
			},
			{
				at = "cycle",
				pose = {
					UpperTorso = { 0, -14, 0 },
					Right = R({ 0.45, -0.8, -0.1 }, { 0.3, -0.3, -0.9 }, { 0.2, 0.7, -0.7 }),
					Left = CARRY_L,
				},
			},
			{ at = "length", pose = ONE },
		},
	},
	["blade.light3"] = { -- the finisher: an overhead diagonal cleave with a step
		keys = {
			{ at = 0, pose = with(ONE, STAND) },
			{
				at = "prep",
				pose = with({
					UpperTorso = { 6, -10, 0 },
					Right = R({ 0.45, 0.25, 0.25 }, { 0.15, 1, 0 }, { 0.1, 0.65, 0.75 }),
					Left = CARRY_L,
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 12, -26, 0 },
					Head = { -6, 10, 0 },
					Right = R({ 0.35, 0.9, 0.2 }, { -0.05, 0.45, 0.9 }, { -0.1, -0.55, 1 }),
					Left = GUARD_L,
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -24, 16, 0 },
					Right = R({ 0.15, -0.25, -1 }, { 0, -0.75, -0.7 }, { -0.25, -0.8, -0.55 }),
					Left = BACK_L,
				}, LUNGE),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -30, 26, 0 },
					Right = R({ -0.1, -0.85, -0.45 }, { -0.3, -0.9, 0.3 }, { -0.35, -0.75, 0.6 }),
					Left = BACK_L,
				}, LUNGE),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -10, 10, 0 },
					Right = R({ 0.1, -1, -0.25 }, { 0, -0.6, -0.9 }, { 0, 0.4, -1 }),
					Left = CARRY_L,
				}, READY),
			},
			{ at = "length", pose = with(ONE, STAND) },
		},
	},
	["blade.heavy"] = { -- charged: coiled low with the blade high, then a stepping cleave
		keys = {
			{ at = 0, pose = with(ONE, STAND) },
			{
				at = 0.14,
				pose = with({
					UpperTorso = { 4, -28, 0 },
					Right = R({ 0.7, 0.2, 0.35 }, { 0.3, 0.9, 0.2 }, { 0, 0.8, 0.6 }),
					Left = GUARD_L,
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 10, -55, 0 },
					Head = { -4, 30, 0 },
					Right = R({ 0.85, 0.45, 0.35 }, { 0.2, 0.6, 0.8 }, { -0.5, -0.2, 1 }),
					Left = L({ -0.1, -0.2, -1 }, { 0.4, 0, -1 }),
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -18, 35, 0 },
					Head = { 0, -10, 0 },
					Right = R({ -0.15, -0.25, -1 }, { -0.55, -0.45, -0.75 }, { -0.8, -0.5, -0.35 }),
					Left = BACK_L,
				}, LUNGE),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -22, 58, 0 },
					Right = R({ -0.6, -0.65, -0.3 }, { -0.9, -0.4, 0.2 }, { -0.4, -0.6, 0.75 }),
					Left = BACK_L,
				}, LUNGE),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -8, 18, 0 },
					Right = R({ 0, -1, -0.3 }, { -0.25, -0.6, -0.8 }, { -0.3, 0.4, -1 }),
					Left = CARRY_L,
				}, READY),
			},
			{ at = "length", pose = with(ONE, STAND) },
		},
	},

	-- Axe (hatchets, Fire Axe) ------------------------------------------------------------------
	["axe.light1"] = { -- forehand overhead chop, high right down into the chest
		keys = {
			{ at = 0, pose = ONE },
			{
				at = "prep",
				pose = {
					UpperTorso = { 2, -10, 0 },
					Right = R({ 0.55, -0.4, 0.3 }, { 0.3, 0.6, 0.1 }, { 0.1, 0.9, 0.5 }),
					Left = CARRY_L,
				},
			},
			{
				at = "windup",
				ease = "in",
				pose = {
					UpperTorso = { 10, -30, 0 },
					Right = R({ 0.6, 0.75, 0.3 }, { 0.05, 0.7, 0.75 }, { -0.05, -0.35, 1 }),
					Left = GUARD_L,
				},
			},
			{
				at = "contact",
				ease = "out",
				pose = {
					UpperTorso = { -18, 12, 0 },
					Right = R({ 0.1, -0.2, -1 }, { -0.05, -0.65, -0.8 }, { -0.15, -0.55, -0.8 }),
					Left = BACK_L,
				},
			},
			{
				at = "follow",
				pose = {
					UpperTorso = { -22, 22, 0 },
					Right = R({ 0, -0.75, -0.6 }, { -0.15, -0.95, 0.1 }, { -0.25, -0.8, 0.5 }),
					Left = BACK_L,
				},
			},
			{
				at = "cycle",
				pose = {
					UpperTorso = { -6, 10, 0 },
					Right = R({ 0.05, -1, -0.25 }, { -0.1, -0.5, -1 }, { -0.1, 0.5, -1 }),
					Left = CARRY_L,
				},
			},
			{ at = "length", pose = ONE },
		},
	},
	["axe.light2"] = { -- backhand sweep, left to right at the chest
		keys = {
			{ at = 0, pose = { UpperTorso = { -6, 10, 0 }, Right = CARRY_R, Left = CARRY_L } },
			{
				at = "prep",
				pose = {
					UpperTorso = { 0, 24, 0 },
					Right = R({ -0.3, -0.5, -0.8 }, { -0.85, 0.15, -0.45 }, { -0.85, 0.35, 0.35 }),
					Left = TUCK_L,
				},
			},
			{
				at = "windup",
				ease = "in",
				pose = {
					UpperTorso = { 4, 52, 0 },
					Right = R({ -0.5, -0.05, -0.85 }, { -0.85, 0.35, 0.3 }, { -0.1, 0.35, 1 }),
					Left = TUCK_L,
				},
			},
			{
				at = "contact",
				ease = "out",
				pose = {
					UpperTorso = { -8, -12, 0 },
					Right = R({ 0.3, -0.1, -1 }, { 0.55, -0.15, -0.85 }, { 0.85, -0.2, -0.5 }),
					Left = BACK_L,
				},
			},
			{
				at = "follow",
				pose = {
					UpperTorso = { -8, -40, 0 },
					Right = R({ 0.9, -0.25, -0.1 }, { 0.8, -0.2, 0.55 }, { 0.2, -0.25, 1 }),
					Left = GUARD_L,
				},
			},
			{
				at = "cycle",
				pose = {
					UpperTorso = { 0, -12, 0 },
					Right = R({ 0.4, -0.85, -0.1 }, { 0.25, -0.35, -0.9 }, { 0.15, 0.6, -0.8 }),
					Left = CARRY_L,
				},
			},
			{ at = "length", pose = ONE },
		},
	},
	["axe.heavy"] = { -- charged two-handed overhead chop
		keys = {
			{ at = 0, pose = with(ONE, STAND) },
			{
				at = 0.16,
				pose = with({
					UpperTorso = { 6, -10, 0 },
					Right = R({ 0.3, 0.6, -0.4 }, { 0.05, 1, 0.1 }, { 0, 0.75, 0.65 }),
					Left = GRIP(-0.35),
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 16, -14, 0 },
					Head = { -10, 8, 0 },
					Right = R({ 0.25, 0.95, 0.15 }, { 0, 0.45, 0.9 }, { 0, -0.55, 1 }),
					Left = GRIP(-0.35),
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -32, 6, 0 },
					Right = R({ 0.1, -0.35, -1 }, { 0, -0.85, -0.55 }, { 0, -0.8, -0.6 }),
					Left = GRIP(-0.35),
				}, LUNGE),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -38, 8, 0 },
					Right = R({ 0.05, -0.8, -0.6 }, { 0, -1, 0.15 }, { 0, -0.6, 0.6 }),
					Left = GRIP(-0.35),
				}, LUNGE),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -10, 6, 0 },
					Right = R({ 0.1, -1, -0.25 }, { 0, -0.55, -0.9 }, { 0, 0.45, -1 }),
					Left = CARRY_L,
				}, READY),
			},
			{ at = "length", pose = with(ONE, STAND) },
		},
	},

	-- Pick (picks) --------------------------------------------------------------------------------
	["pick.light1"] = { -- overhead strike, straight down the middle
		keys = {
			{ at = 0, pose = ONE },
			{
				at = "prep",
				pose = {
					UpperTorso = { 4, -6, 0 },
					Right = R({ 0.4, -0.3, 0.2 }, { 0.2, 0.8, 0 }, { 0.05, 0.85, 0.55 }),
					Left = CARRY_L,
				},
			},
			{
				at = "windup",
				ease = "in",
				pose = {
					UpperTorso = { 14, -12, 0 },
					Right = R({ 0.3, 0.95, 0.15 }, { 0, 0.45, 0.9 }, { 0, -0.45, 1 }),
					Left = GUARD_L,
				},
			},
			{
				at = "contact",
				ease = "out",
				pose = {
					UpperTorso = { -24, 6, 0 },
					Right = R({ 0.15, -0.25, -1 }, { 0.05, -0.8, -0.65 }, { 0, -0.65, -0.75 }),
					Left = BACK_L,
				},
			},
			{
				at = "follow",
				pose = {
					UpperTorso = { -28, 8, 0 },
					Right = R({ 0.1, -0.75, -0.65 }, { 0, -1, 0 }, { 0, -0.75, 0.55 }),
					Left = BACK_L,
				},
			},
			{
				at = "cycle",
				pose = {
					UpperTorso = { -6, 4, 0 },
					Right = R({ 0.1, -1, -0.25 }, { 0, -0.5, -1 }, { 0, 0.5, -1 }),
					Left = CARRY_L,
				},
			},
			{ at = "length", pose = ONE },
		},
	},
	["pick.light2"] = { -- a side strike from the right, rising across
		keys = {
			{ at = 0, pose = ONE },
			{
				at = "prep",
				pose = {
					UpperTorso = { 0, -16, 0 },
					Right = R({ 0.75, -0.55, 0.3 }, { 0.6, 0.3, 0.5 }, { 0.4, 0.6, 0.7 }),
					Left = CARRY_L,
				},
			},
			{
				at = "windup",
				ease = "in",
				pose = {
					UpperTorso = { 2, -44, 0 },
					Right = R({ 0.9, -0.1, 0.45 }, { 0.45, 0.45, 0.8 }, { 0.2, -0.1, 1 }),
					Left = GUARD_L,
				},
			},
			{
				at = "contact",
				ease = "out",
				pose = {
					UpperTorso = { -10, 18, 0 },
					Right = R({ 0.1, -0.1, -1 }, { -0.3, -0.2, -1 }, { -0.8, -0.1, -0.55 }),
					Left = BACK_L,
				},
			},
			{
				at = "follow",
				pose = {
					UpperTorso = { -12, 40, 0 },
					Right = R({ -0.45, -0.55, -0.7 }, { -0.9, -0.3, 0 }, { -0.5, -0.3, 0.8 }),
					Left = BACK_L,
				},
			},
			{
				at = "cycle",
				pose = {
					UpperTorso = { -4, 12, 0 },
					Right = R({ 0, -1, -0.3 }, { -0.25, -0.55, -0.85 }, { -0.3, 0.45, -1 }),
					Left = CARRY_L,
				},
			},
			{ at = "length", pose = ONE },
		},
	},
	["pick.heavy"] = { -- charged two-handed overhead, all the weight behind it
		keys = {
			{ at = 0, pose = with(ONE, STAND) },
			{
				at = 0.16,
				pose = with({
					UpperTorso = { 8, -8, 0 },
					Right = R({ 0.3, 0.65, -0.35 }, { 0.05, 1, 0.1 }, { 0, 0.8, 0.6 }),
					Left = GRIP(-0.4),
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 20, -10, 0 },
					Head = { -12, 6, 0 },
					Right = R({ 0.2, 1, 0.2 }, { 0, 0.35, 0.95 }, { 0, -0.7, 0.9 }),
					Left = GRIP(-0.4),
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -36, 4, 0 },
					Right = R({ 0.1, -0.4, -1 }, { 0, -0.9, -0.45 }, { 0, -0.85, -0.5 }),
					Left = GRIP(-0.4),
				}, LUNGE),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -40, 6, 0 },
					Right = R({ 0.05, -0.85, -0.55 }, { 0, -1, 0.2 }, { 0, -0.65, 0.55 }),
					Left = GRIP(-0.4),
				}, LUNGE),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -10, 4, 0 },
					Right = R({ 0.1, -1, -0.25 }, { 0, -0.55, -0.9 }, { 0, 0.45, -1 }),
					Left = CARRY_L,
				}, READY),
			},
			{ at = "length", pose = with(ONE, STAND) },
		},
	},

	-- Blunt (Spiked Club, Tire Iron) ---------------------------------------------------------------
	["blunt.light1"] = { -- forehand: a flat swing, right to left at head height
		keys = {
			{ at = 0, pose = ONE },
			{
				at = "prep",
				pose = {
					UpperTorso = { 0, -14, 0 },
					Right = R({ 0.75, -0.6, 0.15 }, { 0.6, 0.3, 0.3 }, { 0.3, 0.75, 0.6 }),
					Left = CARRY_L,
				},
			},
			{
				at = "windup",
				ease = "in",
				pose = {
					UpperTorso = { 2, -46, 0 },
					Right = R({ 0.9, 0.05, 0.45 }, { 0.35, 0.55, 0.75 }, { -0.1, 0.35, 1 }),
					Left = GUARD_L,
				},
			},
			{
				at = "contact",
				ease = "out",
				pose = {
					UpperTorso = { -6, 18, 0 },
					Right = R({ 0.05, 0.05, -1 }, { -0.35, 0.05, -1 }, { -0.85, 0.15, -0.5 }),
					Left = BACK_L,
				},
			},
			{
				at = "follow",
				pose = {
					UpperTorso = { -8, 48, 0 },
					Right = R({ -0.55, -0.45, -0.7 }, { -0.95, -0.1, 0.1 }, { -0.4, -0.05, 0.9 }),
					Left = BACK_L,
				},
			},
			{
				at = "cycle",
				pose = {
					UpperTorso = { -2, 16, 0 },
					Right = R({ -0.1, -1, -0.3 }, { -0.35, -0.5, -0.8 }, { -0.4, 0.45, -1 }),
					Left = CARRY_L,
				},
			},
			{ at = "length", pose = ONE },
		},
	},
	["blunt.light2"] = { -- backhand return, left to right
		keys = {
			{ at = 0, pose = { UpperTorso = { -2, 16, 0 }, Right = CARRY_R, Left = CARRY_L } },
			{
				at = "prep",
				pose = {
					UpperTorso = { 0, 26, 0 },
					Right = R({ -0.3, -0.45, -0.85 }, { -0.85, 0.15, -0.45 }, { -0.85, 0.35, 0.35 }),
					Left = TUCK_L,
				},
			},
			{
				at = "windup",
				ease = "in",
				pose = {
					UpperTorso = { 2, 50, 0 },
					Right = R({ -0.5, 0.05, -0.85 }, { -0.85, 0.35, 0.3 }, { -0.15, 0.4, 1 }),
					Left = TUCK_L,
				},
			},
			{
				at = "contact",
				ease = "out",
				pose = {
					UpperTorso = { -6, -14, 0 },
					Right = R({ 0.3, 0, -1 }, { 0.6, 0, -0.85 }, { 0.9, 0.05, -0.45 }),
					Left = BACK_L,
				},
			},
			{
				at = "follow",
				pose = {
					UpperTorso = { -6, -44, 0 },
					Right = R({ 0.9, -0.2, -0.1 }, { 0.8, -0.05, 0.55 }, { 0.2, 0, 1 }),
					Left = GUARD_L,
				},
			},
			{
				at = "cycle",
				pose = {
					UpperTorso = { 0, -14, 0 },
					Right = R({ 0.45, -0.85, -0.1 }, { 0.3, -0.35, -0.9 }, { 0.15, 0.6, -0.8 }),
					Left = CARRY_L,
				},
			},
			{ at = "length", pose = ONE },
		},
	},
	["blunt.light3"] = { -- the finisher: an overhead smash with a step
		keys = {
			{ at = 0, pose = with(ONE, STAND) },
			{
				at = "prep",
				pose = with({
					UpperTorso = { 6, -8, 0 },
					Right = R({ 0.4, 0.2, 0.2 }, { 0.15, 1, 0 }, { 0.05, 0.7, 0.7 }),
					Left = CARRY_L,
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 16, -16, 0 },
					Head = { -8, 6, 0 },
					Right = R({ 0.3, 0.95, 0.15 }, { 0, 0.45, 0.9 }, { 0, -0.5, 1 }),
					Left = GUARD_L,
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -28, 8, 0 },
					Right = R({ 0.15, -0.3, -1 }, { 0.05, -0.8, -0.6 }, { 0, -0.7, -0.7 }),
					Left = BACK_L,
				}, LUNGE),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -32, 12, 0 },
					Right = R({ 0.1, -0.8, -0.6 }, { 0, -1, 0.1 }, { -0.05, -0.75, 0.6 }),
					Left = BACK_L,
				}, LUNGE),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -8, 6, 0 },
					Right = R({ 0.1, -1, -0.25 }, { 0, -0.55, -0.9 }, { 0, 0.45, -1 }),
					Left = CARRY_L,
				}, READY),
			},
			{ at = "length", pose = with(ONE, STAND) },
		},
	},
	["blunt.heavy"] = { -- charged two-handed swing, the whole body unwinding through it
		keys = {
			{ at = 0, pose = with(ONE, STAND) },
			{
				at = 0.16,
				pose = with({
					UpperTorso = { 2, -30, 0 },
					Right = R({ 0.6, -0.3, 0.2 }, { 0.2, 0.8, 0.3 }, { -0.1, 0.9, 0.4 }),
					Left = GRIP(-0.3),
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 6, -62, 0 },
					Head = { 0, 40, 0 },
					Right = R({ 0.85, 0.05, 0.5 }, { 0.15, 0.85, 0.55 }, { -0.35, 0.3, 1 }),
					Left = GRIP(-0.3),
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -10, 22, 0 },
					Right = R({ 0.1, -0.15, -1 }, { -0.35, -0.05, -1 }, { -0.85, 0.05, -0.5 }),
					Left = GRIP(-0.3),
				}, LUNGE),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -10, 70, 0 },
					Right = R({ -0.6, -0.35, -0.7 }, { -0.95, 0.2, 0.15 }, { -0.2, 0.55, 0.8 }),
					Left = GRIP(-0.3),
				}, LUNGE),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -4, 20, 0 },
					Right = R({ -0.05, -1, -0.3 }, { -0.3, -0.55, -0.8 }, { -0.35, 0.45, -1 }),
					Left = CARRY_L,
				}, READY),
			},
			{ at = "length", pose = with(ONE, STAND) },
		},
	},

	-- Heavy two-handed (Rail Mallet) ---------------------------------------------------------------
	["heavy.light1"] = { -- a diagonal slam, high right to low front
		keys = {
			{ at = 0, pose = with(TWO, STAND) },
			{
				at = "prep",
				pose = with({
					UpperTorso = { 4, -14, 0 },
					Right = R({ 0.5, -0.5, 0.1 }, { 0.2, 0.6, -0.4 }, { -0.05, 0.95, 0.35 }),
					Left = GRIP(-0.55),
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 14, -40, 0 },
					Head = { -6, 20, 0 },
					Right = R({ 0.7, 0.55, 0.3 }, { 0.1, 0.75, 0.65 }, { -0.25, -0.15, 1 }),
					Left = GRIP(-0.55),
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -30, 18, 0 },
					Right = R({ 0.1, -0.4, -1 }, { -0.2, -0.75, -0.65 }, { -0.35, -0.75, -0.55 }),
					Left = GRIP(-0.55),
				}, LUNGE),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -34, 26, 0 },
					Right = R({ -0.05, -0.8, -0.6 }, { -0.35, -0.95, 0.05 }, { -0.4, -0.75, 0.35 }),
					Left = GRIP(-0.55),
				}, LUNGE),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -10, 10, 0 },
					Right = CARRY2_R,
					Left = GRIP(-0.55),
				}, READY),
			},
			{ at = "length", pose = with(TWO, STAND) },
		},
	},
	["heavy.light2"] = { -- a waist-high sweep, right to left
		keys = {
			{ at = 0, pose = with(TWO, STAND) },
			{
				at = "prep",
				pose = with({
					UpperTorso = { 0, -22, 0 },
					Right = R({ 0.6, -0.75, 0.2 }, { 0.3, -0.1, 0.9 }, { 0.15, 0.15, 1 }),
					Left = GRIP(-0.55),
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 4, -58, 0 },
					Head = { 0, 34, 0 },
					Right = R({ 0.85, -0.4, 0.4 }, { 0.35, 0.05, 0.95 }, { -0.25, 0, 1 }),
					Left = GRIP(-0.55),
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -12, 20, 0 },
					Right = R({ 0.15, -0.55, -1 }, { -0.35, -0.3, -1 }, { -0.85, -0.2, -0.5 }),
					Left = GRIP(-0.55),
				}, LUNGE),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -12, 62, 0 },
					Right = R({ -0.55, -0.55, -0.6 }, { -0.95, -0.15, 0.2 }, { -0.25, -0.1, 1 }),
					Left = GRIP(-0.55),
				}, LUNGE),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -6, 18, 0 },
					Right = CARRY2_R,
					Left = GRIP(-0.55),
				}, READY),
			},
			{ at = "length", pose = with(TWO, STAND) },
		},
	},
	["heavy.heavy"] = { -- charged overhead ground slam
		keys = {
			{ at = 0, pose = with(TWO, STAND) },
			{
				at = 0.2,
				pose = with({
					UpperTorso = { 8, -10, 0 },
					Right = R({ 0.35, 0.5, -0.4 }, { 0.05, 1, 0 }, { -0.05, 0.85, 0.5 }),
					Left = GRIP(-0.55),
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 22, -8, 0 },
					Head = { -14, 0, 0 },
					Right = R({ 0.25, 1, 0.1 }, { 0, 0.4, 0.95 }, { 0, -0.6, 1 }),
					Left = GRIP(-0.55),
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -44, 4, 0 },
					Head = { 10, 0, 0 },
					Right = R({ 0.15, -0.5, -1 }, { 0, -0.95, -0.35 }, { 0, -0.95, -0.35 }),
					Left = GRIP(-0.55),
				}, CROUCH),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -46, 4, 0 },
					Right = R({ 0.15, -0.55, -1 }, { 0, -0.95, -0.3 }, { 0, -0.98, -0.2 }),
					Left = GRIP(-0.55),
				}, CROUCH),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -14, 4, 0 },
					Right = CARRY2_R,
					Left = GRIP(-0.55),
				}, READY),
			},
			{ at = "length", pose = with(TWO, STAND) },
		},
	},

	-- Stab (Sharpened Stake): a two-handed spear grip ------------------------------------------------
	["stab.light1"] = { -- a quick thrust from the hip
		keys = {
			{ at = 0, pose = SPEAR },
			{
				at = "prep",
				pose = {
					UpperTorso = { 0, -10, 0 },
					Right = R({ 0.35, -0.95, 0.55 }, { 0.1, -0.3, -1 }, { -0.1, 0, -1 }),
					Left = GRIP(-0.85),
				},
			},
			{
				at = "windup",
				ease = "in",
				pose = {
					UpperTorso = { 2, -30, 0 },
					Right = R({ 0.3, -0.45, 1 }, { 0.15, -0.85, -0.25 }, { -0.08, 0.02, -1 }),
					Left = GRIP(-0.85),
				},
			},
			{
				at = "contact",
				ease = "out",
				pose = {
					UpperTorso = { -10, 18, 0 },
					Right = R({ 0.1, -0.25, -1 }, { -0.05, -0.05, -1 }, { -0.06, 0, -1 }),
					Left = GRIP(-0.85),
				},
			},
			{
				at = "follow",
				pose = {
					UpperTorso = { -12, 22, 0 },
					Right = R({ 0.08, -0.2, -1 }, { -0.05, -0.02, -1 }, { -0.06, -0.04, -1 }),
					Left = GRIP(-0.85),
				},
			},
			{
				at = "cycle",
				pose = {
					UpperTorso = { -2, 4, 0 },
					Right = SPEAR_R,
					Left = GRIP(-0.85),
				},
			},
			{ at = "length", pose = SPEAR },
		},
	},
	["stab.light2"] = { -- a second thrust, higher, at the head
		keys = {
			{ at = 0, pose = { UpperTorso = { -2, 4, 0 }, Right = SPEAR_R, Left = GRIP(-0.85) } },
			{
				at = "prep",
				pose = {
					UpperTorso = { 2, -12, 0 },
					Right = R({ 0.4, -0.85, 0.6 }, { 0.15, -0.1, -1 }, { -0.1, 0.12, -1 }),
					Left = GRIP(-0.85),
				},
			},
			{
				at = "windup",
				ease = "in",
				pose = {
					UpperTorso = { 4, -32, 0 },
					Right = R({ 0.35, -0.35, 1 }, { 0.2, -0.7, -0.35 }, { -0.08, 0.18, -1 }),
					Left = GRIP(-0.85),
				},
			},
			{
				at = "contact",
				ease = "out",
				pose = {
					UpperTorso = { -6, 22, 0 },
					Right = R({ 0.1, 0.05, -1 }, { -0.05, 0.15, -1 }, { -0.05, 0.14, -1 }),
					Left = GRIP(-0.85),
				},
			},
			{
				at = "follow",
				pose = {
					UpperTorso = { -8, 26, 0 },
					Right = R({ 0.08, 0.08, -1 }, { -0.05, 0.12, -1 }, { -0.05, 0.1, -1 }),
					Left = GRIP(-0.85),
				},
			},
			{
				at = "cycle",
				pose = {
					UpperTorso = { -2, 4, 0 },
					Right = SPEAR_R,
					Left = GRIP(-0.85),
				},
			},
			{ at = "length", pose = SPEAR },
		},
	},
	["stab.light3"] = { -- the finisher: a lunging thrust
		keys = {
			{ at = 0, pose = with(SPEAR, STAND) },
			{
				at = "prep",
				pose = with({
					UpperTorso = { 0, -12, 0 },
					Right = R({ 0.35, -0.95, 0.6 }, { 0.1, -0.3, -1 }, { -0.1, 0, -1 }),
					Left = GRIP(-0.85),
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 6, -40, 0 },
					Right = R({ 0.3, -0.35, 1 }, { 0.2, -0.85, -0.2 }, { -0.08, 0.02, -1 }),
					Left = GRIP(-0.85),
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -20, 24, 0 },
					Right = R({ 0.05, -0.2, -1 }, { -0.05, -0.05, -1 }, { -0.05, -0.03, -1 }),
					Left = GRIP(-0.85),
				}, LUNGE),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -22, 26, 0 },
					Right = R({ 0.05, -0.18, -1 }, { -0.05, -0.04, -1 }, { -0.05, -0.05, -1 }),
					Left = GRIP(-0.85),
				}, LUNGE),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -6, 6, 0 },
					Right = SPEAR_R,
					Left = GRIP(-0.85),
				}, READY),
			},
			{ at = "length", pose = with(SPEAR, STAND) },
		},
	},
	["stab.heavy"] = { -- charged: coiled deep with the stake drawn back, then a driving lunge
		keys = {
			{ at = 0, pose = with(SPEAR, STAND) },
			{
				at = 0.16,
				pose = with({
					UpperTorso = { 2, -24, 0 },
					Right = R({ 0.4, -0.8, 0.75 }, { 0.15, -0.15, -1 }, { -0.1, 0.05, -1 }),
					Left = GRIP(-0.85),
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 8, -55, 0 },
					Head = { 0, 40, 0 },
					Right = R({ 0.25, -0.2, 1 }, { 0.25, -0.9, 0.05 }, { -0.05, 0.08, -1 }),
					Left = GRIP(-0.85),
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -24, 28, 0 },
					Head = { 6, -16, 0 },
					Right = R({ 0.05, -0.15, -1 }, { -0.05, -0.02, -1 }, { -0.04, -0.02, -1 }),
					Left = GRIP(-0.85),
				}, LUNGE),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -26, 30, 0 },
					Right = R({ 0.05, -0.12, -1 }, { -0.05, -0.02, -1 }, { -0.04, -0.06, -1 }),
					Left = GRIP(-0.85),
				}, LUNGE),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -8, 6, 0 },
					Right = SPEAR_R,
					Left = GRIP(-0.85),
				}, READY),
			},
			{ at = "length", pose = with(SPEAR, STAND) },
		},
	},

	-- Fists: UAL's jab (left) and cross (right); the haymaker is hand-keyed ------------------------
	["fists.light1"] = {
		ual = {
			clip = "Punch_Jab",
			map = { { 0.133, "windup" }, { 0.2, "contact" }, { 0.333, "follow" }, { 0.667, "cycle" } },
			legs = true,
		},
	},
	["fists.light2"] = {
		ual = {
			clip = "Punch_Cross",
			map = { { 0.133, "windup" }, { 0.267, "contact" }, { 0.4, "follow" }, { 0.8, "cycle" } },
			legs = true,
		},
	},
	["fists.heavy"] = { -- a wound-up right haymaker
		keys = {
			{ at = 0, pose = with({ Right = L({ 0.2, -1, 0 }, { 0.1, -0.6, -0.8 }), Left = CARRY_L }, STAND) },
			{
				at = 0.12,
				pose = with({
					UpperTorso = { 0, -24, 0 },
					Right = L({ 0.5, -0.5, 0.5 }, { 0.1, 0.6, -0.6 }),
					Left = L({ -0.3, -0.6, -0.8 }, { 0, 0.7, -0.6 }),
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 4, -50, 0 },
					Head = { 0, 34, 0 },
					Right = L({ 0.75, -0.1, 0.65 }, { 0.05, 0.6, -0.8 }),
					Left = L({ -0.3, -0.5, -0.9 }, { 0.1, 0.75, -0.6 }),
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -12, 30, 0 },
					Head = { 4, -10, 0 },
					Right = L({ 0.05, 0.05, -1 }, { -0.55, 0.1, -0.85 }),
					Left = L({ -0.5, -0.8, 0.3 }, { 0.2, 0.6, -0.4 }),
				}, LUNGE),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -14, 46, 0 },
					Right = L({ -0.4, -0.2, -0.9 }, { -0.9, 0, -0.3 }),
					Left = L({ -0.5, -0.8, 0.3 }, { 0.2, 0.6, -0.4 }),
				}, LUNGE),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -4, 12, 0 },
					Right = L({ 0.2, -1, -0.1 }, { 0, -0.5, -0.9 }),
					Left = CARRY_L,
				}, READY),
			},
			{ at = "length", pose = with({ Right = L({ 0.2, -1, 0 }, { 0.1, -0.6, -0.8 }), Left = CARRY_L }, STAND) },
		},
	},

	-- Gathering ---------------------------------------------------------------------------------
	["gather.chop"] = { -- a flat forehand into a trunk at chest height, the axe biting and stopping
		keys = {
			{ at = 0, pose = with(ONE, STAND) },
			{
				at = 0.1,
				pose = with({
					UpperTorso = { 2, -20, 0 },
					Right = R({ 0.75, -0.45, 0.3 }, { 0.5, 0.45, 0.4 }, { 0.2, 0.7, 0.7 }),
					Left = CARRY_L,
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 4, -50, 0 },
					Head = { 0, 30, 0 },
					Right = R({ 0.9, 0.2, 0.4 }, { 0.25, 0.65, 0.7 }, { -0.15, 0.2, 1 }),
					Left = GUARD_L,
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -10, 6, 0 },
					Right = R({ 0.15, -0.2, -1 }, { -0.2, -0.2, -1 }, { -0.75, -0.2, -0.6 }),
					Left = BACK_L,
				}, READY),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -10, 2, 0 },
					Right = R({ 0.2, -0.25, -1 }, { -0.1, -0.25, -1 }, { -0.7, -0.15, -0.7 }),
					Left = BACK_L,
				}, READY),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -2, -8, 0 },
					Right = R({ 0.4, -0.8, -0.2 }, { 0.3, -0.2, -0.95 }, { 0.2, 0.5, -0.85 }),
					Left = CARRY_L,
				}, READY),
			},
			{ at = "length", pose = with(ONE, STAND) },
		},
	},
	["gather.mine"] = { -- overhead, down onto a rock at knee height
		keys = {
			{ at = 0, pose = with(ONE, STAND) },
			{
				at = 0.1,
				pose = with({
					UpperTorso = { 6, -8, 0 },
					Right = R({ 0.4, -0.2, 0.2 }, { 0.2, 0.85, 0 }, { 0.05, 0.85, 0.55 }),
					Left = CARRY_L,
				}, READY),
			},
			{
				at = "windup",
				ease = "in",
				pose = with({
					UpperTorso = { 16, -14, 0 },
					Head = { -8, 4, 0 },
					Right = R({ 0.3, 0.95, 0.15 }, { 0, 0.45, 0.9 }, { 0, -0.4, 1 }),
					Left = GRIP(-0.35),
				}, COIL),
			},
			{
				at = "contact",
				ease = "out",
				pose = with({
					UpperTorso = { -40, 6, 0 },
					Head = { 14, 0, 0 },
					Right = R({ 0.15, -0.55, -1 }, { 0.05, -0.95, -0.35 }, { 0, -0.95, -0.3 }),
					Left = GRIP(-0.35),
				}, CROUCH),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -36, 6, 0 },
					Right = R({ 0.15, -0.5, -1 }, { 0.05, -0.9, -0.45 }, { 0, -0.85, -0.5 }),
					Left = GRIP(-0.35),
				}, CROUCH),
			},
			{
				at = "cycle",
				pose = with({
					UpperTorso = { -8, 2, 0 },
					Right = R({ 0.2, -0.9, -0.2 }, { 0.05, -0.2, -1 }, { 0, 0.6, -0.8 }),
					Left = CARRY_L,
				}, READY),
			},
			{ at = "length", pose = with(ONE, STAND) },
		},
	},
	["gather.pickup"] = { -- crouch, reach to the ground, grab and stand
		keys = {
			{ at = 0, pose = with(ONE, STAND) },
			{
				at = "windup",
				ease = "inOut",
				pose = with({
					UpperTorso = { -38, 0, 0 },
					Head = { 18, 0, 0 },
					Right = R({ 0.2, -0.75, -0.65 }, { 0.05, -0.9, -0.45 }, { 0, -0.2, -1 }),
					Left = L({ -0.4, -0.85, -0.2 }, { -0.2, -0.6, -0.8 }),
				}, CROUCH),
			},
			{
				at = "contact",
				ease = "inOut",
				pose = with({
					UpperTorso = { -42, 0, 0 },
					Head = { 20, 0, 0 },
					Right = R({ 0.15, -0.85, -0.5 }, { 0.05, -0.98, -0.2 }, { 0, -0.5, -0.9 }),
					Left = L({ -0.4, -0.85, -0.2 }, { -0.2, -0.6, -0.8 }),
				}, CROUCH),
			},
			{
				at = "follow",
				pose = with({
					UpperTorso = { -20, 0, 0 },
					Right = R({ 0.2, -0.6, -0.6 }, { 0, 0.5, -0.9 }, { 0, 0.6, -0.8 }),
					Left = CARRY_L,
				}, READY),
			},
			{ at = "cycle", pose = with(ONE, STAND) },
			{ at = "length", pose = with(ONE, STAND) },
		},
	},

	-- Survivor actions ----------------------------------------------------------------------------
	["use.eat"] = { -- the hand to the mouth twice
		keys = {
			{ at = 0, pose = ONE },
			{
				at = "windup",
				pose = { Head = { -6, 0, 0 }, Right = L({ 0.3, -0.6, -0.75 }, { -0.4, 0.85, -0.3 }), Left = CARRY_L },
			},
			{
				at = "contact",
				pose = { Head = { -10, 0, 0 }, Right = L({ 0.25, -0.55, -0.8 }, { -0.5, 0.85, -0.15 }), Left = CARRY_L },
			},
			{
				at = 0.5,
				pose = { Head = { 2, 0, 0 }, Right = L({ 0.3, -0.75, -0.6 }, { -0.25, 0.6, -0.75 }), Left = CARRY_L },
			},
			{
				at = "follow",
				pose = { Head = { -10, 0, 0 }, Right = L({ 0.25, -0.55, -0.8 }, { -0.5, 0.85, -0.15 }), Left = CARRY_L },
			},
			{ at = "cycle", pose = ONE },
			{ at = "length", pose = ONE },
		},
	},
	["use.drink"] = { -- raise the bottle, tip the head back, lower it
		keys = {
			{ at = 0, pose = ONE },
			{
				at = "windup",
				pose = { Right = L({ 0.3, -0.5, -0.8 }, { -0.35, 0.9, -0.2 }), Left = CARRY_L },
			},
			{
				at = "contact",
				pose = {
					UpperTorso = { 8, 0, 0 },
					Head = { 24, 0, 0 },
					Right = L({ 0.25, -0.3, -0.95 }, { -0.4, 0.9, 0.15 }),
					Left = CARRY_L,
				},
			},
			{
				at = "follow",
				pose = {
					UpperTorso = { 8, 0, 0 },
					Head = { 26, 0, 0 },
					Right = L({ 0.25, -0.25, -0.95 }, { -0.4, 0.9, 0.2 }),
					Left = CARRY_L,
				},
			},
			{ at = "cycle", pose = { Right = L({ 0.25, -0.8, -0.5 }, { 0, 0.2, -1 }), Left = CARRY_L } },
			{ at = "length", pose = ONE },
		},
	},
	["use.swap"] = { -- the hand drops to the hip and comes back up (4.9)
		keys = {
			{ at = 0, pose = ONE },
			{
				at = "windup",
				ease = "in",
				pose = {
					UpperTorso = { 0, -12, 0 },
					Right = R({ 0.3, -1, 0.35 }, { 0.15, -0.6, 0.8 }, { 0.2, -1, 0.2 }),
					Left = CARRY_L,
				},
			},
			{ at = "contact", pose = { UpperTorso = { 0, -10, 0 }, Right = R({ 0.3, -1, 0.3 }, { 0.15, -0.65, 0.75 }, { 0.2, -1, 0.1 }), Left = CARRY_L } },
			{ at = "length", pose = ONE },
		},
	},
	["react.chest"] = { ual = { clip = "Hit_Chest" } },
	["react.head"] = { ual = { clip = "Hit_Head" } },
} :: { [string]: MoveSpec }

return MeleePoses
