--!strict
--[[
	DataSafety: the rules that keep saves safe on live servers (MVP_LAUNCH v0.1).

	- Store names: live servers use the real DataStore names; Studio always uses
	  "<name>_Studio", so a playtest can never touch a live save. (Without Studio API
	  access ProfileStore falls back to its in-memory mock by itself.)
	- Loading retries: a session that can't start (the lock is held elsewhere, DataStore
	  hiccups) is retried with a growing delay before the player is asked to rejoin.
	- The audit: the server checks at start that every store is named for its
	  environment, that profiles load through session-locked sessions, and that a
	  shutdown save is bound. Services/PlayerData runs it and reports any problem.
]]

local DataSafety = {}

DataSafety.STUDIO_SUFFIX = "_Studio"
DataSafety.MAX_LOAD_ATTEMPTS = 3
DataSafety.FIRST_RETRY_SECONDS = 2
DataSafety.MAX_RETRY_SECONDS = 15

-- The DataStore name a store uses here.
function DataSafety.storeName(name: string, isStudio: boolean): string
	return if isStudio then name .. DataSafety.STUDIO_SUFFIX else name
end

-- How long to wait before load attempt `attempt` (2, 3, ...): doubling, capped.
function DataSafety.retryDelay(attempt: number): number
	local delay = DataSafety.FIRST_RETRY_SECONDS * 2 ^ math.max(0, attempt - 2)
	return math.min(delay, DataSafety.MAX_RETRY_SECONDS)
end

export type Facts = {
	isStudio: boolean,
	stores: { { base: string, opened: string } }, -- each store: its base name and the name it opened
	sessionLocked: boolean, -- profiles load with StartSessionAsync (ProfileStore's session lock)
	shutdownBound: boolean, -- a BindToClose handler releases (and so saves) every profile
}

-- Every problem with how saves are set up; empty when it is safe.
function DataSafety.audit(facts: Facts): { string }
	local problems: { string } = {}
	for _, store in facts.stores do
		local expected = DataSafety.storeName(store.base, facts.isStudio)
		if store.opened ~= expected then
			table.insert(problems, `store '{store.base}' opened as '{store.opened}', expected '{expected}'`)
		end
	end
	if not facts.sessionLocked then
		table.insert(problems, "profiles must load through session-locked sessions")
	end
	if not facts.shutdownBound then
		table.insert(problems, "no shutdown save is bound (BindToClose)")
	end
	return problems
end

return DataSafety
