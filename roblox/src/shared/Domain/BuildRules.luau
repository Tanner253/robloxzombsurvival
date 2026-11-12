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
local Unlocks = require("./Unlocks")

local BuildRules = {}

export type Progress = Unlocks.Progress

export type Reason = Grid.Reason | "notBase" | "locked" | "limit" | "cantAfford" | "floorTier"

-- Floor names by foundation tier, for the floor-tier gate (LDOE_PARITY #22).
BuildRules.FLOOR_NAMES = { "Timber", "Scrap", "Reinforced" } :: { string }

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
	notReady = "Not available yet",
	floorTier = "Needs a better floor",
} :: { [string]: string }

local unlocked = Unlocks.isMet

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

-- Extra plot slots the player bought, per base piece ("+1 Smelter can be placed"):
-- each product's pieceSlot grants times how many of it they bought.
function BuildRules.pieceSlots(
	products: { [string]: Types.ProductDef },
	counts: { [string]: number }
): { [string]: number }
	local slots: { [string]: number } = {}
	for id, product in products do
		local bought = counts[id] or 0
		if bought > 0 then
			for _, grant in product.grants do
				local g: any = grant
				if g.kind == "pieceSlot" then
					slots[g.pieceId] = (slots[g.pieceId] or 0) + g.amount * bought
				end
			end
		end
	end
	return slots
end

-- The plot limit for `pieceId`'s upgrade chain, or nil (shown as "Placed 1/2", 5.11),
-- raised by the slots the player bought for the chain's base piece.
function BuildRules.limitOf(pieceId: Types.BuildPieceId, defs: Grid.Defs, slots: { [string]: number }?): number?
	local limit = chainLimit(pieceId, defs)
	if limit and slots then
		local root = BuildRules.rootOf(pieceId, defs)
		limit += if root then slots[root] or 0 else 0
	end
	return limit
end

-- Every capped chain on the plot, by base piece: how many stand and the limit now (the
-- shop's "+1 can be placed" waits for count >= limit, the flow review's F-27).
function BuildRules.placedCaps(
	layout: Grid.Layout,
	defs: Grid.Defs,
	slots: { [string]: number }?
): { [string]: { count: number, limit: number } }
	local caps: { [string]: { count: number, limit: number } } = {}
	for id in defs do
		if BuildRules.isBase(id, defs) then
			local limit = BuildRules.limitOf(id, defs, slots)
			if limit then
				caps[id] = { count = BuildRules.countChain(layout, id, defs), limit = limit }
			end
		end
	end
	return caps
end

-- Whether every foundation under an object meets its minFoundationTier.
local function foundationOk(
	layout: Grid.Layout,
	def: Types.BuildPieceDef,
	target: Grid.Target,
	defs: Grid.Defs
): boolean
	local need = def.minFoundationTier
	if need == nil or Grid.layerOf(def) ~= "object" then
		return true
	end
	for _, cell in Grid.cellsUnder(def, target) do
		local floor = Grid.pieceAt(layout, "floor", cell.x, cell.z)
		local floorDef = if floor then defs[floor.pieceId] else nil
		if floorDef == nil or floorDef.tier < need then
			return false
		end
	end
	return true
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
	inventory: Types.Inventory?,
	slots: { [string]: number }?
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
	if not foundationOk(layout, def, target, ctx.pieces) then
		return false, "floorTier"
	end
	local limit = BuildRules.limitOf(pieceId, ctx.pieces, slots)
	if limit and BuildRules.countChain(layout, pieceId, ctx.pieces) >= limit then
		return false, "limit"
	end
	if inventory and not Inventory.hasAll(inventory, def.cost) then
		return false, "cantAfford"
	end
	return true, nil
end

-- Whether an object may move to `target` (LDOE_PARITY #27): where it fits once lifted, on
-- a floor of its tier. Returns true, or false and a reason.
function BuildRules.canMove(
	layout: Grid.Layout,
	uid: string,
	target: Grid.Target,
	ctx: Grid.Context
): (boolean, Reason?)
	local piece = layout.pieces[uid]
	if piece == nil then
		return false, "notFound"
	end
	local def = ctx.pieces[piece.pieceId]
	local lifted = Grid.without(layout, uid, ctx.pieces)
	local ok: boolean, reason: Grid.Reason? = Grid.canPlace(lifted, piece.pieceId, target, ctx)
	if not ok then
		return false, reason
	end
	if piece.layer ~= "object" then
		return false, "badTarget"
	end
	if not foundationOk(lifted, def, target, ctx.pieces) then
		return false, "floorTier"
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
	if not foundationOk(layout, nextDef, { x = piece.x, z = piece.z, rot = piece.rot }, ctx.pieces) then
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

--[[
	The sentence a player sees for a refusal, with the specifics the bare reason
	leaves out (PLAYER_EXPERIENCE_CHECKLIST 6.2): what is missing with have/need,
	the level or blueprint that unlocks the piece, the plot limit. `items` names
	item ids; `inventory` may be nil before the first sync.
]]
function BuildRules.explain(
	reason: string?,
	def: Types.BuildPieceDef?,
	inventory: Types.Inventory?,
	items: { [string]: { name: string } },
	defs: Grid.Defs?,
	quests: { [string]: { name: string } }?
): string
	local base = BuildRules.REASON_TEXT[reason or ""] or "Can't build there"
	if def == nil then
		return base
	end
	if reason == "cantAfford" and inventory then
		local missing: { string } = {}
		for _, stack in def.cost do
			local have = Inventory.count(inventory, stack.itemId)
			if have < stack.count then
				local item = items[stack.itemId]
				table.insert(missing, `{if item then item.name else stack.itemId} {have}/{stack.count}`)
			end
		end
		if #missing > 0 then
			return `Not enough {table.concat(missing, ", ")}`
		end
	elseif reason == "floorTier" and def.minFoundationTier then
		local name = BuildRules.FLOOR_NAMES[def.minFoundationTier] or "better"
		return `Needs a {name} floor`
	elseif reason == "locked" and def.unlock and quests then
		return Unlocks.text(def.unlock, { items = items, quests = quests }) or base
	elseif reason == "limit" and defs then
		local limit = chainLimit(def.id, defs)
		if limit then
			return `Plot limit reached ({limit} per plot)`
		end
	end
	return base
end

-- "Timber 12/8 · Stone 2/5": a cost with what the player has against what it needs.
function BuildRules.costText(
	cost: { Types.ItemStack },
	inventory: Types.Inventory?,
	items: { [string]: { name: string } }
): string
	local parts: { string } = {}
	for _, stack in cost do
		local item = items[stack.itemId]
		local name = if item then item.name else stack.itemId
		if inventory then
			table.insert(parts, `{name} {Inventory.count(inventory, stack.itemId)}/{stack.count}`)
		else
			table.insert(parts, `{stack.count} {name}`)
		end
	end
	return table.concat(parts, ", ")
end

return BuildRules
