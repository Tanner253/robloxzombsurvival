--!strict
--[[
	Player levels 1-20: the total XP needed to reach each level, plus small rewards.
	MVP content; see docs/CONTENT_MVP.md.

	What a level unlocks is not listed here: it comes from the UnlockGates on
	recipes and build pieces and the level gates on locations and station upgrades,
	so there is one source of truth. Every level-up also restores
	Tuning.energy.levelUpRestore Energy and fully heals.

	Pacing target: level 6 (Scrap Metal tier) in a first long session, level 10
	(Black fog) on day 2, level 20 in one to two weeks of regular play.
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
	{ level = 6, xp = 6700, rewards = { { itemId = "item.plank", count = 10 } } },
	{ level = 7, xp = 9400 },
	{ level = 8, xp = 12700, rewards = { { itemId = "item.scrap_plate", count = 4 } } },
	{ level = 9, xp = 16600 },
	{
		level = 10,
		xp = 21200,
		rewards = { { itemId = "item.ember_tonic", count = 2 }, { itemId = "item.rivets", count = 4 } },
	},
	{ level = 11, xp = 26500 },
	{ level = 12, xp = 32600, rewards = { { itemId = "item.brass_gear", count = 1 } } },
	{ level = 13, xp = 39500 },
	{ level = 14, xp = 47300, rewards = { { itemId = "item.hearth_stew", count = 3 } } },
	{
		level = 15,
		xp = 56000,
		rewards = { { itemId = "item.ember_tonic", count = 2 }, { itemId = "item.brass_gear", count = 1 } },
	},
	{ level = 16, xp = 65700 },
	{ level = 17, xp = 76400, rewards = { { itemId = "item.coil_spring", count = 4 } } },
	{ level = 18, xp = 88200 },
	{ level = 19, xp = 101100 },
	{
		level = 20,
		xp = 115200,
		rewards = { { itemId = "item.ember_tonic", count = 3 }, { itemId = "item.brass_gear", count = 2 } },
	},
}

return Levels
