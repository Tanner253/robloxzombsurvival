--!strict
--[[
	Timers: timestamp-based timing with offline progress (ARCHITECTURE.md §1.5).

	Nothing ticks per player. Every timer is a pair of absolute UTC timestamps in
	seconds, and progress is computed from `now` whenever it is needed, including
	when a player loads after being offline. All functions are pure; callers pass
	`now` (the server's os.time() or workspace:GetServerTimeNow()).

	If the clock ever reads earlier than a stored timestamp, elapsed time is
	treated as zero rather than negative.
]]

local Timers = {}

export type Timer = {
	startedAt: number,
	endsAt: number,
}

-- One job in a station queue. Jobs run back to back.
export type Job = {
	id: string, -- what is being made, e.g. a recipe ID
	startsAt: number,
	endsAt: number,
}

export type Queue = { Job }

local function assertDuration(duration: number)
	assert(duration >= 0 and duration == duration, "duration must be a non-negative number")
end

function Timers.start(now: number, duration: number): Timer
	assertDuration(duration)
	return { startedAt = now, endsAt = now + duration }
end

function Timers.remaining(timer: Timer, now: number): number
	return math.max(0, timer.endsAt - now)
end

function Timers.isDone(timer: Timer, now: number): boolean
	return now >= timer.endsAt
end

-- Progress from 0 to 1. A zero-length timer is always complete.
function Timers.progress(timer: Timer, now: number): number
	local length = timer.endsAt - timer.startedAt
	if length <= 0 then
		return 1
	end
	return math.clamp((now - timer.startedAt) / length, 0, 1)
end

--[[
	Appends a job that starts when the last job ends (or now, if the queue is
	idle). Returns the new queue, or nil when the queue already holds `maxSlots`
	unfinished-or-uncollected jobs.
]]
function Timers.enqueue(queue: Queue, now: number, id: string, duration: number, maxSlots: number): Queue?
	assertDuration(duration)
	if #queue >= maxSlots then
		return nil
	end
	local last = queue[#queue]
	local startsAt = if last then math.max(now, last.endsAt) else now
	local result = table.clone(queue)
	table.insert(result, { id = id, startsAt = startsAt, endsAt = startsAt + duration })
	return result
end

-- Splits a queue into the jobs finished by `now` and the jobs still pending.
function Timers.collect(queue: Queue, now: number): (Queue, { Job })
	local pending: Queue = {}
	local finished: { Job } = {}
	for _, job in queue do
		if now >= job.endsAt then
			table.insert(finished, job)
		else
			table.insert(pending, job)
		end
	end
	return pending, finished
end

--[[
	Regenerating value (Energy and similar): one unit per `secondsPerUnit` up to
	`cap`. Takes the stored value and its last-update timestamp and returns the
	new pair. Partial progress toward the next unit is kept by advancing the
	timestamp only by whole units. A value at or above the cap (for example after
	a purchase) is never reduced, and its clock restarts at `now`.
]]
function Timers.accrue(
	value: number,
	updatedAt: number,
	now: number,
	cap: number,
	secondsPerUnit: number
): (number, number)
	assert(secondsPerUnit > 0, "secondsPerUnit must be positive")
	if value >= cap then
		return value, now
	end
	local elapsed = math.max(0, now - updatedAt)
	local gained = math.floor(elapsed / secondsPerUnit)
	local newValue = math.min(cap, value + gained)
	if newValue >= cap then
		return newValue, now
	end
	return newValue, updatedAt + gained * secondsPerUnit
end

return Timers
