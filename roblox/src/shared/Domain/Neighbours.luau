--!strict
--[[
	Neighbours: other players' outposts as markers on the Fog map, and who may be
	raided (GAME_DESIGN "The Fog map: neighbours, raids, guilds"). Raids are M2; v0.1
	ships this model and its rules, plus the map's neighbours layer, with nothing
	feeding it yet. M2 fills the list from a MemoryStore index of bases by region and
	power band, and the State section "neighbours" carries it to the map.

	A marker shows Hearth level and defense rating, an estimated loot tier ("smoke from
	the chimneys"), online, offline or shielded with the shield's timer, the guild tag,
	and when the outpost was last raided.
]]

local Neighbours = {}

export type Status = "online" | "offline" | "shielded"
export type LootTier = "low" | "medium" | "high"
export type Refusal = "self" | "band" | "protected" | "shielded"

export type Neighbour = {
	userId: number,
	name: string,
	hearthLevel: number,
	defense: number, -- defense rating
	stockValue: number, -- what raidable storage holds (sets the loot tier)
	online: boolean,
	createdAt: number, -- when the outpost was founded (new-player protection)
	shieldUntil: number?, -- unix seconds
	guildTag: string?,
	lastRaidedAt: number?,
}

export type Raider = { userId: number, hearthLevel: number }

export type Rules = {
	band: number, -- a raider picks targets within this many Hearth levels
	protectLevel: number, -- outposts below this Hearth level can't be raided...
	protectSeconds: number, -- ...nor for this long after founding
	lootTiers: { medium: number, high: number }, -- stock value thresholds
	raidShare: number, -- the most one raid takes of raidable storage
}

-- GAME_DESIGN's v1 rules: ±2 Hearth levels, new players safe to Hearth 3 or 3 days,
-- a raid takes up to about 40% of raidable storage.
Neighbours.RULES = {
	band = 2,
	protectLevel = 3,
	protectSeconds = 3 * 24 * 60 * 60,
	lootTiers = { medium = 400, high = 1500 },
	raidShare = 0.4,
} :: Rules

-- Online, offline or shielded, and the seconds left on a shield.
function Neighbours.status(neighbour: Neighbour, now: number): (Status, number?)
	local shield = neighbour.shieldUntil
	if shield and shield > now then
		return "shielded", shield - now
	end
	return if neighbour.online then "online" else "offline", nil
end

-- The estimated loot tier the marker shows ("smoke from the chimneys").
function Neighbours.lootTier(stockValue: number, rules: Rules): LootTier
	if stockValue >= rules.lootTiers.high then
		return "high"
	elseif stockValue >= rules.lootTiers.medium then
		return "medium"
	end
	return "low"
end

function Neighbours.inBand(myLevel: number, theirLevel: number, rules: Rules): boolean
	return math.abs(myLevel - theirLevel) <= rules.band
end

-- Whether a new outpost is still protected (by Hearth level or by age).
function Neighbours.protected(neighbour: Neighbour, now: number, rules: Rules): boolean
	return neighbour.hearthLevel < rules.protectLevel or now - neighbour.createdAt < rules.protectSeconds
end

-- Whether `raider` may raid `target` now, or why not.
function Neighbours.canRaid(raider: Raider, target: Neighbour, now: number, rules: Rules): (boolean, Refusal?)
	if raider.userId == target.userId then
		return false, "self"
	elseif Neighbours.protected(target, now, rules) then
		return false, "protected"
	elseif Neighbours.status(target, now) == "shielded" then
		return false, "shielded"
	elseif not Neighbours.inBand(raider.hearthLevel, target.hearthLevel, rules) then
		return false, "band"
	end
	return true, nil
end

-- The most one raid can take from raidable storage worth `stockValue`.
function Neighbours.raidCap(stockValue: number, rules: Rules): number
	return math.floor(math.max(0, stockValue) * rules.raidShare)
end

--[[
	The markers to show `me`: everyone else, those in my band first, then the nearest in
	Hearth level, then by user id (stable), at most `limit`.
]]
function Neighbours.shown(list: { Neighbour }, me: Raider, rules: Rules, limit: number): { Neighbour }
	local others: { Neighbour } = {}
	for _, neighbour in list do
		if neighbour.userId ~= me.userId then
			table.insert(others, neighbour)
		end
	end
	table.sort(others, function(a: Neighbour, b: Neighbour): boolean
		local aBand = Neighbours.inBand(me.hearthLevel, a.hearthLevel, rules)
		local bBand = Neighbours.inBand(me.hearthLevel, b.hearthLevel, rules)
		if aBand ~= bBand then
			return aBand
		end
		local aGap = math.abs(a.hearthLevel - me.hearthLevel)
		local bGap = math.abs(b.hearthLevel - me.hearthLevel)
		if aGap ~= bGap then
			return aGap < bGap
		end
		return a.userId < b.userId
	end)
	local shown: { Neighbour } = {}
	for index = 1, math.min(limit, #others) do
		shown[index] = others[index]
	end
	return shown
end

--[[
	Which of `count` map slots each shown neighbour takes: the same slot every time for
	the same player (a hash of the user id), moving on to the next free one when two
	collide. Returns slot indexes in the order of `shown`.
]]
function Neighbours.slots(shown: { Neighbour }, count: number): { number }
	local taken: { [number]: boolean } = {}
	local result: { number } = {}
	for index, neighbour in shown do
		if index > count then
			break
		end
		-- Multiplicative hashing: the product's high bits pick the slot (the low bits
		-- would just follow the id's own low bits). The id is reduced first so the
		-- product stays an exact integer in a double.
		local mixed = ((math.abs(neighbour.userId) % 1000003) * 2654435761) % 4294967296
		local slot = math.floor(mixed / 4294967296 * count) + 1
		while taken[slot] do
			slot = slot % count + 1
		end
		taken[slot] = true
		result[index] = slot
	end
	return result
end

return Neighbours
