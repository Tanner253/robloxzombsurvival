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
	  ("equip", itemId, slot, durability?) puts a weapon in hand 1 or 2 (worn down to
	  `durability` if given), ("shoot", studs?) fires the gun in hand once at the nearest Hollow
	  and reports its health and the gun's durability before and after, ("heal") restores the
	  survivor between checks, ("wear", itemId) puts armor in its
	  slot, ("energy", n) sets Energy,
	  ("embers", n) sets the Ember balance, ("deathstate") reports the death screen's wait
  (F-09: holding, Embers, inbox size, Energy, the body), ("meter", seconds) ages your lobby (or, on the death screen, the one you died in) by that long, ("looted", n) counts n container
	  searches toward the location quests. ("npcfeet") reports each Haven NPC's
	  foot-to-ground gap (seated settlers report their seat height).
	  ("navprobe", locationId, enemyId?, trips?) walks virtual Hollow over a built map
	  (checklist 12.9); run it with no lobby open.
	  Scripted playtests: ("kill", range?) kills the nearest Hollow as the survivor and stands
	  them on the spot, ("queststate", questId) reads one trail quest's progress.
	- puts the Dev Armory crate by each claimed plot: one of every weapon and armor piece
	  into the inbox, so the developer can try all the gear.
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
local Models = require("../World/Models")
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
	elseif command == "navprobe" then
		-- Checklist 12.9's nav probe on one built map: ("navprobe", locationId, enemyId?, trips?).
		local map = require("./RunWorld").map(args[1])
		if map == nil then
			return "no map"
		end
		return require("./Hollow").navProbe(map, args[2] or "enemy.shambler", args[3] or 40)
	elseif command == "looted" then
		-- As if the survivor finished searching a container here (location quest checks).
		local run = Lobby.runOf(player)
		if run == nil then
			return "no run"
		end
		for _ = 1, args[1] or 1 do
			require("./Containers").looted:Fire(player, run.hosted, "container")
		end
		return "ok"
	elseif command == "kill" then
		-- The survivor kills the nearest living Hollow within `range` studs (default 400),
		-- through the real damage path, and stands where it fell. Returns its id and spot.
		local run = Lobby.runOf(player)
		local character = player.Character
		if run == nil or character == nil then
			return "no run"
		end
		local HollowService = require("./Hollow")
		local origin = character:GetPivot().Position
		local nearest = HollowService.inArc(run.hosted, origin, 0, args[1] or 400, 360)[1]
		if nearest == nil then
			return "no hollow"
		end
		local at = HollowService.positionOf(run.hosted, nearest.id) or origin
		local _, died = HollowService.damage(run.hosted, nearest.id, 1e6, player)
		character:PivotTo(CFrame.new(at + Vector3.new(0, 3, 0)))
		return { id = nearest.id, died = died, at = { at.X, at.Y, at.Z } }
	elseif command == "queststate" then
		-- One Ember Trail quest as the profile has it: its progress by objective, or done.
		local data = PlayerData.get(player)
		if data == nil then
			return "no data"
		end
		local quests = data.quests :: any
		local active = quests.active[args[1]]
		return {
			completed = quests.completed[args[1]] ~= nil,
			active = active ~= nil,
			progress = if active then table.clone(active.progress) else nil,
		}
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
		equipment[key] = { itemId = item.id, count = 1, durability = args[3] or item.durability }
		Sync.mark(player, "inventory")
		Inventory.refreshGear(player) -- the held and holstered models follow
		return "ok"
	elseif command == "heal" then
		require("./Survival").healFull(player)
		return "ok"
	elseif command == "approach" then
		-- Stands the survivor `args[1]` studs (default 4) off the nearest living Hollow, on the
		-- ground, facing it, for melee checks. Returns its id, health and the yaw to it.
		local run = Lobby.runOf(player)
		local character = player.Character
		if run == nil or character == nil then
			return "no run"
		end
		local HollowService = require("./Hollow")
		local origin = character:GetPivot().Position
		local nearest = HollowService.inArc(run.hosted, origin, 0, 400, 360)[1]
		local at = nearest and HollowService.positionOf(run.hosted, nearest.id)
		if nearest == nil or at == nil then
			return "no hollow"
		end
		local away = Vector3.new(origin.X - at.X, 0, origin.Z - at.Z)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
		local stand = at + away * (args[1] or 4)
		local ground = RaycastParams.new()
		ground.FilterType = Enum.RaycastFilterType.Exclude
		ground.FilterDescendantsInstances = { character }
		local floor = workspace:Raycast(Vector3.new(stand.X, at.Y + 40, stand.Z), Vector3.new(0, -120, 0), ground)
		local height = (if floor then floor.Position.Y else at.Y) + 3
		character:PivotTo(CFrame.lookAt(Vector3.new(stand.X, height, stand.Z), Vector3.new(at.X, height, at.Z)))
		return {
			id = nearest.id,
			hp = HollowService.hpOf(run.hosted, nearest.id),
			yaw = math.atan2(at.X - stand.X, at.Z - stand.Z),
		}
	elseif command == "hold" then
		-- Puts weapon slot `args[1]` (1 or 2) in hand, as the WeaponSelect remote does (on a run
		-- through Combat's hands). Returns the hand ref.
		local n = if args[1] == 2 then 2 else 1
		local hook = Inventory.combat
		if hook and hook.active(player) then
			hook.select(player, n)
		end
		Inventory.setActiveWeapon(player, n)
		return Inventory.handRef(player)
	elseif command == "shoot" then
		-- Fires the gun in hand once at the nearest living Hollow through the real fire path
		-- (reloading first when the magazine is empty), from `args[1]` studs away (default 10).
		-- Returns the Hollow's health and the gun's durability before and after.
		local run = Lobby.runOf(player)
		local character = player.Character
		local data = PlayerData.get(player)
		if run == nil or character == nil or data == nil then
			return "no run"
		end
		local CombatService = require("./Combat")
		local HollowService = require("./Hollow")
		-- The hand the gun is in now: a gun that breaks hands over to the other slot.
		local key = if Inventory.activeWeapon(player) == 2 then "weapon2" else "weapon"
		local function gun(): any
			local slot = (data.inventory.equipment :: any)[key]
			return if slot and slot.count > 0 then slot else nil
		end
		local held = gun()
		local def = held and Content.Items[held.itemId]
		local firearm = def and def.weapon and def.weapon.firearm
		if held == nil or firearm == nil then
			return "no gun in hand"
		end
		if CombatService.dev.loaded(player) == 0 then
			CombatService.dev.reload(player)
			task.wait(firearm.reloadSeconds + 0.2)
		end
		local origin = character:GetPivot().Position
		local nearest = HollowService.inArc(run.hosted, origin, 0, 400, 360)[1]
		local at = nearest and HollowService.positionOf(run.hosted, nearest.id)
		if nearest == nil or at == nil then
			return "no hollow"
		end
		-- Stand `distance` studs off it, on the survivor's side, facing it.
		local away = Vector3.new(origin.X - at.X, 0, origin.Z - at.Z)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
		local stand = at + away * (args[1] or 10)
		-- On the ground there (the map is hilly): the survivor's pivot rides 3 studs above it.
		local ground = RaycastParams.new()
		ground.FilterType = Enum.RaycastFilterType.Exclude
		ground.FilterDescendantsInstances = { character }
		local floor = workspace:Raycast(Vector3.new(stand.X, at.Y + 40, stand.Z), Vector3.new(0, -120, 0), ground)
		local height = (if floor then floor.Position.Y else at.Y) + 3
		character:PivotTo(CFrame.lookAt(Vector3.new(stand.X, height, stand.Z), Vector3.new(at.X, height, at.Z)))
		task.wait(0.1)
		at = HollowService.positionOf(run.hosted, nearest.id) or at
		local from = character:GetPivot().Position
		local before = { hp = HollowService.hpOf(run.hosted, nearest.id), durability = held.durability }
		-- What stands between the muzzle and the Hollow, if anything (a wall stops a round).
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.RespectCanCollide = true -- as Combat's shots: only solid things stop a round
		local muzzle = from + Vector3.new(0, 1.5, 0)
		local toward = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
		local wall = workspace:Raycast(muzzle, Vector3.new(at.X, at.Y + 3.5, at.Z) - muzzle, params)
		CombatService.dev.fire(player, math.atan2(at.X - from.X, at.Z - from.Z), nearest.id)
		task.wait(0.4)
		local after = gun()
		return {
			gun = held.itemId,
			hand = key,
			target = nearest.id,
			distance = toward.Magnitude,
			blockedBy = if wall then wall.Instance:GetFullName() else nil,
			hpBefore = before.hp,
			hpAfter = HollowService.hpOf(run.hosted, nearest.id) or 0,
			durabilityBefore = before.durability,
			durabilityAfter = if after and after.itemId == held.itemId then after.durability else 0,
			broke = after == nil or after.itemId ~= held.itemId,
			loaded = CombatService.dev.loaded(player),
		}
	elseif command == "npcfeet" then
		-- Every standing Haven NPC's gap between its lowest foot point and the ground under
		-- it (studs); the check wants each within 0.15.
		local HavenWorld = require("../World/Haven")
		local haven = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Haven")
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		local report = {}
		for _, humanoid in (if haven then haven:GetDescendants() else {}) do
			if humanoid:IsA("Humanoid") and humanoid.Parent and humanoid.Parent:IsA("Model") then
				local rig = humanoid.Parent :: Model
				local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
				local low = HavenWorld.lowestFoot(rig)
				if root and low then
					local hit = workspace:Raycast(root.Position + Vector3.new(0, 5, 0), Vector3.new(0, -40, 0), params)
					local gap = if hit then low - hit.Position.Y else 999
					table.insert(report, string.format("%s %.3f", rig.Name, gap))
				end
			end
		end
		return table.concat(report, " | ")
	elseif command == "wear" then
		local data = PlayerData.get(player)
		local item = Content.Items[args[1]]
		local slot = item and item.equipSlot
		if data == nil or item == nil or slot == nil or slot == "weapon" then
			return "not armor or a bag"
		end
		local equipment = data.inventory.equipment :: any
		equipment[slot] = { itemId = item.id, count = 1, durability = item.durability }
		Sync.mark(player, "inventory")
		Inventory.refreshGear(player)
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
	elseif command == "embers" then
		local data = PlayerData.get(player)
		if data == nil then
			return "no profile"
		end
		data.embers = math.max(0, math.floor(args[1]))
		Sync.mark(player, "wallet")
		return "ok"
	elseif command == "deathstate" then
		local data = PlayerData.get(player)
		local energy = Energy.state(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return {
			holding = Lobby.holding(player),
			onRun = Lobby.runOf(player) ~= nil,
			busy = Lobby.busy(player),
			embers = if data then data.embers else nil,
			inbox = if data then #data.inbox else nil,
			energy = if energy then energy.value else nil,
			alive = humanoid ~= nil and humanoid.Health > 0,
			anchored = root ~= nil and root.Anchored,
		}
	elseif command == "meter" then
		-- Your lobby, or the one you died in while you are still on the death screen.
		local run = Lobby.runOf(player)
		local hosted = if run then run.hosted else Lobby.heldIn(player)
		if hosted == nil then
			return "no run"
		end
		local state: any = hosted.state
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

--[[
	The Dev Armory (Studio only, hard-off in live games): a crate by every claimed plot's
	road edge that puts one of every weapon and armor piece in the inbox, so the developer
	can see and try all the gear. It's a plain Roblox prompt; players never see it.
]]
local function armoryGrant(player: Player)
	local slots: { any } = {}
	for id, item in Content.Items do
		if item.category == "weapon" or item.category == "armor" then
			table.insert(slots, { itemId = id, count = 1, durability = item.durability })
		end
	end
	table.sort(slots, function(a, b)
		return a.itemId < b.itemId
	end)
	Inbox.grant(player, slots :: any, "Dev Armory")
end

local function devArmory(player: Player, plot: any)
	local name = `EO_DevArmory_{player.UserId}`
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local crate = Models.kit({ "EO_StorageCrate", "Crate" })
	if crate == nil then
		return
	end
	crate.Name = name
	local spawn = Plots.spawnCFrame(plot)
	local at = spawn * CFrame.new(7, 0, 0)
	crate:PivotTo(CFrame.new(at.Position.X, plot.origin.Y, at.Position.Z) * spawn.Rotation)
	local body = crate:FindFirstChildWhichIsA("BasePart", true)
	if body == nil then
		crate:Destroy()
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Dev Armory (Studio only)"
	prompt.ActionText = "Take every weapon and armor piece"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(who: Player)
		if who == player then
			armoryGrant(who)
		end
	end)
	prompt.Parent = body
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(220, 30)
	label.StudsOffsetWorldSpace = Vector3.new(0, crate:GetExtentsSize().Y + 1.5, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 80
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "DEV ARMORY (Studio)"
	text.TextColor3 = Color3.fromRGB(255, 210, 122)
	text.TextStrokeTransparency = 0.3
	text.TextScaled = true
	text.FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold)
	text.Parent = label
	label.Parent = body
	crate.Parent = workspace
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
	-- The Dev Armory crate by each claimed plot (Studio only; this start() returns in live games).
	Plots.claimed:Connect(function(player: Player, plot: any)
		task.defer(devArmory, player, plot)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local crate = workspace:FindFirstChild(`EO_DevArmory_{player.UserId}`)
		if crate then
			crate:Destroy()
		end
	end)
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
