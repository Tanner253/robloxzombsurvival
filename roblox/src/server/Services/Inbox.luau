--!strict
--[[
	Inbox: the item inbox (PLAYER_EXPERIENCE_CHECKLIST 4.15). Level-up, quest,
	purchase and event rewards, and anything granted that doesn't fit the bag, land
	here instead of being lost or dropped. No capacity limit; it lives in the
	profile, so raids never touch it and nothing in it expires.

	Players take a row into the bag (TAKE), take everything (optionally one category),
	or use a consumable in place. Home building and crafting also draw from it
	(Services/Materials).

	Only at home (the flow review's F-04): on a Fog Run the inbox can't be taken from or
	eaten from (OnRun), so it is never a death-proof stash mid-run. Grants still land in it
	there (a level-up, a quest reward), to be picked up at home.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Types = require(ReplicatedStorage.Shared.Types)
local HoldRules = require(ReplicatedStorage.Shared.Domain.HoldRules)
local InboxMath = require(ReplicatedStorage.Shared.Domain.Inbox)
local Events = require("../Events")
local Net = require("../Net")
local OnRun = require("../OnRun")
local Analytics = require("./Analytics")
local Inventory = require("./Inventory")
local PlayerData = require("./PlayerData")
local Survival = require("./Survival")
local Sync = require("./Sync")

local Inbox = {}

local Items = Content.Items

local function changed(player: Player)
	Sync.mark(player, "inbox")
end

--[[
	Puts stacks or slots in the player's inbox from `source` ("LevelUp", "Quest",
	"Purchase", "Event", "Overflow", ...) and tells them. Never fails for a loaded
	profile; returns false only when the profile isn't loaded.
]]
function Inbox.grant(player: Player, slots: { Types.Slot }, source: string, quiet: boolean?): boolean
	local data = PlayerData.get(player)
	if data == nil then
		return false
	end
	local count = 0
	for _, slot in slots do
		count += if slot.count > 0 then 1 else 0
	end
	if count == 0 then
		return true
	end
	data.inbox, data.inboxSeq = InboxMath.add(data.inbox, data.inboxSeq, slots, source, os.time())
	changed(player)
	if not quiet then
		Sync.fx(player, "inbox", { source = source, items = slots })
	end
	return true
end

-- The rows as they are now (for Services/Materials).
function Inbox.entries(player: Player): { Types.InboxEntry }
	local data = PlayerData.get(player)
	return if data then data.inbox else {}
end

-- Replaces the rows (Services/Materials after a draw).
function Inbox.set(player: Player, entries: { Types.InboxEntry })
	local data = PlayerData.get(player)
	if data then
		data.inbox = entries
		changed(player)
	end
end

-- Moves one row into the bag as far as it fits; the rest stays in the row.
local function takeRow(player: Player, id: string): (boolean, boolean)
	local data = PlayerData.get(player)
	local index = data and InboxMath.indexOf(data.inbox, id)
	if data == nil or index == nil then
		return false, false
	end
	local entry = data.inbox[index]
	local given, leftover =
		Inventory.giveSlots(player, { { itemId = entry.itemId, count = entry.count, durability = entry.durability } })
	local moved = if given[1] then given[1].count else 0
	local left = if leftover[1] then leftover[1].count else 0
	if moved > 0 then
		data.inbox = InboxMath.withCount(data.inbox, id, left)
		Analytics.economy(player, "source", entry.itemId, moved, 0, `Inbox{entry.source}`)
	end
	return moved > 0, left > 0
end

-- Whether the inbox can be used now; tells the player why not on a run.
local function usable(player: Player): boolean
	if OnRun.is(player) then
		Sync.notice(player, OnRun.INBOX_NOTICE, "warn")
		return false
	end
	return true
end

local function take(player: Player, id: string)
	if not usable(player) then
		return
	end
	local moved, short = takeRow(player, id)
	if moved then
		changed(player)
		Sync.fx(player, "items", { items = {}, source = "inbox" })
	end
	if short then
		Sync.notice(player, "Your bag is full. The rest waits in the inbox.")
	end
end

local function takeAll(player: Player, category: string?)
	local data = PlayerData.get(player)
	if data == nil or not usable(player) then
		return
	end
	local anyMoved, anyShort = false, false
	for _, entry in table.clone(data.inbox) do
		local def = Items[entry.itemId]
		if category == nil or category == "all" or (def and def.category == category) then
			local moved, short = takeRow(player, entry.id)
			anyMoved = anyMoved or moved
			anyShort = anyShort or short or not moved
		end
	end
	if anyMoved then
		changed(player)
	end
	if anyShort then
		Sync.notice(player, "Your bag is full. The rest waits in the inbox.")
	end
end

-- Eats or drinks one unit straight from the inbox.
local function use(player: Player, id: string)
	local data = PlayerData.get(player)
	local index = data and InboxMath.indexOf(data.inbox, id)
	if data == nil or index == nil or not usable(player) then
		return
	end
	local entry = data.inbox[index]
	local def = Items[entry.itemId]
	if def == nil or def.consume == nil or not Survival.canConsume(player, def.consume) then
		return
	end
	data.inbox = InboxMath.withCount(data.inbox, id, entry.count - 1)
	changed(player)
	Survival.consume(player, def.consume)
	local action = HoldRules.consumeAction(def.consume)
	Net.fireAllClients("Fx", "act", { userId = player.UserId, action = action })
	Analytics.economy(player, "sink", entry.itemId, 1, 0, "Consume")
	Sync.fx(player, "consumed", { itemId = entry.itemId })
	-- Counts for quests like eating from the bag does (the flow review's F-22: water drunk
	-- from the inbox didn't count for Keep the Fire).
	Events.played:Fire(player, { kind = "consume", itemId = entry.itemId, count = 1 })
end

function Inbox.init()
	Sync.provide("inbox", function(player: Player)
		local data = PlayerData.get(player)
		return if data then data.inbox else false
	end)
	Net.onEvent("InboxTake", take)
	Net.onEvent("InboxTakeAll", takeAll)
	Net.onEvent("InboxUse", use)
end

function Inbox.start() end

return Inbox
