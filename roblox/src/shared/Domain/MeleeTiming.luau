--!strict
--[[
	MeleeTiming: the timing of every melee swing, gathering swing and survivor action
	(checklist 13.4). Pure and shared: the client animates from it and the server lands
	damage and gathering hits on its contact frame, validating requests against it.

	Each weapon class has a light combo of 2-3 swings and a heavy attack. Every move has
	marks, in seconds at play rate 1 (Data/MeleePoses keys its poses on them):
	- prep: a pressed button holds the swing here (a small cock) until it is released.
	- windup: the anticipation peak; a charged heavy holds here while the button is held.
	- contact: the hit frame. Damage, hit-stop, sparks and the impact sound fire here.
	- follow: the end of the follow-through.
	- cycle: the recovery reaches the point where the next swing may start.
	- length: the settle back to the carry pose ends; a combo continues until then.

	A swing's server clock starts at its anchor: `prep` for a light swing (the release),
	`windup` for a charged heavy, 0 for an uncharged one (AUTO). The play rate makes the
	anchor-to-cycle span equal one attack at the weapon's attacksPerSecond, so the damage
	per second stays what Data/Items says; combos and heavies change the feel, not the
	cadence. Light combo steps do the weapon's damage; heavies use Tuning.melee.

	Classes (Data/Items ids; tools fall back by kind):
	blade (Scrapblade, Machete), axe (hatchets, Fire Axe), pick (picks), blunt (Spiked Club,
	Tire Iron), heavy (Rail Mallet), stab (Sharpened Stake), fists (empty hands).
]]

local MeleeTiming = {}

export type ClassId = "blade" | "axe" | "pick" | "blunt" | "heavy" | "stab" | "fists"
export type Trail = "slash" | "smash" | "thrust" | "none"

export type Marks = {
	prep: number,
	windup: number,
	contact: number,
	follow: number,
	cycle: number,
	length: number,
}

export type Move = {
	id: string,
	marks: Marks,
	heavy: boolean,
	arcDegrees: number?, -- overrides the weapon's arc (a stab is narrow)
	reachBonus: number?, -- studs on top of the weapon's range
	knockbackScale: number?, -- a finisher shoves harder
	lunge: number?, -- studs the survivor steps in on the strike (client only)
	trail: Trail,
	shake: number?, -- camera shake on a landed hit, studs
}

export type Class = { id: ClassId, light: { string }, heavy: string }

-- Seconds of input slack: a request this early is queued, not refused (network jitter).
MeleeTiming.EARLY_SECONDS = 0.15
-- A combo keeps going if the next swing starts within this after the last one settles.
MeleeTiming.CHAIN_GRACE = 0.3
-- Play rates stay within this, so a very fast or slow weapon still reads.
MeleeTiming.MIN_RATE = 0.7
MeleeTiming.MAX_RATE = 1.45
-- A heavy counts as charged when the hold reached at least this share of its windup.
MeleeTiming.CHARGE_SHARE = 0.75
-- Gathering: a landing (Gather) may arrive this much before or after the swing's contact.
MeleeTiming.LANDING_EARLY = 0.2
MeleeTiming.LANDING_LATE = 2

local function marks(prep: number, windup: number, contact: number, follow: number, cycle: number, length: number): Marks
	return { prep = prep, windup = windup, contact = contact, follow = follow, cycle = cycle, length = length }
end

local function move(id: string, m: Marks, trail: Trail, extra: { [string]: any }?): Move
	local made: any = { id = id, marks = m, heavy = string.find(id, "%.heavy$") ~= nil, trail = trail }
	if extra then
		for key, value in extra do
			made[key] = value
		end
	end
	return made :: Move
end

--[[
	The timing tables. Strikes take 0.07-0.16 s from the anticipation peak to contact;
	follow-throughs 0.08-0.2 s; recovery runs to `cycle` and settles by `length`.
]]
MeleeTiming.MOVES = {
	-- One-handed blade: a forehand diagonal, a backhand return, an overhead cleave.
	["blade.light1"] = move("blade.light1", marks(0.06, 0.17, 0.25, 0.37, 0.66, 0.92), "slash"),
	["blade.light2"] = move("blade.light2", marks(0.05, 0.15, 0.23, 0.35, 0.64, 0.9), "slash"),
	["blade.light3"] = move(
		"blade.light3",
		marks(0.06, 0.22, 0.31, 0.45, 0.74, 1.02),
		"slash",
		{ knockbackScale = 1.5, lunge = 0.8 }
	),
	["blade.heavy"] = move(
		"blade.heavy",
		marks(0, 0.32, 0.44, 0.62, 0.92, 1.2),
		"slash",
		{ lunge = 1.2, shake = 0.22 }
	),
	-- Axe: a forehand chop, a backhand sweep; heavy is a two-handed overhead chop.
	["axe.light1"] = move("axe.light1", marks(0.07, 0.24, 0.34, 0.46, 0.86, 1.12), "smash"),
	["axe.light2"] = move("axe.light2", marks(0.06, 0.22, 0.32, 0.44, 0.84, 1.1), "smash"),
	["axe.heavy"] = move(
		"axe.heavy",
		marks(0, 0.36, 0.5, 0.66, 1.02, 1.32),
		"smash",
		{ lunge = 1, shake = 0.25, arcDegrees = 70 }
	),
	-- Pick: an overhead strike, a side strike; heavy is a two-handed overhead.
	["pick.light1"] = move("pick.light1", marks(0.07, 0.24, 0.35, 0.46, 0.86, 1.1), "smash", { arcDegrees = 70 }),
	["pick.light2"] = move("pick.light2", marks(0.06, 0.22, 0.32, 0.44, 0.84, 1.1), "smash"),
	["pick.heavy"] = move(
		"pick.heavy",
		marks(0, 0.38, 0.52, 0.68, 1.04, 1.34),
		"smash",
		{ lunge = 0.8, shake = 0.25, arcDegrees = 60 }
	),
	-- Blunt: a forehand swing, a backhand return, an overhead smash; heavy is a big
	-- two-handed horizontal swing.
	["blunt.light1"] = move("blunt.light1", marks(0.07, 0.2, 0.3, 0.42, 0.78, 1.04), "smash"),
	["blunt.light2"] = move("blunt.light2", marks(0.06, 0.18, 0.28, 0.4, 0.76, 1.02), "smash"),
	["blunt.light3"] = move(
		"blunt.light3",
		marks(0.07, 0.26, 0.36, 0.48, 0.86, 1.12),
		"smash",
		{ knockbackScale = 1.5, arcDegrees = 70 }
	),
	["blunt.heavy"] = move(
		"blunt.heavy",
		marks(0, 0.36, 0.5, 0.7, 1.0, 1.3),
		"smash",
		{ lunge = 0.8, shake = 0.25, arcDegrees = 140 }
	),
	-- Heavy two-handed (mallet): a diagonal slam, a sweep; heavy is an overhead ground slam.
	["heavy.light1"] = move("heavy.light1", marks(0.08, 0.34, 0.48, 0.62, 1.08, 1.38), "smash", { shake = 0.1 }),
	["heavy.light2"] = move(
		"heavy.light2",
		marks(0.08, 0.3, 0.44, 0.6, 1.04, 1.34),
		"smash",
		{ shake = 0.1, arcDegrees = 130 }
	),
	["heavy.heavy"] = move(
		"heavy.heavy",
		marks(0, 0.46, 0.62, 0.8, 1.3, 1.6),
		"smash",
		{ lunge = 0.6, shake = 0.35, arcDegrees = 110 }
	),
	-- Stab (stake): two quick thrusts and a lunging thrust; heavy is a charged lunge.
	["stab.light1"] = move(
		"stab.light1",
		marks(0.06, 0.16, 0.23, 0.32, 0.72, 0.96),
		"thrust",
		{ arcDegrees = 40, reachBonus = 1 }
	),
	["stab.light2"] = move(
		"stab.light2",
		marks(0.05, 0.15, 0.22, 0.31, 0.7, 0.94),
		"thrust",
		{ arcDegrees = 40, reachBonus = 1 }
	),
	["stab.light3"] = move(
		"stab.light3",
		marks(0.06, 0.2, 0.29, 0.4, 0.8, 1.06),
		"thrust",
		{ arcDegrees = 40, reachBonus = 1.4, lunge = 1, knockbackScale = 1.4 }
	),
	["stab.heavy"] = move(
		"stab.heavy",
		marks(0, 0.36, 0.46, 0.62, 1.0, 1.28),
		"thrust",
		{ arcDegrees = 35, reachBonus = 1.8, lunge = 1.4, shake = 0.2 }
	),
	-- Fists: a jab and a cross; heavy is a wound-up haymaker.
	["fists.light1"] = move("fists.light1", marks(0.04, 0.1, 0.16, 0.24, 0.5, 0.72), "none"),
	["fists.light2"] = move("fists.light2", marks(0.04, 0.12, 0.19, 0.28, 0.54, 0.78), "none"),
	["fists.heavy"] = move("fists.heavy", marks(0, 0.3, 0.4, 0.52, 0.8, 1.04), "none", { shake = 0.15 }),
	-- Gathering (rate 1 at Tuning.gathering.swingSeconds = 0.8): no prep, contact is the hit.
	["gather.chop"] = move("gather.chop", marks(0, 0.24, 0.34, 0.42, 0.8, 1), "smash"),
	["gather.mine"] = move("gather.mine", marks(0, 0.26, 0.37, 0.45, 0.8, 1), "smash"),
	["gather.pickup"] = move("gather.pickup", marks(0, 0.22, 0.34, 0.46, 0.8, 0.95), "none"),
	-- Survivor actions: eating and drinking (contact is the first bite or gulp).
	["use.eat"] = move("use.eat", marks(0, 0.22, 0.36, 0.7, 1, 1.2), "none"),
	["use.drink"] = move("use.drink", marks(0, 0.25, 0.42, 0.9, 1.1, 1.3), "none"),
	-- The survivor's own hit-react (UAL Hit_Chest / Hit_Head), contact is the jolt.
	["react.chest"] = move("react.chest", marks(0, 0.02, 0.07, 0.2, 0.3, 0.33), "none"),
	["react.head"] = move("react.head", marks(0, 0.03, 0.09, 0.25, 0.4, 0.43), "none"),
	-- A quick weapon swap (4.9): the hand drops to the hip and comes back up.
	["use.swap"] = move("use.swap", marks(0, 0.14, 0.16, 0.2, 0.3, 0.32), "none"),
} :: { [string]: Move }

MeleeTiming.CLASSES = {
	blade = { id = "blade", light = { "blade.light1", "blade.light2", "blade.light3" }, heavy = "blade.heavy" },
	axe = { id = "axe", light = { "axe.light1", "axe.light2" }, heavy = "axe.heavy" },
	pick = { id = "pick", light = { "pick.light1", "pick.light2" }, heavy = "pick.heavy" },
	blunt = { id = "blunt", light = { "blunt.light1", "blunt.light2", "blunt.light3" }, heavy = "blunt.heavy" },
	heavy = { id = "heavy", light = { "heavy.light1", "heavy.light2" }, heavy = "heavy.heavy" },
	stab = { id = "stab", light = { "stab.light1", "stab.light2", "stab.light3" }, heavy = "stab.heavy" },
	fists = { id = "fists", light = { "fists.light1", "fists.light2" }, heavy = "fists.heavy" },
} :: { [ClassId]: Class }

-- Weapons by item id. Items not listed fall back by tool kind, then to blunt.
MeleeTiming.ITEM_CLASS = {
	["item.scrapblade"] = "blade",
	["item.machete"] = "blade",
	["item.stone_hatchet"] = "axe",
	["item.forged_hatchet"] = "axe",
	["item.fire_axe"] = "axe",
	["item.stone_pick"] = "pick",
	["item.forged_pick"] = "pick",
	["item.spiked_club"] = "blunt",
	["item.tire_iron"] = "blunt",
	["item.rail_mallet"] = "heavy",
	["item.sharpened_stake"] = "stab",
} :: { [string]: ClassId }

-- The gathering swing for a node's tool kind (nil: by hand).
MeleeTiming.GATHER = { hatchet = "gather.chop", pick = "gather.mine", hand = "gather.pickup" } :: { [string]: string }

export type ItemLike = { tool: { kind: string }?, weapon: { kind: string }? }

-- The class an item in hand swings as. nil or "" is bare fists.
function MeleeTiming.classOf(itemId: string?, item: ItemLike?): ClassId
	if itemId == nil or itemId == "" then
		return "fists"
	end
	local listed = MeleeTiming.ITEM_CLASS[itemId]
	if listed then
		return listed
	end
	local tool = item and item.tool
	if tool and tool.kind == "hatchet" then
		return "axe"
	elseif tool and tool.kind == "pick" then
		return "pick"
	end
	return "blunt"
end

function MeleeTiming.move(id: string): Move
	local found = MeleeTiming.MOVES[id]
	assert(found, `MeleeTiming: no move '{id}'`)
	return found
end

function MeleeTiming.marksOf(id: string): Marks
	return MeleeTiming.move(id).marks
end

function MeleeTiming.comboLength(classId: ClassId): number
	return #MeleeTiming.CLASSES[classId].light
end

-- The move for a class's light combo step (wrapping) or its heavy.
function MeleeTiming.moveFor(classId: ClassId, heavy: boolean, step: number): Move
	local class = MeleeTiming.CLASSES[classId] or MeleeTiming.CLASSES.fists
	if heavy then
		return MeleeTiming.move(class.heavy)
	end
	local count = #class.light
	local index = ((math.max(1, math.floor(step)) - 1) % count) + 1
	return MeleeTiming.move(class.light[index])
end

-- The mark a swing's server clock starts at.
export type Anchor = "start" | "prep" | "windup"

function MeleeTiming.anchorTime(m: Marks, anchor: Anchor): number
	if anchor == "prep" then
		return m.prep
	elseif anchor == "windup" then
		return m.windup
	end
	return 0
end

export type Plan = {
	rate: number, -- animation play speed
	anchor: Anchor,
	contactDelay: number, -- seconds from the anchor to the hit
	recoverDelay: number, -- seconds from the anchor until the next swing may start
	settleDelay: number, -- seconds from the anchor until the move has settled
}

-- How a move plays for a weapon with `attacksPerSecond`, counted from `anchor`.
function MeleeTiming.plan(m: Move, attacksPerSecond: number, anchor: Anchor): Plan
	local from = MeleeTiming.anchorTime(m.marks, anchor)
	-- The rate always comes from the swing's natural anchor, so an uncharged heavy plays
	-- at the same speed as a charged one (it just has its windup still to come).
	local natural = if m.heavy then m.marks.windup else m.marks.prep
	local span = m.marks.cycle - natural
	local rate = math.clamp(span * math.max(attacksPerSecond, 0.05), MeleeTiming.MIN_RATE, MeleeTiming.MAX_RATE)
	return {
		rate = rate,
		anchor = anchor,
		contactDelay = (m.marks.contact - from) / rate,
		recoverDelay = (m.marks.cycle - from) / rate,
		settleDelay = (m.marks.length - from) / rate,
	}
end

-- A gathering or action move at its own speed: cycle maps onto `cycleSeconds`.
function MeleeTiming.actionPlan(m: Move, cycleSeconds: number): Plan
	local rate = math.clamp(m.marks.cycle / math.max(cycleSeconds, 0.05), MeleeTiming.MIN_RATE, MeleeTiming.MAX_RATE)
	return {
		rate = rate,
		anchor = "start",
		contactDelay = m.marks.contact / rate,
		recoverDelay = m.marks.cycle / rate,
		settleDelay = m.marks.length / rate,
	}
end

-- Combos and the swing clock ----------------------------------------------------------------------

export type Swing = {
	classId: ClassId,
	moveId: string,
	step: number, -- light combo step (1-based); 0 for a heavy
	heavy: boolean,
	startedAt: number, -- when the anchor was reached
	contactAt: number,
	readyAt: number, -- the next swing may start
	chainUntil: number, -- a light swing starting by then continues the combo
	plan: Plan,
}

export type State = {
	last: Swing?,
	readyAt: number,
	chargeAt: number?, -- a heavy charge started here (CombatCharge)
}

function MeleeTiming.newState(): State
	return { last = nil, readyAt = -math.huge, chargeAt = nil }
end

-- The light combo step a swing starting at `now` takes.
function MeleeTiming.nextStep(last: Swing?, classId: ClassId, now: number): number
	if last == nil or last.heavy or last.classId ~= classId or now > last.chainUntil then
		return 1
	end
	return (last.step % MeleeTiming.comboLength(classId)) + 1
end

-- Whether a heavy released at `now` was charged long enough to skip its windup.
function MeleeTiming.charged(state: State, m: Move, attacksPerSecond: number, now: number): boolean
	if state.chargeAt == nil then
		return false
	end
	local full = MeleeTiming.plan(m, attacksPerSecond, "start")
	local windupSeconds = m.marks.windup / full.rate
	return now - state.chargeAt >= windupSeconds * MeleeTiming.CHARGE_SHARE
end

export type Request = {
	classId: ClassId,
	heavy: boolean,
	step: number?, -- what the client played; nil lets the clock choose
	attacksPerSecond: number,
}

export type Refusal = "cooldown"

--[[
	Starts a swing at `now` (both sides run this: the client to predict, the server to
	decide). A request up to EARLY_SECONDS before the last swing recovers is queued to
	that moment; earlier ones are refused. The combo step follows the clock; a client
	that says it restarted (step 1) restarts. Returns the swing and the new state.
]]
function MeleeTiming.begin(state: State, request: Request, now: number): (Swing?, State, Refusal?)
	if now < state.readyAt - MeleeTiming.EARLY_SECONDS then
		return nil, state, "cooldown"
	end
	local start = math.max(now, state.readyAt)
	local step = 0
	local m: Move
	local anchor: Anchor
	if request.heavy then
		m = MeleeTiming.moveFor(request.classId, true, 1)
		anchor = if MeleeTiming.charged(state, m, request.attacksPerSecond, start) then "windup" else "start"
	else
		step = MeleeTiming.nextStep(state.last, request.classId, start)
		if request.step == 1 then
			step = 1
		end
		m = MeleeTiming.moveFor(request.classId, false, step)
		anchor = "prep"
	end
	local plan = MeleeTiming.plan(m, request.attacksPerSecond, anchor)
	local swing: Swing = {
		classId = request.classId,
		moveId = m.id,
		step = step,
		heavy = request.heavy,
		startedAt = start,
		contactAt = start + plan.contactDelay,
		readyAt = start + plan.recoverDelay,
		chainUntil = start + plan.settleDelay + MeleeTiming.CHAIN_GRACE,
		plan = plan,
	}
	return swing, { last = swing, readyAt = swing.readyAt, chargeAt = nil }, nil
end

-- A heavy charge begins (the hold passed the heavy threshold). Not while a swing is still
-- recovering: the windup can't be hidden inside the last swing.
function MeleeTiming.charge(state: State, now: number): State
	if now < state.readyAt - MeleeTiming.EARLY_SECONDS then
		return state
	end
	return { last = state.last, readyAt = state.readyAt, chargeAt = math.max(now, state.readyAt) }
end

-- Gathering: whether a landing at `now` fits a swing started at `startedAt`.
function MeleeTiming.landingOk(startedAt: number?, now: number, contactDelay: number): boolean
	if startedAt == nil then
		return false
	end
	local elapsed = now - startedAt
	return elapsed >= contactDelay - MeleeTiming.LANDING_EARLY and elapsed <= contactDelay + MeleeTiming.LANDING_LATE
end

-- Every move id, sorted (for tools and specs).
function MeleeTiming.ids(): { string }
	local list: { string } = {}
	for id in MeleeTiming.MOVES do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

return MeleeTiming
