--!strict
--[[
	Migrations: upgrades saved data one schema version at a time (ARCHITECTURE.md §6).

	`steps[n]` upgrades data from version n to n + 1 and mutates it in place; the
	runner then sets `data.version = n + 1`. Data newer than the server's target
	version is refused untouched (an older server must never overwrite it).
]]

local Migrations = {}

export type Step = (data: { [string]: any }) -> ...any
export type Steps = { [number]: Step }

--[[
	Upgrades `data` to `targetVersion`. Returns true on success, or false and a
	reason. On failure the data may be partly migrated, so the caller must not
	save it (end the session instead).
]]
function Migrations.run(data: { [string]: any }, steps: Steps, targetVersion: number): (boolean, string?)
	local version = data.version
	if type(version) ~= "number" or version < 1 or version % 1 ~= 0 then
		return false, `data has no valid version (got {tostring(version)})`
	end
	if version > targetVersion then
		return false, `data is version {version}, newer than this server's {targetVersion}`
	end
	while version < targetVersion do
		local step = steps[version]
		if step == nil then
			return false, `no migration from version {version} to {version + 1}`
		end
		local ok, err = pcall(step, data)
		if not ok then
			return false, `migration {version} -> {version + 1} failed: {tostring(err)}`
		end
		version += 1
		data.version = version
	end
	return true, nil
end

return Migrations
