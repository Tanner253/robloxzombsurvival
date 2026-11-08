--!strict
-- The Hollow: enemy definitions, keyed by permanent ID. MVP content; see docs/CONTENT_MVP.md.
-- Rated Mild: the Hollow dissolve into ash when killed and leave their loot behind.
-- Player walk speed is 16 and sprint is 22 (Tuning.player), so a Runner can be outrun
-- only by sprinting.

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
	},
	["enemy.brute"] = {
		id = "enemy.brute",
		name = "Brute",
		hp = 220,
		damage = 18,
		attackSeconds = 2.4,
		attackRange = 6,
		moveSpeed = 10,
		aggroRadius = 34,
		xp = 80,
		lootTableId = "loot.enemy_brute",
	},
}

return Enemies
