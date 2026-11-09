--!strict
--[[
	Haven Square: the public safe-zone hub in the middle of every Neighbourhood
	(MVP_LAUNCH; LDoE's Settlement, rec4). World/Haven builds it, Services/Haven runs it.

	- npcs: who stands where, what they say (LDoE's floating line over the head), their
	  outfit tints on the survivor rig, and what talking to them opens. A members-only NPC
	  stands inside the VIP Lounge; the Gatekeeper says memberGreeting to members.
	- trader: Mara's fixed stock in coins. `buy` is what you buy from her, `sell` what she
	  buys from you.
	- contracts: the daily contract board, three a day per survivor, reset at 00:00 UTC.
	- comforts: the public square's free comforts: the Well and the Soup Kitchen, one item
	  per survivor per cooldown (Domain/Comforts).
	- vipTraders: the Lounge's members-only traders (Quartermaster, Fence): a stock table
	  each, rotated daily (Domain/Market.rotation), priced in coins plus Embers.
	- chapterRewards: what the Trail Keeper hands over for a finished Ember Trail chapter.
	- vip: the VIP Lounge game pass and its perks (playbook §6.1).
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
	-- The Lounge gate (the moment of need): a non-member walking up hears greeting and gets
	-- the JOIN card; members hear memberGreeting.
	["npc.gatekeeper"] = {
		id = "npc.gatekeeper",
		name = "Rook",
		title = "Gatekeeper",
		role = "vip",
		greeting = "Members only, survivor",
		memberGreeting = "Welcome back. The fire is lit for you",
		lines = {
			"Members drink by the brazier, trade with the Quartermaster and carry more Energy.",
			"Behind this rope: the best guns in Haven, a warm seat and a crate every morning.",
		},
		jacket = "3A2C2A",
		pants = "2E2826",
		keepsPack = false,
	},
	-- The Soup Kitchen's cook: talking to her is taking a bowl (comfort.kitchen).
	["npc.cook"] = {
		id = "npc.cook",
		name = "Bess",
		title = "Cook",
		role = "cook",
		greeting = "Soup's on, grab a bowl",
		lines = { "One bowl each, every half hour. Nobody starves on my square." },
		jacket = "B88A64",
		pants = "6E625A",
		keepsPack = false,
		uses = "comfort.kitchen",
	},
	["npc.quartermaster"] = {
		id = "npc.quartermaster",
		name = "Vance",
		title = "Quartermaster",
		role = "quartermaster",
		greeting = "Guns, oiled and true",
		lines = {
			"Every piece on my table is checked and at full wear. New stock at dawn.",
			"You want parts that fit first time? You came to the right man.",
		},
		jacket = "5E6450",
		pants = "4A4840",
		keepsPack = true,
		membersOnly = true,
	},
	["npc.fence"] = {
		id = "npc.fence",
		name = "Juno",
		title = "Fence",
		role = "fence",
		greeting = "Ask for what isn't on the board",
		lines = {
			"Rare parts, good armor, sealed rations. Don't ask where they came from.",
			"What I have today, I may not have tomorrow.",
		},
		jacket = "7A2E34",
		pants = "3C3436",
		keepsPack = false,
		membersOnly = true,
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

-- The public square's free comforts (no membership): one `itemId` per survivor every
-- cooldownSeconds, a server cooldown saved in the profile (survives a rejoin).
Haven.comforts = {
	["comfort.well"] = {
		id = "comfort.well",
		name = "Well",
		verb = "Draw water",
		itemId = "item.boiled_water",
		count = 1,
		cooldownSeconds = 10 * 60,
		reachStuds = 8,
	},
	["comfort.kitchen"] = {
		id = "comfort.kitchen",
		name = "Soup Kitchen",
		verb = "Take a bowl",
		-- Hearth Stew: 60 hunger (and some health and thirst), the square's one hot meal.
		itemId = "item.hearth_stew",
		count = 1,
		cooldownSeconds = 30 * 60,
		reachStuds = 8,
	},
} :: { [string]: Types.HavenComfort }

--[[
	The Lounge's members-only traders, by NPC. Each UTC day a seeded rotation (the same for
	every survivor, Domain/Market.rotation) puts `slots` entries of `stock` on the table,
	leading with a `featured` entry when the table has one. Each entry sells `count` of an
	item at full durability for `coins` plus `embers`, at most perDay times per survivor a
	UTC day.

	Follow-up (data only): S2B's new guns (Duty Pistol, Service Auto, Hand Cannon, Hunting
	Rifle, Suppressed Rifle, Carbine, Marksman Rifle) join the Quartermaster's stock as
	featured rows when their item ids land on this branch; the Reedweave set
	(item.reedweave_*) joins the Fence's when the launch home branch's items do.
]]
Haven.vipTraders = {
	["npc.quartermaster"] = {
		slots = { min = 4, max = 6 },
		salt = 4111,
		reachStuds = 10,
		stock = {
			-- Guns: one always leads the table.
			{
				id = "qm.pipe_pistol",
				itemId = "item.pipe_pistol",
				count = 1,
				coins = 420,
				embers = 35,
				perDay = 1,
				featured = true,
			},
			{
				id = "qm.scrap_shotgun",
				itemId = "item.scrap_shotgun",
				count = 1,
				coins = 600,
				embers = 50,
				perDay = 1,
				featured = true,
			},
			{
				id = "qm.flare_pistol",
				itemId = "item.flare_pistol",
				count = 1,
				coins = 360,
				embers = 30,
				perDay = 1,
				featured = true,
			},
			{ id = "qm.shortbow", itemId = "item.shortbow", count = 1, coins = 220, embers = 15, perDay = 1 },
			-- Weapon parts.
			{ id = "qm.trigger_group", itemId = "item.trigger_group", count = 1, coins = 160, embers = 14, perDay = 2 },
			{ id = "qm.steel_pipe", itemId = "item.steel_pipe", count = 1, coins = 90, embers = 8, perDay = 3 },
			{ id = "qm.coil_spring", itemId = "item.coil_spring", count = 2, coins = 110, embers = 9, perDay = 3 },
			{ id = "qm.brass_gear", itemId = "item.brass_gear", count = 2, coins = 130, embers = 10, perDay = 3 },
		},
	},
	["npc.fence"] = {
		slots = { min = 4, max = 6 },
		salt = 7349,
		reachStuds = 10,
		stock = {
			{ id = "fence.trigger_group", itemId = "item.trigger_group", count = 1, coins = 180, embers = 12, perDay = 1 },
			{ id = "fence.copper_wire", itemId = "item.copper_wire", count = 2, coins = 140, embers = 10, perDay = 2 },
			{ id = "fence.brass_gear", itemId = "item.brass_gear", count = 1, coins = 60, embers = 4, perDay = 3 },
			{ id = "fence.coil_spring", itemId = "item.coil_spring", count = 1, coins = 50, embers = 4, perDay = 3 },
			{ id = "fence.padded_hood", itemId = "item.padded_hood", count = 1, coins = 140, embers = 8, perDay = 1 },
			{
				id = "fence.padded_vest",
				itemId = "item.padded_vest",
				count = 1,
				coins = 260,
				embers = 16,
				perDay = 1,
				featured = true,
			},
			{ id = "fence.rations", itemId = "item.rations", count = 1, coins = 90, embers = 10, perDay = 3 },
		},
	},
} :: { [string]: Types.HavenVipTrader }

-- A finished Ember Trail chapter, handed in at the Trail Keeper.
Haven.chapterRewards = {
	["Ashes and Embers"] = {
		coins = 150,
		items = { { itemId = "item.field_dressing", count = 3 }, { itemId = "item.hearth_stew", count = 2 } },
	},
} :: { [string]: { coins: number, items: { Types.ItemStack } } }

Haven.vip = {
	-- The VIP game pass on universe 10775267789 (made through Open Cloud). Any purchase also
	-- opens the Lounge for Tuning.embers.vipTrialDays (LDoE's VIP 1).
	passId = 2075836390,
	priceRobux = Tuning.prices.robux["product.vip_lounge"],
	icon = "rbxassetid://91515713612492",
	energyCapBonus = 40, -- the Energy cap goes up by this much (200 to 240)
	-- The daily crate, to the inbox, once a UTC day: fixed contents (no odds rule applies).
	dailyCrate = {
		{ itemId = "item.hearth_stew", count = 1 },
		{ itemId = "item.boiled_water", count = 1 },
		{ itemId = "item.field_dressing", count = 1 },
	},
	-- Every 7th consecutive day's crate adds a Trail Ration.
	streakDays = 7,
	streakBonus = { { itemId = "item.rations", count = 1 } },
}

return Haven
