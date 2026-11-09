--!strict
--[[
	Player levels 1-30: the total XP needed to reach each level, plus small rewards.
	MVP content; see docs/CONTENT_MVP.md.

	What a level unlocks is not listed here: it comes from the UnlockGates on
	recipes and build pieces and the level gates on locations and station upgrades,
	so there is one source of truth. Every level-up also restores
	Tuning.energy.levelUpRestore Energy and fully heals.

	The curve is docs/ECONOMY.md §9.3 (binding) to level 20. Levels 1-5 are unchanged so the
	first-hour hook still lands at level 5; from level 6 it follows the pacing model's XP with
	every sink on (tests/Pacing.spec): level 8 (Dense fog) on day 2, level 15 (Black fog)
	around day 7 and level 20 at 115,000 XP, for a free player at about 2.5 h a day.

	Levels 21-30 (the launch cap, docs/research/ldoe-mvp-parity-content.md BR-8) carry the
	curve on: each step is 1,500 XP longer than the last (level 20's step was 14,000), so
	there is no flat tail. In the pacing model (2.5 h a day, chapter 3's quest XP included)
	level 20 lands on day 11, level 25, which the Ember Trail's last quest asks for, on day
	17, and level 30 only after three weeks. Half of them carry a reward, sized like the
	ones below 20.
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
	{ level = 21, xp = 130000 },
	{
		level = 22,
		xp = 146500,
		rewards = { { itemId = "item.hearth_stew", count = 3 }, { itemId = "item.field_dressing", count = 2 } },
	},
	{ level = 23, xp = 164500 },
	{ level = 24, xp = 184000, rewards = { { itemId = "item.coil_spring", count = 4 } } },
	{
		level = 25,
		xp = 205000,
		rewards = { { itemId = "item.ember_tonic", count = 2 }, { itemId = "item.brass_gear", count = 2 } },
	},
	{ level = 26, xp = 227500 },
	{
		level = 27,
		xp = 251500,
		rewards = { { itemId = "item.copper_wire", count = 6 }, { itemId = "item.rivets", count = 6 } },
	},
	{ level = 28, xp = 277000 },
	{ level = 29, xp = 304000 },
	{
		level = 30,
		xp = 332500,
		rewards = {
			{ itemId = "item.ember_tonic", count = 3 },
			{ itemId = "item.brass_gear", count = 3 },
			{ itemId = "item.trigger_group", count = 1 },
		},
	},
}

return Levels
