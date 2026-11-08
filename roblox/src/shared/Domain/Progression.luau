--!strict
--[[
	Progression: player XP and levels (Data/Levels). Pure.

	`xp` is the lifetime total; a level is reached when xp >= its Levels entry's
	xp. The last entry is the level cap: XP keeps counting but no level follows.
]]

local Types = require("../Types")

local Progression = {}

export type State = { level: number, xp: number }
export type Levels = { Types.PlayerLevelDef }

-- The level a lifetime XP total reaches.
function Progression.levelFor(xp: number, levels: Levels): number
	local level = 1
	for _, def in levels do
		if xp >= def.xp then
			level = math.max(level, def.level)
		end
	end
	return level
end

--[[
	Adds XP. Returns the new state and the level definitions newly reached, in
	order (empty when no level-up), so the caller can grant their rewards.
]]
function Progression.addXp(state: State, amount: number, levels: Levels): (State, { Types.PlayerLevelDef })
	assert(amount >= 0 and amount % 1 == 0, "amount must be a non-negative integer")
	local xp = state.xp + amount
	local level = Progression.levelFor(xp, levels)
	local reached: { Types.PlayerLevelDef } = {}
	for _, def in levels do
		if def.level > state.level and def.level <= level then
			table.insert(reached, def)
		end
	end
	return { level = math.max(level, state.level), xp = xp }, reached
end

--[[
	Progress toward the next level: XP earned in this level, XP this level spans
	and the fraction 0..1. At the cap it returns (0, 0, 1).
]]
function Progression.progress(state: State, levels: Levels): (number, number, number)
	local current = levels[state.level]
	local nextDef = levels[state.level + 1]
	if current == nil or nextDef == nil then
		return 0, 0, 1
	end
	local span = nextDef.xp - current.xp
	local into = math.clamp(state.xp - current.xp, 0, span)
	return into, span, if span > 0 then into / span else 1
end

return Progression
