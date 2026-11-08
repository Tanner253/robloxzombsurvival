--!strict
local TestKit = require("./TestKit")
local Grid = require("../src/shared/Domain/Grid")

local T0 = 1_700_000_000
local OWNER = 1

-- Local fixtures, not Data/BuildPieces. `any` because "window" is not yet a
-- Types.BuildPieceKind.
local function def(
	id: string,
	kind: string,
	tier: number,
	hp: number,
	cost: { any },
	breach: number,
	upgradesTo: string?
): any
	return {
		id = id,
		name = id,
		kind = kind,
		tier = tier,
		hp = hp,
		cost = cost,
		breachCost = breach,
		upgradesTo = upgradesTo,
	}
end

local function wood(count: number): any
	return { itemId = "item.wood", count = count }
end
local function stone(count: number): any
	return { itemId = "item.stone", count = count }
end

local DEFS: any = {
	["build.floor_wood"] = def("build.floor_wood", "foundation", 1, 300, { wood(10) }, 2, "build.floor_stone"),
	["build.floor_stone"] = def("build.floor_stone", "foundation", 2, 600, { stone(10) }, 4),
	["build.wall_wood"] = def("build.wall_wood", "wall", 1, 200, { wood(6) }, 2, "build.wall_stone"),
	["build.wall_stone"] = def("build.wall_stone", "wall", 2, 500, { stone(8) }, 5),
	["build.wall_steel"] = def("build.wall_steel", "wall", 3, 900, { stone(20) }, 9),
	["build.doorway_wood"] = def("build.doorway_wood", "doorway", 1, 200, { wood(5) }, 2),
	["build.door_wood"] = def("build.door_wood", "door", 1, 150, { wood(4) }, 1),
	["build.window_wood"] = def("build.window_wood", "window", 1, 150, { wood(5) }, 2),
	["build.roof_wood"] = def("build.roof_wood", "roof", 1, 100, { wood(3) }, 1),
	["build.box"] = def("build.box", "storage", 1, 100, { wood(3) }, 1),
	-- Furniture on the quarter-cell sub-grid: 2 x 1 and 2 x 2 quarter cells.
	["build.chest"] = def("build.chest", "storage", 1, 100, { wood(2) }, 1, "build.chest_big"),
	["build.chest_big"] = def("build.chest_big", "storage", 2, 200, { wood(4) }, 1),
	["build.bench"] = def("build.bench", "station", 1, 100, { wood(4) }, 1),
}
DEFS["build.chest"].footprint = { w = 2, d = 1 }
DEFS["build.chest_big"].footprint = { w = 3, d = 2 }
DEFS["build.bench"].footprint = { w = 2, d = 2 }

local function ctx(now: number?, actor: number?, maxTier: number?): Grid.Context
	return {
		plot = { ownerUserId = OWNER, width = 6, depth = 6, maxTier = maxTier },
		actorUserId = actor or OWNER,
		pieces = DEFS,
		now = now or T0,
		config = { refundGraceSeconds = 300, lateRefundFraction = 0.5 },
	}
end

-- Places a list of pieces, failing loudly on any refusal.
local function build(steps: { { any } }, layout: Grid.Layout?): Grid.Layout
	local result = layout or Grid.new()
	for _, step in steps do
		local nextLayout, _, reason = Grid.place(result, step[1], step[2], ctx())
		assert(nextLayout, `could not place {step[1]}: {reason}`)
		result = nextLayout
	end
	return result
end

local function reasonOf(layout: Grid.Layout, pieceId: string, target: Grid.Target, context: Grid.Context?): string?
	local _, why = Grid.canPlace(layout, pieceId, target, context or ctx())
	return why
end

local function uidAt(layout: Grid.Layout, layer: Grid.Layer, x: number, z: number, axis: Grid.Axis?): string
	return (Grid.pieceAt(layout, layer, x, z, axis) :: Grid.Piece).uid
end

local function count(stacks: { any }, itemId: string): number
	for _, stack in stacks do
		if stack.itemId == itemId then
			return stack.count
		end
	end
	return 0
end

-- A one-cell wooden room at (2, 2): foundation, three walls, a doorway with a door.
local function room(): Grid.Layout
	return build({
		{ "build.floor_wood", { x = 2, z = 2 } },
		{ "build.wall_wood", { x = 2, z = 2, axis = "h" } },
		{ "build.wall_wood", { x = 2, z = 3, axis = "h" } },
		{ "build.wall_wood", { x = 2, z = 2, axis = "v" } },
		{ "build.doorway_wood", { x = 3, z = 2, axis = "v" } },
		{ "build.door_wood", { x = 3, z = 2, axis = "v" } },
	})
end

return function(test: TestKit.Register)
	test("foundations go on cells and walls on their edges", function()
		local layout = build({
			{ "build.floor_wood", { x = 0, z = 0 } },
			{ "build.wall_wood", { x = 0, z = 0, axis = "h" } },
			{ "build.wall_wood", { x = 1, z = 0, axis = "v" } },
		})
		TestKit.equal(Grid.pieceAt(layout, "floor", 0, 0).pieceId, "build.floor_wood")
		TestKit.equal((Grid.pieceAt(layout, "frame", 1, 0, "v") :: Grid.Piece).hp, 200, "full HP")
		TestKit.equal(Grid.pieceAt(layout, "frame", 0, 0, "v"), nil, "different edge")
		TestKit.equal(layout.nextUid, 4)
	end)

	test("placement refuses occupied slots, bad targets and out-of-bounds", function()
		local layout = build({ { "build.floor_wood", { x = 0, z = 0 } } })
		TestKit.equal(reasonOf(layout, "build.floor_wood", { x = 0, z = 0 }), "occupied")
		TestKit.equal(reasonOf(layout, "build.box", { x = 0, z = 0 }), nil, "objects use their own layer")
		TestKit.equal(reasonOf(layout, "build.floor_wood", { x = 6, z = 0 }), "outOfBounds")
		TestKit.equal(reasonOf(layout, "build.floor_wood", { x = -1, z = 0 }), "outOfBounds")
		TestKit.equal(reasonOf(layout, "build.floor_wood", { x = 0.5, z = 0 }), "badTarget")
		TestKit.equal(reasonOf(layout, "build.wall_wood", { x = 0, z = 0 }), "badTarget", "edge needs an axis")
		TestKit.equal(reasonOf(layout, "build.wall_wood", { x = 6, z = 0, axis = "h" }), "outOfBounds")
		TestKit.equal(reasonOf(layout, "build.wall_wood", { x = 0, z = 6, axis = "v" }), "outOfBounds")
		TestKit.equal(reasonOf(layout, "build.nope", { x = 1, z = 1 }), "unknownPiece")
	end)

	test("plot edges are in bounds on the far side", function()
		local layout = build({ { "build.floor_wood", { x = 5, z = 5 } } })
		TestKit.equal(
			reasonOf(layout, "build.wall_wood", { x = 5, z = 6, axis = "h" }),
			nil,
			"north edge of the last row"
		)
		TestKit.equal(
			reasonOf(layout, "build.wall_wood", { x = 6, z = 5, axis = "v" }),
			nil,
			"east edge of the last column"
		)
	end)

	test("edge pieces need an adjacent foundation", function()
		local layout = build({ { "build.floor_wood", { x = 0, z = 0 } } })
		TestKit.equal(reasonOf(layout, "build.wall_wood", { x = 3, z = 3, axis = "h" }), "needsFoundation")
		TestKit.equal(reasonOf(layout, "build.wall_wood", { x = 0, z = 1, axis = "h" }), nil, "north edge of (0,0)")
	end)

	test("wall tier cannot exceed the best adjacent foundation tier", function()
		local layout = build({ { "build.floor_wood", { x = 0, z = 0 } }, { "build.floor_stone", { x = 1, z = 0 } } })
		TestKit.equal(reasonOf(layout, "build.wall_stone", { x = 0, z = 0, axis = "h" }), "tierTooHigh")
		TestKit.equal(reasonOf(layout, "build.wall_stone", { x = 1, z = 0, axis = "v" }), nil, "shared edge with stone")
		TestKit.equal(reasonOf(layout, "build.wall_steel", { x = 1, z = 0, axis = "v" }), "tierTooHigh")
	end)

	test("Hearth tier cap and ownership are enforced", function()
		local layout = build({ { "build.floor_wood", { x = 0, z = 0 } } })
		TestKit.equal(reasonOf(layout, "build.floor_stone", { x = 1, z = 1 }, ctx(T0, OWNER, 1)), "plotTier")
		TestKit.equal(reasonOf(layout, "build.floor_wood", { x = 1, z = 1 }, ctx(T0, 999)), "notOwner")
		local uid = uidAt(layout, "floor", 0, 0)
		TestKit.equal(select(3, Grid.upgrade(layout, uid, ctx(T0, 999))), "notOwner")
		TestKit.equal(select(3, Grid.demolish(layout, uid, ctx(T0, 999))), "notOwner")
	end)

	test("doors need a doorway; windows are frames", function()
		local layout =
			build({ { "build.floor_wood", { x = 0, z = 0 } }, { "build.wall_wood", { x = 0, z = 0, axis = "h" } } })
		TestKit.equal(
			reasonOf(layout, "build.door_wood", { x = 0, z = 0, axis = "h" }),
			"needsDoorway",
			"wall, not doorway"
		)
		TestKit.equal(reasonOf(layout, "build.door_wood", { x = 0, z = 1, axis = "h" }), "needsDoorway", "empty edge")
		TestKit.equal(reasonOf(layout, "build.window_wood", { x = 0, z = 0, axis = "h" }), "occupied")
		local withWindow = build({ { "build.window_wood", { x = 0, z = 1, axis = "h" } } }, layout)
		TestKit.equal((Grid.pieceAt(withWindow, "frame", 0, 1, "h") :: Grid.Piece).layer, "frame")
	end)

	test("roofs and objects need a foundation", function()
		local layout = Grid.new()
		TestKit.equal(reasonOf(layout, "build.roof_wood", { x = 1, z = 1 }), "needsFoundation")
		TestKit.equal(reasonOf(layout, "build.box", { x = 4, z = 4 }), "needsFoundation", "no bare ground")
		layout = build({ { "build.floor_wood", { x = 1, z = 1 } } })
		local placed, piece = Grid.place(layout, "build.box", { x = 4, z = 4, rot = 5 }, ctx())
		TestKit.truthy(placed, "box on the foundation")
		TestKit.equal((piece :: Grid.Piece).rot, 1, "rotation wraps to 0-3")
	end)

	test("objects sit on a quarter-cell sub-grid, side by side but never overlapping", function()
		local layout = build({ { "build.floor_wood", { x = 1, z = 1 } }, { "build.floor_wood", { x = 2, z = 1 } } })
		-- Cell (1, 1) is quarters 4..7 on each axis: two 2 x 1 chests share it.
		layout = build({ { "build.chest", { x = 4, z = 4 } }, { "build.chest", { x = 6, z = 4 } } }, layout)
		TestKit.equal(reasonOf(layout, "build.chest", { x = 5, z = 4 }), "occupied", "overlaps both")
		TestKit.equal(reasonOf(layout, "build.chest", { x = 4, z = 5 }), nil, "the next quarter row is free")
		-- A footprint may straddle two foundations, but every cell under it needs one.
		TestKit.equal(reasonOf(layout, "build.bench", { x = 7, z = 6 }), nil, "across cells (1,1) and (2,1)")
		TestKit.equal(reasonOf(layout, "build.bench", { x = 11, z = 6 }), "needsFoundation", "half off the floor")
		TestKit.equal(reasonOf(layout, "build.bench", { x = 23, z = 0 }), "outOfBounds")
		-- Rotation turns the footprint: a 2 x 1 chest turned once is 1 x 2.
		TestKit.deepEqual({ Grid.footprint(DEFS["build.chest"], 1) }, { 1, 2 })
		TestKit.equal(reasonOf(layout, "build.chest", { x = 8, z = 4, rot = 1 }), nil)
		TestKit.equal(Grid.objectAt(layout, 6, 4).pieceId, "build.chest")
		TestKit.equal(Grid.pieceAt(layout, "object", 1, 1).pieceId, "build.chest", "any object on the cell")
	end)

	test("an object upgrades only when its next tier still fits", function()
		local layout = build({ { "build.floor_wood", { x = 1, z = 1 } } })
		layout = build({ { "build.chest", { x = 4, z = 4 } }, { "build.chest", { x = 6, z = 5 } } }, layout)
		local first = uidAt(layout, "object", 1, 1)
		local _, why = Grid.canUpgrade(layout, first, ctx())
		TestKit.equal(why, "occupied", "the bigger chest would cover its neighbour")
		local alone = build({ { "build.floor_wood", { x = 1, z = 1 } }, { "build.chest", { x = 4, z = 4 } } })
		local upgraded = Grid.upgrade(alone, uidAt(alone, "object", 1, 1), ctx()) :: Grid.Layout
		TestKit.equal(Grid.objectAt(upgraded, 6, 5).pieceId, "build.chest_big", "re-keyed to the new footprint")
		local removed = Grid.demolish(upgraded, uidAt(upgraded, "object", 1, 1), ctx()) :: Grid.Layout
		TestKit.equal(next(removed.slots, nil) ~= nil, true, "the floor's slot stays")
		TestKit.equal(Grid.objectAt(removed, 6, 5), nil, "every quarter freed")
	end)

	test("upgrade swaps in the next tier at full HP and returns its cost", function()
		local layout = build({ { "build.floor_wood", { x = 0, z = 0 } } })
		local uid = uidAt(layout, "floor", 0, 0)
		local damaged = Grid.damage(layout, uid, 100, DEFS)
		local upgraded, cost = Grid.upgrade(damaged, uid, ctx(T0 + 10))
		local piece = (upgraded :: Grid.Layout).pieces[uid]
		TestKit.equal(piece.pieceId, "build.floor_stone")
		TestKit.equal(piece.hp, 600)
		TestKit.equal(piece.upgradedAt, T0 + 10)
		TestKit.equal(count(cost :: any, "item.stone"), 10)
		TestKit.equal(select(3, Grid.upgrade(upgraded :: any, uid, ctx())), "maxTier")
	end)

	test("a wall cannot upgrade past its foundation", function()
		local layout =
			build({ { "build.floor_wood", { x = 0, z = 0 } }, { "build.wall_wood", { x = 0, z = 0, axis = "h" } } })
		local wall = uidAt(layout, "frame", 0, 0, "h")
		TestKit.equal(select(3, Grid.upgrade(layout, wall, ctx())), "tierTooHigh")
		local floorUp = Grid.upgrade(layout, uidAt(layout, "floor", 0, 0), ctx()) :: Grid.Layout
		TestKit.truthy(Grid.upgrade(floorUp, wall, ctx()), "allowed after the floor upgrade")
	end)

	test("demolish refunds in full inside the grace window and half after (boundary)", function()
		local layout = build({ { "build.floor_wood", { x = 0, z = 0 } } })
		local uid = uidAt(layout, "floor", 0, 0)
		local _, inside = Grid.demolish(layout, uid, ctx(T0 + 300))
		TestKit.equal(count((inside :: Grid.Removal).refund, "item.wood"), 10, "at exactly 300 s")
		local _, after = Grid.demolish(layout, uid, ctx(T0 + 301))
		TestKit.equal(count((after :: Grid.Removal).refund, "item.wood"), 5, "one second later")
	end)

	test("late refunds round down per stack", function()
		local layout =
			build({ { "build.floor_wood", { x = 0, z = 0 } }, { "build.doorway_wood", { x = 0, z = 0, axis = "h" } } })
		local _, removal = Grid.demolish(layout, uidAt(layout, "frame", 0, 0, "h"), ctx(T0 + 1000))
		TestKit.equal(count((removal :: Grid.Removal).refund, "item.wood"), 2, "5 * 0.5 = 2.5 -> 2")
	end)

	test("a fresh upgrade on an old piece refunds the upgrade in full and the base at half", function()
		local layout = build({ { "build.floor_wood", { x = 0, z = 0 } } })
		local uid = uidAt(layout, "floor", 0, 0)
		local upgraded = Grid.upgrade(layout, uid, ctx(T0 + 10_000)) :: Grid.Layout
		local _, removal = Grid.demolish(upgraded, uid, ctx(T0 + 10_100))
		local refund = (removal :: Grid.Removal).refund
		TestKit.equal(count(refund, "item.stone"), 10, "upgrade cost back in full")
		TestKit.equal(count(refund, "item.wood"), 5, "base cost at half")
		local _, later = Grid.demolish(upgraded, uid, ctx(T0 + 20_000))
		TestKit.equal(count((later :: Grid.Removal).refund, "item.stone"), 5, "both halves later")
	end)

	test("removing a foundation collapses unsupported walls, doors and roof (cascade)", function()
		local layout = build({ { "build.roof_wood", { x = 2, z = 2 } } }, room())
		local removedLayout, removal = Grid.demolish(layout, uidAt(layout, "floor", 2, 2), ctx(T0 + 10))
		local result = removedLayout :: Grid.Layout
		TestKit.equal(#(removal :: Grid.Removal).removed, 7, "floor, 3 walls, doorway, door, roof")
		TestKit.equal(next(result.pieces), nil, "nothing left")
		TestKit.equal(next(result.slots), nil, "slot index cleared")
		TestKit.equal(count((removal :: Grid.Removal).refund, "item.wood"), 10 + 18 + 5 + 4 + 3, "cascade refunded")
	end)

	test("walls shared with a remaining foundation survive unless its tier is too low", function()
		local layout = build({
			{ "build.floor_stone", { x = 0, z = 0 } },
			{ "build.floor_wood", { x = 1, z = 0 } },
			{ "build.floor_stone", { x = 2, z = 0 } },
			{ "build.wall_wood", { x = 1, z = 0, axis = "v" } }, -- between stone (0,0) and wood (1,0)
			{ "build.wall_stone", { x = 2, z = 0, axis = "v" } }, -- between wood (1,0) and stone (2,0)
		})
		local afterStone = Grid.demolish(layout, uidAt(layout, "floor", 0, 0), ctx()) :: Grid.Layout
		TestKit.truthy(Grid.pieceAt(afterStone, "frame", 1, 0, "v"), "wood wall still held by the wood floor")
		local afterWood = Grid.demolish(layout, uidAt(layout, "floor", 1, 0), ctx()) :: Grid.Layout
		TestKit.truthy(Grid.pieceAt(afterWood, "frame", 2, 0, "v"), "stone wall held by stone (2,0)")
		TestKit.truthy(Grid.pieceAt(afterWood, "frame", 1, 0, "v"), "wood wall held by stone (0,0)")
		local both = Grid.demolish(afterStone, uidAt(afterStone, "floor", 2, 0), ctx()) :: Grid.Layout
		TestKit.equal(Grid.pieceAt(both, "frame", 2, 0, "v"), nil, "stone wall over wood only: collapses")
	end)

	test("demolishing a doorway takes its door with it", function()
		local layout = room()
		local _, removal = Grid.demolish(layout, uidAt(layout, "frame", 3, 2, "v"), ctx())
		TestKit.equal(#(removal :: Grid.Removal).removed, 2)
		TestKit.equal((removal :: Grid.Removal).removed[2].pieceId, "build.door_wood")
	end)

	test("a foundation under an object cannot be demolished, but can be destroyed", function()
		local layout = build({ { "build.box", { x = 8, z = 8 } } }, room())
		local floor = uidAt(layout, "floor", 2, 2)
		TestKit.equal(select(3, Grid.demolish(layout, floor, ctx())), "objectOnTop")
		local destroyed, gone = Grid.damage(layout, floor, 10_000, DEFS)
		TestKit.equal(#gone, 6, "floor plus its walls, doorway and door")
		TestKit.truthy(Grid.pieceAt(destroyed, "object", 2, 2), "the box rests on the ground")
	end)

	test("damage lowers HP; breach cost scales with remaining HP", function()
		local layout = room()
		local wall = uidAt(layout, "frame", 2, 2, "h")
		TestKit.equal(Grid.breachCost(layout.pieces[wall], DEFS["build.wall_wood"]), 2, "full HP")
		local damaged, gone = Grid.damage(layout, wall, 120, DEFS)
		TestKit.equal(#gone, 0, "survived")
		TestKit.equal(damaged.pieces[wall].hp, 80)
		TestKit.equal(Grid.breachCost(damaged.pieces[wall], DEFS["build.wall_wood"]), 1, "80 HP of 100 per charge")
		TestKit.equal(layout.pieces[wall].hp, 200, "input untouched")
	end)

	test("breachCost charges destroy a piece; one fewer does not", function()
		local layout =
			build({ { "build.floor_stone", { x = 0, z = 0 } }, { "build.wall_stone", { x = 0, z = 0, axis = "h" } } })
		local wall = uidAt(layout, "frame", 0, 0, "h")
		local _, survived = Grid.applyCharges(layout, wall, 4, DEFS)
		TestKit.equal(#survived, 0, "4 of 5 charges")
		local _, destroyed = Grid.applyCharges(layout, wall, 5, DEFS)
		TestKit.equal(#destroyed, 1, "5 charges")
	end)

	test("breachCostTo finds the cheapest way in", function()
		local layout = room()
		local plot = ctx().plot
		TestKit.equal(Grid.breachCostTo(layout, plot, 2, 2, DEFS), 1, "through the door")
		TestKit.equal(Grid.breachCostTo(layout, plot, 0, 0, DEFS), 0, "open ground")
		local open = Grid.demolish(layout, uidAt(layout, "fill", 3, 2, "v"), ctx()) :: Grid.Layout
		TestKit.equal(Grid.breachCostTo(open, plot, 2, 2, DEFS), 0, "empty doorway")
		local sealed =
			build({ { "build.floor_wood", { x = 2, z = 0 } }, { "build.wall_wood", { x = 2, z = 0, axis = "h" } } })
		TestKit.equal(Grid.breachCostTo(sealed, plot, 2, 0, DEFS), 0, "a wall on one side only")
	end)

	test("breachCostTo sums nested walls", function()
		-- A 3x1 strip of floor walled all round, with an inner wall: reaching the
		-- middle cell takes the cheaper of an outer wall (2) or the long way.
		local steps: { { any } } = {}
		for x = 0, 2 do
			table.insert(steps, { "build.floor_wood", { x = x, z = 0 } })
			table.insert(steps, { "build.wall_wood", { x = x, z = 0, axis = "h" } })
			table.insert(steps, { "build.wall_wood", { x = x, z = 1, axis = "h" } })
		end
		table.insert(steps, { "build.wall_wood", { x = 0, z = 0, axis = "v" } })
		table.insert(steps, { "build.wall_wood", { x = 3, z = 0, axis = "v" } })
		table.insert(steps, { "build.wall_wood", { x = 1, z = 0, axis = "v" } })
		table.insert(steps, { "build.wall_wood", { x = 2, z = 0, axis = "v" } })
		local layout = build(steps)
		TestKit.equal(Grid.breachCostTo(layout, ctx().plot, 1, 0, DEFS), 2, "straight through the north wall")
	end)

	test("serialize and deserialize round-trip a layout exactly", function()
		local layout =
			build({ { "build.roof_wood", { x = 2, z = 2 } }, { "build.box", { x = 8, z = 8, rot = 3 } } }, room())
		layout = Grid.damage(layout, uidAt(layout, "frame", 2, 2, "h"), 37, DEFS)
		layout = Grid.upgrade(layout, uidAt(layout, "floor", 2, 2), ctx(T0 + 50)) :: Grid.Layout
		local saved = Grid.serialize(layout)
		TestKit.equal(saved.v, Grid.LAYOUT_VERSION)
		TestKit.equal(#saved.d, 8 * 8, "8 pieces x 8 numbers")
		TestKit.equal(#saved.p, 6, "palette dedupes piece IDs; the wood floor was upgraded away")
		local loaded = Grid.deserialize(saved, DEFS) :: Grid.Layout
		TestKit.deepEqual(loaded, layout, "pieces, slots and nextUid")
		TestKit.deepEqual(Grid.serialize(loaded), saved, "stable encoding")
	end)

	test("deserialize rejects unknown versions and corrupt data", function()
		local saved = Grid.serialize(room())
		local future = table.clone(saved)
		future.v = 99
		TestKit.equal(select(2, Grid.deserialize(future, DEFS)), "unsupportedVersion")
		TestKit.equal(select(2, Grid.deserialize(nil :: any, DEFS)), "unsupportedVersion")
		local short = table.clone(saved)
		short.d = { 1, 2, 3 }
		TestKit.equal(select(2, Grid.deserialize(short, DEFS)), "corrupt")
		local duplicate = table.clone(saved)
		duplicate.d = table.clone(saved.d)
		for i = 1, 8 do
			table.insert(duplicate.d, saved.d[i])
		end
		TestKit.equal(select(2, Grid.deserialize(duplicate, DEFS)), "corrupt", "same uid twice")
		TestKit.deepEqual(Grid.deserialize(Grid.serialize(Grid.new()), DEFS), Grid.new(), "empty layout")
		local unknown = table.clone(saved)
		unknown.p = table.clone(saved.p)
		unknown.p[1] = "build.gone"
		TestKit.equal(select(2, Grid.deserialize(unknown, DEFS)), "corrupt", "unknown piece id")
	end)

	test("layouts from the retired 12-stud grid reset to an empty plot", function()
		local layout = build({ { "build.floor_wood", { x = 2, z = 1 } } })
		for _, version in { 1, 2 } do
			local saved = Grid.serialize(layout)
			saved.v = version
			local loaded = Grid.deserialize(saved, DEFS) :: Grid.Layout
			TestKit.deepEqual(loaded, Grid.new(), `v{version} resets`)
		end
		TestKit.equal(Grid.serialize(layout).v, 3, "saves as version 3")
	end)

	test("stud helpers snap positions to cells and edges", function()
		local c = Grid.CELL_STUDS -- 8
		TestKit.deepEqual({ Grid.cellAt(c + 1, 2.5 * c) }, { 1, 2 })
		TestKit.deepEqual({ Grid.cellCenter(1, 2) }, { 1.5 * c, 2.5 * c })
		TestKit.deepEqual({ Grid.edgeCenter("v", 1, 2) }, { c, 2.5 * c, 90 })
		TestKit.deepEqual({ Grid.edgeNear(1.5 * c, 2.1 * c) }, { "h", 1, 2 }, "near the south side of (1,2)")
		TestKit.deepEqual({ Grid.edgeNear(1.9 * c, 2.5 * c) }, { "v", 2, 2 }, "near the east side of (1,2)")
	end)
end
