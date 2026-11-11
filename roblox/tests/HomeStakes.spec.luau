--!strict
--[[
	Home stakes (the flow review's F-04 and F-05): what is risked on a run stays risked, and
	home is not a free refill.

	The server glue (OnRun, Inbox, Stations) needs Roblox, so these specs read its source for
	the guards that make the rules hold, beside the pure rules themselves.
]]

local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local Death = require("../src/shared/Domain/Death")
local Inventory = require("../src/shared/Domain/Inventory")
local Survival = require("../src/shared/Domain/Survival")
local Tuning = require("../src/shared/Data/Tuning")

local T0 = 1_700_000_000

local function source(path: string): string
	return fs.readFile(path)
end

-- The body of `local function <name>(` up to the next top-level `end`.
local function body(text: string, name: string): string
	local start = string.find(text, `local function {name}%(`)
	assert(start, `no local function {name}`)
	local finish = string.find(text, "\nend\n", start, true)
	assert(finish, `{name} has no end`)
	return string.sub(text, start, finish)
end

return function(test: TestKit.Register)
	test("F-04: a run server, or a seat in a simulated lobby, counts as on a run", function()
		local text = source("src/server/OnRun.luau")
		TestKit.truthy(string.find(text, 'Teleport.role() == "run" or OnRun.seated(player)', 1, true), "OnRun.is")
		local lobby = source("src/server/Services/Lobby.luau")
		TestKit.truthy(string.find(lobby, "OnRun.seated = function", 1, true), "Lobby seats count")
		local materials = source("src/server/Services/Materials.luau")
		TestKit.truthy(string.find(materials, "not OnRun.is(player)", 1, true), "crafting on a run uses only the bag")
	end)

	test("F-04: on a run the inbox refuses TAKE, TAKE ALL and USE with a notice", function()
		local text = source("src/server/Services/Inbox.luau")
		local usable = body(text, "usable")
		TestKit.truthy(string.find(usable, "OnRun.is(player)", 1, true), "usable asks OnRun")
		TestKit.truthy(string.find(usable, "Sync.notice(player, OnRun.INBOX_NOTICE", 1, true), "and says why")
		for _, handler in { "take", "takeAll", "use" } do
			TestKit.truthy(string.find(body(text, handler), "usable(player)", 1, true), `{handler} checks usable`)
		end
		-- Grants still land in it: a level-up on a run waits at home.
		TestKit.equal(string.find(text, "function Inbox.grant[^\n]*\n[^\n]*usable"), nil, "grants are never refused")
	end)

	test("F-04: a hand craft that overflows on a run drops on the ground, never in the inbox", function()
		local text = source("src/server/Services/Stations.luau")
		local craft = body(text, "handCraft")
		local runBranch = string.find(craft, "if #leftover > 0 and onRun then", 1, true)
		local inboxBranch = string.find(craft, "Inbox.grant(player, leftover", 1, true)
		TestKit.truthy(runBranch and inboxBranch and runBranch < inboxBranch, "the run branch comes first")
		TestKit.truthy(string.find(craft, "Drops%.spawn%(player, [^\n]*, true%)"), "a ground-only drop")
		local drops = source("src/server/Services/Drops.luau")
		TestKit.truthy(
			string.find(drops, "if keepOnGround then\n\t\t\treturn nil", 1, true),
			"ground drops skip the inbox"
		)
	end)

	test("F-05: a death wakes at HP 50, hunger 40 and thirst 40, whatever the meters were", function()
		local survival = Tuning.survival
		TestKit.equal(survival.respawnHealth, 50)
		TestKit.equal(survival.respawnHunger, 40)
		TestKit.equal(survival.respawnThirst, 40)
		for _, before in { 0, 39, 41, 100 } do
			local meters, health = Survival.respawn(survival, T0)
			TestKit.equal(meters.hunger, 40, `hunger from {before}`)
			TestKit.equal(meters.thirst, 40, `thirst from {before}`)
			TestKit.equal(meters.updatedAt, T0)
			TestKit.equal(health, 50)
		end
		-- Full meters at death come back lower: resetting is never a refill.
		local _, health = Survival.respawn(survival, T0)
		TestKit.truthy(health < Tuning.player.maxHealth and survival.respawnHunger < survival.hunger.max, "not full")
		local text = source("src/server/Services/Survival.luau")
		TestKit.equal(string.find(text, "math.max(state.meters.hunger", 1, true), nil, "the old refill is gone")
		TestKit.truthy(string.find(text, "SurvivalMath.respawn(config, now())", 1, true), "Survival uses the rule")
	end)

	test("F-05: a home death drops pockets and backpack as a bag; equipment stays on", function()
		local items = {
			["item.sticks"] = { stackSize = 20 },
			["item.stone_hatchet"] = { stackSize = 1, durability = 40 },
		}
		local carried = Inventory.new(2, 2)
		carried = Inventory.add(carried, "item.sticks", 7, items)
		carried = Inventory.addSlot(carried, { itemId = "item.stone_hatchet", count = 1, durability = 12 }, items)
		local after, bag = Death.drop(carried, {
			id = "home1",
			ownerUserId = 1,
			locationId = "home",
			now = T0,
		}, Tuning.death :: any)
		assert(bag, "a bag")
		TestKit.equal(Inventory.count(after, "item.sticks"), 0, "pockets emptied")
		TestKit.equal(Inventory.count(after, "item.stone_hatchet"), 0)
		TestKit.equal(#bag.contents, 2)
		TestKit.equal(bag.contents[2].durability, 12, "durability kept")
		-- The server's home path: skipped on a run, a ground-only drop, Reset comes through Died.
		local text = source("src/server/Services/Deaths.luau")
		local drop = body(text, "dropAtHome")
		TestKit.truthy(string.find(drop, "OnRun.is(player)", 1, true), "run deaths are Lobby's")
		TestKit.truthy(string.find(drop, "DeathMath.drop(view", 1, true), "Domain/Death.drop")
		TestKit.truthy(string.find(drop, "Drops.spawn(player, position, bag.contents, true)", 1, true), "on the ground")
		TestKit.truthy(string.find(body(text, "watch"), "humanoid.Died:Once", 1, true), "every death, Reset included")
		local plots = source("src/server/Services/Plots.luau")
		TestKit.truthy(string.find(plots, "def.respawn and model", 1, true), "you wake on the Doormat")
	end)
end
