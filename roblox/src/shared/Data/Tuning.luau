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
		-- LDOE_PARITY #38 (binding): cap 200 at 1 per 5 min, as LDoE; Runs cost 15/22/33
		-- by fog tier (Data/Locations). Food restoring Energy goes in slice 1 (#33).
		cap = 200,
		secondsPerPoint = 5 * 60,
		hardCap = 400,
		levelUpRestore = 20,
		foodDailyCap = 40,
	},
	inventory = {
		pocketSlots = 10,
		backpackSlots = 0,
		maxBackpackSlots = 18, -- Scrap Pack Frame (12) + Pack Expansion (6)
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
		-- Meters drain only in the world (not on the Fog map or offline), so these are
		-- active-play rates. LDoE drains 1 point per 10 s for both (about 17 min from
		-- full) and deals 2 HP/s at 0. Here a full meter lasts about 23 min (hunger)
		-- and 18 min (thirst): a long run plus the trip home, with a warning band.
		hunger = {
			max = 100,
			decayPerSecond = 1 / 14,
			thresholds = {
				{ atOrBelow = 15, damagePerSecond = 0.25 },
				{ atOrBelow = 0, damagePerSecond = 0.75 },
			},
		},
		thirst = {
			max = 100,
			decayPerSecond = 1 / 11,
			thresholds = {
				{ atOrBelow = 15, damagePerSecond = 0.25 },
				{ atOrBelow = 0, damagePerSecond = 0.75 },
			},
		},
		regenThreshold = 60,
		regenPerSecond = 0.1,
		respawnHealth = 60,
		respawnHunger = 60,
		respawnThirst = 60,
		tickSeconds = 1,
	},
	combat = {
		armorConstant = 50 / 3, -- LDoE's damage reduction formula
		weaponDurabilityPerHit = 1,
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
	death = {
		despawnSeconds = 2 * 60 * 60,
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
		-- Home is for starter materials (LDoE): enough for the first 30-60 minute hook
		-- (hatchet and pick, a workbench, a campfire, first floors and walls), then it
		-- runs dry and the bulk comes from Fog Runs. Node state is saved per player and
		-- regrows on real-time stamps, so a server restart never refills it.
		nodes = {
			{ nodeId = "node.fallen_branches", count = 8 },
			{ nodeId = "node.loose_stones", count = 6 },
			{ nodeId = "node.pine_tree", count = 12 },
			{ nodeId = "node.boulder", count = 2 },
			{ nodeId = "node.reed_patch", count = 5 },
			{ nodeId = "node.ember_bush", count = 3 },
			{ nodeId = "node.spring_pool", count = 1 },
		},
		-- How long a depleted home node takes to regrow, in real hours (a random time
		-- in the span each time).
		regrowHours = {
			["node.fallen_branches"] = { min = 1, max = 2 },
			["node.loose_stones"] = { min = 1, max = 2 },
			["node.pine_tree"] = { min = 8, max = 12 },
			["node.fatwood_stump"] = { min = 8, max = 12 },
			["node.boulder"] = { min = 12, max = 24 },
			["node.scrap_heap"] = { min = 12, max = 24 },
			["node.reed_patch"] = { min = 4, max = 6 },
			["node.ember_bush"] = { min = 4, max = 6 },
			["node.ashroot_mound"] = { min = 4, max = 6 },
			["node.spring_pool"] = { min = 1, max = 2 },
		},
	},
	plots = {
		-- 8 plots in two rows of 4 facing a shared road: the Neighbourhood.
		-- A plot is the 10 x 10 cell build grid (120 studs) plus a gathering ring.
		count = 8,
		columns = 4,
		spacingStuds = 184,
		rowGapStuds = 36,
		marginStuds = 28,
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
	raid = {
		lootFraction = 0.3,
	},
	shield = {
		afterRaidSeconds = 8 * 60 * 60,
	},

	-- Fog Runs (M1 slice 2) -------------------------------------------------------------
	-- Hidden until the art grades A (PLAYER_EXPERIENCE_CHECKLIST §0): with fogRuns off, the
	-- recipes, station and remotes tagged with it are left out of the game entirely.
	features = {
		fogRuns = false,
		aiRaiders = false, -- M2
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
		newLobbyAfterSeconds = 12, -- nobody waits long: an empty lobby beats a queue
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
		-- LDOE_PARITY #34: a hatchet or pick in a weapon slot is a weak club (below the Spiked Club's 14).
		toolDamage = 8,
		toolAttacksPerSecond = 1.1,
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
		-- LDOE_PARITY #43: up to three a day, as Energy falls below 140, 80 and 20.
		thresholds = { 140, 80, 20 },
		locationId = "loc.supply_drop",
		pinSeconds = 2 * 60 * 60,
	},
	regionGates = {
		-- LDOE_PARITY #43: the signal towers. Dense needs Scrap-tier parts (day 2), Black
		-- needs brass and springs from Dense runs (about day 5, with level 15).
		{
			id = "tower_dense",
			name = "Quarry Signal Tower",
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
		-- LDOE_PARITY #37: unprotected, Dense fog fills the meter in about 10 min and
		-- Black in 4, inside a 15 min run; padded gear stretches that, sets will gate it.
		max = 100,
		ratePerTier = { 0, 100 / 600, 100 / 240 },
		maxResist = 0.8,
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
		hitRadiusStuds = 1.6,
	},
}

return Tuning
