--!strict
--[[
	Shared types for content definitions and inventory state.

	Content IDs are permanent strings such as "item.wood" (ARCHITECTURE.md §1.6).
	Display names may change; IDs never do, and save data stores IDs only.
	Field lists are M0 placeholders; they are finalised from docs/ldoe-systems/.
]]

-- IDs ----------------------------------------------------------------------

export type ItemId = string -- "item.*"
export type RecipeId = string -- "recipe.*"
export type StationId = string -- "station.*"
export type LootTableId = string -- "loot.*"
export type LocationId = string -- "loc.*"
export type BuildPieceId = string -- "build.*"
export type ProductId = string -- "product.*"

-- Items ----------------------------------------------------------------------

export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary"

export type ItemCategory = "resource" | "material" | "tool" | "weapon" | "armor" | "consumable" | "key" | "misc"

export type ItemDef = {
	id: ItemId,
	name: string,
	category: ItemCategory,
	tier: number,
	rarity: Rarity,
	stackSize: number, -- 1 for tools, weapons and armor
	durability: number?, -- max durability; only for items with stackSize 1
	icon: string, -- "rbxassetid://..."; "" until the icon exists
	flags: { [string]: boolean }?,
}

-- An amount of one item, used for costs, recipe inputs and outputs, and grants.
export type ItemStack = {
	itemId: ItemId,
	count: number,
}

-- Recipes and stations ---------------------------------------------------------

export type UnlockGate = { kind: "default" } | { kind: "level", level: number } | { kind: "blueprint", itemId: ItemId }

export type RecipeDef = {
	id: RecipeId,
	inputs: { ItemStack },
	outputs: { ItemStack },
	stationId: StationId?, -- nil means hand-crafted from the inventory
	stationLevel: number?, -- minimum station level; defaults to 1
	craftSeconds: number,
	unlock: UnlockGate,
}

export type StationLevel = {
	level: number,
	upgradeCost: { ItemStack }, -- empty for level 1 (paid by the build piece)
	queueSlots: number,
	speedMultiplier: number, -- 1 = recipe craftSeconds as written
}

export type StationFuel = {
	itemIds: { ItemId },
	secondsPerUnit: number,
}

export type StationDef = {
	id: StationId,
	name: string,
	levels: { StationLevel },
	fuel: StationFuel?,
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

-- World map ---------------------------------------------------------------------

export type LocationDef = {
	id: LocationId,
	name: string,
	fogTier: number,
	levelGate: number,
	energyCost: number, -- cost to Run there
	walkSeconds: number, -- real time to Walk there for free
	resetSeconds: number?, -- nil means the location never resets
	lootTableIds: { LootTableId },
	-- enemySpawns arrive with Data/Enemies (M1, step 8) so the validator can check them.
}

-- Building -----------------------------------------------------------------------

export type BuildPieceKind = "foundation" | "wall" | "doorway" | "door" | "roof" | "station" | "storage"

export type BuildPieceDef = {
	id: BuildPieceId,
	name: string,
	kind: BuildPieceKind,
	tier: number,
	hp: number,
	cost: { ItemStack },
	breachCost: number, -- breach charges needed to destroy it in a raid
	upgradesTo: BuildPieceId?,
	stationId: StationId?, -- required when kind == "station"
}

-- Shop ----------------------------------------------------------------------------

export type ProductKind = "devProduct" | "gamePass"

export type ProductGrant =
	{ kind: "item", itemId: ItemId, count: number }
	| { kind: "energy", amount: number }
	| { kind: "backpackSlots", amount: number }

export type ProductDef = {
	id: ProductId,
	name: string,
	kind: ProductKind,
	robloxId: number, -- 0 until the product exists on the Creator Dashboard
	grants: { ProductGrant }, -- delivered into the locked stash (ARCHITECTURE.md §6)
}

-- Tuning ---------------------------------------------------------------------------

export type TuningDef = {
	energy: { cap: number, secondsPerPoint: number },
	inventory: { pocketSlots: number, backpackSlots: number, maxBackpackSlots: number, lockedStashSlots: number },
	raid: { lootFraction: number },
	shield: { afterRaidSeconds: number },
}

-- Everything in Data/, as one bundle (what the validator checks).
export type Content = {
	Items: { [ItemId]: ItemDef },
	Recipes: { [RecipeId]: RecipeDef },
	Stations: { [StationId]: StationDef },
	LootTables: { [LootTableId]: LootTableDef },
	Locations: { [LocationId]: LocationDef },
	BuildPieces: { [BuildPieceId]: BuildPieceDef },
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
