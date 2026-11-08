--!strict
--[[
	Lobby (LobbyService): Fog Run lobbies on the server (M1 slice 2; checklist 12.1,
	12.3, 12.6). Off until Tuning.features.fogRuns: init and start do nothing then.

	Two halves, both over the pure Domain modules:
	- World side (the Neighbourhood): Trailhead parties, a matchmaking queue
	  (Domain/Matchmaking) that joins open lobbies or opens fresh ones, and the trip
	  in through the teleport adapter (FogRuns/Teleport). Travel calls `enqueue`
	  when a trip arrives, and `reenter` for a player going back for their bag.
	- Host side (a reserved run server, or the same server in the Studio
	  simulation): one Domain/Lobby state per lobby. It seats arrivals from their
	  run ticket, applies death drops by fog tier, re-entry, the Fog meter's bands
	  and the 60 s warning, and closes the lobby, losing whoever is still inside.

	Other Fog Run services build on the signals (`opened`, `closed`, `entered`,
	`exited`, `bandChanged`, `hurt`) and on `hurtPlayer`, the one way anything
	damages a player on a run (armor, dodge i-frames and the interrupt signal).
	They add their part of the client's RunState with `addRunState`.

	Written and type-checked in Phase A; playtested in Phase B.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Features = require(ReplicatedStorage.Shared.Features)
local Types = require(ReplicatedStorage.Shared.Types)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Domain = ReplicatedStorage.Shared.Domain
local CombatMath = require(Domain.Combat)
local DeathRecovery = require(Domain.DeathRecovery)
local FogExposure = require(Domain.FogExposure)
local ExtractionMath = require(Domain.Extraction)
local InventoryMath = require(Domain.Inventory)
local LobbyMath = require(Domain.Lobby)
local Matchmaking = require(Domain.Matchmaking)
local RunTicket = require(Domain.RunTicket)
local Net = require("../Net")
local Map = require("../FogRuns/Map")
local Payments = require("../FogRuns/Payments")
local Teleport = require("../FogRuns/Teleport")
local Analytics = require("./Analytics")
local Inbox = require("./Inbox")
local Inventory = require("./Inventory")
local PlayerData = require("./PlayerData")
local Plots = require("./Plots")
local Progression = require("./Progression")
local Sync = require("./Sync")

local Lobby = {}

local tuning = Content.Tuning
local lobbyConfig = tuning.lobby
local deathConfig: any = tuning.death -- Domain/Death.Config (keepPockets is optional there)
local Items: any = Content.Items
local ARMOR_KEYS = { "head", "body", "legs", "feet" }
local INVITE_SECONDS = 60
local TICK_SECONDS = 0.5
local MATCH_SECONDS = 1
local PUBLISH_SECONDS = 5
local STATE_SECONDS = 1

export type RunStats = {
	enteredAt: number,
	kills: number,
	containers: number,
	exposure: number, -- LDOE_PARITY #37: the fog-exposure meter, reset each run
}

export type Hosted = {
	id: string,
	location: Types.LocationDef,
	state: LobbyMath.State,
	band: number,
	warned: boolean,
	players: { [Player]: boolean },
	map: Instance?,
	lastPublish: number,
}

export type Run = {
	player: Player,
	hosted: Hosted,
	ticket: RunTicket.Ticket,
	stats: RunStats,
}

type Party = { id: string, leader: Player, members: { Player } }
type Queued = { entry: Matchmaking.Entry, players: { Player } }
type Reentry = { lobbyId: string, locationId: string, untilAt: number }

-- Signals for the other Fog Run services.
Lobby.opened = Signal.new() -- (hosted)
Lobby.closed = Signal.new() -- (hosted)
Lobby.entered = Signal.new() -- (player, run)
Lobby.exited = Signal.new() -- (player, run, outcome): fires before the player is sent home
Lobby.bandChanged = Signal.new() -- (hosted, band)
Lobby.hurt = Signal.new() -- (player, damage, cause)
Lobby.failed = Signal.new() -- (player, reason): a trip in that never happened (refund it)

-- Set by Combat: whether a player is inside a dodge roll's i-frames.
Lobby.invulnerable = function(_player: Player): boolean
	return false
end

local adapter: Teleport.Adapter? = nil
local role: Teleport.Role = "world"
local hostedLobbies: { [string]: Hosted } = {}
local runs: { [Player]: Run } = {}
local parties: { [Player]: Party } = {}
local invites: { [Player]: { [Player]: number } } = {}
local queue: { [string]: Queued } = {}
local reentries: { [Player]: Reentry } = {}
local lastCause: { [Player]: string } = {}
local providers: { [string]: (Player, Run) -> any } = {}
local seq = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function nextId(prefix: string): string
	seq += 1
	return `{prefix}{seq}`
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Queries ---------------------------------------------------------------------------------------

function Lobby.runOf(player: Player): Run?
	return runs[player]
end

function Lobby.hosted(lobbyId: string): Hosted?
	return hostedLobbies[lobbyId]
end

function Lobby.playersIn(hosted: Hosted): { Player }
	local list: { Player } = {}
	for player in hosted.players do
		table.insert(list, player)
	end
	return list
end

function Lobby.band(hosted: Hosted): (number, Types.MeterBand)
	return LobbyMath.band(hosted.state, now(), lobbyConfig)
end

function Lobby.isRunServer(): boolean
	return role == "run"
end

function Lobby.partyIdOf(player: Player): string?
	local party = parties[player]
	return if party then party.id else nil
end

function Lobby.partyOf(player: Player): { Player }
	local party = parties[player]
	return if party then table.clone(party.members) else { player }
end

function Lobby.isPartyLeader(player: Player): boolean
	local party = parties[player]
	return party == nil or party.leader == player
end

-- Where a player who died may go back in, while that is still possible.
function Lobby.reentryOf(player: Player): Reentry?
	local entry = reentries[player]
	if entry and now() < entry.untilAt then
		return entry
	end
	return nil
end

-- Adds a named part to every player's RunState (Extraction's exits, a search...).
function Lobby.addRunState(name: string, provider: (Player, Run) -> any)
	assert(providers[name] == nil, `RunState part '{name}' already provided`)
	providers[name] = provider
end

function Lobby.recordKill(player: Player)
	local run = runs[player]
	if run then
		run.stats.kills += 1
	end
end

function Lobby.recordSearch(player: Player)
	local run = runs[player]
	if run then
		run.stats.containers += 1
	end
end

-- Damage --------------------------------------------------------------------------------------

local function armorDefense(equipment: { [string]: Types.Slot }): number
	local defense = 0
	for _, key in ARMOR_KEYS do
		local slot = equipment[key]
		local item = slot and slot.count > 0 and Items[slot.itemId]
		if item and item.armor then
			defense += item.armor.defense
		end
	end
	return defense
end

local function wearArmor(player: Player, equipment: { [string]: Types.Slot })
	local broke = false
	for _, key in ARMOR_KEYS do
		local slot = equipment[key]
		if slot and slot.count > 0 and slot.durability then
			slot.durability -= tuning.combat.armorDurabilityPerHitTaken
			if slot.durability <= 0 then
				equipment[key] = InventoryMath.emptySlot()
				broke = true
			end
		end
	end
	Sync.mark(player, "inventory")
	if broke then
		Sync.notice(player, "Your armor broke")
	end
end

--[[
	Damages a player on a run: dodge i-frames first, then their armor (LDoE's
	reduction, Domain/Combat), which wears. Fires `hurt` (searches and extraction
	channels break on it) and the client's hit feedback. Returns the damage dealt.
]]
function Lobby.hurtPlayer(player: Player, amount: number, cause: string, from: Vector3?): number
	local run = runs[player]
	local humanoid = humanoidOf(player)
	local data = PlayerData.get(player)
	if run == nil or humanoid == nil or data == nil or humanoid.Health <= 0 or amount <= 0 then
		return 0
	end
	if Lobby.invulnerable(player) then
		Sync.fx(player, "dodged", { cause = cause })
		return 0
	end
	local equipment = data.inventory.equipment :: any
	local damage = amount
	if cause ~= "fog" then -- fog exposure goes through armor (#37 resists it instead)
		damage = CombatMath.damage({
			base = amount,
			critMultiplier = 1,
			defense = armorDefense(equipment),
			armorConstant = tuning.combat.armorConstant,
		})
		wearArmor(player, equipment)
	end
	lastCause[player] = cause
	if humanoid.Health - damage <= 0 then
		-- LDOE_PARITY #46: a carried Reanimator burns out instead of you.
		local view = Inventory.view(player)
		local revived = view and DeathRecovery.useReanimator(view, Items)
		if revived then
			Inventory.commit(player, revived)
			humanoid.Health = tuning.deathRecovery.reanimatorHealth
			Sync.fx(player, "reanimated", { cause = cause })
			Lobby.hurt:Fire(player, damage, cause)
			return damage
		end
	end
	humanoid.Health = math.max(0, humanoid.Health - damage)
	Sync.fx(player, "hurt", { amount = damage, cause = cause, from = if from then { from.X, from.Z } else nil })
	Lobby.hurt:Fire(player, damage, cause)
	return damage
end

-- Leaving a run ---------------------------------------------------------------------------------

local function carried(player: Player): { Types.ItemStack }
	local view = Inventory.view(player)
	local stacks: { Types.ItemStack } = {}
	if view == nil then
		return stacks
	end
	local index: { [string]: number } = {}
	for _, container in { view.pockets, view.backpack } do
		for _, slot in container do
			if slot.count > 0 then
				local at = index[slot.itemId]
				if at then
					stacks[at].count += slot.count
				else
					table.insert(stacks, { itemId = slot.itemId, count = slot.count })
					index[slot.itemId] = #stacks
				end
			end
		end
	end
	return stacks
end

local function sendHome(player: Player, run: Run, data: Teleport.HomeData)
	local transport = adapter
	if transport == nil then
		return
	end
	local ok, err = transport.sendHome(player, run.ticket.homePlaceId, data)
	if not ok then
		warn(`Lobby: could not send {player.Name} home: {err}`)
	end
end

-- Ends a player's run: results, XP, the exited signal, then home.
local function finish(player: Player, run: Run, outcome: ExtractionMath.Outcome)
	if runs[player] ~= run then
		return
	end
	local hosted = run.hosted
	local stamp = now()
	local result = ExtractionMath.summarize({
		outcome = outcome,
		fogTier = hosted.location.fogTier,
		enteredAt = run.stats.enteredAt,
		endedAt = stamp,
		kills = run.stats.kills,
		containersSearched = run.stats.containers,
		carriedOut = if outcome == "extracted" then carried(player) else {},
	}, tuning.extraction)
	-- Others (Combat unloading magazines, Extraction, Containers) tidy up first.
	Lobby.exited:Fire(player, run, outcome)
	runs[player] = nil
	hosted.players[player] = nil
	lastCause[player] = nil
	if result.xp > 0 then
		Progression.grantXp(player, result.xp, "Extraction")
	end
	Sync.fx(player, "runResult", result)
	Analytics.custom(player, "FogRunEnd", result.seconds, { hosted.location.id, outcome })
	local home: Teleport.HomeData = { v = 1 }
	if outcome == "died" then
		local closesAt = LobbyMath.closesAt(hosted.state, lobbyConfig) or stamp
		home.lobbyId = hosted.id
		home.locationId = hosted.location.id
		home.reentryUntil = closesAt - lobbyConfig.reentryCutoffSeconds
	end
	sendHome(player, run, home)
end

-- Death drops by fog tier (Domain/Lobby), written back to the profile.
local function applyDeath(player: Player, run: Run, lost: boolean): LobbyMath.DeathResult?
	local data = PlayerData.get(player)
	local view = Inventory.view(player)
	if data == nil or view == nil then
		return nil
	end
	local root = rootOf(player)
	local info: LobbyMath.DeathInfo = {
		inventory = view,
		equipment = data.inventory.equipment :: any,
		position = if root then Map.plane(root.Position) else nil,
		cause = if lost then "fog" else (lastCause[player] or "hollow"),
	}
	local stamp = now()
	local result = if lost
		then LobbyMath.loseToFog(run.hosted.state, player.UserId, stamp, lobbyConfig, deathConfig, info)
		else LobbyMath.die(run.hosted.state, player.UserId, stamp, lobbyConfig, deathConfig, info)
	Inventory.commit(player, result.inventory)
	data.inventory.equipment = result.equipment :: any
	Sync.mark(player, "inventory")
	return result
end

local function onDied(player: Player, run: Run)
	if runs[player] ~= run then
		return
	end
	local result = applyDeath(player, run, false)
	local drop = result and result.drop
	Sync.fx(player, "runDeath", {
		cause = lastCause[player] or "hollow",
		lost = if drop then { backpack = drop.backpack, equipment = drop.equipment } else nil,
		bagId = if drop then drop.id else nil,
	})
	finish(player, run, "died")
end

-- Extraction got the player out alive.
function Lobby.extract(player: Player)
	local run = runs[player]
	if run and LobbyMath.extract(run.hosted.state, player.UserId) then
		finish(player, run, "extracted")
	end
end

-- Hosting -------------------------------------------------------------------------------------

local function publish(hosted: Hosted, force: boolean?)
	local transport = adapter
	local stamp = now()
	if transport == nil or (not force and stamp - hosted.lastPublish < PUBLISH_SECONDS) then
		return
	end
	hosted.lastPublish = stamp
	local phase = LobbyMath.phase(hosted.state, stamp, lobbyConfig)
	transport.publish({
		id = hosted.id,
		locationId = hosted.location.id,
		powerBand = hosted.state.powerBand,
		freeSeats = LobbyMath.freeSeats(hosted.state, stamp, lobbyConfig),
		joinable = phase == "open" or phase == "joinable",
	}, lobbyConfig.durationSeconds + lobbyConfig.openTimeoutSeconds)
end

local function host(lobbyId: string, locationId: string, powerBand: number): Hosted?
	local location = Content.Locations[locationId]
	if location == nil then
		return nil
	end
	local existing = hostedLobbies[lobbyId]
	if existing then
		return existing
	end
	local hosted: Hosted = {
		id = lobbyId,
		location = location,
		state = LobbyMath.new({
			id = lobbyId,
			locationId = locationId,
			fogTier = location.fogTier,
			seed = Random.new():NextInteger(1, 2 ^ 31 - 2),
			powerBand = powerBand,
			now = now(),
		}),
		band = 1,
		warned = false,
		players = {},
		map = Map.of(locationId, role == "run"),
		lastPublish = 0,
	}
	hostedLobbies[lobbyId] = hosted
	Lobby.opened:Fire(hosted)
	return hosted
end

-- A spawn marker for the next arrival, spread across the map's spawn points.
local function spawnFor(hosted: Hosted): CFrame?
	local spots = Map.markers(hosted.map, "spawn")
	if #spots == 0 then
		return nil
	end
	local count = 0
	for _ in hosted.players do
		count += 1
	end
	return spots[count % #spots + 1].CFrame + Vector3.new(0, 3, 0)
end

local function refuse(player: Player, ticket: RunTicket.Ticket, reason: string)
	Sync.notice(player, `Couldn't join that lobby ({reason})`)
	Lobby.failed:Fire(player, reason)
	local transport = adapter
	if transport then
		transport.sendHome(player, ticket.homePlaceId, { v = 1 })
	end
end

local function arrive(player: Player, ticket: RunTicket.Ticket)
	if role == "run" and ticket.lobbyId ~= game.PrivateServerId then
		refuse(player, ticket, "wrong server")
		return
	end
	local hosted: Hosted? = hostedLobbies[ticket.lobbyId]
	if hosted == nil and role == "run" then
		hosted = host(ticket.lobbyId, ticket.locationId, ticket.powerBand)
	end
	if hosted == nil or hosted.location.id ~= ticket.locationId then
		refuse(player, ticket, "closed")
		return
	end
	assert(hosted, "hosted")
	local stamp = now()
	local state = hosted.state
	local ok: boolean, reason: string? = true, nil
	if ticket.reentry then
		ok, reason = LobbyMath.reenter(state, player.UserId, stamp, lobbyConfig)
	else
		ok, reason = LobbyMath.reserve(state, stamp, lobbyConfig, { player.UserId }, ticket.partyId, ticket.powerBand)
	end
	if ok then
		ok, reason = LobbyMath.arrive(state, player.UserId, stamp, lobbyConfig)
	end
	if not ok then
		refuse(player, ticket, reason or "refused")
		return
	end
	local run: Run = {
		player = player,
		hosted = hosted,
		ticket = ticket,
		stats = { enteredAt = stamp, kills = 0, containers = 0, exposure = 0 },
	}
	runs[player] = run
	hosted.players[player] = true
	reentries[player] = nil
	local spawn = spawnFor(hosted)
	local character = player.Character
	if spawn and character then
		character:PivotTo(spawn)
	end
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.Died:Once(function()
			onDied(player, run)
		end)
	end
	publish(hosted, true)
	Lobby.entered:Fire(player, run)
	Sync.fx(player, "runEnter", { locationId = hosted.location.id, reentry = ticket.reentry })
	Analytics.custom(player, "FogRunEnter", hosted.location.fogTier, { hosted.location.id })
end

-- The simulation's way home: back to the player's plot.
local function homeLocally(player: Player, data: Teleport.HomeData)
	if data.lobbyId and data.locationId and data.reentryUntil then
		reentries[player] = { lobbyId = data.lobbyId, locationId = data.locationId, untilAt = data.reentryUntil }
	end
	local plot = Plots.of(player)
	local character = player.Character
	local humanoid = humanoidOf(player)
	if plot and character and humanoid and humanoid.Health > 0 then
		character:PivotTo(Plots.spawnCFrame(plot))
	end
end

local function closeHosted(hosted: Hosted, lost: { number })
	for _, userId in lost do
		local player = Players:GetPlayerByUserId(userId)
		local run = player and runs[player]
		if player and run then
			applyDeath(player, run, true)
			Sync.notice(player, "The Fog took you")
			finish(player, run, "lost")
		end
	end
	for player in hosted.players do
		local run = runs[player]
		if run then
			finish(player, run, "lost")
		end
	end
	hostedLobbies[hosted.id] = nil
	local transport = adapter
	if transport then
		transport.unpublish(hosted.id, hosted.location.id)
	end
	Lobby.closed:Fire(hosted)
end

local function tickHosted(hosted: Hosted)
	local stamp = now()
	local state = hosted.state
	local result = LobbyMath.tick(state, stamp, lobbyConfig)
	if result.closed then
		closeHosted(hosted, result.lost)
		return
	end
	if LobbyMath.canCloseEarly(state, stamp, lobbyConfig) then
		closeHosted(hosted, LobbyMath.close(state, stamp, "empty"))
		return
	end
	local band, def = LobbyMath.band(state, stamp, lobbyConfig)
	if band ~= hosted.band then
		hosted.band = band
		Lobby.bandChanged:Fire(hosted, band)
		for player in hosted.players do
			Sync.notice(player, `The Fog thickens: {def.name}`, "warn")
		end
	end
	if not hosted.warned and LobbyMath.phase(state, stamp, lobbyConfig) == "warning" then
		hosted.warned = true
		for player in hosted.players do
			Sync.notice(player, `The Fog closes in {lobbyConfig.warningSeconds} s. Get out.`, "warn")
			Sync.fx(player, "fogWarning", { closesAt = LobbyMath.closesAt(state, lobbyConfig) })
		end
	end
	-- LDOE_PARITY #37: Dense and Black fog seep in; worn fogResist slows it.
	local exposureConfig = tuning.fogExposure
	for player in hosted.players do
		local run = runs[player]
		local data = PlayerData.get(player)
		if run and data then
			local resist = FogExposure.resist(data.inventory.equipment :: any, Items, exposureConfig)
			local fogTier = hosted.location.fogTier
			run.stats.exposure = FogExposure.step(run.stats.exposure, TICK_SECONDS, fogTier, resist, exposureConfig)
			local damage = FogExposure.damage(run.stats.exposure, TICK_SECONDS, exposureConfig)
			if damage > 0 then
				Lobby.hurtPlayer(player, damage, "fog")
			end
		end
	end
	publish(hosted)
end

-- What the client's HUD shows on a run (checklist 12.3, 12.6, 12.7).
local function runState(player: Player, run: Run): any
	local hosted = run.hosted
	local stamp = now()
	local band, def = LobbyMath.band(hosted.state, stamp, lobbyConfig)
	local drops = {}
	for _, drop in LobbyMath.drops(hosted.state, stamp, lobbyConfig) do
		local canOpen =
			LobbyMath.canAccessDrop(hosted.state, drop.id, player.UserId, run.ticket.partyId, stamp, lobbyConfig)
		table.insert(drops, {
			id = drop.id,
			owner = drop.ownerUserId,
			at = if drop.position then { drop.position.x, drop.position.z } else nil,
			canOpen = canOpen,
			mine = drop.ownerUserId == player.UserId,
		})
	end
	local payload: { [string]: any } = {
		lobbyId = hosted.id,
		locationId = hosted.location.id,
		fogTier = hosted.location.fogTier,
		phase = LobbyMath.phase(hosted.state, stamp, lobbyConfig),
		meter = LobbyMath.meter(hosted.state, stamp, lobbyConfig),
		band = band,
		bandName = def.name,
		closesAt = LobbyMath.closesAt(hosted.state, lobbyConfig),
		serverTime = stamp,
		drops = drops,
		exposure = run.stats.exposure / tuning.fogExposure.max, -- LDOE_PARITY #37
	}
	for name, provider in providers do
		local ok, value = pcall(provider, player, run)
		if ok then
			payload[name] = value
		end
	end
	return payload
end

-- Death drops (BagTake, BagTakeAll) ---------------------------------------------------------------

local function nearDrop(player: Player, drop: LobbyMath.DeathDrop): boolean
	local root = rootOf(player)
	if root == nil or drop.position == nil then
		return false
	end
	local offset = Vector3.new(drop.position.x - root.Position.X, 0, drop.position.z - root.Position.Z)
	return offset.Magnitude <= tuning.interaction.reachStuds + tuning.combat.lagToleranceStuds
end

local function takeFromBag(player: Player, bagId: string, section: LobbyMath.Section, index: number): boolean
	local run = runs[player]
	if run == nil then
		return false
	end
	local state = run.hosted.state
	local drop = state.drops[bagId]
	if drop == nil or not nearDrop(player, drop) then
		return false
	end
	local slot, reason =
		LobbyMath.takeFromDrop(state, bagId, player.UserId, run.ticket.partyId, section, index, nil, now(), lobbyConfig)
	if slot == nil then
		if reason == "denied" then
			Sync.notice(player, "Only its owner and their party can open that in Light fog")
		end
		return false
	end
	local given, leftover = Inventory.giveSlots(player, { slot })
	for _, rest in leftover do
		LobbyMath.returnToDrop(state, bagId, section, rest, now(), drop.ownerUserId)
	end
	if #given == 0 then
		Sync.notice(player, "Your bag is full")
		return false
	end
	Sync.fx(player, "items", { items = given, source = "bag" })
	return true
end

local function takeAllFromBag(player: Player, bagId: string)
	local run = runs[player]
	local drop = run and run.hosted.state.drops[bagId]
	if drop == nil then
		return
	end
	-- Gear first, then the backpack, last slot first so indices stay valid.
	for index = #drop.equipment, 1, -1 do
		if not takeFromBag(player, bagId, "equipment", index) then
			return
		end
	end
	for index = #drop.backpack, 1, -1 do
		if not takeFromBag(player, bagId, "backpack", index) then
			return
		end
	end
end

-- "Recover all" (LDOE_PARITY #46): the death screen sends the whole drop to the inbox,
-- by rewarded ad once a day or by premium (both verified by S3 through Payments).
local recoverDaily: { [Player]: DeathRecovery.DailyState } = {}

local function recoverAll(player: Player, bagId: string, method: DeathRecovery.Method)
	local stamp = now()
	local daily = recoverDaily[player] or { day = 0, used = 0 }
	if not DeathRecovery.canRecoverAll(daily, method, stamp, tuning.deathRecovery) then
		Sync.notice(player, "You've used today's free recovery")
		return
	end
	for _, hosted in hostedLobbies do
		local drop = hosted.state.drops[bagId]
		if drop and drop.ownerUserId == player.UserId then
			if not Payments.pay(player, "recoverAll", method, 0) then
				Sync.notice(player, "Recovery isn't available yet")
				return
			end
			local slots = LobbyMath.recoverAll(hosted.state, bagId, player.UserId, stamp, lobbyConfig)
			if slots then
				Inbox.grant(player, slots, "Recovery")
				if method == "ad" then
					recoverDaily[player] = DeathRecovery.useRecoverAll(daily, stamp)
				end
			end
			return
		end
	end
end

-- Parties (PartyInvite, PartyRespond, PartyLeave) ----------------------------------------------------

local function broadcastParty(party: Party)
	local members = {}
	for _, member in party.members do
		table.insert(members, member.UserId)
	end
	for _, member in party.members do
		Sync.fx(member, "party", { id = party.id, leader = party.leader.UserId, members = members })
	end
end

local function leaveParty(player: Player)
	local party = parties[player]
	if party == nil then
		return
	end
	parties[player] = nil
	local index = table.find(party.members, player)
	if index then
		table.remove(party.members, index)
	end
	Sync.fx(player, "party", nil)
	if #party.members <= 1 then
		for _, member in party.members do
			parties[member] = nil
			Sync.fx(member, "party", nil)
		end
		return
	end
	if party.leader == player then
		party.leader = party.members[1]
	end
	broadcastParty(party)
end

local function invite(player: Player, userId: number)
	local target = Players:GetPlayerByUserId(userId)
	if target == nil or target == player or runs[player] or runs[target] then
		return
	end
	local party = parties[player]
	if party and (party.leader ~= player or #party.members >= tuning.matchmaking.maxPartySize) then
		Sync.notice(player, "Only the party leader can invite, up to a full party")
		return
	end
	invites[target] = invites[target] or {}
	invites[target][player] = now() + INVITE_SECONDS
	Sync.fx(target, "partyInvite", { from = player.UserId, name = player.DisplayName })
end

local function respond(player: Player, inviterId: number, accept: boolean)
	local inviter = Players:GetPlayerByUserId(inviterId)
	local pending = invites[player]
	local expiresAt = if pending and inviter then pending[inviter] else nil
	if pending and inviter then
		pending[inviter] = nil
	end
	if not accept or inviter == nil or expiresAt == nil or now() > expiresAt then
		return
	end
	local party = parties[inviter]
	if party == nil then
		local guid = string.gsub(HttpService:GenerateGUID(false), "-", "")
		party = { id = string.sub(guid, 1, 16), leader = inviter, members = { inviter } }
		parties[inviter] = party
	end
	if #party.members >= tuning.matchmaking.maxPartySize then
		Sync.notice(player, "That party is full")
		return
	end
	leaveParty(player)
	table.insert(party.members, player)
	parties[player] = party
	broadcastParty(party)
end

-- Matchmaking (world side) ---------------------------------------------------------------------------

local function powerOf(player: Player): number
	local data = PlayerData.get(player)
	local view = Inventory.view(player)
	if data == nil or view == nil then
		return 0
	end
	local loadout = Matchmaking.loadoutOf(view, data.inventory.equipment :: any, Items)
	local gear = Matchmaking.gearScore(loadout, Items, tuning.matchmaking)
	return Matchmaking.power(Progression.level(player), gear, tuning.matchmaking)
end

--[[
	Queues players (a whole party, or one) for a lobby at `locationId`. Travel calls
	this when their trip arrives. They are matched within seconds (Matchmaking).
]]
function Lobby.enqueue(players: { Player }, locationId: string)
	if not Features.on(tuning, "fogRuns") or #players == 0 then
		return
	end
	local ids, powers = {}, {}
	for _, player in players do
		table.insert(ids, player.UserId)
		table.insert(powers, powerOf(player))
	end
	local id = nextId("q")
	local entry = Matchmaking.entry(id, locationId, ids, powers, Lobby.partyIdOf(players[1]), now(), tuning.matchmaking)
	queue[id] = { entry = entry, players = table.clone(players) }
	for _, player in players do
		Sync.fx(player, "matching", { locationId = locationId })
	end
end

-- Sends a player who died back into their lobby (Travel has charged the Energy).
function Lobby.reenter(player: Player, locationId: string): boolean
	local entry = Lobby.reentryOf(player)
	local transport = adapter
	if entry == nil or entry.locationId ~= locationId or transport == nil then
		return false
	end
	local location = Content.Locations[locationId]
	if location == nil then
		return false
	end
	-- The run server checks the band only for new seats; a re-entry keeps its own.
	local band = Matchmaking.band(powerOf(player), tuning.matchmaking)
	local ticket =
		RunTicket.new(entry.lobbyId, locationId, band, Lobby.partyIdOf(player), true, game.PlaceId, math.floor(now()))
	local ok = transport.send({ player }, ticket)
	if ok then
		Analytics.custom(player, "FogRunReenter", location.fogTier, { locationId })
	end
	return ok
end

local function dispatch(queued: Queued, lobbyId: string, powerBand: number)
	local transport = adapter :: Teleport.Adapter
	local ticket = RunTicket.new(
		lobbyId,
		queued.entry.locationId,
		powerBand,
		queued.entry.partyId,
		false,
		game.PlaceId,
		math.floor(now())
	)
	local ok, err = transport.send(queued.players, ticket)
	if not ok then
		for _, player in queued.players do
			Lobby.failed:Fire(player, err or "teleport failed")
		end
	end
end

local matching = false
local function matchmake()
	local transport = adapter
	if matching or transport == nil or next(queue) == nil then
		return
	end
	matching = true
	-- Drop anyone who left or started a run while queued.
	for id, queued in queue do
		for _, player in queued.players do
			if player.Parent ~= Players or runs[player] then
				queue[id] = nil
				break
			end
		end
	end
	local byLocation: { [string]: { Matchmaking.Entry } } = {}
	for _, queued in queue do
		local list = byLocation[queued.entry.locationId] or {}
		table.insert(list, queued.entry)
		byLocation[queued.entry.locationId] = list
	end
	local ttl = lobbyConfig.durationSeconds + lobbyConfig.openTimeoutSeconds
	for locationId, entries in byLocation do
		local open: { Matchmaking.OpenLobby } = {}
		for _, info in transport.listOpen(locationId) do
			table.insert(open, info)
		end
		local plan = Matchmaking.tick(entries, open, now(), tuning.matchmaking, lobbyConfig.capacity)
		for _, join in plan.joins do
			local queued = queue[join.entryId]
			if queued and transport.claimSeats(join.lobbyId, locationId, #queued.players, ttl) then
				queue[join.entryId] = nil
				local band = queued.entry.band
				for _, info in open do
					if info.id == join.lobbyId then
						band = info.powerBand
					end
				end
				dispatch(queued, join.lobbyId, band)
			end
		end
		for _, created in plan.creates do
			local lobbyId = transport.create(locationId, created.powerBand, lobbyConfig.capacity, ttl)
			if lobbyId then
				for _, entryId in created.entryIds do
					local queued = queue[entryId]
					if queued and transport.claimSeats(lobbyId, locationId, #queued.players, ttl) then
						queue[entryId] = nil
						dispatch(queued, lobbyId, created.powerBand)
					end
				end
			end
		end
	end
	matching = false
end

-- Lifecycle -------------------------------------------------------------------------------------------

local function readJoinData(player: Player): any
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	return if ok and type(data) == "table" then data.TeleportData else nil
end

local function onPlayerAdded(player: Player)
	local data = readJoinData(player)
	if role == "run" then
		local ticket, reason = RunTicket.parse(data, now(), lobbyConfig.ticketMaxAgeSeconds)
		if ticket == nil then
			warn(`Lobby: {player.Name} arrived without a valid ticket ({reason})`)
			player:Kick("That Fog Run has ended. Rejoin to go home.")
			return
		end
		local accepted = ticket :: RunTicket.Ticket
		-- Seat them once their profile has moved over (ProfileStore session).
		local connection: any
		connection = PlayerData.loaded:Connect(function(loadedPlayer: Player)
			if loadedPlayer == player then
				connection:Disconnect()
				arrive(player, accepted)
			end
		end)
		if PlayerData.get(player) then
			connection:Disconnect()
			arrive(player, accepted)
		end
	elseif type(data) == "table" and data.v == 1 and type(data.lobbyId) == "string" then
		-- Home from a run they died in: offer re-entry (the run server re-checks it all).
		if type(data.locationId) == "string" and type(data.reentryUntil) == "number" then
			reentries[player] = { lobbyId = data.lobbyId, locationId = data.locationId, untilAt = data.reentryUntil }
		end
	end
end

local function onPlayerRemoving(player: Player)
	local run = runs[player]
	if run then
		LobbyMath.leave(run.hosted.state, player.UserId)
		Lobby.exited:Fire(player, run, "left")
		runs[player] = nil
		run.hosted.players[player] = nil
	end
	leaveParty(player)
	invites[player] = nil
	reentries[player] = nil
	lastCause[player] = nil
	for id, queued in queue do
		if table.find(queued.players, player) then
			queue[id] = nil
		end
	end
end

function Lobby.init()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	role = Teleport.role()
	Net.onEvent("PartyInvite", invite)
	Net.onEvent("PartyRespond", respond)
	Net.onEvent("PartyLeave", leaveParty)
	Net.onEvent("BagTake", function(player: Player, bagId: string, section: LobbyMath.Section, index: number)
		takeFromBag(player, bagId, section, index)
	end)
	Net.onEvent("BagTakeAll", takeAllFromBag)
	Net.onEvent("RecoverAll", recoverAll)
end

function Lobby.start()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	local transport = if Teleport.canGoLive() or role == "run"
		then Teleport.live()
		else Teleport.simulated({
			host = function(lobbyId: string, locationId: string, powerBand: number)
				host(lobbyId, locationId, powerBand)
			end,
			arrive = arrive,
			home = homeLocally,
		})
	adapter = transport
	transport.onFailure(function(player: Player, message: string)
		Lobby.failed:Fire(player, message)
	end)
	print(`Lobby: Fog Runs on ({role} server, {transport.kind} teleports)`)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			for _, hosted in hostedLobbies do
				local ok, err = pcall(tickHosted :: any, hosted)
				if not ok then
					warn(`Lobby: tick failed for {hosted.id}: {err}`)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(MATCH_SECONDS)
			local ok, err = pcall(matchmake :: any)
			matching = false
			if not ok then
				warn(`Lobby: matchmaking failed: {err}`)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(STATE_SECONDS)
			for player, run in runs do
				Net.fireClient("RunState", player, runState(player, run))
			end
		end
	end)
end

return Lobby
