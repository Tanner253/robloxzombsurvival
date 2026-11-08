--!strict
--[[
	Loot: seeded loot-table rolls (ARCHITECTURE.md §5, LootTableDef).

	Opening a table:
	1. Adds every guaranteed stack.
	2. Picks `rolls.min..rolls.max` entries by weight (entries may repeat; weight
	   0 entries never drop). An item entry gives `min..max` units (0 is allowed,
	   meaning "nothing this time"). A nested entry (`tableId`) opens that table
	   `min..max` times.
	3. Optional pity: a table with `pity = { rarity, every }` guarantees that at
	   least one in every `every` opens of that table yields an item of that
	   rarity or better. Counters live per player in a PityState keyed by table
	   ID; when the counter says this open is the Nth, the first pick is drawn
	   only from qualifying entries. Any qualifying drop resets the counter.

	Item rarity comes from the entry's own `rarity` override, else the `items`
	lookup (Data/Items), else "common". A nested entry qualifies for a forced
	pity pick only with an explicit `rarity`.

	Extensions over Types.LootTableDef that the data layer may adopt (read here
	without changing Types): entry `tableId` (nested table, `itemId` unused),
	entry `rarity`, table `pity`. Pure: pass an Rng.Source and the pity state.
]]

local Types = require("../Types")
local Rng = require("./Rng")

local Loot = {}

local MAX_DEPTH = 8

export type Rarity = Types.Rarity

export type Pity = { rarity: Rarity, every: number }

-- The fields Loot reads from an entry: Types.LootEntry plus the extensions.
export type Entry = {
	itemId: string?,
	tableId: string?,
	weight: number,
	min: number,
	max: number,
	rarity: Rarity?,
}

export type PityState = { [string]: number } -- table ID -> opens since the last qualifying drop

export type RarityLookup = { [string]: { rarity: Rarity } }

export type Options = {
	items: RarityLookup?,
	pity: PityState?,
}

export type Result = {
	items: { Types.ItemStack }, -- merged by item, in first-drop order
	pity: PityState, -- the updated counters (a new table)
}

export type Tables = { [string]: Types.LootTableDef }

Loot.RARITY_RANK = {
	common = 1,
	uncommon = 2,
	rare = 3,
	epic = 4,
	legendary = 5,
} :: { [Rarity]: number }

type Drop = { itemId: string, count: number, rank: number }

local function entriesOf(def: Types.LootTableDef): { Entry }
	return def.entries :: any
end

local function pityOf(def: Types.LootTableDef): Pity?
	return (def :: any).pity
end

local function rankOfItem(itemId: string, override: Rarity?, items: RarityLookup?): number
	local rarity: Rarity = override or (items and items[itemId] and items[itemId].rarity) or "common"
	return Loot.RARITY_RANK[rarity]
end

-- Picks one entry by weight among those passing `accept` (all when nil).
local function pick(entries: { Entry }, rng: Rng.Source, accept: ((Entry) -> boolean)?): Entry?
	local total = 0
	local last: Entry? = nil
	for _, entry in entries do
		if entry.weight > 0 and (accept == nil or accept(entry)) then
			total += entry.weight
			last = entry
		end
	end
	if total <= 0 then
		return nil
	end
	local target = rng:NextNumber() * total
	for _, entry in entries do
		if entry.weight > 0 and (accept == nil or accept(entry)) then
			target -= entry.weight
			if target < 0 then
				return entry
			end
		end
	end
	return last -- floating-point edge
end

local function open(
	tables: Tables,
	tableId: string,
	rng: Rng.Source,
	options: Options,
	pity: PityState,
	depth: number
): { Drop }
	assert(depth <= MAX_DEPTH, `loot table '{tableId}' nests deeper than {MAX_DEPTH} (a cycle?)`)
	local def = tables[tableId]
	assert(def, `unknown loot table '{tableId}'`)
	local items = options.items
	local drops: { Drop } = {}

	for _, stack in def.guaranteed or {} do
		table.insert(drops, { itemId = stack.itemId, count = stack.count, rank = rankOfItem(stack.itemId, nil, items) })
	end

	local rule = pityOf(def)
	local forced = false
	local targetRank = 0
	if rule and options.pity then
		targetRank = Loot.RARITY_RANK[rule.rarity]
		forced = (pity[tableId] or 0) + 1 >= rule.every
	end

	local picks = rng:NextInteger(def.rolls.min, def.rolls.max)
	if forced then
		picks = math.max(picks, 1)
	end

	for index = 1, picks do
		local entry: Entry? = nil
		if forced and index == 1 then
			entry = pick(entriesOf(def), rng, function(candidate)
				if candidate.tableId then
					return candidate.rarity ~= nil and Loot.RARITY_RANK[candidate.rarity] >= targetRank
				end
				return rankOfItem(candidate.itemId :: string, candidate.rarity, items) >= targetRank
			end)
		end
		entry = entry or pick(entriesOf(def), rng, nil)
		if entry then
			local times = rng:NextInteger(entry.min, entry.max)
			if entry.tableId then
				for _ = 1, times do
					for _, drop in open(tables, entry.tableId, rng, options, pity, depth + 1) do
						table.insert(drops, drop)
					end
				end
			elseif times > 0 then
				local itemId = entry.itemId :: string
				table.insert(drops, { itemId = itemId, count = times, rank = rankOfItem(itemId, entry.rarity, items) })
			end
		end
	end

	if rule and options.pity then
		local hit = false
		for _, drop in drops do
			if drop.rank >= targetRank then
				hit = true
				break
			end
		end
		pity[tableId] = if hit then 0 else (pity[tableId] or 0) + 1
	end
	return drops
end

--[[
	Opens `tableId` once. Returns the merged item stacks and the updated pity
	counters; the input pity state is not modified.
]]
function Loot.roll(tables: Tables, tableId: string, rng: Rng.Source, options: Options?): Result
	local opts = options or {}
	local pity = table.clone(opts.pity or {})
	local drops = open(tables, tableId, rng, opts, pity, 1)

	local merged: { Types.ItemStack } = {}
	local indexOf: { [string]: number } = {}
	for _, drop in drops do
		local index = indexOf[drop.itemId]
		if index then
			merged[index].count += drop.count
		else
			table.insert(merged, { itemId = drop.itemId, count = drop.count })
			indexOf[drop.itemId] = #merged
		end
	end
	return { items = merged, pity = pity }
end

--[[
	The share of picks that land on each item, flattened through nested tables
	(a nested entry's share is split by that table's weights). Guaranteed items
	report 1. For the location panel's "main loot" and "possible loot" lists.
]]
function Loot.shares(tables: Tables, tableId: string): { [string]: number }
	local shares: { [string]: number } = {}
	local function visit(id: string, scale: number, depth: number)
		assert(depth <= MAX_DEPTH, `loot table '{id}' nests deeper than {MAX_DEPTH} (a cycle?)`)
		local def = tables[id]
		assert(def, `unknown loot table '{id}'`)
		if depth == 1 then
			for _, stack in def.guaranteed or {} do
				shares[stack.itemId] = 1
			end
		end
		local total = 0
		for _, entry in entriesOf(def) do
			total += math.max(0, entry.weight)
		end
		if total <= 0 then
			return
		end
		for _, entry in entriesOf(def) do
			if entry.weight > 0 then
				local share = scale * entry.weight / total
				if entry.tableId then
					visit(entry.tableId, share, depth + 1)
				else
					local itemId = entry.itemId :: string
					shares[itemId] = math.min(1, (shares[itemId] or 0) + share)
				end
			end
		end
	end
	visit(tableId, 1, 1)
	return shares
end

return Loot
