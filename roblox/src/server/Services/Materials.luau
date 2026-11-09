--!strict
--[[
	Materials: the home material pool (PLAYER_EXPERIENCE_CHECKLIST 5.13). At home,
	building, crafting and station jobs take materials from pockets, then backpack,
	then every home storage crate, then the inbox, all or nothing (Domain/MaterialPool).
	Have/need counts on the client add the same sources up (the "pool" sync section).
	On Fog Runs only what the player carries counts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local InboxMath = require(ReplicatedStorage.Shared.Domain.Inbox)
local MaterialPool = require(ReplicatedStorage.Shared.Domain.MaterialPool)
local OnRun = require("../OnRun")
local Analytics = require("./Analytics")
local Inbox = require("./Inbox")
local Inventory = require("./Inventory")
local PlayerData = require("./PlayerData")
local Plots = require("./Plots")
local Sync = require("./Sync")

local Materials = {}

-- Home is anywhere but a Fog Run: not a run server or a Studio-simulated lobby (OnRun,
-- the flow review's F-03), nor a place that sets the FogRun Workspace attribute.
function Materials.atHome(player: Player): boolean
	return workspace:GetAttribute("FogRun") ~= true and not OnRun.is(player)
end

local function crateKeys(data: any): { string }
	local keys = {}
	for uid in data.storage do
		table.insert(keys, uid)
	end
	table.sort(keys, function(a: string, b: string)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return keys
end

-- The sources in draw order.
function Materials.sources(player: Player): { MaterialPool.Source }
	local data = PlayerData.get(player)
	if data == nil then
		return {}
	end
	local sources: { MaterialPool.Source } = {
		{ key = "pockets", slots = data.inventory.pockets },
		{ key = "backpack", slots = data.inventory.backpack },
	}
	if Materials.atHome(player) then
		for _, uid in crateKeys(data) do
			table.insert(sources, { key = `crate:{uid}`, slots = data.storage[uid] })
		end
		table.insert(sources, { key = "inbox", slots = InboxMath.asSlots(data.inbox) })
	end
	return sources
end

--[[
	The carried inventory with one extra backpack slot per item held in crates and the
	inbox, so the shared domain checks (BuildRules, Crafting.check) count the whole
	pool without knowing about it. Only for checks: never commit it.
]]
function Materials.virtual(player: Player): Types.Inventory?
	local view = Inventory.view(player)
	if view == nil then
		return nil
	end
	local extra: { [string]: number } = {}
	for _, source in Materials.sources(player) do
		if source.key ~= "pockets" and source.key ~= "backpack" then
			for _, slot in source.slots do
				if slot.count > 0 then
					extra[slot.itemId] = (extra[slot.itemId] or 0) + slot.count
				end
			end
		end
	end
	local backpack = table.clone(view.backpack)
	for itemId, count in extra do
		table.insert(backpack, { itemId = itemId, count = count })
	end
	return { pockets = view.pockets, backpack = backpack }
end

-- What the client adds to its carried counts: units per item in crates (at home).
function Materials.crateTotals(player: Player): { [string]: number }
	local totals: { [string]: number } = {}
	for _, source in Materials.sources(player) do
		if string.sub(source.key, 1, 6) == "crate:" then
			for _, slot in source.slots do
				if slot.count > 0 then
					totals[slot.itemId] = (totals[slot.itemId] or 0) + slot.count
				end
			end
		end
	end
	return totals
end

--[[
	Takes every stack from the pool, all or nothing. Returns true when taken, or
	false and the first short stack (how many are missing).
]]
function Materials.take(player: Player, stacks: { Types.ItemStack }, sink: string?): (boolean, Types.ItemStack?)
	local data = PlayerData.get(player)
	if data == nil then
		return false, nil
	end
	local sources = Materials.sources(player)
	local changed, short = MaterialPool.take(sources, stacks)
	if changed == nil then
		return false, short
	end
	if changed.pockets or changed.backpack then
		Inventory.commit(player, {
			pockets = (changed.pockets or data.inventory.pockets) :: any,
			backpack = (changed.backpack or data.inventory.backpack) :: any,
		})
	end
	local cratesChanged = false
	for key, slots in changed do
		if string.sub(key, 1, 6) == "crate:" then
			data.storage[string.sub(key, 7)] = slots
			Plots.setCrateIcon(player, string.sub(key, 7), slots)
			cratesChanged = true
		end
	end
	if cratesChanged then
		Sync.mark(player, "storage")
		Sync.mark(player, "pool")
	end
	if changed.inbox then
		Inbox.set(player, InboxMath.fromSlots(data.inbox, changed.inbox))
	end
	if sink then
		for _, stack in stacks do
			Analytics.economy(player, "sink", stack.itemId, stack.count, 0, sink)
		end
	end
	return true, nil
end

function Materials.init()
	Sync.provide("pool", function(player: Player)
		return { home = Materials.atHome(player), crates = Materials.crateTotals(player) }
	end)
end

function Materials.start() end

return Materials
