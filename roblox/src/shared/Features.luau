--!strict
--[[
	Features: feature flags (Tuning.features) and the content they hide.

	A feature that isn't graded A yet stays hidden (PLAYER_EXPERIENCE_CHECKLIST §0:
	"never visible below A"). Content tagged `feature = "<name>"` (recipes, stations,
	build pieces, Ember Trail quests and single loot-table rows) is left out of the
	bundle while that flag is off, so neither the server nor any client screen can see
	it, and nothing drops it. Tagged items stay in the bundle but nothing gives them
	(the validator lets a tagged item go unearned). A kept piece whose `upgradesTo` was
	left out loses that link, so the tier below simply tops out. Untagged content must
	never point at tagged content; the data validator runs on the stripped bundle at
	boot and in the Lune suite, so a stray reference fails the build.

	Services behind a flag check `Features.on(tuning, name)` in init() and stay
	idle when it is off; Net/Remotes leaves their remotes out the same way.
]]

local Types = require("./Types")

local Features = {}

-- Whether a flag is on in this tuning table.
function Features.on(tuning: Types.TuningDef, name: Types.FeatureName): boolean
	return (tuning.features :: any)[name] == true
end

local function keep(tuning: Types.TuningDef, feature: Types.FeatureName?): boolean
	return feature == nil or Features.on(tuning, feature)
end

local function filter<T>(
	defs: { [string]: T },
	tuning: Types.TuningDef,
	featureOf: (T) -> Types.FeatureName?
): { [string]: T }
	local kept: { [string]: T } = {}
	for id, def in defs do
		if keep(tuning, featureOf(def)) then
			kept[id] = def
		end
	end
	return kept
end

--[[
	Leaves out every recipe, station, build piece, quest and loot-table row whose feature
	flag is off. Replaces those tables on `content` with filtered copies and returns
	`content`; untouched entries are shared, and only a loot table that lost a row, or a
	piece that lost its upgrade, is copied. Runs before the bundle is frozen.
]]
function Features.strip(content: Types.Content): Types.Content
	local tuning = content.Tuning
	content.Recipes = filter(content.Recipes, tuning, function(def: Types.RecipeDef)
		return def.feature
	end)
	content.Stations = filter(content.Stations, tuning, function(def: Types.StationDef)
		return def.feature
	end)
	local pieces = filter(content.BuildPieces, tuning, function(def: Types.BuildPieceDef)
		return def.feature
	end)
	for id, def in pieces do
		if def.upgradesTo ~= nil and pieces[def.upgradesTo] == nil then
			local copy = table.clone(def)
			copy.upgradesTo = nil
			pieces[id] = copy
		end
	end
	content.BuildPieces = pieces
	content.Quests = filter(content.Quests, tuning, function(def: Types.QuestDef)
		return def.feature
	end)
	local tables: { [string]: Types.LootTableDef } = {}
	for id, def in content.LootTables do
		local entries: { Types.LootEntry } = {}
		for _, entry in def.entries do
			if keep(tuning, entry.feature) then
				table.insert(entries, entry)
			end
		end
		if #entries == #def.entries then
			tables[id] = def
		else
			local copy = table.clone(def)
			copy.entries = entries
			tables[id] = copy
		end
	end
	content.LootTables = tables
	return content
end

return Features
