--!strict
--[[
	Grid: the outpost building model (GAME_DESIGN.md "Building"). The same module
	runs on the client (placement preview) and the server (authority).

	Coordinates: a plot is `width` x `depth` cells of 12 studs, cell (0, 0) at
	the plot's corner. Edges sit between cells:
	- an "h" edge (x, z) runs along X on the line z, between cells (x, z-1) and (x, z);
	- a "v" edge (x, z) runs along Z on the line x, between cells (x-1, z) and (x, z).
	So "h" edges have 0 <= x < width, 0 <= z <= depth, and "v" edges have
	0 <= x <= width, 0 <= z < depth.

	Layers (one piece per layer per slot), from BuildPieceDef.kind:
	- floor:  foundation, on a cell
	- frame:  wall, doorway, window, on an edge
	- fill:   door, gate, on an edge that has a doorway frame
	- roof:   roof, on a cell with a foundation
	- object: everything else (station, storage, defenses), on a fine sub-grid
	          of Grid.SUB x Grid.SUB quarter cells per cell. An object's x, z
	          are its footprint's minimum corner in quarter cells; its
	          footprint (BuildPieceDef.footprint, quarter cells, turned by
	          `rot`) must lie wholly on foundations and overlap no other object.

	Rules:
	- Only the plot owner builds, upgrades or demolishes; pieces must be inside
	  the plot and their slot free; `plot.maxTier` (Hearth gating) caps tiers.
	- An edge piece needs an adjacent foundation whose tier is at least its own
	  ("wall tier cannot exceed floor tier"). A roof needs a foundation of at
	  least its tier on its cell. Objects need foundations under every cell
	  their footprint covers.
	- Removing a foundation collapses every edge piece and roof that loses its
	  support, and every door whose doorway collapsed. Objects rest on the
	  ground, so a foundation with an object on it cannot be demolished (empty
	  the station or storage first), but it can still be destroyed in a raid.
	- Demolish refunds the full cost within the grace window and
	  `lateRefundFraction` (50%) after. BuildPieceDef.cost of an upgraded tier
	  is the price of upgrading into it, so a refund walks the upgrade chain.
	- Breach: one charge removes hp / breachCost, so every piece falls to a
	  finite number of charges.

	Grid never touches inventories: `place` and `upgrade` tell the service what
	to charge (BuildPieceDef.cost), `demolish` what to refund.
]]

local Tuning = require("../Data/Tuning")
local Types = require("../Types")

local Grid = {}

Grid.CELL_STUDS = Tuning.building.gridStuds
-- Quarter cells per cell side: the furniture sub-grid.
Grid.SUB = 4
Grid.SUB_STUDS = Grid.CELL_STUDS / Grid.SUB
-- 2: objects moved from whole cells to quarter cells.
-- 3: the cell shrank from 12 to 8 studs. Older layouts are reset to an empty plot on
--    load (nothing was live; their cell coordinates no longer mean the same place).
Grid.LAYOUT_VERSION = 3

export type Axis = "h" | "v"
export type Layer = "floor" | "frame" | "fill" | "roof" | "object"

export type Target = {
	x: number, -- cells; for objects, quarter cells (footprint minimum corner)
	z: number,
	axis: Axis?, -- edge pieces
	rot: number?, -- objects: quarter turns 0-3
}

export type Piece = {
	uid: string,
	pieceId: Types.BuildPieceId,
	layer: Layer,
	x: number,
	z: number,
	axis: Axis?,
	rot: number,
	hp: number,
	placedAt: number,
	upgradedAt: number,
}

export type Layout = {
	nextUid: number,
	pieces: { [string]: Piece },
	slots: { [string]: string }, -- slot key -> uid; derived, rebuilt on load
}

export type Plot = {
	ownerUserId: number,
	width: number,
	depth: number,
	maxTier: number?,
}

export type Config = {
	refundGraceSeconds: number,
	lateRefundFraction: number,
}

export type Defs = { [Types.BuildPieceId]: Types.BuildPieceDef }

export type Context = {
	plot: Plot,
	actorUserId: number,
	pieces: Defs,
	now: number,
	config: Config?,
}

export type Removal = {
	removed: { Piece }, -- the target first, then everything that collapsed
	refund: { Types.ItemStack },
}

export type Saved = {
	v: number, -- layout version
	n: number, -- next uid
	t: number, -- base timestamp
	p: { string }, -- palette of piece IDs
	d: { number }, -- FIELDS numbers per piece
}

export type Reason =
	"notOwner"
	| "unknownPiece"
	| "badTarget"
	| "outOfBounds"
	| "occupied"
	| "needsFoundation"
	| "needsDoorway"
	| "tierTooHigh"
	| "plotTier"
	| "notFound"
	| "maxTier"
	| "objectOnTop"

Grid.DEFAULT_CONFIG = {
	refundGraceSeconds = 300,
	lateRefundFraction = 0.5,
} :: Config

local EPSILON = 1e-6
local FIELDS = 8
local MAX_CHAIN = 32

local LAYER_BY_KIND: { [string]: Layer } = {
	foundation = "floor",
	wall = "frame",
	doorway = "frame",
	window = "frame",
	door = "fill",
	gate = "fill",
	roof = "roof",
}

type Cell = { x: number, z: number }
type Edge = { axis: Axis, x: number, z: number }

-- Helpers ------------------------------------------------------------------------

local function isInteger(value: number): boolean
	return value == value and value % 1 == 0
end

local function isEdgeLayer(layer: Layer): boolean
	return layer == "frame" or layer == "fill"
end

local function slotKey(layer: Layer, x: number, z: number, axis: Axis?): string
	return `{layer}:{axis or "c"}:{x},{z}`
end

local function keyOf(piece: Piece): string
	return slotKey(piece.layer, piece.x, piece.z, piece.axis)
end

local function quarterKey(qx: number, qz: number): string
	return `object:q:{qx},{qz}`
end

-- An object's footprint in quarter cells for a rotation: width along X, depth along Z.
function Grid.footprint(def: Types.BuildPieceDef, rot: number?): (number, number)
	local fp = def.footprint
	local w = if fp then fp.w else Grid.SUB
	local d = if fp then fp.d else Grid.SUB
	if (rot or 0) % 2 == 1 then
		return d, w
	end
	return w, d
end

-- The quarter-cell slot keys an object covers at (qx, qz) with this footprint.
local function quarterKeys(qx: number, qz: number, w: number, d: number): { string }
	local keys = table.create(w * d) :: { string }
	for x = qx, qx + w - 1 do
		for z = qz, qz + d - 1 do
			table.insert(keys, quarterKey(x, z))
		end
	end
	return keys
end

local function edgeCells(axis: Axis, x: number, z: number): { Cell }
	if axis == "h" then
		return { { x = x, z = z - 1 }, { x = x, z = z } }
	end
	return { { x = x - 1, z = z }, { x = x, z = z } }
end

local function cellEdges(x: number, z: number): { Edge }
	return {
		{ axis = "h", x = x, z = z },
		{ axis = "h", x = x, z = z + 1 },
		{ axis = "v", x = x, z = z },
		{ axis = "v", x = x + 1, z = z },
	}
end

local function cellInBounds(plot: Plot, x: number, z: number): boolean
	return x >= 0 and z >= 0 and x < plot.width and z < plot.depth
end

local function edgeInBounds(plot: Plot, axis: Axis, x: number, z: number): boolean
	if axis == "h" then
		return x >= 0 and x < plot.width and z >= 0 and z <= plot.depth
	end
	return x >= 0 and x <= plot.width and z >= 0 and z < plot.depth
end

local function copy(layout: Layout): Layout
	return { nextUid = layout.nextUid, pieces = table.clone(layout.pieces), slots = table.clone(layout.slots) }
end

local function defOf(defs: Defs, piece: Piece): Types.BuildPieceDef
	local def = defs[piece.pieceId]
	assert(def, `unknown build piece '{piece.pieceId}'`)
	return def
end

-- Every slot key a piece occupies: one for cells and edges, each covered quarter for objects.
local function keysOf(piece: Piece, defs: Defs): { string }
	if piece.layer ~= "object" then
		return { keyOf(piece) }
	end
	local w, d = Grid.footprint(defOf(defs, piece), piece.rot)
	return quarterKeys(piece.x, piece.z, w, d)
end

-- The cells an object's footprint at `target` covers.
function Grid.cellsUnder(def: Types.BuildPieceDef, target: Target): { Cell }
	local w, d = Grid.footprint(def, target.rot)
	local cells: { Cell } = {}
	for x = target.x // Grid.SUB, (target.x + w - 1) // Grid.SUB do
		for z = target.z // Grid.SUB, (target.z + d - 1) // Grid.SUB do
			table.insert(cells, { x = x, z = z })
		end
	end
	return cells
end

-- Highest foundation tier among the cells an edge touches; -1 when there is none.
local function supportTier(layout: Layout, defs: Defs, axis: Axis, x: number, z: number): number
	local best = -1
	for _, cell in edgeCells(axis, x, z) do
		local uid = layout.slots[slotKey("floor", cell.x, cell.z)]
		if uid then
			best = math.max(best, defOf(defs, layout.pieces[uid]).tier)
		end
	end
	return best
end

-- Public queries ---------------------------------------------------------------------

function Grid.new(): Layout
	return { nextUid = 1, pieces = {}, slots = {} }
end

-- The layer a piece definition occupies.
function Grid.layerOf(def: Types.BuildPieceDef): Layer
	return LAYER_BY_KIND[def.kind :: string] or "object"
end

-- The piece in `layer` at a cell (or an edge, with `axis`), if any. For "object",
-- any object whose footprint covers part of the cell.
function Grid.pieceAt(layout: Layout, layer: Layer, x: number, z: number, axis: Axis?): Piece?
	if layer == "object" then
		for qx = x * Grid.SUB, x * Grid.SUB + Grid.SUB - 1 do
			for qz = z * Grid.SUB, z * Grid.SUB + Grid.SUB - 1 do
				local found = layout.slots[quarterKey(qx, qz)]
				if found then
					return layout.pieces[found]
				end
			end
		end
		return nil
	end
	local uid = layout.slots[slotKey(layer, x, z, if isEdgeLayer(layer) then axis else nil)]
	return if uid then layout.pieces[uid] else nil
end

-- The object covering quarter cell (qx, qz), if any.
function Grid.objectAt(layout: Layout, qx: number, qz: number): Piece?
	local uid = layout.slots[quarterKey(qx, qz)]
	return if uid then layout.pieces[uid] else nil
end

-- Stud offsets of an object's footprint centre from the plot corner.
function Grid.objectCenter(def: Types.BuildPieceDef, target: Target): (number, number)
	local w, d = Grid.footprint(def, target.rot)
	return (target.x + w / 2) * Grid.SUB_STUDS, (target.z + d / 2) * Grid.SUB_STUDS
end

-- Stud offsets of a cell's centre from the plot corner.
function Grid.cellCenter(x: number, z: number): (number, number)
	return (x + 0.5) * Grid.CELL_STUDS, (z + 0.5) * Grid.CELL_STUDS
end

-- Stud offsets of an edge's centre and its yaw in degrees (0 runs along X).
function Grid.edgeCenter(axis: Axis, x: number, z: number): (number, number, number)
	if axis == "h" then
		return (x + 0.5) * Grid.CELL_STUDS, z * Grid.CELL_STUDS, 0
	end
	return x * Grid.CELL_STUDS, (z + 0.5) * Grid.CELL_STUDS, 90
end

-- The cell under a stud position (relative to the plot corner).
function Grid.cellAt(px: number, pz: number): (number, number)
	return math.floor(px / Grid.CELL_STUDS), math.floor(pz / Grid.CELL_STUDS)
end

-- The edge nearest a stud position, for snapping walls under the cursor or finger.
function Grid.edgeNear(px: number, pz: number): (Axis, number, number)
	local x, z = Grid.cellAt(px, pz)
	local fx, fz = px / Grid.CELL_STUDS - x, pz / Grid.CELL_STUDS - z
	local candidates: { { distance: number, edge: Edge } } = {
		{ distance = fz, edge = { axis = "h", x = x, z = z } },
		{ distance = 1 - fz, edge = { axis = "h", x = x, z = z + 1 } },
		{ distance = fx, edge = { axis = "v", x = x, z = z } },
		{ distance = 1 - fx, edge = { axis = "v", x = x + 1, z = z } },
	}
	local best = candidates[1]
	for _, candidate in candidates do
		if candidate.distance < best.distance then
			best = candidate
		end
	end
	return best.edge.axis, best.edge.x, best.edge.z
end

-- Placement ------------------------------------------------------------------------------

-- Whether `pieceId` can go at `target`. Returns true, or false and a reason.
function Grid.canPlace(layout: Layout, pieceId: Types.BuildPieceId, target: Target, ctx: Context): (boolean, Reason?)
	local plot = ctx.plot
	if ctx.actorUserId ~= plot.ownerUserId then
		return false, "notOwner"
	end
	local def = ctx.pieces[pieceId]
	if not def then
		return false, "unknownPiece"
	end
	if plot.maxTier and def.tier > plot.maxTier then
		return false, "plotTier"
	end
	if not isInteger(target.x) or not isInteger(target.z) then
		return false, "badTarget"
	end

	local layer: Layer = Grid.layerOf(def)
	if isEdgeLayer(layer) then
		local axis = target.axis
		if axis ~= "h" and axis ~= "v" then
			return false, "badTarget"
		end
		if not edgeInBounds(plot, axis, target.x, target.z) then
			return false, "outOfBounds"
		end
		if layout.slots[slotKey(layer, target.x, target.z, axis)] then
			return false, "occupied"
		end
		if layer == "fill" then
			local frame = Grid.pieceAt(layout, "frame", target.x, target.z, axis)
			if not frame or (defOf(ctx.pieces, frame).kind :: string) ~= "doorway" then
				return false, "needsDoorway"
			end
		end
		local support = supportTier(layout, ctx.pieces, axis, target.x, target.z)
		if support < 0 then
			return false, "needsFoundation"
		end
		if support < def.tier then
			return false, "tierTooHigh"
		end
		return true, nil
	end

	if layer == "object" then
		local w, d = Grid.footprint(def, target.rot)
		if
			target.x < 0
			or target.z < 0
			or target.x + w > plot.width * Grid.SUB
			or target.z + d > plot.depth * Grid.SUB
		then
			return false, "outOfBounds"
		end
		for _, key in quarterKeys(target.x, target.z, w, d) do
			if layout.slots[key] then
				return false, "occupied"
			end
		end
		for _, cell in Grid.cellsUnder(def, target) do
			if layout.slots[slotKey("floor", cell.x, cell.z)] == nil then
				return false, "needsFoundation"
			end
		end
		return true, nil
	end
	if not cellInBounds(plot, target.x, target.z) then
		return false, "outOfBounds"
	end
	if layout.slots[slotKey(layer, target.x, target.z)] then
		return false, "occupied"
	end
	if layer == "roof" then
		local floor = Grid.pieceAt(layout, "floor", target.x, target.z)
		if not floor then
			return false, "needsFoundation"
		end
		if defOf(ctx.pieces, floor).tier < def.tier then
			return false, "tierTooHigh"
		end
	end
	return true, nil
end

--[[
	Places a piece at full HP. Returns the new layout and the piece, or nil, nil
	and a reason. The caller charges BuildPieceDef.cost.
]]
function Grid.place(
	layout: Layout,
	pieceId: Types.BuildPieceId,
	target: Target,
	ctx: Context
): (Layout?, Piece?, Reason?)
	local ok: boolean, reason: Reason? = Grid.canPlace(layout, pieceId, target, ctx)
	if not ok then
		return nil, nil, reason
	end
	local def = ctx.pieces[pieceId]
	local layer: Layer = Grid.layerOf(def)
	local piece: Piece = {
		uid = tostring(layout.nextUid),
		pieceId = pieceId,
		layer = layer,
		x = target.x,
		z = target.z,
		axis = if isEdgeLayer(layer) then target.axis else nil,
		rot = if layer == "object" then (target.rot or 0) % 4 else 0,
		hp = def.hp,
		placedAt = ctx.now,
		upgradedAt = ctx.now,
	}
	local result = copy(layout)
	result.nextUid += 1
	result.pieces[piece.uid] = piece
	for _, key in keysOf(piece, ctx.pieces) do
		result.slots[key] = piece.uid
	end
	return result, piece, nil
end

-- Move ---------------------------------------------------------------------------------------

-- The layout without one piece (for checking where an object may move to).
function Grid.without(layout: Layout, uid: string, defs: Defs): Layout
	local piece = layout.pieces[uid]
	if piece == nil then
		return layout
	end
	local result = copy(layout)
	result.pieces[uid] = nil
	for _, key in keysOf(piece, defs) do
		if result.slots[key] == uid then
			result.slots[key] = nil
		end
	end
	return result
end

--[[
	Moves or turns an object (station, storage, furniture) to `target`, keeping its uid,
	HP and timestamps, so a station keeps its converter and a crate its items (LDOE_PARITY
	#27's move button). Floors, walls and doors are rebuilt rather than moved. Returns the
	new layout, or nil and a reason.
]]
function Grid.move(layout: Layout, uid: string, target: Target, ctx: Context): (Layout?, Reason?)
	local piece = layout.pieces[uid]
	if piece == nil then
		return nil, "notFound"
	end
	if ctx.actorUserId ~= ctx.plot.ownerUserId then
		return nil, "notOwner"
	end
	if piece.layer ~= "object" then
		return nil, "badTarget"
	end
	local lifted = Grid.without(layout, uid, ctx.pieces)
	local ok: boolean, reason: Reason? = Grid.canPlace(lifted, piece.pieceId, target, ctx)
	if not ok then
		return nil, reason
	end
	local moved = table.clone(piece)
	moved.x = target.x
	moved.z = target.z
	moved.rot = (target.rot or 0) % 4
	lifted.pieces[uid] = moved
	for _, key in keysOf(moved, ctx.pieces) do
		lifted.slots[key] = uid
	end
	return lifted, nil
end

-- Upgrade ----------------------------------------------------------------------------------

-- Whether the piece can upgrade in place. Returns true, or false and a reason.
function Grid.canUpgrade(layout: Layout, uid: string, ctx: Context): (boolean, Reason?)
	if ctx.actorUserId ~= ctx.plot.ownerUserId then
		return false, "notOwner"
	end
	local piece = layout.pieces[uid]
	if not piece then
		return false, "notFound"
	end
	local nextId = defOf(ctx.pieces, piece).upgradesTo
	if not nextId then
		return false, "maxTier"
	end
	local nextDef = ctx.pieces[nextId]
	if not nextDef then
		return false, "unknownPiece"
	end
	if ctx.plot.maxTier and nextDef.tier > ctx.plot.maxTier then
		return false, "plotTier"
	end
	if isEdgeLayer(piece.layer) then
		if supportTier(layout, ctx.pieces, piece.axis :: Axis, piece.x, piece.z) < nextDef.tier then
			return false, "tierTooHigh"
		end
	elseif piece.layer == "roof" then
		local floor = Grid.pieceAt(layout, "floor", piece.x, piece.z)
		if not floor or defOf(ctx.pieces, floor).tier < nextDef.tier then
			return false, "tierTooHigh"
		end
	elseif piece.layer == "object" then
		-- A bigger next tier must still fit where the object stands.
		local w, d = Grid.footprint(nextDef, piece.rot)
		local plot = ctx.plot
		if piece.x + w > plot.width * Grid.SUB or piece.z + d > plot.depth * Grid.SUB then
			return false, "outOfBounds"
		end
		for _, key in quarterKeys(piece.x, piece.z, w, d) do
			local other = layout.slots[key]
			if other and other ~= uid then
				return false, "occupied"
			end
		end
	end
	return true, nil
end

--[[
	Upgrades a piece in place to its `upgradesTo` tier at full HP. Returns the new
	layout and the cost to charge, or nil, nil and a reason.
]]
function Grid.upgrade(layout: Layout, uid: string, ctx: Context): (Layout?, { Types.ItemStack }?, Reason?)
	local ok: boolean, reason: Reason? = Grid.canUpgrade(layout, uid, ctx)
	if not ok then
		return nil, nil, reason
	end
	local piece = layout.pieces[uid]
	local nextId = defOf(ctx.pieces, piece).upgradesTo :: Types.BuildPieceId
	local nextDef = ctx.pieces[nextId]
	assert(Grid.layerOf(nextDef) == piece.layer, `'{nextId}' is on a different layer than '{piece.pieceId}'`)
	local upgraded = table.clone(piece)
	upgraded.pieceId = nextId
	upgraded.hp = nextDef.hp
	upgraded.upgradedAt = ctx.now
	local result = copy(layout)
	result.pieces[uid] = upgraded
	if piece.layer == "object" then
		for _, key in keysOf(piece, ctx.pieces) do
			result.slots[key] = nil
		end
		for _, key in keysOf(upgraded, ctx.pieces) do
			result.slots[key] = uid
		end
	end
	return result, table.clone(nextDef.cost), nil
end

-- Removal, collapse and refunds -------------------------------------------------------------

-- Removes `uid` and everything that loses support because of it.
local function removeWithCascade(layout: Layout, uid: string, defs: Defs): (Layout, { Piece })
	local result = copy(layout)
	local removed: { Piece } = {}
	local function drop(piece: Piece)
		result.pieces[piece.uid] = nil
		for _, key in keysOf(piece, defs) do
			result.slots[key] = nil
		end
		table.insert(removed, piece)
	end

	local target = result.pieces[uid]
	drop(target)
	if target.layer == "floor" then
		for _, edge in cellEdges(target.x, target.z) do
			local support = supportTier(result, defs, edge.axis, edge.x, edge.z)
			local frame = Grid.pieceAt(result, "frame", edge.x, edge.z, edge.axis)
			if frame and support < defOf(defs, frame).tier then
				drop(frame)
			end
			local fill = Grid.pieceAt(result, "fill", edge.x, edge.z, edge.axis)
			local frameLeft = Grid.pieceAt(result, "frame", edge.x, edge.z, edge.axis)
			if fill and (not frameLeft or support < defOf(defs, fill).tier) then
				drop(fill)
			end
		end
		local roof = Grid.pieceAt(result, "roof", target.x, target.z)
		if roof then
			drop(roof)
		end
	elseif target.layer == "frame" then
		local fill = Grid.pieceAt(result, "fill", target.x, target.z, target.axis)
		if fill then
			drop(fill)
		end
	end
	return result, removed
end

-- The upgrade chain ending at `pieceId`, base tier first.
local function upgradeChain(pieceId: Types.BuildPieceId, defs: Defs): { Types.BuildPieceDef }
	local chain: { Types.BuildPieceDef } = { defs[pieceId] }
	local current = pieceId
	for _ = 1, MAX_CHAIN do
		local previous: Types.BuildPieceDef? = nil
		for _, def in defs do
			if def.upgradesTo == current then
				previous = def
				break
			end
		end
		if not previous then
			return chain
		end
		table.insert(chain, 1, previous)
		current = previous.id
	end
	error(`upgrade chain for '{pieceId}' is longer than {MAX_CHAIN} (a cycle?)`)
end

local function merge(into: { Types.ItemStack }, itemId: string, count: number)
	if count <= 0 then
		return
	end
	for _, stack in into do
		if stack.itemId == itemId then
			stack.count += count
			return
		end
	end
	table.insert(into, { itemId = itemId, count = count })
end

--[[
	What demolishing `piece` now would return. The whole investment comes back
	in full while the piece is within the grace window of being placed; the
	latest upgrade comes back in full within the grace window of that upgrade;
	everything else returns `lateRefundFraction`, rounded down per stack.
]]
function Grid.refundFor(piece: Piece, ctx: Context): { Types.ItemStack }
	local config = ctx.config or Grid.DEFAULT_CONFIG
	local fresh = ctx.now - piece.placedAt <= config.refundGraceSeconds
	local freshUpgrade = ctx.now - piece.upgradedAt <= config.refundGraceSeconds
	local chain = upgradeChain(piece.pieceId, ctx.pieces)
	local refund: { Types.ItemStack } = {}
	for index, def in chain do
		local fraction = if fresh or (index == #chain and freshUpgrade) then 1 else config.lateRefundFraction
		for _, stack in def.cost do
			merge(refund, stack.itemId, math.floor(stack.count * fraction + EPSILON))
		end
	end
	return refund
end

--[[
	Demolishes a piece and everything it was holding up. Returns the new layout
	and the removal (pieces and refund), or nil, nil and a reason ("notOwner",
	"notFound", "objectOnTop").
]]
function Grid.demolish(layout: Layout, uid: string, ctx: Context): (Layout?, Removal?, Reason?)
	if ctx.actorUserId ~= ctx.plot.ownerUserId then
		return nil, nil, "notOwner"
	end
	local piece = layout.pieces[uid]
	if not piece then
		return nil, nil, "notFound"
	end
	if piece.layer == "floor" and Grid.pieceAt(layout, "object", piece.x, piece.z) then
		return nil, nil, "objectOnTop"
	end
	local result, removed = removeWithCascade(layout, uid, ctx.pieces)
	local refund: { Types.ItemStack } = {}
	for _, gone in removed do
		for _, stack in Grid.refundFor(gone, ctx) do
			merge(refund, stack.itemId, stack.count)
		end
	end
	return result, { removed = removed, refund = refund }, nil
end

-- Damage and breach ------------------------------------------------------------------------

--[[
	Deals `amount` damage. Returns the new layout and the destroyed pieces (the
	target and its collapse cascade), or an empty list if it survived. Destroyed
	pieces refund nothing. An unknown uid changes nothing.
]]
function Grid.damage(layout: Layout, uid: string, amount: number, defs: Defs): (Layout, { Piece })
	local piece = layout.pieces[uid]
	if not piece or amount <= 0 then
		return layout, {}
	end
	local hp = piece.hp - amount
	if hp > EPSILON then
		local damaged = table.clone(piece)
		damaged.hp = hp
		local result = copy(layout)
		result.pieces[uid] = damaged
		return result, {}
	end
	return removeWithCascade(layout, uid, defs)
end

-- HP one breach charge removes from a piece of this definition.
function Grid.chargeDamage(def: Types.BuildPieceDef): number
	return def.hp / math.max(1, def.breachCost)
end

-- Charges needed to destroy `piece` at its current HP (at least 1).
function Grid.breachCost(piece: Piece, def: Types.BuildPieceDef): number
	return math.max(1, math.ceil(piece.hp / Grid.chargeDamage(def) - EPSILON))
end

-- Applies `charges` breach charges to a piece (see `damage`).
function Grid.applyCharges(layout: Layout, uid: string, charges: number, defs: Defs): (Layout, { Piece })
	local piece = layout.pieces[uid]
	if not piece then
		return layout, {}
	end
	return Grid.damage(layout, uid, charges * Grid.chargeDamage(defOf(defs, piece)), defs)
end

-- Charges to get through one edge: 0 when open, else the frame (or its door).
local function edgeCost(layout: Layout, defs: Defs, edge: Edge): number
	local frame = Grid.pieceAt(layout, "frame", edge.x, edge.z, edge.axis)
	if not frame then
		return 0
	end
	local frameDef = defOf(defs, frame)
	if (frameDef.kind :: string) == "doorway" then
		local door = Grid.pieceAt(layout, "fill", edge.x, edge.z, edge.axis)
		return if door then Grid.breachCost(door, defOf(defs, door)) else 0
	end
	return Grid.breachCost(frame, frameDef)
end

--[[
	Estimates the fewest breach charges a raider needs to reach cell (x, z) from
	outside the plot, crossing walls, windows and doors at their current HP.
	0 means the cell is open to the outside.
]]
function Grid.breachCostTo(layout: Layout, plot: Plot, x: number, z: number, defs: Defs): number
	assert(cellInBounds(plot, x, z), "target cell is outside the plot")
	local function index(cx: number, cz: number): number
		return cz * plot.width + cx + 1
	end
	local count = plot.width * plot.depth
	local dist: { number } = table.create(count, math.huge) :: { number }
	local settled: { boolean } = table.create(count, false) :: { boolean }

	-- Seed: boundary cells are reachable from outside through their outer edges.
	for cz = 0, plot.depth - 1 do
		for cx = 0, plot.width - 1 do
			for _, edge in cellEdges(cx, cz) do
				local outside = false
				for _, cell in edgeCells(edge.axis, edge.x, edge.z) do
					if not cellInBounds(plot, cell.x, cell.z) then
						outside = true
					end
				end
				if outside then
					local i = index(cx, cz)
					dist[i] = math.min(dist[i], edgeCost(layout, defs, edge))
				end
			end
		end
	end

	-- Dijkstra over cells (plots are small, so a linear scan is fine).
	for _ = 1, count do
		local best, bestIndex = math.huge, 0
		for i = 1, count do
			if not settled[i] and dist[i] < best then
				best, bestIndex = dist[i], i
			end
		end
		if bestIndex == 0 then
			break
		end
		settled[bestIndex] = true
		local cx, cz = (bestIndex - 1) % plot.width, (bestIndex - 1) // plot.width
		if cx == x and cz == z then
			return best
		end
		for _, edge in cellEdges(cx, cz) do
			for _, cell in edgeCells(edge.axis, edge.x, edge.z) do
				if cellInBounds(plot, cell.x, cell.z) and not (cell.x == cx and cell.z == cz) then
					local j = index(cell.x, cell.z)
					local candidate = best + edgeCost(layout, defs, edge)
					if candidate < dist[j] then
						dist[j] = candidate
					end
				end
			end
		end
	end
	return dist[index(x, z)]
end

-- Serialization ------------------------------------------------------------------------------

local SLOT_CODE: { [string]: number } = {
	["floor:c"] = 0,
	["frame:h"] = 1,
	["frame:v"] = 2,
	["fill:h"] = 3,
	["fill:v"] = 4,
	["object:c"] = 5,
	["roof:c"] = 6,
}

local SLOT_DECODE: { { layer: Layer, axis: Axis? } } = {
	[0] = { layer = "floor" },
	[1] = { layer = "frame", axis = "h" },
	[2] = { layer = "frame", axis = "v" },
	[3] = { layer = "fill", axis = "h" },
	[4] = { layer = "fill", axis = "v" },
	[5] = { layer = "object" },
	[6] = { layer = "roof" },
} :: any

--[[
	Encodes a layout compactly for its own DataStore key (ARCHITECTURE.md §6):
	a palette of piece IDs plus FIELDS numbers per piece: uid, palette index,
	slot code * 4 + rot, x, z, hp, placedAt - t, upgradedAt - placedAt.
	Pieces are sorted by uid, so the same layout always encodes the same way.
]]
function Grid.serialize(layout: Layout): Saved
	local list: { Piece } = {}
	local base = math.huge
	for _, piece in layout.pieces do
		table.insert(list, piece)
		base = math.min(base, piece.placedAt)
	end
	table.sort(list, function(a, b)
		return (tonumber(a.uid) :: number) < (tonumber(b.uid) :: number)
	end)
	if base == math.huge then
		base = 0
	end

	local palette: { string } = {}
	local paletteIndex: { [string]: number } = {}
	local data: { number } = {}
	for _, piece in list do
		local index = paletteIndex[piece.pieceId]
		if not index then
			table.insert(palette, piece.pieceId)
			index = #palette
			paletteIndex[piece.pieceId] = index
		end
		local code = SLOT_CODE[`{piece.layer}:{piece.axis or "c"}`]
		for _, value in
			{
				tonumber(piece.uid) :: number,
				index,
				code * 4 + piece.rot,
				piece.x,
				piece.z,
				piece.hp,
				piece.placedAt - base,
				piece.upgradedAt - piece.placedAt,
			}
		do
			table.insert(data, value)
		end
	end
	return { v = Grid.LAYOUT_VERSION, n = layout.nextUid, t = base, p = palette, d = data }
end

--[[
	Decodes a saved layout and rebuilds the slot index. Returns nil and a reason
	("unsupportedVersion", "corrupt") for data it cannot trust. `defs` sizes
	object footprints; a piece ID it doesn't know is "corrupt". `saved` is
	untrusted DataStore data.

	Version 1 stored objects on whole cells; they move to the quarter-cell
	footprint centred on that cell (as near as the sub-grid allows).
]]
function Grid.deserialize(saved: any, defs: Defs): (Layout?, string?)
	if type(saved) == "table" and (saved.v == 1 or saved.v == 2) then
		return Grid.new(), nil -- laid out on the retired 12-stud grid: start fresh
	end
	if type(saved) ~= "table" or saved.v ~= Grid.LAYOUT_VERSION then
		return nil, "unsupportedVersion"
	end
	local data, palette = saved.d, saved.p
	if
		type(data) ~= "table"
		or type(palette) ~= "table"
		or #data % FIELDS ~= 0
		or type(saved.n) ~= "number"
		or type(saved.t) ~= "number"
	then
		return nil, "corrupt"
	end
	local layout = Grid.new()
	layout.nextUid = saved.n
	for offset = 0, #data - 1, FIELDS do
		local uidNumber, paletteIndex, slot = data[offset + 1], data[offset + 2], data[offset + 3]
		local pieceId = palette[paletteIndex]
		local decoded = SLOT_DECODE[slot // 4]
		if not pieceId or not decoded or not isInteger(uidNumber) or uidNumber >= saved.n then
			return nil, "corrupt"
		end
		local placedAt = saved.t + data[offset + 7]
		local def = defs[pieceId]
		if def == nil then
			return nil, "corrupt"
		end
		local piece: Piece = {
			uid = tostring(uidNumber),
			pieceId = pieceId,
			layer = decoded.layer,
			x = data[offset + 4],
			z = data[offset + 5],
			axis = decoded.axis,
			rot = slot % 4,
			hp = data[offset + 6],
			placedAt = placedAt,
			upgradedAt = placedAt + data[offset + 8],
		}
		if piece.layer == "object" and saved.v == 1 then
			local w, d = Grid.footprint(def, piece.rot)
			piece.x = math.max(0, piece.x * Grid.SUB + (Grid.SUB - w) // 2)
			piece.z = math.max(0, piece.z * Grid.SUB + (Grid.SUB - d) // 2)
		end
		if layout.pieces[piece.uid] then
			return nil, "corrupt"
		end
		local keys = keysOf(piece, defs)
		for _, key in keys do
			if layout.slots[key] then
				return nil, "corrupt"
			end
		end
		layout.pieces[piece.uid] = piece
		for _, key in keys do
			layout.slots[key] = piece.uid
		end
	end
	return layout, nil
end

return Grid
