--!strict
--[[
	TestKit: a tiny test harness for Lune.

	A spec module returns `function(test: TestKit.Register)` and calls
	`test("name", function() ... end)` for each case. Assertions raise errors;
	tests/run.luau collects and reports them.
]]

local TestKit = {}

export type Register = (name: string, fn: () -> ()) -> ()
export type Spec = (test: Register) -> ()

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function TestKit.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {show(expected)}, got {show(actual)}`, 2)
	end
end

function TestKit.deepEqual(actual: any, expected: any, label: string?)
	if not deepEqual(actual, expected) then
		error(`{label or "value"}: tables differ`, 2)
	end
end

function TestKit.truthy(value: any, label: string?)
	if not value then
		error(`{label or "value"}: expected truthy, got {show(value)}`, 2)
	end
end

function TestKit.throws(fn: () -> (), pattern: string?)
	local ok, err = pcall(fn)
	if ok then
		error("expected an error, but none was raised", 2)
	end
	if pattern and not string.find(tostring(err), pattern, 1, true) then
		error(`error {show(tostring(err))} does not contain {show(pattern)}`, 2)
	end
end

-- Asserts that some string in `list` contains `fragment`.
function TestKit.anyContains(list: { string }, fragment: string, label: string?)
	for _, entry in list do
		if string.find(entry, fragment, 1, true) then
			return
		end
	end
	error(`{label or "list"}: no entry contains {show(fragment)} (got {#list} entries)`, 2)
end

return TestKit
