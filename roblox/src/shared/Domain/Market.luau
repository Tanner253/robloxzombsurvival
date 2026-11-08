--!strict
--[[
	Market: Haven Square's coin rules (Data/Haven), shared by Services/Haven, the
	Trader and Trail Keeper panels and the tests.

	- cost: what `count` of an item costs (or pays) on one of the Trader's price lists.
	- chapterDone / claimable: which finished Ember Trail chapters the Trail Keeper still
	  owes a reward for.
]]

local Market = {}

export type Price = { itemId: string, coins: number }

Market.MAX_TRADE = 99 -- the most of one item a single trade moves

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

return Market
