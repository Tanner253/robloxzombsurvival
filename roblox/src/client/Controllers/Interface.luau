--!strict
--[[
	Interface: mounts the React UI tree into the player's PlayerGui and turns off
	the Roblox core UI it replaces (backpack, health bar, player list, which also
	frees Tab for the inventory).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local App = require("../UI/App")

local Interface = {}

local REPLACED = { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.PlayerList }

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

	local screen = Instance.new("ScreenGui")
	screen.Name = "App"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local root = ReactRoblox.createRoot(screen)
	root:render(React.createElement(App))
end

return Interface
