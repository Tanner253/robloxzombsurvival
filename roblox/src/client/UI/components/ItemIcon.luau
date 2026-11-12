--!strict
--[[
	ItemIcon: an item's picture. In order of preference:
	1. the item's real in-game model (ReplicatedStorage.Assets.Icons: the very model
	   held in the hand or worn), rendered live by ModelView (checklist 4.16), so the
	   slot shows exactly what the player sees; held items lie on the icon diagonal,
	2. the ItemDef.icon image (the painted icon set), for items with no model in the
	   game (materials, parts, food), where the picture is the only form there is,
	3. a fallback badge: a rarity-tinted disc with the item's initials (no emoji, 4.17).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Art = require(ReplicatedStorage.Shared.Art)
local HoldRules = require(ReplicatedStorage.Shared.Domain.HoldRules)
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

-- The pose an item's icon lies in, top up (HoldRules.iconSigns turns Art.held's hand frame
-- over where it differs: a gun's `edge` is its underside). One table per item, so ModelView
-- doesn't rebuild its copy on every render.
local poses: { [string]: ModelView.Pose } = {}

local function iconPose(itemId: string, def: any): ModelView.Pose?
	local cached = poses[itemId]
	if cached then
		return cached
	end
	local held = Art.held[itemId]
	if held == nil then
		return nil
	end
	local axisSign, edgeSign = HoldRules.iconSigns(itemId, def)
	local pose = { axis = held.axis * axisSign, edge = held.edge * edgeSign }
	poses[itemId] = pose
	return pose
end

local function ItemIcon(props: Props)
	local def = Content.Items[props.itemId]
	local size = props.size or UDim2.fromScale(0.82, 0.82)
	local position = props.position or UDim2.fromScale(0.5, 0.5)
	local anchor = props.anchorPoint or Vector2.new(0.5, 0.5)
	if def == nil then
		return nil
	end
	local model = iconModel(props.itemId)
	if model then
		return React.createElement(ModelView, {
			model = model,
			pose = iconPose(props.itemId, def),
			size = size,
			position = position,
			anchorPoint = anchor,
			zIndex = props.zIndex,
		})
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
			Text = string.sub(def.name, 1, 2),
			TextScaled = true,
			TextColor3 = Theme.colors.text,
			ZIndex = props.zIndex,
		}),
	})
end

return ItemIcon
