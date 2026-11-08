--!strict
--[[
	Stations: LDoE converter stations and hand crafting (Domain/Converter, Domain/Crafting;
	LDOE_PARITY #18-23).

	A placed station's state lives in the profile (PlayerSchema.StationState, keyed by the
	piece's UID) as a timestamped converter, so it keeps converting while the player is
	offline and simply catches up when it is next read. The Building service creates and
	removes station records; this service runs them:
	- drag a stack from the inventory into the input (StationPutInput) or the fuel slot
	  (StationPutFuel); take the input, fuel or output back out; upgrade in place (paid
	  from the home pool, checklist 5.13);
	- hand crafting (gear, tools, bags, food mixes) from the catalogue (HandCraft).

	Station models get attributes for the client: Level, Ready (items waiting in the
	output, the teal badge #23), Working (converting now), Burning (fuel lit), and the
	batch in progress (BatchProgress 0..1, BatchRemaining seconds, BatchItem).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Types = require(ReplicatedStorage.Shared.Types)
local Domain = ReplicatedStorage.Shared.Domain
local Converter = require(Domain.Converter)
local Crafting = require(Domain.Crafting)
local Rng = require(Domain.Rng)
local Net = require("../Net")
local Events = require("../Events")
local Analytics = require("./Analytics")
local Inbox = require("./Inbox")
local Inventory = require("./Inventory")
local Materials = require("./Materials")
local PlayerData = require("./PlayerData")
local Plots = require("./Plots")
local Quests = require("./Quests")
local Sync = require("./Sync")

local Stations = {}

-- Content.Items as the narrower lookup types the Domain modules take (tables are invariant).
local Items: any = Content.Items
local Recipes = Content.Recipes
local tuning = Content.Tuning

local REASON_TEXT: { [string]: string } = {
	locked = "Not unlocked yet",
	wrongStation = "Make that at its station",
	stationLevel = "Upgrade this station first",
	missingInputs = "Not enough materials",
	inventoryFull = "Make room in your bag",
	notConvertible = "This station can't use that",
	inputBusy = "Take the current input out first",
	inputFull = "The input slot is full",
	notFuel = "That won't burn",
	noFuelSlot = "This station doesn't burn fuel",
	fuelBusy = "Burn the current fuel first, or take it out",
	fuelFull = "The fuel slot is full",
	busy = "Let it finish, or take the input out, before upgrading",
	maxLevel = "Already at the top level",
	empty = "Nothing to take",
}

local rng = Rng.new(Random.new():NextInteger(1, 2 ^ 31 - 2))

local function context(def: Types.StationDef): Converter.Context
	return {
		def = def,
		recipes = Recipes,
		items = Items,
		rng = rng,
		scalesChance = tuning.salvage.durabilityScalesChance,
	}
end

-- Station records ------------------------------------------------------------------------------

-- Creates the record for a newly placed station.
function Stations.create(player: Player, uid: string, stationId: Types.StationId)
	local data = PlayerData.get(player)
	local def = Content.Stations[stationId]
	if data and def and data.stations[uid] == nil then
		data.stations[uid] = Converter.new(def, os.time())
		Sync.mark(player, "stations")
	end
end

-- Whether a station holds anything (it can't be demolished then: take it out first).
function Stations.isBusy(player: Player, uid: string): boolean
	local data = PlayerData.get(player)
	local station = data and data.stations[uid]
	return station ~= nil and not Converter.isEmpty(station)
end

-- Removes a demolished station's record.
function Stations.remove(player: Player, uid: string)
	local data = PlayerData.get(player)
	if data and data.stations[uid] then
		data.stations[uid] = nil
		Sync.mark(player, "stations")
	end
end

-- Brings a station up to now (catching up offline time) and returns it.
local function current(data: any, uid: string): Converter.State?
	local station = data.stations[uid]
	local def = station and Content.Stations[station.stationId]
	if station == nil or def == nil then
		return nil
	end
	local now = os.time()
	if station.at <= 0 then
		station.at = now -- migrated or freshly loaded: the clock starts now
	end
	local advanced = Converter.advance(station, context(def), now)
	data.stations[uid] = advanced
	return advanced
end

local function updateModel(player: Player, uid: string)
	local plot = Plots.of(player)
	local data = PlayerData.get(player)
	local model = plot and plot.pieceModels[uid]
	local station = data and current(data, uid)
	if model == nil or station == nil then
		return
	end
	local def = Content.Stations[station.stationId]
	local status = Converter.status(station, context(def))
	local working = status.activity == "working"
	model:SetAttribute("Level", station.level)
	model:SetAttribute("Ready", status.ready)
	model:SetAttribute("Working", working)
	model:SetAttribute("Burning", working and def.fuel ~= nil)
	model:SetAttribute("BatchProgress", if working then status.progress else nil)
	model:SetAttribute("BatchRemaining", if working then status.batchRemaining else nil)
	model:SetAttribute("BatchItem", if status.line then status.line.outputs[1].itemId else nil)
end

-- Refreshes a station's model attributes and the player's synced stations.
function Stations.refresh(player: Player, uid: string)
	updateModel(player, uid)
	Sync.mark(player, "stations")
end

-- Request helpers --------------------------------------------------------------------------------

type Context = {
	data: any,
	station: Converter.State,
	def: Types.StationDef,
	ctx: Converter.Context,
}

local function open(player: Player, uid: string): Context?
	local data = PlayerData.get(player)
	local station = data and current(data, uid)
	if data == nil or station == nil then
		return nil
	end
	local position = Plots.piecePosition(player, uid)
	if position == nil or not Plots.withinArm(player, position, Plots.pieceRadius(player, uid)) then
		Sync.notice(player, "Move closer to the station")
		return nil
	end
	local def = Content.Stations[station.stationId]
	return { data = data, station = station, def = def, ctx = context(def) }
end

local function refuse(player: Player, reason: string?)
	Sync.notice(player, REASON_TEXT[reason or ""] or "Can't do that")
	Sync.fx(player, "denied", { reason = reason })
end

local function save(player: Player, c: Context, uid: string, station: Converter.State)
	c.data.stations[uid] = station
	Stations.refresh(player, uid)
end

-- Gives taken slots back to the bag; returns what didn't fit.
local function giveBack(player: Player, slots: { Types.Slot }): { Types.Slot }
	local _, leftover = Inventory.giveSlots(player, slots)
	return leftover
end

-- Handlers: the converter ------------------------------------------------------------------------

-- (uid, ref, index, count?) drags up to `count` of a carried stack into the input.
local function putInput(player: Player, uid: string, ref: string, index: number, count: number?)
	local c = open(player, uid)
	local slot = Inventory.peekSlot(player, ref, index)
	if c == nil or slot == nil or slot.count <= 0 then
		return
	end
	local offered =
		{ itemId = slot.itemId, count = math.min(count or slot.count, slot.count), durability = slot.durability }
	local station, accepted, reason = Converter.putInput(c.station, c.ctx, Quests.progress(c.data), offered, os.time())
	if station == nil or accepted <= 0 then
		refuse(player, reason)
		return
	end
	if Inventory.takeFromSlot(player, ref, index, accepted) == nil then
		return
	end
	save(player, c, uid, station)
	Analytics.economy(player, "sink", slot.itemId, accepted, 0, "Station")
	Sync.fx(player, "stationInput", { uid = uid, itemId = slot.itemId, count = accepted })
end

-- (uid, ref, index, count?) drags fuel into the fuel slot.
local function putFuel(player: Player, uid: string, ref: string, index: number, count: number?)
	local c = open(player, uid)
	local slot = Inventory.peekSlot(player, ref, index)
	if c == nil or slot == nil or slot.count <= 0 then
		return
	end
	local amount = math.min(count or slot.count, slot.count)
	local station, accepted, reason = Converter.putFuel(c.station, c.ctx, slot.itemId, amount, os.time())
	if station == nil or accepted <= 0 then
		refuse(player, reason)
		return
	end
	if Inventory.takeFromSlot(player, ref, index, accepted) == nil then
		return
	end
	save(player, c, uid, station)
	Analytics.economy(player, "sink", slot.itemId, accepted, 0, "Fuel")
	Sync.fx(player, "fuelled", { uid = uid, itemId = slot.itemId, count = accepted })
end

-- (uid) takes the whole input back out (the batch in progress is lost).
local function takeInput(player: Player, uid: string)
	local c = open(player, uid)
	if c == nil then
		return
	end
	local station, slot = Converter.takeInput(c.station, c.ctx, nil, os.time())
	if slot.count <= 0 then
		return
	end
	local leftover = giveBack(player, { slot })
	if #leftover > 0 then
		-- What didn't fit goes back in, so nothing is lost.
		station = (Converter.putInput(station, c.ctx, Quests.progress(c.data), leftover[1], os.time()) or station)
		Sync.notice(player, REASON_TEXT.inventoryFull)
	end
	save(player, c, uid, station)
end

-- (uid) takes the unlit fuel back out.
local function takeFuel(player: Player, uid: string)
	local c = open(player, uid)
	if c == nil then
		return
	end
	local station, slot = Converter.takeFuel(c.station, c.ctx, nil, os.time())
	if slot.count <= 0 then
		return
	end
	local leftover = giveBack(player, { slot })
	if #leftover > 0 then
		station = (Converter.putFuel(station, c.ctx, slot.itemId, leftover[1].count, os.time()) or station)
		Sync.notice(player, REASON_TEXT.inventoryFull)
	end
	save(player, c, uid, station)
end

-- (uid, index) takes output slot `index` (0: every output slot) into the bag, as much as fits.
local function takeOutput(player: Player, uid: string, index: number)
	local c = open(player, uid)
	if c == nil then
		return
	end
	local now = os.time()
	local station = c.station
	local taken: { Types.Slot } = {}
	local first, last = index, index
	if index == 0 then
		first, last = 1, #station.output
	end
	local full = false
	for slotIndex = first, last do
		local slot = station.output[slotIndex]
		if slot and slot.count > 0 then
			local nextStation, out = Converter.takeOutput(station, c.ctx, slotIndex, nil, now)
			local given, leftover = Inventory.giveSlots(player, { out })
			station = nextStation
			if #leftover > 0 then
				-- Put back what didn't fit, in the same slot.
				station.output[slotIndex] = {
					itemId = out.itemId,
					count = leftover[1].count,
					durability = out.durability,
				}
				full = true
			end
			for _, slotGiven in given do
				table.insert(taken, slotGiven)
			end
		end
	end
	if #taken == 0 then
		if full then
			refuse(player, "inventoryFull")
		end
		return
	end
	save(player, c, uid, station)
	if full then
		Sync.notice(player, REASON_TEXT.inventoryFull)
	end
	-- Quest progress: batches of each converter line taken.
	for _, slot in taken do
		Analytics.economy(player, "source", slot.itemId, slot.count, 0, "Station")
		for _, line in Converter.lines(c.def, Recipes) do
			if line.recipeId and line.outputs[1].itemId == slot.itemId then
				local batches = math.max(1, slot.count // line.outputs[1].count)
				Events.played:Fire(player, { kind = "craft", recipeId = line.recipeId, count = batches })
			end
		end
	end
	Sync.fx(player, "items", { items = taken, source = "station", uid = uid })
end

local function upgrade(player: Player, uid: string)
	local c = open(player, uid)
	if c == nil then
		return
	end
	local nextLevel = Converter.nextLevel(c.def, c.station.level)
	local station, reason = Converter.upgrade(c.station, c.ctx, os.time())
	if station == nil or nextLevel == nil then
		refuse(player, reason)
		return
	end
	-- Paid from the whole home pool (5.13).
	if not Materials.take(player, nextLevel.upgradeCost, "StationUpgrade") then
		refuse(player, "missingInputs")
		return
	end
	save(player, c, uid, station)
	Analytics.progression(player, c.def.id, "complete", station.level)
	Sync.fx(player, "stationUpgraded", { uid = uid, level = station.level })
end

-- Handlers: the crafting catalogue -----------------------------------------------------------------

local function handCraft(player: Player, recipeId: string, count: number)
	local data = PlayerData.get(player)
	local recipe = Recipes[recipeId]
	if data == nil or recipe == nil then
		return
	end
	-- Inputs come from the home pool (5.13); what doesn't fit the bag goes to the inbox.
	local pool = Materials.virtual(player) :: Types.Inventory
	local ok, reason = Crafting.check(recipe, pool, Quests.progress(data), count)
	if not ok then
		refuse(player, reason)
		return
	end
	local inputs: { Types.ItemStack } = {}
	for _, stack in recipe.inputs do
		table.insert(inputs, { itemId = stack.itemId, count = stack.count * count })
	end
	if not Materials.take(player, inputs, "Crafting") then
		refuse(player, "missingInputs")
		return
	end
	local made: { Types.ItemStack } = {}
	for _, stack in recipe.outputs do
		table.insert(made, { itemId = stack.itemId, count = stack.count * count })
	end
	local _, leftover = Inventory.give(player, made, "Crafting")
	Inbox.grant(player, leftover :: any, "Overflow")
	Analytics.custom(player, "HandCraft", count, { recipeId })
	Sync.fx(player, "items", { items = made, source = "craft" })
	Events.played:Fire(player, { kind = "craft", recipeId = recipeId, count = count })
end

-- The crafting catalogue's favourites and NEW marks (5.9).
local function favourite(player: Player, recipeId: string, on: boolean)
	local data = PlayerData.get(player)
	if data == nil or Recipes[recipeId] == nil then
		return
	end
	(data.recipeMarks.favourites :: any)[recipeId] = if on then true else nil
	Sync.mark(player, "recipeMarks")
end

local function seen(player: Player)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	local progress = Quests.progress(data)
	for id, recipe in Recipes do
		if Crafting.isUnlocked(recipe, progress) then
			data.recipeMarks.seen[id] = true
		end
	end
	Sync.mark(player, "recipeMarks")
end

-- Lifecycle -------------------------------------------------------------------------------------------

function Stations.init()
	Net.onEvent("StationPutInput", putInput)
	Net.onEvent("StationPutFuel", putFuel)
	Net.onEvent("StationTakeInput", takeInput)
	Net.onEvent("StationTakeFuel", takeFuel)
	Net.onEvent("StationTakeOutput", takeOutput)
	Net.onEvent("StationUpgrade", upgrade)
	Net.onEvent("HandCraft", handCraft)
	Net.onEvent("RecipeFavourite", favourite)
	Net.onEvent("RecipesSeen", seen)
	Sync.provide("recipeMarks", function(player: Player)
		local data = PlayerData.get(player)
		return if data then data.recipeMarks else false
	end)
end

function Stations.start()
	Sync.provide("stations", function(player: Player)
		local data = PlayerData.get(player)
		return if data then data.stations else false
	end)
	-- Ready badges, fires and batch bars follow the clock: refresh station models each
	-- second. The synced section is re-sent only when something visibly changed.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				if data and Plots.of(player) then
					local changed = false
					for uid, before in data.stations do
						local ready, input = Converter.ready(before), before.input.count
						updateModel(player, uid)
						local after = data.stations[uid]
						if after and (Converter.ready(after) ~= ready or after.input.count ~= input) then
							changed = true
						end
					end
					if changed then
						Sync.mark(player, "stations")
					end
				end
			end
		end
	end)
end

return Stations
