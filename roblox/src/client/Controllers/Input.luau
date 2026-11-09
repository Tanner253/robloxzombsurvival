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
local CombatControl = require("./CombatControl")
local FogRun = require("./FogRun")
local Interaction = require("./Interaction")

local Input = {}

local WEAPON_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
}

local function onKey(key: Enum.KeyCode)
	local ui = State.ui()
	local playing = ui.panel == "none"
	local weapon = WEAPON_KEYS[key]
	if weapon and playing then
		Actions.selectWeapon(weapon)
	elseif key == Enum.KeyCode.F and playing then
		Actions.swapWeapon()
	elseif key == Enum.KeyCode.H and playing then
		Actions.useMeds()
	elseif key == Enum.KeyCode.Tab then
		Actions.toggleInventory()
	elseif key == Enum.KeyCode.B then
		Actions.toggleBuild()
	elseif key == Enum.KeyCode.E then
		-- Like LDoE's action button: tap to use, hold to keep gathering (walking to the next node).
		Actions.interact()
		if playing then
			Actions.setGathering(true)
		end
	elseif key == Enum.KeyCode.Q then
		Actions.toggleAuto()
	elseif key == Enum.KeyCode.O then
		Actions.toggleSettings()
	elseif key == Enum.KeyCode.C and playing and FogRun.active() then
		CombatControl.dodge() -- on a run C rolls (13.11); crafting waits for home
	elseif key == Enum.KeyCode.C then
		Actions.toggleCrafting()
	elseif key == Enum.KeyCode.R and playing and FogRun.active() then
		CombatControl.reload()
	elseif key == Enum.KeyCode.M and Content.Tuning.features.fogRuns then
		Actions.toggleFogMap()
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
				if Interaction.clickFar() then
					return -- walking there to use it (3.11)
				elseif ui.target and ui.target.kind == "node" then
					Actions.setGathering(true)
				elseif FogRun.active() then
					CombatControl.press() -- on a run LMB attacks (13.3)
				else
					Interaction.aimAtMouse()
				end
			end
		end
	end)
	-- The mouse wheel only zooms (Camera, checklist 2.2); weapons are on 1, 2 and F (4.9).
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Building.setPainting(false)
			Actions.setGathering(false)
			CombatControl.release()
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
