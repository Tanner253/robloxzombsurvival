--!strict
-- Domain/AutoPlan: the Studio-only AutoPlayer's decisions, on the real content, and the
-- controller's guard rails (Studio only, a player's inputs only).
local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local AutoPlan = require("../src/shared/Domain/AutoPlan")

local C: any = Content

local function ctx(extra: { [string]: any }?): AutoPlan.Context
	local recipeOpen, pieceOpen = {}, {}
	for id in C.Recipes do
		recipeOpen[id] = true
	end
	for id in C.BuildPieces do
		pieceOpen[id] = true
	end
	local made: any = {
		carried = {},
		home = {},
		equipped = {},
		tools = {},
		health = 100,
		hunger = 100,
		thirst = 100,
		recipeOpen = recipeOpen,
		pieceOpen = pieceOpen,
		stations = {},
		standing = {
			["node.fallen_branches"] = 12,
			["node.loose_stones"] = 11,
			["node.reed_patch"] = 20,
			["node.pine_tree"] = 28,
			["node.boulder"] = 7,
		},
		recipes = C.Recipes,
		items = C.Items,
		nodes = C.Nodes,
		pieces = C.BuildPieces,
	}
	for key, value in extra or {} do
		made[key] = value
	end
	return made
end

local NO_GOALS: AutoPlan.Goals = { base = {} }

return function(test: TestKit.Register)
	test("survive: drink, eat and dress wounds from what is carried, best first", function()
		local c = ctx({
			thirst = 30,
			carried = { ["item.boiled_water"] = 1, ["item.murky_water"] = 2, ["item.sealed_tin"] = 1 },
		})
		local step = AutoPlan.survive(c) :: AutoPlan.Step
		TestKit.equal(step.kind, "drink")
		TestKit.equal(step.itemId, "item.boiled_water", "the bigger drink")
		c.thirst, c.hunger = 90, 20
		TestKit.equal((AutoPlan.survive(c) :: AutoPlan.Step).itemId, "item.sealed_tin")
		c.hunger, c.health = 90, 30
		TestKit.equal((AutoPlan.survive(c) :: AutoPlan.Step).itemId, "item.sealed_tin", "a tin heals a little")
		c.carried = {}
		TestKit.equal(AutoPlan.survive(c), nil, "nothing to use")
	end)

	test("timber needs a hatchet: sticks and stone first, then craft, then chop", function()
		local c = ctx()
		local step = AutoPlan.obtain(c, "item.timber", 10) :: AutoPlan.Step
		TestKit.equal(step.kind, "gather")
		TestKit.equal(step.itemId, "item.sticks", "the hatchet's sticks")
		c.home = { ["item.sticks"] = 3 }
		TestKit.equal((AutoPlan.obtain(c, "item.timber", 10) :: AutoPlan.Step).itemId, "item.stone")
		c.home = { ["item.sticks"] = 3, ["item.stone"] = 3 }
		local craft = AutoPlan.obtain(c, "item.timber", 10) :: AutoPlan.Step
		TestKit.equal(craft.kind, "craft")
		TestKit.equal(craft.recipeId, "recipe.stone_hatchet")
		c.tools = { hatchet = 1 }
		local chop = AutoPlan.obtain(c, "item.timber", 10) :: AutoPlan.Step
		TestKit.equal(chop.kind, "gather")
		TestKit.equal(chop.itemId, "item.timber")
		c.standing["node.pine_tree"] = 0
		local run = AutoPlan.obtain(c, "item.timber", 10) :: AutoPlan.Step
		TestKit.equal(run.kind, "run", "home's pines gone: the Fog")
		c.home = { ["item.timber"] = 10 }
		TestKit.equal(AutoPlan.obtain(c, "item.timber", 10), nil, "enough")
	end)

	-- The first session looped stone -> pick -> stone (the boulder sorted first and needs a pick).
	test("stone comes from the loose stones before a pick is made for the boulders", function()
		local c = ctx()
		local step = AutoPlan.obtain(c, "item.stone", 6) :: AutoPlan.Step
		TestKit.equal(step.kind, "gather")
		TestKit.deepEqual(step.nodeIds, { "node.loose_stones" })
		local quest = AutoPlan.objectiveStep(c, { kind = "gather", itemId = "item.stone", count = 6 }, 0, 6)
		TestKit.deepEqual(quest.nodeIds, { "node.loose_stones" })
		c.standing["node.loose_stones"] = 0
		c.home = { ["item.sticks"] = 3 }
		TestKit.equal((AutoPlan.obtain(c, "item.stone", 6) :: AutoPlan.Step).kind, "run", "no stone for a pick")
		c.home = { ["item.stone"] = 3, ["item.sticks"] = 3 }
		local pick = AutoPlan.obtain(c, "item.stone", 6) :: AutoPlan.Step
		TestKit.equal(pick.kind, "craft", "the boulders need a pick: make one")
		TestKit.equal(pick.recipeId, "recipe.stone_pick")
		c.tools = { pick = 1 }
		TestKit.deepEqual((AutoPlan.obtain(c, "item.stone", 6) :: AutoPlan.Step).nodeIds, { "node.boulder" })
	end)

	test("a station recipe builds the station, loads it, waits on it and collects", function()
		local c = ctx({ home = {}, tools = { hatchet = 1, pick = 1 } })
		local step = AutoPlan.obtain(c, "item.plank", 1) :: AutoPlan.Step
		TestKit.truthy(step.kind == "gather" or step.kind == "craft", `the bench's costs first ({step.kind})`)
		c.home = { ["item.timber"] = 20, ["item.stone"] = 6, ["item.rope"] = 2 }
		c.carried = { ["item.timber"] = 20 }
		local build = AutoPlan.obtain(c, "item.plank", 1) :: AutoPlan.Step
		TestKit.equal(build.kind, "build")
		TestKit.equal(build.pieceId, "build.woodworking_bench")
		local bench: AutoPlan.StationView = {
			uid = "1",
			stationId = "station.woodworking_bench",
			busy = false,
			inputItemId = "",
			inputCount = 0,
			ready = {},
			fuelSeconds = 0,
			fuelled = false,
		}
		c.stations = { ["station.woodworking_bench"] = bench }
		local load = AutoPlan.obtain(c, "item.plank", 2) :: AutoPlan.Step
		TestKit.equal(load.kind, "load")
		TestKit.equal(load.itemId, "item.timber")
		TestKit.equal(load.count, 2)
		bench.busy, bench.inputItemId = true, "item.timber"
		TestKit.equal((AutoPlan.obtain(c, "item.plank", 2) :: AutoPlan.Step).kind, "wait")
		bench.ready = { ["item.plank"] = 1 }
		TestKit.equal((AutoPlan.obtain(c, "item.plank", 2) :: AutoPlan.Step).kind, "collect")
	end)

	test("a goal that waits on a timer gives way to the next goal", function()
		local c = ctx({
			tools = { hatchet = 1 },
			home = { ["item.timber"] = 30 },
			carried = { ["item.timber"] = 30 },
		})
		c.stations = {
			["station.woodworking_bench"] = {
				uid = "1",
				stationId = "station.woodworking_bench",
				busy = true,
				inputItemId = "item.timber",
				inputCount = 2,
				ready = {},
				fuelSeconds = 0,
				fuelled = false,
			},
		}
		local plank = { kind = "craft", recipeId = "recipe.plank", count = 1 }
		local step = AutoPlan.atHome(c, { objective = plank, have = 0, need = 1, base = { "build.wall_wood" } })
		TestKit.truthy(step.kind ~= "wait", `the wall goes on while the plank cuts ({step.kind} {step.why})`)
		local only = AutoPlan.atHome(c, { objective = plank, have = 0, need = 1, base = {} })
		TestKit.equal(only.kind, "wait")
	end)

	test("chapter 1's first objectives map to gathering, crafting and equipping", function()
		local c = ctx()
		local gather = AutoPlan.objectiveStep(c, { kind = "gather", itemId = "item.sticks", count = 10 }, 4, 10)
		TestKit.equal(gather.kind, "gather")
		TestKit.equal(gather.count, 6)
		c.home = { ["item.fiber"] = 2 }
		local rope = AutoPlan.objectiveStep(c, { kind = "craft", recipeId = "recipe.rope", count = 1 }, 0, 1)
		TestKit.equal(rope.kind, "craft")
		c.carried = { ["item.sharpened_stake"] = 1 }
		local equip = AutoPlan.objectiveStep(c, { kind = "equip", itemId = "item.sharpened_stake" }, 0, 1)
		TestKit.equal(equip.kind, "equip")
		local travel = AutoPlan.objectiveStep(c, { kind = "travel", locationId = "loc.pine_hollow" }, 0, 1)
		TestKit.equal(travel.kind, "run")
		TestKit.equal(travel.locationId, "loc.pine_hollow")
		TestKit.equal(AutoPlan.atHome(c, NO_GOALS).kind, "idle")
	end)

	test("on a run: survive, fight close, leave when full, loot, gather, then leave", function()
		local c = ctx()
		local view: AutoPlan.RunView = {
			hollowDistance = 10,
			hollowCount = 1,
			containerDistance = 30,
			nodeDistance = 20,
			exitDistance = 50,
			bagFree = 5,
			minutesLeft = 10,
			armed = true,
			goalsMet = false,
			elapsed = 30,
		}
		TestKit.equal((AutoPlan.onRun(c, view)), "fight")
		c.health = 20
		TestKit.equal((AutoPlan.onRun(c, view)), "flee", "hurt, a Hollow close, nothing to heal")
		c.health = 100
		view.hollowDistance = nil
		TestKit.equal((AutoPlan.onRun(c, view)), "loot")
		view.containerDistance = nil
		TestKit.equal((AutoPlan.onRun(c, view)), "gather")
		view.nodeDistance = nil
		TestKit.equal((AutoPlan.onRun(c, view)), "explore")
		view.bagFree = 0
		TestKit.equal((AutoPlan.onRun(c, view)), "extract", "bag full")
		view.bagFree, view.minutesLeft = 5, 1
		TestKit.equal((AutoPlan.onRun(c, view)), "extract", "the lobby closes soon")
	end)

	-- Found by the AutoPlayer: a path to a station inside a walled room failed at the closed
	-- door (it opens only as you reach it), so E walked the survivor into the wall.
	test("your own doors are open to your paths", function()
		local fx = fs.readFile("src/client/Controllers/WorldFx.luau")
		local watch = string.match(fx, "local function watchDoor%(.-\nend")
		TestKit.truthy(watch, "WorldFx.watchDoor")
		TestKit.truthy(string.find(watch :: string, 'OwnerUserId") ~= player.UserId', 1, true), "own doors only")
		TestKit.truthy(string.find(watch :: string, "PassThrough = true", 1, true), "the leaf lets paths through")
	end)

	test("the AutoPlayer runs only in Studio and only through a player's inputs", function()
		local source = fs.readFile("src/client/Controllers/AutoPlayer.luau")
		local start = string.match(source, "function AutoPlayer%.start%(%).-\nend")
		TestKit.truthy(start, "AutoPlayer.start")
		TestKit.truthy(
			string.find(start :: string, "if not RunService:IsStudio() then\n\t\treturn", 1, true),
			"start returns outside Studio before anything else"
		)
		TestKit.truthy(string.find(start :: string, 'GetAttribute("AutoPlayer") == true', 1, true), "off by default")
		for _, banned in { "EO_Dev", "PivotTo", "TeleportService", ".CFrame =", "SetPrimaryPartCFrame", "DevSpeed" } do
			TestKit.truthy(not string.find(source, banned, 1, true), `no {banned}`)
		end
	end)
end
