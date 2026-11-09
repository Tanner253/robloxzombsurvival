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
	  ("quests", order?) completes every Ember Trail quest up to that order (default all),
	  unlocking their blueprints, as a playtest shortcut (no rewards are paid).
	  ("clock", hours).
	  Fog Runs: ("fogrun", locationId) queues a run there at once (no Trailhead walk),
	  ("runstate") summarises the run, ("extract") gets out, ("die") ends the survivor,
	  ("equip", itemId, slot) puts a weapon in hand 1 or 2, ("energy", n) sets Energy,
	  ("meter", seconds) ages your lobby by that long, ("looted", n) counts n container
	  searches toward the location quests.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local InventoryMath = require(ReplicatedStorage.Shared.Domain.Inventory)
local Net = require("../Net")
local Building = require("./Building")
local PlayerData = require("./PlayerData")
local Plots = require("./Plots")
local Inbox = require("./Inbox")
local Inventory = require("./Inventory")
local Lobby = require("./Lobby")
local Energy = require("./Energy")
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
	{ "build.foundation_wood", 6, 3 },
	{ "build.foundation_wood", 3, 4 },
	{ "build.foundation_wood", 4, 4 },
	{ "build.foundation_wood", 5, 4 },
	{ "build.foundation_wood", 6, 4 },
	{ "build.foundation_wood", 3, 5 },
	{ "build.foundation_wood", 4, 5 },
	{ "build.foundation_wood", 5, 5 },
	{ "build.foundation_wood", 6, 5 },
	{ "build.wall_wood", 3, 3, "h" },
	{ "build.wall_wood", 4, 3, "h" },
	{ "build.doorway_wood", 5, 3, "h" },
	{ "build.door_wood", 5, 3, "h" },
	{ "build.window_wood", 6, 3, "h" },
	{ "build.wall_wood", 3, 3, "v" },
	{ "build.wall_wood", 3, 4, "v" },
	{ "build.wall_wood", 3, 5, "v" },
	{ "build.woodworking_bench", 12, 12, nil, 3 }, -- back to the west wall, working side to the room
	{ "build.workbench", 12, 16, nil, 3 },
	{ "build.campfire", 19, 18, nil, 0 },
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
	if command == "fogrun" then
		Lobby.enqueue({ player }, args[1], args[2] or "run")
		return "queued"
	elseif command == "runstate" then
		local run = Lobby.runOf(player)
		if run == nil then
			return "no run"
		end
		local band, def = Lobby.band(run.hosted)
		return {
			location = run.hosted.location.id,
			lobby = run.hosted.id,
			band = band,
			bandName = def.name,
			players = #Lobby.playersIn(run.hosted),
			kills = run.stats.kills,
			containers = run.stats.containers,
			map = if run.hosted.map then run.hosted.map:GetFullName() else "none",
		}
	elseif command == "extract" then
		Lobby.extract(player)
		return "ok"
	elseif command == "looted" then
		-- As if the survivor finished searching a container here (location quest checks).
		local run = Lobby.runOf(player)
		if run == nil then
			return "no run"
		end
		for _ = 1, args[1] or 1 do
			require("./Containers").looted:Fire(player, run.hosted)
		end
		return "ok"
	elseif command == "die" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
		return "ok"
	elseif command == "equip" then
		local data = PlayerData.get(player)
		local item = Content.Items[args[1]]
		if data == nil or item == nil then
			return "no such item"
		end
		local key = if args[2] == 2 then "weapon2" else "weapon"
		local equipment = data.inventory.equipment :: any
		equipment[key] = { itemId = item.id, count = 1, durability = item.durability }
		Sync.mark(player, "inventory")
		return "ok"
	elseif command == "energy" then
		local state, config = Energy.state(player)
		if state == nil then
			return "no energy"
		end
		local now = workspace:GetServerTimeNow()
		Energy.set(
			player,
			{ value = math.clamp(args[1], 0, config.hardCap or config.cap), updatedAt = now } :: any,
			0,
			"Dev"
		)
		return "ok"
	elseif command == "meter" then
		local run = Lobby.runOf(player)
		if run == nil then
			return "no run"
		end
		local state: any = run.hosted.state
		for key, value in state do
			if type(value) == "number" and (string.find(key, "At$") or key == "now") then
				state[key] = value - args[1]
			end
		end
		return "aged"
	elseif command == "place" or command == "upgrade" then
		Building.lastDenied[player] = nil
		if command == "place" then
			Building.place(player, args[1], args[2], args[3], args[4], args[5])
		else
			Building.upgrade(player, args[1])
		end
		return Building.lastDenied[player] or "ok"
	elseif command == "bag" then
		local view = Inventory.view(player)
		player:SetAttribute("DevBackpackSlots", args[1])
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
		player:SetAttribute("DevBackpackSlots", 60) -- kept through gear changes (Inventory.apply)
		local resized = view and InventoryMath.setBackpackCapacity(view, 60)
		if resized then
			Inventory.commit(player, resized)
		end
		Progression.grantXp(player, 50_000, "Dev")
		devCommand("quests", 8) -- the home chapter's blueprints
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
	elseif command == "quests" then
		local data = PlayerData.get(player)
		if data == nil then
			return "no data"
		end
		local QuestsMath = require(ReplicatedStorage.Shared.Domain.Quests)
		local upTo = args[1] or math.huge
		local state = data.quests :: any
		for id, quest in Content.Quests do
			if quest.order <= upTo then
				state.completed[id] = os.time()
				state.active[id] = nil
			end
		end
		data.quests = QuestsMath.open(state, Content.Quests) :: any
		Sync.mark(player, "quests")
		return "ok"
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
