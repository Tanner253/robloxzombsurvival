--!strict
--[[
	BuildRules: the game rules on top of Domain/Grid's geometry. Pure, and the
	one check both the client's ghost preview and the server's authority run.

	Grid answers "does it fit here?". BuildRules adds:
	- only chain bases can be placed (upgraded tiers are reached by upgrading,
	  so placing `build.wall_scrap` directly cannot skip the wood price);
	- the piece's (or the next tier's) UnlockGate;
	- BuildPieceDef.maxPerPlot, counted across the whole upgrade chain;
	- objects with minFoundationTier need a foundation of that tier under them;
	- the player can pay the cost (when an inventory is passed).
]]

local Types = require("../Types")
local Grid = require("./Grid")
local Inventory = require("./Inventory")

local BuildRules = {}

export type Progress = {
	level: number,
	unlocks: { recipes: { [string]: boolean }, blueprints: { [string]: boolean } },
}

export type Reason = Grid.Reason | "notBase" | "locked" | "limit" | "cantAfford"

-- Player-facing copy for every reason, for toasts and the build menu.
BuildRules.REASON_TEXT = {
	notOwner = "This isn't your plot",
	unknownPiece = "Unknown piece",
	badTarget = "Can't build there",
	outOfBounds = "Outside your plot",
	occupied = "Something is already there",
	needsFoundation = "Needs a foundation",
	needsDoorway = "Doors go in a doorway",
	tierTooHigh = "Upgrade the foundation first",
	plotTier = "Your Hearth can't support this tier yet",
	notFound = "That piece is gone",
	maxTier = "Already at the top tier",
	objectOnTop = "Clear what stands on it first",
	notBase = "Build the first tier, then upgrade it",
	locked = "Not unlocked yet",
	limit = "Plot limit reached",
	cantAfford = "Not enough materials",
} :: { [string]: string }

local function unlocked(gate: Types.UnlockGate?, progress: Progress): boolean
	if gate == nil or gate.kind == "default" then
		return true
	elseif gate.kind == "level" then
		return progress.level >= gate.level
	end
	return progress.unlocks.blueprints[gate.itemId] == true
end

-- Whether a piece's unlock gate is met.
function BuildRules.isUnlocked(def: Types.BuildPieceDef, progress: Progress): boolean
	return unlocked(def.unlock, progress)
end

-- The piece each upgraded tier comes from (reverse of upgradesTo).
local function parents(defs: Grid.Defs): { [string]: string }
	local result: { [string]: string } = {}
	for id, def in defs do
		if def.upgradesTo then
			result[def.upgradesTo] = id
		end
	end
	return result
end

-- True when nothing upgrades into the piece, so it can be placed directly.
function BuildRules.isBase(pieceId: Types.BuildPieceId, defs: Grid.Defs): boolean
	return parents(defs)[pieceId] == nil
end

-- The base of a piece's upgrade chain.
function BuildRules.rootOf(pieceId: Types.BuildPieceId, defs: Grid.Defs): Types.BuildPieceId
	local up = parents(defs)
	local current = pieceId
	for _ = 1, 32 do
		local parent = up[current]
		if parent == nil then
			return current
		end
		current = parent
	end
	return current
end

-- How many placed pieces share `pieceId`'s upgrade chain.
function BuildRules.countChain(layout: Grid.Layout, pieceId: Types.BuildPieceId, defs: Grid.Defs): number
	local root = BuildRules.rootOf(pieceId, defs)
	local count = 0
	for _, piece in layout.pieces do
		if BuildRules.rootOf(piece.pieceId, defs) == root then
			count += 1
		end
	end
	return count
end

-- The plot limit for the chain (the smallest maxPerPlot along it), or nil.
local function chainLimit(pieceId: Types.BuildPieceId, defs: Grid.Defs): number?
	local limit: number? = nil
	local current: string? = BuildRules.rootOf(pieceId, defs)
	for _ = 1, 32 do
		if current == nil then
			break
		end
		local def = defs[current]
		if def == nil then
			break
		end
		if def.maxPerPlot then
			limit = if limit then math.min(limit, def.maxPerPlot) else def.maxPerPlot
		end
		current = def.upgradesTo
	end
	return limit
end

local function foundationOk(
	layout: Grid.Layout,
	def: Types.BuildPieceDef,
	x: number,
	z: number,
	defs: Grid.Defs
): boolean
	local need = def.minFoundationTier
	if need == nil or Grid.layerOf(def) ~= "object" then
		return true
	end
	local floor = Grid.pieceAt(layout, "floor", x, z)
	if floor == nil then
		return false
	end
	local floorDef = defs[floor.pieceId]
	return floorDef ~= nil and floorDef.tier >= need
end

--[[
	Whether the player may place `pieceId` at `target`. Pass `inventory` to also
	check the cost. Returns true, or false and a Reason.
]]
function BuildRules.canPlace(
	layout: Grid.Layout,
	pieceId: Types.BuildPieceId,
	target: Grid.Target,
	ctx: Grid.Context,
	progress: Progress,
	inventory: Types.Inventory?
): (boolean, Reason?)
	local def = ctx.pieces[pieceId]
	if def == nil then
		return false, "unknownPiece"
	end
	if not BuildRules.isBase(pieceId, ctx.pieces) then
		return false, "notBase"
	end
	if not BuildRules.isUnlocked(def, progress) then
		return false, "locked"
	end
	local ok: boolean, reason: Grid.Reason? = Grid.canPlace(layout, pieceId, target, ctx)
	if not ok then
		return false, reason
	end
	if not foundationOk(layout, def, target.x, target.z, ctx.pieces) then
		local floor = Grid.pieceAt(layout, "floor", target.x, target.z)
		return false, if floor then "tierTooHigh" else "needsFoundation"
	end
	local limit = chainLimit(pieceId, ctx.pieces)
	if limit and BuildRules.countChain(layout, pieceId, ctx.pieces) >= limit then
		return false, "limit"
	end
	if inventory and not Inventory.hasAll(inventory, def.cost) then
		return false, "cantAfford"
	end
	return true, nil
end

--[[
	Whether the player may upgrade piece `uid`. Pass `inventory` to also check
	the upgrade price. Returns true and the next tier's definition, or false,
	nil and a Reason.
]]
function BuildRules.canUpgrade(
	layout: Grid.Layout,
	uid: string,
	ctx: Grid.Context,
	progress: Progress,
	inventory: Types.Inventory?
): (boolean, Types.BuildPieceDef?, Reason?)
	local ok: boolean, reason: Grid.Reason? = Grid.canUpgrade(layout, uid, ctx)
	if not ok then
		return false, nil, reason
	end
	local piece = layout.pieces[uid]
	local nextDef = ctx.pieces[ctx.pieces[piece.pieceId].upgradesTo :: string]
	if not BuildRules.isUnlocked(nextDef, progress) then
		return false, nextDef, "locked"
	end
	if not foundationOk(layout, nextDef, piece.x, piece.z, ctx.pieces) then
		return false, nextDef, "tierTooHigh"
	end
	if inventory and not Inventory.hasAll(inventory, nextDef.cost) then
		return false, nextDef, "cantAfford"
	end
	return true, nextDef, nil
end

-- Pieces the build menu offers: every chain base, sorted by tier then name.
function BuildRules.catalog(defs: Grid.Defs): { Types.BuildPieceDef }
	local result: { Types.BuildPieceDef } = {}
	for id, def in defs do
		if BuildRules.isBase(id, defs) then
			table.insert(result, def)
		end
	end
	table.sort(result, function(a: Types.BuildPieceDef, b: Types.BuildPieceDef)
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		return a.name < b.name
	end)
	return result
end

return BuildRules
