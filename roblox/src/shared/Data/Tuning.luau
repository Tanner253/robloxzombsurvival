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
}

return Tuning
