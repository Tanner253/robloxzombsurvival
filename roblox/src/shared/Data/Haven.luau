--!strict
--[[
	Haven Square: the public safe-zone hub in the middle of every Neighbourhood
	(MVP_LAUNCH; LDoE's Settlement, rec4). World/Haven builds it, Services/Haven runs it.

	- npcs: who stands where, what they say (LDoE's floating line over the head), their
	  outfit tints on the survivor rig, and what talking to them opens.
	- trader: the Trader's fixed stock in coins (v0.1; Daily Deals come in M2). `buy` is
	  what you buy from her, `sell` what she buys from you.
	- contracts: the daily contract board, three a day per survivor, reset at 00:00 UTC.
	- chapterRewards: what the Trail Keeper hands over for a finished Ember Trail chapter.
	- vip: the VIP Lounge game pass and its perks.
]]

local Types = require("../Types")
local Tuning = require("./Tuning")

local Haven = {}

Haven.npcs = {
	["npc.trader"] = {
		id = "npc.trader",
		name = "Mara",
		title = "Trader",
		role = "trader",
		greeting = "Hey, friend, come over here",
		lines = {
			"Coin for goods, goods for coin. Nobody leaves my stall empty-handed.",
			"Bring me timber and scrap, I'll keep you fed.",
		},
		jacket = "E0A878",
		pants = "A09484",
		keepsPack = false,
	},
	["npc.keeper"] = {
		id = "npc.keeper",
		name = "Old Hale",
		title = "Trail Keeper",
		role = "quests",
		greeting = "Got work, if you've got hands",
		lines = {
			"Three jobs a day on the board. Finish the Trail's chapters and I'll see you right.",
			"Every fire out here started with someone carrying wood. Help them carry it.",
		},
		jacket = "A8B48C",
		pants = "8C8478",
		keepsPack = true,
	},
	["npc.warden"] = {
		id = "npc.warden",
		name = "Rook",
		title = "Lounge Warden",
		role = "vip",
		greeting = "Members keep this fire lit",
		lines = {
			"The Lounge is for members. Warm fire, a crate every day, and more Energy for the road.",
		},
		jacket = "C8786A",
		pants = "7C7470",
		keepsPack = false,
	},
} :: { [string]: Types.HavenNpc }

Haven.trader = {
	-- What she sells, for coins.
	buy = {
		{ itemId = "item.boiled_water", coins = 15 },
		{ itemId = "item.sealed_tin", coins = 25 },
		{ itemId = "item.field_dressing", coins = 40 },
		{ itemId = "item.rope", coins = 20 },
		{ itemId = "item.cloth", coins = 15 },
		{ itemId = "item.plank", coins = 12 },
		{ itemId = "item.rivets", coins = 18 },
		{ itemId = "item.fatwood", coins = 10 },
	} :: { Types.HavenPrice },
	-- What she buys from you, for coins.
	sell = {
		{ itemId = "item.sticks", coins = 1 },
		{ itemId = "item.timber", coins = 2 },
		{ itemId = "item.stone", coins = 2 },
		{ itemId = "item.fiber", coins = 1 },
		{ itemId = "item.scrap", coins = 4 },
		{ itemId = "item.emberberry", coins = 1 },
		{ itemId = "item.plank", coins = 5 },
		{ itemId = "item.scrap_plate", coins = 12 },
	} :: { Types.HavenPrice },
	reachStuds = 14, -- how near the Trader you must stand to trade
}

Haven.contracts = {
	perDay = 3,
	pool = {
		{ id = "contract.timber", itemId = "item.timber", count = 30, coins = 60, xp = 150 },
		{ id = "contract.stone", itemId = "item.stone", count = 30, coins = 60, xp = 150 },
		{ id = "contract.fiber", itemId = "item.fiber", count = 20, coins = 40, xp = 100 },
		{ id = "contract.sticks", itemId = "item.sticks", count = 20, coins = 30, xp = 80 },
		{ id = "contract.scrap", itemId = "item.scrap", count = 15, coins = 75, xp = 180 },
		{ id = "contract.plank", itemId = "item.plank", count = 10, coins = 80, xp = 200 },
		{ id = "contract.rope", itemId = "item.rope", count = 6, coins = 60, xp = 150 },
		{ id = "contract.berries", itemId = "item.emberberry", count = 12, coins = 40, xp = 100 },
		{ id = "contract.cloth", itemId = "item.cloth", count = 6, coins = 60, xp = 150 },
	} :: { Types.HavenContract },
	reachStuds = 14,
}

-- A finished Ember Trail chapter, handed in at the Trail Keeper.
Haven.chapterRewards = {
	["Ashes and Embers"] = {
		coins = 150,
		items = { { itemId = "item.field_dressing", count = 3 }, { itemId = "item.hearth_stew", count = 2 } },
	},
} :: { [string]: { coins: number, items: { Types.ItemStack } } }

Haven.vip = {
	-- The VIP game pass on universe 10775267789 (made through Open Cloud).
	passId = 2075836390,
	priceRobux = Tuning.prices.vipLounge, -- placeholder until the monetization playbook
	icon = "rbxassetid://91515713612492",
	energyCapBonus = 0.2, -- +20% Energy cap while you hold the pass
	-- The daily crate, to the inbox, once a UTC day.
	dailyCrate = {
		{ itemId = "item.sealed_tin", count = 2 },
		{ itemId = "item.boiled_water", count = 2 },
		{ itemId = "item.field_dressing", count = 1 },
		{ itemId = "item.fatwood", count = 4 },
	},
}

return Haven
