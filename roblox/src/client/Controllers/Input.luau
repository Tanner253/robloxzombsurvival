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

local UserInputService = game:GetService("UserInputService")

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
		Actions.interact()
	elseif key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
		Actions.setSprint(true)
	elseif ui.panel == "build" then
		if key == Enum.KeyCode.R then
			Actions.rotate()
		elseif key == Enum.KeyCode.U then
			Actions.buildMode("upgrade")
		elseif key == Enum.KeyCode.X then
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

function Input.start()
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
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Building.setPainting(false)
			Actions.setGathering(false)
		elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			Actions.setSprint(false)
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
