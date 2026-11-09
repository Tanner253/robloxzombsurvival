--!strict
--[[
	Player levels 1-20: the total XP needed to reach each level, plus small rewards.
	MVP content; see docs/CONTENT_MVP.md.

	What a level unlocks is not listed here: it comes from the UnlockGates on
	recipes and build pieces and the level gates on locations and station upgrades,
	so there is one source of truth. Every level-up also restores
	Tuning.energy.levelUpRestore Energy and fully heals.

	The curve is docs/ECONOMY.md §9.3 (binding). Levels 1-5 are unchanged so the first-hour
	hook still lands at level 5; from level 6 it follows the pacing model's XP with every
	sink on (tests/Pacing.spec): level 8 (Dense fog) on day 2, level 15 (Black fog) around
	day 7 and level 20 at 115,000 XP, for a free player at about 2.5 h a day.
]]

local Types = require("../Types")

local Levels: { Types.PlayerLevelDef } = {
	{ level = 1, xp = 0 },
	{ level = 2, xp = 600, rewards = { { itemId = "item.field_dressing", count = 2 } } },
	{ level = 3, xp = 1500, rewards = { { itemId = "item.sealed_tin", count = 3 } } },
	{ level = 4, xp = 2800 },
	{
		level = 5,
		xp = 4500,
		rewards = { { itemId = "item.arrow", count = 10 }, { itemId = "item.ember_tonic", count = 1 } },
	},
	{ level = 6, xp = 7000, rewards = { { itemId = "item.plank", count = 10 } } },
	{ level = 7, xp = 11000 },
	{ level = 8, xp = 16000, rewards = { { itemId = "item.scrap_plate", count = 4 } } },
	{ level = 9, xp = 21000 },
	{
		level = 10,
		xp = 26000,
		rewards = { { itemId = "item.ember_tonic", count = 2 }, { itemId = "item.rivets", count = 4 } },
	},
	{ level = 11, xp = 32000 },
	{ level = 12, xp = 38000, rewards = { { itemId = "item.brass_gear", count = 1 } } },
	{ level = 13, xp = 44000 },
	{ level = 14, xp = 50000, rewards = { { itemId = "item.hearth_stew", count = 3 } } },
	{
		level = 15,
		xp = 57000,
		rewards = { { itemId = "item.ember_tonic", count = 2 }, { itemId = "item.brass_gear", count = 1 } },
	},
	{ level = 16, xp = 66000 },
	{ level = 17, xp = 76000, rewards = { { itemId = "item.coil_spring", count = 4 } } },
	{ level = 18, xp = 88000 },
	{ level = 19, xp = 101000 },
	{
		level = 20,
		xp = 115000,
		rewards = { { itemId = "item.ember_tonic", count = 3 }, { itemId = "item.brass_gear", count = 2 } },
	},
}

return Levels
