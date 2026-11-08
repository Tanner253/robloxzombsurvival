--!strict
--[[
	Diagnostics: answers the example Ping remote so clients can check Net end to end.

	Studio only (never in live games):
	- grants a test kit when the Workspace attribute `DevKit` is true, so playtests
	  can reach any part of the loop quickly;
	- exposes ServerStorage.EO_Dev, a BindableFunction that tools and the command
	  bar can invoke to drive the real services: ("place", pieceId, x, z, axis?, rot?),
	  ("upgrade", uid), ("demolish", uid), ("give", itemId, count), ("xp", amount),
	  ("learn", blueprintItemId), ("pool", itemId) counts it per pool source, ("inboxgrant", itemId, n),
	  ("testbase") builds a furnished test base, ("rebuildworld") rebuilds
	  the Neighbourhood from code,
	  ("bag", slots) resizes the backpack. place/upgrade return "ok" or the refusal reason.
	  ("clock", hours).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryMath = require(ReplicatedStorage.Shared.Domain.Inventory)
local Net = require("../Net")
local Building = require("./Building")
local PlayerData = require("./PlayerData")
local Plots = require("./Plots")
local Inbox = require("./Inbox")
local Inventory = require("./Inventory")
local Materials = require("./Materials")
local Progression = require("./Progression")
local Scenery = require("./Scenery")
local Sync = require("./Sync")

local Diagnostics = {}

-- What the Studio test kit holds (tools and weapons first, so they land in pockets).
-- A pack frame is equipped first, so materials land in the backpack and pockets keep room.
local DEV_KIT = {
	{ itemId = "item.stone_hatchet", count = 1 },
	{ itemId = "item.stone_pick", count = 1 },
	{ itemId = "item.spiked_club", count = 1 },
	{ itemId = "item.scrapblade", count = 1 },
	{ itemId = "item.timber", count = 60 },
	{ itemId = "item.stone", count = 30 },
	{ itemId = "item.rope", count = 12 },
	{ itemId = "item.fiber", count = 20 },
}

-- A small furnished base for captures: a 3 x 2 deck, an L of walls with a doorway,
-- door and window, a workbench against the wall and a campfire.
local TEST_BASE: { { any } } = {
	{ "build.foundation_wood", 3, 3 },
	{ "build.foundation_wood", 4, 3 },
	{ "build.foundation_wood", 5, 3 },
	{ "build.foundation_wood", 3, 4 },
	{ "build.foundation_wood", 4, 4 },
	{ "build.foundation_wood", 5, 4 },
	{ "build.wall_wood", 3, 3, "h" },
	{ "build.doorway_wood", 4, 3, "h" },
	{ "build.door_wood", 4, 3, "h" },
	{ "build.window_wood", 5, 3, "h" },
	{ "build.wall_wood", 3, 3, "v" },
	{ "build.wall_wood", 3, 4, "v" },
	{ "build.workbench", 12, 18, nil, 1 },
	{ "build.campfire", 17, 17, nil, 0 },
}
local TEST_STOCK = {
	{ itemId = "item.timber", count = 200 },
	{ itemId = "item.stone", count = 60 },
	{ itemId = "item.plank", count = 80 },
	{ itemId = "item.rope", count = 30 },
	{ itemId = "item.scrap", count = 60 },
	{ itemId = "item.fiber", count = 30 },
	{ itemId = "item.sticks", count = 60 },
}

local function devCommand(command: string, ...: any): any
	local player = Players:GetPlayers()[1]
	if player == nil then
		return "no player"
	end
	local args = { ... }
	if command == "place" or command == "upgrade" then
		Building.lastDenied[player] = nil
		if command == "place" then
			Building.place(player, args[1], args[2], args[3], args[4], args[5])
		else
			Building.upgrade(player, args[1])
		end
		return Building.lastDenied[player] or "ok"
	elseif command == "bag" then
		local view = Inventory.view(player)
		local resized = view and InventoryMath.setBackpackCapacity(view, args[1])
		if resized then
			Inventory.commit(player, resized)
		end
	elseif command == "demolish" then
		Building.demolish(player, args[1])
	elseif command == "give" then
		Inventory.give(player, { { itemId = args[1], count = args[2] or 1 } })
	elseif command == "learn" then
		local data = PlayerData.get(player)
		if data then
			data.unlocks.blueprints[args[1]] = true
			Sync.mark(player, "unlocks")
		end
	elseif command == "testbase" then
		local view = Inventory.view(player)
		local resized = view and InventoryMath.setBackpackCapacity(view, 60)
		if resized then
			Inventory.commit(player, resized)
		end
		Progression.grantXp(player, 50_000, "Dev")
		Inventory.give(player, TEST_STOCK)
		local failed: { string } = {}
		for _, step in TEST_BASE do
			Building.lastDenied[player] = nil
			Building.place(player, step[1], step[2], step[3], step[4], step[5])
			if Building.lastDenied[player] then
				table.insert(failed, `{step[1]}: {Building.lastDenied[player]}`)
			end
		end
		return if #failed > 0 then table.concat(failed, ", ") else "ok"
	elseif command == "rebuildworld" then
		-- The fresh-build test inside a playtest: drop everything Scenery makes and
		-- let it build the Neighbourhood again from code.
		workspace.Terrain:Clear()
		local world = workspace:FindFirstChild("World")
		for _, name in { "Dressing", "Trailhead", "FogWall", "Hearth" } do
			local old = world and world:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
		Scenery.start()
	elseif command == "pool" then
		-- ("pool", itemId) -> units per source in draw order, e.g. "pockets=2 inbox=40".
		local MaterialPool = require(ReplicatedStorage.Shared.Domain.MaterialPool)
		local parts = {}
		for _, source in Materials.sources(player) do
			local n = MaterialPool.count({ source }, args[1])
			if n > 0 then
				table.insert(parts, `{source.key}={n}`)
			end
		end
		return table.concat(parts, " ")
	elseif command == "stock" then
		-- ("stock", uid, itemId, count) fills a placed crate directly, for captures.
		local data = PlayerData.get(player)
		local crate = data and data.storage[args[1]]
		if data == nil or crate == nil then
			return "no crate"
		end
		local fresh = table.clone(crate)
		fresh[1] = { itemId = args[2], count = args[3] or 1 }
		data.storage[args[1]] = fresh
		Plots.setCrateIcon(player, args[1], fresh)
		Sync.mark(player, "pool")
	elseif command == "inboxgrant" then
		Inbox.grant(player, { { itemId = args[1], count = args[2] or 1 } }, args[3] or "Event")
	elseif command == "xp" then
		Progression.grantXp(player, args[1], "Dev")
	elseif command == "clock" then
		Lighting.ClockTime = args[1]
	else
		return `unknown command '{command}'`
	end
	return "ok"
end

function Diagnostics.init()
	Net.onInvoke("Ping", function(_player: Player, nonce: number)
		return nonce, workspace:GetServerTimeNow()
	end)
end

function Diagnostics.start()
	if not RunService:IsStudio() then
		return
	end
	local dev = Instance.new("BindableFunction")
	dev.Name = "EO_Dev"
	dev.OnInvoke = devCommand
	dev.Parent = ServerStorage
	PlayerData.loaded:Connect(function(player: Player)
		if workspace:GetAttribute("DevKit") == true then
			task.wait(1)
			if player.Parent == Players then
				Inventory.equipBag(player, "item.pack_frame")
				Inventory.give(player, DEV_KIT)
			end
		end
	end)
end

return Diagnostics
