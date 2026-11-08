--!strict
--[[
	Runs every Lune spec and exits non-zero on any failure.
	Usage (from roblox/): lune run tests/run.luau
	Add new spec modules to SPECS.
]]

local process = require("@lune/process")
local TestKit = require("./TestKit")

local SPECS: { { name: string, spec: TestKit.Spec } } = {
	{ name = "DataValidator", spec = require("./DataValidator.spec") },
	{ name = "Inventory", spec = require("./Inventory.spec") },
	{ name = "Timers", spec = require("./Timers.spec") },
	{ name = "PlayerSchema", spec = require("./PlayerSchema.spec") },
	{ name = "Net", spec = require("./Net.spec") },
	{ name = "Rng", spec = require("./Rng.spec") },
	{ name = "Energy", spec = require("./Energy.spec") },
	{ name = "Travel", spec = require("./Travel.spec") },
	{ name = "Survival", spec = require("./Survival.spec") },
	{ name = "Death", spec = require("./Death.spec") },
	{ name = "Loot", spec = require("./Loot.spec") },
	{ name = "Crafting", spec = require("./Crafting.spec") },
	{ name = "Grid", spec = require("./Grid.spec") },
	{ name = "HomeLoop", spec = require("./HomeLoop.spec") },
	{ name = "Clock", spec = require("./Clock.spec") },
	{ name = "MaterialPool", spec = require("./MaterialPool.spec") },
	{ name = "ItemSources", spec = require("./ItemSources.spec") },
}

local passed, failed = 0, 0

for _, entry in SPECS do
	local cases: { { name: string, fn: () -> () } } = {}
	entry.spec(function(name, fn)
		table.insert(cases, { name = name, fn = fn })
	end)

	print(`{entry.name}`)
	for _, case in cases do
		local ok, err = pcall(case.fn)
		if ok then
			passed += 1
			print(`  PASS  {case.name}`)
		else
			failed += 1
			print(`  FAIL  {case.name}\n        {err}`)
		end
	end
end

print(`\n{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
