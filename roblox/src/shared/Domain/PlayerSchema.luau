--!strict
--[[
	PlayerSchema: the saved player profile (ARCHITECTURE.md §6); VERSION is the schema.

	To change the schema:
	1. Bump VERSION.
	2. Add `steps[oldVersion]` to `migrations` that turns old data into new data.
	3. Update the PlayerData type and template().
	The Lune suite fails if a version has no migration.

	All timestamps are UTC seconds; 0 means "not set yet" and is filled in on the
	first load. The outpost layout is saved separately, not in this profile.
]]

local Types = require("../Types")
local Items = require("../Data/Items")
local Stations = require("../Data/Stations")
local Tuning = require("../Data/Tuning")
local Converter = require("./Converter")
local Inventory = require("./Inventory")
local Migrations = require("./Migrations")

local PlayerSchema = {}

PlayerSchema.VERSION = 11

-- How many purchase receipt IDs are kept for idempotency checks (oldest dropped first).
PlayerSchema.RECEIPT_LOG_SIZE = 100

export type Equipment = {
	head: Types.Slot,
	body: Types.Slot,
	legs: Types.Slot,
	feet: Types.Slot,
	weapon: Types.Slot,
	weapon2: Types.Slot, -- the secondary weapon (4.9)
	bag: Types.Slot,
	quick: Types.Slot, -- the quick slot: meds, food or a spare tool (LDOE_PARITY #14)
}

-- A placed station: an LDoE converter (Domain/Converter, LDOE_PARITY #18).
export type StationState = Converter.State

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
	-- The icon a crate's lid shows when the player pinned one (LDOE_PARITY #16's brush),
	-- by crate UID; otherwise the lid shows what the crate holds most of.
	storageLabels: { [string]: string },
	-- The item inbox (checklist 4.15): rewards, purchases and overflow, no capacity
	-- limit, never raidable, never expires. inboxSeq numbers its rows.
	inbox: { Types.InboxEntry },
	inboxSeq: number,
	stations: { [string]: StationState }, -- keyed by placed station UID (timestamped converters)
	crops: { [string]: CropState }, -- keyed by placed plot UID
	progression: { level: number, xp: number },
	-- foodDay is the UTC day number foodGained counts for (Tuning.energy.foodDailyCap).
	energy: { value: number, updatedAt: number, foodDay: number, foodGained: number },
	survival: SurvivalSave,
	quests: { active: { [string]: QuestState }, completed: { [string]: number } },
	unlocks: { recipes: { [string]: boolean }, blueprints: { [string]: boolean } },
	-- The crafting catalogue (5.9): starred recipes, and recipes already looked at
	-- (anything unlocked and not seen wears a NEW badge).
	recipeMarks: { favourites: { [string]: boolean }, seen: { [string]: boolean } },
	-- The UTC day number of the last daily food and water gift (LDOE_PARITY #58).
	gifts: { lastDay: number },
	-- Location quests (#45) by id: the period (UTC day) each last paid out. They pay once
	-- a day, never once per lobby (docs/ECONOMY.md §6.2, Domain/Quests.locationQuestOpen).
	locationQuests: { [string]: number },
	-- Robux purchases (Domain/Receipts): the receipt log (most recent last, capped at
	-- RECEIPT_LOG_SIZE), purchases per product for limits, and backpack slots bought.
	purchases: { receiptIds: { string }, counts: { [string]: number }, backpackSlots: number },
	raid: { shieldUntil: number, log: { RaidLogEntry } },
	settings: Settings,
	haven: HavenSave,
	-- Embers, the premium currency (MVP_LAUNCH Monetization v0.1): bought, never raidable.
	embers: number,
	-- The shop: when the player first won (the first night survived or the first
	-- extraction; 0 = not yet), which opens the Firestarter Kit's window (Domain/Offers).
	shop: { firstWinAt: number },
}

-- Haven Square (Services/Haven): coins from the Trader and contracts, today's contract
-- board and deliveries (Domain/Contracts; `ids` is the day's board once rolled, empty
-- before), chapters handed in to the Trail Keeper (chapter -> UTC time), the UTC day of
-- the last VIP crate and how many days in a row it came, until when a purchase opened the
-- Lounge (UTC seconds, 0 = never), when each free comfort was last taken (Domain/Comforts:
-- comfort id -> UTC seconds) and today's purchases per stock key (Domain/Market's ledger).
export type HavenSave = {
	coins: number,
	contracts: { day: number, done: { [string]: boolean }, ids: { string } },
	chapters: { [string]: number },
	vipCrateDay: number,
	vipStreak: number,
	vipTrialUntil: number,
	comforts: { [string]: number },
	stock: { day: number, bought: { [string]: number } },
}

function PlayerSchema.freshHaven(): HavenSave
	return {
		coins = 0,
		contracts = { day = 0, done = {}, ids = {} },
		chapters = {},
		vipCrateDay = 0,
		vipStreak = 0,
		vipTrialUntil = 0,
		comforts = {},
		stock = { day = 0, bought = {} },
	}
end

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
				weapon2 = Inventory.emptySlot(),
				bag = Inventory.emptySlot(),
				quick = Inventory.emptySlot(),
			},
		},
		storage = {},
		storageLabels = {},
		inbox = {},
		inboxSeq = 0,
		stations = {},
		crops = {},
		progression = { level = 1, xp = 0 },
		energy = { value = Tuning.energy.cap, updatedAt = 0, foodDay = 0, foodGained = 0 },
		survival = PlayerSchema.freshSurvival(),
		quests = { active = {}, completed = {} },
		unlocks = { recipes = {}, blueprints = {} },
		recipeMarks = { favourites = {}, seen = {} },
		gifts = { lastDay = 0 },
		locationQuests = {},
		purchases = { receiptIds = {}, counts = {}, backpackSlots = 0 },
		raid = { shieldUntil = 0, log = {} },
		settings = PlayerSchema.defaultSettings(),
		haven = PlayerSchema.freshHaven(),
		embers = 0,
		shop = { firstWinAt = 0 },
	}
end

-- The v6 station recipes, for refunding saved queues (their ratios changed in v7).
local LEGACY_RECIPES: { [string]: { inputs: { Types.ItemStack }, outputs: { Types.ItemStack } } } = {
	["recipe.plank"] = {
		inputs = { { itemId = "item.timber", count = 4 } },
		outputs = { { itemId = "item.plank", count = 4 } },
	},
	["recipe.cloth"] = {
		inputs = { { itemId = "item.fiber", count = 4 } },
		outputs = { { itemId = "item.cloth", count = 2 } },
	},
	["recipe.stone_block"] = {
		inputs = { { itemId = "item.stone", count = 4 } },
		outputs = { { itemId = "item.stone_block", count = 2 } },
	},
	["recipe.scrap_plate"] = {
		inputs = { { itemId = "item.scrap", count = 6 } },
		outputs = { { itemId = "item.scrap_plate", count = 2 } },
	},
	["recipe.spiked_club"] = {
		inputs = {
			{ itemId = "item.plank", count = 4 },
			{ itemId = "item.rope", count = 2 },
			{ itemId = "item.scrap", count = 3 },
		},
		outputs = { { itemId = "item.spiked_club", count = 1 } },
	},
	["recipe.padded_hood"] = {
		inputs = { { itemId = "item.cloth", count = 4 }, { itemId = "item.rope", count = 2 } },
		outputs = { { itemId = "item.padded_hood", count = 1 } },
	},
	["recipe.shortbow"] = {
		inputs = {
			{ itemId = "item.plank", count = 4 },
			{ itemId = "item.rope", count = 4 },
			{ itemId = "item.pitch_glue", count = 1 },
		},
		outputs = { { itemId = "item.shortbow", count = 1 } },
	},
	["recipe.arrow"] = {
		inputs = {
			{ itemId = "item.sticks", count = 2 },
			{ itemId = "item.scrap", count = 2 },
			{ itemId = "item.fiber", count = 1 },
		},
		outputs = { { itemId = "item.arrow", count = 5 } },
	},
	["recipe.padded_vest"] = {
		inputs = {
			{ itemId = "item.cloth", count = 6 },
			{ itemId = "item.rope", count = 3 },
			{ itemId = "item.scrap_plate", count = 2 },
		},
		outputs = { { itemId = "item.padded_vest", count = 1 } },
	},
	["recipe.scrapblade"] = {
		inputs = {
			{ itemId = "item.scrap_plate", count = 4 },
			{ itemId = "item.plank", count = 2 },
			{ itemId = "item.cloth", count = 2 },
			{ itemId = "item.rivets", count = 2 },
		},
		outputs = { { itemId = "item.scrapblade", count = 1 } },
	},
	["recipe.pack_frame"] = {
		inputs = {
			{ itemId = "item.cloth", count = 6 },
			{ itemId = "item.rope", count = 6 },
			{ itemId = "item.scrap_plate", count = 3 },
			{ itemId = "item.rivets", count = 2 },
			{ itemId = "item.brass_gear", count = 1 },
		},
		outputs = { { itemId = "item.pack_frame", count = 1 } },
	},
	["recipe.boiled_water"] = {
		inputs = { { itemId = "item.murky_water", count = 2 } },
		outputs = { { itemId = "item.boiled_water", count = 2 } },
	},
	["recipe.roasted_ashroot"] = {
		inputs = { { itemId = "item.ashroot", count = 2 } },
		outputs = { { itemId = "item.roasted_ashroot", count = 2 } },
	},
	["recipe.ember_tea"] = {
		inputs = { { itemId = "item.emberberry", count = 3 }, { itemId = "item.boiled_water", count = 1 } },
		outputs = { { itemId = "item.ember_tea", count = 1 } },
	},
	["recipe.pitch_glue"] = {
		inputs = { { itemId = "item.fatwood", count = 2 } },
		outputs = { { itemId = "item.pitch_glue", count = 1 } },
	},
	["recipe.hearth_stew"] = {
		inputs = {
			{ itemId = "item.ashroot", count = 2 },
			{ itemId = "item.emberberry", count = 3 },
			{ itemId = "item.boiled_water", count = 1 },
		},
		outputs = { { itemId = "item.hearth_stew", count = 1 } },
	},
}

--[[
	v7, LDoE parity (LDOE_PARITY.md):
	- Stations became converters (#18). Each saved v6 queue is settled into the inbox:
	  jobs finished by `now` (and, on fuelled stations, by the time the fire went out)
	  give their outputs, unfinished ones give their inputs back, and a Recycler job
	  gives its item back. The record restarts as an empty converter at its level.
	- Stacks are 20 (scrap 50, #15) and bags give +5/+10: anything over a slot's new
	  stack, or in backpack slots past the bag's new size, moves to the inbox.
	- The quick slot joins the equipment (#14).
	- Home nodes moved to the outpost save and became finite (#30): homeNodes goes.
	Nothing is lost: every item that no longer fits lands in the inbox (source "Update").
]]
function PlayerSchema.migrateToV7(data: { [string]: any }, now: number)
	local inbox: { any } = if type(data.inbox) == "table" then data.inbox :: any else {}
	data.inbox = inbox
	local seq = if type(data.inboxSeq) == "number" then data.inboxSeq else 0
	local function toInbox(itemId: any, count: any, durability: number?)
		if type(itemId) ~= "string" or itemId == "" or type(count) ~= "number" or count <= 0 then
			return
		end
		seq += 1
		table.insert(inbox, {
			id = `i{seq}`,
			itemId = itemId,
			count = count,
			durability = durability,
			source = "Update",
			at = now,
		})
	end

	-- Stations: settle each v6 queue, then restart as a converter.
	local stations: { [string]: any } = if type(data.stations) == "table" then data.stations :: any else {}
	for uid, record in stations do
		local def = if type(record) == "table" then Stations[record.stationId] else nil
		if def == nil then
			stations[uid] = nil
			continue
		end
		local queue = if type(record.queue) == "table" then record.queue else {}
		local fuelEndsAt = if type(record.fuelEndsAt) == "number" then record.fuelEndsAt else 0
		local cutoff = if def.fuel then math.min(now, fuelEndsAt) else now
		for _, job in queue do
			if type(job) ~= "table" or type(job.id) ~= "string" then
				continue
			end
			local legacy = LEGACY_RECIPES[job.id]
			if legacy then
				local finished = type(job.endsAt) == "number" and job.endsAt <= cutoff
				local given: { Types.ItemStack } = if finished then legacy.outputs else legacy.inputs
				for _, stack in given do
					toInbox(stack.itemId, stack.count)
				end
			else
				-- A Recycler job, "<itemId>#<percent>": the item comes back as it went in.
				local itemId, percent = string.match(job.id, "^(.-)#(%d+)$")
				local item = if itemId then Items[itemId] else nil
				if item then
					local share = (tonumber(percent) or 100) / 100
					local durability = if item.durability then math.max(1, math.floor(item.durability * share)) else nil
					toInbox(itemId, 1, durability)
				end
			end
		end
		local fresh = Converter.new(def, 0)
		fresh.level = math.clamp(if type(record.level) == "number" then record.level else 1, 1, #def.levels)
		stations[uid] = fresh
	end
	data.stations = stations

	-- Stacks and bag sizes.
	local function clamp(container: any)
		if type(container) ~= "table" then
			return
		end
		for _, slot in container do
			local item = if type(slot) == "table" then Items[slot.itemId] else nil
			if item and type(slot.count) == "number" and slot.count > item.stackSize then
				toInbox(slot.itemId, slot.count - item.stackSize, slot.durability)
				slot.count = item.stackSize
			end
		end
	end
	local inventory = data.inventory
	if type(inventory) == "table" then
		clamp(inventory.pockets)
		clamp(inventory.backpack)
		local equipment = if type(inventory.equipment) == "table" then inventory.equipment else {}
		inventory.equipment = equipment
		if equipment.quick == nil then
			equipment.quick = { itemId = "", count = 0 }
		end
		local bag = if type(equipment.bag) == "table" then Items[equipment.bag.itemId] else nil
		local capacity = Tuning.inventory.backpackSlots + (if bag and bag.bagSlots then bag.bagSlots else 0)
		local backpack: { any } = if type(inventory.backpack) == "table" then inventory.backpack :: any else {}
		for index = #backpack, capacity + 1, -1 do
			local slot = backpack[index]
			if type(slot) == "table" then
				toInbox(slot.itemId, slot.count, slot.durability)
			end
			backpack[index] = nil
		end
		for index = #backpack + 1, capacity do
			backpack[index] = { itemId = "", count = 0 }
		end
		inventory.backpack = backpack
	end
	if type(data.storage) == "table" then
		for _, container in data.storage do
			clamp(container)
		end
	end

	if type(data.storageLabels) ~= "table" then
		data.storageLabels = {}
	end
	if type(data.gifts) ~= "table" then
		data.gifts = { lastDay = 0 }
	end
	data.homeNodes = nil
	data.inboxSeq = seq
end

-- The v7 converter lines whose ratio, timer or station changed in v8 (docs/ECONOMY.md §2).
-- A station saved mid-way through one of these is settled under its old rule.
local LEGACY_V7_LINES: { Types.RecipeDef } = {
	{
		id = "recipe.plank",
		inputs = { { itemId = "item.timber", count = 1 } },
		outputs = { { itemId = "item.plank", count = 1 } },
		stationId = "station.woodworking_bench",
		craftSeconds = 4 * 60,
		unlock = { kind = "default" },
	},
	{
		id = "recipe.stone_block",
		inputs = { { itemId = "item.stone", count = 2 } },
		outputs = { { itemId = "item.stone_block", count = 1 } },
		stationId = "station.workbench",
		craftSeconds = 4 * 60,
		unlock = { kind = "default" },
	},
	{
		id = "recipe.scrap_plate",
		inputs = { { itemId = "item.scrap", count = 3 } },
		outputs = { { itemId = "item.scrap_plate", count = 1 } },
		stationId = "station.workbench",
		craftSeconds = 4 * 60,
		unlock = { kind = "default" },
	},
	{
		id = "recipe.blackpowder",
		inputs = { { itemId = "item.niter", count = 2 } },
		outputs = { { itemId = "item.blackpowder", count = 2 } },
		stationId = "station.ammo_press",
		craftSeconds = 6 * 60,
		unlock = { kind = "default" },
	},
}

local function legacyLine(stationId: string, itemId: string): Types.RecipeDef?
	for _, recipe in LEGACY_V7_LINES do
		if recipe.stationId == stationId and recipe.inputs[1].itemId == itemId then
			return recipe
		end
	end
	return nil
end

--[[
	v8, the economy rescale (docs/ECONOMY.md §11.3). Nothing owned is lost:
	- A station loaded with the input of a line whose rule changed (planks 1:1, blocks and
	  plates at the Workbench, powder 2:2) is settled under the v7 rule: the batches done by
	  `now` (and while its fuel lasted) become outputs, and outputs, leftover input and
	  unlit fuel all go to the inbox (source "Update"). The station restarts empty at its
	  level. The scrap_plate line held scrap; it now takes ingots.
	- Stack counts never change.
	- Durability above an item's new maximum (ECONOMY §8.1: a Pipe Pistol at 120 of 140)
	  is clamped to it, wherever the item is: pockets, backpack, equipment, crates, the
	  inbox and station slots.
	- PlayerData.locationQuests starts empty (location quests pay once a day, §6.2).
]]
function PlayerSchema.migrateToV8(data: { [string]: any }, now: number)
	local inbox: { any } = if type(data.inbox) == "table" then data.inbox :: any else {}
	data.inbox = inbox
	local seq = if type(data.inboxSeq) == "number" then data.inboxSeq else 0
	local function toInbox(slot: any)
		if type(slot) ~= "table" or type(slot.itemId) ~= "string" or slot.itemId == "" then
			return
		end
		if type(slot.count) ~= "number" or slot.count <= 0 then
			return
		end
		seq += 1
		table.insert(inbox, {
			id = `i{seq}`,
			itemId = slot.itemId,
			count = slot.count,
			durability = slot.durability,
			source = "Update",
			at = now,
		})
	end

	local stations: { [string]: any } = if type(data.stations) == "table" then data.stations :: any else {}
	for uid, record in stations do
		local def = if type(record) == "table" then Stations[record.stationId] else nil
		local input = if def and type(record.input) == "table" then record.input else nil
		local legacy = if def and input then legacyLine(def.id, input.itemId) else nil
		if def == nil or legacy == nil then
			continue
		end
		local state = record :: Converter.State
		local settled = state
		if type(state.at) == "number" and state.at > 0 then
			local ok, advanced = pcall(Converter.advance, state, {
				def = def,
				recipes = { [legacy.id] = legacy },
				items = Items :: any,
			}, now)
			if ok then
				settled = advanced
			end
		end
		for _, slot in settled.output do
			toInbox(slot)
		end
		toInbox(settled.input)
		toInbox(settled.fuel)
		local fresh = Converter.new(def, now)
		fresh.level = math.clamp(if type(state.level) == "number" then state.level else 1, 1, #def.levels)
		stations[uid] = fresh
	end
	data.stations = stations

	local function clamp(slot: any)
		local item = if type(slot) == "table" then Items[slot.itemId] else nil
		local max = if item then item.durability else nil
		if max and type(slot.durability) == "number" and slot.durability > max then
			slot.durability = max
		end
	end
	local function clampAll(container: any)
		if type(container) == "table" then
			for _, slot in container do
				clamp(slot)
			end
		end
	end
	local inventory = data.inventory
	if type(inventory) == "table" then
		clampAll(inventory.pockets)
		clampAll(inventory.backpack)
		clampAll(inventory.equipment)
	end
	if type(data.storage) == "table" then
		for _, container in data.storage do
			clampAll(container)
		end
	end
	clampAll(inbox)
	for _, record in stations do
		if type(record) == "table" then
			clamp(record.input)
			clampAll(record.output)
		end
	end

	if type(data.locationQuests) ~= "table" then
		data.locationQuests = {}
	end
	data.inboxSeq = seq
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
	-- v4: the locked stash becomes the unlimited item inbox (its items move over), and
	-- the crafting catalogue's favourites and seen marks start empty.
	[3] = function(data)
		local entries, seq = {}, 0
		for _, slot in (if type(data.lockedStash) == "table" then data.lockedStash else {}) do
			if type(slot) == "table" and type(slot.count) == "number" and slot.count > 0 then
				seq += 1
				table.insert(entries, {
					id = `i{seq}`,
					itemId = slot.itemId,
					count = slot.count,
					durability = slot.durability,
					source = "Stash",
					at = 0,
				})
			end
		end
		data.inbox = entries
		data.inboxSeq = seq
		data.lockedStash = nil
		data.recipeMarks = { favourites = {}, seen = {} }
	end,
	-- v5: home resource nodes are saved (depleted ones stay depleted across sessions).
	[4] = function(data)
		if type(data.homeNodes) ~= "table" then
			data.homeNodes = {}
		end
	end,
	-- v6: a secondary weapon slot (the 1-9 hotbar became two weapon slots, 4.9).
	[5] = function(data)
		local inventory = data.inventory
		if
			type(inventory) == "table"
			and type(inventory.equipment) == "table"
			and inventory.equipment.weapon2 == nil
		then
			inventory.equipment.weapon2 = { itemId = "", count = 0 }
		end
	end,
	-- v7: LDoE parity (LDOE_PARITY.md). See migrateToV7.
	[6] = function(data)
		PlayerSchema.migrateToV7(data, os.time())
	end,
	-- v8: the economy rescale (docs/ECONOMY.md). See migrateToV8.
	[7] = function(data)
		PlayerSchema.migrateToV8(data, os.time())
	end,
	-- v9: Haven Square (coins, contracts, chapter hand-ins, the VIP crate).
	[8] = function(data)
		if type(data.haven) ~= "table" then
			data.haven = PlayerSchema.freshHaven()
		end
	end,
	-- v10: the v0.1 shop: Embers, the first win, the VIP crate streak and Lounge trial. The
	-- Backpack Upgrade product became the Pack Expansion pass: slots bought stay, counted as
	-- the pass.
	[9] = function(data)
		if type(data.embers) ~= "number" then
			data.embers = 0
		end
		if type(data.shop) ~= "table" then
			data.shop = { firstWinAt = 0 }
		end
		if type(data.haven) == "table" then
			data.haven.vipStreak = data.haven.vipStreak or 0
			data.haven.vipTrialUntil = data.haven.vipTrialUntil or 0
		end
		local purchases: any = data.purchases
		if type(purchases) == "table" then
			purchases.counts = if type(purchases.counts) == "table" then purchases.counts else {}
			purchases.backpackSlots = if type(purchases.backpackSlots) == "number" then purchases.backpackSlots else 0
		end
		local counts: { [string]: any }? = if type(purchases) == "table" then purchases.counts else nil
		if type(counts) == "table" then
			local legacy = counts["product.backpack_upgrade"]
			if type(legacy) == "number" and legacy > 0 then
				counts["product.pack_expansion"] = 1
			end
			counts["product.backpack_upgrade"] = nil
		end
	end,
	-- v11: Haven Square H1: the free comforts' cooldowns (Well, Soup Kitchen), the daily
	-- stock ledger (the Lounge traders' per-day limits) and the day's contract board.
	[10] = function(data)
		local haven: any = data.haven
		if type(haven) ~= "table" then
			data.haven = PlayerSchema.freshHaven()
			return
		end
		if type(haven.comforts) ~= "table" then
			haven.comforts = {}
		end
		if type(haven.stock) ~= "table" then
			haven.stock = { day = 0, bought = {} }
		end
		if type(haven.contracts) ~= "table" then
			haven.contracts = { day = 0, done = {}, ids = {} }
		elseif type(haven.contracts.ids) ~= "table" then
			haven.contracts.ids = {}
		end
	end,
} :: Migrations.Steps

return PlayerSchema
