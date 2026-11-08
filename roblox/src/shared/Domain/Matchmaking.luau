--!strict
--[[
	Matchmaking: who plays with whom on a Fog Run (GAME_DESIGN "Lobbies"; checklist
	12.1). Pure.

	- Gear score from the loadout: the best weapon carried, the armor worn and the
	  bag, each by item tier (Tuning.matchmaking.weights), plus a companion hook for
	  M3 (weight 0 until companions ship).
	- Power = level x levelWeight + gear score; a power band is bandWidth wide.
	- A party is one queue entry, matched at its strongest member's power, so a
	  veteran can't carry newcomers into a soft lobby. Entries are never split.
	- Each tick, oldest first: join the fullest open lobby whose band is within the
	  entry's tolerance (0 bands at first, +1 every widenEverySeconds, up to
	  maxTolerance). An entry that has waited newLobbyAfterSeconds with nothing that
	  fits opens a fresh lobby, and other waiting entries that fit it pile in. So
	  lobbies fill to capacity during their join window and nobody waits long.
	- AI-raider backfill (M2, features.aiRaiders) tops up short lobbies.
]]

local Types = require("../Types")

local Matchmaking = {}

export type Config = Types.MatchmakingTuning

export type Loadout = {
	weaponIds: { Types.ItemId }, -- every weapon carried (the best one counts)
	armorIds: { Types.ItemId }, -- armor worn, one per slot
	bagId: Types.ItemId?,
	companionScore: number?, -- M3: the companion's own rating
}

export type ItemLookup = { [string]: { tier: number, category: Types.ItemCategory, equipSlot: Types.EquipSlot? } }

export type Entry = {
	id: string,
	locationId: Types.LocationId,
	userIds: { number },
	partyId: string?,
	power: number,
	band: number,
	enqueuedAt: number,
}

export type OpenLobby = {
	id: string,
	locationId: Types.LocationId,
	powerBand: number,
	freeSeats: number,
	joinable: boolean,
}

export type Join = { entryId: string, lobbyId: string }
export type NewLobby = { key: string, locationId: Types.LocationId, powerBand: number, entryIds: { string } }

export type Plan = {
	joins: { Join }, -- into lobbies that already exist
	creates: { NewLobby }, -- fresh lobbies to reserve (their entries are matched into them)
	waiting: { string }, -- entry IDs still queued
}

-- The gear score of a loadout (shown on the loadout screen and location panel).
function Matchmaking.gearScore(loadout: Loadout, items: ItemLookup, config: Config): number
	local weights = config.weights
	local bestWeapon = 0
	for _, itemId in loadout.weaponIds do
		local item = items[itemId]
		if item and item.category == "weapon" then
			bestWeapon = math.max(bestWeapon, item.tier)
		end
	end
	local armor = 0
	local seen: { [string]: number } = {}
	for _, itemId in loadout.armorIds do
		local item = items[itemId]
		if item and item.category == "armor" then
			local slot: string = item.equipSlot or itemId
			seen[slot] = math.max(seen[slot] or 0, item.tier) -- one piece per slot counts
		end
	end
	for _, tier in seen do
		armor += tier
	end
	local bag = 0
	local bagItem = if loadout.bagId then items[loadout.bagId] else nil
	if bagItem and bagItem.category == "bag" then
		bag = bagItem.tier
	end
	return bestWeapon * weights.weapon
		+ armor * weights.armor
		+ bag * weights.bag
		+ (loadout.companionScore or 0) * weights.companion
end

--[[
	The loadout a player carries in: weapons from pockets, backpack and the weapon
	slot; armor and the bag from equipment.
]]
function Matchmaking.loadoutOf(
	inventory: Types.Inventory,
	equipment: { [string]: Types.Slot },
	items: ItemLookup,
	companionScore: number?
): Loadout
	local weapons: { Types.ItemId } = {}
	local function addWeapon(slot: Types.Slot?)
		if slot and slot.count > 0 then
			local item = items[slot.itemId]
			if item and item.category == "weapon" then
				table.insert(weapons, slot.itemId)
			end
		end
	end
	for _, slot in inventory.pockets do
		addWeapon(slot)
	end
	for _, slot in inventory.backpack do
		addWeapon(slot)
	end
	addWeapon(equipment.weapon)
	local armor: { Types.ItemId } = {}
	for _, key in { "head", "body", "legs", "feet" } do
		local slot = equipment[key]
		if slot and slot.count > 0 then
			table.insert(armor, slot.itemId)
		end
	end
	local bag = equipment.bag
	return {
		weaponIds = weapons,
		armorIds = armor,
		bagId = if bag and bag.count > 0 then bag.itemId else nil,
		companionScore = companionScore,
	}
end

function Matchmaking.power(level: number, gearScore: number, config: Config): number
	return level * config.levelWeight + gearScore
end

function Matchmaking.band(power: number, config: Config): number
	return math.floor(math.max(0, power) / config.bandWidth) + 1
end

-- How many bands away an entry will accept after waiting `waited` seconds.
function Matchmaking.tolerance(waited: number, config: Config): number
	return math.min(config.maxTolerance, math.floor(math.max(0, waited) / config.widenEverySeconds))
end

-- A queue entry for a solo player or a whole party (matched at its strongest member).
function Matchmaking.entry(
	id: string,
	locationId: Types.LocationId,
	userIds: { number },
	powers: { number },
	partyId: string?,
	now: number,
	config: Config
): Entry
	assert(#userIds > 0 and #userIds == #powers, "one power per member")
	local power = 0
	for _, value in powers do
		power = math.max(power, value)
	end
	return {
		id = id,
		locationId = locationId,
		userIds = table.clone(userIds),
		partyId = partyId,
		power = power,
		band = Matchmaking.band(power, config),
		enqueuedAt = now,
	}
end

-- The best open lobby for an entry now: the fullest that fits, then the nearest band.
function Matchmaking.pickLobby(entry: Entry, lobbies: { OpenLobby }, now: number, config: Config): OpenLobby?
	local tolerance = Matchmaking.tolerance(now - entry.enqueuedAt, config)
	local best: OpenLobby? = nil
	for _, lobby in lobbies do
		local gap = math.abs(lobby.powerBand - entry.band)
		if
			lobby.joinable
			and lobby.locationId == entry.locationId
			and lobby.freeSeats >= #entry.userIds
			and gap <= tolerance
		then
			local better = best == nil
			if best then
				-- Fewest free seats first, then the nearest band, then the ID (deterministic).
				local bestGap = math.abs(best.powerBand - entry.band)
				local sameSeats = lobby.freeSeats == best.freeSeats
				better = lobby.freeSeats < best.freeSeats
					or (sameSeats and gap < bestGap)
					or (sameSeats and gap == bestGap and lobby.id < best.id)
			end
			if better then
				best = lobby
			end
		end
	end
	return best
end

--[[
	One matchmaking pass. `capacity` is Tuning.lobby.capacity. Returns which entries
	join which lobbies, which fresh lobbies to open, and who keeps waiting. Inputs
	are not modified.
]]
function Matchmaking.tick(queue: { Entry }, lobbies: { OpenLobby }, now: number, config: Config, capacity: number): Plan
	local plan: Plan = { joins = {}, creates = {}, waiting = {} }
	local open: { OpenLobby } = {}
	for _, lobby in lobbies do
		table.insert(open, table.clone(lobby))
	end
	local order = table.clone(queue)
	table.sort(order, function(a: Entry, b: Entry): boolean
		if a.enqueuedAt ~= b.enqueuedAt then
			return a.enqueuedAt < b.enqueuedAt
		end
		return a.id < b.id
	end)

	local placed: { [string]: boolean } = {}
	local fresh: { [string]: NewLobby } = {}
	for _, entry in order do
		local lobby = Matchmaking.pickLobby(entry, open, now, config)
		if lobby then
			lobby.freeSeats -= #entry.userIds
			placed[entry.id] = true
			local created = fresh[lobby.id]
			if created then
				table.insert(created.entryIds, entry.id)
			else
				table.insert(plan.joins, { entryId = entry.id, lobbyId = lobby.id })
			end
		elseif now - entry.enqueuedAt >= config.newLobbyAfterSeconds and #entry.userIds <= capacity then
			local key = `new{#plan.creates + 1}`
			local created: NewLobby =
				{ key = key, locationId = entry.locationId, powerBand = entry.band, entryIds = { entry.id } }
			table.insert(plan.creates, created)
			fresh[key] = created
			placed[entry.id] = true
			-- Later entries this tick can pile into it like any open lobby.
			table.insert(open, {
				id = key,
				locationId = entry.locationId,
				powerBand = entry.band,
				freeSeats = capacity - #entry.userIds,
				joinable = true,
			})
		end
	end

	-- Entries older than this one that were waiting may fit a lobby made after them.
	for _, entry in order do
		if not placed[entry.id] then
			local lobby = Matchmaking.pickLobby(entry, open, now, config)
			local created = lobby and fresh[lobby.id]
			if lobby and created then
				lobby.freeSeats -= #entry.userIds
				placed[entry.id] = true
				table.insert(created.entryIds, entry.id)
			else
				table.insert(plan.waiting, entry.id)
			end
		end
	end
	return plan
end

--[[
	M2 hook: how many AI raider bands to add to a lobby with `humans` players.
	Always 0 while features.aiRaiders is off.
]]
function Matchmaking.backfill(humans: number, features: Types.Features, config: Config): number
	if not features.aiRaiders then
		return 0
	end
	return math.max(0, config.aiBackfillTarget - humans)
end

return Matchmaking
