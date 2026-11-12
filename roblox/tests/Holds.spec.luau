--!strict
-- Data/Holds and Domain/HoldRules (2.0 batch 1): every holdable item has a grip and a class,
-- every class's clips exist and are well formed, and every clip the code names is one it loads.
local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Holds = require("../src/shared/Data/Holds")
local UalClips = require("../src/shared/Data/UalClips")
local HoldRules = require("../src/shared/Domain/HoldRules")

local Items: any = Content.Items
local USES = { "carry", "swing", "heavy", "aim", "recoil", "reload" }
local GUN_CLASSES = { pistol = true, long = true, bow = true }

local function holdable(def: any): boolean
	return def.tool ~= nil or def.equipSlot == "weapon"
end

-- Content behind a feature that is off (content2 until its Studio pass) can't be held yet;
-- switching the feature on brings its items under this spec, so they need grips first.
local function shipped(def: any): boolean
	return def.feature == nil or (Content.Tuning.features :: any)[def.feature] == true
end

-- The body of a `Name = { ... } :: ...` table in Art.luau (read as source: it uses Roblox types).
local function block(source: string, opener: string, closer: string): string
	local _, from = string.find(source, opener, 1, true)
	assert(from, `{opener} in Art.luau`)
	local to = string.find(source, closer, from, true)
	assert(to, `{closer} after {opener}`)
	return string.sub(source, from, to)
end

local function listFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			listFiles(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
end

return function(test: TestKit.Register)
	test("every holdable item has a class, a grip and a model in Art", function()
		local art = fs.readFile("src/shared/Art.luau")
		local held = block(art, "Art.held = {", "\n} :: { [string]: HeldArt }")
		local models = block(art, "Art.items = {", "\n} :: { [string]: { string } }")
		local count = 0
		for id, def in Items do
			if holdable(def) and shipped(def) then
				count += 1
				local class = Holds.items[id]
				TestKit.truthy(class, `{id} has a hold class in Data/Holds`)
				TestKit.truthy(Holds.classes[class], `{id}'s class {class} exists`)
				TestKit.truthy(string.find(held, `["{id}"] = \{`, 1, true), `{id} has an Art.held grip`)
				TestKit.truthy(string.find(models, `["{id}"] = \{`, 1, true), `{id} has a model, not a built stand-in`)
			end
		end
		TestKit.truthy(count >= 20, `{count} holdable items`)
		for id in Holds.items do
			TestKit.truthy(Items[id] and holdable(Items[id]), `Data/Holds lists {id}, which is holdable`)
		end
	end)

	test("guns and the bow sit along the forearm; everything else ahead of the fist", function()
		for name, class in Holds.classes do
			TestKit.equal(class.mount, if GUN_CLASSES[name] then "gun" else "fist", name)
		end
		for id, def in Items do
			if def.weapon and def.weapon.kind == "ranged" then
				TestKit.equal(HoldRules.mountOf(id, def), "gun", id)
			elseif holdable(def) then
				TestKit.equal(HoldRules.mountOf(id, def), "fist", id)
			end
		end
	end)

	test("every clip a class names exists; melee classes swing and guns aim", function()
		for name, class in Holds.classes do
			for _, use in USES do
				local clip = (class :: any)[use]
				if clip then
					TestKit.truthy(Holds.clips[clip], `{name}.{use} = {clip} is a clip`)
				end
			end
			if GUN_CLASSES[name] then
				TestKit.truthy(class.aim and class.carry, `{name} aims and carries`)
			else
				TestKit.truthy(class.swing and class.heavy, `{name} swings`)
				TestKit.truthy(Holds.clips[class.swing :: string].hit, `{name}'s swing has a hit frame`)
			end
		end
		for _, name in Holds.gather do
			TestKit.truthy(Holds.clips[name] and Holds.clips[name].hit, `gather clip {name}`)
		end
	end)

	test("clips are well formed: keys in order, poses on real parts, hit inside the clip", function()
		for name, clip in Holds.clips do
			TestKit.truthy(#clip.keys >= 2, `{name} has keys`)
			TestKit.equal(clip.keys[1].time, 0, `{name} starts at 0`)
			local last = -1
			for _, key in clip.keys do
				TestKit.truthy(key.time > last, `{name}: keys in time order`)
				last = key.time
				for part, pose in key.poses do
					TestKit.truthy(Holds.PARENTS[part], `{name}: {part} is a rig part`)
					TestKit.truthy(#pose == 3 or #pose == 6, `{name}: {part} pose has 3 angles (+3 offsets)`)
					for _, value in pose do
						TestKit.truthy(type(value) == "number" and value == value, `{name}: {part} numbers`)
					end
				end
			end
			TestKit.truthy(last <= clip.length + 1e-9, `{name}: last key inside its length`)
			if clip.loop then
				TestKit.equal(last, clip.length, `{name}: a loop ends on its length`)
			end
			if clip.hit then
				TestKit.truthy(clip.hit > 0 and clip.hit < clip.length, `{name}: hit frame inside the clip`)
			end
			if clip.ual then
				TestKit.truthy(UalClips.clips[clip.ual], `{name}: UAL clip {clip.ual} exists`)
			end
		end
	end)

	test("every clip the code plays by name is in Data/Holds", function()
		local files: { string } = {}
		listFiles("src/client", files)
		listFiles("src/server", files)
		local named: { [string]: string } = {}
		for _, path in files do
			local source = fs.readFile(path)
			-- Animations.play(character, "name") / play(character, "name") / Clips.play(...)
			for name in string.gmatch(source, '[pP]lay%([^,%)]+,%s*"(%w+)"') do
				named[name] = path
			end
			-- The server's "act" effects name the action the other clients play.
			for name in string.gmatch(source, 'action = "(%w+)"') do
				named[name] = path
			end
		end
		local found = 0
		for name, path in named do
			found += 1
			TestKit.truthy(Holds.clips[name], `{path} plays "{name}", which Data/Holds defines`)
		end
		TestKit.truthy(found >= 5, `{found} clip names found in code`)
		for _, consume in { { thirst = 45 }, { health = 40 }, { hunger = 30, health = 15 }, { energy = 25 } } do
			TestKit.truthy(Holds.clips[HoldRules.consumeAction(consume)], "consume actions are clips")
		end
	end)

	test("pose limits: every held stance keeps both arms out of the chest (batch 5)", function()
		-- The batch-3 long carry, which put the gun forearm 0.47 studs into the chest in Studio:
		-- the rule must catch it.
		local clipped = {
			UpperTorso = { 0, -42, 0 },
			RightUpperArm = { 8.7, 43.7, -37.3 },
			RightLowerArm = { 46.9, 38, -14.3 },
		}
		TestKit.truthy(not HoldRules.armClear(clipped, "Right"), "the old low ready is caught")
		local elbow = HoldRules.armPoints(clipped, "Right")
		TestKit.truthy(
			math.abs(elbow[1] - 0.33) < 0.03 and math.abs(elbow[3] - 0.22) < 0.03,
			"FK matches Studio's elbow"
		)
		-- Arms hanging at rest are clear.
		TestKit.truthy(HoldRules.armClear({}, "Right") and HoldRules.armClear({}, "Left"), "rest")
		local checked = 0
		local names: { [string]: boolean } = { throw = true, reload = true }
		for _, class in Holds.classes do
			for _, use in { "carry", "aim", "recoil" } do
				local clip = (class :: any)[use]
				if clip and class.mount == "gun" then
					names[clip] = true
				end
			end
		end
		for name in names do
			for _, key in Holds.clips[name].keys do
				for _, side in { "Right", "Left" } do
					if key.poses[side .. "UpperArm"] then
						checked += 1
						TestKit.truthy(
							HoldRules.armClear(key.poses, side),
							`{name} at {key.time}: the {side} arm clears the chest`
						)
					end
				end
			end
		end
		TestKit.truthy(checked >= 20, `{checked} arm keys checked`)
	end)

	test("classOf: listed items by Data/Holds, new ones by their kind, empty hands are fists", function()
		TestKit.equal(HoldRules.classOf(nil, nil), "fists")
		TestKit.equal(HoldRules.classOf("", nil), "fists")
		TestKit.equal(HoldRules.classOf("item.sharpened_stake", Items["item.sharpened_stake"]), "stab")
		TestKit.equal(HoldRules.classOf("item.assault_rifle", Items["item.assault_rifle"]), "long")
		TestKit.equal(HoldRules.classOf("item.duty_pistol", Items["item.duty_pistol"]), "pistol")
		TestKit.equal(HoldRules.classOf("item.new_pick", { tool = { kind = "pick" } }), "pick")
		TestKit.equal(HoldRules.classOf("item.new_axe", { tool = { kind = "hatchet" } }), "axe")
		TestKit.equal(HoldRules.classOf("item.new_bow", { weapon = { kind = "ranged", bow = {} } }), "bow")
		local smg = { weapon = { kind = "ranged", firearm = { animClass = "smg" } } }
		TestKit.equal(HoldRules.classOf("item.new_smg", smg), "long")
		local pistol = { weapon = { kind = "ranged", firearm = { animClass = "pistol" } } }
		TestKit.equal(HoldRules.classOf("item.new_pistol", pistol), "pistol")
		TestKit.equal(HoldRules.classOf("item.new_club", { weapon = { kind = "melee" } }), "blunt")
	end)

	test("a light blow lands on its swing's hit frame, before the next swing may start", function()
		TestKit.equal(HoldRules.strikeDelay("blade", false), Holds.clips.slash.hit)
		TestKit.equal(HoldRules.strikeDelay("stab", true), Holds.clips.lunge.hit)
		TestKit.equal(HoldRules.strikeDelay("long", false), 0, "guns don't swing")
		local melee = Content.Tuning.melee
		for id, def in Items do
			if holdable(def) and not (def.weapon and def.weapon.kind == "ranged") then
				local class = HoldRules.classOf(id, def)
				local rate = if def.weapon then def.weapon.attacksPerSecond else melee.toolAttacksPerSecond
				TestKit.truthy(HoldRules.strikeDelay(class, false) < 1 / rate, `{id}: the blow lands inside one swing`)
			end
		end
		local fists = Content.Tuning.player.fistAttacksPerSecond
		TestKit.truthy(HoldRules.strikeDelay("fists", false) < 1 / fists, "a punch lands inside one swing")
	end)

	test("F-29: a tool in a weapon slot beats bare fists but not the weakest crafted weapon", function()
		local melee = Content.Tuning.melee
		local player = Content.Tuning.player
		local tool = melee.toolDamage * melee.toolAttacksPerSecond
		local fists = player.fistDamage * player.fistAttacksPerSecond
		TestKit.truthy(tool > fists, `tool {tool} a second against fists {fists}`)
		TestKit.truthy(melee.toolDamage > player.fistDamage, "each blow hits harder than a punch")
		local weakest = math.huge
		for _, def in Items do
			if def.weapon and def.weapon.kind == "melee" then
				weakest = math.min(weakest, def.weapon.damage * def.weapon.attacksPerSecond)
			end
		end
		TestKit.truthy(tool <= weakest, `tool {tool} a second against the weakest weapon's {weakest}`)
	end)

	test("consumables play the action they mostly are", function()
		TestKit.equal(HoldRules.consumeAction(Items["item.boiled_water"].consume), "drink")
		TestKit.equal(HoldRules.consumeAction(Items["item.field_dressing"].consume), "bandage")
		TestKit.equal(HoldRules.consumeAction(Items["item.hearth_stew"].consume), "eat")
		TestKit.equal(HoldRules.consumeAction(Items["item.ember_tea"].consume), "drink")
		TestKit.equal(HoldRules.consumeAction(nil), "eat")
	end)
end
