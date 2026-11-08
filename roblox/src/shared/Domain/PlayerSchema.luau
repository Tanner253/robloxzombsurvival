--!strict
--[[
	PlayerSchema: the saved player profile, schema version 2 (ARCHITECTURE.md §6).

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

PlayerSchema.VERSION = 3

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

-- Health and the survival meters, saved so leaving and rejoining never refills them.
-- Meters only drain in the world (Domain/Survival), so updatedAt is reset on join.
export type SurvivalSave = {
	health: number,
	hunger: number,
	thirst: number,
	updatedAt: number,
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
	-- foodDay is the UTC day number foodGained counts for (Tuning.energy.foodDailyCap).
	energy: { value: number, updatedAt: number, foodDay: number, foodGained: number },
	survival: SurvivalSave,
	quests: { active: { [string]: QuestState }, completed: { [string]: number } },
	unlocks: { recipes: { [string]: boolean }, blueprints: { [string]: boolean } },
	purchases: { receiptIds: { string } }, -- most recent last, capped at RECEIPT_LOG_SIZE
	raid: { shieldUntil: number, log: { RaidLogEntry } },
	settings: Settings,
}

-- Player settings (checklist 8.6): mixer volumes 0..1, camera shake, UI scale.
export type Settings = {
	master: number,
	music: number,
	ambience: number,
	sfx: number,
	ui: number,
	shake: boolean,
	uiScale: number,
}

-- Default settings, for new profiles and the v2 -> v3 migration.
function PlayerSchema.defaultSettings(): Settings
	return { master = 1, music = 0.7, ambience = 0.9, sfx = 1, ui = 0.9, shake = true, uiScale = 1 }
end

-- Settings from untrusted client input: known keys only, clamped; nil when malformed.
function PlayerSchema.cleanSettings(input: any): Settings?
	if type(input) ~= "table" then
		return nil
	end
	local result = PlayerSchema.defaultSettings()
	for _, key in { "master", "music", "ambience", "sfx", "ui" } do
		local value = input[key]
		if type(value) ~= "number" or value ~= value then
			return nil
		end
		(result :: any)[key] = math.clamp(value, 0, 1)
	end
	if type(input.shake) ~= "boolean" or type(input.uiScale) ~= "number" or input.uiScale ~= input.uiScale then
		return nil
	end
	result.shake = input.shake
	result.uiScale = math.clamp(input.uiScale, 0.8, 1.25)
	return result
end

-- Full health and meters, for new profiles and the v1 -> v2 migration.
function PlayerSchema.freshSurvival(): SurvivalSave
	return {
		health = Tuning.player.maxHealth,
		hunger = Tuning.survival.hunger.max,
		thirst = Tuning.survival.thirst.max,
		updatedAt = 0,
	}
end

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
		energy = { value = Tuning.energy.cap, updatedAt = 0, foodDay = 0, foodGained = 0 },
		survival = PlayerSchema.freshSurvival(),
		quests = { active = {}, completed = {} },
		unlocks = { recipes = {}, blueprints = {} },
		purchases = { receiptIds = {} },
		raid = { shieldUntil = 0, log = {} },
		settings = PlayerSchema.defaultSettings(),
	}
end

-- steps[n] upgrades version n to n + 1.
PlayerSchema.migrations = {
	-- v2: health, hunger and thirst are saved; food energy counts toward a daily cap.
	[1] = function(data)
		if data.survival == nil then
			data.survival = PlayerSchema.freshSurvival()
		end
		if type(data.energy) == "table" then
			data.energy.foodDay = data.energy.foodDay or 0
			data.energy.foodGained = data.energy.foodGained or 0
		end
	end,
	-- v3: player settings (volumes, camera shake, UI scale).
	[2] = function(data)
		if data.settings == nil then
			data.settings = PlayerSchema.defaultSettings()
		end
	end,
} :: Migrations.Steps

return PlayerSchema
