--!strict
--[[
	ItemSlot: one inventory cell. Shows the item's icon (ItemIcon), a
	rarity-colored border, the stack count, a durability bar and an optional
	hotkey number. Hover lifts it; selection glows ember; a changed count pops.
	An empty slot is a quiet frame. Left click activates, right click is the
	secondary action (use / equip).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Theme = require("../theme")
local hooks = require("../hooks")
local ItemIcon = require("./ItemIcon")

export type Props = {
	itemId: string?, -- nil or "" for an empty slot
	count: number?,
	durability: number?, -- 0..1 of max; nil hides the bar
	selected: boolean?,
	hotkey: string?,
	placeholder: string?, -- shown in an empty slot (equipment slot names)
	dim: boolean?,
	size: number?,
	onActivated: (() -> ())?,
	onSecondary: (() -> ())?,
	onHover: ((hovering: boolean) -> ())?,
	layoutOrder: number?,
}

-- Which Theme.itemKind backplate an item gets.
local function kindOf(def: any): string
	local category = def.category
	if category == "consumable" then
		local effect = def.consume or {}
		return if (effect.hunger or 0) > 0 or (effect.thirst or 0) > 0 then "food" else "medical"
	elseif category == "tool" or category == "weapon" or category == "ammo" then
		return "tool"
	elseif category == "armor" or category == "bag" then
		return "gear"
	elseif category == "junk" then
		return "junk"
	elseif category == "blueprint" then
		return "blueprint"
	end
	return "material"
end

local function ItemSlot(props: Props)
	local itemId = props.itemId
	local empty = itemId == nil or itemId == "" or (props.count or 0) <= 0
	local def = if empty then nil else Content.Items[itemId :: string]
	local hovering, setHovering = React.useState(false)
	local size = props.size or Theme.slotSize

	-- Pop when the count changes (a reward landing in this slot).
	local lastCount = React.useRef(props.count)
	local pop, setPop = React.useState(0)
	React.useEffect(function()
		if props.count ~= lastCount.current and not empty then
			setPop(function(n: number)
				return n + 1
			end)
		end
		lastCount.current = props.count
	end, { props.count })
	local popScale = hooks.useAnimated(if pop % 2 == 1 then 1.12 else 1, 18)
	local lift = hooks.useAnimated(if hovering then 1 else 0, 20)

	local border = if props.selected
		then Theme.colors.accent
		elseif def then Theme.rarity[def.rarity] or Theme.colors.strokeWarm
		else Theme.colors.strokeWarm

	React.useEffect(function()
		if pop % 2 == 1 then
			local thread = task.delay(0.12, function()
				setPop(function(n: number)
					return n + 1
				end)
			end)
			return function()
				task.cancel(thread)
			end
		end
		return function() end
	end, { pop })

	return React.createElement("TextButton", {
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = if props.selected
			then Theme.colors.panelRaised:Lerp(Theme.colors.accent, 0.18)
			else Theme.colors.panelRaised,
		BackgroundTransparency = if empty then 0.35 else 0,
		[React.Event.Activated] = props.onActivated,
		[React.Event.MouseButton2Click] = props.onSecondary,
		[React.Event.MouseEnter] = function()
			setHovering(true)
			if props.onHover then
				props.onHover(true)
			end
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
			if props.onHover then
				props.onHover(false)
			end
		end,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = Theme.radius }),
		Scale = React.createElement("UIScale", {
			Scale = (React.joinBindings :: any)({ popScale, lift }):map(function(values: any)
				return values[1] * (1 + values[2] * 0.04)
			end),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = border,
			Thickness = if props.selected then 3 else Theme.strokeThickness,
			Transparency = if empty and not props.selected then 0.55 else 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Shade = not empty and React.createElement("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 186, 180)),
			Rotation = 90,
		}),
		Backplate = def and React.createElement("Frame", {
			Size = UDim2.fromScale(0.86, 0.86),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.itemKind[kindOf(def)] or Theme.colors.panelRaised,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Fade = React.createElement("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.35),
					NumberSequenceKeypoint.new(0.7, 0.85),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		}),
		Icon = not empty and React.createElement(ItemIcon, { itemId = itemId :: string }),
		Dim = props.dim and not empty and React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.colors.shadow,
			BackgroundTransparency = 0.45,
			ZIndex = 3,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.radius }),
		}),
		Placeholder = empty and props.placeholder and React.createElement("TextLabel", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.body,
			Text = props.placeholder,
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.textMuted,
			TextTransparency = 0.3,
			TextWrapped = true,
		}),
		Hotkey = props.hotkey and React.createElement("TextLabel", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.fromOffset(4, 2),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = props.hotkey,
			TextSize = Theme.textSize.caption,
			TextColor3 = if props.selected then Theme.colors.accent else Theme.colors.textMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		}),
		Count = not empty and (props.count or 0) > 1 and React.createElement("TextLabel", {
			Size = UDim2.new(1, -6, 0, Theme.textSize.caption),
			Position = UDim2.new(0, 0, 1, -Theme.textSize.caption - 4),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = tostring(props.count),
			TextSize = Theme.textSize.caption + 2,
			TextColor3 = Theme.colors.text,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 4,
		}, {
			Stroke = React.createElement("UIStroke", { Color = Theme.colors.shadow, Thickness = 1.5 }),
		}),
		DurabilityTrack = not empty and props.durability ~= nil and React.createElement("Frame", {
			Size = UDim2.new(1, -8, 0, 4),
			Position = UDim2.new(0, 4, 1, -7),
			BackgroundColor3 = Theme.colors.track,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = React.createElement("Frame", {
				Size = UDim2.fromScale(math.clamp(props.durability or 0, 0, 1), 1),
				BackgroundColor3 = if (props.durability or 1) < 0.25
					then Theme.colors.accent
					else Theme.colors.durability,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
	})
end

return ItemSlot
