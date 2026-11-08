--!strict
--[[
	PlayerData: loads and saves each player's profile with ProfileStore
	(ARCHITECTURE.md §6).

	On join: start a session-locked profile, run schema migrations, then Reconcile
	(fill keys added to the template), then fire `loaded`. A profile that cannot be
	loaded or migrated kicks the player without saving anything.

	Other services read and change data only through PlayerData.get(player) after
	`loaded` fires, and only from the server. Purchases (Shop, M1) must record the
	receipt ID in `purchases.receiptIds` in the same change that grants the goods,
	and confirm the receipt only once that profile version has saved.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Migrations = require(ReplicatedStorage.Shared.Domain.Migrations)
local PlayerSchema = require(ReplicatedStorage.Shared.Domain.PlayerSchema)

-- The DataStore name. The schema version lives inside each profile, not here.
local STORE_NAME = "PlayerData"

type PlayerData = PlayerSchema.PlayerData

-- The parts of a ProfileStore profile this service uses.
type Profile = {
	Data: PlayerData,
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	AddUserId: (self: Profile, userId: number) -> (),
	OnSessionEnd: { Connect: (self: any, callback: () -> ()) -> any },
}

local PlayerData = {}

-- Fires (player, data) once a player's profile is loaded and migrated.
PlayerData.loaded = Signal.new()

local store: any
local profiles: { [Player]: Profile } = {}

local function loadProfile(player: Player)
	local profile: Profile? = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
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

function PlayerData.init()
	-- Cast: the solver cannot prove a typed record matches ProfileStore's JSON template type.
	store = ProfileStore.New(STORE_NAME, PlayerSchema.template() :: any)
	if RunService:IsStudio() then
		-- Studio play sessions use an in-memory store so tests never touch live saves.
		store = store.Mock
	end
end

function PlayerData.start()
	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
end

return PlayerData
