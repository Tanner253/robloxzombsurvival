--!strict
--[[
	RateLimiter: per-player, per-remote token buckets (ARCHITECTURE.md §8). Pure;
	the caller passes the current time, so it is testable outside Roblox.

	A limit of { count = 5, perSeconds = 1 } allows bursts of up to 5 requests and
	refills at 5 per second.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Limit = {
	count: number,
	perSeconds: number,
}

type Bucket = {
	tokens: number,
	updatedAt: number,
}

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_buckets: { [number]: { [string]: Bucket } },
	},
	RateLimiter
))

function RateLimiter.new(): RateLimiter
	return setmetatable({ _buckets = {} }, RateLimiter)
end

-- Spends one token for `key` (a remote name) on behalf of `userId`. Returns
-- false when the bucket is empty, meaning the request must be dropped.
function RateLimiter.allow(self: RateLimiter, userId: number, key: string, limit: Limit, now: number): boolean
	local perUser = self._buckets[userId]
	if perUser == nil then
		perUser = {}
		self._buckets[userId] = perUser
	end

	local bucket = perUser[key]
	if bucket == nil then
		bucket = { tokens = limit.count, updatedAt = now }
		perUser[key] = bucket
	else
		local refill = math.max(0, now - bucket.updatedAt) * (limit.count / limit.perSeconds)
		bucket.tokens = math.min(limit.count, bucket.tokens + refill)
		bucket.updatedAt = now
	end

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

-- Drops all state for a player (call when they leave).
function RateLimiter.forget(self: RateLimiter, userId: number)
	self._buckets[userId] = nil
end

return RateLimiter
