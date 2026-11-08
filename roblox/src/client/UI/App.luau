--!strict
--[[
	App: the root of the React UI tree. Screens (HUD, Inventory, ...) mount here
	from M1 on. In Studio, set the workspace attribute `ShowUIKit` to true to show
	the kit preview for look-test screenshots.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local KitPreview = require("./screens/KitPreview")

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

local function App()
	local showKit = useWorkspaceFlag("ShowUIKit")

	return React.createElement(React.Fragment, nil, {
		KitPreview = RunService:IsStudio() and showKit and React.createElement(KitPreview),
	})
end

return App
