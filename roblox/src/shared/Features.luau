--!strict
--[[
	Features: feature flags (Tuning.features) and the content they hide.

	A feature that isn't graded A yet stays hidden (PLAYER_EXPERIENCE_CHECKLIST §0:
	"never visible below A"). Content tagged `feature = "<name>"` (recipes, stations
	and build pieces, the things menus list) is left out of the bundle while that
	flag is off, so neither the server nor any client screen can see it. Untagged
	content must never point at tagged content; the data validator runs on the
	stripped bundle at boot and in the Lune suite, so a stray reference fails the
	build.

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
	Leaves out every recipe, station and build piece whose feature flag is off.
	Replaces those three tables on `content` with filtered copies (the entries are
	shared, never copied) and returns `content`. Runs before the bundle is frozen.
]]
function Features.strip(content: Types.Content): Types.Content
	local tuning = content.Tuning
	content.Recipes = filter(content.Recipes, tuning, function(def: Types.RecipeDef)
		return def.feature
	end)
	content.Stations = filter(content.Stations, tuning, function(def: Types.StationDef)
		return def.feature
	end)
	content.BuildPieces = filter(content.BuildPieces, tuning, function(def: Types.BuildPieceDef)
		return def.feature
	end)
	return content
end

return Features
