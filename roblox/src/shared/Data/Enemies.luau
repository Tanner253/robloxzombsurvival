--!strict
-- The Hollow: enemy definitions, keyed by permanent ID. See docs/CONTENT_MVP.md and,
-- for slice 2's perception and fear fields, docs/CONTENT_S2.md.
-- Rated Mild: the Hollow dissolve into ash when killed and leave their loot behind.
-- Player walk speed is 16 and sprint is 22 (Tuning.player), so a Runner can be outrun
-- only by sprinting.
-- M1 ships three archetypes (shambler, runner, bloater; checklist 13.1). The brute and
-- the fog wraith (ART_DIRECTION §6) come back with their own rigs in M2.
-- HP and damage here are the "Thin" band; Tuning.lobby.bands scales them as the Fog
-- meter rises.

local Types = require("../Types")

local Enemies: { [Types.EnemyId]: Types.EnemyDef } = {
	["enemy.shambler"] = {
		id = "enemy.shambler",
		name = "Shambler",
		hp = 40,
		damage = 5,
		attackSeconds = 1.6,
		attackRange = 4,
		moveSpeed = 8,
		aggroRadius = 28,
		xp = 10,
		lootTableId = "loot.enemy_shambler",
		hearing = 1,
		lightFear = 0.35, -- shies from a lantern; a flare scatters them
	},
	["enemy.runner"] = {
		id = "enemy.runner",
		name = "Runner",
		hp = 70,
		damage = 6,
		attackSeconds = 1.0,
		attackRange = 4,
		moveSpeed = 18,
		aggroRadius = 42,
		xp = 25,
		lootTableId = "loot.enemy_runner",
		hearing = 1.25, -- the one that comes running when you fire
		lightFear = 0.7, -- only a flare's core turns it
	},
	["enemy.bloater"] = {
		id = "enemy.bloater",
		name = "Bloater",
		hp = 60,
		damage = 4, -- a weak shove; the burst is the threat
		attackSeconds = 2,
		attackRange = 4,
		moveSpeed = 7,
		aggroRadius = 24,
		xp = 30,
		lootTableId = "loot.enemy_bloater",
		hearing = 0.8,
		lightFear = 0.5,
		-- Pops when it reaches you, or when it dies: kill it at range, or dodge the cloud.
		-- 6 HP/s for 6 s is 36 HP if you stand in it, about a third of your health.
		burst = { triggerRange = 5, fuseSeconds = 0.8, radius = 9, damagePerSecond = 6, cloudSeconds = 6 },
	},
}

return Enemies
