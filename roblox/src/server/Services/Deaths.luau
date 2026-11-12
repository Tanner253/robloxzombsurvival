--!strict
--[[
	Deaths: dying at home (the flow review's F-05). Run deaths are Services/Lobby's.

	Nothing hunts you at home, so a home death is starving, thirst or Roblox's Reset
	Character (which kills the Humanoid, so it comes through here too). Like LDoE, it drops
	what you carry, pockets and backpack, as a bag where you fell (Domain/Death.drop); your
	equipment stays on. The bag is an ordinary ground drop (Services/Drops): only you can pick
	it up, and it lasts Tuning.drops.lifetimeSeconds. You wake on your Reed Doormat, or at the
	plot's road edge (Plots.spawnCFrame), at the respawn values (Services/Survival), never
	full: a reset before a run costs a walk back for your things and leaves you hungry.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local DeathMath = require(ReplicatedStorage.Shared.Domain.Death)
local OnRun = require("../OnRun")
local Analytics = require("./Analytics")
local Drops = require("./Drops")
local Inventory = require("./Inventory")
local PlayerData = require("./PlayerData")
local Sync = require("./Sync")

local Deaths = {}

local deathConfig: any = Content.Tuning.death -- Domain/Death.Config
local seq = 0

-- Drops what `player` carries at `position`, as a bag on the ground.
local function dropAtHome(player: Player, position: Vector3)
	-- Without a sack model there is nowhere to put it: the carried items stay carried.
	if OnRun.is(player) or PlayerData.get(player) == nil or not Art.dropReady() then
		return
	end
	local view = Inventory.view(player)
	if view == nil then
		return
	end
	seq += 1
	local inventory, bag = DeathMath.drop(view, {
		id = `home{seq}`,
		ownerUserId = player.UserId,
		locationId = "home",
		now = os.time(),
		despawnAt = os.time() + Content.Tuning.drops.lifetimeSeconds, -- the ground drop's own life
	}, deathConfig)
	if bag == nil then
		return -- nothing carried
	end
	Inventory.commit(player, inventory)
	Drops.spawn(player, position, bag.contents, true)
	Sync.notice(player, "You dropped what you carried where you fell. Go back for it.", "warn")
	Analytics.custom(player, "HomeDeath", #bag.contents)
end

local function watch(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Once(function()
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		dropAtHome(player, if root then root.Position else character:GetPivot().Position)
	end)
end

function Deaths.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			watch(player, character)
		end)
		if player.Character then
			task.spawn(watch, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return Deaths
