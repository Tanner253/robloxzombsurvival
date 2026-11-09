--!strict
--[[
	Embers: the premium currency (MVP_LAUNCH Monetization v0.1). Bought in the shop (the Ember
	Pouch and Chest, the Firestarter Kit); spent on Fill Up, speed-ups, Trail Rations and
	Recover all (Tuning.embers). The balance is in the profile and never raidable.

	The "wallet" section syncs the balance; the inventory header shows it with a "+" that
	opens the shop's Embers tab.
]]

local Analytics = require("./Analytics")
local PlayerData = require("./PlayerData")
local Sync = require("./Sync")

local Embers = {}

function Embers.balance(player: Player): number
	local data = PlayerData.get(player)
	return if data then data.embers else 0
end

-- Adds Embers (a purchase or a reward); `source` names the analytics transaction.
function Embers.grant(player: Player, amount: number, source: string)
	local data = PlayerData.get(player)
	if data == nil or amount <= 0 then
		return
	end
	data.embers += math.floor(amount)
	Analytics.economy(player, "source", "Embers", math.floor(amount), data.embers, source)
	Sync.mark(player, "wallet")
end

-- Spends Embers for `sink`; false (and nothing spent) when the balance is short.
function Embers.spend(player: Player, amount: number, sink: string): boolean
	local data = PlayerData.get(player)
	if data == nil or amount <= 0 or data.embers < amount then
		return false
	end
	data.embers -= amount
	Analytics.economy(player, "sink", "Embers", amount, data.embers, sink)
	Sync.mark(player, "wallet")
	return true
end

-- Tells the player what they're short and opens the shop's Embers tab on their screen.
function Embers.short(player: Player, need: number)
	Sync.notice(player, `You need {need} Embers`, "warn")
	Sync.fx(player, "needEmbers", { need = need, have = Embers.balance(player) })
end

function Embers.start()
	Sync.provide("wallet", function(player: Player)
		local data = PlayerData.get(player)
		return if data then { embers = data.embers } else false
	end)
	PlayerData.loaded:Connect(function(player: Player)
		Sync.mark(player, "wallet")
	end)
end

return Embers
