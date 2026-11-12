--!strict
--[[
	Content 2.0, batch 4 (docs/CONTENT_2_0.md): everything is behind
	Tuning.features.content2, on since batch 4b's Studio pass graded its models. With the flag
	off, nothing new reaches a player: no recipe, station, build piece, quest or loot row names
	any of it, and the items are dormant. With it on, the bundle validates and every new item
	can be earned. The rules it adds are pure (Domain/Gear, Domain/Meds,
	FogExposure.filterWear, Combat.backstab) and checked here too.
]]

local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local DataValidator = require("../src/shared/Domain/DataValidator")
local Features = require("../src/shared/Features")
local Combat = require("../src/shared/Domain/Combat")
local FogExposure = require("../src/shared/Domain/FogExposure")
local Gear = require("../src/shared/Domain/Gear")
local Meds = require("../src/shared/Domain/Meds")
local TableUtil = require("../src/shared/Util/Table")
local Types = require("../src/shared/Types")

local RawItems = require("../src/shared/Data/Items")
local RawRecipes = require("../src/shared/Data/Recipes")
local RawStations = require("../src/shared/Data/Stations")
local RawPieces = require("../src/shared/Data/BuildPieces")
local RawQuests = require("../src/shared/Data/Quests")
local RawLoot = require("../src/shared/Data/LootTables")

-- The raw content modules (nothing stripped), as a fresh mutable copy.
local function rawContent(): any
	return TableUtil.deepCopy({
		Items = RawItems,
		Recipes = RawRecipes,
		Stations = RawStations,
		Nodes = require("../src/shared/Data/Nodes"),
		LootTables = RawLoot,
		Enemies = require("../src/shared/Data/Enemies"),
		Locations = require("../src/shared/Data/Locations"),
		BuildPieces = RawPieces,
		Levels = require("../src/shared/Data/Levels"),
		Quests = RawQuests,
		Products = require("../src/shared/Data/Products"),
		Haven = require("../src/shared/Data/Haven"),
		Projects = require("../src/shared/Data/Projects"),
		StarterShelter = require("../src/shared/Data/StarterShelter"),
		Tuning = require("../src/shared/Data/Tuning"),
	})
end

-- Every ID the batch adds: items, recipes, stations, pieces and quests tagged content2.
local function newIds(): { [string]: string }
	local ids: { [string]: string } = {}
	local function collect(kind: string, defs: { [string]: any })
		for id, def in defs do
			if def.feature == "content2" then
				ids[id] = kind
			end
		end
	end
	collect("item", RawItems)
	collect("recipe", RawRecipes)
	collect("station", RawStations)
	collect("piece", RawPieces)
	collect("quest", RawQuests)
	return ids
end

-- Every string anywhere under `value` that is one of `ids`, with its path.
local function mentions(value: any, ids: { [string]: string }, path: string, found: { string })
	if type(value) == "string" then
		if ids[value] then
			table.insert(found, `{path} = {value}`)
		end
	elseif type(value) == "table" then
		for key, child in value do
			mentions(child, ids, `{path}.{tostring(key)}`, found)
		end
	end
end

local function report(errors: { string })
	if #errors > 0 then
		error(`{#errors} content error(s):\n        ` .. table.concat(errors, "\n        "), 0)
	end
end

local function withContent2(): any
	local content = rawContent()
	content.Tuning.features.content2 = true
	return Features.strip(content)
end

-- The bundle as it would ship with the flag off (the rollback switch).
local function withoutContent2(): any
	local content = rawContent()
	content.Tuning.features.content2 = false
	return Features.strip(content)
end

local function slot(itemId: string): Types.Slot
	return { itemId = itemId, count = 1, durability = 100 }
end

return function(test: TestKit.Register)
	-- The flag -----------------------------------------------------------------------------
	test("content2 ships on: batch 4b's Studio pass graded its models", function()
		TestKit.equal(Content.Tuning.features.content2, true, "flag")
		for id, kind in newIds() do
			local tables = {
				item = Content.Items,
				recipe = Content.Recipes,
				station = Content.Stations,
				piece = Content.BuildPieces,
				quest = Content.Quests,
			} :: { [string]: any }
			TestKit.truthy(tables[kind][id], `{id} ships`)
		end
	end)

	test("the batch adds 23 items, 18 recipes, 2 stations, 7 pieces, 8 quests and 32 loot rows", function()
		local counts: { [string]: number } = {}
		for _, kind in newIds() do
			counts[kind] = (counts[kind] or 0) + 1
		end
		TestKit.deepEqual(counts, { item = 23, recipe = 18, station = 2, piece = 7, quest = 8 })
		local rows = 0
		for _, loot in RawLoot do
			for _, entry in loot.entries do
				if entry.feature == "content2" then
					rows += 1
					TestKit.truthy(RawItems[entry.itemId :: string].feature == "content2", entry.itemId)
				end
			end
		end
		TestKit.equal(rows, 32, "loot rows")
	end)

	test("flag off: nothing in the bundle names anything new; the items are dormant", function()
		local ids = newIds()
		local found: { string } = {}
		local stripped = withoutContent2()
		for name, section in stripped :: any do
			if name ~= "Items" then
				mentions(section, ids, name, found)
			end
		end
		TestKit.deepEqual(found, {}, "references to content2 outside Items")
		for id, kind in ids do
			if kind == "item" then
				TestKit.truthy(stripped.Items[id], `{id} stays as a dormant item`)
			else
				local tables = {
					recipe = stripped.Recipes,
					station = stripped.Stations,
					piece = stripped.BuildPieces,
					quest = stripped.Quests,
				} :: { [string]: any }
				TestKit.equal(tables[kind][id], nil, `{id} is left out`)
			end
		end
		-- The Reinforced tier tops out: its link up to Fortified is dropped with Fortified.
		TestKit.equal(stripped.BuildPieces["build.wall_reinforced"].upgradesTo, nil, "Reinforced Wall upgrade")
		TestKit.equal(RawPieces["build.wall_reinforced"].upgradesTo, "build.wall_fortified", "raw data keeps it")
	end)

	test("flag on: the bundle validates and every new item can be earned in play", function()
		local content = withContent2()
		report(DataValidator.validate(content))
		for id, kind in newIds() do
			if kind == "quest" then
				TestKit.truthy(content.Quests[id], id)
			end
		end
		TestKit.equal(content.BuildPieces["build.wall_reinforced"].upgradesTo, "build.wall_fortified")
	end)

	test("chapter 4 opens after Hold the Line and runs quests 26 to 33 on two lines", function()
		local content = withContent2()
		local orders: { number } = {}
		for _, quest in content.Quests do
			if quest.chapter == "Iron Lungs" then
				table.insert(orders, quest.order)
			end
		end
		table.sort(orders)
		TestKit.deepEqual(orders, { 26, 27, 28, 29, 30, 31, 32, 33 })
		TestKit.equal(content.Quests["quest.hotter_fires"].prerequisite, "quest.hold_the_line")
		TestKit.equal(content.Quests["quest.hide_and_rivet"].prerequisite, "quest.hold_the_line")
	end)

	-- ARSENAL §4 and §5, exactly ---------------------------------------------------------------
	test("the four melee weapons carry ARSENAL §4's stats and a melee class", function()
		local rows = {
			["item.hand_axe"] = { 20, 1.4, 6, 70, "axe" },
			["item.hardwood_bat"] = { 18, 1.0, 6.5, 80, "blunt" },
			["item.field_knife"] = { 11, 2.0, 4.5, 120, "stab" },
			["item.hay_fork"] = { 16, 0.9, 8.5, 60, "stab" },
		}
		for id, row in rows do
			local item = RawItems[id]
			local weapon = item.weapon :: Types.WeaponStats
			TestKit.deepEqual(
				{ weapon.damage, weapon.attacksPerSecond, weapon.range, item.durability, (weapon.melee :: any).class },
				row,
				id
			)
		end
		-- Below the Machete's DPS (35): they widen the ladder, they don't top it.
		for id in rows do
			local weapon = RawItems[id].weapon :: Types.WeaponStats
			TestKit.truthy(weapon.damage * weapon.attacksPerSecond < 35, id)
		end
	end)

	test("Hidebound and Riveted match ARSENAL §5, and each piece consumes the one below", function()
		local sets = {
			{ ids = { "hidebound_cap", "hidebound_coat", "hidebound_leggings", "hidebound_boots" }, defense = 21 },
			{ ids = { "riveted_helm", "riveted_cuirass", "riveted_legguards", "riveted_boots" }, defense = 28 },
		}
		local below = {
			hidebound_cap = "padded_hood",
			hidebound_coat = "padded_vest",
			hidebound_leggings = "padded_leggings",
			hidebound_boots = "padded_boots",
			riveted_helm = "hidebound_cap",
			riveted_cuirass = "hidebound_coat",
			riveted_legguards = "hidebound_leggings",
			riveted_boots = "hidebound_boots",
		} :: { [string]: string }
		for _, set in sets do
			local equipment: { [string]: Types.Slot } = {}
			for _, short in set.ids do
				local item = RawItems["item." .. short]
				equipment[item.equipSlot :: string] = slot(item.id)
				local consumed = false
				for _, stack in RawRecipes["recipe." .. short].inputs do
					consumed = consumed or stack.itemId == "item." .. below[short]
				end
				TestKit.truthy(consumed, `{short} consumes {below[short]}`)
			end
			TestKit.equal(Gear.defense(equipment, RawItems), set.defense, "set defense")
		end
		local riveted = {
			head = slot("item.riveted_helm"),
			body = slot("item.riveted_cuirass"),
			legs = slot("item.riveted_legguards"),
			feet = slot("item.riveted_boots"),
		}
		local reduction = Gear.reduction(riveted, RawItems, Content.Tuning.combat.armorConstant)
		TestKit.truthy(math.abs(reduction - 0.627) < 0.001, `Riveted reduction {reduction}`)
	end)

	-- The rules -----------------------------------------------------------------------------------
	test("Gear: bag slots add up to the cap, and the bag ladder is +5, +8, +10, +15", function()
		local inventory = Content.Tuning.inventory
		local ladder = {}
		for _, id in { "item.satchel", "item.hide_rucksack", "item.pack_frame", "item.ranger_pack" } do
			table.insert(ladder, RawItems[id].bagSlots)
		end
		TestKit.deepEqual(ladder, { 5, 8, 10, 15 })
		TestKit.equal(Gear.backpackSlots(0, RawItems["item.ranger_pack"], 5, inventory.maxBackpackSlots), 20)
		TestKit.equal(Gear.backpackSlots(0, nil, 0, inventory.maxBackpackSlots), 0)
		TestKit.equal(Gear.backpackSlots(0, RawItems["item.ranger_pack"], 30, 20), 20, "never past the cap")
		TestKit.equal(Gear.armorLevel(RawItems["item.plate_carrier"]), 4)
		TestKit.equal(Gear.armorLevel(RawItems["item.ranger_pack"]), nil)
	end)

	-- The economy batch: maxResist 0.56 (was 0.8, where the mask made Black fog harmless to a
	-- Hidebound or Riveted wearer: 18 and 20 min against a 15 min run).
	test("Gas mask: only its filter reaches the fog cap, and at the cap Black fog still bleeds you", function()
		local config = Content.Tuning.fogExposure
		local run = Content.Tuning.lobby.durationSeconds
		local function minutes(head: string, prefix: string, body: string, legs: string): number
			local equipment = {
				head = slot(head),
				body = slot(`item.{prefix}_{body}`),
				legs = slot(`item.{prefix}_{legs}`),
				feet = slot(`item.{prefix}_boots`),
			} :: { [string]: Types.Slot }
			local resist = FogExposure.resist(equipment, RawItems, config)
			return FogExposure.secondsToFull(0, 3, resist, config) / 60
		end
		local sets = {
			{ "padded", "item.padded_hood", "vest", "leggings", 11.52 },
			{ "hidebound", "item.hidebound_cap", "coat", "leggings", 12.18 },
			{ "riveted", "item.riveted_helm", "cuirass", "legguards", 12.93 },
		}
		local capped = config.max / config.ratePerTier[3] / (1 - config.maxResist) / 60
		TestKit.truthy(math.abs(capped - 14.39) < 0.05, `the cap fills at {capped} min`)
		TestKit.truthy(capped * 60 < run, "the cap still fills inside a run")
		local last = 0
		for _, set in sets do
			local name, helm, body, legs, expected = set[1], set[2], set[3], set[4], set[5]
			local bare = minutes(helm, name, body, legs)
			TestKit.truthy(math.abs(bare - expected) < 0.05, `{name} set: {bare} min`)
			TestKit.truthy(bare > last and bare < capped, `{name}: better than the set below, under the cap`)
			last = bare
			local masked = minutes("item.gas_mask", name, body, legs)
			TestKit.truthy(math.abs(masked - capped) < 1e-6, `{name} with the mask: {masked} min, the cap`)
		end
	end)

	test("Gas mask: the filter wears 1 a second in Dense and Black fog, never in Light", function()
		local config = Content.Tuning.fogExposure
		local equipment = { head = slot("item.gas_mask"), body = slot("item.padded_vest") }
		TestKit.deepEqual(FogExposure.filterWear(equipment, RawItems, 1, 10, config), {}, "Light fog")
		TestKit.deepEqual(FogExposure.filterWear(equipment, RawItems, 2, 10, config), { head = 10 }, "Dense fog")
		TestKit.deepEqual(FogExposure.filterWear(equipment, RawItems, 3, 0.5, config), { head = 0.5 }, "Black fog")
		local run = Content.Tuning.lobby.durationSeconds
		local filter = RawItems["item.gas_mask"].durability :: number
		TestKit.equal(filter, run, "one filter lasts one full run in the fog")
	end)

	test("Meds: instant, then the rest over time; the ladder climbs; three heal at once", function()
		local ladder = {}
		for _, id in { "item.field_dressing", "item.trauma_pouch", "item.first_aid_kit", "item.ember_stim" } do
			table.insert(ladder, Meds.total(RawItems[id].consume :: Types.ConsumeEffect))
		end
		TestKit.deepEqual(ladder, { 40, 65, 100, 110 })
		TestKit.equal(Meds.start(RawItems["item.field_dressing"].consume :: any, 0), nil, "a dressing is instant")
		local kit = Meds.start(RawItems["item.first_aid_kit"].consume :: any, 100) :: Meds.Heal
		local healed, running = Meds.step({ kit }, 106)
		TestKit.equal(healed, 30, "half the kit's 60 over 12 s")
		healed, running = Meds.step(running, 200)
		TestKit.equal(healed, 30, "the rest, never more")
		TestKit.deepEqual(running, {}, "done")
		local heals: { Meds.Heal } = {}
		for amount = 1, 4 do
			heals = Meds.add(heals, { perSecond = 1, remaining = amount * 10, updatedAt = 0 })
		end
		TestKit.equal(#heals, Meds.MAX_ACTIVE, "capped")
		local least = math.huge
		for _, heal in heals do
			least = math.min(least, heal.remaining)
		end
		TestKit.equal(least, 20, "the heal with least left went")
	end)

	test("Field Knife: a x4 backstab and a quiet swing; other weapons keep the tuning's", function()
		local sneak = Content.Tuning.sneak
		local knife = (RawItems["item.field_knife"].weapon :: Types.WeaponStats).melee
		TestKit.equal(Combat.backstab(true, false, sneak, knife), 4)
		TestKit.equal(Combat.backstab(true, false, sneak, nil), sneak.backstabMultiplier)
		TestKit.equal(Combat.backstab(true, true, sneak, knife), 1, "seen")
		TestKit.equal(Combat.meleeNoise(knife, Content.Tuning.noise.melee), 6)
		TestKit.equal(Combat.meleeNoise(nil, Content.Tuning.noise.melee), Content.Tuning.noise.melee)
	end)

	test("Fortified doubles Reinforced's HP, and its stations need the floors", function()
		for _, kind in { "foundation", "wall", "doorway", "door", "window" } do
			local reinforced = RawPieces[`build.{kind}_reinforced`]
			local fortified = RawPieces[`build.{kind}_fortified`]
			TestKit.equal(fortified.hp, reinforced.hp * 2, kind)
			TestKit.equal(fortified.tier, 4, kind)
			TestKit.truthy(fortified.breachCost > reinforced.breachCost, `{kind}: still breachable, harder`)
		end
		TestKit.equal(RawPieces["build.blast_furnace"].minFoundationTier, 3, "Blast Furnace on Reinforced")
		TestKit.equal(RawPieces["build.apothecary"].minFoundationTier, 4, "Apothecary on Fortified")
	end)
end
