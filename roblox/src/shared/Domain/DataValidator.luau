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
	- every item, station, loot table and build piece reference points at an entry
	- counts, weights, ranges, levels and timings are sane
]]

local Types = require("../Types")
local TableUtil = require("../Util/Table")

local DataValidator = {}

local ID_FORM = "^%l+%.[%l%d_]+$"

type Errors = { string }

local function push(errors: Errors, message: string)
	table.insert(errors, message)
end

local function isPositiveInteger(value: number): boolean
	return value >= 1 and value % 1 == 0
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

local function checkItems(errors: Errors, content: Types.Content)
	for _, id in TableUtil.sortedKeys(content.Items) do
		local item = content.Items[id]
		local where = `Items['{id}']`
		if not isPositiveInteger(item.stackSize) then
			push(errors, `{where}: stackSize must be a positive integer`)
		end
		if item.durability ~= nil and item.stackSize ~= 1 then
			push(errors, `{where}: only items with stackSize 1 can have durability`)
		end
		if not isPositiveInteger(item.tier) then
			push(errors, `{where}: tier must be a positive integer`)
		end
	end
end

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
		end
		if recipe.craftSeconds < 0 then
			push(errors, `{where}: craftSeconds must not be negative`)
		end
		local unlock = recipe.unlock
		if unlock.kind == "blueprint" then
			checkItemRef(errors, content, `{where}.unlock`, unlock.itemId)
		elseif unlock.kind == "level" and not isPositiveInteger(unlock.level) then
			push(errors, `{where}.unlock: level must be a positive integer`)
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
		for index, level in station.levels do
			if level.level ~= index then
				push(errors, `{where}.levels[{index}]: level must be {index}`)
			end
			if not isPositiveInteger(level.queueSlots) then
				push(errors, `{where}.levels[{index}]: queueSlots must be a positive integer`)
			end
			if level.speedMultiplier <= 0 then
				push(errors, `{where}.levels[{index}]: speedMultiplier must be positive`)
			end
			checkStacks(errors, content, `{where}.levels[{index}].upgradeCost`, level.upgradeCost)
		end
		if station.fuel then
			for index, itemId in station.fuel.itemIds do
				checkItemRef(errors, content, `{where}.fuel.itemIds[{index}]`, itemId)
			end
			if station.fuel.secondsPerUnit <= 0 then
				push(errors, `{where}.fuel: secondsPerUnit must be positive`)
			end
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
		for index, entry in loot.entries do
			local entryWhere = `{where}.entries[{index}]`
			checkItemRef(errors, content, entryWhere, entry.itemId)
			if entry.weight <= 0 then
				push(errors, `{entryWhere}: weight must be positive`)
			end
			if not isPositiveInteger(entry.min) or entry.min > entry.max then
				push(errors, `{entryWhere}: need 1 <= min <= max`)
			end
		end
		if loot.guaranteed then
			checkStacks(errors, content, `{where}.guaranteed`, loot.guaranteed)
		end
	end
end

local function checkLocations(errors: Errors, content: Types.Content)
	for _, id in TableUtil.sortedKeys(content.Locations) do
		local location = content.Locations[id]
		local where = `Locations['{id}']`
		for index, lootId in location.lootTableIds do
			if content.LootTables[lootId] == nil then
				push(errors, `{where}.lootTableIds[{index}]: unknown loot table '{lootId}'`)
			end
		end
		if location.energyCost < 0 or location.walkSeconds < 0 then
			push(errors, `{where}: energyCost and walkSeconds must not be negative`)
		end
		if location.resetSeconds ~= nil and location.resetSeconds <= 0 then
			push(errors, `{where}: resetSeconds must be positive when set`)
		end
	end
end

local function checkBuildPieces(errors: Errors, content: Types.Content)
	for _, id in TableUtil.sortedKeys(content.BuildPieces) do
		local piece = content.BuildPieces[id]
		local where = `BuildPieces['{id}']`
		checkStacks(errors, content, `{where}.cost`, piece.cost)
		if piece.hp <= 0 then
			push(errors, `{where}: hp must be positive`)
		end
		if piece.breachCost < 1 then
			push(errors, `{where}: breachCost must be at least 1 (nothing is unbreachable)`)
		end
		if piece.upgradesTo ~= nil and content.BuildPieces[piece.upgradesTo] == nil then
			push(errors, `{where}: unknown upgradesTo piece '{piece.upgradesTo}'`)
		end
		if piece.stationId ~= nil and content.Stations[piece.stationId] == nil then
			push(errors, `{where}: unknown station '{piece.stationId}'`)
		end
		if piece.kind == "station" and piece.stationId == nil then
			push(errors, `{where}: station pieces need a stationId`)
		end
	end
end

local function checkProducts(errors: Errors, content: Types.Content)
	for _, id in TableUtil.sortedKeys(content.Products) do
		local product = content.Products[id]
		local where = `Products['{id}']`
		if #product.grants == 0 then
			push(errors, `{where}: needs at least one grant`)
		end
		for index, grant in product.grants do
			if grant.kind == "item" then
				checkItemRef(errors, content, `{where}.grants[{index}]`, grant.itemId)
				if not isPositiveInteger(grant.count) then
					push(errors, `{where}.grants[{index}]: count must be a positive integer`)
				end
			elseif not isPositiveInteger(grant.amount) then
				push(errors, `{where}.grants[{index}]: amount must be a positive integer`)
			end
		end
	end
end

local function checkTuning(errors: Errors, content: Types.Content)
	local tuning = content.Tuning
	local inventory = tuning.inventory
	if tuning.energy.cap <= 0 or tuning.energy.secondsPerPoint <= 0 then
		push(errors, "Tuning.energy: cap and secondsPerPoint must be positive")
	end
	if not isPositiveInteger(inventory.pocketSlots) or inventory.backpackSlots > inventory.maxBackpackSlots then
		push(errors, "Tuning.inventory: need pocketSlots >= 1 and backpackSlots <= maxBackpackSlots")
	end
	if tuning.raid.lootFraction < 0 or tuning.raid.lootFraction > 1 then
		push(errors, "Tuning.raid: lootFraction must be between 0 and 1")
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
	checkIds(errors, "LootTables", "loot", content.LootTables, function(def: Types.LootTableDef)
		return def.id
	end)
	checkIds(errors, "Locations", "loc", content.Locations, function(def: Types.LocationDef)
		return def.id
	end)
	checkIds(errors, "BuildPieces", "build", content.BuildPieces, function(def: Types.BuildPieceDef)
		return def.id
	end)
	checkIds(errors, "Products", "product", content.Products, function(def: Types.ProductDef)
		return def.id
	end)

	checkItems(errors, content)
	checkRecipes(errors, content)
	checkStations(errors, content)
	checkLootTables(errors, content)
	checkLocations(errors, content)
	checkBuildPieces(errors, content)
	checkProducts(errors, content)
	checkTuning(errors, content)

	table.sort(errors)
	return errors
end

return DataValidator
