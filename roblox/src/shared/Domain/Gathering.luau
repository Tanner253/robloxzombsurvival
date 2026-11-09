--!strict
--[[
	Gathering: resource node hits, tool checks, yields and respawn (Data/Nodes).
	Pure; pass `now` and an Rng source in.

	A node instance is { hitsLeft, respawnAt }. Each hit yields every
	NodeYield.perHit (rolling `chance` when set; on tier-2 nodes only every yieldEvery-th
	hit yields) and wears the tool by Tuning.gathering.durabilityPerHit. The last hit depletes the node until
	`respawnAt`; `refresh` brings it back once that time has passed. Home nodes are
	finite (LDOE_PARITY #30): their last hit sets respawnAt to Gathering.NEVER and
	they stay depleted for good.

	Tool choice: the carried tool (pockets or backpack) with the highest tier that
	can harvest the node (LDoE's context button that switches to the axe).
]]

local Types = require("../Types")
local Rng = require("./Rng")

local Gathering = {}

-- respawnAt for a node that never comes back (home nodes, LDOE_PARITY #30).
Gathering.NEVER = -1

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

local function due(node: Node, now: number): boolean
	return node.respawnAt ~= Gathering.NEVER and now >= node.respawnAt
end

-- True while the node can be hit (standing, or its respawn time has passed).
function Gathering.isStanding(node: Node, now: number): boolean
	return node.hitsLeft > 0 or due(node, now)
end

-- The node with its respawn applied if due.
function Gathering.refresh(node: Node, def: Types.ResourceNodeDef, now: number): Node
	if node.hitsLeft <= 0 and due(node, now) then
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
	Whether the hit that finds the node at `hitsLeft` yields (ResourceNodeDef.yieldEvery,
	ECONOMY §11.1): only every yieldEvery-th hit does, counting from the first, so a 4-hit
	Ironbark with yieldEvery 2 gives a log on hits 2 and 4. XP is still paid on every hit.
]]
function Gathering.yieldsOnHit(def: Types.ResourceNodeDef, hitsLeft: number): boolean
	local every = def.yieldEvery or 1
	return (def.hits - hitsLeft + 1) % every == 0
end

-- Units of each item one whole node gives (chance yields at their expected value).
function Gathering.expectedYield(def: Types.ResourceNodeDef): { [Types.ItemId]: number }
	local yielding = def.hits // (def.yieldEvery or 1)
	local result: { [Types.ItemId]: number } = {}
	for _, entry in def.yields do
		result[entry.itemId] = (result[entry.itemId] or 0) + entry.perHit * (entry.chance or 1) * yielding
	end
	return result
end

--[[
	One hit. Returns the new node state, what it yielded and whether this hit
	depleted it, or nil, {}, false and "depleted" when it is not standing.
]]
-- `respawnSeconds` overrides the def's respawn; Gathering.NEVER makes the node finite
-- (home nodes: depleted for good).
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
	if Gathering.yieldsOnHit(def, current.hitsLeft) then
		for _, entry in def.yields do
			if entry.chance == nil or rng:NextNumber() < entry.chance then
				table.insert(yields, { itemId = entry.itemId, count = entry.perHit })
			end
		end
	end
	local hitsLeft = current.hitsLeft - 1
	local depleted = hitsLeft <= 0
	return {
		hitsLeft = hitsLeft,
		respawnAt = if not depleted
			then 0
			elseif respawnSeconds == Gathering.NEVER then Gathering.NEVER
			else now + (respawnSeconds or def.respawnSeconds),
	},
		yields,
		depleted,
		nil
end

-- A saved node (home nodes persist per outpost): nil when the node is whole, so only
-- hit or depleted nodes take space. Stamps are real Unix seconds (os.time).
export type Saved = { hitsLeft: number, respawnAt: number }

function Gathering.toSave(node: Node, def: Types.ResourceNodeDef): Saved?
	if node.hitsLeft >= def.hits then
		return nil
	end
	return { hitsLeft = node.hitsLeft, respawnAt = node.respawnAt }
end

-- The node a save describes at `now`: whole when nothing was saved or its respawn has
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

-- The respawn a home node gets on depletion: never, unless Tuning.home.renewing lists it
-- (water sources), in which case its own respawnSeconds.
function Gathering.homeRespawn(nodeId: Types.NodeId, renewing: { Types.NodeId }): number?
	return if table.find(renewing, nodeId) then nil else Gathering.NEVER
end

return Gathering
