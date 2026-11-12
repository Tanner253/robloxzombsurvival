--!strict
--[[
	Global tuning numbers. Services read these instead of hard-coding values (ARCHITECTURE.md §5).
	Every number here is one that no single content definition owns.
	MVP values; the reasoning and the LDoE comparison are in docs/CONTENT_MVP.md.
]]

local Types = require("../Types")

local Tuning: Types.TuningDef = {
	-- Studio playtests only: timers, yields, regen and XP sped up by this much
	-- (Shared/DevSpeed). Live servers always run at 1.
	devSpeed = 1, -- timers only, opt-in: Workspace attribute "DevSpeed" in Studio (Shared/DevSpeed)
	energy = {
		-- LDOE_PARITY #38: 1 per 5 min, as LDoE; Runs cost 15/22/33 by fog tier (Data/Locations).
		-- The cap is 120, not LDoE's 200 (the flow review's F-16): at 200 a night's regen was
		-- all banked and a 2.5 h-a-day player never ran dry (5 short moments in 233 runs in
		-- Pacing.spec); at 120 the night tops out, the Black-heavy sessions run short (33) and
		-- the Refill, Rations and VIP's +40 cap have a moment. A new player starts full.
		cap = 120,
		secondsPerPoint = 5 * 60,
		hardCap = 400,
		levelUpRestore = 20,
		foodDailyCap = 40,
		-- The content parity audit's BR-9: all location quests together pay at most this many
		-- Trail Rations (60 Energy each) a UTC day per player, whatever their data says
		-- (Domain/Quests.payLocationQuest). 0 since F-16: 2 a day was 120 free Energy, a whole
		-- cap, and the dailies kept the Refill idle. They still pay their XP and other items.
		locationQuestRations = { itemId = "item.rations", perDay = 0 },
	},
	inventory = {
		pocketSlots = 10, -- LDoE's 10 pockets
		backpackSlots = 0,
		-- Bags add +5, +8, +10 or +15 (LDOE_PARITY #15, CONTENT_2_0 §4). The +15 Ranger Pack
		-- (content2) and the Pack Expansion (+5) reach 20.
		maxBackpackSlots = 20,
	},
	player = {
		maxHealth = 100,
		walkSpeed = 16,
		sprintSpeed = 22,
		fistDamage = 6,
		fistAttacksPerSecond = 1.8,
		fistRange = 4,
	},
	survival = {
		-- LDoE's numbers (LDOE_PARITY #33): both meters drain 1 point every 10 s while in
		-- the world (about 17 min from full), an empty meter deals 2 HP/s, and the HUD
		-- warns at 20. A death (anywhere, Reset Character included) wakes you at exactly the
		-- respawn values below, never full (the flow review's F-05): dying is not a meal.
		hunger = {
			max = 100,
			decayPerSecond = 1 / 10,
			thresholds = {
				{ atOrBelow = 0, damagePerSecond = 2 },
			},
		},
		thirst = {
			max = 100,
			decayPerSecond = 1 / 10,
			thresholds = {
				{ atOrBelow = 0, damagePerSecond = 2 },
			},
		},
		warnAt = 20,
		regenThreshold = 60,
		regenPerSecond = 0.1,
		respawnHealth = 50,
		respawnHunger = 40,
		respawnThirst = 40,
		tickSeconds = 1,
	},
	combat = {
		armorConstant = 50 / 3, -- LDoE's damage reduction formula
		-- Durability (docs/ECONOMY.md §8.1): everything wears out at LDoE's rate or faster.
		weaponDurabilityPerHit = 1, -- a landed light hit; each bow shot released
		heavyDurabilityPerHit = 2, -- a landed heavy swing
		gunDurabilityPerShot = 1, -- every round fired, hit or miss (a shotgun shell is a round)
		durabilityWarn = { 0.25, 0.10 }, -- the weapon ring turns amber, then red with a toast
		armorDurabilityPerHitTaken = 1,
		critChance = 0.08, -- Fog Runs: one hit in 12; rolled once per shot, not per pellet
		critMultiplier = 1.5,
		pvpMaxHitFraction = 0.6, -- GAME_DESIGN: no one-shots from full HP; every fight takes 2+ hits
		lagToleranceStuds = 3,
		softLockDegrees = 12,
	},
	gathering = {
		swingSeconds = 0.8,
		durabilityPerHit = 1,
	},
	travel = {
		runSeconds = 3,
		fogTierNames = { "Light", "Dense", "Black" },
		-- Going back in for your bag costs half a Run (rounded up): enough that dying hurts,
		-- not so much that a lost backpack is never worth fetching.
		reentryEnergyMultiplier = 0.5,
		departureStuds = 40, -- the Trailhead sign or the fog wall: travel starts only at the edge (GAME_DESIGN)
	},
	-- A dropped bag lives until the lobby closes on a run, and drops.lifetimeSeconds at home
	-- (the flow review's F-32: no third number).
	death = {
		keepPockets = false, -- LDoE drops everything carried; equipment is always kept
	},
	building = {
		gridStuds = 8, -- a wall segment about 1.4 survivor heights: rooms read as rooms (LDoE scale)
		wallHeightStuds = 12,
		plotCells = 15, -- 15 x 8 studs: the same 120-stud plot
		refundGraceSeconds = 30,
		lateRefundFraction = 0.5,
	},
	salvage = {
		durabilityScalesChance = true,
	},
	home = {
		-- LDoE's home set (LDOE_PARITY #30): enough for the first hours (tools, the first
		-- stations, floors and walls), and it never respawns. Node state is saved per
		-- outpost, so a restart or rejoin never refills it; repeat farming happens on Fog
		-- Runs. The spring is a well, not a stock: it refills like a Fog Run node.
		-- ECONOMY §1.3: 7 boulders and 5 heaps are LDoE's 21 stone and 40 scrap. Loose stones
		-- are 11 (was 10): the hook's stations, blocks and the 2 picks that 41 rock and heap
		-- hits wear through need 42 stone (tests/Pacing.spec). Pines are 28 (LDoE's 20 plus 8,
		-- the flow review's F-07): 84 timber and Claim the Ground's 20 pay for chapter 1's
		-- builds (quests 3, 4 and 7, the Stonecutter and the Workbench's planks: 87) with a
		-- little fuel to spare. The last one falling says so, and points at the Fog.
		nodes = {
			{ nodeId = "node.pine_tree", count = 28 },
			{ nodeId = "node.boulder", count = 7 },
			{ nodeId = "node.scrap_heap", count = 5 },
			{ nodeId = "node.ember_bush", count = 7 },
			{ nodeId = "node.reed_patch", count = 20 },
			{ nodeId = "node.fallen_branches", count = 12 },
			{ nodeId = "node.loose_stones", count = 11 },
			{ nodeId = "node.spring_pool", count = 1 },
		},
		-- The exception: water sources refill on their node respawnSeconds, the way LDoE's
		-- well and rain catcher keep a base drinkable.
		renewing = { "node.spring_pool" },
	},
	plots = {
		-- 8 plots in two rows of 4 facing a shared road: the Neighbourhood.
		-- A plot is the 10 x 10 cell build grid (120 studs) plus a gathering ring.
		count = 8,
		columns = 4,
		spacingStuds = 184,
		rowGapStuds = 36,
		marginStuds = 28,
		-- Haven Square (Domain/Neighbourhood): the trodden middle inside its palisade, half
		-- its width and depth. Tight like LDoE's settlement (rec4_01): 0.6 of the first
		-- cut's area. Two plots stand each side of it in both rows; the road runs through it.
		plazaHalfStuds = 44,
		plazaDepthStuds = 62,
	},
	interaction = {
		-- Arm's reach (checklist 3.11): how far from an object's edge (its footprint
		-- radius) the survivor can use it, for nodes, pickups, crates and stations.
		reachStuds = 5,
		-- The server allows this much more for movement and latency.
		toleranceStuds = 1.5,
	},
	drops = {
		lifetimeSeconds = 600, -- a bag on the ground lasts 10 minutes
	},
	movement = {
		-- A short hop (PLAYER_EXPERIENCE_CHECKLIST 1.4): feels like Roblox, but can't
		-- clear a wall (8.6+ studs), a crate or a node's collider.
		hopHeight = 2.2,
		hopCooldownSeconds = 1.2,
	},
	dayNight = {
		cycleSeconds = 24 * 60, -- one day and night in 24 real minutes
		dayFraction = 0.72, -- about 17 minutes of day, 7 of night
		offset = 0.1, -- where in the cycle server time 0 falls
	},
	newPlayer = {
		items = {
			{ itemId = "item.sealed_tin", count = 2 },
			{ itemId = "item.boiled_water", count = 2 },
		},
	},
	-- LDOE_PARITY #58: until level 10, a daily food and water gift waits in the inbox (one
	-- per UTC day, the first time the player is online that day).
	dailyGift = {
		items = {
			{ itemId = "item.sealed_tin", count = 2 },
			{ itemId = "item.boiled_water", count = 2 },
		},
		untilLevel = 10,
	},
	raid = {
		lootFraction = 0.3,
	},
	shield = {
		afterRaidSeconds = 8 * 60 * 60,
	},
	-- docs/ECONOMY.md §10.1: the Smelter and Stonecutter are launch stations, but their models
	-- still wait for an A grade (Art.pieces lists none), so their lines run here until then:
	-- ingots at the fuelled Campfire, blocks at the Saw Bench. (Not the Workbench, as §10.1
	-- has it: the Workbench costs blocks, so the first one could never be built.) Delete each
	-- entry the day its model is approved (tests/Economy.spec checks this against Art.pieces).
	-- (Both models graded A in the launch lineup, docs/milestones/m1-launch L01-L03: none left.)
	stationFallback = {},
	-- docs/ECONOMY.md §6.2: location quests pay once per UTC day per player, not per lobby,
	-- so a Rations reward can never refund the Run that earned it.
	locationQuests = { period = "daily" },
	-- ECONOMY §1/§11.1: resource nodes are personal in a lobby (every player gets their own
	-- tree and rock); containers and PvP stay contested. Nothing regrows within a lobby.
	runs = { personalNodes = true, nodesRegrow = false },
	-- ECONOMY §6.4: Hollow health and damage by fog tier (Light, Dense, Black), multiplied
	-- on top of the Fog-meter bands. A Black lobby at band 3 tops out at HP x2.03.
	hollowTierScale = { health = { 1, 1.2, 1.4 }, damage = { 1, 1.15, 1.3 } },

	-- Fog Runs (M1 slice 2) -------------------------------------------------------------
	-- A feature that is off is left out of the game entirely: the recipes, stations, pieces
	-- and remotes tagged with it (Features.strip). fogRuns is on for launch (the flow
	-- review's F-01; tests/Launch.spec holds it on and checks no quest is left dormant).
	features = {
		fogRuns = true,
		aiRaiders = false, -- M2
		-- LDOE_PARITY #58: on for launch (the flow review's F-33). MVP_LAUNCH never cut it; the old
		-- "cut" note was wrong, and a new player needs the food and water cushion F-05 made matter.
		dailyGift = true,
		-- M4 (docs/MVP_LAUNCH.md): built and tested on the server, no client UI yet. Off, Dense
		-- and Black fog open on the level gate alone, and no airdrops land.
		regionGates = false,
		airdrops = false,
		-- Deer and wolves wait for their own rig (Data/Enemies `deferred`). Until then the Smoke
		-- Rack, its venison line and the quest steps that need them stay hidden: nothing else
		-- drops enough Raw Venison to feed them (the flow review's F-21).
		wildlife = false,
		-- 2.0 batch 4 (docs/CONTENT_2_0.md): the Fortified tier, chapter 4 and the Zona item
		-- depth. On since batch 4b's Studio pass uploaded, graded and gripped every model and
		-- icon (tests/Content2.spec: off, nothing new appears; on, the bundle validates).
		content2 = true,
	},
	lobby = {
		capacity = 12, -- GAME_DESIGN: 8-12 a lobby
		openTimeoutSeconds = 90,
		reservationSeconds = 45,
		joinWindowSeconds = 3 * 60, -- GAME_DESIGN: new players join only in the first 3 min
		durationSeconds = 15 * 60, -- the Fog closes in after about 15 min (a ~20 min session loop)
		warningSeconds = 60,
		meterExponent = 1.2, -- quiet start, a sharper rise into the late-run scramble
		reentryCutoffSeconds = 60, -- no re-entry once the 60 s warning sounds
		ticketMaxAgeSeconds = 120,
		bandTolerance = 1,
		-- Loot gets better and the Hollow stronger as the meter rises; that pull toward
		-- staying late is what makes extraction tense.
		bands = {
			{ from = 0, name = "Thin", lootMultiplier = 1, hollowStrength = 1 },
			{ from = 0.4, name = "Rising", lootMultiplier = 1.25, hollowStrength = 1.2 },
			{ from = 0.75, name = "Closing", lootMultiplier = 1.5, hollowStrength = 1.45 },
		},
		drops = {
			{ access = "party", equipment = false }, -- Light: only you and your party open it
			{ access = "anyone", equipment = false }, -- Dense: anyone takes the backpack
			{ access = "anyone", equipment = true }, -- Black: everything but the secure pouch
		},
	},
	extraction = {
		edgeSeconds = 1.5, -- the same fog-out as leaving the Neighbourhood
		pointSeconds = 8,
		flareSeconds = 30,
		radiusStuds = 10,
		xpByTier = { 40, 100, 180 }, -- a safe exit is worth about two Hollow kills per tier
	},
	matchmaking = {
		-- Power = level x 10 + gear score; one band is 60 power, about one gear tier.
		levelWeight = 10,
		bandWidth = 60,
		widenEverySeconds = 4,
		maxTolerance = 2,
		-- Nobody waits long: an empty lobby beats a queue. The wait counts from the trip's start
		-- (Matchmaking.waitSince), so a 3 s Run opens a lobby at the first tick after it (batch 3:
		-- it was 12, and the first survivor waited 12 s at home after every Run's timer).
		newLobbyAfterSeconds = 3,
		weights = { weapon = 40, armor = 12, bag = 10, companion = 0 }, -- companion: M3 hook
		aiBackfillTarget = 8,
		maxPartySize = 4, -- a crew (GAME_DESIGN "Crews")
	},
	containers = {
		searchSeconds = 5, -- checklist 12.4
		reachStuds = 8,
		lootModeByTier = { "personal", "shared", "shared" }, -- GAME_DESIGN: Light rolls per player
	},
	travelBonus = {
		-- Walking is free but slow; it always turns something up. A Run sometimes does.
		runChance = 0.35,
		walkChance = 1,
		walkRolls = 2,
		takeAllRations = 1, -- LDOE_PARITY #40; TAKE is one rewarded ad per item (S3)
		hurryEnergyPerMinute = 2, -- #43 "Hurry": a 19 min Dense walk skips for 38 Energy, more than its Run
	},
	noise = {
		decaySeconds = 4,
		melee = 10, -- quiet: GAME_DESIGN makes melee and bows the stealth options
		bow = 6,
		sprint = 14,
		search = 8,
		bloaterBurst = 45,
		flare = 30, -- the pop of the flare pistol; its light does the rest
	},
	stamina = {
		max = 100,
		regenPerSecond = 20,
		regenDelaySeconds = 0.8,
		sprintPerSecond = 0, -- sprint stays free in M1 (slice 1 movement); dodge and heavy swings spend
	},
	dodge = {
		staminaCost = 25, -- four rolls from full
		iframeSeconds = 0.3,
		cooldownSeconds = 0.9,
		distanceStuds = 9,
		durationSeconds = 0.45,
	},
	melee = {
		arcDegrees = 100,
		heavyMultiplier = 1.8,
		heavyWindupSeconds = 0.45,
		staminaLight = 6,
		staminaHeavy = 18,
		hitStopSeconds = 0.06, -- checklist 13.4: about 60 ms
		heavyHitStopSeconds = 0.09,
		knockbackStuds = 1.5,
		heavyKnockbackStuds = 4,
		-- LDOE_PARITY #34: a hatchet or pick in a weapon slot is a weak club. F-29: never weaker
		-- than bare fists (6 x 1.8 = 10.8 a second), never stronger than the crafted Stake
		-- (10 x 1.1 = 11): 9 x 1.22 = 10.98.
		toolDamage = 9,
		toolAttacksPerSecond = 1.22,
		toolRange = 5,
	},
	sneak = {
		-- LDOE_PARITY #44: Ctrl. Half speed, much quieter, seen from half as far, and a 3x
		-- backstab on a Hollow that hasn't noticed you. Looting or harvesting breaks it.
		speedMultiplier = 0.5,
		noiseMultiplier = 0.35,
		detectionMultiplier = 0.5,
		backstabMultiplier = 3,
	},
	autoAttack = {
		radiusStuds = 14, -- LDOE_PARITY #31: in-world AUTO also fights, free everywhere
		tickSeconds = 0.25,
	},
	autoClear = {
		-- LDOE_PARITY #31: the location panel's AUTO clears a location into the inbox.
		adPerDay = 10,
		adMinLevel = 13,
		rationsByTier = { 1, 2, 3 },
		nodeShare = 0.5, -- you get half of what walking it would: entering pays better
		killShare = 0.5,
	},
	airdrops = {
		-- LDOE_PARITY #43: up to three a day, as Energy falls below 140, 80 and 20 of LDoE's 200
		-- (70%, 40% and 10%); the same shares of our 120 cap (F-16).
		thresholds = { 84, 48, 12 },
		locationId = "loc.supply_drop",
		pinSeconds = 2 * 60 * 60,
	},
	regionGates = {
		-- LDOE_PARITY #43: the signal towers. Dense needs Scrap-tier parts (day 2), Black
		-- needs brass and springs from Dense runs (about day 5, with level 15).
		{
			id = "tower_dense",
			name = "Crossing Signal Tower",
			fogTier = 2,
			parts = {
				{ itemId = "item.plank", count = 20 },
				{ itemId = "item.scrap_plate", count = 6 },
				{ itemId = "item.rope", count = 10 },
				{ itemId = "item.coil_spring", count = 1 },
			},
		},
		{
			id = "tower_black",
			name = "Depot Signal Tower",
			fogTier = 3,
			parts = {
				{ itemId = "item.scrap_plate", count = 16 },
				{ itemId = "item.rivets", count = 12 },
				{ itemId = "item.coil_spring", count = 4 },
				{ itemId = "item.brass_gear", count = 2 },
				{ itemId = "item.steel_pipe", count = 2 },
			},
		},
	},
	fogExposure = {
		-- LDOE_PARITY #37: unprotected, Dense fog fills the meter in about 10 min and Black in
		-- 6.3, inside a 15 min run. The flow review's F-15: Black was 4 min, so a full Padded
		-- set filled at 7.3 and band 3 (11.8 min) cost over 500 HP; at 380 s it fills at 11.5,
		-- about one dressing short of band 3. Hidebound (12.2) and Riveted (12.9) buy a little
		-- more. maxResist 0.56 is reached only with a Gas Mask's filter (14.4 min), so even
		-- the best kit still bleeds before the lobby closes (it was 0.8: a geared player
		-- never filled the meter, and Black stopped being a pay-or-prepare tier).
		max = 100,
		ratePerTier = { 0, 100 / 600, 100 / 380 },
		maxResist = 0.56,
		damagePerSecond = 2,
	},
	deathRecovery = {
		recoverAllAdsPerDay = 1, -- LDOE_PARITY #46; premium recovery is S3
		reanimatorHealth = 50,
		milestones = {
			{ deaths = 1, items = { { itemId = "item.field_dressing", count = 2 } } },
			{ deaths = 5, items = { { itemId = "item.rations", count = 1 } } },
			{ deaths = 20, items = { { itemId = "item.reanimator", count = 1 } } },
		},
	},
	hands = {
		-- LDoE-style: two weapon slots, 1 and 2 select, F swaps (no hotbar). A swap takes a
		-- beat and cancels a reload, so switching guns mid-fight is a choice, not a free action.
		slots = 2,
		swapSeconds = 0.45,
	},
	hollow = {
		tickSeconds = 0.2,
		syncSeconds = 0.2, -- 5 snapshots a second; clients interpolate between them
		alertSeconds = 6,
		loseTargetSeconds = 4,
		idleSeconds = { min = 2, max = 6 },
		wanderRadius = 30,
		fleeSeconds = 3,
		maxActive = 60,
		spawnSpreadStuds = 40,
		-- F-19: band 1 spawns one more Shambler for every seated survivor past two, topped up
		-- as they join (HollowAI.crowdExtra): Pine Hollow's 6-9 become 16-19 at 12.
		crowd = { freePlayers = 2, perPlayer = 1 },
		hitRadiusStuds = 1.6,
	},
	-- Robux prices of the v0.1 shop (MVP_LAUNCH Monetization v0.1; the ladder is
	-- 79/99/149/199/249/399/799/1,199/1,699/...). Data/Products reads these as display
	-- fallbacks; the live price on Roblox (Open Cloud) is what the shop shows once loaded, so
	-- changing one here also means updating the product or pass there.
	prices = {
		robux = {
			["product.starter_offer"] = 99, -- Firestarter Kit
			["product.scavenger_kit"] = 79,
			["product.resource_pack"] = 99, -- Supply Bundle
			["product.builders_crate"] = 399,
			["product.room_kit_reinforced"] = 1699,
			["product.energy_refill"] = 99,
			["product.embers_50"] = 149, -- Ember Pouch
			["product.embers_300"] = 799, -- Ember Chest
			["product.pack_expansion"] = 199,
			["product.vip_lounge"] = 399,
			-- The Equipment tab (MVP_LAUNCH, LDoE rec8_sheet4) and the Building tab's capacity packs.
			["product.scouts_kit"] = 79,
			["product.weapon_parts"] = 149,
			["product.padded_armor"] = 199,
			["product.gunrunner_pack"] = 249,
			["product.raider_arms"] = 499,
			["product.heavy_equipment"] = 2499,
			["product.smelter_slot"] = 399,
			["product.recycler_slot"] = 399,
		},
	},
	-- Embers, the premium currency (playbook §7.2, at LDoE coin parity). Sinks: Recover all,
	-- Trail Rations, speed-ups by time left, Fill Up per missing unit (40 Embers per free
	-- grind-hour, at least 1 a unit; per-unit numbers rebalance with the ECONOMY pacing test).
	embers = {
		recoverAll = 100,
		ration = 20,
		rationsFive = 90,
		speedUpFactor = 3.9, -- Embers = max(speedUpMin, ceil(3.9 x sqrt(minutes left)))
		speedUpMin = 2,
		speedUpMinSeconds = 120, -- speed-ups show from 2 minutes left
		-- Embers a missing unit: round(40 x free minutes / 60), the minutes as in Data/Products'
		-- header (docs/ECONOMY.md chains; rebalance with the pacing sim). A buy is rounded up
		-- once (Offers.fillUpPrice). The flow review's F-25: tier-1 raw materials (under a
		-- minute each) cost a third of an Ember, not 1, which was 3-4x the plate rate.
		fillUp = {
			["item.sticks"] = 1 / 3,
			["item.timber"] = 1 / 3,
			["item.stone"] = 1 / 3,
			["item.fiber"] = 1 / 3,
			["item.scrap"] = 1 / 3,
			["item.emberberry"] = 1 / 3,
			["item.ironstone"] = 1 / 3,
			["item.rope"] = 1,
			["item.malachite"] = 1,
			["item.ironbark_log"] = 1,
			["item.embercoal"] = 1,
			["item.cloth"] = 2,
			["item.plank"] = 2,
			["item.stone_block"] = 3,
			["item.iron_ingot"] = 3,
			["item.pitch_glue"] = 3,
			["item.rivets"] = 8,
			["item.scrap_plate"] = 13,
			["item.ironbark_plank"] = 13,
			["item.copper_wire"] = 13,
			["item.copper_ingot"] = 20,
		},
		vipTrialDays = 7, -- any purchase opens the VIP Lounge for this long (LDoE's VIP 1)
		firstPurchaseHours = 48, -- the Firestarter Kit's window after the first win
	},
}

return Tuning
