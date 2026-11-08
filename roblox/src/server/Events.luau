--!strict
--[[
	Events: gameplay signals that several services report and one listens to, kept in a
	module with no service dependencies so reporting never creates a require cycle
	(Inventory -> Quests -> Progression -> Inbox -> Inventory would).

	- played (player, event): something counted toward Ember Trail objectives happened
	  (a Domain/Quests.Event: gather, craft, build, consume, kill, loot, travel...).
	- factsChanged (player): what the player wears or their level changed, so state
	  objectives (equip, reachLevel) are re-checked.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local Events = {}

Events.played = Signal.new()
Events.factsChanged = Signal.new()

return Events
