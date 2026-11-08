--!strict
--[[
	Global tuning numbers. Services read these instead of hard-coding values (ARCHITECTURE.md §5).
	Every number here is one that no single content definition owns.
	MVP values; the reasoning and the LDoE comparison are in docs/CONTENT_MVP.md.
]]

local Types = require("../Types")

local Tuning: Types.TuningDef = {
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
		pocketSlots = 10,
		backpackSlots = 0,
		maxBackpackSlots = 18, -- Scrap Pack Frame (12) + Pack Expansion (6)
		lockedStashSlots = 30,
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
		gridStuds = 12,
		wallHeightStuds = 12,
		plotCells = 10,
		refundGraceSeconds = 30,
		lateRefundFraction = 0.5,
	},
	salvage = {
		durabilityScalesChance = true,
	},
	home = {
		-- Enough for quests 1-5 (about 60 timber and 20 stone) with respawns.
		nodes = {
			{ nodeId = "node.fallen_branches", count = 6 },
			{ nodeId = "node.loose_stones", count = 6 },
			{ nodeId = "node.pine_tree", count = 10 },
			{ nodeId = "node.boulder", count = 6 },
			{ nodeId = "node.reed_patch", count = 4 },
			{ nodeId = "node.ember_bush", count = 2 },
			{ nodeId = "node.spring_pool", count = 1 },
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
		reachStuds = 10,
		gatherReachStuds = 9,
	},
	drops = {
		lifetimeSeconds = 600, -- a bag on the ground lasts 10 minutes
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
}

return Tuning
