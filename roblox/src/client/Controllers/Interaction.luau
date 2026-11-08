--!strict
--[[
	Interaction: what the player is about to use, and using it.

	Ten times a second it picks a target: the node, station or crate under the
	mouse when it is within reach, otherwise the nearest one in reach. The HUD's
	prompt draws State.ui().target. `activate` (E, or the touch action button)
	opens a station or crate, or swings at a node; holding the gather button
	(LMB, or holding the touch button) keeps swinging every
	Tuning.gathering.swingSeconds. Swings face the target and play a local arm
	swing; the server decides what each swing yields.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Content = require(ReplicatedStorage.Shared.Data)
local Net = require("../Net")
local State = require("../State")

local Interaction = {}

local tuning = Content.Tuning
local TAGS: { [string]: string } = { node = "EO_Node", station = "EO_Station", storage = "EO_Storage" }
local SCAN_SECONDS = 0.1
local VERB: { [string]: string } = { hatchet = "Chop", pick = "Mine" }

local player = Players.LocalPlayer
local gathering = false
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

local function reachFor(kind: string, model: Model): number
	if kind == "node" then
		local size = model:GetExtentsSize()
		return tuning.interaction.gatherReachStuds + math.max(size.X, size.Z) / 2
	end
	return tuning.interaction.reachStuds
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

local function swingArm()
	local character = player.Character
	local arm = character and character:FindFirstChild("RightUpperArm")
	local shoulder = arm and arm:FindFirstChild("RightShoulder") :: Motor6D?
	if shoulder == nil then
		return
	end
	local rest = shoulder:GetAttribute("RestC0")
	if typeof(rest) ~= "CFrame" then
		rest = shoulder.C0
		shoulder:SetAttribute("RestC0", rest)
	end
	local raised = (rest :: CFrame) * CFrame.Angles(math.rad(110), 0, math.rad(-10))
	local up = TweenService:Create(
		shoulder,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = raised }
	)
	up.Completed:Once(function()
		TweenService:Create(shoulder, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { C0 = rest })
			:Play()
	end)
	up:Play()
end

local function swing(): boolean
	local target = State.ui().target
	if target == nil or target.kind ~= "node" then
		return false
	end
	local now = os.clock()
	if now - lastSwing < tuning.gathering.swingSeconds then
		return true
	end
	lastSwing = now
	face(target.model:GetPivot().Position)
	swingArm()
	Net.fire("Gather", target.key)
	State.fx:Fire("swing", { key = target.key, model = target.model })
	return true
end

-- Uses the current target: opens stations and crates, swings at nodes.
function Interaction.activate()
	local target = State.ui().target
	if target == nil then
		return
	end
	if target.kind == "station" then
		State.toggle("station", target.key)
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
		swing()
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
		if gathering and State.ui().panel == "none" then
			swing()
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
