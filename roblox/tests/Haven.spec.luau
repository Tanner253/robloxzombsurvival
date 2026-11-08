--!strict
-- Specs for Haven Square: the Neighbourhood layout, the daily contract board, Haven data.
local TestKit = require("./TestKit")
local Neighbourhood = require("../src/shared/Domain/Neighbourhood")
local Contracts = require("../src/shared/Domain/Contracts")
local Market = require("../src/shared/Domain/Market")
local PlayerSchema = require("../src/shared/Domain/PlayerSchema")
local Content = require("../src/shared/Data")
local Haven = require("../src/shared/Data/Haven")
local Grid = require("../src/shared/Domain/Grid")

local tuning: any = Content.Tuning.plots
local GRID = Content.Tuning.building.plotCells * Grid.CELL_STUDS

return function(test: TestKit.Register)
	test("the 8 plots stand around Haven Square: none on it, none overlapping", function()
		local rects = {}
		for index = 1, tuning.count do
			local x, z = Neighbourhood.plotCentre(tuning, GRID, index)
			local half = GRID / 2
			-- No corner of a plot lies on the square.
			for _, dx in { -half, half } do
				for _, dz in { -half, half } do
					TestKit.equal(Neighbourhood.inSquare(tuning, x + dx, z + dz), false, `plot {index} corner`)
				end
			end
			for other, rect in rects do
				local apart = math.abs(rect.x - x) >= GRID + tuning.marginStuds or math.abs(rect.z - z) >= GRID
				TestKit.truthy(apart, `plots {other} and {index} overlap`)
			end
			table.insert(rects, { x = x, z = z })
		end
	end)

	test("two plots each side of the square in both rows, fronts facing the road", function()
		local left, right = 0, 0
		for index = 1, tuning.count do
			local x, z, front = Neighbourhood.plotCentre(tuning, GRID, index)
			if x < 0 then
				left += 1
			else
				right += 1
			end
			TestKit.equal(front, if z < 0 then 1 else -1, `plot {index} faces the road`)
		end
		TestKit.equal(left, 4)
		TestKit.equal(right, 4)
	end)

	test("the Trailhead is just off the square, past the plots, inside the edge", function()
		local x, z = Neighbourhood.trailhead(tuning, GRID)
		TestKit.equal(Neighbourhood.inSquare(tuning, x, z), false)
		TestKit.truthy(math.abs(x) <= tuning.plazaHalfStuds, "lined up with the square")
		TestKit.truthy(math.abs(z) > Neighbourhood.halfDepth(tuning, GRID), "past the rows")
	end)

	test("three distinct contracts a day, the same all day, new the next", function()
		local pool: any = Haven.contracts.pool
		local a = Contracts.forDay(pool, 3, 42, 20000)
		local b = Contracts.forDay(pool, 3, 42, 20000)
		TestKit.equal(#a, 3)
		local seen = {}
		for index, contract in a do
			TestKit.equal(contract.id, b[index].id, "same day, same board")
			TestKit.equal(seen[contract.id], nil, "distinct")
			seen[contract.id] = true
		end
		local differs = false
		for day = 20001, 20010 do
			local other = Contracts.forDay(pool, 3, 42, day)
			if other[1].id ~= a[1].id or other[2].id ~= a[2].id then
				differs = true
			end
		end
		TestKit.truthy(differs, "boards change from day to day")
	end)

	test("a contract is delivered once; the next day starts fresh", function()
		local pool: any = Haven.contracts.pool
		local board = Contracts.forDay(pool, 3, 7, 100)
		local state = Contracts.today(nil, 100)
		local ok, contract = Contracts.canDeliver(board, state, board[1].id)
		TestKit.equal(ok, true)
		TestKit.equal((contract :: any).id, board[1].id)
		state.done[board[1].id] = true
		TestKit.equal((Contracts.canDeliver(board, state, board[1].id)), false)
		TestKit.equal((Contracts.canDeliver(board, state, "contract.nope")), false)
		local tomorrow = Contracts.today(state, 101)
		TestKit.equal(next(tomorrow.done), nil)
		TestKit.equal(Contracts.dayOf(86400 * 5 + 10), 5)
	end)

	test("Haven data names real items, and the Trader buys for less than she sells", function()
		local Items: any = Content.Items
		local sells: { [string]: number } = {}
		for _, price in Haven.trader.buy do
			TestKit.truthy(Items[price.itemId] ~= nil, price.itemId)
			TestKit.truthy(price.coins > 0, price.itemId)
			sells[price.itemId] = price.coins
		end
		for _, price in Haven.trader.sell do
			TestKit.truthy(Items[price.itemId] ~= nil, price.itemId)
			if sells[price.itemId] then
				TestKit.truthy(price.coins < sells[price.itemId], `{price.itemId} can't be flipped for profit`)
			end
		end
		for _, contract in Haven.contracts.pool do
			TestKit.truthy(Items[contract.itemId] ~= nil, contract.id)
		end
		for _, crate in Haven.vip.dailyCrate do
			TestKit.truthy(Items[crate.itemId] ~= nil, crate.itemId)
		end
		for chapter, reward in Haven.chapterRewards do
			local found = false
			for _, quest in Content.Quests do
				found = found or quest.chapter == chapter
			end
			TestKit.truthy(found, `{chapter} is an Ember Trail chapter`)
			for _, stack in reward.items do
				TestKit.truthy(Items[stack.itemId] ~= nil, stack.itemId)
			end
		end
	end)

	test("trades cost the listed price per item, and only listed items in whole counts", function()
		local list = { { itemId = "item.rope", coins = 20 } }
		TestKit.equal(Market.cost(list, "item.rope", 3), 60)
		TestKit.equal(Market.cost(list, "item.cloth", 1), nil, "unlisted")
		TestKit.equal(Market.cost(list, "item.rope", 0), nil, "zero")
		TestKit.equal(Market.cost(list, "item.rope", 1.5), nil, "fraction")
		TestKit.equal(Market.cost(list, "item.rope", Market.MAX_TRADE + 1), nil, "too many")
	end)

	test("a chapter is claimable once every one of its quests is done, and only once", function()
		local quests = {
			a = { chapter = "One" },
			b = { chapter = "One" },
			c = { chapter = "Two" },
		}
		local rewards = { One = {}, Two = {}, Three = {} }
		TestKit.equal(#Market.claimable(rewards, quests, { a = 1 }, {}), 0, "half done")
		local ready = Market.claimable(rewards, quests, { a = 1, b = 2, c = 3 }, {})
		TestKit.equal(#ready, 2)
		TestKit.equal(ready[1], "One")
		-- A chapter with no quests is never finished.
		TestKit.equal(Market.chapterDone(quests, { a = 1, b = 2, c = 3 }, "Three"), false)
		TestKit.equal(#Market.claimable(rewards, quests, { a = 1, b = 2, c = 3 }, { One = 100, Two = 200 }), 0)
	end)

	test("the home chapter has a Trail Keeper reward and the v8 profile starts with no coins", function()
		TestKit.truthy(Market.chapterDone(Content.Quests :: any, {}, "Ashes and Embers") == false)
		TestKit.truthy(Haven.chapterRewards["Ashes and Embers"] ~= nil)
		local fresh = PlayerSchema.template()
		TestKit.equal(fresh.haven.coins, 0)
		TestKit.equal(fresh.haven.vipCrateDay, 0)
		local old: any = { version = 7 }
		PlayerSchema.migrations[7](old)
		TestKit.equal(old.haven.coins, 0)
	end)
end
