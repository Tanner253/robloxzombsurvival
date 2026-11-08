--!strict
--[[
	Input: PC-first keybinds (GAME_DESIGN.md "PC controls") with a touch fallback.

	WASD moves (Roblox's controls, camera-relative to the fixed camera), the
	mouse aims, LMB gathers or builds, E interacts, Shift sprints, 1-9 use or
	hold hotbar slots, Tab opens the inventory, B build mode. In build mode R
	rotates, U and X switch to upgrade and demolish. With a crate open, F takes
	all and G puts all. Touch uses the on-screen buttons (Actions) and taps the
	world to aim the build ghost.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Content = require(ReplicatedStorage.Shared.Data)
local Actions = require("../Actions")
local State = require("../State")
local Building = require("./Building")
local Interaction = require("./Interaction")

local Input = {}

local HOTBAR_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local function onKey(key: Enum.KeyCode)
	local ui = State.ui()
	local hotbar = HOTBAR_KEYS[key]
	if hotbar then
		Actions.hotbar(hotbar)
	elseif key == Enum.KeyCode.Tab then
		Actions.toggleInventory()
	elseif key == Enum.KeyCode.B then
		Actions.toggleBuild()
	elseif key == Enum.KeyCode.E then
		-- Like LDoE's action button: tap to use, hold to keep gathering (walking to the next node).
		Actions.interact()
		if ui.panel == "none" then
			Actions.setGathering(true)
		end
	elseif key == Enum.KeyCode.Q then
		Actions.toggleAuto()
	elseif key == Enum.KeyCode.O then
		Actions.toggleSettings()
	elseif key == Enum.KeyCode.C then
		Actions.toggleCrafting()
	elseif
		ui.auto and (key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D)
	then
		-- Taking the wheel cancels AUTO.
		Interaction.setAuto(false)
	elseif key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
		Actions.setSprint(true)
	elseif ui.panel == "build" then
		if key == Enum.KeyCode.R then
			Actions.rotate()
		elseif key == Enum.KeyCode.U then
			Actions.buildMode("upgrade")
		elseif key == Enum.KeyCode.Delete or key == Enum.KeyCode.X then
			Actions.buildMode("demolish")
		end
	elseif ui.panel == "inventory" then
		if key == Enum.KeyCode.F then
			Actions.transfer("takeAll")
		elseif key == Enum.KeyCode.G then
			Actions.transfer("putAll")
		end
	end
end

-- No climbing, and jumps are short hops with a cooldown (the server sets the hop height).
local function grounded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		humanoid.StateChanged:Connect(function(_old, new)
			if new == Enum.HumanoidStateType.Jumping then
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
				task.delay(Content.Tuning.movement.hopCooldownSeconds, function()
					if humanoid.Parent then
						humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
					end
				end)
			end
		end)
	end
end

function Input.start()
	local player = game:GetService("Players").LocalPlayer
	player.CharacterAdded:Connect(grounded)
	if player.Character then
		task.spawn(grounded, player.Character)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			-- Tab is processed by the core player list; take it anyway.
			if processed and input.KeyCode ~= Enum.KeyCode.Tab then
				return
			end
			onKey(input.KeyCode)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			local ui = State.ui()
			if ui.panel == "build" then
				Building.setPainting(true)
			elseif ui.panel == "none" then
				if ui.target and ui.target.kind == "node" then
					Actions.setGathering(true)
				else
					Interaction.aimAtMouse()
				end
			end
		end
	end)
	-- The mouse wheel zooms (Camera); the hotbar is on 1-9 (checklist 2.2: the developer
	-- expects the wheel to zoom).
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Building.setPainting(false)
			Actions.setGathering(false)
		elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			Actions.setSprint(false)
		elseif input.KeyCode == Enum.KeyCode.E then
			Actions.setGathering(false)
		end
	end)
	UserInputService.TouchTap:Connect(function(positions, processed)
		if not processed and State.ui().panel == "build" and positions[1] then
			Building.setTouchPoint(positions[1])
		end
	end)
	UserInputService.LastInputTypeChanged:Connect(function(kind)
		local touch = kind == Enum.UserInputType.Touch
		if touch ~= State.ui().touch then
			State.patch({ touch = touch })
		end
	end)
end

return Input
