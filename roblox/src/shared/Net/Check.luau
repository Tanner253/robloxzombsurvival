--!strict
--[[
	Check: argument validators for remotes (ARCHITECTURE.md §8). Pure.

	A Check tests one value. `Check.args(...)` combines Checks into a Validator for
	a remote's whole argument list, and also rejects extra or missing arguments.
	These only check shape and range; services still check ownership, distance and
	cooldowns, which need world state.
]]

local Check = {}

export type Check = (value: any) -> (boolean, string?)
export type Validator = (...any) -> (boolean, string?)

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Check.number(min: number, max: number): Check
	return function(value)
		if not isFiniteNumber(value) then
			return false, "expected a finite number"
		end
		if value < min or value > max then
			return false, `number out of range [{min}, {max}]`
		end
		return true, nil
	end
end

function Check.integer(min: number, max: number): Check
	local inRange = Check.number(min, max)
	return function(value)
		local ok, reason = inRange(value)
		if not ok then
			return false, reason
		end
		if value % 1 ~= 0 then
			return false, "expected an integer"
		end
		return true, nil
	end
end

function Check.string(maxLength: number): Check
	return function(value)
		if type(value) ~= "string" then
			return false, "expected a string"
		end
		if #value > maxLength then
			return false, `string longer than {maxLength}`
		end
		if utf8.len(value) == nil then
			return false, "string is not valid UTF-8"
		end
		return true, nil
	end
end

function Check.boolean(): Check
	return function(value)
		if type(value) ~= "boolean" then
			return false, "expected a boolean"
		end
		return true, nil
	end
end

-- A content ID with the given prefix, e.g. Check.contentId("item") accepts "item.wood".
-- Whether the ID exists is checked by the service against Data.
function Check.contentId(prefix: string): Check
	local pattern = "^" .. prefix .. "%.[%l%d_]+$"
	return function(value)
		if type(value) ~= "string" or #value > 64 or string.match(value, pattern) == nil then
			return false, `expected a '{prefix}.*' ID`
		end
		return true, nil
	end
end

function Check.optional(inner: Check): Check
	return function(value)
		if value == nil then
			return true, nil
		end
		return inner(value)
	end
end

-- Rejects every call. For server-to-client remotes that clients must never send.
function Check.never(): Validator
	return function()
		return false, "clients may not send this remote"
	end
end

-- Validates an exact argument list: one Check per argument, no extras.
function Check.args(...: Check): Validator
	local checks = { ... }
	return function(...)
		local count = select("#", ...)
		if count > #checks then
			return false, `expected at most {#checks} arguments, got {count}`
		end
		local values = { ... }
		for index, check in checks do
			local ok, reason = check(values[index])
			if not ok then
				return false, `argument {index}: {reason}`
			end
		end
		return true, nil
	end
end

return Check
