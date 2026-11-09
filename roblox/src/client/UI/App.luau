--!strict
--[[
	App: the root of the React UI tree. Lays every screen out in the design frame
	(Theme.designSize, 1366 x 768 at 16:9) and scales that frame to fit the safe area, so
	the PC layout holds at any resolution. The ScreenGui uses Roblox's CoreUI safe insets
	(Controllers/Interface), so nothing we draw sits under Roblox's top-bar buttons, chat
	or notch (checklist 4.18).

	Screens behind Shared/Flags (S1b, LDoE parity):
	- ldoeHud: the LDoE HUD (screens/ldoe/Hud) instead of the slice-1 HUD;
	- ldoeInventory / ldoeStations: the two-pane screen (screens/ldoe/Panels);
	- ldoeBuild: the LDoE build tray and piece actions (screens/ldoe/Build).

	The UI gate (Controllers/UiGate) can emulate another screen: State.ui().gate gives a
	size and insets, and the App lays out for that instead of the real window.

	In Studio, set the workspace attribute `ShowUIKit` to true to show the kit preview.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Flags = require(ReplicatedStorage.Shared.Flags)
local Theme = require("./theme")
local Boundary = require("./components/Boundary")
local BuildMenu = require("./screens/BuildMenu")
local Feed = require("./screens/Feed")
local HUD = require("./screens/HUD")
local InventoryScreen = require("./screens/InventoryScreen")
local KitPreview = require("./screens/KitPreview")
local SettingsScreen = require("./screens/SettingsScreen")
local CraftingScreen = require("./screens/CraftingScreen")
local Panels = require("./screens/ldoe/Panels")
local LdoeHud = require("./screens/ldoe/Hud")
local LdoeBuild = require("./screens/ldoe/Build")
local Shop = require("./screens/ldoe/Shop")
local EmberConfirm = require("./screens/ldoe/EmberConfirm")
local FogMap = require("./screens/FogMap")
local RunHud = require("./screens/RunHud")
local hooks = require("./hooks")

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

-- Re-renders when a Studio flag override changes, and returns whether it is on.
local function useFeature(name: string): boolean
	useWorkspaceFlag(`Flag_{name}`)
	return Flags.on(name)
end

-- The safe area's size in pixels: the emulated one while the UI gate runs, else the
-- ScreenGui's own (Roblox already took its insets out).
local function safeSize(screen: ScreenGui?, gate: any): Vector2
	if gate then
		return Vector2.new(gate.width - gate.left - gate.right, gate.height - gate.top - gate.bottom)
	end
	if screen then
		return screen.AbsoluteSize
	end
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Theme.designSize
end

-- The scale that fits the design frame into the safe area.
local function fitScale(size: Vector2, preference: number): number
	local scale = math.min(size.X / Theme.designSize.X, size.Y / Theme.designSize.Y) * preference
	-- Snap to 1/8 steps so most edges land on whole pixels (crisp text and icons, 4.1).
	return math.clamp(math.floor(scale * 8) / 8, MIN_SCALE, MAX_SCALE)
end

local function useSafeArea(screen: ScreenGui?, gate: any): Vector2
	local size, setSize = React.useState(safeSize(screen, gate))
	React.useEffect(function()
		setSize(safeSize(screen, gate))
		if screen == nil then
			return function() end
		end
		local connection = screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			setSize(safeSize(screen, gate))
		end)
		return function()
			connection:Disconnect()
		end
	end, { screen :: any, gate })
	return size
end

export type Props = { screen: ScreenGui? }

local function App(props: Props)
	local showKit = useWorkspaceFlag("ShowUIKit")
	local ui = hooks.useUi()
	local settings = hooks.useSection("settings")
	local preference = if type(settings) == "table" then settings.uiScale else 1
	local gate = ui.gate
	local size = useSafeArea(props.screen, gate)
	local scale = fitScale(size, preference)
	Theme.currentScale = scale
	Theme.currentFrame = Vector2.new(size.X / scale, size.Y / scale)
	local ldoeHud = useFeature("ldoeHud")
	local ldoeInventory = useFeature("ldoeInventory")
	local ldoeBuild = useFeature("ldoeBuild")
	useFeature("ldoeStations")

	-- Panels draws the station screen always, and the inventory once ldoeInventory is on.
	local oldInventory = not ldoeInventory

	return e("Frame", {
		-- The design frame: the safe area divided by the scale (UIScale scales it back).
		Size = if gate then UDim2.fromOffset(size.X / scale, size.Y / scale) else UDim2.fromScale(1 / scale, 1 / scale),
		BackgroundTransparency = 1,
	}, {
		Scale = e("UIScale", { Scale = scale }),
		-- Each screen has its own error boundary: one failing screen never blanks the rest.
		HUD = e(Boundary, { name = "HUD" }, { Screen = if ldoeHud then e(LdoeHud) else e(HUD) }),
		Feed = e(Boundary, { name = "Feed" }, { Screen = e(Feed) }),
		Inventory = oldInventory and e(Boundary, { name = "Inventory" }, { Screen = e(InventoryScreen) }),
		Panels = e(Boundary, { name = "Panels" }, { Screen = e(Panels) }),
		Build = e(Boundary, { name = "Build" }, { Screen = if ldoeBuild then e(LdoeBuild) else e(BuildMenu) }),
		Settings = e(Boundary, { name = "Settings" }, { Screen = e(SettingsScreen) }),
		Crafting = e(Boundary, { name = "Crafting" }, { Screen = e(CraftingScreen) }),
		Shop = e(Boundary, { name = "Shop" }, { Screen = e(Shop) }),
		EmberConfirm = e(Boundary, { name = "EmberConfirm" }, { Screen = e(EmberConfirm) }),
		-- Fog Runs (M1 slice 2): the travel map, and everything a run adds to the screen.
		FogMap = e(Boundary, { name = "FogMap" }, { Screen = e(FogMap) }),
		Run = e(Boundary, { name = "Run" }, { Screen = e(RunHud.Screen) }),
		KitPreview = RunService:IsStudio() and showKit and e(KitPreview),
	})
end

return App
