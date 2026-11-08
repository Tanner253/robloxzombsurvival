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
	- LDoE parity (LDOE_PARITY.md): station recipes are converter lines (one input, one
	  output); recipes and pieces never use level gates (#49); the Ember Trail can be
	  played in order (each quest's recipes and pieces are unlocked by a quest before it);
	  the starter shelter builds on both rows of plots; projects name real parts
]]

local Types = require("../Types")
local TableUtil = require("../Util/Table")
local Grid = require("./Grid")
local Shelter = require("./Shelter")

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
	if gate.kind == "quest" then
		if content.Quests[gate.questId] == nil then
			push(errors, `{where}: unknown quest '{gate.questId}'`)
		end
	elseif gate.kind == "blueprint" then
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
		end
		if item.armor and item.armor.defense <= 0 then
			push(errors, `{where}.armor: defense must be positive`)
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
		if recipe.stationId ~= nil and (#recipe.inputs ~= 1 or #recipe.outputs ~= 1) then
			push(errors, `{where}: station recipes convert exactly one input stack into one output stack`)
		end
		if recipe.unlock.kind == "level" then
			push(errors, `{where}: recipes unlock through quests or schematics, not levels`)
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
		local previousCap = 0
		for index, level in station.levels do
			local levelWhere = `{where}.levels[{index}]`
			if level.level ~= index then
				push(errors, `{levelWhere}: level must be {index}`)
			end
			if not isPositiveInteger(level.slotCap) then
				push(errors, `{levelWhere}: slotCap must be a positive integer`)
			elseif level.slotCap <= previousCap then
				push(errors, `{levelWhere}: slotCap must grow with each level`)
			else
				previousCap = level.slotCap
			end
			if level.speedMultiplier <= 0 then
				push(errors, `{levelWhere}: speedMultiplier must be positive`)
			end
			checkStacks(errors, content, `{levelWhere}.upgradeCost`, level.upgradeCost)
			if index > 1 and #level.upgradeCost == 0 then
				push(errors, `{levelWhere}: upgrades past level 1 need an upgradeCost`)
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
		if station.outputSlots ~= nil and not isPositiveInteger(station.outputSlots) then
			push(errors, `{where}: outputSlots must be a positive integer`)
		end
		local outputs = station.outputSlots or 1
		local salvageList: { Types.SalvageDef } = station.salvage or {}
		for _, salvage in salvageList do
			if #salvage.outputs > outputs then
				push(errors, `{where}: '{salvage.inputItemId}' breaks into more items than its {outputs} output slots`)
			end
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
		end
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
		if piece.unlock and piece.unlock.kind == "level" then
			push(errors, `{where}: pieces unlock through quests or schematics, not levels`)
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
	if objective.flag ~= nil and type(objective.flag) ~= "string" then
		push(errors, `{where}: flag must be a feature flag name`)
	end
	local count = (objective :: any).count
	if count ~= nil and not isPositiveInteger(count) then
		push(errors, `{where}: count must be a positive integer`)
	end
end

-- The quests a quest's prerequisite chain completes before it.
local function ancestors(content: Types.Content, quest: Types.QuestDef): { [string]: boolean }
	local result: { [string]: boolean } = {}
	local current = if quest.prerequisite then content.Quests[quest.prerequisite] else nil
	while current and not result[current.id] do
		result[current.id] = true
		current = if current.prerequisite then content.Quests[current.prerequisite] else nil
	end
	return result
end

-- Whether a gate is met by default, by a schematic, or by one of `done`'s quests.
local function gateOpen(gate: Types.UnlockGate?, done: { [string]: boolean }): boolean
	if gate == nil or gate.kind == "default" or gate.kind == "blueprint" then
		return true
	elseif gate.kind == "quest" then
		return done[gate.questId] == true
	end
	return false
end

local function checkQuests(errors: Errors, content: Types.Content)
	local starts = 0
	local orders: { [number]: string } = {}
	for _, id in TableUtil.sortedKeys(content.Quests) do
		local quest = content.Quests[id]
		local where = `Quests['{id}']`
		if not isPositiveInteger(quest.order) then
			push(errors, `{where}: order must be a positive integer`)
		elseif orders[quest.order] then
			push(errors, `{where}: order {quest.order} is also '{orders[quest.order]}'`)
		else
			orders[quest.order] = id
		end
		if quest.chapter == "" then
			push(errors, `{where}: needs a chapter`)
		end
		local prerequisite = if quest.prerequisite then content.Quests[quest.prerequisite] else nil
		if prerequisite and prerequisite.order >= quest.order then
			push(errors, `{where}: comes before its prerequisite on the trail`)
		end
		-- Playable in order: what it asks you to craft or build is unlocked before it opens.
		local done = ancestors(content, quest)
		for index, objective in quest.objectives do
			local objectiveWhere = `{where}.objectives[{index}]`
			if objective.kind == "craft" then
				local recipe = content.Recipes[objective.recipeId]
				if recipe and not gateOpen(recipe.unlock, done) then
					push(errors, `{objectiveWhere}: '{objective.recipeId}' is still locked when the quest opens`)
				end
			elseif objective.kind == "build" then
				local piece = content.BuildPieces[objective.pieceId]
				if piece and not gateOpen(piece.unlock, done) then
					push(errors, `{objectiveWhere}: '{objective.pieceId}' is still locked when the quest opens`)
				end
			end
		end
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
	if survival.warnAt < 0 or survival.warnAt > math.min(survival.hunger.max, survival.thirst.max) then
		push(errors, "Tuning.survival: warnAt must be between 0 and the meters' max")
	end
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
	checkStacks(errors, content, "Tuning.dailyGift.items", tuning.dailyGift.items)
	checkLevel(errors, content, "Tuning.dailyGift.untilLevel", tuning.dailyGift.untilLevel)
	checkLocationNodes(errors, content, "Tuning.home.nodes", tuning.home.nodes)
	for index, nodeId in tuning.home.renewing do
		local listed = false
		for _, entry in tuning.home.nodes do
			listed = listed or entry.nodeId == nodeId
		end
		if not listed then
			push(errors, `Tuning.home.renewing[{index}]: '{nodeId}' doesn't grow at home`)
		end
	end
end

-- The starter shelter and projects (LDOE_PARITY #56) ---------------------------------------------

local function checkOnboarding(errors: Errors, content: Types.Content)
	local cells = content.Tuning.building.plotCells
	local plot: Grid.Plot = { ownerUserId = 1, width = cells, depth = cells }
	for _, front in { 1, -1 } do
		local _, reason = Shelter.build(content.StarterShelter, content.BuildPieces, plot, front, 0)
		if reason then
			push(errors, `StarterShelter (front {front}): {reason}`)
		end
	end
	for index, piece in content.StarterShelter do
		if piece.hp <= 0 or piece.hp > 1 then
			push(errors, `StarterShelter[{index}]: hp must be a fraction in (0, 1]`)
		end
	end
	for _, id in TableUtil.sortedKeys(content.Projects) do
		local project = content.Projects[id]
		local where = `Projects['{id}']`
		if project.id ~= id or string.match(id, "^project%.[%l%d_]+$") == nil then
			push(errors, `{where}: key must equal its id, of the form 'project.snake_case'`)
		end
		if #project.parts == 0 then
			push(errors, `{where}: needs at least one part`)
		end
		checkStacks(errors, content, `{where}.parts`, project.parts)
		if project.rewards then
			checkStacks(errors, content, `{where}.rewards`, project.rewards)
		end
	end
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
	addStacks(content.Tuning.dailyGift.items)

	for _, id in TableUtil.sortedKeys(content.Items) do
		local item = content.Items[id]
		if not earnable[id] then
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
	checkOnboarding(errors, content)
	checkUsage(errors, content)

	table.sort(errors)
	return errors
end

return DataValidator
