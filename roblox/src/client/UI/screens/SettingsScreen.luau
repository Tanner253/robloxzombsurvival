--!strict
--[[
	SettingsScreen (the gear button, or O): audio volumes, camera shake, UI size and
	the key list (PLAYER_EXPERIENCE_CHECKLIST 8.6). Changes apply at once
	(Controllers/Preferences) and are saved to the player's profile.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSchema = require(ReplicatedStorage.Shared.Domain.PlayerSchema)
local Actions = require("../../Actions")
local Theme = require("../theme")
local hooks = require("../hooks")
local Button = require("../components/Button")
local Label = require("../components/Label")
local Sheet = require("../components/Sheet")

local e = React.createElement

local VOLUMES = {
	{ key = "master", label = "Master" },
	{ key = "music", label = "Music" },
	{ key = "ambience", label = "Ambience" },
	{ key = "sfx", label = "Effects" },
	{ key = "ui", label = "Interface" },
}
local UI_SCALES = { 0.875, 1, 1.125, 1.25 } -- eighths keep edges on whole pixels (4.1)
local KEYS = {
	{ "WASD", "Move" },
	{ "Shift", "Sprint" },
	{ "Space", "Hop" },
	{ "E", "Use / gather (hold to keep going)" },
	{ "Q", "AUTO gather" },
	{ "1 / 2 / F", "Weapon 1 / weapon 2 / swap" },
	{ "H", "Meds" },
	{ "Wheel / + -", "Zoom" },
	{ "Tab", "Inventory" },
	{ "C", "Crafting" },
	{ "B", "Build" },
	{ "R / U / X", "Rotate / upgrade / demolish" },
	{ "F / G", "Take all / Put all at a crate" },
	{ "O", "Settings" },
}

local function Row(props: { label: string, layoutOrder: number, children: any })
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Label = e(Label, {
			text = props.label,
			style = "body",
			size = UDim2.new(0, 140, 1, 0),
		}),
		Control = e("Frame", {
			Size = UDim2.new(1, -150, 1, 0),
			Position = UDim2.fromOffset(150, 0),
			BackgroundTransparency = 1,
		}, props.children),
	})
end

-- A volume: a bar with - and + (10% steps), easy on touch.
local function Volume(props: { value: number, onChange: (number) -> () })
	return e(React.Fragment, nil, {
		Minus = e(Button, {
			text = "-",
			variant = "secondary",
			size = UDim2.fromOffset(44, 44),
			onActivated = function()
				props.onChange(math.max(0, math.round((props.value - 0.1) * 10) / 10))
			end,
		}),
		Track = e("Frame", {
			Size = UDim2.new(1, -170, 0, 12),
			Position = UDim2.new(0, 56, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Theme.colors.track,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = e("Frame", {
				Size = UDim2.fromScale(props.value, 1),
				BackgroundColor3 = Theme.colors.accent,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		}),
		Plus = e(Button, {
			text = "+",
			variant = "secondary",
			size = UDim2.fromOffset(44, 44),
			position = UDim2.new(1, -60, 0, 0),
			anchorPoint = Vector2.new(1, 0),
			onActivated = function()
				props.onChange(math.min(1, math.round((props.value + 0.1) * 10) / 10))
			end,
		}),
		Value = e(Label, {
			text = `{math.round(props.value * 100)}%`,
			style = "caption",
			tone = "muted",
			size = UDim2.new(0, 50, 1, 0),
			position = UDim2.fromScale(1, 0),
			anchorPoint = Vector2.new(1, 0),
			alignX = Enum.TextXAlignment.Right,
		}),
	})
end

local function SettingsScreen()
	local ui = hooks.useUi()
	local saved = hooks.useSection("settings")
	local settings = if type(saved) == "table" then saved else PlayerSchema.defaultSettings()
	local open = ui.panel == "settings"

	local function change(key: string, value: any)
		local nextSettings = table.clone(settings)
		nextSettings[key] = value
		Actions.saveSettings(nextSettings)
	end

	local left: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Title = e(Label, { text = "AUDIO", style = "section", tone = "accent", size = UDim2.new(1, 0, 0, 22) }),
	}
	for index, volume in VOLUMES do
		left[volume.key] = e(Row, { label = volume.label, layoutOrder = index }, {
			Inner = e(Volume, {
				value = settings[volume.key] :: number,
				onChange = function(value: number)
					change(volume.key, value)
				end,
			}),
		})
	end
	left.ViewTitle = e(Label, {
		text = "VIEW",
		style = "section",
		tone = "accent",
		size = UDim2.new(1, 0, 0, 22),
		layoutOrder = 10,
	})
	left.Shake = e(Row, { label = "Camera shake", layoutOrder = 11 }, {
		Toggle = e(Button, {
			text = if settings.shake then "On" else "Off",
			variant = if settings.shake then "primary" else "secondary",
			size = UDim2.fromOffset(100, 44),
			onActivated = function()
				change("shake", not settings.shake)
			end,
		}),
	})
	local scaleButtons: { [string]: any } = {
		Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	}
	for index, scale in UI_SCALES do
		scaleButtons[`S{index}`] = e(Button, {
			text = `{math.round(scale * 100)}%`,
			variant = if math.abs(settings.uiScale - scale) < 0.01 then "primary" else "secondary",
			size = UDim2.fromOffset(84, 44),
			layoutOrder = index,
			onActivated = function()
				change("uiScale", scale)
			end,
		})
	end
	left.Scale = e(Row, { label = "Interface size", layoutOrder = 12 }, scaleButtons)

	local keys: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Title = e(Label, { text = "KEYS", style = "section", tone = "accent", size = UDim2.new(1, 0, 0, 22) }),
	}
	for index, pair in KEYS do
		keys[`K{index}`] = e("Frame", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			LayoutOrder = index,
		}, {
			Key = e(Label, { text = pair[1], style = "body", tone = "highlight", size = UDim2.new(0, 120, 1, 0) }),
			Does = e(Label, {
				text = pair[2],
				style = "body",
				tone = "muted",
				size = UDim2.new(1, -124, 1, 0),
				position = UDim2.fromOffset(124, 0),
			}),
		})
	end

	return e(Sheet, {
		open = open,
		title = "Settings",
		subtitle = "Saved to your profile",
		closeKey = "O",
		onClose = Actions.closePanel,
		size = UDim2.fromOffset(900, 560),
	}, {
		Left = e("Frame", { Size = UDim2.new(0.55, -12, 1, 0), BackgroundTransparency = 1 }, left),
		Right = e("Frame", {
			Size = UDim2.new(0.45, -12, 1, 0),
			Position = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
		}, keys),
	})
end

return SettingsScreen
