--!strict
--[[
	Animations: the survivor's action animations and held-item carries (Data/Holds,
	played by client/Clips; ART_DIRECTION §6: never Roblox defaults).

	- Actions: chop, mine, pickup, swap, eat, drink, bandage. The local player's play
	  immediately on input; everyone else's play when the server's "act" effect arrives,
	  so all players see each other work. `Animations.hitDelay(kind)` is when the hit
	  frame lands, for timing impacts.
	- Carries: while a gun or the bow is in a survivor's hand, its class's carry loops
	  under everything else (a long gun at low ready in both hands, a pistol and the bow
	  in front of the hip), on every character, read from the server-built Gear model's
	  HandItem. Melee weapons and tools hang from the fist under the walk.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Content = require(ReplicatedStorage.Shared.Data)
local Holds = require(ReplicatedStorage.Shared.Data.Holds)
local HoldRules = require(ReplicatedStorage.Shared.Domain.HoldRules)
local Clips = require("../Clips")
local State = require("../State")

local Animations = {}

local Items: any = Content.Items

-- Plays an action on a character. Returns seconds until its hit frame.
function Animations.play(character: Model?, name: string, speed: number?): number
	local mine = character ~= nil and character == Players.LocalPlayer.Character
	local track = Clips.play(character, name, speed, Enum.AnimationPriority.Action4, mine)
	if track == nil then
		return 0
	end
	return Clips.hit(name) / (speed or 1)
end

-- Seconds from the start of an action to its hit frame.
function Animations.hitDelay(name: string): number
	return Clips.hit(name)
end

-- The action for a node's tool kind.
function Animations.forTool(kind: string?): string
	return if kind then Holds.gather[kind] or "pickup" else "pickup"
end

-- Carries ------------------------------------------------------------------------------------------

local carrying: { [Model]: string? } = {}

--[[
	The off hand on a long gun's handguard (batch 3): an IKControl on the left arm toward the
	held model's "Support" attachment (World/Models, HoldRules.supportAt), on every character
	this client draws. The solved stances stop at the magazine well at 1.3x gun scale. It
	lets go during a reload, when that hand works the magazine.

	On this rig (AnimationConstraint joints) the IKControl settles 0.2 to 0.3 studs short of
	its target wherever the target is, so the target it chases is the handguard point plus a
	correction that grows each frame by the remaining gap: the palm lands on the point
	(measured gap under 0.01 studs within half a second).
]]
type Support = { ik: IKControl, source: Attachment, aim: Attachment, palm: Attachment, correction: Vector3 }
local supports: { [Model]: Support } = {}
local SUPPORT_NAME = "EO_SupportHand"
local CORRECTION_RATE = 0.35 -- share of the remaining gap added each frame
local CORRECTION_MAX = 0.6 -- studs

local function dropSupport(character: Model, existing: Instance?)
	local record = supports[character]
	if record then
		record.aim:Destroy()
	end
	if existing then
		existing:Destroy()
	end
	supports[character] = nil
end

local function supportFor(character: Model, gear: Instance?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local upper = character:FindFirstChild("LeftUpperArm")
	local hand = character:FindFirstChild("LeftHand")
	local torso = character:FindFirstChild("UpperTorso")
	local palm = if hand then hand:FindFirstChild("LeftGripAttachment") else nil
	local inHand = if gear then gear:FindFirstChild("hand") else nil
	local source = if inHand then inHand:FindFirstChild("Support", true) else nil
	local existing = if humanoid then humanoid:FindFirstChild(SUPPORT_NAME) else nil
	if
		humanoid == nil
		or upper == nil
		or torso == nil
		or palm == nil
		or not palm:IsA("Attachment")
		or source == nil
		or not source:IsA("Attachment")
	then
		dropSupport(character, existing)
		return
	end
	local record = supports[character]
	if record and record.source == source and record.ik.Parent then
		return
	end
	dropSupport(character, existing)
	local ik = Instance.new("IKControl")
	ik.Name = SUPPORT_NAME
	ik.Type = Enum.IKControlType.Position
	ik.SmoothTime = 0.04
	-- The elbow stays down and out to the side, as in the solved stances.
	local found = torso:FindFirstChild("EO_SupportPole")
	local pole: Attachment = if found and found:IsA("Attachment") then found else Instance.new("Attachment")
	pole.Name = "EO_SupportPole"
	pole.Position = Vector3.new(-1.8, -2.2, 0.6)
	pole.Parent = torso
	local aim = Instance.new("Attachment")
	aim.Name = "EO_SupportAim"
	aim.WorldPosition = source.WorldPosition
	aim.Parent = workspace.Terrain
	ik.Pole = pole
	ik.ChainRoot = upper
	ik.EndEffector = palm
	ik.Target = aim
	ik.Parent = humanoid
	supports[character] = { ik = ik, source = source, aim = aim, palm = palm, correction = Vector3.zero }
end

-- Each frame: chase the handguard point (see above).
local function stepSupports()
	for character, record in supports do
		if record.source.Parent == nil or record.ik.Parent == nil then
			dropSupport(character, record.ik)
			continue
		end
		local want = record.source.WorldPosition
		if record.ik.Weight > 0 then
			local correction = record.correction + (want - record.palm.WorldPosition) * CORRECTION_RATE
			if correction.Magnitude > CORRECTION_MAX then
				correction = correction.Unit * CORRECTION_MAX
			end
			record.correction = correction
		end
		record.aim.WorldPosition = want + record.correction
	end
end

local function carryFor(character: Model)
	local gear = character:FindFirstChild("Gear")
	supportFor(character, gear)
	local itemId = if gear then gear:GetAttribute("HandItem") else nil
	local id = if type(itemId) == "string" and itemId ~= "" then itemId else nil
	local name = if id then HoldRules.clip(HoldRules.classOf(id, Items[id]), "carry") else nil
	local current = carrying[character]
	if current == name then
		return
	end
	if current then
		Clips.stop(character, current, 0.2)
	end
	carrying[character] = name
	if name then
		Clips.play(character, name)
	end
end

local function watch(character: Model)
	carryFor(character)
	character.ChildAdded:Connect(function(child)
		if child.Name == "Gear" then
			carryFor(character)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "Gear" then
			task.defer(carryFor, character)
		end
	end)
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			carrying[character] = nil
			dropSupport(character, nil)
		end
	end)
end

local function track(player: Player)
	if player.Character then
		task.defer(watch, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		-- The Animator arrives with the Humanoid; give the rig a moment to assemble.
		task.delay(0.5, watch, character)
	end)
end

function Animations.start()
	-- Other players' actions arrive from the server; the local player's play on input.
	State.fx:Connect(function(kind: any, payload: any)
		if kind == "act" and payload.userId ~= Players.LocalPlayer.UserId then
			local other = Players:GetPlayerByUserId(payload.userId)
			Animations.play(if other then other.Character else nil, payload.action)
		end
	end)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	-- The support hand lets go for a reload (a few checks a second is plenty).
	task.spawn(function()
		while true do
			task.wait(0.1)
			for character, record in supports do
				record.ik.Weight = HoldRules.supportWeight(Clips.playing(character, "reload"))
			end
		end
	end)
	RunService.PreRender:Connect(stepSupports)
end

return Animations
