--!strict
--[[
	ARSENAL's roster (docs/ARSENAL.md): the first five (HANDOFF §6 step 3) and the rest (2.0
	batch 5; the Combat Shotgun waits for M2). Their stats rows, how each is obtained, the model
	each shows, and the rules the gun path gained for them (a piercing round, a held trigger's
	beat, the Patrol Carbine's burst).
]]
local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Combat = require("../src/shared/Domain/Combat")
local Loot = require("../src/shared/Domain/Loot")
local Credits = require("../src/shared/Data/Credits")

local TUNING = Content.Tuning

-- ARSENAL §3.2 rows: damage, pellets, fire interval, magazine, reload, ARSENAL's shot count,
-- range, class, tier, rarity; §0's kit and asset ID.
type Row = {
	damage: number,
	pellets: number?,
	interval: number,
	magazine: number,
	reload: number,
	shots: number,
	range: number,
	class: string,
	tier: number,
	rarity: string,
	kit: string,
	asset: string,
	credited: boolean?, -- false: Studio's mesh generator made it (ours, no credit row)
}
local GUNS: { [string]: Row } = {
	["item.duty_pistol"] = {
		damage = 22,
		interval = 0.3,
		magazine = 12,
		reload = 1.6,
		shots = 90,
		range = 70,
		class = "pistol",
		tier = 3,
		rarity = "uncommon",
		kit = "EO_DutyPistol",
		asset = "72665632302595",
	},
	["item.pump_shotgun"] = {
		damage = 10,
		pellets = 8,
		interval = 0.9,
		magazine = 5,
		reload = 3,
		shots = 28,
		range = 32,
		class = "shotgun",
		tier = 3,
		rarity = "uncommon",
		kit = "EO_PumpShotgun",
		asset = "102438923048838",
	},
	["item.hunting_rifle"] = {
		damage = 70,
		interval = 1.3,
		magazine = 5,
		reload = 2.8,
		shots = 32,
		range = 120,
		class = "rifle",
		tier = 3,
		rarity = "uncommon",
		kit = "EO_HuntingRifle",
		asset = "99562708864658",
	},
	["item.assault_rifle"] = {
		damage = 17,
		interval = 0.12,
		magazine = 30,
		reload = 2.4,
		shots = 160,
		range = 90,
		class = "rifle",
		tier = 4,
		rarity = "rare",
		kit = "EO_AssaultRifle",
		asset = "129256241328198",
	},
	["item.anti_materiel_rifle"] = {
		damage = 220,
		interval = 0.9,
		magazine = 5,
		reload = 3.5,
		shots = 15,
		range = 160,
		class = "rifle",
		tier = 4,
		rarity = "legendary",
		kit = "EO_AntiMaterielRifle",
		asset = "93078334956668",
	},
	-- Batch 5
	["item.hand_cannon"] = {
		damage = 48,
		interval = 0.7,
		magazine = 7,
		reload = 2,
		shots = 45,
		range = 80,
		class = "pistol",
		tier = 3,
		rarity = "uncommon",
		kit = "EO_HandCannon",
		asset = "104201434214205",
		credited = false,
	},
	["item.machine_pistol"] = {
		damage = 9,
		interval = 0.09,
		magazine = 20,
		reload = 1.8,
		shots = 240,
		range = 45,
		class = "smg",
		tier = 3,
		rarity = "uncommon",
		kit = "EO_MachinePistol",
		asset = "109481505500458",
	},
	["item.patrol_carbine"] = {
		damage = 16,
		interval = 0.07,
		magazine = 30,
		reload = 2.2,
		shots = 190,
		range = 95,
		class = "rifle",
		tier = 4,
		rarity = "rare",
		kit = "EO_PatrolCarbine",
		asset = "75563310459171",
	},
	["item.compact_rifle"] = {
		damage = 13,
		interval = 0.1,
		magazine = 20,
		reload = 1.8,
		shots = 200,
		range = 70,
		class = "rifle",
		tier = 4,
		rarity = "rare",
		kit = "EO_CompactRifle",
		asset = "74935082651837",
		credited = false,
	},
	["item.tactical_smg"] = {
		damage = 11,
		interval = 0.075,
		magazine = 40,
		reload = 2,
		shots = 240,
		range = 55,
		class = "smg",
		tier = 4,
		rarity = "rare",
		kit = "EO_TacticalSMG",
		asset = "138864024632624",
	},
	["item.marksman_rifle"] = {
		damage = 110,
		interval = 1.5,
		magazine = 5,
		reload = 3,
		shots = 26,
		range = 140,
		class = "rifle",
		tier = 4,
		rarity = "rare",
		kit = "EO_MarksmanRifle",
		asset = "78490302802730",
		credited = false,
	},
}

-- The advanced guns learned from a Black-fog schematic (ARSENAL §3.3).
local SCHEMATICS = {
	["recipe.assault_rifle"] = "item.bp_assault_rifle",
	["recipe.patrol_carbine"] = "item.bp_patrol_carbine",
	["recipe.compact_rifle"] = "item.bp_compact_rifle",
	["recipe.tactical_smg"] = "item.bp_tactical_smg",
	["recipe.marksman_rifle"] = "item.bp_marksman_rifle",
}

-- ARSENAL §0: uploads that must never be referenced.
local DEAD_ASSETS = {
	"87273802704697",
	"112557069701253",
	"99838449574262",
	"124307241329393",
	"109217049271999",
	"101143506328630",
	"107836528763914",
	"87043412758876",
	"103273183249174",
}

local F14_FACTOR = 3 -- F-14 tripled the three improvised guns' shot counts; these follow

local function weapon(itemId: string): any
	return (Content.Items[itemId] :: any).weapon
end

-- Shots to drop a Hollow in Black fog (band 1), body hits inside the falloff start.
local function shotsInBlack(itemId: string, enemyId: string): number
	local stats = weapon(itemId)
	local perShot = stats.damage * (stats.firearm.pellets or 1)
	local hp = Content.Enemies[enemyId].hp * TUNING.hollowTierScale.health[3]
	return Combat.hitsToKill(perShot, hp)
end

-- Every loot table that can drop `itemId`, with the row.
local function lootRows(itemId: string): { [string]: any }
	local found: { [string]: any } = {}
	for tableId, loot in Content.LootTables do
		for _, entry in (loot :: any).entries do
			if entry.itemId == itemId then
				found[tableId] = entry
			end
		end
	end
	return found
end

return function(test: TestKit.Register)
	test("the roster carries ARSENAL's stats and three times its shot count", function()
		for itemId, row in GUNS do
			local item = Content.Items[itemId] :: any
			TestKit.truthy(item, `{itemId} exists`)
			local stats, firearm = item.weapon, item.weapon.firearm
			TestKit.equal(item.category, "weapon", itemId)
			TestKit.equal(item.equipSlot, "weapon", itemId)
			TestKit.equal(item.tier, row.tier, `{itemId} tier`)
			TestKit.equal(item.rarity, row.rarity, `{itemId} rarity`)
			TestKit.equal(item.durability, row.shots * F14_FACTOR, `{itemId} shots`)
			TestKit.equal(stats.kind, "ranged", itemId)
			TestKit.equal(stats.damage, row.damage, `{itemId} damage`)
			TestKit.equal(stats.range, row.range, `{itemId} range`)
			TestKit.equal(firearm.pellets, row.pellets, `{itemId} pellets`)
			TestKit.equal(firearm.fireInterval, row.interval, `{itemId} interval`)
			TestKit.equal(firearm.magazine, row.magazine, `{itemId} magazine`)
			TestKit.equal(firearm.reloadSeconds, row.reload, `{itemId} reload`)
			TestKit.equal(firearm.animClass, row.class, `{itemId} class`)
			TestKit.equal(stats.ammoItemId, nil, `{itemId} takes no rounds`)
		end
	end)

	test("every firearm has a class, and none takes rounds", function()
		for itemId, item in Content.Items do
			local stats = (item :: any).weapon
			if stats and stats.firearm then
				TestKit.truthy(stats.firearm.animClass, `{itemId} has a class`)
				TestKit.equal(stats.ammoItemId, nil, `{itemId} takes no rounds`)
			end
		end
	end)

	test("the ladder holds: each tier out-damages the one below over a gun's life", function()
		local function life(itemId: string): number
			local item = Content.Items[itemId] :: any
			return item.weapon.damage * (item.weapon.firearm.pellets or 1) * item.durability
		end
		TestKit.truthy(life("item.duty_pistol") > life("item.pipe_pistol"), "Duty Pistol over the Worn Pistol")
		TestKit.truthy(life("item.pump_shotgun") > life("item.scrap_shotgun"), "Pump over the Scrap Shotgun")
		TestKit.truthy(life("item.assault_rifle") > life("item.duty_pistol"), "advanced over standard")
		TestKit.truthy(life("item.anti_materiel_rifle") > life("item.assault_rifle"), "the jackpot on top")
		for _, advanced in { "item.patrol_carbine", "item.compact_rifle", "item.tactical_smg", "item.marksman_rifle" } do
			TestKit.truthy(life(advanced) > life("item.hand_cannon"), `{advanced} over the best standard gun`)
			TestKit.truthy(life(advanced) < life("item.anti_materiel_rifle"), `{advanced} under the jackpot`)
		end
	end)

	test("shots to kill in Black fog match ARSENAL §6.2", function()
		TestKit.equal(shotsInBlack("item.duty_pistol", "enemy.shambler"), 3)
		TestKit.equal(shotsInBlack("item.duty_pistol", "enemy.runner"), 5)
		TestKit.equal(shotsInBlack("item.pump_shotgun", "enemy.shambler"), 1)
		TestKit.equal(shotsInBlack("item.pump_shotgun", "enemy.runner"), 2)
		TestKit.equal(shotsInBlack("item.hunting_rifle", "enemy.shambler"), 1)
		TestKit.equal(shotsInBlack("item.hunting_rifle", "enemy.runner"), 2)
		TestKit.equal(shotsInBlack("item.assault_rifle", "enemy.shambler"), 4)
		TestKit.equal(shotsInBlack("item.assault_rifle", "enemy.runner"), 6)
		TestKit.equal(shotsInBlack("item.anti_materiel_rifle", "enemy.runner"), 1)
		-- Batch 5 (§6.2's Black column)
		TestKit.equal(shotsInBlack("item.hand_cannon", "enemy.shambler"), 2)
		TestKit.equal(shotsInBlack("item.hand_cannon", "enemy.runner"), 3)
		TestKit.equal(shotsInBlack("item.machine_pistol", "enemy.shambler"), 7)
		TestKit.equal(shotsInBlack("item.machine_pistol", "enemy.runner"), 11)
		TestKit.equal(shotsInBlack("item.patrol_carbine", "enemy.shambler"), 4)
		TestKit.equal(shotsInBlack("item.patrol_carbine", "enemy.runner"), 7)
		TestKit.equal(shotsInBlack("item.compact_rifle", "enemy.shambler"), 5)
		TestKit.equal(shotsInBlack("item.compact_rifle", "enemy.runner"), 8)
		TestKit.equal(shotsInBlack("item.tactical_smg", "enemy.shambler"), 6)
		TestKit.equal(shotsInBlack("item.tactical_smg", "enemy.runner"), 9)
		TestKit.equal(shotsInBlack("item.marksman_rifle", "enemy.shambler"), 1)
		TestKit.equal(shotsInBlack("item.marksman_rifle", "enemy.runner"), 1)
	end)

	test("no gun's hit on a survivor passes the PvP cap", function()
		local maxHealth = TUNING.player.maxHealth
		for itemId in GUNS do
			local biggest = Combat.maxHit(weapon(itemId), TUNING.combat, TUNING.melee)
			local capped = Combat.pvpCap(biggest, maxHealth, TUNING.combat)
			TestKit.truthy(capped <= maxHealth * TUNING.combat.pvpMaxHitFraction + 1e-9, `{itemId} capped`)
			TestKit.truthy(Combat.hitsToKill(capped, maxHealth) >= 2, `{itemId}: at least two hits`)
		end
	end)

	test("standard guns unlock on the chapter-3 trail; the Assault Rifle by its schematic", function()
		local quests = {
			["recipe.duty_pistol"] = "quest.into_the_black",
			["recipe.pump_shotgun"] = "quest.the_plans",
			["recipe.hunting_rifle"] = "quest.copper_lines",
			["recipe.hand_cannon"] = "quest.walls_that_hold",
			["recipe.machine_pistol"] = "quest.padded_through",
		}
		for recipeId, questId in quests do
			local recipe = Content.Recipes[recipeId] :: any
			TestKit.truthy(recipe, recipeId)
			TestKit.equal(recipe.unlock.kind, "quest", recipeId)
			TestKit.equal(recipe.unlock.questId, questId, recipeId)
			TestKit.equal(recipe.stationId, nil, `{recipeId} is made by hand`)
			TestKit.truthy(Content.Quests[questId], questId)
		end
		for recipeId, schematic in SCHEMATICS do
			local recipe = Content.Recipes[recipeId] :: any
			TestKit.equal(recipe.unlock.kind, "blueprint", recipeId)
			TestKit.equal(recipe.unlock.itemId, schematic, recipeId)
			TestKit.equal((Content.Items[schematic] :: any).category, "blueprint", schematic)
		end
		-- Hold the Line, chapter 3's end, teaches the Patrol Carbine (ARSENAL §3.3).
		local taught = false
		for _, reward in (Content.Quests["quest.hold_the_line"] :: any).rewards.items do
			taught = taught or reward.itemId == "item.bp_patrol_carbine"
		end
		TestKit.truthy(taught, "Hold the Line rewards the Patrol Carbine Schematic")
		-- Every gun recipe burns Trigger Groups (ARSENAL rule 3): three for the advanced gun.
		for recipeId, groups in
			{
				["recipe.duty_pistol"] = 1,
				["recipe.pump_shotgun"] = 2,
				["recipe.hunting_rifle"] = 1,
				["recipe.assault_rifle"] = 3,
				["recipe.hand_cannon"] = 1,
				["recipe.machine_pistol"] = 2,
				["recipe.patrol_carbine"] = 3,
				["recipe.compact_rifle"] = 3,
				["recipe.tactical_smg"] = 3,
				["recipe.marksman_rifle"] = 3,
			}
		do
			local count = 0
			for _, input in (Content.Recipes[recipeId] :: any).inputs do
				if input.itemId == "item.trigger_group" then
					count = input.count
				end
			end
			TestKit.equal(count, groups, `{recipeId} Trigger Groups`)
		end
	end)

	test("the Anti-Materiel Rifle is loot only, and only as a legendary", function()
		for recipeId, recipe in Content.Recipes do
			for _, output in (recipe :: any).outputs do
				TestKit.truthy(output.itemId ~= "item.anti_materiel_rifle", `{recipeId} must not make it`)
			end
		end
		local rows = lootRows("item.anti_materiel_rifle")
		TestKit.truthy(rows["loot.depot_band3"], "late Black-fog containers")
		TestKit.truthy(rows["loot.depot_strongbox"], "the Depot strongbox")
		for tableId, row in rows do
			TestKit.equal(row.rarity, "legendary", tableId)
			TestKit.equal(row.weight, 1, tableId)
		end
	end)

	test("every gun and the schematic drop on a Fog Run, at ARSENAL §3.4's weights", function()
		for itemId in GUNS do
			TestKit.truthy(next(lootRows(itemId)) ~= nil, `{itemId} drops somewhere`)
		end
		local band3 = {
			["item.duty_pistol"] = 4,
			["item.pump_shotgun"] = 3,
			["item.assault_rifle"] = 1,
			["item.bp_assault_rifle"] = 1,
			["item.hand_cannon"] = 3,
			["item.machine_pistol"] = 3,
			["item.patrol_carbine"] = 1,
			["item.compact_rifle"] = 1,
			["item.tactical_smg"] = 1,
			["item.marksman_rifle"] = 1,
			["item.bp_patrol_carbine"] = 1,
			["item.bp_compact_rifle"] = 1,
			["item.bp_tactical_smg"] = 1,
			["item.bp_marksman_rifle"] = 1,
		}
		for itemId, weight in band3 do
			local row = lootRows(itemId)["loot.depot_band3"]
			TestKit.truthy(row, `{itemId} in loot.depot_band3`)
			TestKit.equal(row.weight, weight, itemId)
			TestKit.equal(row.rarity, "epic", `{itemId} counts toward the band's pity`)
		end
		for _, schematic in SCHEMATICS do
			TestKit.equal(lootRows(schematic)["loot.depot_strongbox"].weight, 2, schematic)
			TestKit.truthy(lootRows(schematic)["loot.schematics_advanced"], `{schematic} in the airdrop's sub-table`)
		end
		TestKit.equal(lootRows("item.hand_cannon")["loot.depot_strongbox"].weight, 4)
		TestKit.equal(lootRows("item.hand_cannon")["loot.caravan_band3"].weight, 3)
		TestKit.equal(lootRows("item.machine_pistol")["loot.airdrop_crate"].weight, 2)
		TestKit.equal(lootRows("item.bp_tactical_smg")["loot.mine_box_t3"].weight, 1, "§0: the Combat Shotgun's place")
		TestKit.equal(lootRows("item.hunting_rifle")["loot.forest_crate_t3"].weight, 2)
		TestKit.equal(lootRows("item.hunting_rifle")["loot.airdrop_crate"].weight, 2)
		-- Reinforcement Plans keep about an 11% share of the strongbox (ARSENAL §3.4).
		local plans = Loot.shares(Content.LootTables, "loot.depot_strongbox")["item.bp_reinforced"]
		TestKit.truthy(plans > 0.1 and plans < 0.125, `Reinforcement Plans share {plans}`)
	end)

	test("each gun shows its graded ARSENAL §0 model, and no dead upload is referenced", function()
		-- Art.luau uses Roblox types, so it is read as source.
		local source = fs.readFile("src/shared/Art.luau")
		for itemId, row in GUNS do
			TestKit.truthy(string.find(source, `{row.kit} = true`, 1, true), `{row.kit} is approved`)
			-- Art.uploaded's entry, on one line or spread over several.
			local _, entry = string.find(source, `\n%s*{row.kit} = \{`)
			local id = entry and string.find(string.sub(source, entry, entry + 60), `id = {row.asset},`, 1, true)
			TestKit.truthy(id, `{row.kit} asset ID`)
			TestKit.truthy(string.find(source, `["{itemId}"] = \{ "{row.kit}" }`, 1, true), `{itemId} shows {row.kit}`)
			local _, heldAt = string.find(source, "Art.held = {", 1, true)
			TestKit.truthy(string.find(source, `["{itemId}"] = \{`, heldAt, true), `{itemId} has a held pose`)
		end
		for _, asset in DEAD_ASSETS do
			TestKit.equal(string.find(source, asset, 1, true), nil, `dead upload {asset}`)
		end
	end)

	test("each gun's source model is credited (CREDITS.md and the Credits panel)", function()
		local works: { string } = {}
		for _, section in Credits :: any do
			for _, row in section.rows do
				table.insert(works, row.work)
			end
		end
		for itemId, row in GUNS do
			if row.credited == false then
				continue
			end
			local name = (Content.Items[itemId] :: any).name
			local found = false
			for _, work in works do
				found = found or string.find(work, `(the {name})`, 1, true) ~= nil
			end
			TestKit.truthy(found, `{name} has a credit row`)
		end
	end)

	test("a held trigger fires on the gun's beat however its requests bunch", function()
		local firearm = weapon("item.assault_rifle").firearm
		local leeway = 0.05
		local gun = Combat.fire({ loaded = 30, lastShotAt = -math.huge, reloadEndsAt = nil }, 100)
		TestKit.equal(gun.lastShotAt, 100)
		-- A request 30 ms early passes with the server's leeway and counts on the beat.
		local early = 100 + firearm.fireInterval - 0.03
		TestKit.equal(Combat.canFire(firearm, gun, early), false, "refused with no leeway")
		TestKit.equal(Combat.canFire(firearm, gun, early + leeway), true, "allowed inside it")
		TestKit.equal(Combat.shotTime(firearm, gun, early), 100 + firearm.fireInterval, "on the beat")
		-- A late one counts when it came; a first shot counts now.
		TestKit.equal(Combat.shotTime(firearm, gun, 101), 101)
		TestKit.equal(Combat.shotTime(firearm, Combat.newGun(30), 100), 100)
		-- Thirty early requests in a row never beat thirty beats.
		local at = 100
		for _ = 1, 30 do
			local ask = gun.lastShotAt + firearm.fireInterval - leeway
			at = Combat.shotTime(firearm, gun, ask)
			gun = Combat.fire(gun, at)
		end
		TestKit.truthy(at >= 100 + 30 * firearm.fireInterval - 1e-9, "no faster than fireInterval")
	end)

	test("the Patrol Carbine fires three-round bursts and keeps ARSENAL's 71 a second", function()
		local firearm = weapon("item.patrol_carbine").firearm
		TestKit.deepEqual(firearm.burst, { count = 3, cooldown = 0.35 })
		local gun = Combat.newGun(30)
		local at = 100
		local times: { number } = {}
		for _ = 1, 6 do
			local shot = Combat.shotTime(firearm, gun, at)
			TestKit.truthy(Combat.canFire(firearm, gun, shot + 1e-6), `round {#times + 1} fires on its beat`)
			gun = Combat.fire(gun, shot, firearm)
			table.insert(times, shot)
			at = shot
		end
		local function near(a: number, b: number): boolean
			return math.abs(a - b) < 1e-6
		end
		TestKit.truthy(near(times[2] - times[1], 0.07) and near(times[3] - times[2], 0.07), "inside a burst")
		TestKit.truthy(near(times[4] - times[3], 0.35), "the cooldown between bursts")
		TestKit.equal(Combat.canFire(firearm, gun, times[6] + 0.1), false, "a spent burst waits")
		local dps = 16 * Combat.sustainedRate(firearm)
		TestKit.truthy(math.abs(dps - 71) < 1, `sustained {dps} a second`)
		-- A burst left half-fired starts over once its cooldown has passed.
		local half = Combat.fire(Combat.fire(Combat.newGun(30), 0, firearm), 0.07, firearm)
		TestKit.equal(half.burstShots, 2)
		TestKit.equal(Combat.fire(half, 1, firearm).burstShots, 1)
	end)

	test("only the Anti-Materiel Rifle pierces, through two more Hollow", function()
		for itemId, item in Content.Items do
			local stats = (item :: any).weapon
			if stats and stats.firearm then
				local expected = if itemId == "item.anti_materiel_rifle" then 2 else nil
				TestKit.equal(stats.firearm.pierce, expected, itemId)
			end
		end
	end)
end
