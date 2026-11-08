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

	Trips live in server memory for Phase A, so a Walk ends if you leave the game;
	Phase B saves them in the profile once slice 1's schema is merged.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Features = require(ReplicatedStorage.Shared.Features)
local Types = require(ReplicatedStorage.Shared.Types)
local Domain = ReplicatedStorage.Shared.Domain
local EnergyMath = require(Domain.Energy)
local Rng = require(Domain.Rng)
local TravelBonus = require(Domain.TravelBonus)
local TravelMath = require(Domain.Travel)
local Net = require("../Net")
local Energy = require("./Energy")
local Inventory = require("./Inventory")
local Lobby = require("./Lobby")
local Progression = require("./Progression")
local Sync = require("./Sync")

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

local REASONS: { [string]: string } = {
	level = "You need a higher level for that fog",
	energy = "Not enough Energy for a Run",
	unavailable = "That location isn't open right now",
	tooLate = "The Fog closes too soon to get back in",
}

local function now(): number
	return workspace:GetServerTimeNow()
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
	return {
		now = now(),
		level = Progression.level(player),
		energy = state,
		energyConfig = config,
		config = travelConfig,
	}
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
	if location == nil or trips[player] or Lobby.runOf(player) then
		return
	end
	if not Lobby.isPartyLeader(player) then
		Sync.notice(player, "Your party leader starts the trip")
		return
	end
	local members = Lobby.partyOf(player)
	-- Everyone checks out first; nobody pays unless everybody can go.
	local plans: { [Player]: { trip: TravelMath.Trip, energy: EnergyMath.State } } = {}
	for _, member in members do
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
		plans[member] = { trip = trip, energy = energy }
	end
	local record: Trip = { trip = plans[player].trip, location = location, members = members, spent = {} }
	for _, member in members do
		local plan = plans[member]
		if plan.trip.energySpent > 0 then
			Energy.set(member, plan.energy, -plan.trip.energySpent, "Run")
			lastSpend[member] = { amount = plan.trip.energySpent, at = now() }
		end
		record.spent[member] = plan.trip.energySpent
		trips[member] = record
		Sync.fx(member, "travel", {
			locationId = locationId,
			mode = mode,
			departedAt = plan.trip.departedAt,
			arrivesAt = plan.trip.arrivesAt,
		})
	end
end

local function cancel(player: Player)
	local record = trips[player]
	if record == nil or not Lobby.isPartyLeader(player) then
		return
	end
	local refunds = TravelMath.cancelRefund(record.trip, now()) > 0
	for _, member in record.members do
		trips[member] = nil
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
	if entry == nil or location == nil or entry.locationId ~= locationId or trips[player] or Lobby.runOf(player) then
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
		return
	end
	Energy.set(player, energy, -trip.energySpent, "Reentry")
	lastSpend[player] = { amount = trip.energySpent, at = now() }
	trips[player] = { trip = trip, location = location, members = { player }, spent = { [player] = trip.energySpent } }
	Sync.fx(player, "travel", { locationId = locationId, mode = "run", arrivesAt = trip.arrivesAt, reentry = true })
end

local function arrive(record: Trip)
	local present: { Player } = {}
	for _, member in record.members do
		if member.Parent == Players and trips[member] == record then
			trips[member] = nil
			table.insert(present, member)
			local bonus =
				TravelBonus.roll(record.location.id, record.location.run.travelBonusTableId, record.trip.mode, {
					tables = Content.LootTables :: any,
					rng = rng,
					items = Items,
					config = tuning.travelBonus,
				})
			if bonus then
				bonuses[member] = bonus
				Sync.fx(member, "travelBonus", { items = bonus.items })
			end
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
		Lobby.enqueue(present, record.location.id)
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

local function take(player: Player, index: number)
	local bonus = bonuses[player]
	local stack = bonus and TravelBonus.take(bonus, index)
	if stack then
		giveBonus(player, { stack })
	end
end

local function takeAll(player: Player)
	local bonus = bonuses[player]
	if bonus then
		giveBonus(player, TravelBonus.takeAll(bonus))
	end
end

function Travel.init()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	Net.onEvent("TravelStart", start)
	Net.onEvent("TravelCancel", cancel)
	Net.onEvent("LobbyReenter", reenter)
	Net.onEvent("TravelBonusTake", take)
	Net.onEvent("TravelBonusTakeAll", takeAll)
end

function Travel.start()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	-- A trip in that never seated the player gives its Energy back once.
	Lobby.failed:Connect(function(player: Player, reason: string)
		local spend = lastSpend[player]
		lastSpend[player] = nil
		if spend and now() - spend.at <= REFUND_WINDOW_SECONDS then
			refund(player, spend.amount, "RunRefund")
			Sync.notice(player, `Trip cancelled ({reason}); Energy refunded`, "info")
		end
	end)
	Lobby.entered:Connect(function(player: Player)
		lastSpend[player] = nil
	end)
	Lobby.exited:Connect(function(player: Player)
		local bonus = bonuses[player]
		bonuses[player] = nil
		if bonus and not TravelBonus.isEmpty(bonus) then
			Sync.fx(player, "travelBonus", nil) -- whatever was left behind is gone
		end
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
