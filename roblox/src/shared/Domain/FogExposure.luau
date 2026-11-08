--!strict
--[[
	FogExposure: Dense and Black fog seep into you over a run (LDOE_PARITY #37). Pure.

	A meter from 0 to `max` rises at the fog tier's rate (Tuning.fogExposure;
	Light fog is 0), slowed by the fogResist of the armor worn (summed, capped at
	maxResist). While it is full, it deals damagePerSecond. It resets when a run
	ends. Better armor sets are what make longer Black-fog runs possible.
]]

local Types = require("../Types")

local FogExposure = {}

export type Config = Types.FogExposureTuning
export type ItemLookup = { [string]: { armor: Types.ArmorStats? } }

local ARMOR_KEYS = { "head", "body", "legs", "feet" }

-- The share of exposure the worn armor blocks.
function FogExposure.resist(equipment: { [string]: Types.Slot }, items: ItemLookup, config: Config): number
	local total = 0
	for _, key in ARMOR_KEYS do
		local slot = equipment[key]
		local item = if slot and slot.count > 0 then items[slot.itemId] else nil
		local armor = item and item.armor
		if armor and armor.fogResist then
			total += armor.fogResist
		end
	end
	return math.clamp(total, 0, config.maxResist)
end

function FogExposure.rate(fogTier: number, resist: number, config: Config): number
	return (config.ratePerTier[fogTier] or 0) * (1 - resist)
end

-- The meter after `dt` seconds in this fog.
function FogExposure.step(value: number, dt: number, fogTier: number, resist: number, config: Config): number
	return math.clamp(value + FogExposure.rate(fogTier, resist, config) * dt, 0, config.max)
end

-- Damage over `dt` seconds at this meter value (only while full).
function FogExposure.damage(value: number, dt: number, config: Config): number
	return if value >= config.max then config.damagePerSecond * dt else 0
end

-- Seconds until the meter is full (math.huge in Light fog).
function FogExposure.secondsToFull(value: number, fogTier: number, resist: number, config: Config): number
	local rate = FogExposure.rate(fogTier, resist, config)
	if value >= config.max then
		return 0
	end
	if rate <= 0 then
		return math.huge
	end
	return (config.max - value) / rate
end

return FogExposure
