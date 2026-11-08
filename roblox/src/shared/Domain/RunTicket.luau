--!strict
--[[
	RunTicket: what a player carries into a Fog Run lobby (the teleport data). Pure.

	The world server builds a ticket when it sends a party in; the run server reads
	it from the player's join data. Join data can be tampered with, so `parse`
	accepts only the exact shape below with sane values, and the run server still
	checks the lobby ID against its own reserved server and the seat reservation.
]]

local RunTicket = {}

RunTicket.VERSION = 1

export type Ticket = {
	v: number,
	lobbyId: string,
	locationId: string,
	powerBand: number,
	partyId: string?,
	reentry: boolean,
	homePlaceId: number, -- where to send the player back to
	issuedAt: number,
	mode: ("run" | "walk")?, -- how they travelled (the "found on the way" roll); nil for a re-entry
}

local MAX_ID = 64

local function isId(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= MAX_ID and string.match(value, "^[%w%-_%.]+$") ~= nil
end

local function isInteger(value: any, min: number, max: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= min and value <= max
end

function RunTicket.new(
	lobbyId: string,
	locationId: string,
	powerBand: number,
	partyId: string?,
	reentry: boolean,
	homePlaceId: number,
	now: number,
	mode: ("run" | "walk")?
): Ticket
	return {
		mode = mode,
		v = RunTicket.VERSION,
		lobbyId = lobbyId,
		locationId = locationId,
		powerBand = powerBand,
		partyId = partyId,
		reentry = reentry,
		homePlaceId = homePlaceId,
		issuedAt = now,
	}
end

--[[
	Reads untrusted join data. Returns the ticket, or nil and why. `maxAgeSeconds`
	rejects stale tickets (a replayed teleport).
]]
function RunTicket.parse(data: any, now: number, maxAgeSeconds: number): (Ticket?, string?)
	if type(data) ~= "table" then
		return nil, "no ticket"
	end
	if data.v ~= RunTicket.VERSION then
		return nil, "wrong version"
	end
	if not isId(data.lobbyId) or not isId(data.locationId) then
		return nil, "bad IDs"
	end
	if string.match(data.locationId, "^loc%.[%l%d_]+$") == nil then
		return nil, "bad location"
	end
	if not isInteger(data.powerBand, 1, 1000) or not isInteger(data.homePlaceId, 0, 2 ^ 53) then
		return nil, "bad numbers"
	end
	if data.partyId ~= nil and not isId(data.partyId) then
		return nil, "bad party"
	end
	if type(data.reentry) ~= "boolean" then
		return nil, "bad reentry"
	end
	if type(data.issuedAt) ~= "number" or data.issuedAt ~= data.issuedAt then
		return nil, "bad time"
	end
	if data.issuedAt > now + 5 or now - data.issuedAt > maxAgeSeconds then
		return nil, "stale"
	end
	if data.mode ~= nil and data.mode ~= "run" and data.mode ~= "walk" then
		return nil, "bad mode"
	end
	for key in data do
		if
			key ~= "v"
			and key ~= "lobbyId"
			and key ~= "locationId"
			and key ~= "powerBand"
			and key ~= "partyId"
			and key ~= "reentry"
			and key ~= "homePlaceId"
			and key ~= "issuedAt"
			and key ~= "mode"
		then
			return nil, "unknown field"
		end
	end
	return {
		v = data.v,
		lobbyId = data.lobbyId,
		locationId = data.locationId,
		powerBand = data.powerBand,
		partyId = data.partyId,
		reentry = data.reentry,
		homePlaceId = data.homePlaceId,
		issuedAt = data.issuedAt,
		mode = data.mode,
	},
		nil
end

return RunTicket
