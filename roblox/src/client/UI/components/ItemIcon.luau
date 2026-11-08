--!strict
--[[
	ItemIcon: an item's picture. In order of preference:
	1. the ItemDef.icon image (the painted icon set),
	2. a rendered 3D icon of the item's model (ReplicatedStorage.Assets.Icons),
	3. a fallback badge: a rarity-tinted disc with the item's glyph (Art.glyphs).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Art = require(ReplicatedStorage.Shared.Art)
local Theme = require("../theme")
local ModelView = require("./ModelView")

export type Props = {
	itemId: string,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
}

local function iconModel(itemId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local icons = assets and assets:FindFirstChild("Icons")
	local model = icons and icons:FindFirstChild(itemId)
	return if model and model:IsA("Model") then model else nil
end

local function ItemIcon(props: Props)
	local def = Content.Items[props.itemId]
	local size = props.size or UDim2.fromScale(0.82, 0.82)
	local position = props.position or UDim2.fromScale(0.5, 0.5)
	local anchor = props.anchorPoint or Vector2.new(0.5, 0.5)
	if def == nil then
		return nil
	end
	if def.icon ~= "" then
		return React.createElement("ImageLabel", {
			Size = size,
			Position = position,
			AnchorPoint = anchor,
			BackgroundTransparency = 1,
			Image = def.icon,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = props.zIndex,
		})
	end
	local model = iconModel(props.itemId)
	if model then
		return React.createElement(ModelView, {
			model = model,
			size = size,
			position = position,
			anchorPoint = anchor,
			zIndex = props.zIndex,
		})
	end
	local tint = Theme.rarity[def.rarity] or Theme.rarity.common
	return React.createElement("Frame", {
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = Theme.colors.panelRaised,
		ZIndex = props.zIndex,
	}, {
		Aspect = React.createElement("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Gradient = React.createElement("UIGradient", {
			Color = ColorSequence.new(tint:Lerp(Theme.colors.panelRaised, 0.55), Theme.colors.panel),
			Rotation = 60,
		}),
		Stroke = React.createElement("UIStroke", {
			Color = Theme.colors.shadow,
			Thickness = Theme.strokeThickness,
			Transparency = 0.2,
		}),
		Glyph = React.createElement("TextLabel", {
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = Art.glyphs[props.itemId] or string.sub(def.name, 1, 2),
			TextScaled = true,
			TextColor3 = Theme.colors.text,
			ZIndex = props.zIndex,
		}),
	})
end

return ItemIcon
