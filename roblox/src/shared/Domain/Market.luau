--!strict
--[[
	Market: Haven Square's coin rules (Data/Haven), shared by Services/Haven, the
	Trader, Trail Keeper and Lounge panels and the tests.

	- cost: what `count` of an item costs (or pays) on one of the Trader's price lists.
	- chapterDone / claimable: which finished Ember Trail chapters the Trail Keeper still
	  owes a reward for.
	- The daily ledger (ledger / left / record): what a survivor bought of each stock key
	  today, so a per-item daily limit holds all UTC day and resets at 00:00 UTC.
	- rotation: a members-only trader's table for a UTC day, seeded by the day and the
	  trader alone, so every survivor on every server sees the same stock all day and a
	  new table the next.
]]

local Rng = require("./Rng")

local Market = {}

export type Price = { itemId: string, coins: number }

Market.MAX_TRADE = 99 -- the most of one item a single trade moves

local DAY = 24 * 60 * 60

-- The UTC day number of `now` (UTC seconds).
function Market.dayOf(now: number): number
	return now // DAY
end

-- The coins for `count` of `itemId` on `list`; nil when it is not listed or the count is bad.
function Market.cost(list: { Price }, itemId: string, count: number): number?
	if count < 1 or count > Market.MAX_TRADE or count ~= math.floor(count) then
		return nil
	end
	for _, price in list do
		if price.itemId == itemId then
			return price.coins * count
		end
	end
	return nil
end

-- Whether every quest of `chapter` is completed.
function Market.chapterDone(
	quests: { [string]: { chapter: string? } },
	completed: { [string]: any },
	chapter: string
): boolean
	local any = false
	for questId, quest in quests do
		if quest.chapter == chapter then
			any = true
			if completed[questId] == nil then
				return false
			end
		end
	end
	return any
end

-- Chapters with a reward that are finished and not yet handed in, sorted by name.
function Market.claimable(
	rewards: { [string]: any },
	quests: { [string]: { chapter: string? } },
	completed: { [string]: any },
	claimed: { [string]: number }
): { string }
	local list: { string } = {}
	for chapter in rewards do
		if claimed[chapter] == nil and Market.chapterDone(quests, completed, chapter) then
			table.insert(list, chapter)
		end
	end
	table.sort(list)
	return list
end

-- The daily ledger -------------------------------------------------------------------------------

-- Purchases per stock key ("npc.trader:item.rope", "npc.quartermaster:qm.pipe_pistol") on
-- one UTC day.
export type Ledger = { day: number, bought: { [string]: number } }

-- The stock key for one trader's item or stock row.
function Market.key(traderId: string, id: string): string
	return `{traderId}:{id}`
end

-- The ledger for `day`: yesterday's purchases don't count.
function Market.ledger(ledger: Ledger?, day: number): Ledger
	if ledger == nil or ledger.day ~= day or type(ledger.bought) ~= "table" then
		return { day = day, bought = {} }
	end
	return ledger
end

-- How many more of `key` the survivor may buy on `day` under a daily `limit`.
function Market.left(ledger: Ledger?, day: number, key: string, limit: number): number
	local today = Market.ledger(ledger, day)
	return math.max(0, limit - (today.bought[key] or 0))
end

-- The ledger for `day` with `count` more of `key` bought.
function Market.record(ledger: Ledger?, day: number, key: string, count: number): Ledger
	local today = Market.ledger(ledger, day)
	local bought = table.clone(today.bought)
	bought[key] = (bought[key] or 0) + count
	return { day = day, bought = bought }
end

-- The daily rotation -----------------------------------------------------------------------------

export type StockEntry = {
	id: string,
	itemId: string,
	count: number,
	coins: number,
	embers: number,
	perDay: number,
	featured: boolean?,
	weight: number?,
}

-- One weighted pick from `pool` (removed from it).
local function pick(random: Rng.Source, pool: { StockEntry }): StockEntry
	local total = 0
	for _, entry in pool do
		total += entry.weight or 1
	end
	local roll = random:NextNumber() * total
	for index, entry in pool do
		roll -= entry.weight or 1
		if roll < 0 then
			return table.remove(pool, index) :: StockEntry
		end
	end
	return table.remove(pool) :: StockEntry
end

--[[
	The table for UTC `day`: between slots.min and slots.max distinct rows of `stock`, the
	first a featured row when there is one, the rest weighted picks, in stock order after
	the lead. Seeded by the day and `salt` only (never the player), so it is the same for
	everyone all day.
]]
function Market.rotation(
	stock: { StockEntry },
	slots: { min: number, max: number },
	day: number,
	salt: number
): { StockEntry }
	local random = Rng.new(day * 9973 + salt)
	local count = math.min(#stock, random:NextInteger(slots.min, math.max(slots.min, slots.max)))
	local featured: { StockEntry } = {}
	local rest: { StockEntry } = {}
	for _, entry in stock do
		table.insert(if entry.featured then featured else rest, entry)
	end
	local chosen: { [string]: boolean } = {}
	local lead: StockEntry? = nil
	if #featured > 0 and count > 0 then
		lead = pick(random, featured)
		chosen[(lead :: StockEntry).id] = true
	end
	-- The other featured rows go back in the pool for the remaining slots.
	for _, entry in featured do
		table.insert(rest, entry)
	end
	for _ = 1, count - (if lead then 1 else 0) do
		if #rest == 0 then
			break
		end
		chosen[pick(random, rest).id] = true
	end
	local rows: { StockEntry } = {}
	if lead then
		table.insert(rows, lead)
	end
	for _, entry in stock do
		if chosen[entry.id] and entry ~= lead then
			table.insert(rows, entry)
		end
	end
	return rows
end

-- The row `entryId` when it is on the table for `day`, else nil.
function Market.onTable(
	stock: { StockEntry },
	slots: { min: number, max: number },
	day: number,
	salt: number,
	entryId: string
): StockEntry?
	for _, entry in Market.rotation(stock, slots, day, salt) do
		if entry.id == entryId then
			return entry
		end
	end
	return nil
end

return Market
