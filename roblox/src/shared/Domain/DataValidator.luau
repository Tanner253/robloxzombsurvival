--!strict
--[[
	DataValidator: checks the content bundle for broken references and bad values
	(ARCHITECTURE.md §5). Pure: takes a Types.Content and returns a sorted list of
	error messages, empty when everything is valid.

	Runs in the Lune test suite (a broken reference fails the build) and at server
	boot in Studio (a broken reference stops the server before players join).

	Checks:
	- every table key equals its entry's `id`, and IDs use the right prefix
	  ("item.", "recipe.", ...) and the lowercase "prefix.snake_case" form
	- every reference (items, recipes, stations, nodes, loot tables, enemies,
	  locations, build pieces, quests, blueprint gates) points at an entry
	- counts, weights, ranges, levels, chances and timings are sane
	- item fields match their category (tools have tool stats, ranged weapons name
	  an ammo item, armor has an equip slot, and so on)
	- build tiers chain the way Domain/Grid refunds them: an upgrade goes up exactly
	  one tier of the same kind, each piece is upgraded into from at most one
	  piece, and every structural tier above 1 has a lower tier below it
	- loot nesting (tableId) resolves without loops within Domain/Loot's depth, and
	  every pity rarity is reachable by some entry
	- every node can be harvested by some tool, and every location's loot preview
	  only lists items that really drop there
	- nothing is orphaned: every loot table, node, enemy and station is used, every
	  blueprint unlocks something, and every item can be earned in play (not only
	  bought)
	- Fog Runs (slice 2): firearm, bow and melee stats, flares, bursts, each
	  location's run rules (extraction by fog tier, band loot, travel bonus), the
	  lobby and combat tuning, and feature tags naming a real Tuning.features flag.
	  Boot validates the bundle with disabled features stripped (Shared/Features),
	  so untagged content pointing at tagged content fails there.
]]

local Types = require("../Types")
local TableUtil = require("../Util/Table")

local DataValidator = {}

local ID_FORM = "^%l+%.[%l%d_]+$"
local MAX_BUILD_TIER = 3
local MAX_LOOT_DEPTH = 8 -- Domain/Loot refuses to nest deeper
local EDGE_KINDS: { [string]: boolean } = { wall = true, doorway = true, door = true, gate = true, window = true }
local ARMOR_SLOTS: { [string]: boolean } = { head = true, body = true, legs = true, feet = true }
local RARITY_RANK: { [string]: number } = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }

type Errors = { string }
type ItemSet = { [Types.ItemId]: boolean }

local function push(errors: Errors, message: string)
	table.insert(errors, message)
end

local function isPositiveInteger(value: number): boolean
	return value >= 1 and value % 1 == 0
end

local function isNonNegativeInteger(value: number): boolean
	return value >= 0 and value % 1 == 0
end

local function checkIds<T>(errors: Errors, tableName: string, prefix: string, defs: { [string]: T }, idOf: (T) -> string)
	for _, key in TableUtil.sortedKeys(defs) do
		local id = idOf(defs[key])
		if id ~= key then
			push(errors, `{tableName}['{key}']: id field is '{id}', expected '{key}'`)
		end
		if string.match(key, ID_FORM) == nil or string.sub(key, 1, #prefix + 1) ~= prefix .. "." then
			push(errors, `{tableName}['{key}']: ID must look like '{prefix}.snake_case'`)
		end
	end
end

local function checkItemRef(errors: Errors, content: Types.Content, where: string, itemId: string)
	if content.Items[itemId] == nil then
		push(errors, `{where}: unknown item '{itemId}'`)
	end
end

local function checkStacks(errors: Errors, content: Types.Content, where: string, stacks: { Types.ItemStack })
	for index, stack in stacks do
		checkItemRef(errors, content, `{where}[{index}]`, stack.itemId)
		if not isPositiveInteger(stack.count) then
			push(errors, `{where}[{index}]: count must be a positive integer`)
		end
	end
end

local function checkRange(errors: Errors, where: string, range: Types.Range)
	if not isNonNegativeInteger(range.min) or not isNonNegativeInteger(range.max) or range.min > range.max then
		push(errors, `{where}: need integers 0 <= min <= max`)
	end
end

local function checkLevel(errors: Errors, content: Types.Content, where: string, level: number)
	if not isPositiveInteger(level) or level > #content.Levels then
		push(errors, `{where}: level {level} must be an integer from 1 to {#content.Levels}`)
	end
end

local function checkGate(errors: Errors, content: Types.Content, where: string, gate: Types.UnlockGate)
	if gate.kind == "blueprint" then
		local item = content.Items[gate.itemId]
		if item == nil then
			push(errors, `{where}: unknown item '{gate.itemId}'`)
		elseif item.category ~= "blueprint" then
			push(errors, `{where}: '{gate.itemId}' is not a blueprint item`)
		end
	elseif gate.kind == "level" then
		checkLevel(errors, content, where, gate.level)
	end
end

-- Adds every item `loot` can drop, following nested tables, to `set`.
local function addLootItems(
	set: ItemSet,
	content: Types.Content,
	loot: Types.LootTableDef?,
	visited: { [string]: boolean }?
)
	if loot == nil then
		return
	end
	local seen: { [string]: boolean } = visited or {}
	if seen[loot.id] then
		return
	end
	seen[loot.id] = true
	for _, entry in loot.entries do
		if entry.itemId then
			set[entry.itemId] = true
		end
		if entry.tableId then
			addLootItems(set, content, content.LootTables[entry.tableId], seen)
		end
	end
	if loot.guaranteed then
		for _, stack in loot.guaranteed do
			set[stack.itemId] = true
		end
	end
end

-- How deep nesting goes below `tableId`, or nil when it loops back on itself.
local function lootDepth(content: Types.Content, tableId: string, path: { [string]: boolean }): number?
	if path[tableId] then
		return nil
	end
	local loot = content.LootTables[tableId]
	if loot == nil then
		return 0
	end
	path[tableId] = true
	local deepest = 0
	for _, entry in loot.entries do
		if entry.tableId then
			local below = lootDepth(content, entry.tableId, path)
			if below == nil then
				path[tableId] = nil
				return nil
			end
			deepest = math.max(deepest, below + 1)
		end
	end
	path[tableId] = nil
	return deepest
end

-- Items ------------------------------------------------------------------------------

local function isChance(value: number): boolean
	return value >= 0 and value <= 1
end

-- Fog Runs: melee, firearm and bow stats (Domain/Combat).
local function checkWeaponStats(errors: Errors, where: string, weapon: Types.WeaponStats)
	if weapon.critChance ~= nil and not isChance(weapon.critChance) then
		push(errors, `{where}: critChance must be between 0 and 1`)
	end
	if weapon.swapSeconds ~= nil and weapon.swapSeconds < 0 then
		push(errors, `{where}: swapSeconds must not be negative`)
	end
	local melee = weapon.melee
	if melee then
		if weapon.kind ~= "melee" then
			push(errors, `{where}: melee stats only go on melee weapons`)
		end
		for _, value in { melee.arcDegrees, melee.heavyMultiplier, melee.knockbackStuds, melee.hitStopSeconds } do
			if value ~= nil and value < 0 then
				push(errors, `{where}.melee: values must not be negative`)
			end
		end
		if melee.arcDegrees ~= nil and (melee.arcDegrees <= 0 or melee.arcDegrees > 360) then
			push(errors, `{where}.melee: arcDegrees must be in (0, 360]`)
		end
	end
	if weapon.kind == "ranged" and (weapon.firearm ~= nil) == (weapon.bow ~= nil) then
		push(errors, `{where}: ranged weapons need exactly one of firearm and bow stats`)
	end
	if weapon.kind == "melee" and (weapon.firearm ~= nil or weapon.bow ~= nil) then
		push(errors, `{where}: melee weapons take no firearm or bow stats`)
	end
	local gun = weapon.firearm
	if gun then
		if gun.fireInterval <= 0 or gun.reloadSeconds <= 0 or gun.projectileSpeed <= 0 or gun.noiseRadius <= 0 then
			push(
				errors,
				`{where}.firearm: fireInterval, reloadSeconds, projectileSpeed and noiseRadius must be positive`
			)
		end
		if not isPositiveInteger(gun.magazine) or (gun.pellets ~= nil and not isPositiveInteger(gun.pellets)) then
			push(errors, `{where}.firearm: magazine and pellets must be positive integers`)
		end
		if gun.spreadDegrees < 0 or gun.spreadDegrees >= 180 then
			push(errors, `{where}.firearm: spreadDegrees must be in [0, 180)`)
		end
		if gun.falloffMin ~= nil and (gun.falloffMin <= 0 or gun.falloffMin > 1) then
			push(errors, `{where}.firearm: falloffMin must be in (0, 1]`)
		end
		if gun.falloffStart ~= nil and (gun.falloffStart < 0 or gun.falloffStart >= weapon.range) then
			push(errors, `{where}.firearm: falloffStart must be at least 0 and below range`)
		end
		-- The item card shows attacksPerSecond: it must be the sustained rate Combat fires at.
		local cycle = (gun.magazine - 1) * gun.fireInterval + gun.reloadSeconds
		local sustained = if cycle > 0 then gun.magazine / cycle else 0
		if sustained > 0 and math.abs(weapon.attacksPerSecond - sustained) > sustained * 0.02 then
			push(errors, `{where}: attacksPerSecond must be the sustained rate {sustained} (Combat.sustainedRate)`)
		end
	end
	local bow = weapon.bow
	if bow then
		if bow.drawSeconds <= 0 or bow.projectileSpeed <= 0 then
			push(errors, `{where}.bow: drawSeconds and projectileSpeed must be positive`)
		end
		if bow.minDraw < 0 or bow.minDraw >= 1 or not isChance(bow.recoveryChance) then
			push(errors, `{where}.bow: need 0 <= minDraw < 1 and recoveryChance in [0, 1]`)
		end
	end
end

local function checkItems(errors: Errors, content: Types.Content)
	for _, id in TableUtil.sortedKeys(content.Items) do
		local item = content.Items[id]
		local where = `Items['{id}']`
		local category = item.category
		if not isPositiveInteger(item.stackSize) then
			push(errors, `{where}: stackSize must be a positive integer`)
		end
		if item.durability ~= nil and item.stackSize ~= 1 then
			push(errors, `{where}: only items with stackSize 1 can have durability`)
		end
		if not isPositiveInteger(item.tier) then
			push(errors, `{where}: tier must be a positive integer`)
		end

		local equippable = category == "tool" or category == "weapon" or category == "armor" or category == "bag"
		if equippable and item.stackSize ~= 1 then
			push(errors, `{where}: {category} items must have stackSize 1`)
		end
		if (category == "tool" or category == "weapon" or category == "armor") and (item.durability or 0) <= 0 then
			push(errors, `{where}: {category} items need a positive durability`)
		end

		if (item.tool ~= nil) ~= (category == "tool") then
			push(errors, `{where}: tool stats are required on tools and only allowed on tools`)
		end
		if (item.weapon ~= nil) ~= (category == "weapon") then
			push(errors, `{where}: weapon stats are required on weapons and only allowed on weapons`)
		end
		if (item.armor ~= nil) ~= (category == "armor") then
			push(errors, `{where}: armor stats are required on armor and only allowed on armor`)
		end
		if (item.bagSlots ~= nil) ~= (category == "bag") then
			push(errors, `{where}: bagSlots is required on bags and only allowed on bags`)
		end

		local slot: string? = item.equipSlot
		if category == "weapon" then
			if slot ~= "weapon" then
				push(errors, `{where}: weapons need equipSlot 'weapon'`)
			end
		elseif category == "armor" then
			if slot == nil or not ARMOR_SLOTS[slot] then
				push(errors, `{where}: armor needs equipSlot head, body, legs or feet`)
			end
		elseif category == "bag" then
			if slot ~= "bag" then
				push(errors, `{where}: bags need equipSlot 'bag'`)
			end
		elseif slot ~= nil then
			push(errors, `{where}: only weapons, armor and bags have an equipSlot`)
		end

		if item.tool and not isPositiveInteger(item.tool.tier) then
			push(errors, `{where}.tool: tier must be a positive integer`)
		end
		local weapon = item.weapon
		if weapon then
			if weapon.damage <= 0 or weapon.attacksPerSecond <= 0 or weapon.range <= 0 then
				push(errors, `{where}.weapon: damage, attacksPerSecond and range must be positive`)
			end
			if weapon.kind == "ranged" then
				local ammo = if weapon.ammoItemId then content.Items[weapon.ammoItemId] else nil
				if weapon.ammoItemId == nil then
					push(errors, `{where}.weapon: ranged weapons need an ammoItemId`)
				elseif ammo == nil then
					push(errors, `{where}.weapon: unknown item '{weapon.ammoItemId}'`)
				elseif ammo.category ~= "ammo" then
					push(errors, `{where}.weapon: '{weapon.ammoItemId}' is not an ammo item`)
				end
			elseif weapon.ammoItemId ~= nil then
				push(errors, `{where}.weapon: melee weapons take no ammo`)
			end
			checkWeaponStats(errors, `{where}.weapon`, weapon)
		end
		if item.flare then
			if category ~= "ammo" then
				push(errors, `{where}: only ammo can burn as a flare`)
			end
			local flare = item.flare
			if flare.lightRadius <= 0 or flare.seconds <= 0 or flare.fleeRadius <= 0 then
				push(errors, `{where}.flare: lightRadius, seconds and fleeRadius must be positive`)
			end
			if flare.burnDps < 0 or flare.burnSeconds < 0 then
				push(errors, `{where}.flare: burnDps and burnSeconds must not be negative`)
			end
		end
		if item.armor and item.armor.defense <= 0 then
			push(errors, `{where}.armor: defense must be positive`)
		end
		local fogResist = item.armor and item.armor.fogResist
		if fogResist ~= nil and (fogResist < 0 or fogResist >= 1) then
			push(errors, `{where}.armor: fogResist must be in [0, 1)`)
		end
		if item.bagSlots and not isPositiveInteger(item.bagSlots) then
			push(errors, `{where}: bagSlots must be a positive integer`)
		end
		local consume = item.consume
		if consume then
			local values = { consume.health or 0, consume.hunger or 0, consume.thirst or 0, consume.energy or 0 }
			local total = 0
			for _, value in values do
				if value < 0 then
					push(errors, `{where}.consume: values must not be negative`)
				end
				total += value
			end
			if total <= 0 then
				push(errors, `{where}.consume: must restore something`)
			end
		end
	end
end

-- Recipes and stations ------------------------------------------------------------------

local function checkRecipes(errors: Errors, content: Types.Content)
	for _, id in TableUtil.sortedKeys(content.Recipes) do
		local recipe = content.Recipes[id]
		local where = `Recipes['{id}']`
		if #recipe.inputs == 0 or #recipe.outputs == 0 then
			push(errors, `{where}: needs at least one input and one output`)
		end
		checkStacks(errors, content, `{where}.inputs`, recipe.inputs)
		checkStacks(errors, content, `{where}.outputs`, recipe.outputs)
		if recipe.stationId ~= nil then
			local station = content.Stations[recipe.stationId]
			if station == nil then
				push(errors, `{where}: unknown station '{recipe.stationId}'`)
			elseif (recipe.stationLevel or 1) > #station.levels then
				push(errors, `{where}: station level {recipe.stationLevel} does not exist`)
			end
		elseif recipe.stationLevel ~= nil then
			push(errors, `{where}: stationLevel needs a stationId`)
		end
		if recipe.craftSeconds < 0 then
			push(errors, `{where}: craftSeconds must not be negative`)
		end
		checkGate(errors, content, `{where}.unlock`, recipe.unlock)
	end
end

local function checkSalvage(errors: Errors, content: Types.Content, where: string, salvage: { Types.SalvageDef })
	local seen: { [string]: boolean } = {}
	for index, def in salvage do
		local defWhere = `{where}.salvage[{index}]`
		checkItemRef(errors, content, defWhere, def.inputItemId)
		if seen[def.inputItemId] then
			push(errors, `{defWhere}: '{def.inputItemId}' is listed twice`)
		end
		seen[def.inputItemId] = true
		if def.seconds <= 0 then
			push(errors, `{defWhere}: seconds must be positive`)
		end
		if #def.outputs == 0 then
			push(errors, `{defWhere}: needs at least one output`)
		end
		for outputIndex, output in def.outputs do
			local outputWhere = `{defWhere}.outputs[{outputIndex}]`
			checkItemRef(errors, content, outputWhere, output.itemId)
			if not isPositiveInteger(output.min) or not isPositiveInteger(output.max) or output.min > output.max then
				push(errors, `{outputWhere}: need integers 1 <= min <= max`)
			end
			if output.chance <= 0 or output.chance > 1 then
				push(errors, `{outputWhere}: chance must be in (0, 1]`)
			end
		end
	end
end

local function checkStations(errors: Errors, content: Types.Content)
	for _, id in TableUtil.sortedKeys(content.Stations) do
		local station = content.Stations[id]
		local where = `Stations['{id}']`
		if #station.levels == 0 then
			push(errors, `{where}: needs at least one level`)
		end
		local previousRequired = 1
		for index, level in station.levels do
			local levelWhere = `{where}.levels[{index}]`
			if level.level ~= index then
				push(errors, `{levelWhere}: level must be {index}`)
			end
			if not isPositiveInteger(level.queueSlots) then
				push(errors, `{levelWhere}: queueSlots must be a positive integer`)
			end
			if level.speedMultiplier <= 0 then
				push(errors, `{levelWhere}: speedMultiplier must be positive`)
			end
			checkStacks(errors, content, `{levelWhere}.upgradeCost`, level.upgradeCost)
			if index > 1 and #level.upgradeCost == 0 then
				push(errors, `{levelWhere}: upgrades past level 1 need an upgradeCost`)
			end
			if level.requiredLevel ~= nil then
				checkLevel(errors, content, `{levelWhere}.requiredLevel`, level.requiredLevel)
				if level.requiredLevel < previousRequired then
					push(errors, `{levelWhere}: requiredLevel must not drop below the previous level's`)
				end
				previousRequired = level.requiredLevel
			end
			local bonus = level.salvageChanceBonus
			if bonus ~= nil and (bonus < 0 or bonus >= 1) then
				push(errors, `{levelWhere}: salvageChanceBonus must be in [0, 1)`)
			end
		end
		local fuel = station.fuel
		if fuel then
			local accepted: { [string]: boolean } = {}
			for index, itemId in fuel.itemIds do
				checkItemRef(errors, content, `{where}.fuel.itemIds[{index}]`, itemId)
				accepted[itemId] = true
			end
			if fuel.secondsPerUnit <= 0 then
				push(errors, `{where}.fuel: secondsPerUnit must be positive`)
			end
			if not isPositiveInteger(fuel.maxUnits) then
				push(errors, `{where}.fuel: maxUnits must be a positive integer`)
			end
			for _, itemId in TableUtil.sortedKeys(fuel.burnSeconds or {}) do
				local seconds = (fuel.burnSeconds :: { [string]: number })[itemId]
				if not accepted[itemId] then
					push(errors, `{where}.fuel.burnSeconds: '{itemId}' is not in itemIds`)
				end
				if seconds <= 0 then
					push(errors, `{where}.fuel.burnSeconds['{itemId}']: must be positive`)
				end
			end
		end
		if station.salvage then
			checkSalvage(errors, content, where, station.salvage)
		end
	end
end

-- Nodes, loot and enemies -------------------------------------------------------------

local function checkNodes(errors: Errors, content: Types.Content)
	-- The best tool tier available for each tool kind.
	local bestTool: { [string]: number } = {}
	for _, item in content.Items do
		if item.tool then
			bestTool[item.tool.kind] = math.max(bestTool[item.tool.kind] or 0, item.tool.tier)
		end
	end

	for _, id in TableUtil.sortedKeys(content.Nodes) do
		local node = content.Nodes[id]
		local where = `Nodes['{id}']`
		if node.tool and (bestTool[node.tool.kind] or 0) < node.tool.tier then
			push(errors, `{where}: no item is a tier {node.tool.tier}+ {node.tool.kind}`)
		end
		if not isPositiveInteger(node.hits) then
			push(errors, `{where}: hits must be a positive integer`)
		end
		if #node.yields == 0 then
			push(errors, `{where}: needs at least one yield`)
		end
		for index, yield in node.yields do
			local yieldWhere = `{where}.yields[{index}]`
			checkItemRef(errors, content, yieldWhere, yield.itemId)
			if not isPositiveInteger(yield.perHit) then
				push(errors, `{yieldWhere}: perHit must be a positive integer`)
			end
			if yield.chance ~= nil and (yield.chance <= 0 or yield.chance > 1) then
				push(errors, `{yieldWhere}: chance must be in (0, 1]`)
			end
		end
		if node.xpPerHit < 0 then
			push(errors, `{where}: xpPerHit must not be negative`)
		end
		if node.respawnSeconds <= 0 then
			push(errors, `{where}: respawnSeconds must be positive`)
		end
	end
end

local function checkLootTables(errors: Errors, content: Types.Content)
	for _, id in TableUtil.sortedKeys(content.LootTables) do
		local loot = content.LootTables[id]
		local where = `LootTables['{id}']`
		if loot.rolls.min < 0 or loot.rolls.min > loot.rolls.max then
			push(errors, `{where}.rolls: need 0 <= min <= max`)
		end
		if #loot.entries == 0 then
			push(errors, `{where}: needs at least one entry`)
		end
		local bestRank = 0 -- the rarest thing a pick can force, for the pity check
		for index, entry in loot.entries do
			local entryWhere = `{where}.entries[{index}]`
			if (entry.itemId ~= nil) == (entry.tableId ~= nil) then
				push(errors, `{entryWhere}: set exactly one of itemId and tableId`)
			end
			if entry.itemId then
				checkItemRef(errors, content, entryWhere, entry.itemId)
			end
			if entry.tableId and content.LootTables[entry.tableId] == nil then
				push(errors, `{entryWhere}: unknown loot table '{entry.tableId}'`)
			end
			if entry.weight <= 0 then
				push(errors, `{entryWhere}: weight must be positive`)
			end
			-- min 0 is allowed ("maybe nothing"); an entry must be able to give something.
			if not isNonNegativeInteger(entry.min) or not isPositiveInteger(entry.max) or entry.min > entry.max then
				push(errors, `{entryWhere}: need integers 0 <= min <= max, max >= 1`)
			end
			local rarity: string? = entry.rarity
			if rarity ~= nil and RARITY_RANK[rarity] == nil then
				push(errors, `{entryWhere}: unknown rarity '{rarity}'`)
			end
			-- Domain/Loot: a nested entry counts for pity only with an explicit rarity.
			local item = if entry.itemId then content.Items[entry.itemId] else nil
			local effective: string? = rarity or (if item then item.rarity else nil)
			bestRank = math.max(bestRank, if effective then RARITY_RANK[effective] or 0 else 0)
		end
		if loot.guaranteed then
			checkStacks(errors, content, `{where}.guaranteed`, loot.guaranteed)
		end
		local pity = loot.pity
		if pity then
			local rank = RARITY_RANK[pity.rarity :: string]
			if rank == nil then
				push(errors, `{where}.pity: unknown rarity '{pity.rarity}'`)
			elseif bestRank < rank then
				push(errors, `{where}.pity: no entry is {pity.rarity} or better, so pity can never pay out`)
			end
			if not isPositiveInteger(pity.every) or pity.every < 2 then
				push(errors, `{where}.pity: every must be an integer of at least 2`)
			end
		end
		local depth = lootDepth(content, id, {})
		if depth == nil then
			push(errors, `{where}: nested tables loop back on themselves`)
		elseif depth > MAX_LOOT_DEPTH then
			push(errors, `{where}: nests {depth} tables deep, more than {MAX_LOOT_DEPTH}`)
		end
	end
end

local function checkEnemies(errors: Errors, content: Types.Content)
	for _, id in TableUtil.sortedKeys(content.Enemies) do
		local enemy = content.Enemies[id]
		local where = `Enemies['{id}']`
		if enemy.hp <= 0 or enemy.damage <= 0 or enemy.attackSeconds <= 0 then
			push(errors, `{where}: hp, damage and attackSeconds must be positive`)
		end
		if enemy.moveSpeed <= 0 or enemy.aggroRadius <= 0 or enemy.attackRange <= 0 then
			push(errors, `{where}: moveSpeed, aggroRadius and attackRange must be positive`)
		end
		if enemy.xp < 0 then
			push(errors, `{where}: xp must not be negative`)
		end
		if content.LootTables[enemy.lootTableId] == nil then
			push(errors, `{where}: unknown loot table '{enemy.lootTableId}'`)
		end
		if enemy.hearing <= 0 or enemy.lightFear <= 0 then
			push(errors, `{where}: hearing and lightFear must be positive`)
		end
		local wildlife = enemy.wildlife
		if
			wildlife
			and (wildlife.spookRadius < 0 or (wildlife.temperament == "skittish" and wildlife.spookRadius <= 0))
		then
			push(errors, `{where}.wildlife: skittish animals need a positive spookRadius`)
		end
		if wildlife and enemy.burst then
			push(errors, `{where}: wildlife doesn't burst`)
		end
		local burst = enemy.burst
		if burst then
			for _, value in { burst.triggerRange, burst.radius, burst.damagePerSecond, burst.cloudSeconds } do
				if value <= 0 then
					push(
						errors,
						`{where}.burst: triggerRange, radius, damagePerSecond and cloudSeconds must be positive`
					)
					break
				end
			end
			if burst.fuseSeconds < 0 then
				push(errors, `{where}.burst: fuseSeconds must not be negative`)
			end
		end
	end
end

-- Locations ---------------------------------------------------------------------------

local function checkLocationNodes(errors: Errors, content: Types.Content, where: string, nodes: { Types.LocationNode })
	for index, entry in nodes do
		if content.Nodes[entry.nodeId] == nil then
			push(errors, `{where}[{index}]: unknown node '{entry.nodeId}'`)
		end
		if not isPositiveInteger(entry.count) then
			push(errors, `{where}[{index}]: count must be a positive integer`)
		end
	end
end

local EXTRACTION_POINT_FORM = "^[%l%d_]+$"

-- Fog Runs: the lobby rules of one location. Band loot drops here, so it joins `drops`.
local function checkLocationRun(errors: Errors, content: Types.Content, location: Types.LocationDef, drops: ItemSet)
	local where = `Locations['{location.id}'].run`
	local run = location.run
	if run == nil then
		push(errors, `{where}: every location needs its Fog Run rules`)
		return
	end
	if run.recommendedGearScore < 0 or not isNonNegativeInteger(run.placeId) then
		push(errors, `{where}: need recommendedGearScore >= 0 and an integer placeId (0 until published)`)
	end

	local extraction = run.extraction
	if location.fogTier == 1 and extraction.kind ~= "edge" then
		push(errors, `{where}.extraction: Light fog is left from any edge (kind 'edge')`)
	end
	if location.fogTier > 1 and extraction.kind ~= "points" then
		push(errors, `{where}.extraction: Dense and Black fog leave only through extraction points`)
	end
	if extraction.kind == "points" then
		local seen: { [string]: boolean } = {}
		for index, point in extraction.points do
			if string.match(point.id, EXTRACTION_POINT_FORM) == nil or #point.id > 32 then
				push(errors, `{where}.extraction.points[{index}]: id must be snake_case, at most 32 characters`)
			end
			if seen[point.id] then
				push(errors, `{where}.extraction.points[{index}]: '{point.id}' is listed twice`)
			end
			seen[point.id] = true
		end
		local count = #extraction.points
		if count < 2 or count > 3 then
			push(errors, `{where}.extraction: needs 2-3 points (GAME_DESIGN)`)
		end
		if not isNonNegativeInteger(extraction.closeCount) or extraction.closeCount >= count then
			push(errors, `{where}.extraction: closeCount must leave at least one point open`)
		end
		if extraction.flare and location.fogTier ~= 3 then
			push(errors, `{where}.extraction: the flare extract is Black fog only`)
		end
	end

	local bands = #content.Tuning.lobby.bands
	local seenBands: { [number]: boolean } = {}
	for index, entry in run.bandLoot do
		local entryWhere = `{where}.bandLoot[{index}]`
		if not isPositiveInteger(entry.band) or entry.band < 2 or entry.band > bands then
			push(errors, `{entryWhere}: band must be an integer from 2 to {bands} (band 1 is the base loot)`)
		end
		if seenBands[entry.band] then
			push(errors, `{entryWhere}: band {entry.band} is listed twice`)
		end
		seenBands[entry.band] = true
		local loot = content.LootTables[entry.lootTableId]
		if loot == nil then
			push(errors, `{entryWhere}: unknown loot table '{entry.lootTableId}'`)
		end
		addLootItems(drops, content, loot)
	end
	if content.LootTables[run.travelBonusTableId] == nil then
		push(errors, `{where}: unknown travel bonus loot table '{run.travelBonusTableId}'`)
	end
end

local function checkLocations(errors: Errors, content: Types.Content)
	local fogTiers = #content.Tuning.travel.fogTierNames
	for _, id in TableUtil.sortedKeys(content.Locations) do
		local location = content.Locations[id]
		local where = `Locations['{id}']`
		if not isPositiveInteger(location.fogTier) or location.fogTier > fogTiers then
			push(errors, `{where}: fogTier must be an integer from 1 to {fogTiers}`)
		end
		checkLevel(errors, content, `{where}.levelGate`, location.levelGate)
		if location.energyCost < 0 or location.walkSeconds < 0 then
			push(errors, `{where}: energyCost and walkSeconds must not be negative`)
		end

		local reset = location.reset
		local availability = location.availability
		if reset.kind == "timer" and reset.seconds <= 0 then
			push(errors, `{where}.reset: seconds must be positive`)
		end
		if (reset.kind == "perAppearance") ~= (availability.kind == "rotating") then
			push(errors, `{where}: perAppearance resets go with rotating availability, and only with it`)
		end
		if availability.kind == "rotating" then
			if availability.periodSeconds <= 0 or availability.offsetSeconds < 0 then
				push(errors, `{where}.availability: periodSeconds must be positive and offsetSeconds not negative`)
			end
			if availability.activeSeconds <= 0 or availability.activeSeconds >= availability.periodSeconds then
				push(errors, `{where}.availability: need 0 < activeSeconds < periodSeconds`)
			end
		end

		-- Everything that can drop here, for the preview check below.
		local drops: ItemSet = {}
		for index, container in location.containers do
			local loot = content.LootTables[container.lootTableId]
			if loot == nil then
				push(errors, `{where}.containers[{index}]: unknown loot table '{container.lootTableId}'`)
			end
			checkRange(errors, `{where}.containers[{index}].count`, container.count)
			addLootItems(drops, content, loot)
			if container.searchSeconds ~= nil and container.searchSeconds <= 0 then
				push(errors, `{where}.containers[{index}]: searchSeconds must be positive`)
			end
		end
		checkLocationRun(errors, content, location, drops)
		checkLocationNodes(errors, content, `{where}.nodes`, location.nodes)
		for _, entry in location.nodes do
			local node = content.Nodes[entry.nodeId]
			if node then
				for _, yield in node.yields do
					drops[yield.itemId] = true
				end
			end
		end
		for index, spawn in location.enemySpawns do
			local enemy = content.Enemies[spawn.enemyId]
			if enemy == nil then
				push(errors, `{where}.enemySpawns[{index}]: unknown enemy '{spawn.enemyId}'`)
			end
			checkRange(errors, `{where}.enemySpawns[{index}].count`, spawn.count)
			addLootItems(drops, content, if enemy then content.LootTables[enemy.lootTableId] else nil)
			local band = spawn.minBand
			if band ~= nil and (not isPositiveInteger(band) or band > #content.Tuning.lobby.bands) then
				push(
					errors,
					`{where}.enemySpawns[{index}]: minBand must be an integer from 1 to {#content.Tuning.lobby.bands}`
				)
			end
		end

		if #location.mainLoot == 0 then
			push(errors, `{where}.mainLoot: needs at least one item`)
		end
		for _, listName in { "mainLoot", "possibleLoot" } do
			local list: { Types.ItemId } = if listName == "mainLoot" then location.mainLoot else location.possibleLoot
			for index, itemId in list do
				local itemWhere = `{where}.{listName}[{index}]`
				checkItemRef(errors, content, itemWhere, itemId)
				if content.Items[itemId] ~= nil and not drops[itemId] then
					push(errors, `{itemWhere}: '{itemId}' is previewed but never drops here`)
				end
			end
		end
	end
end

-- Building ------------------------------------------------------------------------------

local function checkBuildPieces(errors: Errors, content: Types.Content)
	-- Who upgrades into each piece: Domain/Grid walks this chain for refunds.
	local upgradedFrom: { [string]: { string } } = {}
	for _, id in TableUtil.sortedKeys(content.BuildPieces) do
		local target = content.BuildPieces[id].upgradesTo
		if target ~= nil then
			upgradedFrom[target] = upgradedFrom[target] or {}
			table.insert(upgradedFrom[target], id)
		end
	end
	for _, id in TableUtil.sortedKeys(upgradedFrom) do
		local sources = upgradedFrom[id]
		if #sources > 1 then
			push(errors, `BuildPieces['{id}']: upgraded into from more than one piece ({table.concat(sources, ", ")})`)
		end
	end

	for _, id in TableUtil.sortedKeys(content.BuildPieces) do
		local piece = content.BuildPieces[id]
		local where = `BuildPieces['{id}']`
		checkStacks(errors, content, `{where}.cost`, piece.cost)
		if #piece.cost == 0 then
			push(errors, `{where}: needs a cost`)
		end
		if not isPositiveInteger(piece.tier) or piece.tier > MAX_BUILD_TIER then
			push(errors, `{where}: tier must be an integer from 1 to {MAX_BUILD_TIER}`)
		end
		if piece.hp <= 0 then
			push(errors, `{where}: hp must be positive`)
		end
		if piece.breachCost < 1 then
			push(errors, `{where}: breachCost must be at least 1 (nothing is unbreachable)`)
		end
		if piece.stationId ~= nil and content.Stations[piece.stationId] == nil then
			push(errors, `{where}: unknown station '{piece.stationId}'`)
		end
		if piece.kind == "station" and piece.stationId == nil then
			push(errors, `{where}: station pieces need a stationId`)
		end
		if (piece.kind == "storage") ~= (piece.storageSlots ~= nil) then
			push(errors, `{where}: storageSlots is required on storage pieces and only allowed on them`)
		elseif piece.storageSlots and not isPositiveInteger(piece.storageSlots) then
			push(errors, `{where}: storageSlots must be a positive integer`)
		end
		local minTier = piece.minFoundationTier
		if minTier ~= nil and (not isPositiveInteger(minTier) or minTier > MAX_BUILD_TIER) then
			push(errors, `{where}: minFoundationTier must be an integer from 1 to {MAX_BUILD_TIER}`)
		end
		if EDGE_KINDS[piece.kind] and (minTier or 0) < piece.tier then
			push(errors, `{where}: {piece.kind} tier can't exceed its foundation tier (minFoundationTier >= tier)`)
		end
		if piece.maxPerPlot ~= nil and not isPositiveInteger(piece.maxPerPlot) then
			push(errors, `{where}: maxPerPlot must be a positive integer`)
		end
		if piece.unlock then
			checkGate(errors, content, `{where}.unlock`, piece.unlock)
		end

		if piece.upgradesTo ~= nil then
			local target = content.BuildPieces[piece.upgradesTo]
			if target == nil then
				push(errors, `{where}: unknown upgradesTo piece '{piece.upgradesTo}'`)
			elseif target.kind ~= piece.kind or target.tier ~= piece.tier + 1 then
				push(errors, `{where}: upgradesTo must be the same kind, one tier up`)
			end
		end
		-- An upgraded tier's cost is only the step into it, so it must never be the
		-- start of a chain: structural pieces above tier 1 need a piece below them.
		local structural = EDGE_KINDS[piece.kind] or piece.kind == "foundation"
		if piece.tier > 1 and structural and upgradedFrom[id] == nil then
			push(errors, `{where}: tier {piece.tier} {piece.kind} has no lower tier upgrading into it`)
		end
	end
end

-- Progression ----------------------------------------------------------------------------

local function checkLevels(errors: Errors, content: Types.Content)
	if #content.Levels == 0 then
		push(errors, "Levels: needs at least level 1")
		return
	end
	if content.Levels[1].xp ~= 0 then
		push(errors, "Levels[1]: xp must be 0")
	end
	for index, def in content.Levels do
		local where = `Levels[{index}]`
		if def.level ~= index then
			push(errors, `{where}: level must be {index}`)
		end
		if index > 1 and def.xp <= content.Levels[index - 1].xp then
			push(errors, `{where}: xp must be higher than the previous level's`)
		end
		if def.rewards then
			checkStacks(errors, content, `{where}.rewards`, def.rewards)
		end
	end
end

local function checkObjective(errors: Errors, content: Types.Content, where: string, objective: Types.QuestObjective)
	if objective.kind == "gather" or objective.kind == "consume" then
		checkItemRef(errors, content, where, objective.itemId)
	elseif objective.kind == "equip" then
		local item = content.Items[objective.itemId]
		if item == nil then
			push(errors, `{where}: unknown item '{objective.itemId}'`)
		elseif item.equipSlot == nil then
			push(errors, `{where}: '{objective.itemId}' can't be equipped`)
		end
	elseif objective.kind == "craft" then
		if content.Recipes[objective.recipeId] == nil then
			push(errors, `{where}: unknown recipe '{objective.recipeId}'`)
		end
	elseif objective.kind == "build" then
		if content.BuildPieces[objective.pieceId] == nil then
			push(errors, `{where}: unknown build piece '{objective.pieceId}'`)
		end
	elseif objective.kind == "travel" then
		if content.Locations[objective.locationId] == nil then
			push(errors, `{where}: unknown location '{objective.locationId}'`)
		end
	elseif objective.kind == "loot" then
		if objective.locationId ~= nil and content.Locations[objective.locationId] == nil then
			push(errors, `{where}: unknown location '{objective.locationId}'`)
		end
	elseif objective.kind == "kill" then
		if objective.enemyId ~= nil and content.Enemies[objective.enemyId] == nil then
			push(errors, `{where}: unknown enemy '{objective.enemyId}'`)
		end
	elseif objective.kind == "reachLevel" then
		checkLevel(errors, content, where, objective.level)
	end
	local count = (objective :: any).count
	if count ~= nil and not isPositiveInteger(count) then
		push(errors, `{where}: count must be a positive integer`)
	end
end

local function checkQuests(errors: Errors, content: Types.Content)
	local starts = 0
	for _, id in TableUtil.sortedKeys(content.Quests) do
		local quest = content.Quests[id]
		local where = `Quests['{id}']`
		if quest.prerequisite == nil then
			starts += 1
		elseif content.Quests[quest.prerequisite] == nil then
			push(errors, `{where}: unknown prerequisite '{quest.prerequisite}'`)
		else
			-- Walk back along the chain; coming back to this quest means a cycle.
			local seen: { [string]: boolean } = { [id] = true }
			local current: Types.QuestDef? = content.Quests[quest.prerequisite]
			while current and current.prerequisite do
				if seen[current.id] then
					push(errors, `{where}: prerequisite chain loops back on itself`)
					break
				end
				seen[current.id] = true
				current = content.Quests[current.prerequisite]
			end
		end
		if #quest.objectives == 0 then
			push(errors, `{where}: needs at least one objective`)
		end
		for index, objective in quest.objectives do
			checkObjective(errors, content, `{where}.objectives[{index}]`, objective)
		end
		if quest.rewards.xp < 0 then
			push(errors, `{where}.rewards: xp must not be negative`)
		end
		if quest.rewards.items then
			checkStacks(errors, content, `{where}.rewards.items`, quest.rewards.items)
		end
		if quest.rewards.energy ~= nil and not isPositiveInteger(quest.rewards.energy) then
			push(errors, `{where}.rewards: energy must be a positive integer`)
		end
	end
	if next(content.Quests) ~= nil and starts == 0 then
		push(errors, "Quests: at least one quest must have no prerequisite")
	end

	-- Location quests (LDOE_PARITY #45): data on each location, IDs unique game-wide.
	local seen: { [string]: string } = {}
	for _, locationId in TableUtil.sortedKeys(content.Locations) do
		local run = content.Locations[locationId].run
		for index, quest in (if run then run.quests else {}) :: { Types.LocationQuest } do
			local where = `Locations['{locationId}'].run.quests[{index}]`
			if string.match(quest.id, ID_FORM) == nil or string.sub(quest.id, 1, 6) ~= "quest." then
				push(errors, `{where}: ID must look like 'quest.snake_case'`)
			end
			if content.Quests[quest.id] ~= nil or seen[quest.id] then
				push(errors, `{where}: '{quest.id}' is already used`)
			end
			seen[quest.id] = locationId
			if #quest.objectives == 0 then
				push(errors, `{where}: needs at least one objective`)
			end
			for objectiveIndex, objective in quest.objectives do
				checkObjective(errors, content, `{where}.objectives[{objectiveIndex}]`, objective)
			end
			if quest.rewards.items then
				checkStacks(errors, content, `{where}.rewards.items`, quest.rewards.items)
			end
		end
	end
end

-- Shop and tuning ---------------------------------------------------------------------------

local function checkProducts(errors: Errors, content: Types.Content)
	local purchasableSlots = 0
	for _, id in TableUtil.sortedKeys(content.Products) do
		local product = content.Products[id]
		local where = `Products['{id}']`
		if #product.grants == 0 then
			push(errors, `{where}: needs at least one grant`)
		end
		if not isPositiveInteger(product.defaultPriceRobux) then
			push(errors, `{where}: defaultPriceRobux must be a positive integer`)
		end
		if product.limit ~= nil and not isPositiveInteger(product.limit) then
			push(errors, `{where}: limit must be a positive integer`)
		end
		if product.kind == "gamePass" and product.limit ~= 1 then
			push(errors, `{where}: game passes are bought once, so limit must be 1`)
		end
		if product.offerMaxLevel ~= nil then
			checkLevel(errors, content, `{where}.offerMaxLevel`, product.offerMaxLevel)
		end
		for index, grant in product.grants do
			if grant.kind == "item" then
				checkItemRef(errors, content, `{where}.grants[{index}]`, grant.itemId)
				if not isPositiveInteger(grant.count) then
					push(errors, `{where}.grants[{index}]: count must be a positive integer`)
				end
			elseif not isPositiveInteger(grant.amount) then
				push(errors, `{where}.grants[{index}]: amount must be a positive integer`)
			elseif grant.kind == "backpackSlots" then
				if product.limit == nil then
					push(errors, `{where}: backpackSlots products need a limit`)
				else
					purchasableSlots += grant.amount * product.limit
				end
			end
		end
	end

	local biggestBag = 0
	for _, item in content.Items do
		biggestBag = math.max(biggestBag, item.bagSlots or 0)
	end
	local inventory = content.Tuning.inventory
	local reachable = inventory.backpackSlots + biggestBag + purchasableSlots
	if reachable > inventory.maxBackpackSlots then
		push(
			errors,
			`Tuning.inventory: maxBackpackSlots is {inventory.maxBackpackSlots} but bags and upgrades reach {reachable}`
		)
	end
end

local function allPositive(errors: Errors, where: string, section: { [string]: any })
	for _, key in TableUtil.sortedKeys(section) do
		local value = section[key]
		if type(value) == "number" and value <= 0 then
			push(errors, `{where}.{key} must be positive`)
		end
	end
end

-- LDoE parity rulings for slice 2 (docs/LDOE_PARITY.md): sneak, AUTO, airdrops, region
-- gates, fog exposure and death recovery.
local function checkParityTuning(errors: Errors, content: Types.Content)
	local tuning = content.Tuning
	local tiers = #tuning.travel.fogTierNames
	allPositive(errors, "Tuning.sneak", tuning.sneak :: any)
	allPositive(errors, "Tuning.autoAttack", tuning.autoAttack :: any)
	if tuning.travelBonus.takeAllRations < 0 or tuning.travelBonus.hurryEnergyPerMinute <= 0 then
		push(errors, "Tuning.travelBonus: need takeAllRations >= 0 and a positive hurryEnergyPerMinute")
	end

	local auto = tuning.autoClear
	if #auto.rationsByTier ~= tiers then
		push(errors, `Tuning.autoClear.rationsByTier: needs one cost per fog tier ({tiers})`)
	end
	if not isChance(auto.nodeShare) or not isChance(auto.killShare) or not isNonNegativeInteger(auto.adPerDay) then
		push(errors, "Tuning.autoClear: shares must be in [0, 1] and adPerDay a non-negative integer")
	end
	checkLevel(errors, content, "Tuning.autoClear.adMinLevel", auto.adMinLevel)

	local airdrops = tuning.airdrops
	local drop = content.Locations[airdrops.locationId]
	if drop == nil then
		push(errors, `Tuning.airdrops: unknown location '{airdrops.locationId}'`)
	elseif drop.availability.kind ~= "airdrop" then
		push(errors, `Tuning.airdrops: '{airdrops.locationId}' needs availability 'airdrop'`)
	end
	for index, threshold in airdrops.thresholds do
		local previous = airdrops.thresholds[index - 1]
		if threshold <= 0 or threshold >= tuning.energy.cap or (previous ~= nil and threshold >= previous) then
			push(errors, "Tuning.airdrops.thresholds: must fall from below the Energy cap to above 0")
		end
	end
	for id, location in content.Locations do
		if location.availability.kind == "airdrop" and id ~= airdrops.locationId then
			push(errors, `Locations['{id}']: only Tuning.airdrops.locationId may use availability 'airdrop'`)
		end
	end

	local gateTiers: { [number]: number } = {}
	local gateIds: { [string]: boolean } = {}
	for index, gate in tuning.regionGates do
		local where = `Tuning.regionGates[{index}]`
		if gateIds[gate.id] then
			push(errors, `{where}: '{gate.id}' is listed twice`)
		end
		gateIds[gate.id] = true
		if not isPositiveInteger(gate.fogTier) or gate.fogTier < 2 or gate.fogTier > tiers then
			push(errors, `{where}: fogTier must be a gated tier from 2 to {tiers}`)
		end
		gateTiers[gate.fogTier] = (gateTiers[gate.fogTier] or 0) + 1
		checkStacks(errors, content, `{where}.parts`, gate.parts)
	end
	for tier = 2, tiers do
		if gateTiers[tier] ~= 1 then
			push(errors, `Tuning.regionGates: fog tier {tier} needs exactly one tower to repair`)
		end
	end

	local exposure = tuning.fogExposure
	if #exposure.ratePerTier ~= tiers or exposure.ratePerTier[1] ~= 0 then
		push(errors, "Tuning.fogExposure.ratePerTier: one rate per tier, and Light fog is 0")
	end
	if exposure.max <= 0 or exposure.damagePerSecond <= 0 or exposure.maxResist < 0 or exposure.maxResist >= 1 then
		push(errors, "Tuning.fogExposure: need positive max and damage, and 0 <= maxResist < 1")
	end

	local recovery = tuning.deathRecovery
	if not isNonNegativeInteger(recovery.recoverAllAdsPerDay) or recovery.reanimatorHealth <= 0 then
		push(errors, "Tuning.deathRecovery: need an integer recoverAllAdsPerDay and a positive reanimatorHealth")
	end
	local lastDeaths = 0
	for index, milestone in recovery.milestones do
		if not isPositiveInteger(milestone.deaths) or milestone.deaths <= lastDeaths then
			push(errors, `Tuning.deathRecovery.milestones[{index}]: deaths must rise`)
		end
		lastDeaths = milestone.deaths
		checkStacks(errors, content, `Tuning.deathRecovery.milestones[{index}].items`, milestone.items)
	end
end

-- Fog Runs (slice 2) tuning: lobby bands, per-tier tables and the combat constants.
local function checkFogRunTuning(errors: Errors, content: Types.Content)
	local tuning = content.Tuning
	local tiers = #tuning.travel.fogTierNames
	for _, key in TableUtil.sortedKeys(tuning.features :: any) do
		if type((tuning.features :: any)[key]) ~= "boolean" then
			push(errors, `Tuning.features.{key} must be a boolean`)
		end
	end

	local lobby = tuning.lobby
	allPositive(errors, "Tuning.lobby", lobby :: any)
	if not isPositiveInteger(lobby.capacity) then
		push(errors, "Tuning.lobby.capacity must be a positive integer")
	end
	if lobby.joinWindowSeconds >= lobby.durationSeconds or lobby.warningSeconds >= lobby.durationSeconds then
		push(errors, "Tuning.lobby: the join window and the warning must be shorter than the run")
	end
	if lobby.reentryCutoffSeconds >= lobby.durationSeconds then
		push(errors, "Tuning.lobby: reentryCutoffSeconds must be shorter than the run")
	end
	if #lobby.bands == 0 or lobby.bands[1].from ~= 0 then
		push(errors, "Tuning.lobby.bands: the first band must start at 0")
	end
	for index, band in lobby.bands do
		if index > 1 and (band.from <= lobby.bands[index - 1].from or band.from >= 1) then
			push(errors, `Tuning.lobby.bands[{index}]: from must rise and stay below 1`)
		end
		if band.lootMultiplier < 1 or band.hollowStrength < 1 then
			push(errors, `Tuning.lobby.bands[{index}]: multipliers must be at least 1`)
		end
	end
	if #lobby.drops ~= tiers then
		push(errors, `Tuning.lobby.drops: needs one rule per fog tier ({tiers})`)
	end
	local extraction = tuning.extraction
	if #extraction.xpByTier ~= tiers then
		push(errors, `Tuning.extraction.xpByTier: needs one value per fog tier ({tiers})`)
	end
	if extraction.edgeSeconds < 0 or extraction.pointSeconds <= 0 or extraction.flareSeconds <= 0 then
		push(errors, "Tuning.extraction: need edgeSeconds >= 0 and positive point and flare channels")
	end
	if #tuning.containers.lootModeByTier ~= tiers then
		push(errors, `Tuning.containers.lootModeByTier: needs one mode per fog tier ({tiers})`)
	end
	allPositive(errors, "Tuning.matchmaking", tuning.matchmaking :: any)
	local travelBonus = tuning.travelBonus
	if not isChance(travelBonus.runChance) or not isChance(travelBonus.walkChance) then
		push(errors, "Tuning.travelBonus: chances must be between 0 and 1")
	end
	if not isPositiveInteger(travelBonus.walkRolls) then
		push(errors, "Tuning.travelBonus.walkRolls must be a positive integer")
	end
	allPositive(errors, "Tuning.noise", tuning.noise :: any)
	allPositive(errors, "Tuning.dodge", tuning.dodge :: any)
	allPositive(errors, "Tuning.melee", tuning.melee :: any)
	if tuning.hands.slots ~= 2 or tuning.hands.swapSeconds < 0 then
		push(errors, "Tuning.hands: two weapon slots (GAME_DESIGN PC controls) and swapSeconds >= 0")
	end
	allPositive(errors, "Tuning.hollow", tuning.hollow :: any)
	checkRange(errors, "Tuning.hollow.idleSeconds", tuning.hollow.idleSeconds)
	local stamina = tuning.stamina
	if
		stamina.max <= 0
		or stamina.regenPerSecond <= 0
		or stamina.regenDelaySeconds < 0
		or stamina.sprintPerSecond < 0
	then
		push(errors, "Tuning.stamina: need positive max and regen, and non-negative delay and sprint cost")
	end
	if tuning.dodge.staminaCost > stamina.max or tuning.melee.staminaHeavy > stamina.max then
		push(errors, "Tuning: a dodge or heavy swing can't cost more than full stamina")
	end
	local combat = tuning.combat
	if not isChance(combat.critChance) or combat.critMultiplier < 1 then
		push(errors, "Tuning.combat: critChance must be in [0, 1] and critMultiplier at least 1")
	end
	if combat.pvpMaxHitFraction <= 0 or combat.pvpMaxHitFraction >= 1 or combat.lagToleranceStuds < 0 then
		push(errors, "Tuning.combat: need 0 < pvpMaxHitFraction < 1 and lagToleranceStuds >= 0")
	end
	if tuning.travel.reentryEnergyMultiplier < 0 then
		push(errors, "Tuning.travel.reentryEnergyMultiplier must not be negative")
	end
	checkParityTuning(errors, content)
end

-- Tagged content must name a flag that exists in Tuning.features.
local function checkFeatureTags(errors: Errors, content: Types.Content)
	local flags = content.Tuning.features :: any
	local function check(where: string, feature: string?)
		if feature ~= nil and flags[feature] == nil then
			push(errors, `{where}: unknown feature '{feature}'`)
		end
	end
	for _, id in TableUtil.sortedKeys(content.Recipes) do
		check(`Recipes['{id}']`, content.Recipes[id].feature)
	end
	for _, id in TableUtil.sortedKeys(content.Stations) do
		check(`Stations['{id}']`, content.Stations[id].feature)
	end
	for _, id in TableUtil.sortedKeys(content.BuildPieces) do
		check(`BuildPieces['{id}']`, content.BuildPieces[id].feature)
	end
end

local function checkTuning(errors: Errors, content: Types.Content)
	local tuning = content.Tuning
	local energy = tuning.energy
	local inventory = tuning.inventory
	if energy.cap <= 0 or energy.secondsPerPoint <= 0 then
		push(errors, "Tuning.energy: cap and secondsPerPoint must be positive")
	end
	if energy.hardCap < energy.cap then
		push(errors, "Tuning.energy: hardCap must be at least cap")
	end
	if energy.levelUpRestore < 0 or energy.foodDailyCap < 0 then
		push(errors, "Tuning.energy: levelUpRestore and foodDailyCap must not be negative")
	end
	if not isPositiveInteger(inventory.pocketSlots) or inventory.backpackSlots > inventory.maxBackpackSlots then
		push(errors, "Tuning.inventory: need pocketSlots >= 1 and backpackSlots <= maxBackpackSlots")
	end
	local survival = tuning.survival
	for _, meterName in { "hunger", "thirst" } do
		local meter: Types.SurvivalMeter = if meterName == "hunger" then survival.hunger else survival.thirst
		local where = `Tuning.survival.{meterName}`
		if meter.max <= 0 or meter.decayPerSecond <= 0 then
			push(errors, `{where}: max and decayPerSecond must be positive`)
		end
		for index, threshold in meter.thresholds do
			if threshold.atOrBelow < 0 or threshold.atOrBelow > meter.max or threshold.damagePerSecond < 0 then
				push(errors, `{where}.thresholds[{index}]: need 0 <= atOrBelow <= max and damage >= 0`)
			end
		end
	end
	if tuning.player.maxHealth <= 0 then
		push(errors, "Tuning.player: maxHealth must be positive")
	end
	if tuning.death.despawnSeconds <= 0 then
		push(errors, "Tuning.death: despawnSeconds must be positive")
	end
	if tuning.combat.armorConstant <= 0 then
		push(errors, "Tuning.combat: armorConstant must be positive")
	end
	if tuning.building.gridStuds <= 0 or not isPositiveInteger(tuning.building.plotCells) then
		push(errors, "Tuning.building: gridStuds and plotCells must be positive")
	end
	local refund = tuning.building.lateRefundFraction
	if refund < 0 or refund > 1 or tuning.building.refundGraceSeconds < 0 then
		push(errors, "Tuning.building: need 0 <= lateRefundFraction <= 1 and refundGraceSeconds >= 0")
	end
	if #tuning.travel.fogTierNames == 0 then
		push(errors, "Tuning.travel: fogTierNames must not be empty")
	end
	if tuning.raid.lootFraction < 0 or tuning.raid.lootFraction > 1 then
		push(errors, "Tuning.raid: lootFraction must be between 0 and 1")
	end
	checkStacks(errors, content, "Tuning.newPlayer.items", tuning.newPlayer.items)
	checkLocationNodes(errors, content, "Tuning.home.nodes", tuning.home.nodes)
	checkFogRunTuning(errors, content)
end

-- Cross-checks: nothing orphaned ----------------------------------------------------------------

local function checkUsage(errors: Errors, content: Types.Content)
	local usedLoot: { [string]: boolean } = {}
	local usedNodes: { [string]: boolean } = {}
	local usedEnemies: { [string]: boolean } = {}
	for _, location in content.Locations do
		for _, container in location.containers do
			usedLoot[container.lootTableId] = true
		end
		for _, entry in location.nodes do
			usedNodes[entry.nodeId] = true
		end
		for _, spawn in location.enemySpawns do
			usedEnemies[spawn.enemyId] = true
		end
		if location.run then
			for _, entry in location.run.bandLoot do
				usedLoot[entry.lootTableId] = true
			end
			usedLoot[location.run.travelBonusTableId] = true
		end
	end
	for _, entry in content.Tuning.home.nodes do
		usedNodes[entry.nodeId] = true
	end
	for _, enemy in content.Enemies do
		usedLoot[enemy.lootTableId] = true
	end
	for _, loot in content.LootTables do
		for _, entry in loot.entries do
			if entry.tableId then
				usedLoot[entry.tableId] = true
			end
		end
	end
	for _, id in TableUtil.sortedKeys(content.LootTables) do
		if not usedLoot[id] then
			push(errors, `LootTables['{id}']: not used by any location container, enemy or nested entry`)
		end
	end
	for _, id in TableUtil.sortedKeys(content.Nodes) do
		if not usedNodes[id] then
			push(errors, `Nodes['{id}']: not placed in any location or on the home plot`)
		end
	end
	for _, id in TableUtil.sortedKeys(content.Enemies) do
		if not usedEnemies[id] then
			push(errors, `Enemies['{id}']: not spawned in any location`)
		end
	end

	local placedStations: { [string]: boolean } = {}
	for _, piece in content.BuildPieces do
		if piece.stationId then
			placedStations[piece.stationId] = true
		end
	end
	for _, id in TableUtil.sortedKeys(content.Stations) do
		if not placedStations[id] then
			push(errors, `Stations['{id}']: no build piece places it`)
		end
	end

	local gatedBy: { [string]: boolean } = {}
	local function noteGate(gate: Types.UnlockGate?)
		if gate and gate.kind == "blueprint" then
			gatedBy[gate.itemId] = true
		end
	end
	for _, recipe in content.Recipes do
		noteGate(recipe.unlock)
	end
	for _, piece in content.BuildPieces do
		noteGate(piece.unlock)
	end

	-- Every way to earn an item in play. Products are left out on purpose: an item
	-- that can only be bought breaks the "fair pacing" guardrail.
	local earnable: ItemSet = {}
	local function addStacks(stacks: { Types.ItemStack }?)
		if stacks then
			for _, stack in stacks do
				earnable[stack.itemId] = true
			end
		end
	end
	for _, recipe in content.Recipes do
		addStacks(recipe.outputs)
	end
	for _, node in content.Nodes do
		for _, yield in node.yields do
			earnable[yield.itemId] = true
		end
	end
	for _, loot in content.LootTables do
		addLootItems(earnable, content, loot)
	end
	for _, station in content.Stations do
		if station.salvage then
			for _, salvage in station.salvage do
				for _, output in salvage.outputs do
					earnable[output.itemId] = true
				end
			end
		end
	end
	for _, quest in content.Quests do
		addStacks(quest.rewards.items)
	end
	for _, level in content.Levels do
		addStacks(level.rewards)
	end
	addStacks(content.Tuning.newPlayer.items)
	-- Fog Runs: location quests and death-milestone gifts pay out too.
	for _, location in content.Locations do
		for _, quest in (if location.run then location.run.quests else {}) :: { Types.LocationQuest } do
			addStacks(quest.rewards.items)
		end
	end
	for _, milestone in content.Tuning.deathRecovery.milestones do
		addStacks(milestone.items)
	end
	local flags = content.Tuning.features :: any

	for _, id in TableUtil.sortedKeys(content.Items) do
		local item = content.Items[id]
		-- An item made only by a switched-off feature's recipes can't be earned yet, by design.
		local dormant = item.feature ~= nil and flags[item.feature] ~= true
		if not earnable[id] and not dormant then
			push(errors, `Items['{id}']: can't be earned in play (no recipe, node, loot, salvage or reward gives it)`)
		end
		if item.category == "blueprint" and not gatedBy[id] then
			push(errors, `Items['{id}']: blueprint doesn't unlock any recipe or build piece`)
		end
	end
end

-- Returns every problem found in `content`, sorted. An empty list means valid.
function DataValidator.validate(content: Types.Content): { string }
	local errors: Errors = {}

	checkIds(errors, "Items", "item", content.Items, function(def: Types.ItemDef)
		return def.id
	end)
	checkIds(errors, "Recipes", "recipe", content.Recipes, function(def: Types.RecipeDef)
		return def.id
	end)
	checkIds(errors, "Stations", "station", content.Stations, function(def: Types.StationDef)
		return def.id
	end)
	checkIds(errors, "Nodes", "node", content.Nodes, function(def: Types.ResourceNodeDef)
		return def.id
	end)
	checkIds(errors, "LootTables", "loot", content.LootTables, function(def: Types.LootTableDef)
		return def.id
	end)
	checkIds(errors, "Enemies", "enemy", content.Enemies, function(def: Types.EnemyDef)
		return def.id
	end)
	checkIds(errors, "Locations", "loc", content.Locations, function(def: Types.LocationDef)
		return def.id
	end)
	checkIds(errors, "BuildPieces", "build", content.BuildPieces, function(def: Types.BuildPieceDef)
		return def.id
	end)
	checkIds(errors, "Quests", "quest", content.Quests, function(def: Types.QuestDef)
		return def.id
	end)
	checkIds(errors, "Products", "product", content.Products, function(def: Types.ProductDef)
		return def.id
	end)

	checkItems(errors, content)
	checkRecipes(errors, content)
	checkStations(errors, content)
	checkNodes(errors, content)
	checkLootTables(errors, content)
	checkEnemies(errors, content)
	checkLocations(errors, content)
	checkBuildPieces(errors, content)
	checkLevels(errors, content)
	checkQuests(errors, content)
	checkProducts(errors, content)
	checkTuning(errors, content)
	checkFeatureTags(errors, content)
	checkUsage(errors, content)

	table.sort(errors)
	return errors
end

return DataValidator
