--!strict
--[[
	Ember Trail chapter 1 can be finished at home alone (MVP_LAUNCH v0.1: a simple first
	session). Walks the home chapter's quests in order with Fog Runs off: every gather,
	craft, build, consume and equip is paid from the new player's kit, the rewards so far,
	and the finite home node set (Tuning.home.nodes; the spring refills). Items are made
	from their recipe (station fuel included) when the pool runs short. Fails naming any
	raw material the home set can't supply.
]]

local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")

local Tuning: any = Content.Tuning
local Nodes: any = Content.Nodes
local Recipes: any = Content.Recipes
local Pieces: any = Content.BuildPieces
local Stations: any = Content.Stations
local Quests: any = Content.Quests

-- What the finite home set yields in total; renewing nodes (the spring) never run out.
local function homeSupply(): { [string]: number }
	local supply: { [string]: number } = {}
	for _, entry in Tuning.home.nodes do
		local def = Nodes[entry.nodeId]
		local renewing = table.find(Tuning.home.renewing, entry.nodeId) ~= nil
		for _, y in def.yields do
			supply[y.itemId] = if renewing
				then math.huge
				else (supply[y.itemId] or 0) + entry.count * def.hits * y.perHit
		end
	end
	return supply
end

-- The recipe that makes an item (the first by id, so the result is stable).
local function recipeFor(itemId: string): any
	local ids: { string } = {}
	for id, recipe in Recipes do
		if recipe.outputs[1].itemId == itemId then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return if ids[1] then Recipes[ids[1]] else nil
end

type Run = { pool: { [string]: number }, used: { [string]: number }, supply: { [string]: number }, gaps: { string } }

local need: (run: Run, itemId: string, count: number, depth: number) -> ()

-- Runs a recipe `runs` times: its inputs, and fuel for a fuelled station (sticks, the
-- fuel a new player has most of).
local function craft(run: Run, recipe: any, runs: number, depth: number)
	for _, input in recipe.inputs do
		need(run, input.itemId, input.count * runs, depth + 1)
	end
	local station = recipe.stationId and Stations[recipe.stationId]
	if station and station.fuel then
		local seconds = (recipe.craftSeconds or 0) * runs
		local perStick = station.fuel.burnSeconds["item.sticks"] or station.fuel.secondsPerUnit
		need(run, "item.sticks", math.ceil(seconds / perStick), depth + 1)
	end
	for _, output in recipe.outputs do
		run.pool[output.itemId] = (run.pool[output.itemId] or 0) + output.count * runs
	end
end

need = function(run: Run, itemId: string, count: number, depth: number)
	assert(depth < 12, `recipe loop at {itemId}`)
	local have = run.pool[itemId] or 0
	local take = math.min(have, count)
	run.pool[itemId] = have - take
	local short = count - take
	if short <= 0 then
		return
	end
	if run.supply[itemId] then
		run.used[itemId] = (run.used[itemId] or 0) + short
		return
	end
	local recipe = recipeFor(itemId)
	if recipe == nil then
		table.insert(run.gaps, `{itemId} has no home source or recipe`)
		return
	end
	local runs = math.ceil(short / recipe.outputs[1].count)
	craft(run, recipe, runs, depth)
	run.pool[itemId] -= short
end

return function(test: TestKit.Register)
	test("Ember Trail chapter 1 is finishable at home with Fog Runs off", function()
		local run: Run = { pool = {}, used = {}, supply = homeSupply(), gaps = {} }
		for _, stack in Tuning.newPlayer.items do
			run.pool[stack.itemId] = (run.pool[stack.itemId] or 0) + stack.count
		end
		local chapter = Quests["quest.first_light"].chapter
		local ordered: { any } = {}
		for _, quest in Quests do
			if quest.chapter == chapter then
				table.insert(ordered, quest)
			end
		end
		table.sort(ordered, function(a, b)
			return a.order < b.order
		end)
		TestKit.truthy(#ordered >= 7, "chapter 1 has its seven home quests")
		for _, quest in ordered do
			for _, objective in quest.objectives do
				if objective.flag == "fogRuns" then
					continue -- left out while Fog Runs is off (Domain/Quests)
				end
				local kind = objective.kind
				if kind == "gather" then
					-- Gathered items stay in the bag for later steps.
					run.used[objective.itemId] = (run.used[objective.itemId] or 0) + objective.count
					run.pool[objective.itemId] = (run.pool[objective.itemId] or 0) + objective.count
				elseif kind == "craft" then
					craft(run, Recipes[objective.recipeId], objective.count, 0)
				elseif kind == "build" then
					for _, stack in Pieces[objective.pieceId].cost do
						need(run, stack.itemId, stack.count * objective.count, 0)
					end
				elseif kind == "consume" or kind == "equip" then
					need(run, objective.itemId, objective.count or 1, 0)
				end
			end
			for _, stack in (quest.rewards.items or {}) do
				run.pool[stack.itemId] = (run.pool[stack.itemId] or 0) + stack.count
			end
		end
		for itemId, used in run.used do
			local supply = run.supply[itemId] or 0
			if used > supply then
				table.insert(run.gaps, `{itemId}: needs {used}, the home set gives {supply}`)
			end
		end
		table.sort(run.gaps)
		TestKit.equal(table.concat(run.gaps, "; "), "", "every material comes from home")
	end)
end
