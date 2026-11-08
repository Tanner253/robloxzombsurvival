--!strict
--[[
	Lobby: one Fog Run lobby's lifecycle, seats and death drops (GAME_DESIGN "Fog
	Runs: shared lobbies and PvP"; checklist 12.1, 12.3, 12.6).

	Lifecycle, all from timestamps (Tuning.lobby):
	- open: reserved, waiting for its first arrival (closes after openTimeoutSeconds)
	- joinable: the first joinWindowSeconds after the first arrival
	- running: no new players; members who died may re-enter
	- warning: the last warningSeconds; the 60 s cue
	- closed: the Fog meter is full (durationSeconds) or the service closed it early.
	  Anyone still inside is lost to the Fog (death rules) and every drop is gone.

	The Fog meter rises from 0 to 1 over the run (shaped by meterExponent) and picks
	a band (Tuning.lobby.bands): loot and Hollow strength multipliers.

	Seats: `capacity` counts members who are incoming (a matched seat being held for
	the teleport), inside, or dead while they could still re-enter, so a full lobby
	never locks a player out of fetching their own bag.

	Death drops by fog tier (Tuning.lobby.drops): the backpack (and pockets unless
	Tuning.death.keepPockets) always drops, through Domain/Death; Black fog drops
	equipped gear too. The secure pouch (M2) is never passed in, so it never drops.
	Light drops open only for the owner and their party; Dense and Black for
	anyone. Drops last until the lobby closes, however the player died.

	The state is a plain record owned by one service; functions here mutate it in
	place and never touch Roblox APIs. Pass `now` in.
]]

local Types = require("../Types")
local Death = require("./Death")
local Inventory = require("./Inventory")
local Plane = require("./Plane")

local Lobby = {}

export type Config = Types.LobbyTuning
export type Phase = "open" | "joinable" | "running" | "warning" | "closed"
export type MemberState = "incoming" | "inside" | "dead" | "extracted" | "left" | "lost"
export type Section = "backpack" | "equipment"

export type Member = {
	userId: number,
	partyId: string?,
	state: MemberState,
	reservedAt: number, -- when the seat was (re)reserved
	enteredAt: number?, -- the latest arrival
	entries: number, -- arrivals, re-entries included
}

export type DeathDrop = {
	id: string,
	ownerUserId: number,
	partyId: string?, -- the owner's party when they fell
	position: Plane.Point?,
	droppedAt: number,
	cause: string, -- "hollow", "player", "fog", "burst", ...
	backpack: Types.Container, -- non-empty slots only
	equipment: Types.Container, -- Black fog only; empty elsewhere
}

export type State = {
	id: string,
	locationId: Types.LocationId,
	fogTier: number,
	seed: number, -- rolls everything random about this lobby (closed exits, containers)
	powerBand: number,
	createdAt: number,
	startedAt: number?,
	closedAt: number?,
	closeReason: string?,
	members: { [number]: Member },
	drops: { [string]: DeathDrop },
	dropSeq: number,
}

export type Params = {
	id: string,
	locationId: Types.LocationId,
	fogTier: number,
	seed: number,
	powerBand: number,
	now: number,
}

export type JoinRequest = {
	seats: number, -- the whole party joins or nobody does
	powerBand: number,
}

export type JoinReason = "closed" | "notJoinable" | "full" | "powerBand"
export type ArriveReason = "notReserved" | "expired" | "closed"
export type ReenterReason = "notMember" | "notDead" | "closed" | "tooLate" | "full"
export type DropReason = "gone" | "denied" | "badSlot"

export type DeathInfo = {
	inventory: Types.Inventory, -- pockets and backpack as carried
	equipment: { [string]: Types.Slot }, -- PlayerSchema.Equipment
	position: Plane.Point?,
	cause: string,
}

export type DeathResult = {
	inventory: Types.Inventory, -- what the player keeps carrying (emptied containers)
	equipment: { [string]: Types.Slot }, -- what stays equipped
	drop: DeathDrop?, -- nil when nothing was carried
}

export type TickResult = {
	expired: { number }, -- reservations that ran out
	lost: { number }, -- members lost to the Fog when it closed this tick
	closed: boolean, -- closed this tick
}

function Lobby.new(params: Params): State
	return {
		id = params.id,
		locationId = params.locationId,
		fogTier = params.fogTier,
		seed = params.seed,
		powerBand = params.powerBand,
		createdAt = params.now,
		startedAt = nil,
		closedAt = nil,
		closeReason = nil,
		members = {},
		drops = {},
		dropSeq = 0,
	}
end

-- When the Fog closes in, or nil before the first arrival.
function Lobby.closesAt(state: State, config: Config): number?
	if state.closedAt then
		return state.closedAt
	end
	if state.startedAt == nil then
		return nil
	end
	return state.startedAt + config.durationSeconds
end

function Lobby.phase(state: State, now: number, config: Config): Phase
	if state.closedAt and now >= state.closedAt then
		return "closed"
	end
	local startedAt = state.startedAt
	if startedAt == nil then
		if now >= state.createdAt + config.openTimeoutSeconds then
			return "closed"
		end
		return "open"
	end
	local elapsed = now - startedAt
	if elapsed >= config.durationSeconds then
		return "closed"
	elseif elapsed >= config.durationSeconds - config.warningSeconds then
		return "warning"
	elseif elapsed < config.joinWindowSeconds then
		return "joinable"
	end
	return "running"
end

-- The shared Fog meter, 0 at the first arrival to 1 when the Fog closes in.
function Lobby.meter(state: State, now: number, config: Config): number
	local startedAt = state.startedAt
	if startedAt == nil then
		return 0
	end
	local t = math.clamp((now - startedAt) / config.durationSeconds, 0, 1)
	return t ^ config.meterExponent
end

-- The band for a meter value: its index (1-based) and definition.
function Lobby.bandFor(meter: number, config: Config): (number, Types.MeterBand)
	local index = 1
	for i, band in config.bands do
		if meter >= band.from then
			index = i
		end
	end
	return index, config.bands[index]
end

function Lobby.band(state: State, now: number, config: Config): (number, Types.MeterBand)
	return Lobby.bandFor(Lobby.meter(state, now, config), config)
end

-- Seconds until the meter reaches `band` (0 if it has; math.huge before the start).
function Lobby.secondsUntilBand(state: State, now: number, config: Config, band: number): number
	local startedAt = state.startedAt
	local def = config.bands[band]
	if def == nil then
		return math.huge
	end
	if startedAt == nil then
		return math.huge
	end
	local reachedAt = startedAt + config.durationSeconds * def.from ^ (1 / config.meterExponent)
	return math.max(0, reachedAt - now)
end

local function reentryOpen(state: State, now: number, config: Config): boolean
	local closesAt = Lobby.closesAt(state, config)
	return Lobby.phase(state, now, config) ~= "closed"
		and closesAt ~= nil
		and now < closesAt - config.reentryCutoffSeconds
end

local function holdsSeat(state: State, member: Member, now: number, config: Config): boolean
	if member.state == "inside" then
		return true
	elseif member.state == "incoming" then
		return now < member.reservedAt + config.reservationSeconds
	elseif member.state == "dead" then
		return reentryOpen(state, now, config)
	end
	return false
end

function Lobby.seatsTaken(state: State, now: number, config: Config): number
	local taken = 0
	for _, member in state.members do
		if holdsSeat(state, member, now, config) then
			taken += 1
		end
	end
	return taken
end

function Lobby.freeSeats(state: State, now: number, config: Config): number
	return math.max(0, config.capacity - Lobby.seatsTaken(state, now, config))
end

-- Whether a party may be matched into this lobby now.
function Lobby.canJoin(state: State, now: number, config: Config, request: JoinRequest): (boolean, JoinReason?)
	local phase = Lobby.phase(state, now, config)
	if phase == "closed" then
		return false, "closed"
	end
	if phase ~= "open" and phase ~= "joinable" then
		return false, "notJoinable"
	end
	if math.abs(request.powerBand - state.powerBand) > config.bandTolerance then
		return false, "powerBand"
	end
	if Lobby.freeSeats(state, now, config) < request.seats then
		return false, "full"
	end
	return true, nil
end

-- Holds seats for a matched party while it teleports in. All or nothing.
function Lobby.reserve(
	state: State,
	now: number,
	config: Config,
	userIds: { number },
	partyId: string?,
	powerBand: number
): (boolean, JoinReason?)
	local ok: boolean, reason: JoinReason? =
		Lobby.canJoin(state, now, config, { seats = #userIds, powerBand = powerBand })
	if not ok then
		return false, reason
	end
	for _, userId in userIds do
		local existing = state.members[userId]
		state.members[userId] = {
			userId = userId,
			partyId = partyId,
			state = "incoming",
			reservedAt = now,
			enteredAt = if existing then existing.enteredAt else nil,
			entries = if existing then existing.entries else 0,
		}
	end
	return true, nil
end

-- A reserved player arrives. The first arrival starts the Fog meter.
function Lobby.arrive(state: State, userId: number, now: number, config: Config): (boolean, ArriveReason?)
	if Lobby.phase(state, now, config) == "closed" then
		return false, "closed"
	end
	local member = state.members[userId]
	if member == nil or member.state ~= "incoming" then
		return false, "notReserved"
	end
	if now >= member.reservedAt + config.reservationSeconds then
		return false, "expired"
	end
	member.state = "inside"
	member.enteredAt = now
	member.entries += 1
	if state.startedAt == nil then
		state.startedAt = now
	end
	return true, nil
end

-- Members inside the lobby now.
function Lobby.inside(state: State): { number }
	local ids: { number } = {}
	for userId, member in state.members do
		if member.state == "inside" then
			table.insert(ids, userId)
		end
	end
	table.sort(ids)
	return ids
end

function Lobby.member(state: State, userId: number): Member?
	return state.members[userId]
end

-- A member got out alive (extraction).
function Lobby.extract(state: State, userId: number): boolean
	local member = state.members[userId]
	if member == nil or member.state ~= "inside" then
		return false
	end
	member.state = "extracted"
	return true
end

-- A member disconnected or walked out by other means; they keep what they carry.
function Lobby.leave(state: State, userId: number)
	local member = state.members[userId]
	if member and (member.state == "inside" or member.state == "incoming") then
		member.state = "left"
	end
end

local function nonEmpty(slots: { [string]: Types.Slot }, order: { string }): Types.Container
	local result: Types.Container = {}
	for _, key in order do
		local slot = slots[key]
		if slot and not Inventory.isEmpty(slot) then
			table.insert(result, { itemId = slot.itemId, count = slot.count, durability = slot.durability })
		end
	end
	return result
end

-- The equipment keys in a fixed order (PlayerSchema.Equipment).
Lobby.EQUIPMENT_ORDER = { "weapon", "head", "body", "legs", "feet", "bag" }

--[[
	A member dies inside. Applies the fog tier's drop rule and records the drop at
	`info.position`. Returns what the player keeps and the drop. `deathConfig` is
	Tuning.death (keepPockets); drops last until the lobby closes.
]]
function Lobby.die(
	state: State,
	userId: number,
	now: number,
	config: Config,
	deathConfig: Death.Config,
	info: DeathInfo
): DeathResult
	local member = state.members[userId]
	if member then
		member.state = "dead"
	end
	local rule = config.drops[state.fogTier] or config.drops[#config.drops]
	local closesAt = Lobby.closesAt(state, config) or now
	state.dropSeq += 1
	local id = `b{state.dropSeq}`
	local position: Death.Position? = if info.position then { x = info.position.x, y = 0, z = info.position.z } else nil
	local inventory, dropped = Death.drop(info.inventory, {
		id = id,
		ownerUserId = userId,
		locationId = state.locationId,
		now = now,
		position = position,
		despawnAt = closesAt,
	}, deathConfig)

	local equipment = table.clone(info.equipment)
	local equipmentDrop: Types.Container = {}
	if rule.equipment then
		equipmentDrop = nonEmpty(info.equipment, Lobby.EQUIPMENT_ORDER)
		for _, key in Lobby.EQUIPMENT_ORDER do
			if equipment[key] then
				equipment[key] = Inventory.emptySlot()
			end
		end
	end

	local backpack: Types.Container = if dropped then dropped.contents else {}
	if #backpack == 0 and #equipmentDrop == 0 then
		state.dropSeq -= 1
		return { inventory = inventory, equipment = equipment, drop = nil }
	end
	local drop: DeathDrop = {
		id = id,
		ownerUserId = userId,
		partyId = if member then member.partyId else nil,
		position = info.position,
		droppedAt = now,
		cause = info.cause,
		backpack = backpack,
		equipment = equipmentDrop,
	}
	state.drops[id] = drop
	return { inventory = inventory, equipment = equipment, drop = drop }
end

--[[
	The same rules for a member lost to the Fog when it closes: they lose what the
	tier would have dropped, but nothing is left behind (the lobby is gone).
]]
function Lobby.loseToFog(
	state: State,
	userId: number,
	now: number,
	config: Config,
	deathConfig: Death.Config,
	info: DeathInfo
): DeathResult
	local result = Lobby.die(state, userId, now, config, deathConfig, info)
	if result.drop then
		state.drops[result.drop.id] = nil
	end
	local member = state.members[userId]
	if member then
		member.state = "lost"
	end
	return { inventory = result.inventory, equipment = result.equipment, drop = nil }
end

-- Live drops (none once the lobby has closed), oldest first.
function Lobby.drops(state: State, now: number, config: Config): { DeathDrop }
	local list: { DeathDrop } = {}
	if Lobby.phase(state, now, config) == "closed" then
		return list
	end
	for _, drop in state.drops do
		table.insert(list, drop)
	end
	table.sort(list, function(a: DeathDrop, b: DeathDrop): boolean
		return a.droppedAt < b.droppedAt or (a.droppedAt == b.droppedAt and a.id < b.id)
	end)
	return list
end

-- Whether `userId` (in `partyId`) may open a drop.
function Lobby.canAccessDrop(
	state: State,
	dropId: string,
	userId: number,
	partyId: string?,
	now: number,
	config: Config
): (boolean, DropReason?)
	local drop = state.drops[dropId]
	if drop == nil or Lobby.phase(state, now, config) == "closed" then
		return false, "gone"
	end
	local rule = config.drops[state.fogTier] or config.drops[#config.drops]
	if rule.access == "anyone" or userId == drop.ownerUserId then
		return true, nil
	end
	if partyId ~= nil and partyId == drop.partyId then
		return true, nil
	end
	return false, "denied"
end

--[[
	Takes `count` units (default: all) from one slot of a drop. Returns the slot
	taken, or nil and a reason. An emptied drop disappears.
]]
function Lobby.takeFromDrop(
	state: State,
	dropId: string,
	userId: number,
	partyId: string?,
	section: Section,
	index: number,
	count: number?,
	now: number,
	config: Config
): (Types.Slot?, DropReason?)
	local allowed: boolean, reason: DropReason? = Lobby.canAccessDrop(state, dropId, userId, partyId, now, config)
	if not allowed then
		return nil, reason
	end
	local drop = state.drops[dropId]
	local container = if section == "equipment" then drop.equipment else drop.backpack
	local slot = container[index]
	if slot == nil then
		return nil, "badSlot"
	end
	local taken = math.clamp(count or slot.count, 1, slot.count)
	local result: Types.Slot = { itemId = slot.itemId, count = taken, durability = slot.durability }
	if taken == slot.count then
		table.remove(container, index)
	else
		slot.count -= taken
	end
	if #drop.backpack == 0 and #drop.equipment == 0 then
		state.drops[dropId] = nil
	end
	return result, nil
end

-- Puts back what didn't fit in the taker's bag (a new slot at the end of the section).
function Lobby.returnToDrop(
	state: State,
	dropId: string,
	section: Section,
	slot: Types.Slot,
	now: number,
	owner: number?
)
	local drop: DeathDrop? = state.drops[dropId]
	if drop == nil then
		-- The drop emptied on take: bring it back so nothing is lost.
		local revived: DeathDrop = {
			id = dropId,
			ownerUserId = owner or 0,
			partyId = nil,
			position = nil,
			droppedAt = now,
			cause = "returned",
			backpack = {},
			equipment = {},
		}
		state.drops[dropId] = revived
		drop = revived
	end
	assert(drop, "drop exists")
	local container = if section == "equipment" then drop.equipment else drop.backpack
	table.insert(container, { itemId = slot.itemId, count = slot.count, durability = slot.durability })
end

--[[
	LDOE_PARITY #46 "Recover all": the owner takes the whole drop at once, for the
	inbox (the service checks the ad or premium payment). Gear first, then the bag.
]]
function Lobby.recoverAll(
	state: State,
	dropId: string,
	userId: number,
	now: number,
	config: Config
): ({ Types.Slot }?, DropReason?)
	local drop = state.drops[dropId]
	if drop == nil or Lobby.phase(state, now, config) == "closed" then
		return nil, "gone"
	end
	if drop.ownerUserId ~= userId then
		return nil, "denied"
	end
	local slots: { Types.Slot } = {}
	for _, container in { drop.equipment, drop.backpack } do
		for _, slot in container do
			table.insert(slots, { itemId = slot.itemId, count = slot.count, durability = slot.durability })
		end
	end
	state.drops[dropId] = nil
	return slots, nil
end

-- Whether a member who died may go back in for their bag now.
function Lobby.canReenter(state: State, userId: number, now: number, config: Config): (boolean, ReenterReason?)
	local member = state.members[userId]
	if member == nil then
		return false, "notMember"
	end
	if member.state ~= "dead" then
		return false, "notDead"
	end
	if Lobby.phase(state, now, config) == "closed" then
		return false, "closed"
	end
	if not reentryOpen(state, now, config) then
		return false, "tooLate"
	end
	-- Their own seat is still held; anything else would be over capacity.
	if Lobby.seatsTaken(state, now, config) > config.capacity then
		return false, "full"
	end
	return true, nil
end

-- Re-reserves a dead member's seat for the trip back in (the service charges Energy).
function Lobby.reenter(state: State, userId: number, now: number, config: Config): (boolean, ReenterReason?)
	local ok: boolean, reason: ReenterReason? = Lobby.canReenter(state, userId, now, config)
	if not ok then
		return false, reason
	end
	local member = state.members[userId]
	member.state = "incoming"
	member.reservedAt = now
	return true, nil
end

-- Members who are inside or on their way in.
function Lobby.isEmpty(state: State, now: number, config: Config): boolean
	for _, member in state.members do
		if member.state == "inside" or (member.state == "incoming" and holdsSeat(state, member, now, config)) then
			return false
		end
	end
	return true
end

-- Empty, and nobody who died can still come back for a bag: safe to close early.
function Lobby.canCloseEarly(state: State, now: number, config: Config): boolean
	if state.startedAt == nil or not Lobby.isEmpty(state, now, config) then
		return false
	end
	for _, member in state.members do
		if member.state == "dead" and reentryOpen(state, now, config) then
			return false
		end
	end
	return true
end

--[[
	Closes the lobby now. Everyone still inside (or on the way in) is lost to the
	Fog; their user IDs are returned so the service applies the death rules. Every
	drop is gone.
]]
function Lobby.close(state: State, now: number, reason: string?): { number }
	local lost: { number } = {}
	if state.closedAt and state.closedAt <= now then
		return lost
	end
	state.closedAt = now
	state.closeReason = reason or "fog"
	for userId, member in state.members do
		if member.state == "inside" or member.state == "incoming" then
			member.state = "lost"
			table.insert(lost, userId)
		end
	end
	table.sort(lost)
	state.drops = {}
	return lost
end

-- Advances the lobby to `now`: expires stale reservations and closes it on time.
function Lobby.tick(state: State, now: number, config: Config): TickResult
	local result: TickResult = { expired = {}, lost = {}, closed = false }
	for userId, member in state.members do
		if member.state == "incoming" and now >= member.reservedAt + config.reservationSeconds then
			-- A first-time arrival that never came is dropped; a re-entry that never came
			-- stays dead (their bag is still there).
			member.state = if member.entries > 0 then "dead" else "left"
			table.insert(result.expired, userId)
		end
	end
	table.sort(result.expired)
	if state.closedAt == nil and Lobby.phase(state, now, config) == "closed" then
		local closesAt = Lobby.closesAt(state, config)
		local reason = if state.startedAt == nil then "unused" else "fog"
		result.lost = Lobby.close(state, closesAt or now, reason)
		result.closed = true
	end
	return result
end

return Lobby
