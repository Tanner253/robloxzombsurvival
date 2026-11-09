--!strict
--[[
	PlayerData: loads and saves each player's profile with ProfileStore
	(ARCHITECTURE.md §6).

	On join: start a session-locked profile, run schema migrations, then Reconcile
	(fill keys added to the template), then fire `loaded`. A profile that cannot be
	loaded or migrated kicks the player without saving anything.

	Other services read and change data only through PlayerData.get(player) after
	`loaded` fires, and only from the server. Purchases (Services/Shop) record the
	receipt ID in `purchases.receiptIds` in the same change that grants the goods,
	and confirm the receipt only once that profile version has saved
	(PlayerData.saveConfirmed).

	Data safety (Domain/DataSafety): a session that can't start is retried with a
	growing delay before the player is asked to rejoin; on server shutdown every
	profile still open gets `releasing` (so services write their runtime state) and is
	ended, which ProfileStore saves before the server closes; and the setup is audited
	at start (store names for the environment, session locks, the shutdown save).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stores = require("../Stores")
local Signal = require(ReplicatedStorage.Packages.Signal)
local DataSafety = require(ReplicatedStorage.Shared.Domain.DataSafety)
local Migrations = require(ReplicatedStorage.Shared.Domain.Migrations)
local PlayerSchema = require(ReplicatedStorage.Shared.Domain.PlayerSchema)

-- The DataStore name. The schema version lives inside each profile, not here.
local STORE_NAME = "PlayerData"

type PlayerData = PlayerSchema.PlayerData

-- The parts of a ProfileStore profile this service uses.
type Profile = {
	Data: PlayerData,
	LastSavedData: any,
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	Save: (self: Profile) -> (),
	IsActive: (self: Profile) -> boolean,
	AddUserId: (self: Profile, userId: number) -> (),
	OnSessionEnd: { Connect: (self: any, callback: () -> ()) -> any },
	OnAfterSave: { Connect: (self: any, callback: (saved: any) -> ()) -> any },
}

local PlayerData = {}

-- Fires (player, data) once a player's profile is loaded and migrated.
PlayerData.loaded = Signal.new()
-- Fires (player, data) as the player leaves, just before the profile is saved and
-- released. Handlers write their last runtime state (meters, health) into `data`
-- and must not yield.
PlayerData.releasing = Signal.new()

local store: any
local profiles: { [Player]: Profile } = {}
local released: { [Player]: boolean } = {}
local shutdownBound = false

-- Starts the player's session-locked profile, retrying with a growing delay when it
-- can't start (the lock is still held by a server that is closing, DataStore errors).
local function startSession(player: Player): Profile?
	for attempt = 1, DataSafety.MAX_LOAD_ATTEMPTS do
		if attempt > 1 then
			task.wait(DataSafety.retryDelay(attempt))
		end
		if player.Parent ~= Players then
			return nil
		end
		local profile: Profile? = store:StartSessionAsync(`Player_{player.UserId}`, {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})
		if profile then
			return profile
		end
		warn(`PlayerData: session for {player.UserId} didn't start (attempt {attempt})`)
	end
	return nil
end

local function loadProfile(player: Player)
	local profile = startSession(player)
	if profile == nil then
		if player.Parent == Players then
			player:Kick("Your save could not be loaded. Please rejoin.")
		end
		return
	end

	local ok, reason = Migrations.run(profile.Data :: any, PlayerSchema.migrations, PlayerSchema.VERSION)
	if not ok then
		warn(`PlayerData: migration failed for {player.UserId}: {reason}`)
		-- The profile was never reconciled or changed by gameplay; end without further edits.
		profile:EndSession()
		player:Kick("Your save needs a newer server. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR erasure support
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your save was opened on another server. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	local data = profile.Data
	local now = os.time()
	if data.meta.createdAt == 0 then
		data.meta.createdAt = now
		data.energy.updatedAt = now
	end
	data.meta.lastLoginAt = now
	data.meta.loginCount += 1

	profiles[player] = profile
	PlayerData.loaded:Fire(player, data)
end

-- The player's live data, or nil if it is not loaded (yet, or any more).
function PlayerData.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

--[[
	Saves the player's profile now and waits (up to `timeout` seconds) until a saved
	version passes `check`, e.g. holds a receipt ID. True once it has; false if the
	profile ended or the time ran out (the caller tries again later).
]]
function PlayerData.saveConfirmed(player: Player, check: (saved: any) -> boolean, timeout: number): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	if profile.LastSavedData ~= nil and check(profile.LastSavedData) then
		return true
	end
	local confirmed = false
	local connection = profile.OnAfterSave:Connect(function(saved: any)
		if check(saved) then
			confirmed = true
		end
	end)
	profile:Save()
	local started = os.clock()
	while not confirmed and os.clock() - started < timeout and profile:IsActive() do
		task.wait(0.1)
	end
	connection:Disconnect()
	return confirmed
end

-- Lets services write their runtime state, then ends the session (ProfileStore saves it).
local function release(player: Player)
	local profile = profiles[player]
	if profile == nil or released[player] then
		return
	end
	released[player] = true
	PlayerData.releasing:Fire(player, profile.Data)
	profile:EndSession()
end

function PlayerData.init()
	-- Studio uses "<name>_Studio" (Stores, Domain/DataSafety).
	store = Stores.open(STORE_NAME, PlayerSchema.template())
end

function PlayerData.start()
	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		release(player)
		released[player] = nil
	end)
	-- Shutdown: release every profile still open (players may not be removed first);
	-- ProfileStore's own BindToClose then waits for those saves.
	game:BindToClose(function()
		for player in profiles do
			release(player)
		end
	end)
	shutdownBound = true
	-- The startup audit (after every service's init has opened its stores).
	task.defer(function()
		local problems = DataSafety.audit({
			isStudio = game:GetService("RunService"):IsStudio(),
			stores = Stores.opened,
			sessionLocked = true, -- loadProfile only uses StartSessionAsync
			shutdownBound = shutdownBound,
		})
		for _, problem in problems do
			warn(`PlayerData: data safety: {problem}`)
		end
	end)
end

return PlayerData
