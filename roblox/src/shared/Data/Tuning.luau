--!strict
-- Global tuning numbers. Services read these instead of hard-coding values (ARCHITECTURE.md §5).

local Types = require("../Types")

local Tuning: Types.TuningDef = {
	energy = {
		cap = 20,
		secondsPerPoint = 6 * 60,
	},
	inventory = {
		pocketSlots = 6,
		backpackSlots = 8,
		maxBackpackSlots = 32,
		lockedStashSlots = 24,
	},
	raid = {
		lootFraction = 0.3,
	},
	shield = {
		afterRaidSeconds = 8 * 60 * 60,
	},
}

return Tuning
