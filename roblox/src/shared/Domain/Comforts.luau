--!strict
--[[
	Comforts: the free comforts on Haven Square's public side (Data/Haven.comforts): the
	Well's clean water and the Soup Kitchen's stew, one per survivor per cooldown.

	The log is the survivor's own (profile haven.comforts: comfort id -> UTC seconds of the
	last take), so the cooldown is per player and survives leaving and rejoining. Pure:
	Services/Haven applies it, the prompt and the tests read it.
]]

local Comforts = {}

export type Comfort = { id: string, cooldownSeconds: number }
export type Log = { [string]: number }

-- When `comfort` is next ready for this survivor (UTC seconds; 0 = never taken).
function Comforts.readyAt(log: Log?, comfort: Comfort): number
	local last = if log then log[comfort.id] else nil
	if type(last) ~= "number" or last <= 0 then
		return 0
	end
	return last + comfort.cooldownSeconds
end

-- Seconds until `comfort` is ready (0 when it is). A clock that ran backwards never makes
-- the wait longer than one cooldown.
function Comforts.remaining(log: Log?, comfort: Comfort, now: number): number
	local readyAt = Comforts.readyAt(log, comfort)
	return math.clamp(readyAt - now, 0, comfort.cooldownSeconds)
end

--[[
	Takes `comfort` at `now`: true and the new log when it is ready, else false, the log
	unchanged and the seconds left. The log is copied, never edited in place.
]]
function Comforts.take(log: Log?, comfort: Comfort, now: number): (boolean, Log, number)
	local current: Log = log or {}
	local left = Comforts.remaining(current, comfort, now)
	if left > 0 then
		return false, current, left
	end
	local nextLog = table.clone(current)
	nextLog[comfort.id] = now
	return true, nextLog, 0
end

-- "9m 12s", "45s": the prompt's countdown.
function Comforts.countdown(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	local minutes = whole // 60
	local rest = whole % 60
	if minutes == 0 then
		return `{rest}s`
	end
	return `{minutes}m {rest}s`
end

return Comforts
