--!strict
--[[
	Travel: going out into the Fog (GAME_DESIGN "Leaving home"; checklist 11.3-11.7).
	Off until Tuning.features.fogRuns.

	- TravelStart (Run or Walk) only from the Trailhead or the fog wall, within
	  Tuning.travel.departureStuds. A party leader takes the whole party; everyone
	  must be there, meet the level gate and (for a Run) pay their own Energy, or
	  nobody goes. Rotating locations refuse trips while closed (Domain/Travel).
	- A Run arrives after its short loading beat, a Walk after its real minutes.
	  Turning back refunds a Run still loading (Travel.cancelRefund); a lobby that
	  never seats the player refunds it too (Lobby.failed).
	- On arrival the trip may turn something up (Domain/TravelBonus): the "found
	  on the way" panel, with TAKE per item and Take all. Untaken items are lost
	  when the run ends.
	- LobbyReenter: back into the lobby you died in, by Run, for half its Energy.

	Trips live in server memory, and a solo Walk is also saved in the profile
	(PlayerData.travel.walk, the flow review's F-36): leaving the game doesn't end it. The
	next visit home resumes it, and a Walk that arrived while you were away arrives then.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Features = require(ReplicatedStorage.Shared.Features)
local Types = require(ReplicatedStorage.Shared.Types)
local Domain = ReplicatedStorage.Shared.Domain
local AutoClear = require(Domain.AutoClear)
local EnergyMath = require(Domain.Energy)
local FogMap = require(Domain.FogMap)
local PlayerSchema = require(Domain.PlayerSchema)
local GatheringMath = require(Domain.Gathering)
local Rng = require(Domain.Rng)
local TravelBonus = require(Domain.TravelBonus)
local TravelMath = require(Domain.Travel)
local Net = require("../Net")
local Payments = require("../FogRuns/Payments")
local Energy = require("./Energy")
local Inbox = require("./Inbox")
local Inventory = require("./Inventory")
local Lobby = require("./Lobby")
local PlayerData = require("./PlayerData")
local Progression = require("./Progression")
local RunWorld = require("./RunWorld")
local Sync = require("./Sync")
local Maps = require("../FogRuns/Maps")
local Teleport = require("../FogRuns/Teleport")

local Travel = {}

local tuning = Content.Tuning
local travelConfig: TravelMath.Config = tuning.travel :: any
local Items: any = Content.Items
local TICK_SECONDS = 0.5
local REFUND_WINDOW_SECONDS = 120

type Trip = {
	trip: TravelMath.Trip,
	location: Types.LocationDef,
	members: { Player },
	spent: { [Player]: number },
}

local trips: { [Player]: Trip } = {}
local bonuses: { [Player]: TravelBonus.Bonus } = {}
local lastSpend: { [Player]: { amount: number, at: number } } = {}
local rng = Rng.new(Random.new():NextInteger(1, 2 ^ 31 - 2))

-- LDoE parity state: #43 airdrops and signal towers, #31 ad clears. It lives in the profile
-- (PlayerSchema v13, the flow review's F-23), since every run is a new server; in memory
-- the caps and tower parts reset on each hop. A profile not loaded yet reads as fresh.
local FRESH = PlayerSchema.freshLimits()

local function limits(player: Player): PlayerSchema.Limits
	local data = PlayerData.get(player)
	return if data and data.limits then data.limits else FRESH
end

-- Writes go to the loaded profile only (never to the shared fresh table).
local function saveLimits(player: Player, write: (PlayerSchema.Limits) -> ())
	local data = PlayerData.get(player)
	if data and data.limits then
		write(data.limits)
	end
end

local REASONS: { [string]: string } = {
	level = "You need a higher level for that fog",
	energy = "Not enough Energy for a Run",
	unavailable = "That location isn't open right now",
	tooLate = "The Fog closes too soon to get back in",
	walkTooLate = "It closes before you'd walk there: take a Run",
	gate = "Repair the signal tower to open this fog",
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local RESUME_DELAY = 5 -- seconds after the profile loads: let the client settle first

-- F-36: a solo Walk lives in the profile too, so it outlasts the session.
local function remember(player: Player, record: Trip?)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	data.travel.walk = if record and #record.members == 1 then TravelMath.saveWalk(record.trip) else nil
end

-- Whether a player stands at the Trailhead or the fog wall (where trips start).
local function atDeparture(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local world = workspace:FindFirstChild("World")
	if root == nil or world == nil then
		return false
	end
	local reach = tuning.travel.departureStuds
	local trailhead = world:FindFirstChild("Trailhead")
	local sign = trailhead and trailhead:FindFirstChild("Sign")
	if sign and sign:IsA("BasePart") and (sign.Position - root.Position).Magnitude <= reach then
		return true
	end
	local wall = world:FindFirstChild("FogWall")
	if wall then
		for _, bank in wall:GetChildren() do
			if bank:IsA("BasePart") and (bank.Position - root.Position).Magnitude <= reach + bank.Size.X / 2 then
				return true
			end
		end
	end
	return false
end

local function context(player: Player): TravelMath.Context?
	local state, config = Energy.state(player)
	if state == nil then
		return nil
	end
	local stamp = now()
	return {
		now = stamp,
		level = Progression.level(player),
		energy = state,
		energyConfig = config,
		config = travelConfig,
		-- The signal towers (M4) gate Dense and Black only once their UI ships.
		gates = if Features.on(tuning, "regionGates") then tuning.regionGates else nil,
		repairedGates = limits(player).towers.repaired,
		airdropPin = #FogMap.livePins(limits(player).pins, stamp) > 0,
	}
end

--[[
	Writes an Energy spend and lands any airdrop it triggered (LDOE_PARITY #43: as
	Energy falls below 140, 80 and 20, once each a UTC day).
]]
local function spendEnergy(
	player: Player,
	before: EnergyMath.State,
	after: EnergyMath.State,
	cost: number,
	reason: string
)
	if cost <= 0 then
		return
	end
	local stamp = now()
	local _, config = Energy.state(player)
	local was = EnergyMath.current(before, stamp, config).value
	Energy.set(player, after, -cost, reason)
	lastSpend[player] = { amount = cost, at = stamp }
	if not Features.on(tuning, "airdrops") then
		return
	end
	local crossed, day =
		FogMap.airdropsCrossed(was, after.value, FogMap.loadDay(limits(player).airdrops), stamp, tuning.airdrops)
	saveLimits(player, function(saved)
		saved.airdrops = FogMap.saveDay(day)
	end)
	for _, threshold in crossed do
		local list = FogMap.livePins(limits(player).pins, stamp)
		local pin = FogMap.pin(threshold, stamp, tuning.airdrops)
		table.insert(list, pin)
		saveLimits(player, function(saved)
			saved.pins = list
		end)
		Sync.fx(player, "airdrop", { locationId = pin.locationId, expiresAt = pin.expiresAt })
	end
end

local function refund(player: Player, amount: number, reason: string)
	if amount <= 0 then
		return
	end
	local state, config = Energy.state(player)
	if state then
		Energy.set(player, EnergyMath.refund(state, now(), config, amount), amount, reason)
	end
end

local function start(player: Player, locationId: string, mode: TravelMath.Mode)
	local location = Content.Locations[locationId]
	if location == nil or trips[player] or Lobby.busy(player) then
		return
	end
	if not Maps.has(locationId) then
		Sync.notice(player, "That place can't be reached yet")
		return
	end
	if not Lobby.isPartyLeader(player) then
		Sync.notice(player, "Your party leader starts the trip")
		return
	end
	local members = Lobby.partyOf(player)
	-- Everyone checks out first; nobody pays unless everybody can go.
	local plans: { [Player]: { trip: TravelMath.Trip, energy: EnergyMath.State, before: EnergyMath.State } } = {}
	for _, member in members do
		if member ~= player and (trips[member] or Lobby.busy(member)) then
			Sync.notice(player, `{member.DisplayName} is already on their way somewhere`)
			return
		end
		if not atDeparture(member) then
			Sync.notice(
				player,
				if member == player
					then "Head to the Trailhead or the fog's edge to set out"
					else `{member.DisplayName} isn't at the Trailhead`
			)
			return
		end
		local ctx = context(member)
		if ctx == nil then
			return
		end
		local trip, energy, reason = TravelMath.start(location :: any, mode, ctx)
		if trip == nil or energy == nil then
			local text = REASONS[reason or ""] or "Can't travel there now"
			Sync.notice(player, if member == player then text else `{member.DisplayName}: {text}`)
			if reason == "energy" then
				local shortfall = EnergyMath.shortfall(ctx.energy, ctx.now, ctx.energyConfig, location.energyCost)
				Sync.fx(member, "energyShort", { need = shortfall }) -- the refill slot (S3)
			end
			return
		end
		plans[member] = { trip = trip, energy = energy, before = ctx.energy }
	end
	local record: Trip = { trip = plans[player].trip, location = location, members = members, spent = {} }
	for _, member in members do
		local plan = plans[member]
		if location.availability.kind == "airdrop" then
			local left = FogMap.usePin(limits(member).pins, now()) or {} -- the crate is yours once
			saveLimits(member, function(saved)
				saved.pins = left
			end)
		end
		spendEnergy(member, plan.before, plan.energy, plan.trip.energySpent, "Run")
		record.spent[member] = plan.trip.energySpent
		trips[member] = record
		remember(member, record)
		Sync.fx(member, "travel", {
			locationId = locationId,
			mode = mode,
			departedAt = plan.trip.departedAt,
			arrivesAt = plan.trip.arrivesAt,
		})
	end
	-- The Studio simulation builds the map during the trip (batch 3; live run servers build at boot).
	RunWorld.prepare(location.id)
end

local function cancel(player: Player)
	local record = trips[player]
	if record == nil or not Lobby.isPartyLeader(player) then
		return
	end
	local refunds = TravelMath.cancelRefund(record.trip, now()) > 0
	for _, member in record.members do
		trips[member] = nil
		remember(member, nil)
		if refunds then
			refund(member, record.spent[member] or 0, "RunRefund")
		end
		lastSpend[member] = nil
		Sync.fx(member, "travelCancelled", nil)
	end
end

local function reenter(player: Player, locationId: string)
	local entry = Lobby.reentryOf(player)
	local location = Content.Locations[locationId]
	if entry == nil or location == nil or entry.locationId ~= locationId or trips[player] or Lobby.busy(player) then
		Sync.notice(player, "There's no bag of yours to go back for")
		return
	end
	local ctx = context(player)
	if ctx == nil then
		return
	end
	local trip, energy, reason = TravelMath.startReentry(location :: any, ctx, entry.untilAt)
	if trip == nil or energy == nil then
		Sync.notice(player, REASONS[reason or ""] or "Can't go back in now")
		if reason == "energy" then
			local cost = TravelMath.reentryPlan(location :: any, ctx.config).energyCost
			Sync.fx(player, "energyShort", { need = EnergyMath.shortfall(ctx.energy, ctx.now, ctx.energyConfig, cost) })
		end
		return
	end
	spendEnergy(player, ctx.energy, energy, trip.energySpent, "Reentry")
	trips[player] = { trip = trip, location = location, members = { player }, spent = { [player] = trip.energySpent } }
	Sync.fx(player, "travel", { locationId = locationId, mode = "run", arrivesAt = trip.arrivesAt, reentry = true })
end

local function arrive(record: Trip)
	local present: { Player } = {}
	for _, member in record.members do
		if member.Parent == Players and trips[member] == record then
			trips[member] = nil
			remember(member, nil)
			table.insert(present, member)
		end
	end
	if #present == 0 then
		return
	end
	if record.trip.reentry then
		if not Lobby.reenter(present[1], record.location.id) then
			refund(present[1], record.spent[present[1]] or 0, "ReentryRefund")
		end
	else
		Lobby.enqueue(present, record.location.id, record.trip.mode, record.trip.departedAt)
	end
end

local function giveBonus(player: Player, stacks: { Types.ItemStack })
	local bonus = bonuses[player]
	if bonus == nil or #stacks == 0 then
		return
	end
	local given, leftover = Inventory.give(player, stacks, "TravelBonus")
	TravelBonus.putBack(bonus, leftover)
	if #given > 0 then
		Sync.fx(player, "items", { items = given, source = "travelBonus" })
	end
	if #leftover > 0 then
		Sync.notice(player, "Your bag is full")
	end
	Sync.fx(player, "travelBonus", { items = bonus.items })
end

-- LDOE_PARITY #40: TAKE costs one rewarded ad per item; TAKE ALL costs Rations.
local function take(player: Player, index: number)
	local bonus = bonuses[player]
	if bonus == nil or bonus.items[index] == nil then
		return
	end
	local price = TravelBonus.price("one", tuning.travelBonus)
	if not Payments.pay(player, "bonusItem", price.method, 0) then
		Sync.notice(player, "Watch an ad to take this (or Take all for Rations)")
		return
	end
	local stack = TravelBonus.take(bonus, index)
	if stack then
		giveBonus(player, { stack })
	end
end

local function takeAll(player: Player)
	local bonus = bonuses[player]
	if bonus == nil or TravelBonus.isEmpty(bonus) then
		return
	end
	local price = TravelBonus.price("all", tuning.travelBonus)
	if not Payments.pay(player, "bonusAll", price.method, price.count) then
		Sync.notice(player, `Take all costs {price.count} Trail Rations`)
		return
	end
	giveBonus(player, TravelBonus.takeAll(bonus))
end

-- LDOE_PARITY #43 Hurry: spend Energy to finish a Walk now.
local function hurry(player: Player)
	local record = trips[player]
	local ctx = context(player)
	if record == nil or ctx == nil or record.trip.mode ~= "walk" or #record.members > 1 then
		return
	end
	local hurried, energy = TravelMath.hurry(record.trip, ctx, tuning.travelBonus.hurryEnergyPerMinute)
	if hurried == nil or energy == nil then
		Sync.notice(player, "Not enough Energy to hurry")
		return
	end
	spendEnergy(player, ctx.energy, energy, hurried.energySpent - record.trip.energySpent, "Hurry")
	record.trip = hurried
	remember(player, record)
	Sync.fx(player, "travel", { locationId = record.location.id, mode = "walk", arrivesAt = hurried.arrivesAt })
end

--[[
	LDOE_PARITY #31 paid AUTO: clears a location into the inbox without entering it.
	It is still a trip, so it costs the Run's Energy (and checks the level and region
	gates) on top of the ad, Rations or premium.
]]
local function autoClear(player: Player, locationId: string, method: AutoClear.Method)
	local location = Content.Locations[locationId]
	local ctx = context(player)
	local view = Inventory.view(player)
	if location == nil or ctx == nil or view == nil or trips[player] or Lobby.runOf(player) then
		return
	end
	if location.availability.kind == "airdrop" then
		Sync.notice(player, "Airdrops have to be looted in person")
		return
	end
	local config = tuning.autoClear
	local rationsCarried = 0
	for _, container in { view.pockets, view.backpack } do
		for _, slot in container do
			if slot.itemId == Payments.RATIONS then
				rationsCarried += slot.count
			end
		end
	end
	-- F-20: the refusal names what is missing, the same price the button shows.
	local runEnergy = TravelMath.plan(location :: any, "run", travelConfig).energyCost
	local price = AutoClear.price(location.fogTier, runEnergy, config)
	local trip, energy, reason = TravelMath.start(location :: any, "run", ctx)
	if trip == nil or energy == nil then
		if reason == "energy" then
			local have = EnergyMath.current(ctx.energy, ctx.now, ctx.energyConfig).value
			Sync.notice(player, AutoClear.shortText({ rations = 0, energy = price.energy }, 0, have) or REASONS.energy)
			Sync.fx(player, "energyShort", {
				need = EnergyMath.shortfall(ctx.energy, ctx.now, ctx.energyConfig, price.energy),
			})
		else
			Sync.notice(player, REASONS[reason or ""] or "Can't clear that now")
		end
		return
	end
	local daily = limits(player).autoAds
	local ok, refusal = AutoClear.canPay(method, location.fogTier, ctx.level, daily, rationsCarried, ctx.now, config)
	if not ok then
		Sync.notice(
			player,
			if refusal == "level"
				then `Ad clears open at level {config.adMinLevel}`
				elseif refusal == "rations" then AutoClear.shortText(price, rationsCarried, math.huge)
					or "You can't pay for that"
				else "You can't pay for that"
		)
		return
	end
	local rations = if method == "rations" then AutoClear.rationsCost(location.fogTier, config) else 0
	if not Payments.pay(player, "autoClear", method, rations) then
		Sync.notice(player, "AUTO isn't available that way yet")
		return
	end
	if method == "ad" then
		local used = AutoClear.useAd(daily, ctx.now)
		saveLimits(player, function(saved)
			saved.autoAds = used
		end)
	end
	spendEnergy(player, ctx.energy, energy, trip.energySpent, "AutoClear")
	local carried = Inventory.view(player)
	local haul = AutoClear.roll(location, {
		tables = Content.LootTables :: any,
		nodes = Content.Nodes :: any,
		enemies = Content.Enemies :: any,
		items = Items,
		rng = rng,
		config = config,
		canHarvest = function(def: Types.ResourceNodeDef): boolean
			return carried ~= nil and GatheringMath.pickTool(def, carried :: any, Items) ~= nil
		end,
	})
	local slots: { Types.Slot } = {}
	for _, stack in haul.items do
		table.insert(slots, { itemId = stack.itemId, count = stack.count })
	end
	Inbox.grant(player, slots, "AutoClear")
	if haul.xp > 0 then
		Progression.grantXp(player, haul.xp, "AutoClear")
	end
	Sync.fx(player, "autoClear", { locationId = locationId, items = haul.items, kills = haul.kills })
end

-- LDOE_PARITY #43 region gates: FILL UP and FINALIZE on a signal tower.
local function gateOf(gateId: string): Types.RegionGate?
	for _, gate in tuning.regionGates do
		if gate.id == gateId then
			return gate
		end
	end
	return nil
end

local function sendGate(player: Player, gate: Types.RegionGate)
	local rows, complete = FogMap.checklist(gate, limits(player).towers.contributed[gate.id] or {})
	Sync.fx(player, "gate", {
		id = gate.id,
		rows = rows,
		complete = complete,
		repaired = limits(player).towers.repaired[gate.id] == true,
	})
end

local function gateFill(player: Player, gateId: string)
	local gate = gateOf(gateId)
	local view = Inventory.view(player)
	if gate == nil or view == nil or limits(player).towers.repaired[gateId] then
		return
	end
	local after, nextContributed, taken = FogMap.fillUp(gate, limits(player).towers.contributed[gateId] or {}, view)
	if #taken > 0 then
		Inventory.commit(player, after)
		saveLimits(player, function(saved)
			saved.towers.contributed[gateId] = nextContributed
		end)
	end
	sendGate(player, gate)
end

local function gateFinalize(player: Player, gateId: string)
	local gate = gateOf(gateId)
	if gate == nil then
		return
	end
	local towers = limits(player).towers
	local done = FogMap.finalize(gate, towers.contributed[gateId] or {}, towers.repaired)
	if done == nil then
		Sync.notice(player, "The tower still needs parts")
		return
	end
	saveLimits(player, function(saved)
		saved.towers.repaired = done
	end)
	Sync.notice(player, `{gate.name} repaired: the {tuning.travel.fogTierNames[gate.fogTier]} fog is open`, "good")
	sendGate(player, gate)
end

function Travel.init()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	Net.onEvent("TravelStart", start)
	Net.onEvent("TravelCancel", cancel)
	Net.onEvent("LobbyReenter", reenter)
	Lobby.wantsReentry:Connect(reenter) -- "Go back in" chosen on the death screen (F-09)
	Net.onEvent("TravelBonusTake", take)
	Net.onEvent("TravelBonusTakeAll", takeAll)
	Net.onEvent("TravelHurry", hurry)
	Net.onEvent("AutoClear", autoClear)
	if Features.on(tuning, "regionGates") then
		Net.onEvent("GateFill", gateFill)
		Net.onEvent("GateFinalize", gateFinalize)
	else
		-- Declared but idle until M4: handled (and rate limited) so nothing queues up.
		Net.onEvent("GateFill", function() end)
		Net.onEvent("GateFinalize", function() end)
	end
end

function Travel.start()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	-- A trip in that never seated the player gives its Energy back once: from the spend
	-- this server recorded, or on a run server (where the spend happened elsewhere) the
	-- price the ticket's trip costs, read from Content (never from the ticket itself).
	local refundedTickets: { [string]: boolean } = {}
	Lobby.failed:Connect(function(player: Player, reason: string, ticket: any)
		local spend = lastSpend[player]
		lastSpend[player] = nil
		local amount = 0
		if spend and now() - spend.at <= REFUND_WINDOW_SECONDS then
			amount = spend.amount
		elseif type(ticket) == "table" and Teleport.role() == "run" then
			local key = `{player.UserId}:{ticket.issuedAt}`
			local location = Content.Locations[ticket.locationId]
			if location and not refundedTickets[key] then
				refundedTickets[key] = true
				amount = if ticket.reentry
					then TravelMath.reentryPlan(location :: any, travelConfig).energyCost
					elseif ticket.mode == "run" then TravelMath.plan(location :: any, "run", travelConfig).energyCost
					else 0
			end
		end
		if amount > 0 then
			refund(player, amount, "RunRefund")
			Sync.notice(player, `Trip cancelled ({reason}); Energy refunded`, "info")
		end
		Sync.fx(player, "travelCancelled")
	end)
	Lobby.entered:Connect(function(player: Player, run: Lobby.Run)
		lastSpend[player] = nil
		-- "Found on the way" (checklist 11.6): rolled where the run is hosted, so it is there
		-- on arrival whether the lobby is a reserved server or simulated here.
		local mode = run.ticket.mode
		if mode == nil or run.ticket.reentry then
			return
		end
		local location = run.hosted.location
		local bonus = TravelBonus.roll(location.id, location.run.travelBonusTableId, mode :: TravelMath.Mode, {
			tables = Content.LootTables :: any,
			rng = rng,
			items = Items,
			config = tuning.travelBonus,
		})
		if bonus then
			bonuses[player] = bonus
			Sync.fx(player, "travelBonus", { items = bonus.items })
		end
	end)
	Lobby.exited:Connect(function(player: Player)
		local bonus = bonuses[player]
		bonuses[player] = nil
		if bonus and not TravelBonus.isEmpty(bonus) then
			Sync.fx(player, "travelBonus", nil) -- whatever was left behind is gone
		end
	end)
	-- F-36: a Walk saved on an earlier visit carries on (or arrives) on this one, at home.
	PlayerData.loaded:Connect(function(player: Player)
		task.delay(RESUME_DELAY, function()
			local data = PlayerData.get(player)
			if data == nil or trips[player] or Teleport.role() == "run" or Lobby.busy(player) then
				return
			end
			local trip = TravelMath.resumeWalk(data.travel.walk, function(locationId: string): boolean
				return Content.Locations[locationId] ~= nil and Maps.has(locationId)
			end)
			if trip == nil then
				data.travel.walk = nil
				return
			end
			local location = Content.Locations[trip.destinationId]
			trips[player] = { trip = trip, location = location, members = { player }, spent = { [player] = 0 } }
			Sync.fx(player, "travel", {
				locationId = location.id,
				mode = "walk",
				departedAt = trip.departedAt,
				arrivesAt = trip.arrivesAt,
			})
			Sync.notice(
				player,
				if TravelMath.hasArrived(trip, now())
					then `You reached {location.name} while you were away`
					else `Still walking to {location.name}`,
				"info"
			)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local record = trips[player]
		trips[player] = nil
		bonuses[player] = nil
		lastSpend[player] = nil
		if record then
			local index = table.find(record.members, player)
			if index then
				table.remove(record.members, index)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			local due: { [Trip]: boolean } = {}
			for _, record in trips do
				if TravelMath.hasArrived(record.trip, now()) then
					due[record] = true
				end
			end
			for record in due do
				local ok, err = pcall(arrive :: any, record)
				if not ok then
					warn(`Travel: arrival failed: {err}`)
				end
			end
		end
	end)
end

return Travel
