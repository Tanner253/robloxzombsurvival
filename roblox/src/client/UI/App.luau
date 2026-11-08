--!strict
--[[
	App: the root of the React UI tree. Lays every screen out in the design frame
	(Theme.designSize, 1366 x 768 at 16:9) and scales that frame to fit the
	window, so the PC layout holds at any resolution. In Studio, set the
	workspace attribute `ShowUIKit` to true to show the kit preview.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require("./theme")
local BuildMenu = require("./screens/BuildMenu")
local Feed = require("./screens/Feed")
local HUD = require("./screens/HUD")
local InventoryScreen = require("./screens/InventoryScreen")
local KitPreview = require("./screens/KitPreview")
local StationScreen = require("./screens/StationScreen")

local e = React.createElement

local MIN_SCALE = 0.55
local MAX_SCALE = 1.6

local function useWorkspaceFlag(name: string): boolean
	local value, setValue = React.useState(workspace:GetAttribute(name) == true)
	React.useEffect(function()
		local connection = workspace:GetAttributeChangedSignal(name):Connect(function()
			setValue(workspace:GetAttribute(name) == true)
		end)
		return function()
			connection:Disconnect()
		end
	end, { name })
	return value
end

-- The scale that fits the design frame into the viewport.
local function useFitScale(): number
	local function measure(): number
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Theme.designSize
		local scale = math.min(viewport.X / Theme.designSize.X, viewport.Y / Theme.designSize.Y)
		return math.clamp(scale, MIN_SCALE, MAX_SCALE)
	end
	local scale, setScale = React.useState(measure())
	React.useEffect(function()
		local camera = workspace.CurrentCamera
		if camera == nil then
			return function() end
		end
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setScale(measure())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return scale
end

local function App()
	local showKit = useWorkspaceFlag("ShowUIKit")
	local scale = useFitScale()

	return e("Frame", {
		Size = UDim2.fromScale(1 / scale, 1 / scale),
		BackgroundTransparency = 1,
	}, {
		Scale = e("UIScale", { Scale = scale }),
		HUD = e(HUD),
		Feed = e(Feed),
		Inventory = e(InventoryScreen),
		Station = e(StationScreen),
		Build = e(BuildMenu),
		KitPreview = RunService:IsStudio() and showKit and e(KitPreview),
	})
end

return App
