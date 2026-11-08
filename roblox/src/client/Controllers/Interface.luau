--!strict
-- Interface: mounts the React UI tree into the player's PlayerGui.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local App = require("../UI/App")

local Interface = {}

function Interface.start()
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
