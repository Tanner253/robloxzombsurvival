--!strict
--[[
	Rng: a small deterministic random source for pure Domain code.

	Park–Miller "minimal standard" generator (multiplier 48271, modulus 2^31 - 1).
	Every intermediate product stays below 2^53, so the arithmetic is exact in
	Luau doubles and a seed gives the same sequence in Lune and in Studio. It is
	fine for loot rolls and must not be used for anything security-related.

	The method names match Roblox's Random (NextInteger, NextNumber). Services
	seed it, for example with Random.new():NextInteger(1, 2^31 - 2), and can log
	the seed to replay a roll.
]]

local MODULUS = 2147483647
local MULTIPLIER = 48271
local WARMUP_STEPS = 4 -- the first outputs of small seeds are correlated

export type Source = {
	NextInteger: (self: Source, min: number, max: number) -> number,
	NextNumber: (self: Source) -> number,
}

local Rng = {}

-- Creates a source from an integer seed (any integer, including 0 and negatives).
function Rng.new(seed: number): Source
	assert(seed == seed and seed % 1 == 0, "seed must be an integer")
	local state = seed % (MODULUS - 1) + 1 -- 1 .. MODULUS - 1; 0 would stick at 0

	local function step(): number
		state = (state * MULTIPLIER) % MODULUS
		return state
	end
	for _ = 1, WARMUP_STEPS do
		step()
	end

	local source: Source = {
		-- A number in [0, 1).
		NextNumber = function(_self: Source): number
			return (step() - 1) / (MODULUS - 1)
		end,
		-- An integer in [min, max], both inclusive.
		NextInteger = function(self: Source, min: number, max: number): number
			assert(min % 1 == 0 and max % 1 == 0 and min <= max, "NextInteger needs integers with min <= max")
			return min + math.floor(self:NextNumber() * (max - min + 1))
		end,
	}
	return source
end

return Rng
