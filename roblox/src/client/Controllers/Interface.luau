--!strict
--[[
	Interface: mounts the React UI tree into the player's PlayerGui and turns off the
	Roblox core UI it replaces (backpack, health bar, player list, which also frees Tab for
	the inventory).

	Roblox's own UI is respected (checklist 4.18): the App's ScreenGui uses the CoreUI safe
	insets, so nothing of ours sits under the top-bar buttons or a device notch. With the
	LDoE HUD on, the chat window docks at the bottom left above the level bar (LDOE_PARITY
	#10), in the gap the HUD leaves for it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Flags = require(ReplicatedStorage.Shared.Flags)
local App = require("../UI/App")

local Interface = {}

local REPLACED = { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.PlayerList }

-- The chat window docked as LDoE's one-line bar at the bottom left (#10).
local function dockChat()
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if window == nil then
		return
	end
	pcall(function()
		window.HorizontalAlignment = Enum.HorizontalAlignment.Left
		window.VerticalAlignment = Enum.VerticalAlignment.Bottom
		window.HeightScale = 0.55
		window.WidthScale = 0.75
	end)
end

function Interface.start()
	task.spawn(function()
		for _, kind in REPLACED do
			-- SetCoreGuiEnabled can fail while the core scripts load; retry briefly.
			for _ = 1, 10 do
				if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, false) then
					break
				end
				task.wait(0.5)
			end
		end
	end)
	if Flags.on("ldoeHud") then
		dockChat()
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "App"
	screen.ResetOnSpawn = false
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local root = ReactRoblox.createRoot(screen)
	root:render(React.createElement(App, { screen = screen }))
end

return Interface
