--!strict
--[[
	questText: one line per Ember Trail objective, for the tracker and the quest screen
	("Build a Saw Bench", "Search containers in Pine Hollow"; Domain/QuestText), and the tracker's
	rows from the synced quest state (Domain/Quests.tracker).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Flags = require(ReplicatedStorage.Shared.Flags)
local QuestText = require(ReplicatedStorage.Shared.Domain.QuestText)
local Quests = require(ReplicatedStorage.Shared.Domain.Quests)

local questText = {}

-- One line per objective, saying where (Domain/QuestText, the flow review's F-22).
function questText.objective(objective: any): string
	return QuestText.objective(objective, Content :: any)
end

-- The tracker rows (up to `limit`) for the synced quest state, or {} before it arrives.
function questText.rows(state: any, limit: number?): { Quests.Row }
	if type(state) ~= "table" then
		return {}
	end
	return Quests.tracker(state, Content.Quests, Flags.snapshot(), limit)
end

return questText
