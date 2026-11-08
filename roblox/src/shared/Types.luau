--!strict
--[[
	Shared types for content definitions and inventory state.

	Content IDs are permanent strings such as "item.timber" (ARCHITECTURE.md §1.6).
	Display names may change; IDs never do, and save data stores IDs only.
	The human-readable summary of the MVP content is docs/CONTENT_MVP.md.

	Units: times are seconds, distances and speeds are studs (one build cell is
	Tuning.building.gridStuds), chances are 0..1.
]]

-- IDs ----------------------------------------------------------------------

export type ItemId = string -- "item.*"
export type RecipeId = string -- "recipe.*"
export type StationId = string -- "station.*"
export type LootTableId = string -- "loot.*"
export type LocationId = string -- "loc.*"
export type BuildPieceId = string -- "build.*"
export type ProductId = string -- "product.*"
export type NodeId = string -- "node.*"
export type EnemyId = string -- "enemy.*"
export type QuestId = string -- "quest.*"

-- An inclusive integer range, e.g. how many containers spawn.
export type Range = { min: number, max: number }

-- Items ----------------------------------------------------------------------

export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary"

export type ItemCategory =
	"resource"
	| "material"
	| "tool"
	| "weapon"
	| "ammo"
	| "armor"
	| "bag"
	| "consumable"
	| "part"
	| "junk" -- loot clutter that only the Recycler turns into something useful
	| "blueprint" -- read to learn the recipes and pieces whose unlock gate names it
	| "key"
	| "misc"

-- Matches the keys of PlayerSchema.Equipment.
export type EquipSlot = "head" | "body" | "legs" | "feet" | "weapon" | "bag"

export type ToolKind = "hatchet" | "pick"

export type ToolStats = {
	kind: ToolKind,
	tier: number, -- harvests nodes whose tool.tier is this or lower
}

export type WeaponStats = {
	kind: "melee" | "ranged",
	damage: number, -- per hit, before armor
	attacksPerSecond: number,
	range: number, -- studs
	ammoItemId: ItemId?, -- ranged only: consumed one per shot
}

export type ArmorStats = {
	defense: number, -- reduction = defense / (defense + Tuning.combat.armorConstant)
}

-- What eating, drinking or using a consumable restores. Missing fields are 0.
export type ConsumeEffect = {
	health: number?,
	hunger: number?,
	thirst: number?,
	energy: number?, -- food and drink energy counts toward Tuning.energy.foodDailyCap
}

export type ItemDef = {
	id: ItemId,
	name: string,
	category: ItemCategory,
	tier: number,
	rarity: Rarity,
	stackSize: number, -- 1 for tools, weapons, armor and bags
	durability: number?, -- max durability; only for items with stackSize 1
	icon: string, -- "rbxassetid://..."; "" until the icon exists
	flags: { [string]: boolean }?,
	equipSlot: EquipSlot?, -- weapons, armor and bags
	tool: ToolStats?,
	weapon: WeaponStats?,
	armor: ArmorStats?,
	consume: ConsumeEffect?,
	bagSlots: number?, -- bags: backpack slots while equipped
}

-- An amount of one item, used for costs, recipe inputs and outputs, and grants.
export type ItemStack = {
	itemId: ItemId,
	count: number,
}

-- Recipes and stations ---------------------------------------------------------

-- Gates recipes and build pieces. A blueprint gate is met once the player has
-- read that blueprint item (PlayerData.unlocks.blueprints[itemId]).
export type UnlockGate = { kind: "default" } | { kind: "level", level: number } | { kind: "blueprint", itemId: ItemId }

export type RecipeDef = {
	id: RecipeId,
	inputs: { ItemStack },
	outputs: { ItemStack },
	stationId: StationId?, -- nil means hand-crafted from the inventory
	stationLevel: number?, -- minimum station level; defaults to 1
	craftSeconds: number, -- one job; divided by the station level's speedMultiplier
	unlock: UnlockGate,
}

export type StationLevel = {
	level: number,
	upgradeCost: { ItemStack }, -- empty for level 1 (paid by the build piece)
	queueSlots: number, -- jobs that can be queued or waiting for collection
	speedMultiplier: number, -- 1 = recipe craftSeconds as written
	requiredLevel: number?, -- player level needed to upgrade to this level
	salvageChanceBonus: number?, -- Recycler: added to every non-guaranteed output chance
}

export type StationFuel = {
	itemIds: { ItemId }, -- what the station accepts as fuel
	secondsPerUnit: number, -- burn time for a fuel item not listed in burnSeconds
	burnSeconds: { [ItemId]: number }?, -- per-item burn time
	maxUnits: number, -- fuel slot capacity
}

-- One output of a Recycler job. chance is rolled once, scaled by the input's
-- remaining durability fraction when it has durability (Tuning.salvage).
export type SalvageOutput = {
	itemId: ItemId,
	min: number,
	max: number,
	chance: number,
}

export type SalvageDef = {
	inputItemId: ItemId,
	seconds: number,
	outputs: { SalvageOutput },
}

export type StationDef = {
	id: StationId,
	name: string,
	levels: { StationLevel },
	fuel: StationFuel?, -- jobs only progress while fuel burns
	salvage: { SalvageDef }?, -- Recycler: what it breaks down
}

-- Loot ------------------------------------------------------------------------

export type LootEntry = {
	itemId: ItemId,
	weight: number,
	min: number,
	max: number,
}

export type LootTableDef = {
	id: LootTableId,
	rolls: { min: number, max: number },
	entries: { LootEntry },
	guaranteed: { ItemStack }?,
}

-- Resource nodes ------------------------------------------------------------------

export type NodeYield = {
	itemId: ItemId,
	perHit: number,
	chance: number?, -- nil means every hit; otherwise rolled per hit
}

export type ResourceNodeDef = {
	id: NodeId,
	name: string,
	tool: ToolStats?, -- nil means harvested by hand
	hits: number, -- hits to deplete; each tool hit costs Tuning.gathering.durabilityPerHit
	yields: { NodeYield },
	xpPerHit: number,
	respawnSeconds: number, -- in shared instances and on the home plot
}

-- Enemies ---------------------------------------------------------------------------

export type EnemyDef = {
	id: EnemyId,
	name: string,
	hp: number,
	damage: number, -- per hit, before armor
	attackSeconds: number, -- time between hits
	attackRange: number, -- studs
	moveSpeed: number, -- studs per second while chasing (player walk speed is in Tuning.player)
	aggroRadius: number, -- studs; noise and light can widen it later
	xp: number,
	lootTableId: LootTableId, -- rolled when it dissolves into ash
}

-- World map ---------------------------------------------------------------------

-- Fog tier: 1 = Light, 2 = Dense, 3 = Black.

export type LocationReset =
	{ kind: "onExit" } -- a fresh instance every visit
	| { kind: "timer", seconds: number } -- starts on first entry; cleared state persists until it ends
	| { kind: "perAppearance" } -- rotating locations: fresh each time they appear

export type LocationAvailability =
	{ kind: "always" }
	-- Open while (now - offsetSeconds) % periodSeconds < activeSeconds, in UTC seconds.
	| { kind: "rotating", periodSeconds: number, activeSeconds: number, offsetSeconds: number }

export type LocationContainer = {
	lootTableId: LootTableId,
	count: Range,
}

export type LocationNode = {
	nodeId: NodeId,
	count: number,
}

export type EnemySpawn = {
	enemyId: EnemyId,
	count: Range,
}

export type LocationDef = {
	id: LocationId,
	name: string,
	fogTier: number,
	levelGate: number,
	energyCost: number, -- cost to Run there
	walkSeconds: number, -- real time to Walk there for free
	reset: LocationReset,
	availability: LocationAvailability,
	containers: { LocationContainer },
	nodes: { LocationNode },
	enemySpawns: { EnemySpawn },
	-- The Fog map panel's preview. Every item listed must actually drop there.
	mainLoot: { ItemId },
	possibleLoot: { ItemId },
}

-- Building -----------------------------------------------------------------------

-- foundation: a grid cell. wall, doorway, window: a cell edge. door: inside a doorway.
-- station, storage: on a cell, on the ground or on a foundation.
export type BuildPieceKind = "foundation" | "wall" | "doorway" | "door" | "window" | "roof" | "station" | "storage"

export type BuildPieceDef = {
	id: BuildPieceId,
	name: string,
	kind: BuildPieceKind,
	tier: number, -- 1 Wood, 2 Scrap Metal, 3 Reinforced; edge pieces can't exceed the foundation's tier
	hp: number,
	cost: { ItemStack }, -- to place it directly; equals the lower tier's cost plus its upgradeCost
	breachCost: number, -- breach charges needed to destroy it in a raid
	upgradesTo: BuildPieceId?,
	upgradeCost: { ItemStack }?, -- to upgrade in place to upgradesTo; set exactly when upgradesTo is
	stationId: StationId?, -- required when kind == "station"
	storageSlots: number?, -- required when kind == "storage"
	minFoundationTier: number?, -- nil means it can stand on bare ground
	maxPerPlot: number?, -- nil means no limit
	unlock: UnlockGate?, -- nil means available from the start
}

-- Player progression ---------------------------------------------------------------

export type PlayerLevelDef = {
	level: number,
	xp: number, -- total XP needed to reach this level; level 1 is 0
	rewards: { ItemStack }?, -- granted on reaching it (unlocks come from UnlockGates)
}

export type QuestObjective =
	{ kind: "gather", itemId: ItemId, count: number } -- harvested from nodes
	| { kind: "craft", recipeId: RecipeId, count: number } -- jobs collected
	| { kind: "build", pieceId: BuildPieceId, count: number } -- placed or upgraded into
	| { kind: "travel", locationId: LocationId } -- arrive by Run or Walk
	| { kind: "loot", count: number, locationId: LocationId? } -- containers opened
	| { kind: "kill", count: number, enemyId: EnemyId? } -- nil means any Hollow
	| { kind: "equip", itemId: ItemId }
	| { kind: "consume", itemId: ItemId, count: number }
	| { kind: "reachLevel", level: number }

export type QuestRewards = {
	xp: number,
	items: { ItemStack }?,
	energy: number?,
}

export type QuestDef = {
	id: QuestId,
	name: string,
	description: string,
	prerequisite: QuestId?, -- nil starts the chain
	objectives: { QuestObjective },
	rewards: QuestRewards,
}

-- Shop ----------------------------------------------------------------------------

export type ProductKind = "devProduct" | "gamePass"

export type ProductGrant =
	{ kind: "item", itemId: ItemId, count: number }
	| { kind: "energy", amount: number } -- may overfill up to Tuning.energy.overfillCap
	| { kind: "backpackSlots", amount: number }

export type ProductDef = {
	id: ProductId,
	name: string,
	kind: ProductKind,
	robloxId: number, -- 0 until the product exists on the Creator Dashboard
	-- Fallback display price only. The live price is read from MarketplaceService
	-- so Roblox price tests and regional pricing work (GAME_DESIGN.md guardrails).
	defaultPriceRobux: number,
	limit: number?, -- purchases per player; nil means unlimited (game passes are 1)
	offerMaxLevel: number?, -- only offered at or below this player level
	grants: { ProductGrant }, -- item grants go into the locked stash (ARCHITECTURE.md §6)
}

-- Tuning ---------------------------------------------------------------------------

export type TuningDef = {
	energy: {
		cap: number,
		secondsPerPoint: number, -- regen, offline included
		overfillCap: number, -- tonics and purchases may go past cap up to this
		levelUpRestore: number,
		foodDailyCap: number, -- energy from food and drink per UTC day
	},
	inventory: {
		pocketSlots: number,
		backpackSlots: number, -- with no bag equipped
		maxBackpackSlots: number, -- largest bag plus every purchasable upgrade
		lockedStashSlots: number,
	},
	player: {
		maxHealth: number,
		walkSpeed: number,
		sprintSpeed: number,
		fistDamage: number,
		fistAttacksPerSecond: number,
		fistRange: number,
	},
	survival: {
		maxHunger: number,
		maxThirst: number,
		hungerDrainSeconds: number, -- seconds per point lost
		thirstDrainSeconds: number,
		starvingDamagePerSecond: number, -- at 0 hunger
		dehydratedDamagePerSecond: number, -- at 0 thirst
		regenThreshold: number, -- passive healing while hunger and thirst are both at or above this
		regenPerSecond: number,
		respawnHealth: number,
		respawnHunger: number,
		respawnThirst: number,
	},
	combat: {
		armorConstant: number,
		weaponDurabilityPerHit: number,
		armorDurabilityPerHitTaken: number,
	},
	gathering: {
		swingSeconds: number,
		durabilityPerHit: number,
	},
	travel: {
		runSeconds: number, -- loading time of a Run, after paying Energy
		fogTierNames: { string },
	},
	death: {
		dropLifetimeSeconds: number,
		dropsPockets: boolean,
		dropsBackpack: boolean,
		keepsEquipped: boolean,
		keepsLatestDropOnly: boolean,
	},
	building: {
		gridStuds: number,
		wallHeightStuds: number,
		plotCells: number, -- the home plot is plotCells x plotCells
		freeRefundSeconds: number, -- full refund if removed this soon after placing
		demolishRefundFraction: number, -- afterwards
	},
	salvage: {
		durabilityScalesChance: boolean,
	},
	home: {
		nodes: { LocationNode }, -- what grows on a fresh home plot; feeds the first quests
	},
	newPlayer: {
		items: { ItemStack },
	},
	raid: { lootFraction: number },
	shield: { afterRaidSeconds: number },
}

-- Everything in Data/, as one bundle (what the validator checks).
export type Content = {
	Items: { [ItemId]: ItemDef },
	Recipes: { [RecipeId]: RecipeDef },
	Stations: { [StationId]: StationDef },
	Nodes: { [NodeId]: ResourceNodeDef },
	LootTables: { [LootTableId]: LootTableDef },
	Enemies: { [EnemyId]: EnemyDef },
	Locations: { [LocationId]: LocationDef },
	BuildPieces: { [BuildPieceId]: BuildPieceDef },
	Levels: { PlayerLevelDef }, -- index = level
	Quests: { [QuestId]: QuestDef },
	Products: { [ProductId]: ProductDef },
	Tuning: TuningDef,
}

-- Inventory state ---------------------------------------------------------------------

-- One inventory slot. An empty slot is { itemId = "", count = 0 } so containers
-- stay dense arrays, which save cleanly to DataStores.
export type Slot = {
	itemId: ItemId,
	count: number,
	durability: number?,
}

export type Container = { Slot }

export type Inventory = {
	pockets: Container,
	backpack: Container,
}

return {}
