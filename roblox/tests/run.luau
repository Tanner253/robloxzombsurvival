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
	{ name = "DevSpeed", spec = require("./DevSpeed.spec") },
	{ name = "Economy", spec = require("./Economy.spec") },
	{ name = "Pacing", spec = require("./Pacing.spec") },
	{ name = "EconomyRules", spec = require("./EconomyRules.spec") },
	{ name = "Converter", spec = require("./Converter.spec") },
	{ name = "Quests", spec = require("./Quests.spec") },
	{ name = "Onboarding", spec = require("./Onboarding.spec") },
	{ name = "Chapter1", spec = require("./Chapter1.spec") },
	{ name = "Shop", spec = require("./Shop.spec") },
	{ name = "DataSafety", spec = require("./DataSafety.spec") },
	{ name = "Credits", spec = require("./Credits.spec") },
	{ name = "Haven", spec = require("./Haven.spec") },
	{ name = "UiAudit", spec = require("./UiAudit.spec") },
	-- Fog Runs (slice 2)
	{ name = "Features", spec = require("./Features.spec") },
	{ name = "Plane", spec = require("./Plane.spec") },
	{ name = "Lobby", spec = require("./Lobby.spec") },
	{ name = "Extraction", spec = require("./Extraction.spec") },
	{ name = "Matchmaking", spec = require("./Matchmaking.spec") },
	{ name = "Combat", spec = require("./Combat.spec") },
	{ name = "Hands", spec = require("./Hands.spec") },
	{ name = "Noise", spec = require("./Noise.spec") },
	{ name = "Flare", spec = require("./Flare.spec") },
	{ name = "HollowAI", spec = require("./HollowAI.spec") },
	{ name = "Containers", spec = require("./Containers.spec") },
	{ name = "TravelBonus", spec = require("./TravelBonus.spec") },
	{ name = "FogTravel", spec = require("./FogTravel.spec") },
	{ name = "FogRunRemotes", spec = require("./FogRunRemotes.spec") },
	{ name = "RunTicket", spec = require("./RunTicket.spec") },
	{ name = "RunSetup", spec = require("./RunSetup.spec") },
	{ name = "FogRegions", spec = require("./FogRegions.spec") },
	{ name = "Neighbours", spec = require("./Neighbours.spec") },
	{ name = "Wildlife", spec = require("./Wildlife.spec") },
	{ name = "Parity", spec = require("./Parity.spec") },
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
