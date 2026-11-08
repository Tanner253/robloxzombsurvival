--[[
	code_sync.luau: puts this worktree's code into Studio without the Rojo plugin (for when
	the plugin is disconnected and nobody can click Connect). Studio's assistant can't
	reach localhost over HTTP, but game:GetObjects can read Studio's own content folder.

	1. From roblox/: build the code trees and copy them into Studio's content folder:
	     rojo build build/code.project.json -o build/eo_code.rbxm
	     cp build/eo_code.rbxm "$LOCALAPPDATA/Roblox/Versions/<studio version>/content/"
	   (build/code.project.json maps src/shared, src/server, src/client and
	   src/first/Loading.client.luau under one Folder; build/ is gitignored, so recreate it
	   from the comment at the end of this file if needed.)
	2. execute_luau (Edit) with this file's body. It replaces ReplicatedStorage.Shared,
	   ServerScriptService.Server, StarterPlayerScripts.Client and ReplicatedFirst.Loading.

	The place file, kit models, materials and Packages are untouched. When the Rojo plugin is
	connected again, it simply takes over.

	build/code.project.json:
	{ "name": "EO_Code", "tree": { "$className": "Folder",
	  "Shared": { "$path": "../src/shared" }, "Server": { "$path": "../src/server" },
	  "Client": { "$path": "../src/client" }, "Loading": { "$path": "../src/first/Loading.client.luau" } } }
]]

local root = game:GetObjects("rbxasset://eo_code.rbxm")[1]
local targets = {
	{ name = "Shared", parent = game:GetService("ReplicatedStorage") },
	{ name = "Server", parent = game:GetService("ServerScriptService") },
	{ name = "Client", parent = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts") },
	{ name = "Loading", parent = game:GetService("ReplicatedFirst") },
}
local report = {}
for _, target in targets do
	local fresh = root:FindFirstChild(target.name)
	local old = target.parent:FindFirstChild(target.name)
	if old then
		old:Destroy()
	end
	fresh.Parent = target.parent
	table.insert(report, `{target.name}: {#fresh:GetDescendants()}`)
end
return table.concat(report, ", ")
