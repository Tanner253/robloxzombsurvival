--!strict
--[[
	Gathering: resource node hits, tool checks, yields and respawn (Data/Nodes).
	Pure; pass `now` and an Rng source in.

	A node instance is { hitsLeft, respawnAt }. Each hit yields every
	NodeYield.perHit (rolling `chance` when set) and wears the tool by
	Tuning.gathering.durabilityPerHit. The last hit depletes the node until
	`respawnAt`; `refresh` brings it back once that time has passed.

	Tool choice: the carried tool (pockets or backpack) with the highest tier that
	can harvest the node (LDoE's context button that switches to the axe).
]]

local Types = require("../Types")
local Rng = require("./Rng")

local Gathering = {}

export type Node = {
	hitsLeft: number,
	respawnAt: number, -- 0 while standing
}

export type Reason = "depleted" | "needsTool" | "toolTier"

-- The item fields Gathering needs; Data/Items satisfies this.
export type ItemLookup = { [string]: { tool: Types.ToolStats? } }

function Gathering.new(def: Types.ResourceNodeDef): Node
	return { hitsLeft = def.hits, respawnAt = 0 }
end

-- True while the node can be hit (standing, or its respawn time has passed).
function Gathering.isStanding(node: Node, now: number): boolean
	return node.hitsLeft > 0 or now >= node.respawnAt
end

-- The node with its respawn applied if due.
function Gathering.refresh(node: Node, def: Types.ResourceNodeDef, now: number): Node
	if node.hitsLeft <= 0 and now >= node.respawnAt then
		return Gathering.new(def)
	end
	return { hitsLeft = node.hitsLeft, respawnAt = node.respawnAt }
end

-- Whether a tool (or bare hands, with nil) can harvest the node.
function Gathering.canHarvest(def: Types.ResourceNodeDef, tool: Types.ToolStats?): (boolean, Reason?)
	local needed = def.tool
	if needed == nil then
		return true, nil
	end
	if tool == nil or tool.kind ~= needed.kind then
		return false, "needsTool"
	end
	if tool.tier < needed.tier then
		return false, "toolTier"
	end
	return true, nil
end

--[[
	The tool to use, as a slot ref: "" when the node needs no tool (bare hands), else
	"p<i>" (pockets) or "b<i>" (backpack) for the best-tier tool that can harvest it.
	Tools never take a weapon slot (4.9): they are found in the bag and only held while
	working. Returns nil and a reason when nothing carried can harvest it.
]]
function Gathering.pickTool(
	def: Types.ResourceNodeDef,
	carried: { pockets: Types.Container, backpack: Types.Container },
	items: ItemLookup
): (string?, Reason?)
	if def.tool == nil then
		return "", nil
	end
	local best: string? = nil
	local bestTier = -1
	local reason: Reason = "needsTool"
	local groups: { { prefix: string, slots: Types.Container } } = {
		{ prefix = "p", slots = carried.pockets },
		{ prefix = "b", slots = carried.backpack or {} },
	}
	for _, group in groups do
		local prefix = group.prefix
		for index, slot in group.slots do
			local item = if slot.count > 0 then items[slot.itemId] else nil
			local tool = if item then item.tool else nil
			local ok, why = Gathering.canHarvest(def, tool)
			if ok and tool and tool.tier > bestTier then
				best, bestTier = `{prefix}{index}`, tool.tier
			elseif why == "toolTier" then
				reason = "toolTier"
			end
		end
	end
	if best then
		return best, nil
	end
	return nil, reason
end

--[[
	One hit. Returns the new node state, what it yielded and whether this hit
	depleted it, or nil, {}, false and "depleted" when it is not standing.
]]
-- `respawnSeconds` overrides the def's respawn (home nodes regrow on Tuning.home.regrowHours).
function Gathering.hit(
	node: Node,
	def: Types.ResourceNodeDef,
	rng: Rng.Source,
	now: number,
	respawnSeconds: number?
): (Node?, { Types.ItemStack }, boolean, Reason?)
	local current = Gathering.refresh(node, def, now)
	if current.hitsLeft <= 0 then
		return nil, {}, false, "depleted"
	end
	local yields: { Types.ItemStack } = {}
	for _, entry in def.yields do
		if entry.chance == nil or rng:NextNumber() < entry.chance then
			table.insert(yields, { itemId = entry.itemId, count = entry.perHit })
		end
	end
	local hitsLeft = current.hitsLeft - 1
	local depleted = hitsLeft <= 0
	return {
		hitsLeft = hitsLeft,
		respawnAt = if depleted then now + (respawnSeconds or def.respawnSeconds) else 0,
	},
		yields,
		depleted,
		nil
end

-- A saved node (home nodes persist per player): nil when the node is whole, so only
-- hit or depleted nodes take space. Stamps are real Unix seconds (os.time).
export type Saved = { hitsLeft: number, respawnAt: number }

function Gathering.toSave(node: Node, def: Types.ResourceNodeDef): Saved?
	if node.hitsLeft >= def.hits then
		return nil
	end
	return { hitsLeft = node.hitsLeft, respawnAt = node.respawnAt }
end

-- The node a save describes at `now`: whole when nothing was saved or its regrowth has
-- passed, else exactly as saved (a restart or rejoin never refills it).
function Gathering.fromSave(saved: Saved?, def: Types.ResourceNodeDef, now: number): Node
	if type(saved) ~= "table" or type(saved.hitsLeft) ~= "number" or type(saved.respawnAt) ~= "number" then
		return Gathering.new(def)
	end
	return Gathering.refresh(
		{ hitsLeft = math.clamp(saved.hitsLeft, 0, def.hits), respawnAt = saved.respawnAt },
		def,
		now
	)
end

-- A regrow time in seconds within a span of real hours.
function Gathering.regrowSeconds(span: { min: number, max: number }?, roll: number): number?
	if span == nil then
		return nil
	end
	return math.floor((span.min + (span.max - span.min) * math.clamp(roll, 0, 1)) * 3600)
end

return Gathering
