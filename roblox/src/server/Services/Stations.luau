--!strict
--[[
	Stations: crafting at the Workbench, Campfire and Recycler, plus hand crafting
	(Domain/Crafting, Domain/Salvage; M1 step 3).

	Station state lives in the profile (PlayerSchema.StationState, keyed by the
	placed piece's UID) as absolute timestamps, so queues keep running while the
	player is offline and are simply collected when they come back. The Building
	service creates and removes station records; this service runs them.

	Station models get attributes for the client: FuelEndsAt (the fire burns
	until then), Ready (a job waits to be collected) and Level.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Types = require(ReplicatedStorage.Shared.Types)
local Domain = ReplicatedStorage.Shared.Domain
local Crafting = require(Domain.Crafting)
local Salvage = require(Domain.Salvage)
local Slots = require(Domain.Slots)
local InventoryMath = require(Domain.Inventory)
local Rng = require(Domain.Rng)
local Net = require("../Net")
local Analytics = require("./Analytics")
local Inventory = require("./Inventory")
local PlayerData = require("./PlayerData")
local Plots = require("./Plots")
local Sync = require("./Sync")

local Stations = {}

-- Content.Items as the narrower lookup types the Domain modules take (tables are invariant).
local Items: any = Content.Items
local Recipes = Content.Recipes
local tuning = Content.Tuning

local REASON_TEXT: { [string]: string } = {
	locked = "Not unlocked yet",
	wrongStation = "Craft that at another station",
	stationLevel = "Upgrade this station first",
	missingInputs = "Not enough materials",
	queueFull = "The queue is full",
	inventoryFull = "Make room in your bag",
	notFound = "That job is gone",
	finished = "That job is done; collect it",
	noFuel = "This station doesn't burn fuel",
	notFuel = "That won't burn",
	busy = "Collect or cancel its jobs before upgrading",
	maxLevel = "Already at the top level",
	notSalvageable = "The Recycler can't break that down",
	fuelFull = "The fuel slot is full",
}

local rng = Rng.new(Random.new():NextInteger(1, 2 ^ 31 - 2))

-- Station records ------------------------------------------------------------------------------

-- Creates the record for a newly placed station.
function Stations.create(player: Player, uid: string, stationId: Types.StationId)
	local data = PlayerData.get(player)
	if data and data.stations[uid] == nil then
		data.stations[uid] = Crafting.newStation(stationId)
		Sync.mark(player, "stations")
	end
end

-- Whether a station has queued or uncollected jobs (it can't be demolished then).
function Stations.isBusy(player: Player, uid: string): boolean
	local data = PlayerData.get(player)
	local station = data and data.stations[uid]
	return station ~= nil and #station.queue > 0
end

-- Removes a demolished station's record.
function Stations.remove(player: Player, uid: string)
	local data = PlayerData.get(player)
	if data and data.stations[uid] then
		data.stations[uid] = nil
		Sync.mark(player, "stations")
	end
end

local function updateModel(player: Player, uid: string)
	local plot = Plots.of(player)
	local data = PlayerData.get(player)
	local model = plot and plot.pieceModels[uid]
	local station = data and data.stations[uid]
	if model == nil or station == nil then
		return
	end
	local def = Content.Stations[station.stationId]
	local now = os.time()
	local ready = false
	local workingUntil = 0
	for _, job in Crafting.status(station, def, now) do
		if job.done then
			ready = true
		elseif not job.stalled then
			workingUntil = math.max(workingUntil, station.queue[job.index].endsAt)
		end
	end
	model:SetAttribute("Level", station.level)
	model:SetAttribute("FuelEndsAt", station.fuelEndsAt)
	model:SetAttribute("Ready", ready)
	-- When the queue's running jobs finish, so clients can animate and sound the station meanwhile.
	model:SetAttribute("WorkingUntil", workingUntil)
end

-- Refreshes a station's model attributes and the player's synced stations.
function Stations.refresh(player: Player, uid: string)
	updateModel(player, uid)
	Sync.mark(player, "stations")
end

-- Request helpers --------------------------------------------------------------------------------

type Context = {
	data: any,
	station: Crafting.Station,
	def: Types.StationDef,
}

local function open(player: Player, uid: string): Context?
	local data = PlayerData.get(player)
	local station = data and data.stations[uid]
	if data == nil or station == nil then
		return nil
	end
	local position = Plots.piecePosition(player, uid)
	if position == nil or not Plots.inReach(player, position, tuning.interaction.reachStuds + 2) then
		Sync.notice(player, "Move closer to the station")
		return nil
	end
	return { data = data, station = station, def = Content.Stations[station.stationId] }
end

local function refuse(player: Player, reason: string?)
	Sync.notice(player, REASON_TEXT[reason or ""] or "Can't do that")
end

local function progressOf(data: any): Crafting.Progress
	return { level = data.progression.level, unlocks = data.unlocks }
end

local function save(player: Player, ctx: Context, uid: string, station: Crafting.Station)
	ctx.data.stations[uid] = station
	Stations.refresh(player, uid)
end

-- Handlers ------------------------------------------------------------------------------------------

local function craft(player: Player, uid: string, recipeId: string, count: number)
	local ctx = open(player, uid)
	local recipe = Recipes[recipeId]
	if ctx == nil or recipe == nil then
		return
	end
	local view = Inventory.view(player) :: Types.Inventory
	local inventory, station, reason =
		Crafting.start(view, ctx.station, ctx.def, recipe, progressOf(ctx.data), os.time(), count)
	if inventory == nil or station == nil then
		refuse(player, reason)
		return
	end
	Inventory.commit(player, inventory)
	save(player, ctx, uid, station)
	for _, stack in recipe.inputs do
		Analytics.economy(
			player,
			"sink",
			stack.itemId,
			stack.count * count,
			InventoryMath.count(inventory, stack.itemId),
			"Crafting",
			recipe.id
		)
	end
	Sync.fx(player, "craftStarted", { uid = uid, recipeId = recipeId, count = count })
end

local function salvage(player: Player, uid: string, ref: string, index: number)
	local ctx = open(player, uid)
	if ctx == nil or (ref ~= "pockets" and ref ~= "backpack") then
		return
	end
	local view = Inventory.view(player) :: Types.Inventory
	local container = if ref == "pockets" then view.pockets else view.backpack
	local slot = container[index]
	if slot == nil or slot.count <= 0 then
		return
	end
	local one = { itemId = slot.itemId, count = 1, durability = slot.durability }
	local station, reason = Salvage.start(ctx.station, ctx.def, one, Items, os.time())
	if station == nil then
		refuse(player, reason)
		return
	end
	local fresh = table.clone(container)
	fresh[index] = if slot.count > 1
		then { itemId = slot.itemId, count = slot.count - 1, durability = slot.durability }
		else InventoryMath.emptySlot()
	Inventory.commit(player, {
		pockets = if ref == "pockets" then fresh else view.pockets,
		backpack = if ref == "backpack" then fresh else view.backpack,
	})
	save(player, ctx, uid, station)
	Analytics.economy(player, "sink", slot.itemId, 1, 0, "Salvage")
	Sync.fx(player, "craftStarted", { uid = uid, recipeId = "", count = 1 })
end

local function collect(player: Player, uid: string)
	local ctx = open(player, uid)
	if ctx == nil then
		return
	end
	local view = Inventory.view(player) :: Types.Inventory
	local now = os.time()
	local station, inventory, collected
	if ctx.def.salvage then
		station, inventory, collected = Salvage.collect(ctx.station, ctx.def, view, Items, rng, now, tuning.salvage)
	else
		station, inventory, collected = Crafting.collect(ctx.station, ctx.def, view, Recipes, Items, now)
	end
	if #collected == 0 then
		local anyDone = false
		for _, job in Crafting.status(ctx.station, ctx.def, now) do
			anyDone = anyDone or job.done
		end
		if anyDone then
			refuse(player, "inventoryFull")
		end
		return
	end
	Inventory.commit(player, inventory)
	save(player, ctx, uid, station)
	for _, stack in collected do
		Analytics.economy(
			player,
			"source",
			stack.itemId,
			stack.count,
			InventoryMath.count(inventory, stack.itemId),
			"Crafting"
		)
	end
	Sync.fx(player, "items", { items = collected, source = "station", uid = uid })
end

local function cancel(player: Player, uid: string, index: number)
	local ctx = open(player, uid)
	if ctx == nil then
		return
	end
	local view = Inventory.view(player) :: Types.Inventory
	local now = os.time()
	if ctx.def.salvage then
		local station, refund, reason = Salvage.cancel(ctx.station, index, Items, now)
		if station == nil or refund == nil then
			refuse(player, reason)
			return
		end
		local after, left = Slots.addTo({ view.pockets, view.backpack }, refund, Items)
		if left > 0 then
			refuse(player, "inventoryFull")
			return
		end
		Inventory.commit(player, { pockets = after[1], backpack = after[2] })
		save(player, ctx, uid, station)
		return
	end
	local station, inventory, reason = Crafting.cancel(ctx.station, ctx.def, index, view, Recipes, Items, now)
	if station == nil or inventory == nil then
		refuse(player, reason)
		return
	end
	Inventory.commit(player, inventory)
	save(player, ctx, uid, station)
end

local function fuel(player: Player, uid: string, itemId: string, count: number)
	local ctx = open(player, uid)
	local fuelDef = ctx and ctx.def.fuel
	if ctx == nil then
		return
	end
	if fuelDef == nil then
		refuse(player, "noFuel")
		return
	end
	local now = os.time()
	local burn = Crafting.burnSeconds(ctx.def, itemId)
	local capacity = fuelDef.maxUnits * burn
	local room = math.floor((capacity - Crafting.fuelRemaining(ctx.station, ctx.def, now)) / burn)
	local amount = math.min(count, room)
	if amount < 1 then
		refuse(player, "fuelFull")
		return
	end
	local view = Inventory.view(player) :: Types.Inventory
	local station, inventory, reason = Crafting.addFuel(ctx.station, ctx.def, view, itemId, amount, now)
	if station == nil or inventory == nil then
		refuse(player, reason)
		return
	end
	Inventory.commit(player, inventory)
	save(player, ctx, uid, station)
	Analytics.economy(player, "sink", itemId, amount, InventoryMath.count(inventory, itemId), "Fuel")
	Sync.fx(player, "fuelled", { uid = uid, itemId = itemId, count = amount })
end

local function upgrade(player: Player, uid: string)
	local ctx = open(player, uid)
	if ctx == nil then
		return
	end
	local nextLevel = ctx.def.levels[ctx.station.level + 1]
	if nextLevel and (nextLevel.requiredLevel or 1) > ctx.data.progression.level then
		Sync.notice(player, `Reach level {nextLevel.requiredLevel} to upgrade`)
		return
	end
	local view = Inventory.view(player) :: Types.Inventory
	local station, inventory, reason = Crafting.upgradeStation(ctx.station, ctx.def, view)
	if station == nil or inventory == nil then
		refuse(player, reason)
		return
	end
	Inventory.commit(player, inventory)
	save(player, ctx, uid, station)
	Analytics.progression(player, ctx.def.id, "complete", station.level)
	Sync.fx(player, "stationUpgraded", { uid = uid, level = station.level })
end

local function handCraft(player: Player, recipeId: string, count: number)
	local data = PlayerData.get(player)
	local recipe = Recipes[recipeId]
	if data == nil or recipe == nil then
		return
	end
	if recipe.stationId then
		refuse(player, "wrongStation")
		return
	end
	local view = Inventory.view(player) :: Types.Inventory
	local inventory, reason = Crafting.craftByHand(view, recipe, progressOf(data), Items, count)
	if inventory == nil then
		refuse(player, reason)
		return
	end
	Inventory.commit(player, inventory)
	local made: { Types.ItemStack } = {}
	for _, stack in recipe.outputs do
		table.insert(made, { itemId = stack.itemId, count = stack.count * count })
	end
	Analytics.custom(player, "HandCraft", count, { recipeId })
	Sync.fx(player, "items", { items = made, source = "craft" })
end

-- Lifecycle -------------------------------------------------------------------------------------------

function Stations.init()
	Net.onEvent("StationCraft", craft)
	Net.onEvent("StationSalvage", salvage)
	Net.onEvent("StationCollect", collect)
	Net.onEvent("StationCancel", cancel)
	Net.onEvent("StationFuel", fuel)
	Net.onEvent("StationUpgrade", upgrade)
	Net.onEvent("HandCraft", handCraft)
end

function Stations.start()
	Sync.provide("stations", function(player: Player)
		local data = PlayerData.get(player)
		return if data then data.stations else false
	end)
	-- Ready badges and fires follow the clock; refresh station models each second.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				if data and Plots.of(player) then
					for uid in data.stations do
						updateModel(player, uid)
					end
				end
			end
		end
	end)
end

return Stations
