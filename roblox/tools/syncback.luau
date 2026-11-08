--!strict
--[[
	syncback: copies the place's non-script content (the kit masters, the survivor
	character and rigs, material sets) out of a saved place file into the repo as .rbxm
	models under place/kit/, so `rojo build` rebuilds the whole place from the repo.

	Usage (from roblox/): lune run tools/syncback.luau [place/ember.rbxl]
	Everything else in the place is code: scripts and data (src/), terrain, lighting,
	dressing and plots (Services/Scenery, Services/Plots), deck materials (place/materials).
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local source = process.args[1] or "place/ember.rbxl"
local game = roblox.deserializePlace(fs.readFile(source))

-- service, child name -> file under place/kit/
local EXTRACT = {
	{ "ServerStorage", "EO_Kit" },
	{ "ServerStorage", "LT_Gen" },
	{ "ServerStorage", "Survivor_v3_standin" },
	{ "ServerStorage", "EO_SurvivorStatic" },
	{ "ServerStorage", "EO_SurvivorRig_display" },
	{ "StarterPlayer", "StarterCharacter", "keepScripts" }, -- its Animate script drives idle/walk/run
	{ "MaterialService", "AssistantMaterials" },
}

if not fs.isDir("place/kit") then
	fs.writeDir("place/kit")
end

local wrote = 0
for _, entry in EXTRACT do
	local service = game:GetService(entry[1])
	local instance = service:FindFirstChild(entry[2])
	if instance == nil then
		print(`skip {entry[1]}.{entry[2]} (not in {source})`)
		continue
	end
	-- Scripts never ride along in art (ART_DIRECTION §10: strip scripts from models);
	-- only the character keeps its own.
	local stripped = 0
	if entry[3] ~= "keepScripts" then
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
				stripped += 1
			end
		end
	end
	local path = `place/kit/{entry[2]}.rbxm`
	fs.writeFile(path, roblox.serializeModel({ instance }))
	wrote += 1
	print(`{path}: {#instance:GetDescendants()} descendants{if stripped > 0 then `, {stripped} scripts stripped` else ""}`)
end
print(`{wrote} models written`)
