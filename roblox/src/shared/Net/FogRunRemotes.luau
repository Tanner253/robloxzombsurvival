--!strict
--[[
	FogRunRemotes: every remote of the Fog Runs feature (M1 slice 2), declared the
	same way as Net/Remotes. Remotes merges them into its one list only while
	Tuning.features.fogRuns is on, so with the flag off no instance exists and no
	client can send them.

	IDs on the wire: lobby drops "b<n>" (Domain/Lobby), containers "c<n>" and the
	Hollow "h<n>" (the Containers and Hollow services). Aim and dodge headings are
	yaw radians on the ground plane (Domain/Plane).
]]

local Check = require("./Check")
local RateLimiter = require("./RateLimiter")

type Decl = {
	kind: "event" | "function",
	clientCanSend: boolean,
	rateLimit: RateLimiter.Limit,
	validate: Check.Validator,
	description: string,
}

local SERVER_ONLY = { count = 1, perSeconds = 60 }
local ACTIONS = { count = 10, perSeconds = 2 }
local TAKES = { count = 24, perSeconds = 4 }
local SHOTS = { count = 8, perSeconds = 2 } -- above the fastest weapon's cadence, below a macro
local MAX_SLOT = 64

local locationId = Check.contentId("loc")
local mode = Check.oneOf({ "run", "walk" })
local index = Check.integer(1, MAX_SLOT)
local yaw = Check.number(-7, 7) -- radians, with room for an unwrapped angle
local userId = Check.integer(1, 2 ^ 53)
local bagId = Check.pattern("^b%d+$", 12)
local containerId = Check.pattern("^c%d+$", 12)
local hollowId = Check.pattern("^h%d+$", 12)
local pointId = Check.pattern("^[%l%d_]+$", 32)

local FogRunRemotes: { [string]: Decl } = {
	-- Travel ---------------------------------------------------------------------------
	TravelStart = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(locationId, mode),
		description = "(locationId, mode) Run or Walk to a location from the fog edge or the Trailhead",
	},
	TravelCancel = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(),
		description = "() turns back; a Run still loading refunds its Energy",
	},
	TravelBonusTake = {
		kind = "event",
		clientCanSend = true,
		rateLimit = TAKES,
		validate = Check.args(Check.integer(1, 16)),
		description = "(index) TAKE one 'found on the way' row",
	},
	TravelBonusTakeAll = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(),
		description = "() Take all from the 'found on the way' panel",
	},

	-- Lobbies and parties ------------------------------------------------------------------
	LobbyReenter = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(locationId),
		description = "(locationId) goes back into the open lobby you died in, for Energy",
	},
	PartyInvite = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(userId),
		description = "(userId) invites a player in this server to your party",
	},
	PartyRespond = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(userId, Check.boolean()),
		description = "(inviterUserId, accept) answers a party invite",
	},
	PartyLeave = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(),
		description = "() leaves your party",
	},
	BagTake = {
		kind = "event",
		clientCanSend = true,
		rateLimit = TAKES,
		validate = Check.args(bagId, Check.oneOf({ "backpack", "equipment" }), index),
		description = "(bagId, section, index) takes one slot from a death drop you may open",
	},
	BagTakeAll = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(bagId),
		description = "(bagId) takes everything that fits from a death drop",
	},

	-- Containers and extraction ---------------------------------------------------------------
	ContainerSearch = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(containerId),
		description = "(containerId) starts searching a container in reach, or opens one already searched",
	},
	ContainerCancel = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(),
		description = "() stops the current search",
	},
	ContainerTake = {
		kind = "event",
		clientCanSend = true,
		rateLimit = TAKES,
		validate = Check.args(containerId, index),
		description = "(containerId, index) TAKE one stack from a searched container",
	},
	ContainerTakeAll = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(containerId),
		description = "(containerId) Take all from a searched container",
	},
	ExtractStart = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(pointId),
		description = "(pointId) starts extracting: 'edge' in Light fog, a point ID, or 'flare' in Black fog",
	},
	ExtractCancel = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(),
		description = "() stops extracting",
	},

	-- Combat and hands -------------------------------------------------------------------------
	CombatMelee = {
		kind = "event",
		clientCanSend = true,
		rateLimit = SHOTS,
		validate = Check.args(Check.boolean(), yaw, Check.optional(hollowId)),
		description = "(heavy, aimYaw, lockedTargetId?) one melee swing; the server finds what it hits",
	},
	CombatFire = {
		kind = "event",
		clientCanSend = true,
		rateLimit = SHOTS,
		validate = Check.args(yaw, Check.optional(hollowId)),
		description = "(aimYaw, lockedTargetId?) fires the active gun, or releases a drawn bow",
	},
	CombatDraw = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(),
		description = "() starts drawing the active bow",
	},
	CombatReload = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(),
		description = "() reloads the active gun from the bag",
	},
	CombatDodge = {
		kind = "event",
		clientCanSend = true,
		rateLimit = { count = 3, perSeconds = 2 },
		validate = Check.args(yaw),
		description = "(dirYaw) a dodge roll: stamina, cooldown and an i-frame window",
	},
	WeaponSelect = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(Check.integer(1, 2)),
		description = "(slot) the 1 and 2 keys: raises that weapon slot",
	},
	WeaponSwap = {
		kind = "event",
		clientCanSend = true,
		rateLimit = ACTIONS,
		validate = Check.args(),
		description = "() F or the swap button: raises the other weapon slot",
	},
	UseMeds = {
		kind = "event",
		clientCanSend = true,
		rateLimit = { count = 4, perSeconds = 2 },
		validate = Check.args(),
		description = "() H or the meds button: uses the best healing item carried",
	},

	-- Server to client ---------------------------------------------------------------------------
	RunState = {
		kind = "event",
		clientCanSend = false,
		rateLimit = SERVER_ONLY,
		validate = Check.never(),
		description = "Server to client: (state) the lobby phase, Fog meter, band, exits, drops and your run",
	},
	HollowSync = {
		kind = "event",
		clientCanSend = false,
		rateLimit = SERVER_ONLY,
		validate = Check.never(),
		description = "Server to client: (snapshot) compact Hollow positions and states; clients interpolate",
	},
}

return FogRunRemotes
