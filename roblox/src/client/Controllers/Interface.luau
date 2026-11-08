--!strict
--[[
	Interface: mounts the React UI tree into the player's PlayerGui and turns off the
	Roblox core UI it replaces (backpack, health bar, player list, which also frees Tab for
	the inventory).

	Roblox's own UI is respected (checklist 4.18): the App's ScreenGui uses the CoreUI safe
	insets, so nothing of ours sits under the top-bar buttons or a device notch. With the
	LDoE HUD on, the chat window docks at the bottom left above the level bar (LDOE_PARITY
	#10), in the gap the HUD leaves for it. Opening any panel or build mode hides the HUD
	(#11, #25), and the chat with it: Roblox draws chat above our panels. A panel also hides
	Roblox's touch thumbstick and jump button, as LDoE hides its joystick; build mode keeps
	them, since you still walk while building. Behind a full-screen panel the whole world
	blurs, as in LDoE (rec1_02), top inset included, which the App's dim can't reach.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Flags = require(ReplicatedStorage.Shared.Flags)
local State = require("../State")
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

-- The full-screen panels (screens/ldoe/Hud's FULL_SCREEN): the world blurs behind them.
local FULL_SCREEN: { [string]: boolean } =
	{ inventory = true, station = true, project = true, crafting = true, settings = true }
local BLUR_SIZE = 18

local blur: BlurEffect? = nil
local function setBackdrop(on: boolean)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	if blur == nil or blur.Parent ~= camera then
		local made = Instance.new("BlurEffect")
		made.Name = "EO_PanelBlur"
		made.Size = 0
		made.Parent = camera
		blur = made
	end
	TweenService:Create(blur :: BlurEffect, TweenInfo.new(0.2), { Size = if on then BLUR_SIZE else 0 }):Play()
end

-- Chat shows only while playing (no panel open); a panel or build mode hides it. Touch
-- controls show while playing and building.
local function followPanels()
	local shown: boolean? = nil
	local controls: boolean? = nil
	local blurred: boolean? = nil
	local function apply()
		local panel = State.ui().panel
		local wantBlur = FULL_SCREEN[panel] == true
		if wantBlur ~= blurred then
			blurred = wantBlur
			setBackdrop(wantBlur)
		end
		local wantControls = panel == "none" or panel == "build"
		if wantControls ~= controls then
			controls = wantControls
			pcall(function()
				GuiService.TouchControlsEnabled = wantControls
			end)
		end
		local want = panel == "none"
		if want == shown then
			return
		end
		shown = want
		pcall(function()
			local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
			local bar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
			if window then
				window.Enabled = want
			end
			if bar then
				bar.Enabled = want
			end
		end)
	end
	State.changed:Connect(function(key: any)
		if key == "ui" then
			apply()
		end
	end)
	apply()
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
		followPanels()
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
