--!strict
--[[
	AutoClear: the location panel's paid AUTO (LDOE_PARITY #31). It clears a
	location into the inbox without entering it. Pure.

	Payment (the ad and premium flows are S3; this decides what is allowed):
	- "ad": a rewarded ad, adPerDay times a UTC day, from adMinLevel
	- "rations": Tuning.autoClear.rationsByTier Rations for the location's tier
	- "premium": always allowed here; the shop charges it

	The haul is what a careful run at the start of a lobby would bring home:
	every container at its rolled count (meter band 1, no band loot), a share of
	the resource nodes fully harvested, and a share of the band-1 Hollow killed
	with their loot. XP is paid for the nodes and kills. Entering pays better:
	band loot, every node, Trigger Groups.
]]

local Types = require("../Types")
local HollowAI = require("./HollowAI")
local Loot = require("./Loot")
local Rng = require("./Rng")

local AutoClear = {}

export type Config = Types.AutoClearTuning
export type Method = "ad" | "rations" | "premium"
export type Reason = "level" | "noAds" | "rations"

export type DailyState = { day: number, adsUsed: number }

export type Haul = {
	items: { Types.ItemStack },
	xp: number,
	kills: number,
	containers: number,
}

export type Context = {
	tables: Loot.Tables,
	nodes: { [string]: Types.ResourceNodeDef },
	enemies: { [string]: Types.EnemyDef },
	items: Loot.RarityLookup?,
	rng: Rng.Source,
	config: Config,
}

local DAY = 24 * 60 * 60

function AutoClear.today(now: number): number
	return now // DAY
end

-- Ads left today.
function AutoClear.adsLeft(state: DailyState, now: number, config: Config): number
	local used = if state.day == AutoClear.today(now) then state.adsUsed else 0
	return math.max(0, config.adPerDay - used)
end

-- Rations an AUTO clear of a location of `fogTier` costs.
function AutoClear.rationsCost(fogTier: number, config: Config): number
	return config.rationsByTier[fogTier] or config.rationsByTier[#config.rationsByTier]
end

--[[
	Whether the player may pay with `method` now. `rationsCarried` only matters for
	"rations". Returns ok and, when not, why.
]]
function AutoClear.canPay(
	method: Method,
	fogTier: number,
	level: number,
	daily: DailyState,
	rationsCarried: number,
	now: number,
	config: Config
): (boolean, Reason?)
	if method == "ad" then
		if level < config.adMinLevel then
			return false, "level"
		end
		if AutoClear.adsLeft(daily, now, config) <= 0 then
			return false, "noAds"
		end
	elseif method == "rations" then
		if rationsCarried < AutoClear.rationsCost(fogTier, config) then
			return false, "rations"
		end
	end
	return true, nil
end

-- Records one ad clear today.
function AutoClear.useAd(state: DailyState, now: number): DailyState
	local today = AutoClear.today(now)
	return { day = today, adsUsed = (if state.day == today then state.adsUsed else 0) + 1 }
end

local function merge(into: { Types.ItemStack }, itemId: string, count: number)
	if count <= 0 then
		return
	end
	for _, stack in into do
		if stack.itemId == itemId then
			stack.count += count
			return
		end
	end
	table.insert(into, { itemId = itemId, count = count })
end

-- `share` of `count`, with the fraction rolled (2.5 is 2 or 3).
local function portion(count: number, share: number, rng: Rng.Source): number
	local exact = count * share
	local whole = math.floor(exact)
	if rng:NextNumber() < exact - whole then
		whole += 1
	end
	return whole
end

-- Rolls everything an AUTO clear of `location` brings home.
function AutoClear.roll(location: Types.LocationDef, ctx: Context): Haul
	local haul: Haul = { items = {}, xp = 0, kills = 0, containers = 0 }
	local pity: Loot.PityState = {}
	local function open(tableId: string)
		local result = Loot.roll(ctx.tables, tableId, ctx.rng, { items = ctx.items, pity = pity })
		pity = result.pity
		for _, stack in result.items do
			merge(haul.items, stack.itemId, stack.count)
		end
	end

	for _, container in location.containers do
		for _ = 1, ctx.rng:NextInteger(container.count.min, container.count.max) do
			open(container.lootTableId)
			haul.containers += 1
		end
	end

	for _, entry in location.nodes do
		local node = ctx.nodes[entry.nodeId]
		if node then
			for _ = 1, portion(entry.count, ctx.config.nodeShare, ctx.rng) do
				for hit = 1, node.hits do
					haul.xp += node.xpPerHit
					-- Tier-2 nodes yield only on every yieldEvery-th hit (Domain/Gathering).
					if hit % (node.yieldEvery or 1) == 0 then
						for _, yield in node.yields do
							if yield.chance == nil or ctx.rng:NextNumber() < yield.chance then
								merge(haul.items, yield.itemId, yield.perHit)
							end
						end
					end
				end
			end
		end
	end

	for _, group in HollowAI.spawnsForBand(location.enemySpawns, 1, ctx.rng) do
		local enemy = ctx.enemies[group.enemyId]
		if enemy then
			for _ = 1, portion(group.count, ctx.config.killShare, ctx.rng) do
				haul.kills += 1
				haul.xp += enemy.xp
				open(enemy.lootTableId)
			end
		end
	end
	return haul
end

return AutoClear
