--!strict
--[[
	Interaction: what the player is about to use, and using it.

	Ten times a second it picks a target: the node, station, crate or pickup under
	the mouse when it is within arm's reach (Tuning.interaction.reachStuds from its
	edge, checklist 3.11), otherwise the nearest one in reach. The HUD's prompt and
	highlight draw State.ui().target, so they only show in reach. `activate` (E, or the
	touch action button) opens a station or crate, picks up, or swings at a node; on
	something farther away it walks there first (pathfinding) and then uses it.
	Holding the gather button (LMB, or holding the touch button) keeps swinging every
	Tuning.gathering.swingSeconds; auto-gather stops at arm's reach before it swings.
	The server checks the same reach and rejects anything out of range.
]]

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Content = require(ReplicatedStorage.Shared.Data)
local GatheringMath = require(ReplicatedStorage.Shared.Domain.Gathering)
local InventoryMath = require(ReplicatedStorage.Shared.Domain.Inventory)
local Net = require("../Net")
local Animations = require("./Animations")
local State = require("../State")

local Interaction = {}

local tuning = Content.Tuning
local TAGS: { [string]: string } =
	{ node = "EO_Node", station = "EO_Station", storage = "EO_Storage", drop = "EO_Drop" }
local SCAN_SECONDS = 0.1
local VERB: { [string]: string } = { hatchet = "Chop", pick = "Mine" }

-- Auto-gather (LDoE's context button and AUTO): holding the gather button walks
-- to the nearest node within HOLD_RADIUS; AUTO keeps going within AUTO_RADIUS.
local HOLD_RADIUS = 28
local AUTO_RADIUS = 180 -- the whole home plot ring
local WALK_REFRESH = 0.35

local player = Players.LocalPlayer
local gathering = false
local walkTarget: Model? = nil
local lastWalk = 0
-- Stuck guard: a goal the survivor can't reach is skipped for SKIP_SECONDS.
local STUCK_SECONDS = 1.5
local SKIP_SECONDS = 8
local skipped: { [Model]: number } = {}
local progressAt = 0
local progressPos: Vector3? = nil
local lastSwing = 0
local scanElapsed = 0

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function describe(model: Model, kind: string): State.Target?
	if kind == "node" then
		if model:GetAttribute("Standing") ~= true or model:GetAttribute("OwnerUserId") ~= player.UserId then
			return nil
		end
		local def = Content.Nodes[model:GetAttribute("NodeId") :: string]
		if def == nil then
			return nil
		end
		return {
			kind = "node",
			key = model:GetAttribute("NodeKey") :: string,
			label = def.name,
			verb = if def.tool then VERB[def.tool.kind] or "Gather" else "Gather",
			model = model,
			hitsLeft = model:GetAttribute("HitsLeft") :: number?,
			hits = def.hits,
		}
	end
	if model:GetAttribute("OwnerUserId") ~= player.UserId then
		return nil
	end
	if kind == "drop" then
		return {
			kind = "drop",
			key = model:GetAttribute("DropId") :: string,
			label = (model:GetAttribute("Label") :: string?) or "Dropped items",
			verb = "Pick up",
			model = model,
		}
	end
	local piece = Content.BuildPieces[model:GetAttribute("PieceId") :: string]
	if piece == nil then
		return nil
	end
	return {
		kind = kind :: any,
		key = model:GetAttribute("Uid") :: string,
		label = piece.name,
		verb = "Open",
		model = model,
	}
end

-- Arm's reach to a model's centre: the reach from its edge plus its footprint radius.
local function reachFor(_kind: string, model: Model): number
	local size = model:GetExtentsSize()
	return tuning.interaction.reachStuds + math.max(size.X, size.Z) / 2
end

local function taggedAncestor(instance: Instance?): (Model?, string?)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") then
			for kind, tag in TAGS do
				if CollectionService:HasTag(current, tag) then
					return current, kind
				end
			end
		end
		current = current.Parent
	end
	return nil, nil
end

local function underMouse(): (Model?, string?)
	if State.ui().touch then
		return nil, nil
	end
	local camera = workspace.CurrentCamera
	local world = workspace:FindFirstChild("World")
	if camera == nil or world == nil then
		return nil, nil
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	return taggedAncestor(if hit then hit.Instance else nil)
end

local function scan()
	local here = root()
	local ui = State.ui()
	if here == nil or ui.panel == "build" then
		if ui.target then
			State.clear("target")
		end
		return
	end
	local best: State.Target? = nil
	local hovered, hoveredKind = underMouse()
	if
		hovered
		and hoveredKind
		and flat(hovered:GetPivot().Position, here.Position) <= reachFor(hoveredKind, hovered)
	then
		best = describe(hovered, hoveredKind)
	end
	if best == nil then
		local bestDistance = math.huge
		for kind, tag in TAGS do
			for _, instance in CollectionService:GetTagged(tag) do
				if instance:IsA("Model") and instance:IsDescendantOf(workspace) then
					local distance = flat(instance:GetPivot().Position, here.Position)
					if distance <= reachFor(kind, instance) and distance < bestDistance then
						local described = describe(instance, kind)
						if described then
							best, bestDistance = described, distance
						end
					end
				end
			end
		end
	end
	local current = ui.target
	if best == nil then
		if current then
			State.clear("target")
		end
	elseif current == nil or current.key ~= best.key or current.hitsLeft ~= best.hitsLeft then
		State.patch({ target = best })
	end
end

-- Swings ---------------------------------------------------------------------------------------

local function face(position: Vector3)
	local here = root()
	if here then
		local look = Vector3.new(position.X, here.Position.Y, position.Z)
		if (look - here.Position).Magnitude > 0.1 then
			here.CFrame = CFrame.lookAt(here.Position, look)
		end
	end
end

-- One swing at a node model (throttled to the swing time).
local function swingAt(model: Model): boolean
	local key = model:GetAttribute("NodeKey")
	if type(key) ~= "string" then
		return false
	end
	local now = os.clock()
	if now - lastSwing < tuning.gathering.swingSeconds then
		return true
	end
	lastSwing = now
	face(model:GetPivot().Position)
	-- Chop, mine or pick up; the request goes out on the hit frame so the impact,
	-- chips and sound land with the blow (3.2, 3.3).
	local def = Content.Nodes[model:GetAttribute("NodeId") :: string]
	local action = Animations.forTool(if def and def.tool then def.tool.kind else nil)
	local hitIn = Animations.play(player.Character, action)
	task.delay(hitIn, function()
		Net.fire("Gather", key)
		State.fx:Fire("swing", { key = key, model = model })
	end)
	return true
end

local function swing(): boolean
	local target = State.ui().target
	if target == nil or target.kind ~= "node" then
		return false
	end
	return swingAt(target.model)
end

-- Auto-gather ---------------------------------------------------------------------------------

local Items: any = Content.Items

-- Whether this client could harvest `model` now: own standing node, a tool in
-- the pockets if it needs one, and room for its sure yields. Same Domain rules
-- as the server, so auto never walks to something it can't take.
local function harvestable(model: Model): boolean
	if model:GetAttribute("Standing") ~= true or model:GetAttribute("OwnerUserId") ~= player.UserId then
		return false
	end
	local def = Content.Nodes[model:GetAttribute("NodeId") :: string]
	local inventory = State.get("inventory")
	if def == nil or not inventory then
		return false
	end
	if GatheringMath.pickTool(def, { pockets = inventory.pockets, backpack = inventory.backpack }, Items) == nil then
		return false
	end
	local view = { pockets = inventory.pockets, backpack = inventory.backpack }
	for _, entry in def.yields do
		if entry.chance == nil and InventoryMath.spaceFor(view, entry.itemId, Items) < entry.perHit then
			return false
		end
	end
	return true
end

local function nearestHarvestable(radius: number): Model?
	local here = root()
	if here == nil then
		return nil
	end
	local best: Model? = nil
	local bestDistance = radius
	local now = os.clock()
	for _, instance in CollectionService:GetTagged(TAGS.node) do
		local skipUntil = skipped[instance :: any]
		if skipUntil and now < skipUntil then
			continue
		end
		if instance:IsA("Model") and instance:IsDescendantOf(workspace) then
			local distance = flat(instance:GetPivot().Position, here.Position)
			if distance < bestDistance and harvestable(instance) then
				best, bestDistance = instance, distance
			end
		end
	end
	return best
end

local function stopWalking()
	if walkTarget then
		walkTarget = nil
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local here = root()
		if humanoid and here then
			humanoid:MoveTo(here.Position)
		end
	end
end

function Interaction.setAuto(on: boolean)
	if State.ui().auto ~= on then
		State.patch({ auto = on })
	end
	if not on then
		stopWalking()
	end
end

-- One step of gathering while the button is held or AUTO is on: swing at the
-- goal node when it's in reach, otherwise walk to it. The goal is the prompt's
-- target when that can be harvested, else the nearest node that can.
local function autoStep()
	local ui = State.ui()
	local target = ui.target
	local here = root()
	if here == nil then
		return
	end
	local current = walkTarget
	if current and not harvestable(current) then
		current = nil
	end
	if current == nil and target and target.kind == "node" and harvestable(target.model) then
		current = target.model
	end
	if current and flat(current:GetPivot().Position, here.Position) <= reachFor("node", current) then
		walkTarget = current
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:MoveTo(here.Position)
		end
		swingAt(current)
		return
	end
	local now = os.clock()
	-- Stuck guard: no progress toward the goal for a while means skip it.
	if walkTarget and progressPos then
		if (here.Position - progressPos).Magnitude > 1 then
			progressPos, progressAt = here.Position, now
		elseif now - progressAt > STUCK_SECONDS then
			skipped[walkTarget] = now + SKIP_SECONDS
			walkTarget = nil
			current = nil
			progressPos = nil
		end
	end
	if now - lastWalk < WALK_REFRESH then
		return
	end
	lastWalk = now
	local goal = current or nearestHarvestable(if ui.auto then AUTO_RADIUS else HOLD_RADIUS)
	if goal == nil and next(skipped) ~= nil then
		-- Give the nodes we couldn't reach one more try before stopping.
		table.clear(skipped)
		goal = nearestHarvestable(if ui.auto then AUTO_RADIUS else HOLD_RADIUS)
	end
	if goal == nil then
		stopWalking()
		if ui.auto then
			Interaction.setAuto(false)
			State.notify("Nothing left to gather nearby", "info")
		elseif target and target.kind == "node" then
			swing() -- let the server say why (needs a tool, bag full)
		end
		return
	end
	if walkTarget ~= goal then
		progressPos, progressAt = here.Position, now
	end
	walkTarget = goal
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local at = goal:GetPivot().Position
		local away = Vector3.new(here.Position.X - at.X, 0, here.Position.Z - at.Z)
		local size = goal:GetExtentsSize()
		local stand = math.max(size.X, size.Z) / 2 + 2
		local offset = if away.Magnitude > 0.1 then away.Unit * stand else Vector3.new(stand, 0, 0)
		humanoid:MoveTo(at + offset)
	end
end

-- Approach-and-use (3.11): walk to something out of reach along a path, then use it.
type Approach = { model: Model, kind: string, waypoints: { Vector3 }, step: number, startedAt: number }
local approach: Approach? = nil
local APPROACH_GIVE_UP = 12 -- seconds
local APPROACH_RADIUS = 80 -- how far E or a click will walk to something
local MOVE_KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D }

local function humanoidOf(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function Interaction.cancelApproach()
	if approach then
		approach = nil
		local humanoid, here = humanoidOf(), root()
		if humanoid and here then
			humanoid:MoveTo(here.Position)
		end
	end
end

-- Uses a described target now (it is in reach).
local function use(target: State.Target)
	if target.kind == "station" then
		State.toggle("station", target.key)
	elseif target.kind == "drop" then
		Net.fire("PickupDrop", target.key)
	elseif target.kind == "storage" then
		Net.fire("StorageOpen", target.key)
		if State.ui().panel ~= "inventory" then
			State.toggle("inventory")
		end
	else
		swingAt(target.model)
	end
end

-- Starts walking to `model` (a stand point at its edge), along a path when one exists.
local function startApproach(model: Model, kind: string)
	local here = root()
	if here == nil then
		return
	end
	local at = model:GetPivot().Position
	local size = model:GetExtentsSize()
	local away = Vector3.new(here.Position.X - at.X, 0, here.Position.Z - at.Z)
	local stand = math.max(size.X, size.Z) / 2 + tuning.interaction.reachStuds * 0.5
	local goal = at + (if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis) * stand
	local waypoints = { goal }
	local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5.5, AgentCanJump = false })
	local ok = pcall(function()
		path:ComputeAsync(here.Position, goal)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		waypoints = {}
		for _, point in path:GetWaypoints() do
			table.insert(waypoints, point.Position)
		end
	end
	approach = { model = model, kind = kind, waypoints = waypoints, step = 1, startedAt = os.clock() }
end

local function approachStep()
	local current = approach
	local here = root()
	local humanoid = humanoidOf()
	if current == nil or here == nil or humanoid == nil then
		return
	end
	for _, key in MOVE_KEYS do
		if UserInputService:IsKeyDown(key) then
			Interaction.cancelApproach() -- the player took over
			return
		end
	end
	if not current.model:IsDescendantOf(workspace) or os.clock() - current.startedAt > APPROACH_GIVE_UP then
		Interaction.cancelApproach()
		return
	end
	if flat(current.model:GetPivot().Position, here.Position) <= reachFor(current.kind, current.model) then
		approach = nil
		humanoid:MoveTo(here.Position)
		face(current.model:GetPivot().Position)
		local described = describe(current.model, current.kind)
		if described then
			use(described)
		end
		return
	end
	local point = current.waypoints[current.step]
	if point and flat(point, here.Position) < 2 and current.step < #current.waypoints then
		current.step += 1
		point = current.waypoints[current.step]
	end
	if point then
		humanoid:MoveTo(point)
	end
end

-- Something usable under the mouse (any distance), or the nearest within APPROACH_RADIUS.
local function farTarget(): (Model?, string?)
	local hovered, kind = underMouse()
	local here = root()
	if hovered and kind and here and describe(hovered, kind) then
		return hovered, kind
	end
	if here == nil then
		return nil, nil
	end
	local best, bestKind, bestDistance = nil, nil, APPROACH_RADIUS
	for tagKind, tag in TAGS do
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("Model") and instance:IsDescendantOf(workspace) and describe(instance, tagKind) then
				local distance = flat(instance:GetPivot().Position, here.Position)
				if distance < bestDistance then
					best, bestKind, bestDistance = instance, tagKind, distance
				end
			end
		end
	end
	return best, bestKind
end

-- A click on something out of reach walks there and uses it (3.11). True when it did.
function Interaction.clickFar(): boolean
	local hovered, kind = underMouse()
	if hovered == nil or kind == nil or describe(hovered, kind) == nil then
		return false
	end
	local here = root()
	if here and flat(hovered:GetPivot().Position, here.Position) <= reachFor(kind, hovered) then
		return false -- in reach: the normal click handles it
	end
	startApproach(hovered, kind)
	return true
end

-- Uses the current target: opens stations and crates, swings at nodes. With nothing
-- in reach, walks to what's under the mouse (or the nearest thing) and uses it there.
function Interaction.activate()
	local target = State.ui().target
	if target == nil then
		local model, kind = farTarget()
		if model and kind then
			startApproach(model, kind)
		end
		return
	end
	if target.kind == "station" then
		State.toggle("station", target.key)
	elseif target.kind == "drop" then
		Net.fire("PickupDrop", target.key)
	elseif target.kind == "storage" then
		Net.fire("StorageOpen", target.key)
		if State.ui().panel ~= "inventory" then
			State.toggle("inventory")
		end
	else
		swing()
	end
end

-- Starts or stops repeated gathering (LMB held, or the touch button held).
function Interaction.setGathering(held: boolean)
	gathering = held
	if held then
		autoStep()
	elseif not State.ui().auto then
		stopWalking()
	end
end

-- Turns the character toward the mouse's point on the ground (aiming with LMB).
function Interaction.aimAtMouse()
	local camera = workspace.CurrentCamera
	local here = root()
	if camera == nil or here == nil then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	if math.abs(ray.Direction.Y) < 1e-3 then
		return
	end
	local t = (here.Position.Y - 2.5 - ray.Origin.Y) / ray.Direction.Y
	if t > 0 then
		face(ray.Origin + ray.Direction * t)
	end
end

function Interaction.start()
	RunService.Heartbeat:Connect(function(dt)
		scanElapsed += dt
		if scanElapsed >= SCAN_SECONDS then
			scanElapsed = 0
			scan()
		end
		local ui = State.ui()
		if approach then
			approachStep()
		elseif (gathering or ui.auto) and ui.panel == "none" then
			autoStep()
		end
	end)
	-- A full bag ends AUTO and held gathering (LDoE stops auto-gather when full).
	State.fx:Connect(function(kind: any)
		if kind == "bagFull" then
			gathering = false
			Interaction.setAuto(false)
		end
	end)
	-- Closing the inventory screen closes the crate on the server too.
	local wasOpen = false
	State.changed:Connect(function(key: any)
		if key ~= "ui" then
			return
		end
		local open = State.ui().panel == "inventory"
		if wasOpen and not open and State.get("storage") then
			Net.fire("StorageOpen", nil)
		end
		wasOpen = open
	end)
end

return Interaction
