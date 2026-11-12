--!strict
--[[
	AutoPlan: the decisions of the Studio-only AutoPlayer (Controllers/AutoPlayer), a simple
	utility AI that plays the game as a player would, to find bugs and pace the grind
	(2026-11-12, the developer: "play the game legit and natural like a real person would").
	Pure: the controller reads the synced state into a Context and carries out the Step.

	Priorities, re-evaluated about twice a second:
	1. Survive: drink, eat or dress a wound when a meter runs low (`survive`).
	2. On a run: fight what is close, loot, extract when the bag fills or time runs out
	   (`onRun`).
	3. At home: take what a station has ready, then the Ember Trail's next objective, then
	   the starter base's next piece, then the tier-2 goal (`atHome`).
	Each goal comes down to an item the player needs (`obtain`): carried or in the home pool
	already, made by hand or at a station (building the station first), gathered from a
	home node (making the tool first), or found on a Fog Run when home has none left.
	A goal that waits on a station's timer lets the next goal run meanwhile.
]]

local AutoPlan = {}

export type Counts = { [string]: number }

-- One of the player's stations, as the planner needs it.
export type StationView = {
	uid: string,
	stationId: string,
	busy: boolean, -- converting now
	inputItemId: string, -- what is in the input ("" when empty)
	inputCount: number,
	ready: Counts, -- output items waiting
	fuelSeconds: number, -- lit and unlit fuel left
	fuelled: boolean, -- the station burns fuel
}

export type Context = {
	carried: Counts, -- pockets and backpack
	home: Counts, -- carried plus the home pool (crates, inbox): what costs are paid from
	equipped: { [string]: boolean },
	tools: Counts, -- the best carried tier of each tool kind ("hatchet", "pick")
	health: number,
	hunger: number,
	thirst: number,
	recipeOpen: { [string]: boolean },
	pieceOpen: { [string]: boolean },
	stations: { [string]: StationView }, -- by station id
	standing: Counts, -- the player's home nodes still standing, by node id
	recipes: { [string]: any }, -- Data/Recipes
	items: { [string]: any }, -- Data/Items
	nodes: { [string]: any }, -- Data/Nodes
	pieces: { [string]: any }, -- Data/BuildPieces
}

export type StepKind =
	"drink"
	| "eat"
	| "heal"
	| "gather"
	| "craft"
	| "load"
	| "collect"
	| "build"
	| "upgrade"
	| "equip"
	| "use"
	| "run"
	| "wait"
	| "idle"

export type Step = {
	kind: StepKind,
	why: string,
	itemId: string?,
	recipeId: string?,
	pieceId: string?,
	stationId: string?,
	nodeIds: { string }?,
	count: number?,
	locationId: string?,
}

-- Meters: act below these (the HUD warns at 20; a player tops up well before).
AutoPlan.DRINK_BELOW = 45
AutoPlan.EAT_BELOW = 45
AutoPlan.HEAL_BELOW = 55
-- How deep the item chain may go (timber -> plank -> workbench -> ...).
local MAX_DEPTH = 7
-- Fuel a fuelled station should hold before a load: about one batch's worth.
local FUEL_ITEMS = { "item.fatwood", "item.timber", "item.sticks" }
local TOOL_ITEMS: { [string]: string } = { hatchet = "item.stone_hatchet", pick = "item.stone_pick" }
local HOME_RUN = "loc.pine_hollow"

local function step(kind: StepKind, why: string, extra: { [string]: any }?): Step
	local made: any = { kind = kind, why = why }
	if extra then
		for key, value in extra do
			made[key] = value
		end
	end
	return made
end

-- Survival -----------------------------------------------------------------------------------------

-- The carried consumable that restores the most of `meter` (nil when none restores it).
function AutoPlan.bestFor(ctx: Context, meter: string): string?
	local best, bestValue = nil, 0
	for itemId, count in ctx.carried do
		local def = ctx.items[itemId]
		local consume = def and def.consume
		local value = if consume then consume[meter] or 0 else 0
		if count > 0 and value > bestValue then
			best, bestValue = itemId, value
		end
	end
	return best
end

-- Drink, eat or dress a wound when a meter is low and something carried helps.
function AutoPlan.survive(ctx: Context): Step?
	if ctx.thirst < AutoPlan.DRINK_BELOW then
		local itemId = AutoPlan.bestFor(ctx, "thirst")
		if itemId then
			return step("drink", `thirst {math.floor(ctx.thirst)}`, { itemId = itemId })
		end
	end
	if ctx.hunger < AutoPlan.EAT_BELOW then
		local itemId = AutoPlan.bestFor(ctx, "hunger")
		if itemId then
			return step("eat", `hunger {math.floor(ctx.hunger)}`, { itemId = itemId })
		end
	end
	if ctx.health < AutoPlan.HEAL_BELOW then
		local itemId = AutoPlan.bestFor(ctx, "health")
		if itemId then
			return step("heal", `health {math.floor(ctx.health)}`, { itemId = itemId })
		end
	end
	return nil
end

-- Item chains -------------------------------------------------------------------------------------

local function makers(ctx: Context, itemId: string): { any }
	local list = {}
	for _, recipe in ctx.recipes do
		local out = recipe.outputs and recipe.outputs[1]
		if out and out.itemId == itemId and ctx.recipeOpen[recipe.id] then
			table.insert(list, recipe)
		end
	end
	-- Hand recipes first, then by id, so the choice is stable.
	table.sort(list, function(a, b)
		local ah, bh = a.stationId == nil, b.stationId == nil
		if ah ~= bh then
			return ah
		end
		return a.id < b.id
	end)
	return list
end

local function stationPiece(ctx: Context, stationId: string): string?
	for id, def in ctx.pieces do
		if def.stationId == stationId and def.upgradesTo == nil and (def.tier or 1) == 1 then
			return id
		end
	end
	for id, def in ctx.pieces do
		if def.stationId == stationId then
			return id
		end
	end
	return nil
end

-- Home nodes that yield `itemId` for sure (not as a chance), with one standing.
function AutoPlan.nodesFor(ctx: Context, itemId: string): { string }
	local list = {}
	for nodeId, def in ctx.nodes do
		if (ctx.standing[nodeId] or 0) > 0 then
			for _, entry in def.yields or {} do
				if entry.itemId == itemId and entry.chance == nil then
					table.insert(list, nodeId)
					break
				end
			end
		end
	end
	table.sort(list)
	return list
end

local obtain: (ctx: Context, itemId: string, count: number, depth: number) -> Step?

-- Everything a cost list needs first, or nil when it is all at hand.
local function obtainAll(ctx: Context, cost: { any }, times: number, depth: number): Step?
	for _, entry in cost do
		local missing = obtain(ctx, entry.itemId, entry.count * times, depth + 1)
		if missing then
			return missing
		end
	end
	return nil
end

-- What to do to have `count` of `itemId` at home, or nil when it is already there.
obtain = function(ctx: Context, itemId: string, count: number, depth: number): Step?
	local have = ctx.home[itemId] or 0
	if have >= count then
		return nil
	end
	if depth > MAX_DEPTH then
		return step("run", `{itemId}: too deep a chain`, { itemId = itemId, locationId = HOME_RUN })
	end
	local short = count - have
	for _, recipe in makers(ctx, itemId) do
		local out = recipe.outputs[1]
		local batches = math.max(1, math.ceil(short / math.max(1, out.count)))
		if recipe.stationId == nil then
			return obtainAll(ctx, recipe.inputs, batches, depth)
				or step("craft", `{itemId} by hand`, { recipeId = recipe.id, itemId = itemId, count = batches })
		end
		local station = ctx.stations[recipe.stationId]
		if station == nil then
			local pieceId = stationPiece(ctx, recipe.stationId)
			if pieceId and ctx.pieceOpen[pieceId] then
				return AutoPlan.buildStep(ctx, pieceId, depth + 1)
			end
			continue -- no way to that station yet: another recipe, or a node
		end
		if (station.ready[itemId] or 0) > 0 then
			return step("collect", `{itemId} is ready`, { stationId = recipe.stationId, itemId = itemId })
		end
		local input = recipe.inputs[1]
		if station.busy and station.inputItemId == input.itemId then
			return step("wait", `{recipe.stationId} is making {itemId}`, { stationId = recipe.stationId })
		end
		-- The input has to be carried to drag it in: count only the bag here.
		if (ctx.carried[input.itemId] or 0) < input.count then
			local missing = obtain(ctx, input.itemId, input.count * batches, depth + 1)
			if missing then
				return missing
			end
			if (ctx.carried[input.itemId] or 0) < input.count then
				return step("wait", `{input.itemId} is in a crate`, { itemId = input.itemId })
			end
		end
		if station.fuelled and station.fuelSeconds <= 0 then
			local fuel = nil
			for _, fuelId in FUEL_ITEMS do
				if (ctx.carried[fuelId] or 0) > 0 then
					fuel = fuelId
					break
				end
			end
			if fuel == nil then
				return obtain(ctx, "item.timber", (ctx.home["item.timber"] or 0) + 2, depth + 1)
					or step("wait", "fuel is in a crate", { itemId = "item.timber" })
			end
		end
		return step(
			"load",
			`{recipe.stationId}: {itemId}`,
			{ stationId = recipe.stationId, recipeId = recipe.id, itemId = input.itemId, count = batches }
		)
	end
	local usable, toolItem = AutoPlan.usableNodes(ctx, itemId)
	if #usable > 0 then
		return step("gather", `{itemId} for {count}`, { itemId = itemId, nodeIds = usable, count = short })
	end
	-- Only nodes that need a tool: make the tool, unless the tool itself needs this item
	-- from such a node (stone for the pick from a boulder: the loose stones come first).
	if toolItem and depth < MAX_DEPTH then
		local missing = obtain(ctx, toolItem, 1, depth + 1)
		if missing and missing.kind ~= "run" then
			return missing
		elseif missing == nil then
			-- Made but in a crate or the inbox: wait for the controller to take it.
			return step("wait", `{toolItem} is not in the bag`, { itemId = toolItem })
		end
	end
	return step("run", `{itemId}: none left at home`, { itemId = itemId, locationId = HOME_RUN })
end

--[[
	The standing home nodes for `itemId` the carried tools can harvest now, and the tier-1
	tool item that would open the rest (nil when none needs one).
]]
function AutoPlan.usableNodes(ctx: Context, itemId: string): ({ string }, string?)
	local usable: { string } = {}
	local toolItem: string? = nil
	for _, nodeId in AutoPlan.nodesFor(ctx, itemId) do
		local tool = ctx.nodes[nodeId].tool
		if tool == nil or (ctx.tools[tool.kind] or 0) >= tool.tier then
			table.insert(usable, nodeId)
		elseif tool.tier <= 1 and toolItem == nil then
			toolItem = TOOL_ITEMS[tool.kind]
		end
	end
	return usable, toolItem
end

function AutoPlan.obtain(ctx: Context, itemId: string, count: number): Step?
	return obtain(ctx, itemId, count, 0)
end

-- Placing a piece: its cost first, then the placement.
function AutoPlan.buildStep(ctx: Context, pieceId: string, depth: number?): Step
	local def = ctx.pieces[pieceId]
	if def == nil or not ctx.pieceOpen[pieceId] then
		return step("wait", `{pieceId} is locked`, { pieceId = pieceId })
	end
	return obtainAll(ctx, def.cost or {}, 1, depth or 0) or step("build", pieceId, { pieceId = pieceId })
end

-- Upgrading a placed piece into `pieceId`: the upgrade's cost first.
function AutoPlan.upgradeStep(ctx: Context, pieceId: string): Step
	local def = ctx.pieces[pieceId]
	if def == nil or not ctx.pieceOpen[pieceId] then
		return step("wait", `{pieceId} is locked`, { pieceId = pieceId })
	end
	return obtainAll(ctx, def.cost or {}, 1, 0) or step("upgrade", pieceId, { pieceId = pieceId })
end

-- Quests ---------------------------------------------------------------------------------------------

-- The step toward one Ember Trail objective, `need - have` short.
function AutoPlan.objectiveStep(ctx: Context, objective: any, have: number, need: number): Step
	local kind = objective.kind
	local left = math.max(1, need - have)
	if kind == "gather" then
		-- Gathering counts swings, not holdings: gather even when the bag already has some.
		local usable, toolItem = AutoPlan.usableNodes(ctx, objective.itemId)
		if #usable > 0 then
			return step("gather", `quest: gather {objective.itemId}`, {
				itemId = objective.itemId,
				nodeIds = usable,
				count = left,
			})
		elseif toolItem then
			return obtain(ctx, toolItem, 1, 0) or step("wait", `{toolItem} is not in the bag`, { itemId = toolItem })
		end
		return step("run", `gather {objective.itemId}: none at home`, {
			itemId = objective.itemId,
			locationId = HOME_RUN,
		})
	elseif kind == "craft" then
		local recipe = ctx.recipes[objective.recipeId]
		if recipe == nil then
			return step("idle", `unknown recipe {objective.recipeId}`)
		end
		local out = recipe.outputs[1]
		if recipe.stationId then
			-- A station objective counts what is taken out: make `left` more than now held.
			return obtain(ctx, out.itemId, (ctx.home[out.itemId] or 0) + left * out.count, 0)
				or step("collect", `quest: {out.itemId}`, { stationId = recipe.stationId, itemId = out.itemId })
		end
		return obtainAll(ctx, recipe.inputs, left, 0)
			or step("craft", `quest: craft {objective.recipeId}`, {
				recipeId = objective.recipeId,
				itemId = out.itemId,
				count = left,
			})
	elseif kind == "equip" then
		if (ctx.carried[objective.itemId] or 0) > 0 then
			return step("equip", `quest: equip {objective.itemId}`, { itemId = objective.itemId })
		end
		return obtain(ctx, objective.itemId, 1, 0)
			or step("wait", `{objective.itemId} is not in the bag`, { itemId = objective.itemId })
	elseif kind == "consume" then
		if (ctx.carried[objective.itemId] or 0) > 0 then
			return step("use", `quest: use {objective.itemId}`, { itemId = objective.itemId })
		end
		return obtain(ctx, objective.itemId, 1, 0)
			or step("wait", `{objective.itemId} is not in the bag`, { itemId = objective.itemId })
	elseif kind == "build" then
		return AutoPlan.buildStep(ctx, objective.pieceId)
	elseif kind == "travel" then
		return step("run", "quest: travel", { locationId = objective.locationId or HOME_RUN })
	elseif kind == "kill" or kind == "lootBody" or kind == "loot" or kind == "reachLevel" then
		return step("run", `quest: {kind}`, { locationId = objective.locationId or HOME_RUN })
	end
	return step("idle", `objective {kind}`)
end

-- Home -----------------------------------------------------------------------------------------------

export type Goals = {
	objective: any?, -- the tracker's next objective
	have: number?,
	need: number?,
	base: { string }, -- the starter base's pieces still to place, in order
	upgrade: string?, -- the tier-2 goal: the piece to upgrade into
}

--[[
	The next step at home. A goal that only waits on a station gives way to the next one;
	when every goal waits, the first wait stands (the controller tends the station).
]]
function AutoPlan.atHome(ctx: Context, goals: Goals): Step
	local survival = AutoPlan.survive(ctx)
	if survival then
		return survival
	end
	for stationId, station in ctx.stations do
		for itemId, count in station.ready do
			if count > 0 then
				return step("collect", `{itemId} is ready`, { stationId = stationId, itemId = itemId })
			end
		end
	end
	local candidates: { Step } = {}
	if goals.objective then
		table.insert(candidates, AutoPlan.objectiveStep(ctx, goals.objective, goals.have or 0, goals.need or 1))
	end
	for _, pieceId in goals.base do
		local piece = ctx.pieces[pieceId]
		if piece and ctx.pieceOpen[pieceId] then
			table.insert(candidates, AutoPlan.buildStep(ctx, pieceId))
			break
		end
	end
	if goals.upgrade then
		table.insert(candidates, AutoPlan.upgradeStep(ctx, goals.upgrade))
	end
	local firstWait: Step? = nil
	for _, candidate in candidates do
		if candidate.kind == "wait" or candidate.kind == "idle" then
			firstWait = firstWait or candidate
		else
			return candidate
		end
	end
	return firstWait or step("idle", "nothing to do")
end

-- Runs -----------------------------------------------------------------------------------------------

export type RunView = {
	hollowDistance: number?, -- the nearest Hollow, studs
	hollowCount: number, -- Hollows within 30 studs
	containerDistance: number?, -- the nearest unsearched container
	nodeDistance: number?, -- the nearest node that yields something home needs (RUN_GATHER)
	exitDistance: number?,
	bagFree: number, -- empty bag slots
	minutesLeft: number?, -- before the lobby closes (nil when unknown)
	armed: boolean, -- a weapon in hand
	goalsMet: boolean, -- the run's quest goals are done (kills, loot)
	elapsed: number, -- seconds on this run
}

AutoPlan.FIGHT_STUDS = 22
AutoPlan.FLEE_HEALTH = 35
AutoPlan.LEAVE_MINUTES = 3
AutoPlan.MAX_RUN_SECONDS = 420

export type RunStep = "fight" | "flee" | "loot" | "gather" | "extract" | "explore" | "drink" | "eat" | "heal"

-- What a run's nodes are worth gathering for: home's nodes never regrow, so the base's
-- timber, stone, rope fibre and water come from the Fog once they are gone.
AutoPlan.RUN_GATHER = {
	"item.timber",
	"item.stone",
	"item.fiber",
	"item.sticks",
	"item.murky_water",
	"item.emberberry",
	"item.ashroot",
}

--[[
	A run's next move: survive, fight what is close (back off when hurt), leave when the bag
	is full or time is short, else loot the containers, then gather what home needs, then
	leave.
]]
function AutoPlan.onRun(ctx: Context, run: RunView): (RunStep, string, string?)
	local survival = AutoPlan.survive(ctx)
	if survival then
		return (survival.kind :: any) :: RunStep, survival.why, survival.itemId
	end
	if ctx.health < AutoPlan.FLEE_HEALTH and run.hollowDistance and run.hollowDistance < AutoPlan.FIGHT_STUDS then
		return "flee", `health {math.floor(ctx.health)}`, nil
	end
	if run.hollowDistance and run.hollowDistance < AutoPlan.FIGHT_STUDS and run.armed then
		return "fight", `Hollow at {math.floor(run.hollowDistance)}`, nil
	end
	local timeUp = (run.minutesLeft ~= nil and run.minutesLeft < AutoPlan.LEAVE_MINUTES)
		or run.elapsed > AutoPlan.MAX_RUN_SECONDS
	if run.bagFree <= 0 or timeUp or ctx.health < AutoPlan.FLEE_HEALTH then
		return "extract", if run.bagFree <= 0 then "bag full" else "time to go", nil
	end
	if run.containerDistance then
		return "loot", "a container", nil
	end
	if run.nodeDistance then
		return "gather", "a node home needs", nil
	end
	if run.goalsMet or run.elapsed > 120 then
		return "extract", "nothing left close", nil
	end
	return "explore", "looking for loot", nil
end

return AutoPlan
