--!strict
--[[
	Survival: health, hunger and thirst in the world (Domain/Survival; M1 step 4).

	Meters drain only while the player is in the world: they resume from the
	saved values on join, so time offline is never charged. Every
	Tuning.survival.tickSeconds the server drains the meters, applies threshold
	damage and passive regeneration (both meters at or above regenThreshold) to
	the Humanoid, and saves the result into the profile. Roblox's default health
	regeneration is removed; healing comes only from this, food and level-ups.

	Food energy goes through the Energy service (daily food cap); an item that
	only restores energy (a tonic) uses the "item" rule and is refused at the cap.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Types = require(ReplicatedStorage.Shared.Types)
local SurvivalMath = require(ReplicatedStorage.Shared.Domain.Survival)
local Energy = require("./Energy")
local PlayerData = require("./PlayerData")
local Sync = require("./Sync")

local Survival = {}

local tuning = Content.Tuning
local config = tuning.survival
local maxHealth = tuning.player.maxHealth

type Runtime = {
	meters: SurvivalMath.State,
	died: boolean,
}

local runtime: { [Player]: Runtime } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function save(player: Player)
	local data = PlayerData.get(player)
	local state = runtime[player]
	if data == nil or state == nil then
		return
	end
	local humanoid = humanoidOf(player)
	data.survival.hunger = state.meters.hunger
	data.survival.thirst = state.meters.thirst
	data.survival.updatedAt = state.meters.updatedAt
	if humanoid then
		data.survival.health = humanoid.Health
	elseif state.died then
		data.survival.health = config.respawnHealth
	end
	Sync.mark(player, "survival")
end

local function energyOnly(effect: Types.ConsumeEffect): boolean
	return (effect.energy or 0) > 0 and effect.hunger == nil and effect.thirst == nil and effect.health == nil
end

-- Whether the player can eat or drink `effect` now (alive; tonics below the energy cap).
function Survival.canConsume(player: Player, effect: Types.ConsumeEffect): boolean
	if humanoidOf(player) == nil or runtime[player] == nil then
		return false
	end
	if energyOnly(effect) and not Energy.belowCap(player) then
		Sync.notice(player, "Your energy is already full", "info")
		return false
	end
	return true
end

-- Applies a food, drink or medicine effect.
function Survival.consume(player: Player, effect: Types.ConsumeEffect)
	local state = runtime[player]
	local humanoid = humanoidOf(player)
	if state == nil or humanoid == nil then
		return
	end
	local result = SurvivalMath.consume(state.meters, now(), config, effect)
	state.meters = result.state
	humanoid.Health = math.clamp(humanoid.Health - result.damage + result.heal, 0, humanoid.MaxHealth)
	if result.energy > 0 then
		if energyOnly(effect) then
			Energy.restore(player, result.energy, "item")
		else
			Energy.fromFood(player, result.energy)
		end
	end
	save(player)
end

-- Full health (level-ups).
function Survival.healFull(player: Player)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
		save(player)
	end
end

local function setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local data = PlayerData.get(player)
	local state = runtime[player]
	if humanoid == nil or data == nil or state == nil then
		return
	end
	-- Default regeneration would heal for free; this service owns healing.
	local regen = character:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end
	humanoid.MaxHealth = maxHealth
	humanoid.WalkSpeed = tuning.player.walkSpeed
	-- A short hop only, and no climbing: walls must hold (night defence, raids).
	-- The client disables climbing and spaces hops out (Controllers/Input).
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Content.Tuning.movement.hopHeight
	if state.died then
		-- A death (a run, starving, Reset Character) wakes at the respawn values, never full
		-- (the flow review's F-05): dying is not a meal.
		state.died = false
		local meters, health = SurvivalMath.respawn(config, now())
		state.meters = meters
		humanoid.Health = health
	else
		local saved = data.survival.health
		humanoid.Health = if saved > 0 then math.min(saved, maxHealth) else config.respawnHealth
	end
	humanoid.Died:Connect(function()
		local current = runtime[player]
		if current then
			-- The respawn meters are saved at once, so leaving before the respawn keeps them.
			current.died = true
			current.meters = (SurvivalMath.respawn(config, now()))
			save(player)
		end
	end)
	save(player)
end

local function onLoaded(player: Player, data: any)
	local saved = data.survival
	runtime[player] = {
		meters = SurvivalMath.resume({ hunger = saved.hunger, thirst = saved.thirst, updatedAt = 0 }, now()),
		died = saved.health <= 0,
	}
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
end

local function tick()
	local t = now()
	for player, state in runtime do
		local humanoid = humanoidOf(player)
		if humanoid then
			local before = state.meters.updatedAt
			local meters, damage = SurvivalMath.advance(state.meters, t, config)
			state.meters = meters
			local dt = math.max(0, t - before)
			local regen = if meters.hunger >= config.regenThreshold and meters.thirst >= config.regenThreshold
				then config.regenPerSecond * dt
				else 0
			if damage > 0 or (regen > 0 and humanoid.Health < humanoid.MaxHealth) then
				humanoid.Health = math.clamp(humanoid.Health - damage + regen, 0, humanoid.MaxHealth)
			end
			save(player)
		end
	end
end

function Survival.start()
	Sync.provide("survival", function(player: Player)
		local state = runtime[player]
		if state == nil then
			return false
		end
		local humanoid = humanoidOf(player)
		return {
			health = if humanoid then humanoid.Health else 0,
			maxHealth = maxHealth,
			hunger = state.meters.hunger,
			thirst = state.meters.thirst,
			hungerMax = config.hunger.max,
			thirstMax = config.thirst.max,
			hungerDecay = config.hunger.decayPerSecond,
			thirstDecay = config.thirst.decayPerSecond,
			updatedAt = state.meters.updatedAt,
		}
	end)
	PlayerData.loaded:Connect(onLoaded)
	PlayerData.releasing:Connect(function(player: Player)
		save(player)
		runtime[player] = nil
	end)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	task.spawn(function()
		while true do
			task.wait(config.tickSeconds)
			tick()
		end
	end)
end

return Survival
