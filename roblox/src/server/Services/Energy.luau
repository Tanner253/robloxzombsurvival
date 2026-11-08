--!strict
--[[
	Energy: the Run currency (Domain/Energy). In this slice it is shown and
	regenerates; spending arrives with the Fog map.

	Regeneration is computed from the saved timestamp, so the client draws the
	countdown itself from the synced { value, updatedAt }. Food and drink energy
	counts toward Tuning.energy.foodDailyCap per UTC day.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local EnergyMath = require(ReplicatedStorage.Shared.Domain.Energy)
local Analytics = require("./Analytics")
local PlayerData = require("./PlayerData")
local Sync = require("./Sync")

local Energy = {}

local config: EnergyMath.Config = Content.Tuning.energy :: any
local foodDailyCap = Content.Tuning.energy.foodDailyCap
local DAY = 24 * 60 * 60

local function sync(player: Player)
	Sync.mark(player, "energy")
end

-- The player's energy right now (regeneration applied), or nil.
function Energy.current(player: Player): EnergyMath.State?
	local data = PlayerData.get(player)
	if data == nil then
		return nil
	end
	return EnergyMath.current(data.energy, os.time(), config)
end

--[[
	Restores energy with a Domain/Energy mode ("clamp", "item", "grant").
	Returns the amount added (0 when an "item" is refused at the cap).
]]
function Energy.restore(player: Player, amount: number, mode: EnergyMath.RestoreMode): number
	local data = PlayerData.get(player)
	if data == nil or amount <= 0 then
		return 0
	end
	local state, added = EnergyMath.restore(data.energy, os.time(), config, math.floor(amount), mode)
	if state == nil then
		return 0
	end
	data.energy.value = state.value
	data.energy.updatedAt = state.updatedAt
	sync(player)
	if added > 0 then
		Analytics.economy(player, "source", "Energy", added, state.value, mode)
	end
	return added
end

-- Energy from food or drink: "clamp" mode, limited to foodDailyCap per UTC day.
function Energy.fromFood(player: Player, amount: number): number
	local data = PlayerData.get(player)
	if data == nil or amount <= 0 then
		return 0
	end
	local today = os.time() // DAY
	if data.energy.foodDay ~= today then
		data.energy.foodDay = today
		data.energy.foodGained = 0
	end
	local allowed = math.max(0, foodDailyCap - data.energy.foodGained)
	local added = Energy.restore(player, math.min(amount, allowed), "clamp")
	data.energy.foodGained += added
	return added
end

-- Whether an energy item ("item" mode) would be accepted now.
function Energy.belowCap(player: Player): boolean
	local state = Energy.current(player)
	return state ~= nil and state.value < config.cap
end

function Energy.start()
	Sync.provide("energy", function(player: Player)
		local state = Energy.current(player)
		if state == nil then
			return false
		end
		return {
			value = state.value,
			updatedAt = state.updatedAt,
			cap = config.cap,
			secondsPerPoint = config.secondsPerPoint,
		}
	end)
	PlayerData.loaded:Connect(function(player: Player)
		sync(player)
	end)
end

return Energy
