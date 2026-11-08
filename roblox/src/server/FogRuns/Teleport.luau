--!strict
--[[
	Teleport: how LobbyService moves players in and out of Fog Run lobbies, behind
	one interface with two implementations (ARCHITECTURE.md §7).

	One place, two server roles (MVP_LAUNCH, decided 2026-11-08): every lobby is a
	reserved server of this same place. A public server is the Neighbourhood (the
	"world" role); a reserved server is one location's lobby (the "run" role). The
	run server learns its location from the lobby directory below, or from the
	first arrival's ticket (FogRuns/RunWorld), and builds that map from code.

	- live: each lobby is a reserved server. A MemoryStore sorted map per location
	  ("FogLobbies_<locationId>") lists the open lobbies with their access code,
	  power band and free seats, so world servers anywhere can match parties into
	  them. Seats are claimed atomically with UpdateAsync.
	- simulated (Studio, where teleports don't work): lobbies are hosted in this
	  same server, each map built beside the Neighbourhood. "Sending" a player calls
	  the host's arrive callback; "sending home" calls its home one.
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.Shared.Data)
local Types = require(ReplicatedStorage.Shared.Types)
local RunTicket = require(ReplicatedStorage.Shared.Domain.RunTicket)

local Teleport = {}

export type LobbyInfo = {
	id: string,
	locationId: string,
	powerBand: number,
	freeSeats: number,
	joinable: boolean,
	seated: { number }?, -- publish only: everyone the run server has seated
}

export type HomeData = {
	v: number,
	lobbyId: string?, -- set when the player died there and may re-enter
	locationId: string?,
	reentryUntil: number?, -- the lobby's re-entry cutoff (UTC seconds)
	result: { [string]: any }?, -- the run's results card, shown once they're home
	death: { [string]: any }?, -- the death screen (cause, what was lost), shown once they're home
}

-- What the simulated adapter needs from LobbyService.
export type Host = {
	host: (lobbyId: string, locationId: string, powerBand: number) -> (),
	arrive: (player: Player, ticket: RunTicket.Ticket) -> (),
	home: (player: Player, data: HomeData) -> (),
}

export type Adapter = {
	kind: "live" | "simulated",
	listOpen: (locationId: string) -> { LobbyInfo },
	create: (locationId: string, powerBand: number, seats: number, ttlSeconds: number) -> (string?, string?),
	claimSeats: (lobbyId: string, locationId: string, userIds: { number }, ttlSeconds: number) -> boolean,
	send: (players: { Player }, ticket: RunTicket.Ticket) -> (boolean, string?),
	sendHome: (player: Player, homePlaceId: number, data: HomeData) -> (boolean, string?),
	publish: (info: LobbyInfo, ttlSeconds: number) -> (),
	unpublish: (lobbyId: string, locationId: string) -> (),
	onFailure: (callback: (player: Player, message: string) -> ()) -> (),
}

export type Role = "world" | "run"

-- The place a location's lobbies run in: this same place, unless the location names
-- its own (run.placeId, kept for a later split into separate places).
function Teleport.placeOf(location: Types.LocationDef): number
	return if location.run.placeId ~= 0 then location.run.placeId else game.PlaceId
end

-- A reserved server of this place hosts one Fog Run lobby; anything else is the Neighbourhood.
function Teleport.role(): Role
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		return "run"
	end
	return "world"
end

-- Whether lobbies can be real reserved servers here (live servers). Studio simulates them.
function Teleport.canGoLive(): boolean
	return not RunService:IsStudio() and game.PlaceId ~= 0
end

local function mapName(locationId: string): string
	return `FogLobbies_{locationId}`
end

local function sorted(locationId: string): MemoryStoreSortedMap
	return MemoryStoreService:GetSortedMap(mapName(locationId))
end

--[[
	The location this reserved server hosts, from the lobby directory the world server
	wrote when it reserved it (keyed by this server's private ID). nil when it can't
	be read; the first arrival's ticket names it then.
]]
function Teleport.locationForServer(): Types.LocationId?
	local serverId = game.PrivateServerId
	if serverId == "" then
		return nil
	end
	for id in Content.Locations do
		local ok, entry = pcall(function()
			return sorted(id):GetAsync(serverId)
		end)
		if ok and type(entry) == "table" then
			return id
		end
	end
	return nil
end

-- Live -------------------------------------------------------------------------------------

type Entry = {
	accessCode: string,
	powerBand: number,
	freeSeats: number,
	joinable: boolean,
	-- Seats claimed by world servers for players still teleporting in (user ID -> expiry,
	-- UTC). The run server's own count can't see them, so it never overwrites them.
	claims: { [string]: number }?,
}

-- How long a claimed seat waits for its player to arrive.
local CLAIM_SECONDS = 90

local function liveClaims(entry: any, stamp: number): number
	local count = 0
	if type(entry.claims) == "table" then
		for userId, expiresAt in entry.claims do
			if type(expiresAt) ~= "number" or expiresAt <= stamp then
				entry.claims[userId] = nil
			else
				count += 1
			end
		end
	end
	return count
end

function Teleport.live(): Adapter
	local failureCallbacks: { (Player, string) -> () } = {}
	TeleportService.TeleportInitFailed:Connect(function(player: Player, _result: Enum.TeleportResult, message: string)
		for _, callback in failureCallbacks do
			task.spawn(callback, player, message)
		end
	end)

	local adapter: Adapter = {
		kind = "live",
		listOpen = function(locationId: string): { LobbyInfo }
			local ok, items = pcall(function()
				return sorted(locationId):GetRangeAsync(Enum.SortDirection.Ascending, 100)
			end)
			local list: { LobbyInfo } = {}
			if not ok or type(items) ~= "table" then
				return list
			end
			for _, item in items :: { any } do
				local value = item.value
				if type(value) == "table" and value.joinable and type(value.freeSeats) == "number" then
					table.insert(list, {
						id = item.key,
						locationId = locationId,
						powerBand = value.powerBand,
						freeSeats = value.freeSeats,
						joinable = true,
					})
				end
			end
			return list
		end,
		create = function(locationId: string, powerBand: number, seats: number, ttlSeconds: number): (string?, string?)
			local location = Content.Locations[locationId]
			if location == nil then
				return nil, "unknown location"
			end
			local ok, code, serverId = pcall(function()
				return TeleportService:ReserveServer(Teleport.placeOf(location))
			end)
			if not ok or type(code) ~= "string" or type(serverId) ~= "string" then
				return nil, tostring(code)
			end
			local entry: Entry = { accessCode = code, powerBand = powerBand, freeSeats = seats, joinable = true }
			local stored = pcall(function()
				sorted(locationId):SetAsync(serverId, entry, ttlSeconds)
			end)
			if not stored then
				return nil, "directory unavailable"
			end
			return serverId, nil
		end,
		claimSeats = function(lobbyId: string, locationId: string, userIds: { number }, ttlSeconds: number): boolean
			local stamp = os.time()
			local ok, result = pcall(function()
				return sorted(locationId):UpdateAsync(lobbyId, function(old: any): any
					if type(old) ~= "table" or not old.joinable or old.freeSeats < #userIds then
						return nil -- leave it as it is
					end
					old.claims = if type(old.claims) == "table" then old.claims else {}
					for _, userId in userIds do
						old.claims[tostring(userId)] = stamp + CLAIM_SECONDS
					end
					old.freeSeats -= #userIds
					return old
				end, ttlSeconds)
			end)
			return ok and result ~= nil
		end,
		send = function(players: { Player }, ticket: RunTicket.Ticket): (boolean, string?)
			local location = Content.Locations[ticket.locationId]
			if location == nil then
				return false, "unknown location"
			end
			local ok, entry = pcall(function()
				return sorted(ticket.locationId):GetAsync(ticket.lobbyId)
			end)
			if not ok or type(entry) ~= "table" or type(entry.accessCode) ~= "string" then
				return false, "lobby gone"
			end
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = entry.accessCode
			options:SetTeleportData(ticket :: any)
			local sent, err = pcall(function()
				TeleportService:TeleportAsync(Teleport.placeOf(location), players, options)
			end)
			return sent, if sent then nil else tostring(err)
		end,
		sendHome = function(player: Player, homePlaceId: number, data: HomeData): (boolean, string?)
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData(data :: any)
			local sent, err = pcall(function()
				TeleportService:TeleportAsync(homePlaceId, { player }, options)
			end)
			return sent, if sent then nil else tostring(err)
		end,
		publish = function(info: LobbyInfo, ttlSeconds: number)
			pcall(function()
				sorted(info.locationId):UpdateAsync(info.id, function(old: any): any
					if type(old) ~= "table" then
						return nil -- only the reserving server writes the access code
					end
					-- Claims for players who have arrived are spent; the rest still hold seats.
					local seated: { number } = info.seated or {}
					if type(old.claims) == "table" then
						for _, userId in seated do
							old.claims[tostring(userId)] = nil
						end
					end
					old.freeSeats = math.max(0, info.freeSeats - liveClaims(old, os.time()))
					old.joinable = info.joinable
					old.powerBand = info.powerBand
					return old
				end, ttlSeconds)
			end)
		end,
		unpublish = function(lobbyId: string, locationId: string)
			pcall(function()
				sorted(locationId):RemoveAsync(lobbyId)
			end)
		end,
		onFailure = function(callback: (Player, string) -> ())
			table.insert(failureCallbacks, callback)
		end,
	}
	return adapter
end

-- Simulated -----------------------------------------------------------------------------------

function Teleport.simulated(host: Host): Adapter
	local lobbies: { [string]: LobbyInfo } = {}
	local nextId = 0
	local adapter: Adapter = {
		kind = "simulated",
		listOpen = function(locationId: string): { LobbyInfo }
			local list: { LobbyInfo } = {}
			for _, info in lobbies do
				if info.locationId == locationId and info.joinable then
					table.insert(list, table.clone(info))
				end
			end
			return list
		end,
		create = function(locationId: string, powerBand: number, seats: number, _ttl: number): (string?, string?)
			nextId += 1
			local id = `sim{nextId}`
			lobbies[id] =
				{ id = id, locationId = locationId, powerBand = powerBand, freeSeats = seats, joinable = true }
			host.host(id, locationId, powerBand)
			return id, nil
		end,
		claimSeats = function(lobbyId: string, _locationId: string, userIds: { number }, _ttl: number): boolean
			local info = lobbies[lobbyId]
			if info == nil or not info.joinable or info.freeSeats < #userIds then
				return false
			end
			info.freeSeats -= #userIds
			return true
		end,
		send = function(players: { Player }, ticket: RunTicket.Ticket): (boolean, string?)
			if lobbies[ticket.lobbyId] == nil then
				return false, "lobby gone"
			end
			for _, player in players do
				task.defer(host.arrive, player, ticket)
			end
			return true, nil
		end,
		sendHome = function(player: Player, _homePlaceId: number, data: HomeData): (boolean, string?)
			task.defer(host.home, player, data)
			return true, nil
		end,
		publish = function(info: LobbyInfo, _ttl: number)
			local existing = lobbies[info.id]
			if existing then
				existing.freeSeats = info.freeSeats
				existing.joinable = info.joinable
				existing.powerBand = info.powerBand
			end
		end,
		unpublish = function(lobbyId: string, _locationId: string)
			lobbies[lobbyId] = nil
		end,
		onFailure = function(_callback: (Player, string) -> ()) end,
	}
	return adapter
end

return Teleport
