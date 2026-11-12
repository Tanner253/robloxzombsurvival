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
	| "armor"
	| "bag"
	| "consumable"
	| "part"
	| "junk" -- loot clutter that only the Recycler turns into something useful
	| "blueprint" -- read to learn the recipes and pieces whose unlock gate names it
	| "key"
	| "misc"

-- Matches the keys of PlayerSchema.Equipment.
-- weapon2: the secondary weapon (an item's equipSlot is "weapon"). quick: LDoE's quick-access
-- pocket (LDOE_PARITY #14), which takes food, drink, healing, a weapon or a tool and feeds the
-- HUD meds button.
export type EquipSlot = "head" | "body" | "legs" | "feet" | "weapon" | "weapon2" | "bag" | "quick"

export type ToolKind = "hatchet" | "pick"

export type ToolStats = {
	kind: ToolKind,
	tier: number, -- 1 stone, 2 forged, 3 Ember Steel (M2); harvests nodes whose tool.tier is this or lower
}

export type WeaponStats = {
	kind: "melee" | "ranged",
	damage: number, -- per hit, before armor
	attacksPerSecond: number,
	range: number, -- studs
	-- Fog Runs (slice 2): exactly one of firearm and bow on ranged weapons; melee may override Tuning.melee.
	critChance: number?, -- overrides Tuning.combat.critChance
	swapSeconds: number?, -- raising it into the active hand; overrides Tuning.hands.swapSeconds
	melee: MeleeStats?,
	firearm: FirearmStats?,
	bow: BowStats?,
}

export type ArmorStats = {
	defense: number, -- reduction = defense / (defense + Tuning.combat.armorConstant)
	fogResist: number?, -- Fog Runs: share of fog exposure this piece blocks (Domain/FogExposure)
	-- A gas mask's filter (content2): durability lost per second in Dense or Black fog
	-- (FogExposure.filterWear). A spent filter breaks the mask like any worn-out armor.
	filterPerSecond: number?,
}

-- What eating, drinking or using a consumable restores. Missing fields are 0.
export type ConsumeEffect = {
	health: number?,
	hunger: number?,
	thirst: number?,
	energy: number?, -- food and drink energy counts toward Tuning.energy.foodDailyCap
	-- Meds past the dressing (content2, Domain/Meds): this much more health, spread evenly
	-- over `seconds` after the instant part.
	healOverTime: { amount: number, seconds: number }?,
}

export type ItemDef = {
	id: ItemId,
	name: string,
	description: string?, -- one line for tooltips and the recipe card (5.10)
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
	flare: FlareStats?, -- the Signal Flare the Black-fog flare extract burns (Domain/Flare)
	feature: FeatureName?, -- only made by recipes of that feature: it need not be earnable while the flag is off
}

-- An amount of one item, used for costs, recipe inputs and outputs, and grants.
export type ItemStack = {
	itemId: ItemId,
	count: number,
}

-- Recipes and stations ---------------------------------------------------------

-- Gates recipes and build pieces (Domain/Unlocks). Blueprints unlock through Ember Trail
-- quests (LDOE_PARITY #49): a quest gate is met once that quest is complete. A blueprint
-- gate is met once the player has read that blueprint item (a schematic found as loot).
-- Level gates only gate locations; recipes and pieces never use them.
export type UnlockGate =
	{ kind: "default" }
	| { kind: "level", level: number }
	| { kind: "blueprint", itemId: ItemId }
	| { kind: "quest", questId: QuestId }

-- A hand recipe (no stationId) makes gear, tools, bags and food mixes instantly in the
-- crafting catalogue (LDOE_PARITY #20). A station recipe is one converter line (#18):
-- exactly one input stack and one output stack, one batch per craftSeconds.
export type RecipeDef = {
	id: RecipeId,
	inputs: { ItemStack },
	outputs: { ItemStack },
	stationId: StationId?, -- nil means hand-crafted from the inventory
	stationLevel: number?, -- minimum station level; defaults to 1
	craftSeconds: number, -- one batch; divided by the station level's speedMultiplier
	unlock: UnlockGate,
	feature: FeatureName?, -- left out of the bundle while that Tuning.features flag is off (Shared/Features)
}

export type StationLevel = {
	level: number,
	upgradeCost: { ItemStack }, -- empty for level 1 (paid by the build piece)
	-- How many items the input, output and fuel slots each hold (LDoE: 20, +20 per level).
	slotCap: number,
	speedMultiplier: number, -- 1 = recipe craftSeconds as written
	salvageChanceBonus: number?, -- Recycler: added to every non-guaranteed output chance
}

-- Fuel burns only while the station is converting (Domain/Converter).
export type StationFuel = {
	itemIds: { ItemId }, -- what the station accepts as fuel
	secondsPerUnit: number, -- burn time for a fuel item not listed in burnSeconds
	burnSeconds: { [ItemId]: number }?, -- per-item burn time
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

-- A station is an LDoE converter (LDOE_PARITY #18): one input slot -> one output slot
-- (the Recycler has outputSlots for its several outputs), an optional fuel slot, and
-- level upgrades that raise slotCap.
export type StationDef = {
	id: StationId,
	name: string,
	levels: { StationLevel },
	fuel: StationFuel?, -- converts only while fuel burns
	salvage: { SalvageDef }?, -- Recycler: what it breaks down
	outputSlots: number?, -- output slots; nil means 1
	feature: FeatureName?, -- left out of the bundle while that Tuning.features flag is off
}

-- Loot ------------------------------------------------------------------------

-- One weighted pick. Exactly one of itemId and tableId is set: an item entry gives
-- min..max units (min 0 means "maybe nothing"); a nested entry opens tableId
-- min..max times (Domain/Loot).
export type LootEntry = {
	itemId: ItemId?,
	tableId: LootTableId?,
	weight: number,
	min: number,
	max: number,
	rarity: Rarity?, -- overrides the item's rarity for pity in this table
	feature: FeatureName?, -- left out of the table while that Tuning.features flag is off (Shared/Features)
}

-- At least one in every `every` opens of the table drops an entry of `rarity` or
-- better. Counters are per player, keyed by table ID.
export type LootPity = {
	rarity: Rarity,
	every: number,
}

export type LootTableDef = {
	id: LootTableId,
	rolls: { min: number, max: number },
	entries: { LootEntry },
	guaranteed: { ItemStack }?,
	pity: LootPity?,
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
	-- Yields land only on every yieldEvery-th hit (ECONOMY §1: Ironbark gives a log every 2nd
	-- hit). nil means every hit. `hits` must be a multiple of it. XP is still per hit.
	yieldEvery: number?,
	xpPerHit: number,
	respawnSeconds: number, -- in Fog Run locations; home nodes never respawn (LDOE_PARITY #30)
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
	-- Fog Runs (slice 2): perception and fear for Domain/HollowAI.
	hearing: number, -- multiplier on every noise radius it hears (1 = as loud as emitted)
	lightFear: number, -- light exposure (0..1) at or above which it flees; above 1 never flees
	burst: BurstDef?, -- bursts into a toxic cloud near its target and on death (the bloater)
	wildlife: WildlifeDef?, -- an animal, not a Hollow (LDOE_PARITY #35): deer flee, wolves hunt
	deferred: string?, -- why no location spawns it yet (e.g. post-launch, awaiting its rig)
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
	-- Fog Runs: only while the player has a live airdrop pin (Domain/FogMap, LDOE_PARITY #43)
	| { kind: "airdrop" }

export type LocationContainer = {
	lootTableId: LootTableId,
	count: Range,
	kind: string?, -- Fog Runs: "crate", "locker", "trunk", "cabinet", "strongbox"... (art and sound)
	searchSeconds: number?, -- Fog Runs: overrides Tuning.containers.searchSeconds
}

export type LocationNode = {
	nodeId: NodeId,
	count: number,
}

export type EnemySpawn = {
	enemyId: EnemyId,
	count: Range,
	minBand: number?, -- Fog Runs: only spawns once the Fog meter reaches this band (Tuning.lobby.bands)
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
	run: LocationRun, -- Fog Runs (slice 2): the lobby, extraction and loot-band rules
}

-- Building -----------------------------------------------------------------------

-- Layers (Domain/Grid): foundation on a cell; wall, doorway, window on a cell edge;
-- door and gate inside a doorway; roof on a foundation; station, storage and
-- everything else on a cell, on the ground or on a foundation.
export type BuildPieceKind =
	"foundation"
	| "wall"
	| "doorway"
	| "door"
	| "gate"
	| "window"
	| "roof"
	| "station"
	| "storage"
	| "furniture" -- lights, the doormat: objects on the furniture sub-grid

export type BuildPieceDef = {
	id: BuildPieceId,
	name: string,
	kind: BuildPieceKind,
	tier: number, -- 1 Wood, 2 Scrap Metal, 3 Reinforced; edge pieces can't exceed the foundation's tier
	hp: number,
	-- The base tier's placement cost. For an upgraded tier (some piece's upgradesTo),
	-- the price of upgrading into it; refunds walk the chain (Domain/Grid). Upgraded
	-- tiers are reached by upgrading, never placed directly.
	cost: { ItemStack },
	breachCost: number, -- breach charges needed to destroy it in a raid (> 0)
	upgradesTo: BuildPieceId?,
	stationId: StationId?, -- required when kind == "station"
	storageSlots: number?, -- required when kind == "storage"
	minFoundationTier: number?, -- objects: the lowest foundation tier they can stand on (nil: any)
	-- Objects: the footprint on the furniture sub-grid, in quarter cells at rotation 0
	-- (w along X, d along Z). nil means one whole cell.
	footprint: { w: number, d: number }?,
	maxPerPlot: number?, -- nil means no limit
	tab: string?, -- build menu tab when it isn't the kind's own, e.g. "defense" for fences
	-- A warm light the placed piece throws (Pitch Torch, Post Lantern): studs and PointLight
	-- brightness (checklist 9.9).
	light: { range: number, brightness: number }?,
	respawn: boolean?, -- the Reed Doormat: you respawn on it at home (Services/Plots)
	unlock: UnlockGate?, -- nil means available from the start
	feature: FeatureName?, -- left out of the bundle while that Tuning.features flag is off
}

-- One piece of the damaged starter shelter every new plot starts with (LDOE_PARITY #56),
-- in plot cells as Domain/Grid targets them, laid out for a plot whose road is on +Z
-- (Domain/Shelter mirrors it for the other row). `hp` is the fraction of full HP it
-- starts with.
export type StarterPiece = {
	pieceId: BuildPieceId,
	x: number,
	z: number,
	axis: ("h" | "v")?,
	rot: number?,
	hp: number,
}

-- A long-term build goal shown on the plot (LDOE_PARITY #56): a wreck restored by handing
-- in parts. The parts checklist screen shows have/need per part, FILL UP and FINALIZE.
export type ProjectDef = {
	id: string, -- "project.*"
	name: string,
	description: string,
	parts: { ItemStack }, -- what finalizing takes
	rewards: { ItemStack }?, -- granted on finalizing (into the inbox)
}

-- Player progression ---------------------------------------------------------------

export type PlayerLevelDef = {
	level: number,
	xp: number, -- total XP needed to reach this level; level 1 is 0
	rewards: { ItemStack }?, -- granted on reaching it (unlocks come from UnlockGates)
}

-- `flag` names a feature flag (Shared/Flags) the objective waits on: while the flag is off
-- the objective is left out, so Into the Fog needs no Hollow until Fog Runs ship.
export type QuestObjective =
	{ kind: "gather", itemId: ItemId, count: number, flag: string? } -- harvested from nodes
	| { kind: "craft", recipeId: RecipeId, count: number, flag: string? } -- hand crafts or batches taken
	| { kind: "build", pieceId: BuildPieceId, count: number, flag: string? } -- placed or upgraded into
	-- Arrive by Run or Walk: at locationId, or (with fogTier instead) at any location of that tier.
	| { kind: "travel", locationId: LocationId?, fogTier: number?, flag: string? }
	| { kind: "loot", count: number, locationId: LocationId?, flag: string? } -- containers opened
	| { kind: "lootBody", count: number, flag: string? } -- a Hollow's drop picked up (Fog Runs report it)
	| { kind: "kill", count: number, enemyId: EnemyId?, flag: string? } -- nil means any Hollow
	| { kind: "equip", itemId: ItemId, flag: string? }
	| { kind: "consume", itemId: ItemId, count: number, flag: string? }
	| { kind: "reachLevel", level: number, flag: string? }

export type QuestRewards = {
	xp: number,
	items: { ItemStack }?,
	energy: number?,
}

-- One quest of the Ember Trail (LDOE_PARITY #48-50). Completing it grants its rewards and
-- unlocks every recipe and build piece whose UnlockGate names it.
export type QuestDef = {
	id: QuestId,
	name: string,
	description: string,
	order: number, -- position on the trail (1 = the first quest); the tracker sorts by it
	chapter: string, -- the Ember Trail chapter it belongs to
	prerequisite: QuestId?, -- nil starts the chain
	objectives: { QuestObjective },
	rewards: QuestRewards,
	feature: FeatureName?, -- left out of the bundle while that Tuning.features flag is off (Shared/Features)
}

-- Shop ----------------------------------------------------------------------------

export type ProductKind = "devProduct" | "gamePass"

export type ProductGrant =
	{ kind: "item", itemId: ItemId, count: number }
	| { kind: "energy", amount: number } -- may overfill up to Tuning.energy.hardCap
	| { kind: "backpackSlots", amount: number }
	| { kind: "embers", amount: number } -- the premium currency
	| { kind: "vipLounge" } -- the VIP Lounge pass (Services/Haven)
	-- One more of a capped piece may stand on your plot ("+1 Smelter can be placed"):
	-- counted from the purchase count, so nothing is stored (Domain/BuildRules.pieceSlots).
	| { kind: "pieceSlot", pieceId: BuildPieceId, amount: number }

export type ProductDef = {
	id: ProductId,
	name: string,
	description: string, -- the shop card's line
	kind: ProductKind,
	robloxId: number, -- 0 until the product exists on the Creator Dashboard
	icon: string?, -- the product icon image, also the shop card's art
	-- Fallback display price only. The live price is read from MarketplaceService
	-- so Roblox price tests and regional pricing work (GAME_DESIGN.md guardrails).
	defaultPriceRobux: number,
	limit: number?, -- purchases per player; nil means unlimited (game passes are 1)
	offerMaxLevel: number?, -- only offered at or below this player level
	-- "firstPurchase": shown only to accounts that never paid, for Tuning.embers.
	-- firstPurchaseHours after their first win, once (Domain/Offers).
	offer: "firstPurchase"?,
	tab: "best" | "supplies" | "equipment" | "building" | "embers" | "passes", -- the shop tab it sits on
	grants: { ProductGrant }, -- item grants go into the locked stash (ARCHITECTURE.md §6)
}

-- Tuning ---------------------------------------------------------------------------

-- One survival meter; matches Domain/Survival.MeterConfig. Thresholds add up: each
-- one the meter is at or below adds its damage.
export type SurvivalMeter = {
	max: number,
	decayPerSecond: number, -- only while the player is in the world
	thresholds: { { atOrBelow: number, damagePerSecond: number } },
}

-- Sections whose shape matches a Domain module's Config can be passed to it as is:
-- energy (Energy), survival (Survival), death (Death), building (Grid), travel (Travel).
export type TuningDef = {
	devSpeed: number, -- Studio-only pacing multiplier (Shared/DevSpeed); live servers use 1
	energy: {
		cap: number,
		secondsPerPoint: number, -- regen, offline included
		hardCap: number, -- tonics and purchases may go past cap up to this
		levelUpRestore: number,
		foodDailyCap: number, -- energy from food and drink per UTC day
		-- Trail Rations all location quests together pay per player per UTC day (Domain/Quests).
		locationQuestRations: { itemId: ItemId, perDay: number },
	},
	inventory: {
		pocketSlots: number,
		backpackSlots: number, -- with no bag equipped
		maxBackpackSlots: number, -- largest bag plus every purchasable upgrade
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
		hunger: SurvivalMeter,
		thirst: SurvivalMeter,
		warnAt: number, -- the HUD shows a pulsing food or water icon at or below this
		regenThreshold: number, -- passive healing while hunger and thirst are both at or above this
		regenPerSecond: number,
		respawnHealth: number,
		respawnHunger: number,
		respawnThirst: number,
		tickSeconds: number, -- how often the server applies drain, damage and regen
	},
	combat: {
		armorConstant: number,
		weaponDurabilityPerHit: number, -- a light melee hit that lands, and each arrow released
		heavyDurabilityPerHit: number, -- ECONOMY §8.1: a heavy swing that lands
		gunDurabilityPerShot: number, -- ECONOMY §8.1: every round fired, hit or miss
		-- Remaining-durability fractions the HUD ring and toasts warn at, highest first:
		-- amber, then red with a toast (ECONOMY §8.1).
		durabilityWarn: { number },
		armorDurabilityPerHitTaken: number,
		critChance: number, -- Fog Runs: the default chance a hit crits
		critMultiplier: number,
		pvpMaxHitFraction: number, -- M2 PvP: no hit takes more than this share of a full-health player
		lagToleranceStuds: number, -- server hit checks allow this much extra reach
		softLockDegrees: number, -- a locked target this close to the aim pulls the shot onto it (13.3)
	},
	gathering: {
		swingSeconds: number,
		durabilityPerHit: number,
	},
	travel: {
		runSeconds: number, -- loading time of a Run, after paying Energy
		fogTierNames: { string },
		reentryEnergyMultiplier: number, -- Fog Runs: re-entering an open lobby costs this share of the Run
		departureStuds: number, -- Fog Runs: how near the Trailhead or the fog wall a trip may start
	},
	death: {
		despawnSeconds: number, -- how long the dropped backpack waits at the location
		keepPockets: boolean, -- false: pockets drop with the backpack (equipment is always kept)
	},
	building: {
		gridStuds: number,
		wallHeightStuds: number,
		plotCells: number, -- the home plot is plotCells x plotCells
		refundGraceSeconds: number, -- full refund if removed this soon after placing or upgrading
		lateRefundFraction: number, -- afterwards
	},
	salvage: {
		durabilityScalesChance: boolean,
	},
	home: {
		-- What grows on a fresh home plot (LDOE_PARITY #30): finite, saved per outpost and
		-- never respawning. Repeat farming happens on Fog Runs.
		nodes: { LocationNode },
		renewing: { NodeId }, -- the exceptions that refill on their respawnSeconds (water)
	},
	plots: {
		count: number, -- plots per server (one per player)
		columns: number, -- plots per row; rows face each other across a road
		spacingStuds: number, -- between plot centres along a row
		rowGapStuds: number, -- the road between the two rows
		marginStuds: number, -- the gathering ring around the build grid
		plazaHalfStuds: number, -- Haven Square: half its width (x)
		plazaDepthStuds: number, -- Haven Square: half its depth (z)
	},
	interaction: {
		reachStuds: number, -- arm's reach from an object's edge (nodes, pickups, crates, stations)
		toleranceStuds: number, -- extra the server allows for movement and latency
	},
	drops: {
		lifetimeSeconds: number, -- how long a bag on the ground lasts
	},
	movement: {
		hopHeight: number, -- studs a jump lifts the survivor
		hopCooldownSeconds: number, -- seconds between hops
	},
	dayNight: {
		cycleSeconds: number, -- real seconds per day and night
		dayFraction: number, -- share of the cycle that is day (06:00-19:30)
		offset: number, -- cycle phase at server time 0
	},
	newPlayer: {
		items: { ItemStack },
	},
	-- LDOE_PARITY #58: a daily food and water gift into the inbox, below untilLevel.
	dailyGift: {
		items: { ItemStack },
		untilLevel: number,
	},
	raid: { lootFraction: number },
	shield: { afterRaidSeconds: number },
	-- ECONOMY §10.1: while a station's model is still waiting for its A grade (Art.pieces),
	-- its converter lines run at the station named here instead (Shared/StationFallback).
	-- Remove an entry the day its model is approved.
	stationFallback: { [StationId]: StationId },
	-- ECONOMY §6.2: a location quest pays once per period per player ("daily": once per UTC
	-- day), never once per lobby, so its Rations can't turn a Run into an Energy loop.
	locationQuests: { period: "daily" },
	-- ECONOMY §1/§11.1: each player in a lobby has their own copy of every resource node
	-- (containers and PvP stay contested), and nothing regrows within a lobby.
	runs: { personalNodes: boolean, nodesRegrow: boolean },
	-- ECONOMY §6.4: the Hollow's health and damage by fog tier (1-3), on top of the
	-- lobby's Fog-meter bands. Wildlife ignores it.
	hollowTierScale: { health: { number }, damage: { number } },
	-- Fog Runs (slice 2). Off until features.fogRuns; the types are in the block below.
	features: Features,
	lobby: LobbyTuning,
	extraction: ExtractionTuning,
	matchmaking: MatchmakingTuning,
	containers: ContainersTuning,
	travelBonus: TravelBonusTuning,
	noise: NoiseTuning,
	stamina: StaminaTuning,
	dodge: DodgeTuning,
	melee: MeleeTuning,
	hands: HandsTuning,
	sneak: SneakTuning,
	autoAttack: AutoAttackTuning,
	autoClear: AutoClearTuning,
	airdrops: AirdropTuning,
	regionGates: { RegionGate },
	fogExposure: FogExposureTuning,
	deathRecovery: DeathRecoveryTuning,
	hollow: HollowTuning,
	-- Robux prices by product or pass ID (display fallbacks; Data/Products).
	prices: { robux: { [string]: number } },
	embers: {
		recoverAll: number,
		ration: number,
		rationsFive: number,
		speedUpFactor: number,
		speedUpMin: number,
		speedUpMinSeconds: number,
		fillUp: { [ItemId]: number },
		vipTrialDays: number,
		firstPurchaseHours: number,
	},
}

-- Fog Runs (slice 2) -------------------------------------------------------------------
-- Everything here is read only while Tuning.features.fogRuns is on (Shared/Features).

export type FeatureName = "fogRuns" | "aiRaiders" | "dailyGift" | "regionGates" | "airdrops" | "content2"

export type Features = {
	fogRuns: boolean, -- Fog map travel, lobbies, combat and the Hollow (M1 slice 2)
	aiRaiders: boolean, -- M2: AI survivor bands backfill short lobbies
	dailyGift: boolean, -- LDOE_PARITY #58's daily food and water gift (cut from v0.1, MVP_LAUNCH)
	regionGates: boolean, -- M4: LDOE_PARITY #43's signal towers before Dense and Black fog
	airdrops: boolean, -- M4: LDOE_PARITY #43's supply drops as Energy falls
	content2: boolean, -- 2.0 batch 4 (docs/CONTENT_2_0.md): the Fortified tier, chapter 4, Zona item depth
}

-- Per-weapon melee overrides; anything missing comes from Tuning.melee.
export type MeleeStats = {
	arcDegrees: number?,
	heavyMultiplier: number?,
	knockbackStuds: number?,
	hitStopSeconds: number?,
	-- content2 (docs/CONTENT_2_0.md §4). The animation class its swings use (the parked melee
	-- WIP's taxonomy; the clips themselves are batch 1's).
	class: MeleeClass?,
	backstabMultiplier: number?, -- overrides Tuning.sneak.backstabMultiplier (Domain/Combat.backstab)
	noise: number?, -- overrides Tuning.noise.melee
	structureMultiplier: number?, -- damage to build pieces (M2 raids; nothing reads it yet)
}

export type MeleeClass = "blade" | "axe" | "pick" | "blunt" | "heavy" | "stab" | "fists"

export type FirearmStats = {
	fireInterval: number, -- seconds between shots from one magazine
	-- attacksPerSecond on a firearm is its sustained rate, reloads included (Domain/Combat.sustainedRate)
	magazine: number, -- rounds loaded at once
	reloadSeconds: number,
	spreadDegrees: number, -- full width of the aim cone
	pellets: number?, -- shotguns: projectiles per shot; damage is per pellet
	projectileSpeed: number, -- studs per second
	noiseRadius: number, -- studs (Domain/Noise)
	falloffStart: number?, -- studs; damage drops linearly from here to range
	falloffMin: number?, -- damage multiplier at full range (default 1: no falloff)
	knockbackStuds: number?,
	flare: FlareStats?, -- each round burns as a flare where it lands (the Flare Pistol; Domain/Flare)
	-- ARSENAL §8.4. The class picks the shot sound, the muzzle flash and how the gun is carried.
	animClass: GunClass,
	pierce: number?, -- extra Hollow one round passes through (the Anti-Materiel Rifle: 2)
	recoilScale: number?, -- the kick's size against a pistol's (camera shake and muzzle flash); default 1
}

export type GunClass = "pistol" | "smg" | "rifle" | "shotgun"

export type BowStats = {
	drawSeconds: number, -- time to full draw
	minDraw: number, -- draw fraction (0..1) below which a release is a dud
	projectileSpeed: number, -- studs per second at full draw
}

export type FlareStats = {
	lightRadius: number, -- studs lit
	seconds: number, -- burn time
	burnDps: number, -- damage per second to a Hollow it hits directly
	burnSeconds: number, -- how long that burn lasts
	fleeRadius: number, -- the Hollow inside this radius flee its light
}

export type BurstDef = {
	triggerRange: number, -- studs to its target that start the fuse
	fuseSeconds: number,
	radius: number, -- the toxic cloud
	damagePerSecond: number,
	cloudSeconds: number,
}

export type ExtractionPoint = {
	id: string, -- unique within the location, e.g. "north_ramp"
	name: string,
}

export type ExtractionDef =
	{ kind: "edge" } -- Light fog: walk out of any edge
	-- Dense and Black: marked points; closeCount of them are shut at random per lobby
	-- seed. flare: the Black-fog flare extract (fire a flare, survive Tuning.extraction.flareSeconds).
	| { kind: "points", points: { ExtractionPoint }, closeCount: number, flare: boolean? }

-- Extra loot rolled into every container searched once the meter reaches `band`.
export type BandLoot = {
	band: number,
	lootTableId: LootTableId,
}

export type LocationRun = {
	recommendedGearScore: number, -- shown on the location panel (Domain/Matchmaking.gearScore)
	placeId: number, -- the location's place in the universe; 0 until it is published (Phase B)
	extraction: ExtractionDef,
	bandLoot: { BandLoot },
	travelBonusTableId: LootTableId, -- "found on the way" (Domain/TravelBonus)
	quests: { LocationQuest }, -- location quests, pinned in teal at the top of the tracker (LDOE_PARITY #45)
}

export type MeterBand = {
	from: number, -- meter value (0..1) where the band starts; the first band starts at 0
	name: string,
	lootMultiplier: number, -- base container rolls are multiplied by this (Domain/Containers)
	hollowStrength: number, -- Hollow HP and damage multiplier
}

-- What a death drops and who may open it, by fog tier (Domain/Lobby).
export type DropRule = {
	access: "party" | "anyone",
	equipment: boolean, -- equipped gear drops too (everything but the secure pouch)
}

export type LobbyTuning = {
	capacity: number,
	openTimeoutSeconds: number, -- a reserved lobby nobody reaches is closed
	reservationSeconds: number, -- a matched seat is held this long for the teleport
	joinWindowSeconds: number,
	durationSeconds: number, -- the Fog meter's run from 0 to full
	warningSeconds: number,
	meterExponent: number, -- 1 = linear; above 1 rises slowly, then fast
	reentryCutoffSeconds: number, -- re-entry closes this long before the Fog closes in
	bandTolerance: number, -- power bands a joiner may sit from the lobby's
	bands: { MeterBand },
	drops: { DropRule }, -- index = fog tier
	ticketMaxAgeSeconds: number, -- a run ticket older than this is refused on arrival (Domain/RunTicket)
}

export type ExtractionTuning = {
	edgeSeconds: number, -- Light: the fog-out at any edge
	pointSeconds: number, -- Dense and Black: the channel, interrupted by damage
	flareSeconds: number, -- Black: survive this long after firing the flare
	radiusStuds: number, -- leaving it cancels a channel
	xpByTier: { number }, -- XP for getting out alive, index = fog tier
}

export type MatchmakingTuning = {
	levelWeight: number, -- power = level * levelWeight + gear score
	bandWidth: number, -- power per band
	widenEverySeconds: number, -- waiting this long widens the band tolerance by one
	maxTolerance: number,
	newLobbyAfterSeconds: number, -- no lobby fits after this long: open a fresh one
	weights: { weapon: number, armor: number, bag: number, companion: number },
	aiBackfillTarget: number, -- M2 (features.aiRaiders): fill short lobbies to this many
	maxPartySize: number,
}

export type ContainersTuning = {
	searchSeconds: number,
	reachStuds: number,
	lootModeByTier: { "personal" | "shared" }, -- index = fog tier
}

export type TravelBonusTuning = {
	runChance: number,
	walkChance: number,
	walkRolls: number,
	-- LDOE_PARITY #40: TAKE costs one rewarded ad per item; TAKE ALL costs Rations (or premium, S3).
	takeAllRations: number,
	hurryEnergyPerMinute: number, -- #43: Energy to cut a minute off a Walk
}

export type NoiseTuning = {
	decaySeconds: number, -- a noise is heard, shrinking, for this long
	melee: number, -- radii in studs; guns carry their own (FirearmStats.noiseRadius)
	bow: number,
	sprint: number,
	search: number,
	bloaterBurst: number,
	flare: number,
}

export type StaminaTuning = {
	max: number,
	regenPerSecond: number,
	regenDelaySeconds: number, -- after spending, regen waits this long
	sprintPerSecond: number,
}

export type DodgeTuning = {
	staminaCost: number,
	iframeSeconds: number,
	cooldownSeconds: number,
	distanceStuds: number,
	durationSeconds: number,
}

export type MeleeTuning = {
	arcDegrees: number,
	heavyMultiplier: number,
	heavyWindupSeconds: number,
	staminaLight: number,
	staminaHeavy: number,
	hitStopSeconds: number,
	heavyHitStopSeconds: number,
	knockbackStuds: number,
	heavyKnockbackStuds: number,
	-- LDOE_PARITY #34: a tool in a weapon slot swings as weak melee.
	toolDamage: number,
	toolAttacksPerSecond: number,
	toolRange: number,
}

-- The two weapon slots, LDoE-style (GAME_DESIGN PC controls; checklist 4.9; Domain/Hands).
export type HandsTuning = {
	slots: number, -- 2: primary and secondary from the equipment paper-doll
	swapSeconds: number, -- default time to raise the other weapon; no attacking meanwhile
}

export type HollowTuning = {
	tickSeconds: number, -- server AI step
	syncSeconds: number, -- snapshot rate to clients (they interpolate)
	alertSeconds: number, -- investigating a noise before giving up
	loseTargetSeconds: number, -- chasing on memory after line of sight breaks
	idleSeconds: Range,
	wanderRadius: number,
	fleeSeconds: number,
	maxActive: number, -- per lobby
	spawnSpreadStuds: number, -- spawns at least this far from players
	hitRadiusStuds: number, -- a Hollow's body for hit tests (Domain/Plane)
}

-- LDoE parity rulings for slice 2 (docs/LDOE_PARITY.md) ------------------------------------

-- #35: animals share the enemy brain with different instincts.
export type WildlifeDef = {
	temperament: "skittish" | "predator", -- deer bolt from players; wolves hunt them
	spookRadius: number, -- skittish: a player this close sends it running
}

-- #45: a quest tied to one location, shown at the top of the tracker while there.
export type LocationQuest = {
	id: QuestId,
	name: string,
	description: string,
	objectives: { QuestObjective },
	rewards: QuestRewards,
}

-- #44: Ctrl sneaks: slower, quieter, harder to spot, and a backstab on the unaware.
export type SneakTuning = {
	speedMultiplier: number,
	noiseMultiplier: number, -- on footsteps and melee noise while sneaking
	detectionMultiplier: number, -- on a Hollow's sight radius against a sneaking player
	backstabMultiplier: number, -- melee on a Hollow that hasn't noticed you
}

-- #31: in-world AUTO (Q) is free everywhere and attacks the nearest Hollow.
export type AutoAttackTuning = {
	radiusStuds: number, -- how far AUTO looks for a target
	tickSeconds: number,
}

-- #31: the location panel's paid AUTO clears a location into the inbox, unentered.
export type AutoClearTuning = {
	adPerDay: number, -- rewarded-ad clears a day (the ad itself is S3)
	adMinLevel: number,
	rationsByTier: { number }, -- Rations per clear, index = fog tier
	nodeShare: number, -- share of the location's resource nodes gathered for you
	killShare: number, -- share of its Hollow cleared (their loot drops too)
}

-- #43: airdrops land as Energy falls past each threshold, once per UTC day.
export type AirdropTuning = {
	thresholds: { number }, -- Energy values, highest first
	locationId: LocationId, -- the guarded crate's location (availability "airdrop")
	pinSeconds: number, -- how long the pin stays on the map
}

-- #43: repair the tower (a parts checklist) before Dense and Black fog open.
export type RegionGate = {
	id: string, -- "tower_dense"
	name: string,
	fogTier: number, -- locations of this tier need it repaired
	parts: { ItemStack },
}

-- #37: Dense and Black fog seep in over a run; armor's fogResist slows it.
export type FogExposureTuning = {
	max: number,
	ratePerTier: { number }, -- per second, index = fog tier (Light is 0)
	maxResist: number, -- the most gear can block (0..1)
	damagePerSecond: number, -- while the meter is full
}

-- #46: getting your things back after a death.
export type DeathRecoveryTuning = {
	recoverAllAdsPerDay: number, -- "Recover all" by rewarded ad (S3 wires the ad)
	reanimatorHealth: number, -- health a Reanimator revives you at
	milestones: { { deaths: number, items: { ItemStack } } }, -- death-milestone gifts to the inbox
}

-- Everything in Data/, as one bundle (what the validator checks).
-- Haven Square (Data/Haven) -----------------------------------------------------------------

export type HavenNpc = {
	id: string,
	name: string,
	title: string, -- shown on the talk panel under the name
	role: "trader" | "quests" | "vip",
	greeting: string, -- floats over the head when you are near (LDoE rec4_01)
	lines: { string }, -- the talk panel picks one
	jacket: string, -- hex tint on the survivor rig's torso and arms (Lune has no Color3)
	pants: string, -- hex tint on the legs
	keepsPack: boolean, -- whether the backpack accessory stays on
}

export type HavenPrice = { itemId: ItemId, coins: number }
export type HavenContract = { id: string, itemId: ItemId, count: number, coins: number, xp: number }

export type HavenDef = {
	npcs: { [string]: HavenNpc },
	trader: { buy: { HavenPrice }, sell: { HavenPrice }, reachStuds: number },
	contracts: { perDay: number, pool: { HavenContract }, reachStuds: number },
	chapterRewards: { [string]: { coins: number, items: { ItemStack } } },
	vip: {
		passId: number,
		priceRobux: number,
		icon: string,
		energyCapBonus: number, -- added to the Energy cap
		dailyCrate: { ItemStack },
		streakDays: number, -- every this-many consecutive crates adds streakBonus
		streakBonus: { ItemStack },
	},
}

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
	Haven: HavenDef,
	Projects: { [string]: ProjectDef },
	StarterShelter: { StarterPiece },
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

-- One row of the item inbox (checklist 4.15): rewards, purchases and overflow wait
-- here with no capacity limit until the player takes or uses them. Saved in the
-- profile, so it is raid-proof; nothing in it expires.
export type InboxEntry = {
	id: string, -- "i<seq>", unique per profile
	itemId: ItemId,
	count: number,
	durability: number?,
	source: string, -- "LevelUp", "Quest", "Purchase", "Event", "Overflow", ...
	at: number, -- os.time() it arrived (or was last added to)
}

export type Inventory = {
	pockets: Container,
	backpack: Container,
}

return {}
