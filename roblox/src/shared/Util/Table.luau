--!strict
-- Small, pure table helpers shared by Domain, Data and tests.

local TableUtil = {}

local function copyAny(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = copyAny(child)
	end
	return copy
end

-- Returns a deep copy of a plain-data table. Metatables are not copied.
function TableUtil.deepCopy<T>(value: T): T
	return copyAny(value)
end

-- Freezes a table and every table inside it, then returns it.
function TableUtil.deepFreeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, child in value :: any do
			TableUtil.deepFreeze(child)
		end
		table.freeze(value :: any)
	end
	return value
end

-- Returns the keys of a dictionary in sorted order, for deterministic iteration.
function TableUtil.sortedKeys<V>(dict: { [string]: V }): { string }
	local keys = {}
	for key in dict do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

return TableUtil
