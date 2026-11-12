--!strict
--[[
	Contracts: the daily contract board at Haven Square (Data/Haven.contracts). Each
	survivor gets `perDay` contracts a UTC day, the same all day (seeded by the day and the
	user), each delivered once for coins and XP. A new day brings a fresh three. The board
	asks only for what the player can get now (`eligible`, the flow review's F-35: a contract
	for Planks before the Saw Bench was a dead card).
]]

local Rng = require("./Rng")

local Contracts = {}

export type Contract = { id: string, itemId: string, count: number, coins: number, xp: number }
export type State = { day: number, done: { [string]: boolean } }

local DAY = 24 * 60 * 60

function Contracts.dayOf(now: number): number
	return now // DAY
end

-- The pool's contracts whose item the player can get now (gathered, or made with what is
-- unlocked), in pool order.
function Contracts.eligible(pool: { Contract }, canGet: (itemId: string) -> boolean): { Contract }
	local result: { Contract } = {}
	for _, contract in pool do
		if canGet(contract.itemId) then
			table.insert(result, contract)
		end
	end
	return result
end

-- The day's contracts for this survivor: `count` distinct entries of the pool.
function Contracts.forDay(pool: { Contract }, count: number, userId: number, day: number): { Contract }
	local random = Rng.new(day * 7919 + userId % 1000003)
	local indices: { number } = {}
	for index = 1, #pool do
		table.insert(indices, index)
	end
	local picked: { Contract } = {}
	for _ = 1, math.min(count, #pool) do
		local slot = random:NextInteger(1, #indices)
		table.insert(picked, pool[indices[slot]])
		table.remove(indices, slot)
	end
	return picked
end

-- Today's state: yesterday's deliveries don't carry over.
function Contracts.today(state: State?, day: number): State
	if state == nil or state.day ~= day then
		return { day = day, done = {} }
	end
	return state
end

-- Whether a contract on today's board can be delivered (not yet done, on the board).
function Contracts.canDeliver(board: { Contract }, state: State, contractId: string): (boolean, Contract?)
	if state.done[contractId] then
		return false, nil
	end
	for _, contract in board do
		if contract.id == contractId then
			return true, contract
		end
	end
	return false, nil
end

return Contracts
