--!strict
--[[
	Gathering: resource node hits, tool checks, yields and respawn (Data/Nodes).
	Pure; pass `now` and an Rng source in.

	A node instance is { hitsLeft, respawnAt }. Each hit yields every
	NodeYield.perHit (rolling `chance` when set) and wears the tool by
	Tuning.gathering.durabilityPerHit. The last hit depletes the node until
	`respawnAt`; `refresh` brings it back once that time has passed.

	Tool choice: the held pocket slot when it can harvest the node, otherwise the
	pocket tool with the highest tier that can (LDoE's context button that
	switches to the axe). Tools work from the pockets (hotbar) only.
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
	The pocket index of the tool to use: 0 when the node needs no tool, the held
	slot when it works, else the best suitable pocket tool. Returns nil and a
	reason when nothing in the pockets can harvest it.
]]
function Gathering.pickTool(
	def: Types.ResourceNodeDef,
	pockets: Types.Container,
	heldIndex: number,
	items: ItemLookup
): (number?, Reason?)
	if def.tool == nil then
		return 0, nil
	end
	local function stats(index: number): Types.ToolStats?
		local slot = pockets[index]
		if slot == nil or slot.count <= 0 then
			return nil
		end
		local item = items[slot.itemId]
		return if item then item.tool else nil
	end
	if heldIndex > 0 and (Gathering.canHarvest(def, stats(heldIndex))) then
		return heldIndex, nil
	end
	local best: number? = nil
	local bestTier = -1
	local reason: Reason = "needsTool"
	for index in pockets do
		local tool = stats(index)
		local ok, why = Gathering.canHarvest(def, tool)
		if ok and tool and tool.tier > bestTier then
			best, bestTier = index, tool.tier
		elseif why == "toolTier" then
			reason = "toolTier"
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
function Gathering.hit(
	node: Node,
	def: Types.ResourceNodeDef,
	rng: Rng.Source,
	now: number
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
		respawnAt = if depleted then now + def.respawnSeconds else 0,
	},
		yields,
		depleted,
		nil
end

return Gathering
