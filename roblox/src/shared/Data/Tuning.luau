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
		-- LDoE: cap 200 at 1 per 5 min. Same regen here, half the cap, and runs cost
		-- about two thirds as much, so a run pays back in two thirds of the time.
		cap = 100,
		secondsPerPoint = 5 * 60,
		hardCap = 200,
		levelUpRestore = 20,
		foodDailyCap = 40,
	},
	inventory = {
		pocketSlots = 10, -- LDoE's 10 pockets
		backpackSlots = 0,
		-- Bags add +5, +10 or +15 (LDOE_PARITY #15); the +15 bag comes with Fog Run loot (S2)
		-- and raises this to 20.
		maxBackpackSlots = 15, -- the Scrap Pack Frame (+10) and the Pack Expansion (+5)
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
		-- warns at 20. Death resets every meter to full.
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
		respawnHealth = 100,
		respawnHunger = 100,
		respawnThirst = 100,
		tickSeconds = 1,
	},
	combat = {
		armorConstant = 50 / 3, -- LDoE's damage reduction formula
		weaponDurabilityPerHit = 1,
		armorDurabilityPerHitTaken = 1,
	},
	gathering = {
		swingSeconds = 0.8,
		durabilityPerHit = 1,
	},
	travel = {
		runSeconds = 3,
		fogTierNames = { "Light", "Dense", "Black" },
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
		-- LDoE's home set (LDOE_PARITY #30): enough for the first hours (tools, the first
		-- stations, floors and walls), and it never respawns. Node state is saved per
		-- outpost, so a restart or rejoin never refills it; repeat farming happens on Fog
		-- Runs. The spring is a well, not a stock: it refills like a Fog Run node.
		nodes = {
			{ nodeId = "node.pine_tree", count = 20 },
			{ nodeId = "node.boulder", count = 7 },
			{ nodeId = "node.scrap_heap", count = 5 },
			{ nodeId = "node.ember_bush", count = 7 },
			{ nodeId = "node.reed_patch", count = 20 },
			{ nodeId = "node.fallen_branches", count = 12 },
			{ nodeId = "node.loose_stones", count = 10 },
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
}

return Tuning
