--!strict
--[[
	PlayerSchema: the saved player profile, schema version 1 (ARCHITECTURE.md §6).

	To change the schema:
	1. Bump VERSION.
	2. Add `steps[oldVersion]` to `migrations` that turns old data into new data.
	3. Update the PlayerData type and template().
	The Lune suite fails if a version has no migration.

	All timestamps are UTC seconds; 0 means "not set yet" and is filled in on the
	first load. The outpost layout is saved separately, not in this profile.
]]

local Types = require("../Types")
local Tuning = require("../Data/Tuning")
local Inventory = require("./Inventory")
local Timers = require("./Timers")
local Migrations = require("./Migrations")

local PlayerSchema = {}

PlayerSchema.VERSION = 1

-- How many purchase receipt IDs are kept for idempotency checks (oldest dropped first).
PlayerSchema.RECEIPT_LOG_SIZE = 100

export type Equipment = {
	head: Types.Slot,
	body: Types.Slot,
	legs: Types.Slot,
	feet: Types.Slot,
	weapon: Types.Slot,
	bag: Types.Slot,
}

export type StationState = {
	stationId: Types.StationId,
	level: number,
	queue: Timers.Queue,
	fuelEndsAt: number,
}

export type CropState = {
	cropId: string,
	plantedAt: number,
	readyAt: number,
}

export type QuestState = {
	progress: { [string]: number },
}

export type RaidLogEntry = {
	at: number,
	raiderUserId: number,
	itemsLost: { Types.ItemStack },
}

export type PlayerData = {
	version: number,
	meta: { createdAt: number, lastLoginAt: number, loginCount: number },
	inventory: {
		pockets: Types.Container,
		backpack: Types.Container,
		equipment: Equipment,
	},
	storage: { [string]: Types.Container }, -- keyed by placed storage piece UID
	lockedStash: Types.Container, -- purchases land here; never raidable
	stations: { [string]: StationState }, -- keyed by placed station UID
	crops: { [string]: CropState }, -- keyed by placed plot UID
	progression: { level: number, xp: number },
	energy: { value: number, updatedAt: number },
	quests: { active: { [string]: QuestState }, completed: { [string]: number } },
	unlocks: { recipes: { [string]: boolean }, blueprints: { [string]: boolean } },
	purchases: { receiptIds: { string } }, -- most recent last, capped at RECEIPT_LOG_SIZE
	raid: { shieldUntil: number, log: { RaidLogEntry } },
}

-- A fresh profile. ProfileStore copies this for new players and uses it to fill
-- missing keys (Reconcile) after migrations run.
function PlayerSchema.template(): PlayerData
	local slots = Tuning.inventory
	return {
		version = PlayerSchema.VERSION,
		meta = { createdAt = 0, lastLoginAt = 0, loginCount = 0 },
		inventory = {
			pockets = Inventory.newContainer(slots.pocketSlots),
			backpack = Inventory.newContainer(slots.backpackSlots),
			equipment = {
				head = Inventory.emptySlot(),
				body = Inventory.emptySlot(),
				legs = Inventory.emptySlot(),
				feet = Inventory.emptySlot(),
				weapon = Inventory.emptySlot(),
				bag = Inventory.emptySlot(),
			},
		},
		storage = {},
		lockedStash = Inventory.newContainer(slots.lockedStashSlots),
		stations = {},
		crops = {},
		progression = { level = 1, xp = 0 },
		energy = { value = Tuning.energy.cap, updatedAt = 0 },
		quests = { active = {}, completed = {} },
		unlocks = { recipes = {}, blueprints = {} },
		purchases = { receiptIds = {} },
		raid = { shieldUntil = 0, log = {} },
	}
end

--[[
	steps[n] upgrades version n to n + 1. Version 1 is the first schema, so there
	are none yet. Example for a future v2:

	[1] = function(data)
		data.progression.prestige = 0
	end,
]]
PlayerSchema.migrations = {} :: Migrations.Steps

return PlayerSchema
