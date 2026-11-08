--!strict
--[[
	Unlocks: whether an UnlockGate is met, and the lock text that names it (LDOE_PARITY #49).
	Pure. Crafting (recipes), BuildRules (pieces), the catalogue and the build tray all ask
	here, so a gate reads the same everywhere.

	Gates: "default" is always met; "quest" once that Ember Trail quest is complete;
	"blueprint" once that schematic has been read; "level" once the player reaches it
	(locations only: recipes and pieces never use level gates).
]]

local Types = require("../Types")

local Unlocks = {}

-- The parts of PlayerData that meet gates. `quests` is PlayerData.quests (only
-- `completed` is read); nil counts as nothing completed.
export type Progress = {
	level: number,
	unlocks: { recipes: { [string]: boolean }, blueprints: { [string]: boolean } },
	quests: { completed: { [string]: number } }?,
}

-- The names lock text needs; Data/Items and Data/Quests satisfy these.
export type Names = {
	items: { [string]: { name: string } },
	quests: { [string]: { name: string } },
}

function Unlocks.isMet(gate: Types.UnlockGate?, progress: Progress): boolean
	if gate == nil or gate.kind == "default" then
		return true
	elseif gate.kind == "level" then
		return progress.level >= gate.level
	elseif gate.kind == "quest" then
		local quests = progress.quests
		return quests ~= nil and quests.completed[gate.questId] ~= nil
	end
	return progress.unlocks.blueprints[gate.itemId] == true
end

-- "Complete the 'Keep the Fire' quest", "Read the Pack Frame Schematic", "Reach level 4";
-- nil for a gate that is always met.
function Unlocks.text(gate: Types.UnlockGate?, names: Names): string?
	if gate == nil or gate.kind == "default" then
		return nil
	elseif gate.kind == "level" then
		return `Reach level {gate.level}`
	elseif gate.kind == "quest" then
		local quest = names.quests[gate.questId]
		return `Complete the '{if quest then quest.name else gate.questId}' quest`
	end
	local item = names.items[gate.itemId]
	return `Read the {if item then item.name else "schematic"}`
end

-- Every recipe and piece a quest unlocks, by id, sorted (the quest card's reward row and
-- the "new blueprints" pop when it completes).
function Unlocks.byQuest(
	questId: Types.QuestId,
	recipes: { [string]: { unlock: Types.UnlockGate } },
	pieces: { [string]: { unlock: Types.UnlockGate? } }
): ({ string }, { string })
	local recipeIds: { string } = {}
	local pieceIds: { string } = {}
	for id, recipe in recipes do
		local gate = recipe.unlock
		if gate.kind == "quest" and gate.questId == questId then
			table.insert(recipeIds, id)
		end
	end
	for id, piece in pieces do
		local gate = piece.unlock
		if gate and gate.kind == "quest" and gate.questId == questId then
			table.insert(pieceIds, id)
		end
	end
	table.sort(recipeIds)
	table.sort(pieceIds)
	return recipeIds, pieceIds
end

return Unlocks
