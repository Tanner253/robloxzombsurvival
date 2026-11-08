--!strict
--[[
	Gathering: resource nodes on the home plot (Domain/Gathering; M1 step 2).

	When a plot is claimed, Tuning.home.nodes are scattered in the ring around
	its build grid (seeded per plot, so a plot always grows the same way). Only
	the owner gathers their home nodes. Each Gather request is one swing: the
	server checks reach, the swing cooldown (Tuning.gathering.swingSeconds), the
	tool (Domain/Gathering.pickTool) and bag space, then yields items and XP and
	wears the tool. Home nodes are finite (LDOE_PARITY #30): once depleted they stay
	down for good (only Tuning.home.renewing, the spring, refills). They are saved per
	outpost (OutpostSchema `nodes`, keyed "<nodeId>#<n>"), so a restart or rejoin never
	refills them. The plot's layout is seeded by the owner, so their home grows the
	same way on whichever plot they get.

	Node models carry attributes for the client: NodeKey, NodeId, Standing,
	HitsLeft, Hits and OwnerUserId, and the "EO_Node" tag.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local Types = require(ReplicatedStorage.Shared.Types)
local GatheringMath = require(ReplicatedStorage.Shared.Domain.Gathering)
local Rng = require(ReplicatedStorage.Shared.Domain.Rng)
local Slots = require(ReplicatedStorage.Shared.Domain.Slots)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local Net = require("../Net")
local Events = require("../Events")
local Models = require("../World/Models")
local Analytics = require("./Analytics")
local Drops = require("./Drops")
local Inventory = require("./Inventory")
local Plots = require("./Plots")
local Progression = require("./Progression")
local Sync = require("./Sync")

local Gathering = {}

Gathering.TAG = "EO_Node"

type Node = {
	key: string,
	saveKey: string, -- "<nodeId>#<n>": the key in the outpost's saved nodes
	def: Types.ResourceNodeDef,
	state: GatheringMath.Node,
	model: Model,
	position: Vector3,
	radius: number,
	plot: Plots.Plot,
	-- The stump or rubble shown while the node is down: each part's authored transparency.
	remnant: { [BasePart]: number }?,
}

local tuning = Content.Tuning
local GRID_STUDS = tuning.building.plotCells * Grid.CELL_STUDS
-- Swings may arrive a little early because of network jitter.
local COOLDOWN_TOLERANCE = 0.85
-- Keep nodes this far from the build grid and from each other.
local GRID_APRON = 4
local SPACING = 7
-- The walkway from the road into the plot stays clear.
local PATH_HALF_WIDTH = 10
-- After the last swing, the previous hand item comes back after this long.
local LOW_DURABILITY = 0.15 -- warn when a tool's durability falls to this fraction
local SWAP_BACK_SECONDS = 2.5
local ACTION_BY_TOOL: { [string]: string } = { hatchet = "chop", pick = "mine", hand = "pickup" }
-- Analytics: gathered totals are sent per player at most this often.
local ANALYTICS_SECONDS = 60

local nodes: { [string]: Node } = {}
local saveNode: (player: Player, node: Node) -> ()
local lastSwing: { [Player]: number } = {}
local gathered: { [Player]: { [string]: number } } = {}
local rng = Rng.new(Random.new():NextInteger(1, 2 ^ 31 - 2))

-- Node attributes --------------------------------------------------------------------------------

local function setStanding(node: Node, standing: boolean)
	node.model:SetAttribute("Standing", standing)
	if node.remnant then
		for part, transparency in node.remnant do
			part.Transparency = if standing then 1 else transparency
		end
	end
	node.model:SetAttribute("HitsLeft", if standing then node.state.hitsLeft else 0)
	for _, descendant in node.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- Only the footprint collider blocks movement (World/Models).
			if descendant.Name == "Collider" then
				descendant.CanCollide = standing
			else
				descendant.CanQuery = standing
			end
		end
	end
end

-- Spawning -----------------------------------------------------------------------------------------

local function groundAt(plot: Plots.Plot, x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { plot.nodes, plot.pieces }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local top = Vector3.new(x, plot.origin.Y + 60, z)
	local hit = workspace:Raycast(top, Vector3.new(0, -140, 0), params)
	return if hit then hit.Position.Y else plot.origin.Y
end

local function spotFor(plot: Plots.Plot, random: Random, taken: { Vector2 }, spacing: number): Vector2?
	local margin = tuning.plots.marginStuds
	local low, high = -margin + 3, GRID_STUDS + margin - 3
	for _ = 1, 200 do
		local x = random:NextNumber(low, high)
		local z = random:NextNumber(low, high)
		local insideGrid = x > -GRID_APRON
			and x < GRID_STUDS + GRID_APRON
			and z > -GRID_APRON
			and z < GRID_STUDS + GRID_APRON
		local onFront = if plot.front > 0 then z > GRID_STUDS else z < 0
		local onPath = onFront and math.abs(x - GRID_STUDS / 2) < PATH_HALF_WIDTH
		if not insideGrid and not onPath then
			local spot = Vector2.new(x, z)
			local clear = true
			for _, other in taken do
				if (other - spot).Magnitude < spacing then
					clear = false
					break
				end
			end
			if clear then
				return spot
			end
		end
	end
	return nil
end

local function spawnNodes(player: Player, plot: Plots.Plot)
	local random = Random.new(player.UserId % 2147483000 + 7919)
	local taken: { Vector2 } = {}
	local outpost = Plots.outpost(player)
	local saved = if outpost then outpost.nodes else {}
	local stamp = os.time()
	for _, entry in tuning.home.nodes do
		local def = Content.Nodes[entry.nodeId]
		if not Art.nodeReady(entry.nodeId) then
			continue -- no approved model yet: the node doesn't appear (checklist §0)
		end
		for index = 1, entry.count do
			local spacing = if def.tool and def.tool.kind == "hatchet" then SPACING + 3 else SPACING
			local spot = spotFor(plot, random, taken, spacing)
			if spot then
				table.insert(taken, spot)
				-- The save key is the node's type and number; the live key adds the owner.
				local saveKey = `{def.id}#{index}`
				local key = `{player.UserId}:{saveKey}`
				local model = Models.node(def, random) :: Model
				local wx, wz = plot.origin.X + spot.X, plot.origin.Z + spot.Y
				local y = groundAt(plot, wx, wz)
				local scale = 0.88 + random:NextNumber() * 0.24
				model:ScaleTo(model:GetScale() * scale)
				local position = Vector3.new(wx, y, wz)
				model:PivotTo(CFrame.new(position) * CFrame.Angles(0, random:NextNumber() * math.pi * 2, 0))
				local size = model:GetExtentsSize()
				model:SetAttribute("NodeKey", key)
				model:SetAttribute("NodeId", def.id)
				model:SetAttribute("Hits", def.hits)
				model:SetAttribute("OwnerUserId", player.UserId)
				CollectionService:AddTag(model, Gathering.TAG)
				local node: Node = {
					key = key,
					def = def,
					saveKey = saveKey,
					state = GatheringMath.fromSave(saved[saveKey], def, stamp),
					model = model,
					position = position,
					radius = math.max(size.X, size.Z) / 2,
					plot = plot,
				}
				local remnant = Models.remnant(def.id)
				if remnant then
					local parts: { [BasePart]: number } = {}
					for _, descendant in remnant:GetDescendants() do
						if descendant:IsA("BasePart") then
							parts[descendant] = descendant.Transparency
						end
					end
					remnant:ScaleTo(remnant:GetScale() * scale)
					remnant:PivotTo(CFrame.new(position) * CFrame.Angles(0, random:NextNumber() * math.pi * 2, 0))
					remnant.Name = `{key}_remnant`
					remnant.Parent = plot.nodes
					node.remnant = parts
				end
				setStanding(node, GatheringMath.isStanding(node.state, stamp) and node.state.hitsLeft > 0)
				model:SetAttribute("HitsLeft", node.state.hitsLeft)
				model.Parent = plot.nodes
				nodes[key] = node
			end
		end
	end
end

-- Records a home node's state on the outpost (nothing while it is whole).
saveNode = function(player: Player, node: Node)
	local outpost = Plots.outpost(player)
	if outpost == nil then
		return
	end
	(outpost.nodes :: any)[node.saveKey] = GatheringMath.toSave(node.state, node.def)
end

local function clearNodes(plot: Plots.Plot)
	for key, node in nodes do
		if node.plot == plot then
			nodes[key] = nil
		end
	end
	plot.nodes:ClearAllChildren()
end

-- Analytics ------------------------------------------------------------------------------------------

local function flushAnalytics(player: Player)
	local totals = gathered[player]
	if totals == nil then
		return
	end
	gathered[player] = nil
	local view = Inventory.view(player)
	for itemId, count in totals do
		local balance = 0
		if view then
			for _, slot in view.pockets do
				balance += if slot.itemId == itemId then slot.count else 0
			end
			for _, slot in view.backpack do
				balance += if slot.itemId == itemId then slot.count else 0
			end
		end
		Analytics.economy(player, "source", itemId, count, balance, "Gathering")
	end
end

-- Toolnames for the "needs a tool" notice.
local function toolName(kind: string, tier: number): string
	for _, def in Content.Items do
		if def.tool and def.tool.kind == kind and def.tool.tier >= tier then
			return def.name
		end
	end
	return kind
end

-- Swing -------------------------------------------------------------------------------------------------

local function gather(player: Player, key: string)
	local node = nodes[key]
	if node == nil or node.plot.owner ~= player then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now - (lastSwing[player] or 0) < tuning.gathering.swingSeconds * COOLDOWN_TOLERANCE then
		return
	end
	if not Plots.withinArm(player, node.position, node.radius) then
		return
	end
	local stamp = os.time()
	if not GatheringMath.isStanding(node.state, stamp) then
		return
	end
	local view = Inventory.view(player)
	if view == nil then
		return
	end
	local toolRef, reason = GatheringMath.pickTool(node.def, view, Content.Items :: any)
	if toolRef == nil then
		local needed = node.def.tool :: Types.ToolStats
		local name = toolName(needed.kind, needed.tier)
		Sync.notice(player, if reason == "toolTier" then `Needs a better {name}` else `Needs a {name}`)
		Sync.fx(player, "gatherDenied", { key = key, reason = reason })
		return
	end
	lastSwing[player] = now
	local respawn = GatheringMath.homeRespawn(node.def.id, tuning.home.renewing)
	local nextState, yields, depleted = GatheringMath.hit(node.state, node.def, rng, stamp, respawn)
	if nextState == nil then
		return
	end
	node.state = nextState
	saveNode(player, node)
	local given, leftover = Inventory.give(player, yields)
	if #leftover > 0 then
		-- Bag full: the rest lands beside the node as a bag to pick up later (LDoE).
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local from = if root then root.Position else node.position + Vector3.xAxis
		local away = (node.position - from) * Vector3.new(1, 0, 1)
		local spot = node.position - (if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis) * (node.radius + 1.5)
		Drops.spawn(player, spot, leftover :: any)
		Sync.notice(player, "Your bag is full. The rest dropped on the ground.")
		Sync.fx(player, "bagFull", { key = key })
	end
	local totals = gathered[player] or {}
	gathered[player] = totals
	for _, stack in given do
		totals[stack.itemId] = (totals[stack.itemId] or 0) + stack.count
	end

	local toolItem = ""
	local broke = false
	-- Swap to the tool (or empty hands for a pickup), then back after a short idle.
	Inventory.holdForAction(player, toolRef, SWAP_BACK_SECONDS)
	Net.fireAllClients(
		"Fx",
		"act",
		{ userId = player.UserId, action = ACTION_BY_TOOL[if node.def.tool then node.def.tool.kind else "hand"] }
	)
	local toolSlot = if toolRef ~= "" then Inventory.slotAt(player, toolRef) else nil
	if toolSlot then
		local slot = toolSlot
		toolItem = slot.itemId
		local worn, didBreak = Slots.wear(slot, tuning.gathering.durabilityPerHit)
		broke = didBreak
		Inventory.setAt(player, toolRef, worn)
		local def = Content.Items[toolItem]
		local max = if def then def.durability else nil
		if broke then
			Sync.notice(player, `Your {def.name} broke`)
		elseif max and slot.durability and worn.durability then
			-- One warning as the tool crosses into its last hits.
			local warnAt = max * LOW_DURABILITY
			if slot.durability > warnAt and worn.durability <= warnAt then
				Sync.notice(player, `Your {def.name} is about to break`, "warn")
			end
		end
	end

	if depleted then
		setStanding(node, false)
	else
		node.model:SetAttribute("HitsLeft", node.state.hitsLeft)
	end
	Progression.grantXp(player, node.def.xpPerHit, "Gathering")
	for _, stack in given do
		Events.played:Fire(player, { kind = "gather", itemId = stack.itemId, count = stack.count })
	end
	Sync.fx(player, "gather", {
		key = key,
		nodeId = node.def.id,
		items = given,
		xp = node.def.xpPerHit,
		depleted = depleted,
		tool = toolItem,
		broke = broke,
	})
end

-- Lifecycle ------------------------------------------------------------------------------------------------

function Gathering.init()
	Net.onEvent("Gather", gather)
end

function Gathering.start()
	Plots.claimed:Connect(spawnNodes)
	Plots.releasing:Connect(function(player: Player, plot: Plots.Plot)
		flushAnalytics(player)
		clearNodes(plot)
		lastSwing[player] = nil
	end)
	task.spawn(function()
		local sinceAnalytics = 0
		while true do
			task.wait(1)
			local stamp = os.time()
			for _, node in nodes do
				if node.state.hitsLeft <= 0 and GatheringMath.isStanding(node.state, stamp) then
					node.state = GatheringMath.refresh(node.state, node.def, stamp)
					setStanding(node, true)
					if node.plot.owner then
						saveNode(node.plot.owner, node)
					end
				end
			end
			sinceAnalytics += 1
			if sinceAnalytics >= ANALYTICS_SECONDS then
				sinceAnalytics = 0
				for player in gathered do
					flushAnalytics(player)
				end
			end
		end
	end)
end

return Gathering
