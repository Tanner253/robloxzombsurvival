--!strict
--[[
	Combat: damage, melee, firearms, the bow and the dodge roll, as data and math
	(GAME_DESIGN "Combat and the arsenal"; checklist 13.3-13.6, 13.9, 13.11). Pure:
	the server's Combat service owns the state records and does the hit tests.

	- Damage: base x multipliers x crit, then armor (defense / (defense + k), LDoE's
	  formula, Tuning.combat.armorConstant). A crit is rolled once per attack, so a
	  shotgun's pellets crit together.
	- Melee: a light swing, or a heavy one that winds up, hits harder and knocks
	  back further; each costs stamina. Hit-stop and knockback are data.
	- Firearms: a magazine, a fire interval, a reload, a spread cone (pellets for
	  shotguns), range with linear falloff, and a projectile speed. There are no
	  rounds to carry (DECISIONS 2026-11-08): a reload refills the magazine for free,
	  a pacing beat, and every shot costs gun durability instead.
	- Bow: hold to draw; damage and arrow speed scale with the draw, a short draw is a
	  dud. Like a gun, it costs durability per shot and nothing else.
	- Dodge roll: a stamina cost, a cooldown and an i-frame window.
	- M2 PvP rule (data in place now): no single hit takes more than
	  pvpMaxHitFraction of a full-health player, so nobody is one-shot.
]]

local Types = require("../Types")
local Rng = require("./Rng")

local Combat = {}

export type CombatConfig = {
	armorConstant: number,
	critChance: number,
	critMultiplier: number,
	pvpMaxHitFraction: number,
}

export type Melee = {
	arcDegrees: number,
	heavyMultiplier: number,
	heavyWindupSeconds: number,
	knockbackStuds: number,
	heavyKnockbackStuds: number,
	hitStopSeconds: number,
	heavyHitStopSeconds: number,
	staminaLight: number,
	staminaHeavy: number,
}

export type Hit = {
	damage: number,
	crit: boolean,
	knockbackStuds: number,
	hitStopSeconds: number,
}

export type DamageSpec = {
	base: number,
	multiplier: number?, -- heavy swing, draw strength, falloff, Hollow band strength...
	crit: boolean?,
	critMultiplier: number,
	defense: number?, -- the target's armor
	armorConstant: number,
}

-- Damage reduction from armor, 0..1.
function Combat.armorReduction(defense: number, armorConstant: number): number
	if defense <= 0 then
		return 0
	end
	return defense / (defense + armorConstant)
end

function Combat.damage(spec: DamageSpec): number
	local amount = spec.base * (spec.multiplier or 1)
	if spec.crit then
		amount *= spec.critMultiplier
	end
	return amount * (1 - Combat.armorReduction(spec.defense or 0, spec.armorConstant))
end

function Combat.critChance(weapon: Types.WeaponStats?, config: CombatConfig): number
	if weapon and weapon.critChance ~= nil then
		return weapon.critChance
	end
	return config.critChance
end

function Combat.rollCrit(chance: number, rng: Rng.Source): boolean
	return chance > 0 and rng:NextNumber() < chance
end

-- Melee ----------------------------------------------------------------------------------

-- A weapon's melee numbers: its own overrides on top of Tuning.melee.
function Combat.meleeStats(weapon: Types.WeaponStats?, tuning: Types.MeleeTuning): Melee
	local own: Types.MeleeStats = (weapon and weapon.melee) or {}
	local knockback = own.knockbackStuds or tuning.knockbackStuds
	local hitStop = own.hitStopSeconds or tuning.hitStopSeconds
	return {
		arcDegrees = own.arcDegrees or tuning.arcDegrees,
		heavyMultiplier = own.heavyMultiplier or tuning.heavyMultiplier,
		heavyWindupSeconds = tuning.heavyWindupSeconds,
		knockbackStuds = knockback,
		-- A weapon's own knockback scales the heavy one in proportion.
		heavyKnockbackStuds = tuning.heavyKnockbackStuds * knockback / tuning.knockbackStuds,
		hitStopSeconds = hitStop,
		heavyHitStopSeconds = tuning.heavyHitStopSeconds * hitStop / tuning.hitStopSeconds,
		staminaLight = tuning.staminaLight,
		staminaHeavy = tuning.staminaHeavy,
	}
end

function Combat.meleeCost(stats: Melee, heavy: boolean): number
	return if heavy then stats.staminaHeavy else stats.staminaLight
end

-- Seconds between swings (heavy swings add their wind-up).
function Combat.swingSeconds(weapon: Types.WeaponStats, stats: Melee, heavy: boolean): number
	local base = 1 / weapon.attacksPerSecond
	return if heavy then base + stats.heavyWindupSeconds else base
end

export type MeleeContext = {
	defense: number?,
	multiplier: number?,
	rng: Rng.Source,
	combat: CombatConfig,
}

-- One melee hit on one target.
function Combat.meleeHit(weapon: Types.WeaponStats, stats: Melee, heavy: boolean, ctx: MeleeContext): Hit
	local crit = Combat.rollCrit(Combat.critChance(weapon, ctx.combat), ctx.rng)
	local multiplier = (ctx.multiplier or 1) * (if heavy then stats.heavyMultiplier else 1)
	return {
		damage = Combat.damage({
			base = weapon.damage,
			multiplier = multiplier,
			crit = crit,
			critMultiplier = ctx.combat.critMultiplier,
			defense = ctx.defense,
			armorConstant = ctx.combat.armorConstant,
		}),
		crit = crit,
		knockbackStuds = if heavy then stats.heavyKnockbackStuds else stats.knockbackStuds,
		hitStopSeconds = if heavy then stats.heavyHitStopSeconds else stats.hitStopSeconds,
	}
end

-- Stamina --------------------------------------------------------------------------------

export type Stamina = {
	value: number, -- at updatedAt
	updatedAt: number,
	regenFrom: number, -- regeneration resumes here (regenDelaySeconds after the last spend)
}

function Combat.newStamina(config: Types.StaminaTuning, now: number): Stamina
	return { value = config.max, updatedAt = now, regenFrom = now }
end

function Combat.staminaAt(state: Stamina, now: number, config: Types.StaminaTuning): number
	local from = math.max(state.updatedAt, state.regenFrom)
	local regen = math.max(0, now - from) * config.regenPerSecond
	return math.min(config.max, state.value + regen)
end

-- Spends stamina; nil (and nothing spent) when there isn't enough.
function Combat.spendStamina(state: Stamina, now: number, amount: number, config: Types.StaminaTuning): Stamina?
	local value = Combat.staminaAt(state, now, config)
	if value < amount then
		return nil
	end
	return { value = value - amount, updatedAt = now, regenFrom = now + config.regenDelaySeconds }
end

-- Firearms ---------------------------------------------------------------------------------

export type Gun = {
	loaded: number,
	lastShotAt: number,
	reloadEndsAt: number?, -- set while reloading
	burstShots: number?, -- a burst gun: rounds fired in the current burst (nil means none)
}

export type FireReason = "reloading" | "empty" | "cooldown"
export type ReloadReason = "full" | "reloading"

function Combat.newGun(loaded: number?): Gun
	return { loaded = loaded or 0, lastShotAt = -math.huge, reloadEndsAt = nil }
end

-- Seconds from the first round of a full magazine to the last, then the reload: one cycle.
-- A burst gun waits its cooldown, not its fire interval, between bursts.
function Combat.cycleSeconds(firearm: Types.FirearmStats): number
	local gaps = firearm.magazine - 1
	local burst = firearm.burst
	if burst == nil then
		return gaps * firearm.fireInterval + firearm.reloadSeconds
	end
	local between = math.floor(gaps / burst.count)
	return (gaps - between) * firearm.fireInterval + between * burst.cooldown + firearm.reloadSeconds
end

-- Rounds a second, reloads included: what the item card shows (validated in data).
function Combat.sustainedRate(firearm: Types.FirearmStats): number
	return firearm.magazine / Combat.cycleSeconds(firearm)
end

-- The wait before the next round: the fire interval, or a burst's cooldown once it is spent.
function Combat.interval(firearm: Types.FirearmStats, gun: Gun): number
	local burst = firearm.burst
	if burst and (gun.burstShots or 0) >= burst.count then
		return burst.cooldown
	end
	return firearm.fireInterval
end

function Combat.isReloading(gun: Gun, now: number): boolean
	return gun.reloadEndsAt ~= nil and now < gun.reloadEndsAt
end

function Combat.canFire(firearm: Types.FirearmStats, gun: Gun, now: number): (boolean, FireReason?)
	if gun.reloadEndsAt ~= nil then
		return false, "reloading"
	end
	if gun.loaded <= 0 then
		return false, "empty"
	end
	if now - gun.lastShotAt < Combat.interval(firearm, gun) then
		return false, "cooldown"
	end
	return true, nil
end

--[[
	Fires one round. Call only after canFire. With the firearm, a burst gun counts the round
	into its burst: a new burst starts once the last one is spent or its cooldown has passed.
]]
function Combat.fire(gun: Gun, now: number, firearm: Types.FirearmStats?): Gun
	local burst = firearm and firearm.burst
	local shots: number? = nil
	if burst then
		local prior = gun.burstShots or 0
		if prior >= burst.count or now - gun.lastShotAt >= burst.cooldown then
			prior = 0
		end
		shots = prior + 1
	end
	return { loaded = gun.loaded - 1, lastShotAt = now, reloadEndsAt = nil, burstShots = shots }
end

--[[
	When a round asked for at `now` counts as fired: on the gun's next beat when the request
	came early (the server lets a held trigger's requests land a moment ahead), never before
	`now`. Fed to Combat.fire, it keeps an automatic at fireInterval however the requests bunch.
]]
function Combat.shotTime(firearm: Types.FirearmStats, gun: Gun, now: number): number
	return math.max(now, gun.lastShotAt + Combat.interval(firearm, gun))
end

-- Starts a reload when the magazine has room. It costs nothing but the time.
function Combat.startReload(firearm: Types.FirearmStats, gun: Gun, now: number): (Gun?, ReloadReason?)
	if gun.reloadEndsAt ~= nil then
		return nil, "reloading"
	end
	if gun.loaded >= firearm.magazine then
		return nil, "full"
	end
	return { loaded = gun.loaded, lastShotAt = gun.lastShotAt, reloadEndsAt = now + firearm.reloadSeconds }, nil
end

--[[
	Completes a reload that has run its time: the magazine is full. Before the
	reload ends it returns the gun unchanged.
]]
function Combat.finishReload(firearm: Types.FirearmStats, gun: Gun, now: number): Gun
	if gun.reloadEndsAt == nil or now < gun.reloadEndsAt then
		return gun
	end
	return { loaded = firearm.magazine, lastShotAt = gun.lastShotAt, reloadEndsAt = nil }
end

-- Switching away or rolling cancels a reload; nothing was spent.
function Combat.cancelReload(gun: Gun): Gun
	return { loaded = gun.loaded, lastShotAt = gun.lastShotAt, reloadEndsAt = nil }
end

-- The heading of each projectile for one shot, spread evenly at random over the cone.
function Combat.shotYaws(firearm: Types.FirearmStats, aimYaw: number, rng: Rng.Source): { number }
	local half = math.rad(firearm.spreadDegrees) / 2
	local yaws: { number } = {}
	for _ = 1, firearm.pellets or 1 do
		table.insert(yaws, aimYaw + (rng:NextNumber() * 2 - 1) * half)
	end
	return yaws
end

-- Damage multiplier at `distance`: 1 up to falloffStart, down to falloffMin at range.
function Combat.falloff(firearm: Types.FirearmStats, range: number, distance: number): number
	local start = firearm.falloffStart
	local floor = firearm.falloffMin or 1
	if start == nil or distance <= start or range <= start then
		return 1
	end
	local t = math.clamp((distance - start) / (range - start), 0, 1)
	return 1 + (floor - 1) * t
end

function Combat.travelSeconds(distance: number, speed: number): number
	return math.max(0, distance) / speed
end

-- Bow ------------------------------------------------------------------------------------------

function Combat.drawFraction(bow: Types.BowStats, drawStartedAt: number, now: number): number
	return math.clamp((now - drawStartedAt) / bow.drawSeconds, 0, 1)
end

-- Releases a draw: the strength (multiplies damage and arrow speed), or nil for a dud.
function Combat.release(bow: Types.BowStats, drawStartedAt: number, now: number): number?
	local fraction = Combat.drawFraction(bow, drawStartedAt, now)
	if fraction < bow.minDraw then
		return nil
	end
	return fraction
end

-- Dodge roll -------------------------------------------------------------------------------------

export type Dodge = { lastAt: number, iframeUntil: number }
export type DodgeReason = "cooldown" | "stamina"

function Combat.newDodge(): Dodge
	return { lastAt = -math.huge, iframeUntil = -math.huge }
end

function Combat.dodge(
	state: Dodge,
	stamina: Stamina,
	now: number,
	config: Types.DodgeTuning,
	staminaConfig: Types.StaminaTuning
): (Dodge?, Stamina?, DodgeReason?)
	if now - state.lastAt < config.cooldownSeconds then
		return nil, nil, "cooldown"
	end
	local spent = Combat.spendStamina(stamina, now, config.staminaCost, staminaConfig)
	if spent == nil then
		return nil, nil, "stamina"
	end
	return { lastAt = now, iframeUntil = now + config.iframeSeconds }, spent, nil
end

function Combat.invulnerable(state: Dodge, now: number): boolean
	return now < state.iframeUntil
end

-- PvP (M2) ------------------------------------------------------------------------------------------

-- No single hit takes more than pvpMaxHitFraction of a full-health player.
function Combat.pvpCap(damage: number, maxHealth: number, config: CombatConfig): number
	return math.min(damage, maxHealth * config.pvpMaxHitFraction)
end

--[[
	The biggest single hit a weapon can land before armor and caps: a heavy crit for
	melee, every pellet on a crit for guns, a full-draw crit for bows.
]]
function Combat.maxHit(weapon: Types.WeaponStats, config: CombatConfig, melee: Types.MeleeTuning): number
	local crit = config.critMultiplier
	if weapon.kind == "melee" then
		return weapon.damage * Combat.meleeStats(weapon, melee).heavyMultiplier * crit
	end
	local pellets = if weapon.firearm then weapon.firearm.pellets or 1 else 1
	return weapon.damage * pellets * crit
end

function Combat.hitsToKill(damagePerHit: number, hp: number): number
	if damagePerHit <= 0 then
		return math.huge
	end
	return math.ceil(hp / damagePerHit - 1e-9)
end

-- LDoE parity (docs/LDOE_PARITY.md) -------------------------------------------------------------

--[[
	#44 Sneak: a melee hit from a sneaking player on a Hollow that hasn't noticed
	them (Hollow.isAware is false) lands at backstabMultiplier. Otherwise 1. A weapon's
	own `melee.backstabMultiplier` overrides it (the Field Knife's x4, CONTENT_2_0 §4).
]]
function Combat.backstab(
	sneaking: boolean,
	targetAware: boolean,
	config: Types.SneakTuning,
	melee: Types.MeleeStats?
): number
	if sneaking and not targetAware then
		return (melee and melee.backstabMultiplier) or config.backstabMultiplier
	end
	return 1
end

-- The noise a melee swing makes: the weapon's own `melee.noise` (the Field Knife's 6), or
-- Tuning.noise.melee.
function Combat.meleeNoise(melee: Types.MeleeStats?, default: number): number
	return (melee and melee.noise) or default
end

-- #34: a tool in a weapon slot swings as weak melee (it has no weapon stats of its own).
function Combat.toolWeapon(item: { tool: Types.ToolStats? }?, melee: Types.MeleeTuning): Types.WeaponStats?
	if item == nil or item.tool == nil then
		return nil
	end
	return {
		kind = "melee",
		damage = melee.toolDamage,
		attacksPerSecond = melee.toolAttacksPerSecond,
		range = melee.toolRange,
	}
end

-- Durability (docs/ECONOMY.md §8.1) ---------------------------------------------------------------

export type WearConfig = {
	weaponDurabilityPerHit: number,
	heavyDurabilityPerHit: number,
	gunDurabilityPerShot: number,
	durabilityWarn: { number },
}

-- What a weapon pays: "light" and "heavy" for a melee hit that lands, "arrow" for each
-- arrow released, "shot" for every round fired, hit or miss (both shotgun barrels pay 2).
export type WearAction = "light" | "heavy" | "arrow" | "shot"

function Combat.wear(action: WearAction, config: WearConfig): number
	if action == "heavy" then
		return config.heavyDurabilityPerHit
	elseif action == "shot" then
		return config.gunDurabilityPerShot
	end
	return config.weaponDurabilityPerHit
end

--[[
	The warning a wear step crosses, 1-based into Tuning.combat.durabilityWarn (1 = amber at
	25%, 2 = red at 10%), or nil when it crosses none. The deepest one crossed wins, so a
	toast fires once per threshold.
]]
function Combat.wearWarning(before: number, after: number, max: number, config: WearConfig): number?
	if max <= 0 then
		return nil
	end
	local crossed: number? = nil
	for index, fraction in config.durabilityWarn do
		local line = max * fraction
		if before > line and after <= line then
			crossed = index
		end
	end
	return crossed
end

export type AutoCandidate = { id: string, distance: number }

--[[
	#31 AUTO (Q): the nearest Hollow within the AUTO radius that the weapon can
	reach after closing in, or nil. Candidates are sorted or not; ties go by ID.
]]
function Combat.autoTarget(candidates: { AutoCandidate }, radius: number): string?
	local best: AutoCandidate? = nil
	for _, candidate in candidates do
		if candidate.distance <= radius then
			if
				best == nil
				or candidate.distance < best.distance
				or (candidate.distance == best.distance and candidate.id < best.id)
			then
				best = candidate
			end
		end
	end
	return if best then best.id else nil
end

return Combat
