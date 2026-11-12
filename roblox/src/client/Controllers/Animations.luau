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

local function carryFor(character: Model)
	local gear = character:FindFirstChild("Gear")
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
end

return Animations
