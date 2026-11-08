--!strict
-- Specs for S1b's save and onboarding changes: the v7 player migration, the outpost
-- schema, the damaged starter shelter and the wrecked hauler's parts checklist
-- (LDOE_PARITY #14-15, #18, #30, #56).
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Gifts = require("../src/shared/Domain/Gifts")
local Grid = require("../src/shared/Domain/Grid")
local Migrations = require("../src/shared/Domain/Migrations")
local OutpostSchema = require("../src/shared/Domain/OutpostSchema")
local PlayerSchema = require("../src/shared/Domain/PlayerSchema")
local Project = require("../src/shared/Domain/Project")
local Shelter = require("../src/shared/Domain/Shelter")

local T0 = 1_700_000_000

-- A v6 profile shaped as slice 1 saved it.
local function v6(): any
	local data: any = PlayerSchema.template()
	data.version = 6
	data.inventory.equipment.quick = nil
	data.homeNodes = {}
	return data
end

local function inboxCount(data: any, itemId: string): number
	local total = 0
	for _, entry in data.inbox do
		if entry.itemId == itemId then
			total += entry.count
		end
	end
	return total
end

return function(test: TestKit.Register)
	-- v7 player migration ------------------------------------------------------------------------
	test("v7 settles saved station queues into the inbox and restarts them as converters", function()
		local data = v6()
		data.stations["7"] = {
			stationId = "station.workbench",
			level = 2,
			queue = {
				{ id = "recipe.plank", startsAt = T0 - 200, endsAt = T0 - 100 }, -- finished
				{ id = "recipe.plank", startsAt = T0 - 100, endsAt = T0 + 500 }, -- unfinished
			},
			fuelEndsAt = 0,
		}
		data.stations["9"] = {
			stationId = "station.recycler",
			level = 1,
			queue = { { id = "item.padded_vest#50", startsAt = T0, endsAt = T0 + 600 } },
			fuelEndsAt = 0,
		}
		data.stations["11"] = {
			stationId = "station.campfire",
			level = 1,
			-- Finished on the clock, but the fire went out first: inputs come back.
			queue = { { id = "recipe.boiled_water", startsAt = T0 - 300, endsAt = T0 - 100 } },
			fuelEndsAt = T0 - 200,
		}
		PlayerSchema.migrateToV7(data, T0)
		TestKit.equal(inboxCount(data, "item.plank"), 4, "the finished job's planks")
		TestKit.equal(inboxCount(data, "item.timber"), 4, "the unfinished job's timber")
		TestKit.equal(inboxCount(data, "item.murky_water"), 2, "stalled by fuel: inputs back")
		TestKit.equal(inboxCount(data, "item.padded_vest"), 1, "the vest back")
		local bench = data.stations["7"]
		TestKit.equal(bench.level, 2, "keeps its level")
		TestKit.equal(bench.input.count, 0)
		TestKit.equal(#bench.output, 1)
		TestKit.equal(#data.stations["9"].output, Content.Stations["station.recycler"].outputSlots)
		TestKit.equal(bench.queue, nil, "no queue left")
	end)

	test("v7 caps stacks at the new sizes and moves the rest to the inbox", function()
		local data = v6()
		data.inventory.pockets[1] = { itemId = "item.timber", count = 30 }
		data.inventory.pockets[2] = { itemId = "item.scrap", count = 50 }
		data.storage["3"] = { { itemId = "item.stone", count = 28 }, { itemId = "", count = 0 } }
		PlayerSchema.migrateToV7(data, T0)
		TestKit.equal(data.inventory.pockets[1].count, 20)
		TestKit.equal(data.inventory.pockets[2].count, 50, "scrap stacks to 50")
		TestKit.equal(data.storage["3"][1].count, 20)
		TestKit.equal(inboxCount(data, "item.timber"), 10)
		TestKit.equal(inboxCount(data, "item.stone"), 8)
		TestKit.equal(data.inboxSeq, #data.inbox, "inbox ids stay unique")
	end)

	test("v7 shrinks the backpack to the bag's new size without losing anything", function()
		local data = v6()
		data.inventory.equipment.bag = { itemId = "item.satchel", count = 1 }
		local backpack = {}
		for index = 1, 6 do
			backpack[index] = { itemId = "item.fiber", count = index }
		end
		data.inventory.backpack = backpack
		PlayerSchema.migrateToV7(data, T0)
		TestKit.equal(#data.inventory.backpack, 5, "a satchel is +5 now")
		TestKit.equal(inboxCount(data, "item.fiber"), 6, "the sixth slot went to the inbox")
		TestKit.truthy(data.inventory.equipment.quick ~= nil, "the quick slot exists")
	end)

	test("a v6 profile runs the whole migration chain to the current version", function()
		local data = v6()
		local ok, reason = Migrations.run(data, PlayerSchema.migrations, PlayerSchema.VERSION)
		TestKit.truthy(ok, reason)
		TestKit.equal(data.version, PlayerSchema.VERSION)
	end)

	-- Outpost schema ----------------------------------------------------------------------------
	test("pre-schema outposts migrate; one with pieces is never given a shelter", function()
		local plot: Grid.Plot = { ownerUserId = 1, width = 15, depth = 15 }
		local built = Shelter.build(Content.StarterShelter, Content.BuildPieces, plot, 1, T0)
		local old: any = { layout = Grid.serialize(built) }
		OutpostSchema.prepare(old)
		local ok, reason = Migrations.run(old, OutpostSchema.migrations, OutpostSchema.VERSION)
		TestKit.truthy(ok, reason)
		TestKit.equal(old.seeded, true)
		TestKit.deepEqual(old.nodes, {})
		local empty: any = { layout = Grid.serialize(Grid.new()) }
		OutpostSchema.prepare(empty)
		Migrations.run(empty, OutpostSchema.migrations, OutpostSchema.VERSION)
		TestKit.equal(empty.seeded, false, "an empty plot still gets its shelter")
		TestKit.equal(OutpostSchema.template().version, OutpostSchema.VERSION)
		for version = 1, OutpostSchema.VERSION - 1 do
			TestKit.truthy(OutpostSchema.migrations[version], `migration {version}`)
		end
	end)

	-- Starter shelter -----------------------------------------------------------------------------
	test("the starter shelter is a damaged timber room with a cold campfire and a crate", function()
		local plot: Grid.Plot = { ownerUserId = 1, width = 15, depth = 15 }
		local layout, reason = Shelter.build(Content.StarterShelter, Content.BuildPieces, plot, 1, T0)
		TestKit.equal(reason, nil)
		local kinds: { [string]: number } = {}
		local damaged = 0
		for _, piece in layout.pieces do
			kinds[piece.pieceId] = (kinds[piece.pieceId] or 0) + 1
			if piece.hp < Content.BuildPieces[piece.pieceId].hp then
				damaged += 1
			end
		end
		TestKit.equal(kinds["build.foundation_wood"], 9)
		TestKit.truthy((kinds["build.wall_wood"] or 0) >= 3, "a few walls")
		TestKit.equal(kinds["build.campfire"], 1)
		TestKit.equal(kinds["build.crate_wood"], 1)
		TestKit.equal(damaged, #Content.StarterShelter, "every piece starts damaged")
	end)

	test("the shelter mirrors onto the facing row so it always opens to the road", function()
		local plot: Grid.Plot = { ownerUserId = 1, width = 15, depth = 15 }
		local near = Shelter.build(Content.StarterShelter, Content.BuildPieces, plot, 1, T0)
		local far, reason = Shelter.build(Content.StarterShelter, Content.BuildPieces, plot, -1, T0)
		TestKit.equal(reason, nil)
		-- The back wall's gap faces away from the road on both rows: on row 1 the walls sit
		-- on the low-Z edge (z = 5), on row 2 on the high-Z edge (z = 10).
		local function backWallZ(layout: Grid.Layout): number?
			for _, piece in layout.pieces do
				if piece.pieceId == "build.wall_wood" and piece.axis == "h" then
					return piece.z
				end
			end
			return nil
		end
		TestKit.equal(backWallZ(near), 5)
		TestKit.equal(backWallZ(far), 10)
		local crate =
			Shelter.mirror(Content.StarterShelter[#Content.StarterShelter], Content.BuildPieces["build.crate_wood"], 15)
		TestKit.equal(crate.rot, 0, "its back still faces the back wall")
	end)

	-- Wrecked hauler ----------------------------------------------------------------------------
	test("the hauler's checklist takes parts up to need, then finalizes once", function()
		local def = Content.Projects["project.hauler"]
		local state = Project.new()
		local rows = Project.rows(def, state)
		TestKit.equal(#rows, #def.parts)
		TestKit.equal(rows[1].delivered, 0)
		local partial, taken = Project.deliver(def, state, "item.rivets", 100)
		TestKit.equal(taken, 16, "FILL UP takes only what is missing")
		local _, none = Project.deliver(def, partial, "item.timber", 5)
		TestKit.equal(none, 0, "not a part")
		TestKit.equal(select(2, Project.finalize(def, partial, T0)), "missingParts")
		local full = partial
		for _, part in def.parts do
			full = (Project.deliver(def, full, part.itemId, part.count))
		end
		TestKit.truthy(Project.isReady(def, full))
		local finished = Project.finalize(def, full, T0) :: Project.State
		TestKit.equal(finished.finishedAt, T0)
		TestKit.equal(select(2, Project.finalize(def, finished, T0)), "finished")
		TestKit.equal(select(2, Project.deliver(def, finished, "item.rivets", 1)), 0, "closed")
	end)

	-- Daily gift ----------------------------------------------------------------------------------
	test("the daily food and water gift comes once a UTC day, until level 10", function()
		local config = Content.Tuning.dailyGift
		local due, today = Gifts.due(0, 1, config.untilLevel, T0)
		TestKit.truthy(due, "first day")
		TestKit.equal(select(1, Gifts.due(today, 1, config.untilLevel, T0 + 3600)), false, "same day")
		TestKit.equal(select(1, Gifts.due(today, 1, config.untilLevel, T0 + 86400)), true, "next day")
		TestKit.equal(select(1, Gifts.due(0, config.untilLevel, config.untilLevel, T0)), false, "level 10 and up")
		TestKit.equal(select(1, Gifts.due(today + 5, 1, config.untilLevel, T0)), false, "a clock running behind")
	end)
end
