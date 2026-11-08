--!strict
--[[
	Containers: searchable crates, lockers, trunks and cabinets on a Fog Run
	(checklist 12.4; GAME_DESIGN "Rules by fog tier").

	- E starts a search that takes searchSeconds (the location's container entry,
	  else Tuning.containers.searchSeconds). Damage or walking off interrupts it;
	  the service simply drops the search record.
	- Light fog rolls loot per player ("personal"): everyone who searches a crate
	  gets their own roll, and a crate is searched once per player. Dense and Black
	  share one roll ("shared"): the first search to finish rolls it, and everyone
	  after takes from what is left. A searched container looks open either way.
	- Loot scales with the Fog meter (Domain/Lobby band): the base table is rolled
	  lootMultiplier times on average (the fraction rolls an extra open), and every
	  band table unlocked so far (Location.run.bandLoot) adds one open each. Rolls
	  go through Domain/Loot, so nesting and pity work as everywhere else.

	State is a plain record per container, mutated in place. Pure.
]]

local Types = require("../Types")
local Loot = require("./Loot")
local Plane = require("./Plane")
local Rng = require("./Rng")

local Containers = {}

export type Config = Types.ContainersTuning
export type Mode = "personal" | "shared"

export type State = {
	id: string,
	kind: string,
	lootTableId: Types.LootTableId,
	searchSeconds: number,
	mode: Mode,
	position: Plane.Point?,
	shared: { Types.ItemStack }?, -- shared mode: the one roll, once searched
	personal: { [number]: { Types.ItemStack } }, -- personal mode: each player's roll
}

export type Search = {
	containerId: string,
	userId: number,
	startedAt: number,
	endsAt: number,
}

export type Spec = {
	id: string,
	kind: string?,
	lootTableId: Types.LootTableId,
	searchSeconds: number?,
	position: Plane.Point?,
}

export type Scaling = {
	lootMultiplier: number, -- the meter band's (Types.MeterBand)
	bandTableIds: { Types.LootTableId }, -- band tables unlocked so far, in band order
}

export type RollContext = {
	tables: Loot.Tables,
	rng: Rng.Source,
	items: Loot.RarityLookup?,
	pity: Loot.PityState?,
	scaling: Scaling,
}

export type SearchReason = "searched" | "notFound"
export type TakeReason = "notSearched" | "badSlot"

-- The loot mode for a fog tier.
function Containers.modeFor(fogTier: number, config: Config): Mode
	return config.lootModeByTier[fogTier] or config.lootModeByTier[#config.lootModeByTier]
end

function Containers.new(spec: Spec, fogTier: number, config: Config): State
	return {
		id = spec.id,
		kind = spec.kind or "crate",
		lootTableId = spec.lootTableId,
		searchSeconds = spec.searchSeconds or config.searchSeconds,
		mode = Containers.modeFor(fogTier, config),
		position = spec.position,
		shared = nil,
		personal = {},
	}
end

-- What `userId` sees inside, or nil while it is unsearched for them.
function Containers.view(state: State, userId: number): { Types.ItemStack }?
	if state.mode == "shared" then
		return state.shared
	end
	return state.personal[userId]
end

function Containers.isSearched(state: State, userId: number): boolean
	return Containers.view(state, userId) ~= nil
end

-- Whether anyone has opened it (the open-lid look for everyone in shared mode).
function Containers.isOpened(state: State): boolean
	return state.shared ~= nil or next(state.personal) ~= nil
end

--[[
	Starts a search. Returns nil and "searched" when the player already sees its
	contents (the loot panel just opens).
]]
function Containers.beginSearch(state: State, userId: number, now: number): (Search?, SearchReason?)
	if Containers.isSearched(state, userId) then
		return nil, "searched"
	end
	return { containerId = state.id, userId = userId, startedAt = now, endsAt = now + state.searchSeconds }, nil
end

function Containers.isDone(search: Search, now: number): boolean
	return now >= search.endsAt
end

function Containers.progress(search: Search, now: number): number
	local length = search.endsAt - search.startedAt
	if length <= 0 then
		return 1
	end
	return math.clamp((now - search.startedAt) / length, 0, 1)
end

-- How many times the base table opens for a multiplier (1.25 is 1, plus 1 a quarter of the time).
function Containers.opens(multiplier: number, rng: Rng.Source): number
	local whole = math.floor(math.max(1, multiplier))
	local fraction = math.max(1, multiplier) - whole
	if fraction > 0 and rng:NextNumber() < fraction then
		whole += 1
	end
	return whole
end

local function merge(into: { Types.ItemStack }, stacks: { Types.ItemStack })
	for _, stack in stacks do
		local merged = false
		for _, existing in into do
			if existing.itemId == stack.itemId then
				existing.count += stack.count
				merged = true
				break
			end
		end
		if not merged then
			table.insert(into, { itemId = stack.itemId, count = stack.count })
		end
	end
end

-- Rolls one container's loot with the band scaling. Returns the stacks and pity.
function Containers.roll(lootTableId: Types.LootTableId, ctx: RollContext): ({ Types.ItemStack }, Loot.PityState)
	local loot: { Types.ItemStack } = {}
	local pity = ctx.pity or {}
	local tableIds: { string } = {}
	for _ = 1, Containers.opens(ctx.scaling.lootMultiplier, ctx.rng) do
		table.insert(tableIds, lootTableId)
	end
	for _, bandTableId in ctx.scaling.bandTableIds do
		table.insert(tableIds, bandTableId)
	end
	for _, tableId in tableIds do
		local result = Loot.roll(ctx.tables, tableId, ctx.rng, { items = ctx.items, pity = pity })
		pity = result.pity
		merge(loot, result.items)
	end
	return loot, pity
end

--[[
	Finishes a search that has run its time. Rolls the loot (or, in shared mode,
	shows the roll someone else finished first) and returns what the player now
	sees plus the updated pity state. Nil before the search is done.
]]
function Containers.complete(
	state: State,
	search: Search,
	now: number,
	ctx: RollContext
): ({ Types.ItemStack }?, Loot.PityState)
	local pity = ctx.pity or {}
	if not Containers.isDone(search, now) or search.containerId ~= state.id then
		return nil, pity
	end
	local existing = Containers.view(state, search.userId)
	if existing then
		return existing, pity
	end
	local loot, nextPity = Containers.roll(state.lootTableId, ctx)
	if state.mode == "shared" then
		state.shared = loot
	else
		state.personal[search.userId] = loot
	end
	return loot, nextPity
end

-- Takes one stack (or `count` of it) from what the player sees.
function Containers.take(state: State, userId: number, index: number, count: number?): (Types.ItemStack?, TakeReason?)
	local view = Containers.view(state, userId)
	if view == nil then
		return nil, "notSearched"
	end
	local stack = view[index]
	if stack == nil then
		return nil, "badSlot"
	end
	local taken = math.clamp(count or stack.count, 1, stack.count)
	if taken == stack.count then
		table.remove(view, index)
	else
		stack.count -= taken
	end
	return { itemId = stack.itemId, count = taken }, nil
end

-- Takes everything the player sees (the service puts back what doesn't fit).
function Containers.takeAll(state: State, userId: number): { Types.ItemStack }
	local view = Containers.view(state, userId)
	if view == nil then
		return {}
	end
	local all = table.clone(view)
	table.clear(view)
	return all
end

-- Returns stacks that didn't fit the player's bag.
function Containers.putBack(state: State, userId: number, stacks: { Types.ItemStack })
	local view = Containers.view(state, userId)
	if view then
		merge(view, stacks)
	end
end

-- The band tables a location has unlocked at meter band `band` (Location.run.bandLoot).
function Containers.bandTables(bandLoot: { Types.BandLoot }, band: number): { Types.LootTableId }
	local sorted = table.clone(bandLoot)
	table.sort(sorted, function(a: Types.BandLoot, b: Types.BandLoot): boolean
		return a.band < b.band
	end)
	local ids: { Types.LootTableId } = {}
	for _, entry in sorted do
		if entry.band <= band then
			table.insert(ids, entry.lootTableId)
		end
	end
	return ids
end

return Containers
