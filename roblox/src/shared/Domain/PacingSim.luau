--!strict
--[[
	PacingSim: the free-player pacing model of docs/ECONOMY.md §9, run on the real data
	(§11.4). Pure and deterministic: expected values, no RNG, one-minute steps, well under a
	second for three weeks of play.

	It is a port of tools/economy/pacing.py. The player's habits are the Model the caller
	passes (tests/Pacing.spec holds §9.1's assumptions): sessions, how a run is chosen and
	spent, eating, the building order and the milestone goal lists. Every game number comes
	from the content: node hits, yields, yieldEvery and XP; every recipe and the station it
	runs on (after Tuning.stationFallback, when the caller applies it); station slot caps,
	levels and fuel, through Domain/Converter itself; build, upgrade and tower costs; tool,
	weapon and armor durability and damage; food values; enemy HP, XP and drops; Energy,
	survival drain, the XP curve and quest and level rewards. Fog Run locations and their
	container tables are model inputs until their data exists (Data/Locations gains the
	Forest and Mine maps after this pass); Domain/Loot.expected reads them either way.

	Stock rule (§11.4): fractional expected stock is floored whenever the player checks
	"have", so 0.97 of a Trigger Group never builds a gun.

	Times are minutes from the start of day 1 (minute 0 is midnight). PacingSim.day turns a
	stamp into the 1-based fractional day §11.4's assertions use ("day 4.4" is day 4 at about
	10:00).
]]

local Types = require("../Types")
local Converter = require("./Converter")
local Gathering = require("./Gathering")
local Loot = require("./Loot")

local PacingSim = {}

local EPSILON = 1e-6
local DAY = 24 * 60
local CLOCK_ZERO = 1_000_000 -- Converter stamps must be positive: second 0 of the sim

export type Content = {
	Items: { [string]: Types.ItemDef },
	Recipes: { [string]: Types.RecipeDef },
	Stations: { [string]: Types.StationDef },
	Nodes: { [string]: Types.ResourceNodeDef },
	Enemies: { [string]: Types.EnemyDef },
	LootTables: { [string]: Types.LootTableDef },
	BuildPieces: { [string]: Types.BuildPieceDef },
	Levels: { Types.PlayerLevelDef },
	Quests: { [string]: Types.QuestDef },
	Tuning: Types.TuningDef,
}

export type Count = { id: string, count: number }

export type Location = {
	id: string,
	tier: number, -- fog tier
	level: number, -- level gate
	energy: number,
	walkMinutes: number,
	nodes: { Count }, -- node id -> how many, in map order
	containers: { { tableId: string, count: number, searchSeconds: number } },
	enemies: { Count }, -- enemy id -> average spawns
	band2: string?, -- loot table rolled into containers searched in Fog band 2
	band3: string?,
	gate: string?, -- the Tuning.regionGates tower that must be repaired first
	dailyReset: boolean?, -- containers full only on the day's first clear (a 20 h reset)
}

-- A goal entry: "build.<piece>", "upgrade:<station id>" (one level up), "gate:<tower id>"
-- or "craft:<recipe id>".
export type Goal = { name: string, pieces: { Count }, flags: { string }?, minLevel: number? }

export type Model = {
	days: number,
	sessions: { { start: number, minutes: number } },
	homeMinutes: number,
	reservedSlots: number, -- bag slots kept for tools, meds and food
	runCapMinutes: number, -- activity inside one run
	hoard: number, -- run choice: weight on units past the current need
	energyWeight: number, -- run choice: minutes one Energy point is worth
	contested: number, -- share of Dense and Black containers one player reaches
	xpWeight: number,
	xpWeightGated: number, -- while a location level gate is still ahead
	demandFloor: number, -- the last few units of a need still count this many
	bandMultiplier: number, -- container rolls (Fog meter bands)
	band2Share: number, -- share of containers searched in band 2+
	band3Share: number,
	overheadSeconds: { number }, -- per run, by fog tier
	extractSeconds: { number },
	keep: { number }, -- share of a haul that gets home (deaths), by fog tier
	depotRunsPerDay: number, -- full clears of a daily-reset location a day
	killShare: number, -- share of the spawns killed
	killSeconds: { [string]: number },
	wildlife: { [string]: boolean }, -- ignores the tier HP scale, never hits back
	stalk: { [string]: boolean }, -- killing it counts as food time (deer)
	hpScale: { number }, -- Hollow HP by fog tier
	hitsTakenPerKill: { number },
	dressingsPerRun: { number },
	gunHitShare: number,
	gunShotsPerRun: { number }, -- by fog tier, once the gun exists
	gunRecipe: string,
	roundsRecipe: string,
	roundsReserve: number,
	earlyWeapon: string, -- recipe ids
	lateWeapon: string,
	lateWeaponFromGoal: number,
	armorRecipes: { string },
	armorFromGoal: number,
	dressingRecipe: string,
	dressingReserve: number,
	toolRecipes: { [string]: { [number]: string } }, -- tool kind -> tier -> recipe id
	spareTools: { below: number, cost: { [string]: number } },
	forgedUpkeep: { fromGoal: number, count: number },
	eatBelow: number,
	hungerOrder: { string },
	thirstOrder: { string },
	foodReserve: number, -- meter points of food (and of drink) the player keeps in stock
	cookedValue: { [string]: string }, -- raw item -> the item it cooks into, for stock value
	hungryBelow: number,
	hungryValues: { [string]: number },
	thirstyValues: { [string]: number },
	enemyDrops: { [string]: boolean }, -- enemy loot that counts (the rest is extra)
	nodeOverheadSeconds: { [string]: number }, -- walking to a node
	nodeValues: { [string]: number },
	nodeValueDefault: number,
	offDemand: number, -- node value multiplier when nothing needs its item
	values: { [string]: number }, -- run choice value per unit
	valueDefault: number,
	locations: { Location },
	lootTables: { [string]: Types.LootTableDef }, -- container tables (Data/LootTables shape)
	goals: { Goal },
	priority: { string }, -- goal entries built before anything cheaper
	questTriggers: { string }, -- first builds that complete the next Ember Trail quest
	laterQuests: { { questId: string, craft: string?, blackRun: boolean? } },
	craftGates: { [string]: { stationId: string, level: number } }, -- "known recipe" gates
	recycle: { string },
	fuelOrder: { string },
	fuelKeep: { [string]: number }, -- never burn below this stock
	lineWants: { [string]: number }, -- station outputs kept at a fixed stock (food, powder)
	lineBoost: { [string]: number }, -- line score multipliers (food before coal)
	plankFloat: { below: number, extra: number, yieldsTo: { string } }, -- planks kept in stock
	glue: { early: number, late: number, fromGoal: number },
	coal: { stock: number, below: number, stationLevel: number },
	ids: {
		cord: string,
		fiber: string,
		plank: string,
		timber: string,
		murky: string,
		rawMeat: string,
		fatwood: string,
		powder: string,
		rounds: string,
		dressing: string,
		cloth: string,
		glue: string,
		coal: string,
		plans: string, -- the blueprint item the reinforced goal waits on
		packSchematic: string,
		satchel: string,
		packFrame: string,
	},
	trace: ((minute: number, message: string) -> ())?, -- debugging: builds, levels, milestones, runs
}

export type Stats = {
	starvingMinutes: number,
	runMinutes: number,
	foodMinutes: number,
	runs: number,
	brokenRuns: number, -- runs where the melee weapon broke with no spare
	gunsCrafted: number,
	gunRuns: number, -- runs the gun was carried and fired
	shots: number,
	crafted: { [string]: { [number]: number } }, -- recipe id -> day -> crafts
	runsAt: { { minute: number, locationId: string, walk: boolean } },
}

export type Result = {
	milestones: { [string]: number },
	levelAt: { [number]: number },
	flagAt: { [string]: number },
	level: number,
	xp: number,
	stats: Stats,
	store: { [string]: number },
}

-- The 1-based fractional day of a stamp: minute 0 is day 1.0, day 4 at 09:36 is 4.4.
function PacingSim.day(minute: number): number
	return minute / DAY + 1
end

-- Minutes of play the sessions hold up to `minute`.
function PacingSim.playMinutes(minute: number, sessions: { { start: number, minutes: number } }): number
	local total = 0
	local day = 0
	while day * DAY <= minute do
		for _, session in sessions do
			local start = day * DAY + session.start
			total += math.max(0, math.min(minute, start + session.minutes) - start)
		end
		day += 1
	end
	return total
end

type Station = {
	def: Types.StationDef,
	state: Converter.State,
	recycler: boolean,
	-- Recycler only (expected values, so outside Converter's rolls):
	line: string?,
	held: number,
	work: number,
	outs: { [string]: number },
}

type Line = {
	recipe: Types.RecipeDef,
	input: string,
	inputCount: number,
	output: string,
	outputCount: number,
	minutes: number,
	level: number,
	fuelled: boolean,
}

local function sortedKeys<T>(dict: { [string]: T }): { string }
	local keys: { string } = {}
	for key in dict do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function add(map: { [string]: number }, key: string, amount: number)
	map[key] = (map[key] or 0) + amount
end

function PacingSim.run(content: Content, model: Model): Result
	local items = content.Items
	local tuning = content.Tuning
	local ids = model.ids
	local fuelDef = content.Stations["station.campfire"]
	assert(fuelDef and fuelDef.fuel, "the Campfire's fuel list sets burn times")

	-- Static tables from the content --------------------------------------------------------
	local recipeIds = sortedKeys(content.Recipes)
	local lines: { Line } = {} -- station lines, by recipe id
	local producer: { [string]: Line } = {} -- the primary line making each item
	local alternates: { Line } = {} -- recipe.<output>_from_<input>
	for _, id in recipeIds do
		local recipe = content.Recipes[id]
		local stationId = recipe.stationId
		if stationId then
			local station = content.Stations[stationId]
			local line: Line = {
				recipe = recipe,
				input = recipe.inputs[1].itemId,
				inputCount = recipe.inputs[1].count,
				output = recipe.outputs[1].itemId,
				outputCount = recipe.outputs[1].count,
				minutes = recipe.craftSeconds / 60,
				level = recipe.stationLevel or 1,
				fuelled = station ~= nil and station.fuel ~= nil,
			}
			table.insert(lines, line)
			if string.find(id, "_from_", 1, true) then
				table.insert(alternates, line)
			elseif producer[line.output] == nil then
				producer[line.output] = line
			end
		end
	end
	local function handInputs(recipeId: string): { [string]: number }
		local result: { [string]: number } = {}
		for _, stack in content.Recipes[recipeId].inputs do
			add(result, stack.itemId, stack.count)
		end
		return result
	end
	local cordRecipe = handInputs("recipe.rope")

	local function burnMinutes(itemId: string): number
		return Converter.burnSeconds(fuelDef, itemId) / 60
	end

	local food: { [string]: { hunger: number, thirst: number } } = {}
	for id, item in items do
		local consume = item.consume
		if consume and ((consume.hunger or 0) > 0 or (consume.thirst or 0) > 0) then
			food[id] = { hunger = consume.hunger or 0, thirst = consume.thirst or 0 }
		end
	end
	local foodIds = sortedKeys(food)

	local gates: { [string]: Types.RegionGate } = {}
	for _, gate in tuning.regionGates do
		gates[gate.id] = gate
	end

	-- What a goal entry costs and does.
	local function costOf(key: string): { [string]: number }
		local result: { [string]: number } = {}
		local function stacks(list: { Types.ItemStack })
			for _, stack in list do
				add(result, stack.itemId, stack.count)
			end
		end
		local kind, id = string.match(key, "^(%a+):(.+)$")
		if kind == "upgrade" then
			stacks(content.Stations[id :: string].levels[2].upgradeCost)
		elseif kind == "gate" then
			stacks(gates[id :: string].parts)
		elseif kind == "craft" then
			stacks(content.Recipes[id :: string].inputs)
		else
			stacks(content.BuildPieces[key].cost)
		end
		return result
	end
	local costCache: { [string]: { [string]: number } } = {}
	local function cost(key: string): { [string]: number }
		local cached = costCache[key]
		if cached == nil then
			cached = costOf(key)
			costCache[key] = cached
		end
		return cached
	end
	local function costSum(key: string): number
		local total = 0
		for _, count in cost(key) do
			total += count
		end
		return total
	end

	local questOrder: { Types.QuestDef } = {}
	for _, quest in content.Quests do
		table.insert(questOrder, quest)
	end
	table.sort(questOrder, function(a: Types.QuestDef, b: Types.QuestDef)
		return a.order < b.order
	end)

	local enemyLoot: { [string]: { [string]: number } } = {}
	for id, enemy in content.Enemies do
		local drops: { [string]: number } = {}
		for itemId, count in Loot.expected(content.LootTables, enemy.lootTableId) do
			if model.enemyDrops[itemId] then
				drops[itemId] = count
			end
		end
		enemyLoot[id] = drops
	end

	-- Expected node yields, read from Data/Nodes.
	type NodeInfo = {
		kind: string?,
		tier: number,
		hits: number,
		units: { [string]: number },
		main: string,
		xp: number,
		overhead: number,
	}
	local nodeInfo: { [string]: NodeInfo } = {}
	local function infoOf(nodeId: string): NodeInfo
		local cached = nodeInfo[nodeId]
		if cached then
			return cached
		end
		local def = content.Nodes[nodeId]
		assert(def, `unknown node '{nodeId}'`)
		local units = Gathering.expectedYield(def)
		local main, best = "", -1
		for _, itemId in sortedKeys(units) do
			if units[itemId] > best then
				main, best = itemId, units[itemId]
			end
		end
		local info: NodeInfo = {
			kind = if def.tool then def.tool.kind else nil,
			tier = if def.tool then def.tool.tier else 0,
			hits = def.hits,
			units = units,
			main = main,
			xp = def.xpPerHit * def.hits,
			overhead = model.nodeOverheadSeconds[nodeId] or 4,
		}
		nodeInfo[nodeId] = info
		return info
	end
	local swing = tuning.gathering.swingSeconds

	-- State ----------------------------------------------------------------------------------
	local t = 0
	local energy = tuning.energy.cap
	local xp = 0
	local store: { [string]: number } = {}
	local tools: { [string]: number } = {} -- "<kind><tier>" -> durability left
	local built: { [string]: number } = {}
	local stations: { Station } = {}
	local goalIndex = 1
	local goalLeft: { { [string]: number } } = {}
	for index, goal in model.goals do
		local left: { [string]: number } = {}
		for _, piece in goal.pieces do
			add(left, piece.id, piece.count)
		end
		goalLeft[index] = left
	end
	local milestones: { [string]: number } = {}
	local levelAt: { [number]: number } = {}
	local flagAt: { [string]: number } = {}
	local flags: { [string]: boolean } = {}
	local questsPaid = 0
	local laterPaid: { [string]: boolean } = {}
	local hunger = tuning.survival.hunger.max
	local thirst = tuning.survival.thirst.max
	local meleeLeft = 0
	local armorLeft: { [string]: number } = {}
	local gunLeft = 0
	local springReadyAt = 0
	local depotRunsToday = 0
	local packFrame = false
	local homeNodes: { [string]: number } = {}
	local spring: Types.LocationNode? = nil
	for _, entry in tuning.home.nodes do
		if table.find(tuning.home.renewing, entry.nodeId) then
			spring = entry
		else
			add(homeNodes, entry.nodeId, entry.count)
		end
	end
	for _, stack in tuning.newPlayer.items do
		add(store, stack.itemId, stack.count)
	end
	local stats: Stats = {
		starvingMinutes = 0,
		runMinutes = 0,
		foodMinutes = 0,
		runs = 0,
		brokenRuns = 0,
		gunsCrafted = 0,
		gunRuns = 0,
		shots = 0,
		crafted = {},
		runsAt = {},
	}
	-- The model plays a player who follows the Ember Trail, so every line it loads is open.
	local allQuests: { [string]: number } = {}
	for id in content.Quests do
		allQuests[id] = 1
	end
	local blueprints: { [string]: boolean } = {}
	for id, item in items do
		if item.category == "blueprint" then
			blueprints[id] = true
		end
	end
	local progress = {
		level = #content.Levels,
		unlocks = { recipes = {}, blueprints = blueprints },
		quests = { completed = allQuests },
	}

	local function nowSeconds(): number
		return CLOCK_ZERO + t * 60
	end
	local function trace(message: string)
		local sink = model.trace
		if sink then
			sink(t, message)
		end
	end
	local function noteCraft(recipeId: string, count: number)
		local byDay = stats.crafted[recipeId] or {}
		stats.crafted[recipeId] = byDay
		local day = t // DAY + 1
		byDay[day] = (byDay[day] or 0) + count
	end

	-- Helpers --------------------------------------------------------------------------------
	local function have(itemId: string): number
		return math.floor((store[itemId] or 0) + EPSILON)
	end
	local function take(need: { [string]: number }): boolean
		for itemId, count in need do
			if have(itemId) < count - 1e-9 then
				return false
			end
		end
		for itemId, count in need do
			store[itemId] = (store[itemId] or 0) - count
		end
		return true
	end
	local function level(): number
		local result = 1
		for index, def in content.Levels do
			if xp >= def.xp then
				result = index
			end
		end
		return result
	end
	local function addXp(amount: number)
		local before = level()
		xp += amount
		local after = level()
		if after > before then
			energy = math.min(tuning.energy.cap, energy + tuning.energy.levelUpRestore * (after - before))
			for reached = before + 1, after do
				levelAt[reached] = t
				trace(`level {reached}`)
				for _, stack in (content.Levels[reached].rewards or {}) :: { Types.ItemStack } do
					add(store, stack.itemId, stack.count)
				end
			end
		end
	end
	local function stationLevel(stationId: string): number
		local best = 0
		for _, station in stations do
			if station.def.id == stationId then
				best = math.max(best, station.state.level)
			end
		end
		return best
	end
	local function slotCap(station: Station): number
		return Converter.slotCap(station.def, station.state.level)
	end
	local function lineOf(station: Station): Line?
		local input = station.state.input
		if input.count <= 0 then
			return nil
		end
		for _, line in lines do
			if line.recipe.stationId == station.def.id and line.input == input.itemId then
				return line
			end
		end
		return nil
	end
	local function ctxOf(station: Station): Converter.Context
		return { def = station.def, recipes = content.Recipes, items = items :: any }
	end
	local function inflight(itemId: string): number
		local total = 0
		for _, station in stations do
			if not station.recycler then
				local line = lineOf(station)
				local output = station.state.output[1]
				if output.itemId == itemId then
					total += output.count
				end
				if line and line.output == itemId then
					total += (station.state.input.count // line.inputCount) * line.outputCount
				end
			end
		end
		return total
	end
	local function foodPoints(): (number, number)
		local h, d = 0, 0
		for _, itemId in foodIds do
			local value = food[model.cookedValue[itemId] or itemId]
			local count = store[itemId] or 0
			h += count * value.hunger
			d += count * value.thirst
		end
		return h, d
	end
	local function toolKey(kind: string, tier: number): string
		return `{kind}{tier}`
	end

	-- What the current goal and the upkeep still need, at the intermediate level.
	local function needs(): { [string]: number }
		local need: { [string]: number } = {}
		local function addAll(list: { [string]: number }, times: number)
			for itemId, count in list do
				add(need, itemId, count * times)
			end
		end
		for key, count in (goalLeft[goalIndex] or {}) :: { [string]: number } do
			addAll(cost(key), count)
		end
		if goalIndex >= model.forgedUpkeep.fromGoal then
			for _, kind in sortedKeys(model.toolRecipes) do
				local recipeId = model.toolRecipes[kind][2]
				if recipeId then
					addAll(handInputs(recipeId), model.forgedUpkeep.count)
				end
			end
		end
		for _, flag in (model.goals[math.min(goalIndex, #model.goals)].flags or {}) :: { string } do
			if not flags[flag] then
				add(need, flag, 1)
			end
		end
		addAll(handInputs(if goalIndex >= model.lateWeaponFromGoal then model.lateWeapon else model.earlyWeapon), 1)
		if
			(tools[toolKey("hatchet", 1)] or 0) < model.spareTools.below
			or (tools[toolKey("pick", 1)] or 0) < model.spareTools.below
		then
			addAll(model.spareTools.cost, 1)
		end
		if goalIndex >= model.armorFromGoal then
			for _, recipeId in model.armorRecipes do
				addAll(handInputs(recipeId), 1)
			end
		end
		local dressing = content.Recipes[model.dressingRecipe]
		addAll(
			handInputs(model.dressingRecipe),
			math.max(0, model.dressingReserve - have(ids.dressing)) / dressing.outputs[1].count
		)
		if (built["build.ammo_press"] or 0) > 0 and (built["craft:" .. model.gunRecipe] or 0) > 0 then
			local rounds = content.Recipes[model.roundsRecipe]
			local short = math.max(0, model.roundsReserve - have(ids.rounds))
			addAll(handInputs(model.roundsRecipe), short / rounds.outputs[1].count)
			addAll(handInputs(model.gunRecipe), 1)
		end
		local h, d = foodPoints()
		local cooked = food[model.cookedValue[ids.rawMeat] or ids.rawMeat]
		local boiled = food[model.cookedValue[ids.murky] or ids.murky]
		if h < model.foodReserve then
			add(need, ids.rawMeat, math.ceil((model.foodReserve - h) / cooked.hunger))
		end
		if d < model.foodReserve then
			add(need, ids.murky, math.ceil((model.foodReserve - d) / boiled.thirst))
		end
		return need
	end

	-- Expands intermediate needs into raw needs through the station lines and cord.
	local function expand(need: { [string]: number }, out: { [string]: number })
		for _, itemId in sortedKeys(need) do
			local count = need[itemId]
			if count > 0 then
				local line = producer[itemId]
				if line then
					expand({ [line.input] = count * line.inputCount / line.outputCount }, out)
					if line.fuelled then
						add(out, "fuel_min", count / line.outputCount * line.minutes)
					end
				elseif itemId == ids.cord then
					local made = content.Recipes["recipe.rope"].outputs[1].count
					local inputs: { [string]: number } = {}
					for input, perCraft in cordRecipe do
						inputs[input] = count * perCraft / made
					end
					expand(inputs, out)
				else
					add(out, itemId, count)
				end
			end
		end
	end

	local function deficits(): ({ [string]: number }, { [string]: number })
		local need = needs()
		local short: { [string]: number } = {}
		for itemId, count in need do
			local rem = count - have(itemId)
			if rem > 0 then
				short[itemId] = rem
			end
		end
		local raw: { [string]: number } = {}
		expand(short, raw)
		local out: { [string]: number } = {}
		for itemId, count in raw do
			if itemId == "fuel_min" then
				out[itemId] = count
				continue
			end
			local rem = count - have(itemId)
			-- An alternative input stands in for the primary one (5 scrap = 1 ingot = 2 ironstone).
			for _, alt in alternates do
				local primary = producer[alt.output]
				if primary and primary.input == itemId then
					rem -= have(alt.input) * (primary.inputCount / primary.outputCount) / (alt.inputCount / alt.outputCount)
				end
			end
			if rem > 0 then
				out[itemId] = rem
			end
		end
		local fuelMinutes = out["fuel_min"]
		if fuelMinutes then
			out["fuel_min"] = nil
			local stock = have(ids.fatwood) * burnMinutes(ids.fatwood) + have(ids.coal) * burnMinutes(ids.coal)
			local missing = math.max(0, fuelMinutes - stock)
			add(out, ids.timber, missing / burnMinutes(ids.timber))
		end
		return out, short
	end

	-- Survival -------------------------------------------------------------------------------
	local drain = tuning.survival.hunger.decayPerSecond * 60
	local drainThirst = tuning.survival.thirst.decayPerSecond * 60
	local function eat(minutes: number)
		for _ = 1, math.floor(minutes + 0.5) do
			hunger -= drain
			thirst -= drainThirst
			for _, meter in { "hunger", "thirst" } do
				for _ = 1, 6 do
					local value = if meter == "hunger" then hunger else thirst
					if value >= model.eatBelow then
						break
					end
					local order: { string } = if meter == "hunger" then model.hungerOrder else model.thirstOrder
					local ate = false
					for _, itemId in order do
						if (store[itemId] or 0) >= 1 then
							store[itemId] -= 1
							local value2 = food[itemId]
							hunger = math.min(tuning.survival.hunger.max, hunger + value2.hunger)
							thirst = math.min(tuning.survival.thirst.max, thirst + value2.thirst)
							ate = true
							break
						end
					end
					if not ate then
						break
					end
				end
			end
			if hunger <= 0 or thirst <= 0 then
				stats.starvingMinutes += 1
			end
			hunger = math.max(0, hunger)
			thirst = math.max(0, thirst)
		end
	end

	-- Stations -------------------------------------------------------------------------------
	local function newStation(stationId: string)
		local def = content.Stations[stationId]
		table.insert(stations, {
			def = def,
			state = Converter.new(def, nowSeconds()),
			recycler = def.salvage ~= nil,
			line = nil,
			held = 0,
			work = 0,
			outs = {},
		})
	end

	local salvageEv: { [string]: { minutes: number, outs: { [string]: number } } } = {}
	local function salvageOf(station: Station, itemId: string): { minutes: number, outs: { [string]: number } }?
		local cached = salvageEv[itemId]
		if cached then
			return cached
		end
		for _, salvage in (station.def.salvage or {}) :: { Types.SalvageDef } do
			if salvage.inputItemId == itemId then
				local outs: { [string]: number } = {}
				for _, output in salvage.outputs do
					add(outs, output.itemId, (output.min + output.max) / 2 * math.min(1, output.chance))
				end
				local result = { minutes = salvage.seconds / 60, outs = outs }
				salvageEv[itemId] = result
				return result
			end
		end
		return nil
	end

	local function tickStations(minutes: number)
		local now = nowSeconds() + minutes * 60
		for _, station in stations do
			if station.recycler then
				local left = math.floor(minutes)
				while left > 0 and station.line ~= nil and station.held >= 1 do
					local salvage = salvageOf(station, station.line :: string) :: any
					local step = math.min(left, salvage.minutes - station.work)
					station.work += step
					left -= step
					if station.work >= salvage.minutes then
						station.work = 0
						station.held -= 1
						for itemId, count in salvage.outs do
							add(station.outs, itemId, count)
						end
					end
				end
			else
				local before = station.state.output[1].count
				local line = lineOf(station)
				station.state = Converter.advance(station.state, ctxOf(station), now)
				local made = station.state.output[1].count - before
				if line and made > 0 then
					noteCraft(line.recipe.id, made / line.outputCount)
				end
			end
		end
	end

	local function refill()
		local _, short = deficits()
		local need = needs()
		local now = nowSeconds()
		local coalWanted = false
		for _, station in stations do
			if station.def.fuel and station.state.level >= model.coal.stationLevel then
				for _, line in lines do
					if line.recipe.stationId == station.def.id and line.level >= model.coal.stationLevel then
						coalWanted = true
					end
				end
			end
		end
		for _, station in stations do
			if station.recycler then
				for itemId, count in station.outs do
					add(store, itemId, count)
				end
				station.outs = {}
				if station.held < 1 then
					for _, itemId in model.recycle do
						if have(itemId) >= 1 then
							local count = math.min(slotCap(station), have(itemId))
							station.line, station.held, station.work = itemId, count, 0
							store[itemId] -= count
							break
						end
					end
				end
				continue
			end
			local ctx = ctxOf(station)
			local output = station.state.output[1]
			if output.count > 0 then
				local taken: Types.Slot
				station.state, taken = Converter.takeOutput(station.state, ctx, 1, nil, now)
				add(store, taken.itemId, taken.count)
			end
			local current = lineOf(station)
			local best: Line? = nil
			local bestScore = 0
			-- The plank float waits while this station's plankFloat.yieldsTo lines are short:
			-- when the Saw Bench also cuts blocks (Tuning.stationFallback), the float would
			-- starve them.
			local busy = false
			for _, line in lines do
				if
					line.recipe.stationId == station.def.id
					and station.state.level >= line.level
					and table.find(model.plankFloat.yieldsTo, line.output)
					and (short[line.output] or 0) > inflight(line.output)
				then
					busy = true
				end
			end
			for _, line in lines do
				if line.recipe.stationId ~= station.def.id or station.state.level < line.level then
					continue
				end
				local item = line.output
				local down = 0
				for _, next in lines do
					if next.input == item then
						local nextDown = math.max(0, (short[next.output] or 0) - inflight(next.output))
						for _, after in lines do
							if after.input == next.output then
								nextDown += math.max(0, (short[after.output] or 0) - inflight(after.output)) * after.inputCount / after.outputCount
							end
						end
						down += nextDown * next.inputCount / next.outputCount
					end
				end
				local want = math.ceil(math.max(0, (need[item] or 0) + down - have(item) - inflight(item)) - EPSILON)
				local fixed = model.lineWants[item]
				if fixed then
					want = math.max(0, fixed - have(item))
				end
				if item == ids.coal then
					want = if coalWanted and have(ids.coal) < model.coal.below then model.coal.stock else 0
				elseif item == ids.glue then
					want = math.max(
						0,
						(if goalIndex >= model.glue.fromGoal then model.glue.late else model.glue.early)
							- have(ids.glue)
					)
				elseif item == ids.plank and have(ids.plank) < model.plankFloat.below and not busy then
					want += model.plankFloat.extra
				end
				local available = have(line.input)
					+ (if current and current.recipe.id == line.recipe.id then station.state.input.count else 0)
				if available < line.inputCount or want <= 0 then
					continue
				end
				local score = want * (1 + line.minutes / 60) * (model.lineBoost[item] or 1)
				if score > bestScore then
					best, bestScore = line, score
				end
			end
			if best == nil then
				continue
			end
			local chosen = best :: Line
			if current == nil or current.recipe.id ~= chosen.recipe.id then
				local back: Types.Slot
				station.state, back = Converter.takeInput(station.state, ctx, nil, now)
				if back.count > 0 then
					add(store, back.itemId, back.count)
				end
			end
			local load = math.min(slotCap(station) - station.state.input.count, have(chosen.input))
			if load > 0 then
				local nextState, accepted =
					Converter.putInput(station.state, ctx, progress, { itemId = chosen.input, count = load }, now)
				if nextState then
					station.state = nextState
					store[chosen.input] -= accepted
				end
			end
			if station.def.fuel then
				for _, fuelId in model.fuelOrder do
					local slot = station.state.fuel
					if slot.count >= slotCap(station) then
						break
					end
					if slot.count > 0 and slot.itemId ~= fuelId then
						continue
					end
					if fuelId == ids.plank and (need[ids.plank] or 0) > have(ids.plank) then
						continue
					end
					if have(fuelId) < (model.fuelKeep[fuelId] or 0) then
						continue
					end
					local amount = math.min(slotCap(station) - slot.count, have(fuelId))
					if amount > 0 then
						local nextState, accepted = Converter.putFuel(station.state, ctx, fuelId, amount, now)
						if nextState then
							station.state = nextState
							store[fuelId] -= accepted
						end
					end
				end
			end
		end
	end

	-- Ember Trail and quests -------------------------------------------------------------------
	local function payQuest(quest: Types.QuestDef)
		addXp(quest.rewards.xp)
		for _, stack in (quest.rewards.items or {}) :: { Types.ItemStack } do
			add(store, stack.itemId, stack.count)
		end
	end
	-- The first quests are paid in trail order by questTriggers; later ones by laterQuests.
	local function questDone(questId: string): boolean
		local quest = content.Quests[questId]
		return quest ~= nil and (laterPaid[questId] == true or quest.order <= questsPaid)
	end
	local function laterQuest(kind: "craft" | "blackRun", key: string?)
		for _, entry in model.laterQuests do
			local quest = content.Quests[entry.questId]
			local fired = (kind == "craft" and entry.craft == key) or (kind == "blackRun" and entry.blackRun == true)
			if laterPaid[entry.questId] or not fired then
				continue
			end
			if quest.prerequisite and not questDone(quest.prerequisite) then
				continue
			end
			local levelOk = true
			for _, objective in quest.objectives do
				if objective.kind == "reachLevel" and level() < objective.level then
					levelOk = false
				end
			end
			if levelOk then
				laterPaid[entry.questId] = true
				payQuest(quest)
			end
		end
	end

	-- Building ---------------------------------------------------------------------------------
	local function onBuilt(key: string)
		add(built, key, 1)
		trace(`built {key}`)
		local kind, id = string.match(key, "^(%a+):(.+)$")
		if kind == "upgrade" then
			for _, station in stations do
				if station.def.id == id and station.state.level == 1 then
					local ctx = ctxOf(station)
					local now = nowSeconds()
					local back: Types.Slot
					station.state, back = Converter.takeInput(station.state, ctx, nil, now)
					if back.count > 0 then
						add(store, back.itemId, back.count)
					end
					local upgraded = Converter.upgrade(station.state, ctx, now)
					if upgraded then
						station.state = upgraded
					end
					break
				end
			end
		elseif kind == "gate" then
			flags[id :: string] = true
			flagAt[id :: string] = t
		elseif kind == "craft" then
			noteCraft(id :: string, 1)
			if id == model.gunRecipe then
				gunLeft += items[content.Recipes[id :: string].outputs[1].itemId].durability or 0
				stats.gunsCrafted += 1
			end
		else
			local piece = content.BuildPieces[key]
			if piece.stationId then
				newStation(piece.stationId)
			end
		end
		if questsPaid < #model.questTriggers and table.find(model.questTriggers, key) and not flags["q:" .. key] then
			flags["q:" .. key] = true
			questsPaid += 1
			payQuest(questOrder[questsPaid])
		end
	end

	local function canBuild(key: string): boolean
		local kind, id = string.match(key, "^(%a+):(.+)$")
		if kind == "craft" then
			local gate = model.craftGates[id :: string]
			return gate == nil or stationLevel(gate.stationId) >= gate.level
		elseif kind == "upgrade" then
			for _, station in stations do
				if station.def.id == id and station.state.level == 1 then
					return true
				end
			end
			return false
		elseif kind == "gate" then
			return true
		end
		local piece = content.BuildPieces[key]
		local unlock = piece.unlock
		if unlock and unlock.kind == "blueprint" and not flags[unlock.itemId] then
			return false
		end
		local floor = piece.minFoundationTier
		if (piece.kind == "station" or piece.kind == "storage") and floor then
			local found = false
			for builtKey, count in built do
				local def = content.BuildPieces[builtKey]
				if count > 0 and def and def.kind == "foundation" and def.tier >= floor then
					found = true
				end
			end
			if not found then
				return false
			end
		end
		return true
	end

	local function build()
		local progressed = true
		while progressed do
			progressed = false
			local goal = model.goals[goalIndex]
			local left = goalLeft[goalIndex]
			local order: { { key: string, rank: number, sum: number, index: number } } = {}
			for index, piece in goal.pieces do
				if (left[piece.id] or 0) > 0 then
					local rank = if table.find(model.priority, piece.id) then 0 else 1
					table.insert(order, { key = piece.id, rank = rank, sum = costSum(piece.id), index = index })
				end
			end
			table.sort(order, function(a, b)
				if a.rank ~= b.rank then
					return a.rank < b.rank
				elseif a.sum ~= b.sum then
					return a.sum < b.sum
				end
				return a.index < b.index
			end)
			for _, entry in order do
				if canBuild(entry.key) and take(cost(entry.key)) then
					left[entry.key] -= 1
					onBuilt(entry.key)
					progressed = true
					break
				end
			end
			local done = true
			for _, count in left do
				if count > 0 then
					done = false
				end
			end
			for _, flag in (goal.flags or {}) :: { string } do
				if not flags[flag] then
					done = false
				end
			end
			if done then
				if goal.minLevel and level() < goal.minLevel then
					return
				end
				if milestones[goal.name] then
					return
				end
				milestones[goal.name] = t
				trace(`MILESTONE {goal.name}`)
				if goalIndex < #model.goals then
					goalIndex += 1
					progressed = true
				else
					return
				end
			end
		end
	end

	local function craftHand()
		local need = needs()
		local made = content.Recipes["recipe.rope"].outputs[1].count
		local want = (need[ids.cord] or 0) + 2 - have(ids.cord)
		while want > 0 and take(cordRecipe) do
			add(store, ids.cord, made)
			want -= made
		end
	end

	-- Tools ------------------------------------------------------------------------------------
	local function toolRecipe(kind: string, tier: number): string?
		local byTier = model.toolRecipes[kind]
		return if byTier then byTier[tier] else nil
	end
	local function ensureTools(plan: { [string]: number })
		for _, key in sortedKeys(plan) do
			local kind, tierText = string.match(key, "^(%a+)(%d+)$")
			local tier = tonumber(tierText) :: number
			local recipeId = toolRecipe(kind :: string, tier)
			while recipeId and (tools[key] or 0) < plan[key] do
				local recipe = content.Recipes[recipeId]
				if take(handInputs(recipeId)) then
					tools[key] = (tools[key] or 0) + (items[recipe.outputs[1].itemId].durability or 0)
					noteCraft(recipeId, 1)
					if tier >= 2 then
						laterQuest("craft", recipeId)
					end
				else
					break
				end
			end
		end
	end
	local function canMakeTool(kind: string, tier: number): boolean
		local recipeId = toolRecipe(kind, tier)
		if recipeId == nil then
			return false
		end
		for itemId, count in handInputs(recipeId) do
			if have(itemId) < count then
				return false
			end
		end
		return true
	end

	-- Gear and sinks on a run ---------------------------------------------------------------------
	local function gearUp(location: Location)
		local tier = location.tier
		local kills: { [string]: number } = {}
		for _, spawn in location.enemies do
			add(kills, spawn.id, spawn.count * model.killShare)
		end
		local hp = 0
		for _, enemyId in sortedKeys(kills) do
			if not model.stalk[enemyId] then
				local scale = if model.wildlife[enemyId] then 1 else model.hpScale[tier]
				hp += content.Enemies[enemyId].hp * scale * kills[enemyId]
			end
		end
		local gunHp = 0
		local shots = model.gunShotsPerRun[tier] or 0
		if shots > 0 and (built["craft:" .. model.gunRecipe] or 0) > 0 then
			local gunRecipe = content.Recipes[model.gunRecipe]
			local gunItem = items[gunRecipe.outputs[1].itemId]
			if gunLeft < shots and take(handInputs(model.gunRecipe)) then
				gunLeft += gunItem.durability or 0
				stats.gunsCrafted += 1
				noteCraft(model.gunRecipe, 1)
			end
			local rounds = content.Recipes[model.roundsRecipe]
			while have(ids.rounds) < shots and take(handInputs(model.roundsRecipe)) do
				add(store, ids.rounds, rounds.outputs[1].count)
			end
			if gunLeft >= shots and have(ids.rounds) >= shots then
				gunLeft -= shots
				store[ids.rounds] -= shots
				local weapon = gunItem.weapon :: Types.WeaponStats
				gunHp = shots * weapon.damage * model.gunHitShare
				stats.shots += shots
				stats.gunRuns += 1
			end
		end
		local weaponRecipe = if goalIndex >= model.lateWeaponFromGoal then model.lateWeapon else model.earlyWeapon
		local function weaponOf(recipeId: string): Types.ItemDef
			return items[content.Recipes[recipeId].outputs[1].itemId]
		end
		local damage = (weaponOf(weaponRecipe).weapon :: Types.WeaponStats).damage
		local hits = math.max(0, hp - gunHp) / damage
		if meleeLeft < hits then
			for _, recipeId in { weaponRecipe, model.earlyWeapon } do
				if take(handInputs(recipeId)) then
					meleeLeft += weaponOf(recipeId).durability or 0
					noteCraft(recipeId, 1)
					break
				end
			end
		end
		local used = math.min(meleeLeft, hits)
		meleeLeft -= used
		if hits > used + 1 then
			stats.brokenRuns += 1
		end
		local taken = 0
		for enemyId, count in kills do
			if not model.wildlife[enemyId] or not model.stalk[enemyId] then
				taken += count
			end
		end
		taken *= model.hitsTakenPerKill[tier]
		if goalIndex >= model.armorFromGoal then
			for _, recipeId in model.armorRecipes do
				local left = armorLeft[recipeId] or 0
				if left < taken and take(handInputs(recipeId)) then
					left += items[content.Recipes[recipeId].outputs[1].itemId].durability or 0
					noteCraft(recipeId, 1)
				end
				armorLeft[recipeId] = math.max(0, left - taken)
			end
		end
		local dressings = model.dressingsPerRun[tier]
		local dressing = content.Recipes[model.dressingRecipe]
		while have(ids.dressing) < math.ceil(dressings) and take(handInputs(model.dressingRecipe)) do
			add(store, ids.dressing, dressing.outputs[1].count)
			noteCraft(model.dressingRecipe, 1)
		end
		store[ids.dressing] = math.max(0, (store[ids.dressing] or 0) - dressings)
	end

	-- Planning a run ---------------------------------------------------------------------------
	local function stackOf(itemId: string): number
		local item = items[itemId]
		return if item then item.stackSize else 20
	end

	type Plan = { haul: { [string]: number }, xp: number, minutes: number, hits: { [string]: number }, food: number }

	local function planRun(location: Location, short: { [string]: number }): Plan
		local tier = location.tier
		local foodSeconds = 0
		local bag = items[ids.satchel].bagSlots or 0
		if packFrame then
			bag = items[ids.packFrame].bagSlots or bag
		end
		local slots = tuning.inventory.pocketSlots + bag - model.reservedSlots
		local seconds = model.overheadSeconds[tier] + model.extractSeconds[tier]
		local haul: { [string]: number } = {}
		local gained = 0
		local hitsUsed: { [string]: number } = {}
		for _, container in location.containers do
			local count = container.count
			if location.dailyReset then
				count *= math.min(1, model.depotRunsPerDay / math.max(1, depotRunsToday))
			end
			local share = if tier >= 2 then model.contested else 1
			count *= share
			for itemId, units in Loot.expected(model.lootTables, container.tableId, model.bandMultiplier) do
				add(haul, itemId, units * count)
			end
			if location.band2 then
				for itemId, units in Loot.expected(model.lootTables, location.band2) do
					add(haul, itemId, units * count * model.band2Share)
				end
			end
			if location.band3 then
				for itemId, units in Loot.expected(model.lootTables, location.band3) do
					add(haul, itemId, units * count * model.band3Share)
				end
			end
			seconds += count * (container.searchSeconds + 15)
		end
		for _, spawn in location.enemies do
			local kills = spawn.count * model.killShare
			seconds += kills * (model.killSeconds[spawn.id] or 5)
			gained += kills * content.Enemies[spawn.id].xp
			if model.stalk[spawn.id] then
				foodSeconds += kills * (model.killSeconds[spawn.id] or 5)
			end
			for itemId, units in enemyLoot[spawn.id] do
				add(haul, itemId, units * kills)
			end
		end
		local lootSlots = 0
		for itemId, units in haul do
			if units > 0.3 then
				lootSlots += math.ceil(units / stackOf(itemId)) * 0.6
			end
		end
		local slotsLeft = math.max(0, slots - lootSlots)
		type Candidate = { score: number, nodeId: string, count: number, info: NodeInfo }
		local candidates: { Candidate } = {}
		for _, entry in location.nodes do
			local info = infoOf(entry.id)
			if info.kind ~= nil then
				local ok = false
				for toolTier = math.max(1, info.tier), 2 do
					if
						(tools[toolKey(info.kind :: string, toolTier)] or 0) > 0
						or canMakeTool(info.kind :: string, toolTier)
					then
						ok = true
					end
				end
				if not ok then
					continue
				end
			end
			local per = info.units[info.main]
			local value = (model.nodeValues[info.main] or model.nodeValueDefault)
				* (if (short[info.main] or 0) > 0 then 1 else model.offDemand)
			table.insert(candidates, {
				score = value * per / (info.hits * swing + info.overhead),
				nodeId = entry.id,
				count = entry.count,
				info = info,
			})
		end
		table.sort(candidates, function(a: Candidate, b: Candidate)
			if a.score ~= b.score then
				return a.score > b.score
			end
			return a.nodeId > b.nodeId
		end)
		local stacks: { [string]: number } = {}
		local cap = model.runCapMinutes * 60
		for _, candidate in candidates do
			if candidate.score <= 0.001 then
				continue
			end
			local info = candidate.info
			for _ = 1, candidate.count do
				if seconds >= cap then
					break
				end
				local current = stacks[info.main] or 0
				local stack = stackOf(info.main)
				local newSlots = math.ceil((current + info.units[info.main]) / stack - EPSILON)
					- math.ceil(current / stack - EPSILON)
				if newSlots > slotsLeft then
					break
				end
				slotsLeft -= newSlots
				for itemId, units in info.units do
					add(stacks, itemId, units)
				end
				gained += info.xp
				local spent = info.hits * swing + info.overhead
				seconds += spent
				if food[info.main] then
					foodSeconds += spent
				end
				if info.kind ~= nil then
					add(hitsUsed, toolKey(info.kind :: string, math.max(info.tier, 1)), info.hits)
				end
			end
		end
		for itemId, units in stacks do
			add(haul, itemId, units)
		end
		gained += tuning.extraction.xpByTier[tier]
		return { haul = haul, xp = gained, minutes = seconds / 60, hits = hitsUsed, food = foodSeconds / 60 }
	end

	type Choice = { location: Location, walk: boolean, plan: Plan, cost: number }

	local function chooseRun(sessionLeft: number): Choice?
		local short = deficits()
		local need = needs()
		local h, d = foodPoints()
		local values = table.clone(model.values)
		if h < model.hungryBelow then
			for itemId, value in model.hungryValues do
				values[itemId] = value
			end
		end
		if d < model.hungryBelow then
			for itemId, value in model.thirstyValues do
				values[itemId] = value
			end
		end
		local current = level()
		local gated = false
		for _, location in model.locations do
			if location.level > current then
				gated = true
			end
		end
		local best: Choice? = nil
		local bestRate = -math.huge
		for _, location in model.locations do
			if current < location.level then
				continue
			end
			if location.gate and not flags[location.gate] then
				continue
			end
			local plan = planRun(location, short)
			local value = 0
			for itemId, units in plan.haul do
				local wanted = if short[itemId] ~= nil then short[itemId] else (need[itemId] or 0) - have(itemId)
				wanted = if wanted > 0 then math.max(wanted, model.demandFloor) else 0
				value += (values[itemId] or model.valueDefault) * (math.min(units, wanted) + model.hoard * units)
			end
			value *= model.keep[location.tier]
			value += plan.xp * (if gated then model.xpWeightGated else model.xpWeight)
			local walk: boolean? = nil
			local spend = 0
			if energy >= location.energy then
				walk, spend = false, plan.minutes + 0.1
			elseif sessionLeft >= location.walkMinutes + plan.minutes + model.homeMinutes then
				walk, spend = true, location.walkMinutes + plan.minutes
			end
			if walk == nil or sessionLeft < plan.minutes + 1 then
				continue
			end
			local rate = value / (spend + model.energyWeight * (if walk then 0 else location.energy))
			if best == nil or rate > bestRate then
				best = { location = location, walk = walk :: boolean, plan = plan, cost = spend }
				bestRate = rate
			end
		end
		return best
	end

	-- Home -------------------------------------------------------------------------------------
	local function advance(minutes: number, regen: boolean)
		eat(minutes)
		tickStations(minutes)
		if regen then
			energy = math.min(tuning.energy.cap, energy + minutes * 60 / tuning.energy.secondsPerPoint)
		end
		t += minutes
	end

	local function gatherHome()
		if (tools[toolKey("hatchet", 1)] or 0) == 0 or (tools[toolKey("pick", 1)] or 0) == 0 then
			for _, nodeId in sortedKeys(homeNodes) do
				local info = infoOf(nodeId)
				local count = homeNodes[nodeId]
				if info.kind == nil and count > 0 then
					for itemId, units in info.units do
						add(store, itemId, units * count)
					end
					addXp(info.xp * count)
					homeNodes[nodeId] = 0
				end
			end
			ensureTools({ [toolKey("hatchet", 1)] = 40, [toolKey("pick", 1)] = 40 })
		end
		local minutes = 0
		for _, nodeId in sortedKeys(homeNodes) do
			local count = homeNodes[nodeId]
			if count <= 0 then
				continue
			end
			local info = infoOf(nodeId)
			if info.kind ~= nil then
				local key = toolKey(info.kind :: string, 1)
				local needHits = info.hits * count
				ensureTools({ [key] = needHits })
				local use = math.min(needHits, tools[key] or 0)
				count = use // info.hits
				tools[key] = (tools[key] or 0) - count * info.hits
			end
			for itemId, units in info.units do
				add(store, itemId, units * count)
			end
			addXp(info.xp * count)
			minutes += count * (info.hits * swing + info.overhead) / 60
			homeNodes[nodeId] = 0
		end
		advance(math.ceil(minutes) + 3, false)
	end

	local function homeActions()
		craftHand()
		build()
		refill()
		build()
	end

	-- The clock ----------------------------------------------------------------------------------
	local dayEnd = model.days * DAY
	local lastDay = -1
	while t < dayEnd do
		local day = t // DAY
		if day ~= lastDay then
			depotRunsToday = 0
			lastDay = day
		end
		local sessionEnd: number? = nil
		for _, session in model.sessions do
			local start = day * DAY + session.start
			if start <= t and t < start + session.minutes then
				sessionEnd = start + session.minutes
			end
		end
		if sessionEnd == nil then
			local nextStart: number? = nil
			for _, session in model.sessions do
				local start = day * DAY + session.start
				if start > t then
					nextStart = start
					break
				end
			end
			local target = nextStart or ((day + 1) * DAY + model.sessions[1].start)
			local gap = target - t
			tickStations(gap)
			energy = math.min(tuning.energy.cap, energy + gap * 60 / tuning.energy.secondsPerPoint)
			t = target
			continue
		end
		homeActions()
		if spring and t >= springReadyAt then
			local springDef = content.Nodes[spring.nodeId]
			for itemId, units in Gathering.expectedYield(springDef) do
				add(store, itemId, units * spring.count)
			end
			springReadyAt = t + springDef.respawnSeconds / 60
		end
		advance(model.homeMinutes, true)
		local sessionLeft = (sessionEnd :: number) - t
		if sessionLeft <= 2 then
			continue
		end
		local anyHome = false
		for _, count in homeNodes do
			if count > 0 then
				anyHome = true
			end
		end
		if anyHome then
			gatherHome()
			continue
		end
		local choice = chooseRun(sessionLeft)
		if choice == nil then
			advance(math.min(10, sessionLeft), true)
			continue
		end
		local location = choice.location
		stats.runMinutes += choice.cost
		stats.foodMinutes += choice.plan.food
		stats.runs += 1
		if not choice.walk then
			energy -= location.energy
		end
		if location.dailyReset then
			depotRunsToday += 1
		end
		ensureTools(choice.plan.hits)
		gearUp(location)
		for key, used in choice.plan.hits do
			tools[key] = math.max(0, (tools[key] or 0) - used)
		end
		local keep = model.keep[location.tier]
		for itemId, units in choice.plan.haul do
			add(store, itemId, units * keep)
		end
		if have(ids.plans) >= 1 then
			flags[ids.plans] = true
		end
		if have(ids.packSchematic) >= 1 then
			packFrame = true
		end
		addXp(choice.plan.xp)
		if location.tier >= 3 then
			laterQuest("blackRun", nil)
		end
		table.insert(stats.runsAt, { minute = t, locationId = location.id, walk = choice.walk })
		trace(`run {location.id}{if choice.walk then " (walk)" else ""} {string.format("%.1f", choice.cost)} min`)
		advance(math.ceil(choice.cost - EPSILON), true)
	end

	return {
		milestones = milestones,
		levelAt = levelAt,
		flagAt = flagAt,
		level = level(),
		xp = xp,
		stats = stats,
		store = store,
	}
end

return PacingSim
