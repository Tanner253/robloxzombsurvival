--!strict
--[[
	Lifecycle: boots a folder of service (server) or controller (client) modules.

	Each ModuleScript in the folder returns a table with optional functions:
	- init(): set up own state, bind remotes and signals. Must not yield and must
	  not call other modules' APIs (they may not be initialised yet).
	- start(): begin work; may call other modules and may yield.

	Every module's init() runs first, in name order, then every start() runs in its
	own thread. A failing init() stops the boot, so problems surface immediately.
]]

local Lifecycle = {}

export type Module = {
	init: (() -> ...any)?,
	start: (() -> ...any)?,
}

local function collect(folder: Instance): { ModuleScript }
	local modules: { ModuleScript } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(modules, child)
		end
	end
	table.sort(modules, function(a: ModuleScript, b: ModuleScript)
		return a.Name < b.Name
	end)
	return modules
end

function Lifecycle.boot(folder: Instance, label: string)
	local loaded: { { name: string, module: Module } } = {}

	for _, moduleScript in collect(folder) do
		local module = (require :: any)(moduleScript) :: Module
		assert(type(module) == "table", `{label}: {moduleScript.Name} must return a table`)
		table.insert(loaded, { name = moduleScript.Name, module = module })
	end

	for _, entry in loaded do
		local init = entry.module.init
		if init then
			local ok, err = pcall(init)
			if not ok then
				error(`{label}: {entry.name}.init() failed: {err}`, 0)
			end
		end
	end

	for _, entry in loaded do
		local start = entry.module.start
		if start then
			task.spawn(function()
				local ok, err = pcall(start)
				if not ok then
					warn(`{label}: {entry.name}.start() failed: {err}`)
				end
			end)
		end
	end

	print(`{label}: booted {#loaded} modules`)
end

return Lifecycle
