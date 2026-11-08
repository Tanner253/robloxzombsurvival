--!strict
--[[
	Remotes: the one list of every remote in the game (ARCHITECTURE.md §8).

	Each entry declares:
	- kind: "event" (RemoteEvent) or "function" (RemoteFunction, client to server only)
	- clientCanSend: false for server-to-client events; any client send is a violation
	- rateLimit: token bucket applied per player before anything else
	- validate: argument shape and range check, run on the server for every client send

	The server half of Net (server/Net.luau) creates the instances from this list
	and guards them; the client half (client/Net.luau) refuses undeclared names.
	Adding a remote means adding an entry here; nothing else creates remotes.

	Container refs name one of the player's slot containers: "pockets",
	"backpack", "equipment" (slots in Slots.EQUIP_ORDER), "storage" (the crate
	the player has open). The item inbox has its own remotes (InboxTake...).
]]

local Check = require("./Check")
local RateLimiter = require("./RateLimiter")
local FogRunRemotes = require("./FogRunRemotes")
local Features = require("../Features")
local Tuning = require("../Data/Tuning")

export type RemoteKind = "event" | "function"

export type RemoteDecl = {
	kind: RemoteKind,
	clientCanSend: boolean,
	rateLimit: RateLimiter.Limit,
	validate: Check.Validator,
	description: string,
}

local Remotes = {}

-- Name of the Folder in ReplicatedStorage that holds the remote instances.
Remotes.FOLDER_NAME = "Remotes"

Remotes.CONTAINER_REFS = { "pockets", "backpack", "equipment", "storage" }

-- Largest slot index any container can have (storage crates top out at 28).
Remotes.MAX_SLOT = 64
-- Most runs one craft request may queue (station queues are smaller anyway).
Remotes.MAX_BATCH = 10
-- Most items one request may move into a station slot (a level-3 slot holds 60).
Remotes.MAX_STACK = 60
-- Build targets: plots are at most this many cells across.
Remotes.MAX_CELL = 64

local ref = Check.oneOf(Remotes.CONTAINER_REFS)
local slot = Check.integer(1, Remotes.MAX_SLOT)
-- Placed piece UIDs come from Domain/Grid: decimal strings.
local uid = Check.pattern("^%d+$", 10)
-- World node keys from the Gathering service, e.g. "12345:node.pine_tree#3".
local nodeKey = Check.pattern("^%d+:node%.[%w_]+#%d+$", 64) -- "<ownerUserId>:<nodeId>#<n>" (Services/Gathering)
-- Ground drops from the Drops service, e.g. "d42".
local dropId = Check.pattern("^d%d+$", 12)
-- Item inbox rows from Domain/Inbox, e.g. "i17".
local inboxId = Check.pattern("^i%d+$", 12)

local SERVER_ONLY = { count = 1, perSeconds = 60 }
local MOVES = { count = 24, perSeconds = 4 }
local ACTIONS = { count = 10, perSeconds = 2 }
local BUILD = { count = 12, perSeconds = 3 }

Remotes.list = {
	-- Example remote. The client sends a nonce; the server replies with the same
	-- nonce and its clock so the client can measure round-trip time.
	Ping = {
		kind = "function",
		clientCanSend = true,
		rateLimit = { count = 3, perSeconds = 10 },
		validate = Check.args(Check.integer(0, 2 ^ 31 - 1)),
		description = "Round-trip check: (nonce: integer) -> (nonce, serverTime)",
	},

	-- State replication -------------------------------------------------------------
	Sync = {
		kind = "event",
		clientCanSend = false,
		rateLimit = SERVER_ONLY,
		validate = Check.never(),
		description = "Server to client: (section, value) replaces one section of the player's state",
	},
	SyncRequest = {
		kind = "function",
		clientCanSend = true,
		rateLimit = { count = 6, perSeconds = 30 },
		validate = Check.args(),
		description = "() -> { [section]: value }: the full state, once the client is listening",
	},
	Fx = {
		kind = "event",
		clientCanSend = false,
		rateLimit = SERVER_ONLY,
		validate = Check.never(),
		description = "Server to client: (kind, payload) for rewards, hits, level-ups and notices",
	},

	-- Inventory -------------------------------------------------------------------------
	InventoryMove = {
		kind = "event",
		clientCanSend = true,
		rateLimit = MOVES,
		validate = Check.args(ref, slot, ref, slot, Check.optional(Check.integer(1, 9999))),
		description = "(fromRef, fromIndex, toRef, toIndex, count?) moves, merges or swaps a slot",
	},
	InventorySplit = {
		kind = "event",
		clientCanSend = true,
		rateLimit = MOVES,
		validate = Check.args(ref, slot),
		description = "(ref, index) splits half a stack into the first empty slot of the same container",
	},
	InventoryTransfer = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.oneOf({ "takeAll", "putAll" })),
		description = "(mode) Take all from the open crate, or Put all materials into it",
	},
	StorageLabel = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.optional(Check.contentId("item"))),
		description = "(itemId?) pins that item's icon on the open crate's lid, or clears it with nil",
	},
	StorageOpen = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.optional(uid)),
		description = "(uid?) opens the player's crate with that UID, or closes it with nil",
	},
	UseItem = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(ref, slot),
		description = "(ref, index) eats, drinks or reads the item in that slot",
	},

	-- Shop (MVP_LAUNCH v0.1) -------------------------------------------------------------
	ShopBuy = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.contentId("product")),
		description = "(productId) asks the server to prompt that developer product, if it is on offer",
	},
	-- Haven Square (Services/Haven) -----------------------------------------------------------
	HavenBuy = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.contentId("item"), Check.integer(1, 99)),
		description = "(itemId, count) buys from the Trader's stock for coins, standing by her",
	},
	HavenSell = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.contentId("item"), Check.integer(1, 99)),
		description = "(itemId, count) sells items from the bag to the Trader for coins",
	},
	ContractDeliver = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.contentId("contract")),
		description = "(contractId) delivers one of today's contracts at the Trail Keeper's board",
	},
	ChapterClaim = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.string(64)),
		description = "(chapter) hands a finished Ember Trail chapter in to the Trail Keeper",
	},
	VipBuy = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(),
		description = "() prompts the VIP Lounge game pass",
	},
	WeaponSelect = {
		kind = "event",
		clientCanSend = true,
		rateLimit = MOVES,
		validate = Check.args(Check.integer(1, 2)),
		description = "(n) makes weapon slot n (1 primary, 2 secondary) active and holds it (4.9)",
	},
	WeaponSwap = {
		kind = "event",
		clientCanSend = true,
		rateLimit = MOVES,
		validate = Check.args(),
		description = "() swaps to the other weapon slot (4.9)",
	},
	UseMeds = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(),
		description = "() uses the carried consumable that heals the most (the meds button, 4.9)",
	},

	-- Gathering ---------------------------------------------------------------------------
	SaveSettings = {
		kind = "event",
		clientCanSend = true,
		rateLimit = { count = 4, perSeconds = 2 },
		validate = Check.args(
			Check.number(0, 1),
			Check.number(0, 1),
			Check.number(0, 1),
			Check.number(0, 1),
			Check.number(0, 1),
			Check.boolean(),
			Check.number(0.8, 1.25)
		),
		description = "(master, music, ambience, sfx, ui, shake, uiScale) saves the player's settings",
	},
	InventorySort = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.oneOf({ "pockets", "backpack", "storage" })),
		description = "(ref) merges and sorts one container (the Sort button)",
	},
	InventoryDrop = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(ref, slot),
		description = "(ref, index) drops a whole slot on the ground at the player's feet",
	},
	InventoryDestroy = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(ref, slot),
		description = "(ref, index) destroys a whole slot for good (the trash button, after a confirm)",
	},
	RecipeFavourite = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.contentId("recipe"), Check.boolean()),
		description = "(recipeId, on) stars or unstars a recipe in the crafting catalogue",
	},
	RecipesSeen = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(),
		description = "() marks every unlocked recipe as seen (clears NEW badges)",
	},
	InboxTake = {
		kind = "event",
		clientCanSend = true,
		rateLimit = MOVES,
		validate = Check.args(inboxId),
		description = "(id) moves one inbox row into the bag as far as it fits",
	},
	InboxTakeAll = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.optional(Check.string(16))),
		description = "(category?) moves every inbox row (or one category's) into the bag",
	},
	InboxUse = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(inboxId),
		description = "(id) eats or drinks one unit straight from the inbox",
	},
	PickupDrop = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(dropId),
		description = "(dropId) picks up a bag on the ground the player owns and is next to",
	},
	Gather = {
		kind = "event",
		clientCanSend = true,
		rateLimit = { count = 6, perSeconds = 3 },
		validate = Check.args(nodeKey),
		description = "(nodeKey) one swing at a resource node; the server checks reach, tool and cooldown",
	},

	-- Crafting and stations -------------------------------------------------------------------
	HandCraft = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.contentId("recipe"), Check.integer(1, Remotes.MAX_BATCH)),
		description = "(recipeId, count) crafts a hand recipe from the inventory",
	},
	StationPutInput = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(uid, ref, slot, Check.optional(Check.integer(1, Remotes.MAX_STACK))),
		description = "(stationUid, ref, index, count?) drags a carried stack into a station's input",
	},
	StationPutFuel = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(uid, ref, slot, Check.optional(Check.integer(1, Remotes.MAX_STACK))),
		description = "(stationUid, ref, index, count?) drags a carried stack into a station's fuel slot",
	},
	StationTakeInput = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(uid),
		description = "(stationUid) takes a station's input back into the bag",
	},
	StationTakeFuel = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(uid),
		description = "(stationUid) takes a station's unlit fuel back into the bag",
	},
	StationTakeOutput = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(uid, Check.integer(0, Remotes.MAX_SLOT)),
		description = "(stationUid, index) takes an output slot (0: all of them) into the bag",
	},
	StationUpgrade = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(uid),
		description = "(stationUid) upgrades an idle station one level",
	},

	-- Projects (the wrecked hauler's parts checklist, LDOE_PARITY #56) ------------------------
	ProjectDeliver = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.pattern("^project%.[%w_]+$", 48), Check.contentId("item")),
		description = "(projectId, itemId) FILL UP: hands in as much of a part as the home pool holds",
	},
	ProjectFinalize = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.pattern("^project%.[%w_]+$", 48)),
		description = "(projectId) FINALIZE once every part is in",
	},

	-- Building ---------------------------------------------------------------------------------
	BuildPlace = {
		kind = "event",
		clientCanSend = true,
		rateLimit = BUILD,
		validate = Check.args(
			Check.contentId("build"),
			Check.integer(0, Remotes.MAX_CELL),
			Check.integer(0, Remotes.MAX_CELL),
			Check.optional(Check.oneOf({ "h", "v" })),
			Check.optional(Check.integer(0, 3))
		),
		description = "(pieceId, x, z, axis?, rot?) places a piece on the player's plot",
	},
	BuildUpgrade = {
		kind = "event",
		clientCanSend = true,
		rateLimit = BUILD,
		validate = Check.args(uid),
		description = "(uid) upgrades a placed piece one tier",
	},
	BuildMove = {
		kind = "event",
		clientCanSend = true,
		rateLimit = BUILD,
		validate = Check.args(
			uid,
			Check.integer(0, Remotes.MAX_CELL * 4),
			Check.integer(0, Remotes.MAX_CELL * 4),
			Check.integer(0, 3)
		),
		description = "(uid, x, z, rot) moves or turns a placed object (quarter cells), keeping what it holds",
	},
	BuildDemolish = {
		kind = "event",
		clientCanSend = true,
		rateLimit = BUILD,
		validate = Check.args(uid),
		description = "(uid) demolishes a piece and what it holds up, with a refund",
	},
} :: { [string]: RemoteDecl }

-- Fog Runs (slice 2) declare theirs in Net/FogRunRemotes; they join the list only
-- while Tuning.features.fogRuns is on, so nothing of the feature exists until then.
Remotes.fogRuns = FogRunRemotes :: { [string]: RemoteDecl }
if Features.on(Tuning, "fogRuns") then
	for name, decl in Remotes.fogRuns do
		assert(Remotes.list[name] == nil, `Remote '{name}' is declared twice`)
		Remotes.list[name] = decl
	end
end

-- Returns a declaration, or errors for an undeclared name (catches typos early).
function Remotes.get(name: string): RemoteDecl
	local decl = Remotes.list[name]
	if decl == nil then
		error(`Remote '{name}' is not declared in Net/Remotes`, 2)
	end
	return decl
end

return Remotes
