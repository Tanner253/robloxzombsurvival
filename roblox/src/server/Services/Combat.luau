--!strict
--[[
	Combat (CombatService): server-authoritative fighting on a Fog Run (checklist
	13.3-13.9, 13.11; GAME_DESIGN "Combat and the arsenal"). Off until
	Tuning.features.fogRuns.

	The client sends intents only (an aim heading, a soft-lock target); the server
	decides every hit:
	- CombatMelee: the active weapon (or fists) swings at the nearest Hollow in its
	  arc, or the locked one if it's in the arc. Heavy swings wind up first. Stamina,
	  the swing timer and range (plus lag tolerance) are checked here.
	- CombatFire: a gun fires from its magazine with seeded spread; each pellet is
	  traced against the Hollow (Hollow.raycast) and capped at the first wall (the
	  line-of-sight hook is a world raycast). Damage lands after the projectile's
	  travel time, with falloff. A bow fires on release after CombatDraw. The Flare
	  Pistol's flare lights where it lands and sets a hit Hollow burning.
	- There are no rounds to carry (DECISIONS 2026-11-08): every shot and every bow
	  release costs durability (Tuning.combat.gunDurabilityPerShot), nothing else.
	- CombatReload refills the active gun's magazine for free when it completes (a
	  pacing beat); swapping or rolling cancels it. An empty magazine is a dry click.
	- CombatDodge: stamina, cooldown and i-frames (Lobby.hurtPlayer honours them).
	- Two weapon slots, LDoE-style (Domain/Hands): WeaponSelect (1, 2), WeaponSwap
	  (F), each slot with its own magazine and a swap delay; UseMeds (H) uses the
	  best healing item.
	- Every shot and swing makes noise for the Hollow (Domain/Noise) and wears the
	  weapon.

	Weapon slots are read from the paper-doll: equipment.weapon is slot 1 and
	equipment.weapon2 is slot 2 (slice 1 adds the second hand slot, checklist 4.9).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Features = require(ReplicatedStorage.Shared.Features)
local Types = require(ReplicatedStorage.Shared.Types)
local Domain = ReplicatedStorage.Shared.Domain
local CombatMath = require(Domain.Combat)
local Hands = require(Domain.Hands)
local HoldRules = require(Domain.HoldRules)
local InventoryMath = require(Domain.Inventory)
local Plane = require(Domain.Plane)
local Rng = require(Domain.Rng)
local Net = require("../Net")
local Containers = require("./Containers")
local Hollow = require("./Hollow")
local Inventory = require("./Inventory")
local Lobby = require("./Lobby")
local PlayerData = require("./PlayerData")
local Survival = require("./Survival")
local Sync = require("./Sync")

local Combat = {}

local tuning = Content.Tuning
local combatConfig: CombatMath.CombatConfig = tuning.combat :: any
local Items: any = Content.Items
local SLOT_KEYS = { "weapon", "weapon2" } -- paper-doll keys for hand slots 1 and 2
local MUZZLE_HEIGHT = 1.5
local FIRE_LEEWAY_SECONDS = 0.05 -- how early a held trigger's next request may land and still fire
local HOLLOW_CHEST = 3.5 -- studs above the ground a Hollow stands on: where a round aims

-- Seconds a melee request is taken to have spent reaching the server (half a typical round
-- trip): taken off the wait for the swing's hit frame.
local STRIKE_TRANSIT = 0.05

-- Bare hands, from Tuning.player.
local FISTS: Types.WeaponStats = {
	kind = "melee",
	damage = tuning.player.fistDamage,
	attacksPerSecond = tuning.player.fistAttacksPerSecond,
	range = tuning.player.fistRange,
}

type Fighter = {
	hands: Hands.State,
	stamina: CombatMath.Stamina,
	dodge: CombatMath.Dodge,
	drawStartedAt: number?,
	nextSwingAt: number,
	sneaking: boolean, -- LDOE_PARITY #44
	auto: boolean, -- LDOE_PARITY #31: AUTO (Q) fights
}

local fighters: { [Player]: Fighter } = {}
local rng = Rng.new(Random.new():NextInteger(1, 2 ^ 31 - 2))

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- The weapon IDs in hand slots 1 and 2.
local function slotIds(player: Player): { string? }
	local data = PlayerData.get(player)
	local ids: { string? } = {}
	if data == nil then
		return ids
	end
	local equipment = data.inventory.equipment :: any
	for index, key in SLOT_KEYS do
		local slot = equipment[key]
		ids[index] = if slot and slot.count > 0 then slot.itemId else nil
	end
	return ids
end

-- Matches the hands to the paper-doll (a changed slot starts over with a full gun).
local function fighterOf(player: Player): Fighter?
	local fighter = fighters[player]
	if fighter == nil then
		return nil
	end
	fighter.hands = Hands.sync(fighter.hands, slotIds(player), Items, tuning.hands)
	return fighter
end

local function sendHands(player: Player, fighter: Fighter)
	local slots = {}
	for index, hand in fighter.hands.hands do
		slots[index] = {
			itemId = hand.itemId,
			loaded = if hand.gun then hand.gun.loaded else nil,
			reloadEndsAt = if hand.gun then hand.gun.reloadEndsAt else nil,
		}
	end
	Sync.fx(player, "hands", { active = fighter.hands.active, swapEndsAt = fighter.hands.swapEndsAt, slots = slots })
end

local function broadcast(run: Lobby.Run, kind: string, payload: any)
	for player in run.hosted.players do
		Sync.fx(player, kind, payload)
	end
end

-- Wears the active hand's weapon (ECONOMY §8.1: a light hit 1, a heavy one 2, every round
-- fired 1); a broken one leaves the slot empty. Toasts at the last warning line.
local function wear(player: Player, fighter: Fighter, action: CombatMath.WearAction)
	local data = PlayerData.get(player)
	local key = SLOT_KEYS[fighter.hands.active]
	if data == nil or key == nil then
		return
	end
	local equipment = data.inventory.equipment :: any
	local slot = equipment[key]
	if slot == nil or slot.count <= 0 or slot.durability == nil then
		return
	end
	local before = slot.durability
	slot.durability -= CombatMath.wear(action, tuning.combat)
	local def = Items[slot.itemId]
	local warning = if def and def.durability
		then CombatMath.wearWarning(before, slot.durability, def.durability, tuning.combat)
		else nil
	if slot.durability > 0 and warning ~= nil and warning == #tuning.combat.durabilityWarn then
		Sync.notice(player, `Your {def and def.name or "weapon"} is about to break`)
	end
	if slot.durability <= 0 then
		local name = Items[slot.itemId] and Items[slot.itemId].name or "weapon"
		equipment[key] = InventoryMath.emptySlot()
		-- LDOE_PARITY #45: switch to the other slot, or bare fists, with a toast.
		local hands, switched = Hands.onBreak(fighter.hands, now(), Items, tuning.hands)
		fighter.hands = hands
		if switched then
			Inventory.setActiveWeapon(player, hands.active) -- the held model follows
		end
		Sync.notice(player, if switched then `Your {name} broke: switched weapons` else `Your {name} broke`)
		sendHands(player, fighter)
	end
	Sync.mark(player, "inventory")
end

-- Pulls the aim onto a locked target that sits close enough to it (13.3 soft lock).
local function softLock(run: Lobby.Run, origin: Vector3, yaw: number, lockId: string?): number
	if lockId == nil then
		return yaw
	end
	local at = Hollow.positionOf(run.hosted, lockId)
	if at == nil then
		return yaw
	end
	local toward = Plane.yawTo(Plane.point(origin.X, origin.Z), Plane.point(at.X, at.Z))
	if math.abs(Plane.angleDiff(yaw, toward)) <= math.rad(tuning.combat.softLockDegrees) then
		return toward
	end
	return yaw
end

-- What stops a round: anything solid, never a survivor. A tree's crown doesn't collide (only
-- its trunk does, Maps/Builder), so a shot passes under the canopy as a survivor walks under it.
local function shotParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local exclude: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

-- The distance a shot travels before a wall stops it (the line-of-sight hook).
local function clearDistance(origin: Vector3, yaw: number, range: number): (number, Vector3)
	local params = shotParams()
	local dir = Plane.direction(yaw)
	local direction = Vector3.new(dir.x, 0, dir.z) * range
	local hit = workspace:Raycast(origin, direction, params)
	if hit then
		return (hit.Position - origin).Magnitude, hit.Position
	end
	return range, origin + direction
end

-- Melee -----------------------------------------------------------------------------------------

local function strike(
	player: Player,
	run: Lobby.Run,
	weapon: Types.WeaponStats,
	heavy: boolean,
	yaw: number,
	lockId: string?
)
	local fighter = fighters[player]
	local root = rootOf(player)
	if fighter == nil or root == nil or Lobby.runOf(player) ~= run or not alive(player) then
		return
	end
	local stats = CombatMath.meleeStats(weapon, tuning.melee)
	local reach = weapon.range + tuning.combat.lagToleranceStuds
	local candidates = Hollow.inArc(run.hosted, root.Position, yaw, reach, stats.arcDegrees)
	local target = candidates[1]
	for _, candidate in candidates do
		if candidate.id == lockId then
			target = candidate
		end
	end
	Hollow.noise(run.hosted, "melee", root.Position, nil, `u{player.UserId}`, fighter.sneaking)
	if target == nil then
		return
	end
	-- LDOE_PARITY #44: a sneak attack on a Hollow that hasn't noticed you lands at 3x.
	local backstab = CombatMath.backstab(fighter.sneaking, Hollow.isAware(run.hosted, target.id), tuning.sneak)
	local hit = CombatMath.meleeHit(weapon, stats, heavy, { rng = rng, combat = combatConfig, multiplier = backstab })
	local dealt = Hollow.damage(run.hosted, target.id, hit.damage, player, {
		knockbackStuds = hit.knockbackStuds,
		fromYaw = yaw,
		crit = hit.crit,
	})
	if dealt > 0 then
		broadcast(
			run,
			"hit",
			{ id = target.id, damage = dealt, crit = hit.crit, hitStop = hit.hitStopSeconds, heavy = heavy }
		)
		wear(player, fighter, if heavy then "heavy" else "light")
	end
end

local function melee(player: Player, heavy: boolean, yaw: number, lockId: string?)
	local run = Lobby.runOf(player)
	local fighter = fighterOf(player)
	if run == nil or fighter == nil or not alive(player) then
		return
	end
	local stamp = now()
	if not Hands.ready(fighter.hands, stamp) or stamp < fighter.nextSwingAt then
		return
	end
	local weapon = Hands.weapon(fighter.hands, Items, tuning.melee) or FISTS -- tools swing weakly (#34)
	if weapon.kind ~= "melee" then
		return -- guns and bows fire instead
	end
	local stats = CombatMath.meleeStats(weapon, tuning.melee)
	local spent = CombatMath.spendStamina(fighter.stamina, stamp, CombatMath.meleeCost(stats, heavy), tuning.stamina)
	if spent == nil then
		Sync.notice(player, "Too tired to swing")
		return
	end
	fighter.stamina = spent
	fighter.nextSwingAt = stamp + CombatMath.swingSeconds(weapon, stats, heavy)
	local itemId = Hands.active(fighter.hands).itemId
	broadcast(run, "swing", { userId = player.UserId, heavy = heavy, yaw = yaw, itemId = itemId })
	if heavy then
		task.delay(stats.heavyWindupSeconds, strike, player, run, weapon, true, yaw, lockId)
	else
		-- The blow lands on the swing's hit frame (Data/Holds), not on the click, so the
		-- number, the flinch and the thud arrive with the blade. The request already spent
		-- part of that on its way here.
		local class = HoldRules.classOf(itemId, Items[itemId])
		local delay = math.max(0, HoldRules.strikeDelay(class, false) - STRIKE_TRANSIT)
		task.delay(delay, strike, player, run, weapon, false, yaw, lockId)
	end
end

-- Guns and the bow ---------------------------------------------------------------------------------

-- One projectile: trace it, then land the damage after its travel time.
local function projectile(
	player: Player,
	run: Lobby.Run,
	weapon: Types.WeaponStats,
	origin: Vector3,
	yaw: number,
	damage: number,
	speed: number,
	crit: boolean,
	flare: Types.FlareStats?
)
	local _, wallAt = clearDistance(origin, yaw, weapon.range)
	local firearm = weapon.firearm
	local params = shotParams()
	local ahead = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
	-- A piercing round carries on through each Hollow it hits (the Anti-Materiel Rifle: two
	-- more), still stopped by the first wall. It is one round: one durability, one crit roll.
	-- Each Hollow is checked along a line to its chest, not a level one, so the ground rising
	-- toward it doesn't swallow the shot.
	local struck: { { id: string, distance: number } } = {}
	local through: { [string]: boolean } = {}
	local stopped: Vector3? = nil
	for _ = 0, if firearm then firearm.pierce or 0 else 0 do
		local id, distance = Hollow.raycast(run.hosted, origin, yaw, weapon.range, through)
		if id == nil then
			break
		end
		local spot = origin + ahead * distance
		local standing = Hollow.positionOf(run.hosted, id)
		local chest = if standing then Vector3.new(spot.X, standing.Y + HOLLOW_CHEST, spot.Z) else spot
		local wall = workspace:Raycast(origin, chest - origin, params)
		if wall then
			stopped = wall.Position
			break
		end
		through[id] = true
		table.insert(struck, { id = id, distance = distance })
	end
	local first = struck[1]
	local impact = if first then origin + ahead * first.distance else stopped or wallAt
	local reach = Vector3.new(impact.X - origin.X, 0, impact.Z - origin.Z).Magnitude
	task.delay(CombatMath.travelSeconds(reach, speed), function()
		if Lobby.hosted(run.hosted.id) == nil then
			return
		end
		if flare then
			Hollow.flare(run.hosted, flare, impact, `u{player.UserId}`)
		end
		for _, hit in struck do
			local amount = damage * (if firearm then CombatMath.falloff(firearm, weapon.range, hit.distance) else 1)
			if crit then
				amount *= combatConfig.critMultiplier
			end
			local dealt = Hollow.damage(run.hosted, hit.id, amount, player, {
				knockbackStuds = if firearm then firearm.knockbackStuds else nil,
				fromYaw = yaw,
				burn = flare,
				crit = crit,
			})
			if dealt > 0 then
				broadcast(run, "hit", { id = hit.id, damage = dealt, crit = crit })
			end
		end
	end)
	return if first then first.id else nil, impact
end

local function fireBow(
	player: Player,
	run: Lobby.Run,
	fighter: Fighter,
	weapon: Types.WeaponStats,
	yaw: number,
	lockId: string?
)
	local bow = weapon.bow :: Types.BowStats
	local started = fighter.drawStartedAt
	fighter.drawStartedAt = nil
	local root = rootOf(player)
	if started == nil or root == nil then
		return
	end
	local strength = CombatMath.release(bow, started, now())
	if strength == nil then
		Sync.fx(player, "dud", nil)
		return
	end
	local origin = root.Position + Vector3.new(0, MUZZLE_HEIGHT, 0)
	local aim = softLock(run, origin, yaw, lockId)
	local crit = CombatMath.rollCrit(CombatMath.critChance(weapon, combatConfig), rng)
	projectile(player, run, weapon, origin, aim, weapon.damage * strength, bow.projectileSpeed * strength, crit, nil)
	Hollow.noise(run.hosted, "bow", origin, nil, `u{player.UserId}`)
	broadcast(run, "shot", { userId = player.UserId, yaw = aim, itemId = Hands.active(fighter.hands).itemId })
	wear(player, fighter, "arrow")
end

local function fire(player: Player, yaw: number, lockId: string?)
	local run = Lobby.runOf(player)
	local fighter = fighterOf(player)
	local root = rootOf(player)
	if run == nil or fighter == nil or root == nil or not alive(player) then
		return
	end
	local stamp = now()
	if not Hands.ready(fighter.hands, stamp) then
		return
	end
	local weapon = Hands.weapon(fighter.hands, Items)
	if weapon == nil or weapon.kind ~= "ranged" then
		return
	end
	if weapon.bow then
		fireBow(player, run, fighter, weapon, yaw, lockId)
		return
	end
	local firearm = weapon.firearm :: Types.FirearmStats
	local hand = Hands.active(fighter.hands)
	local gun = hand.gun or CombatMath.newGun(0)
	-- A held trigger's requests arrive unevenly, so one a moment early still fires; it counts
	-- as fired on the gun's beat (shotTime), so the leeway never raises the rate of fire.
	local ok, reason = CombatMath.canFire(firearm, gun, stamp + FIRE_LEEWAY_SECONDS)
	if not ok then
		if reason == "empty" then
			Sync.fx(player, "dryClick", nil) -- the client starts the reload (CombatControl)
		end
		return
	end
	fighter.hands = Hands.setGun(fighter.hands, CombatMath.fire(gun, CombatMath.shotTime(firearm, gun, stamp)))
	local origin = root.Position + Vector3.new(0, MUZZLE_HEIGHT, 0)
	local aim = softLock(run, origin, yaw, lockId)
	local crit = CombatMath.rollCrit(CombatMath.critChance(weapon, combatConfig), rng)
	for _, pelletYaw in CombatMath.shotYaws(firearm, aim, rng) do
		projectile(player, run, weapon, origin, pelletYaw, weapon.damage, firearm.projectileSpeed, crit, firearm.flare)
	end
	Hollow.noise(run.hosted, "gunshot", origin, firearm, `u{player.UserId}`)
	broadcast(run, "shot", { userId = player.UserId, yaw = aim, itemId = hand.itemId })
	wear(player, fighter, "shot")
	sendHands(player, fighter)
end

local function draw(player: Player)
	local fighter = fighterOf(player)
	if fighter == nil or Lobby.runOf(player) == nil or not Hands.ready(fighter.hands, now()) then
		return
	end
	local weapon = Hands.weapon(fighter.hands, Items)
	if weapon and weapon.bow then
		fighter.drawStartedAt = now()
		Sync.fx(player, "draw", { startedAt = fighter.drawStartedAt })
	end
end

local function reload(player: Player)
	local fighter = fighterOf(player)
	if fighter == nil or Lobby.runOf(player) == nil then
		return
	end
	local weapon = Hands.weapon(fighter.hands, Items)
	local firearm = weapon and weapon.firearm
	local hand = Hands.active(fighter.hands)
	if weapon == nil or firearm == nil or hand.gun == nil then
		return
	end
	local started = CombatMath.startReload(firearm, hand.gun, now())
	if started == nil then
		return
	end
	fighter.hands = Hands.setGun(fighter.hands, started)
	sendHands(player, fighter)
	local slot = fighter.hands.active
	local endsAt = started.reloadEndsAt
	task.delay(firearm.reloadSeconds, function()
		local current = fighters[player]
		local currentHand = current and current.hands.hands[slot]
		local gun = currentHand and currentHand.gun
		-- Only the same reload, still in the same slot and still the active one.
		if current == nil or gun == nil or gun.reloadEndsAt ~= endsAt or current.hands.active ~= slot then
			return
		end
		current.hands = Hands.setGun(current.hands, CombatMath.finishReload(firearm, gun, now()))
		sendHands(player, current)
	end)
end

-- Dodge, hands and meds ----------------------------------------------------------------------------

local function cancelReloads(fighter: Fighter)
	local hand = Hands.active(fighter.hands)
	if hand.gun and hand.gun.reloadEndsAt then
		fighter.hands = Hands.setGun(fighter.hands, CombatMath.cancelReload(hand.gun))
	end
end

local function dodge(player: Player, yaw: number)
	local run = Lobby.runOf(player)
	local fighter = fighterOf(player)
	if run == nil or fighter == nil or not alive(player) then
		return
	end
	local rolled, stamina, reason =
		CombatMath.dodge(fighter.dodge, fighter.stamina, now(), tuning.dodge, tuning.stamina)
	if rolled == nil or stamina == nil then
		if reason == "stamina" then
			Sync.notice(player, "Too tired to roll")
		end
		return
	end
	fighter.dodge = rolled
	fighter.stamina = stamina
	fighter.drawStartedAt = nil
	cancelReloads(fighter)
	broadcast(run, "dodge", { userId = player.UserId, yaw = yaw, seconds = tuning.dodge.durationSeconds })
end

local function selectSlot(player: Player, index: number)
	local fighter = fighterOf(player)
	if fighter == nil then
		return
	end
	local hands, reason = Hands.select(fighter.hands, index, now(), Items, tuning.hands)
	if reason == nil then
		fighter.hands = hands
		fighter.drawStartedAt = nil
		sendHands(player, fighter)
	end
end

local function swap(player: Player)
	local fighter = fighterOf(player)
	if fighter then
		selectSlot(player, if fighter.hands.active == 1 then 2 else 1)
	end
end

local function useMeds(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local view = Inventory.view(player)
	if humanoid == nil or view == nil or humanoid.Health <= 0 then
		return
	end
	local itemId = Hands.bestMeds(view, Items, humanoid.MaxHealth - humanoid.Health)
	if itemId == nil then
		Sync.notice(player, if humanoid.Health >= humanoid.MaxHealth then "You're not hurt" else "No meds")
		return
	end
	local item = Items[itemId]
	if Inventory.take(player, { { itemId = itemId, count = 1 } }, "Meds") then
		Survival.consume(player, item.consume)
		Sync.fx(player, "meds", { itemId = itemId, left = Hands.medsCount(Inventory.view(player) :: any, Items) })
	end
end

-- Forwarded from the Inventory service's home remotes while the player fights in a lobby.
Combat.onWeaponSelect = selectSlot
Combat.onWeaponSwap = swap
Combat.onUseMeds = useMeds

-- Lifecycle ------------------------------------------------------------------------------------------

-- Sneak and AUTO (LDOE_PARITY #44, #31) -------------------------------------------------------------

local sneakSpeeds: { [Player]: number } = {}

-- Ctrl: slower and quieter (the Hollow read the Sneaking attribute for detection).
function Combat.setSneaking(player: Player, on: boolean)
	local fighter = fighters[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if fighter == nil or fighter.sneaking == on then
		return
	end
	fighter.sneaking = on
	player:SetAttribute("Sneaking", on)
	if humanoid then
		if on then
			sneakSpeeds[player] = humanoid.WalkSpeed
			humanoid.WalkSpeed = humanoid.WalkSpeed * tuning.sneak.speedMultiplier
		elseif sneakSpeeds[player] then
			humanoid.WalkSpeed = sneakSpeeds[player]
			sneakSpeeds[player] = nil
		end
	end
	Sync.fx(player, "sneak", { on = on })
end

local function setAuto(player: Player, on: boolean)
	local fighter = fighters[player]
	if fighter then
		fighter.auto = on
		Sync.fx(player, "auto", { on = on })
	end
end

-- AUTO fights: the nearest Hollow in its radius, with whatever is in hand.
local function autoFight(player: Player, fighter: Fighter)
	local run = Lobby.runOf(player)
	local root = rootOf(player)
	if run == nil or root == nil or not alive(player) then
		return
	end
	local radius = tuning.autoAttack.radiusStuds
	local candidates = Hollow.inArc(run.hosted, root.Position, 0, radius, 360)
	local targetId = CombatMath.autoTarget(candidates, radius)
	local at = targetId and Hollow.positionOf(run.hosted, targetId)
	if targetId == nil or at == nil then
		return
	end
	local yaw = Plane.yawTo(Plane.point(root.Position.X, root.Position.Z), Plane.point(at.X, at.Z))
	local weapon = Hands.weapon(fighter.hands, Items, tuning.melee) or FISTS
	if weapon.kind == "ranged" and weapon.firearm then
		fire(player, yaw, targetId)
	elseif weapon.kind == "melee" then
		melee(player, false, yaw, targetId)
	end
end

-- Scripted playtests (Diagnostics "shoot"): the same fire and reload the remotes run, and
-- the active hand's rounds loaded (nil with no gun in hand).
Combat.dev = {
	fire = fire,
	reload = reload,
	loaded = function(player: Player): number?
		local fighter = fighterOf(player) -- matched to the paper-doll first
		local gun = fighter and Hands.active(fighter.hands).gun
		return if gun then gun.loaded else nil
	end,
}

function Combat.init()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	Net.onEvent("SneakSet", Combat.setSneaking)
	Net.onEvent("CombatAuto", setAuto)
	Net.onEvent("CombatMelee", melee)
	Net.onEvent("CombatFire", fire)
	Net.onEvent("CombatDraw", draw)
	Net.onEvent("CombatReload", reload)
	Net.onEvent("CombatDodge", dodge)
	-- WeaponSelect, WeaponSwap and UseMeds belong to the Inventory service (home remotes);
	-- it forwards them here while the player is fighting in a lobby.
	Inventory.combat = {
		active = function(player: Player): boolean
			return fighters[player] ~= nil
		end,
		select = Combat.onWeaponSelect,
		swap = Combat.onWeaponSwap,
		meds = Combat.onUseMeds,
	}
end

function Combat.start()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	Lobby.invulnerable = function(player: Player): boolean
		local fighter = fighters[player]
		return fighter ~= nil and CombatMath.invulnerable(fighter.dodge, now())
	end
	Lobby.entered:Connect(function(player: Player)
		-- The run starts with whichever slot was in hand at home.
		local hands = Hands.new(slotIds(player), Items, tuning.hands)
		hands.active = Inventory.activeWeapon(player)
		-- Drawn as the run starts: at home the hand may still hold a tool, or nothing.
		Inventory.setActiveWeapon(player, hands.active)
		local fighter: Fighter = {
			hands = hands,
			stamina = CombatMath.newStamina(tuning.stamina, now()),
			dodge = CombatMath.newDodge(),
			drawStartedAt = nil,
			nextSwingAt = 0,
			sneaking = false,
			auto = false,
		}
		fighters[player] = fighter
		sendHands(player, fighter)
	end)
	-- Looting or harvesting breaks sneak (#44).
	Containers.searched:Connect(function(player: Player)
		Combat.setSneaking(player, false)
	end)
	task.spawn(function()
		while true do
			task.wait(tuning.autoAttack.tickSeconds)
			for player, fighter in fighters do
				if fighter.auto then
					local ok, err = pcall(autoFight :: any, player, fighter)
					if not ok then
						warn(`Combat: AUTO failed: {err}`)
					end
				end
			end
		end
	end)
	Lobby.exited:Connect(function(player: Player)
		Combat.setSneaking(player, false)
		player:SetAttribute("Sneaking", nil)
		fighters[player] = nil
	end)
	Lobby.addRunState("stamina", function(player: Player): any
		local fighter = fighters[player]
		return if fighter then CombatMath.staminaAt(fighter.stamina, now(), tuning.stamina) else nil
	end)
end

return Combat
