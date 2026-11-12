--!strict
--[[
	StatPairs: an item's stats as icon + value chips (checklist 4.14), used in the
	inventory details strip and the recipe card. Gear stats use the equip-slot
	silhouettes; food and drink use the HUD meter glyphs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local Theme = require("../theme")
local Glyph = require("./Glyph")

export type Props = {
	itemId: string,
	durability: number?, -- the slot's current durability, when known
	size: UDim2?,
	position: UDim2?,
	layoutOrder: number?,
}

type Pair = { silhouette: string?, glyph: string?, color: Color3?, text: string }

local e = React.createElement

local function pairsFor(def: any, durability: number?): { Pair }
	local list: { Pair } = {}
	if def.tool then
		table.insert(list, { silhouette = "weapon", text = `Tier {def.tool.tier} {def.tool.kind}` })
	end
	if def.weapon then
		table.insert(list, { silhouette = "weapon", text = `{def.weapon.damage} damage` })
		table.insert(list, { glyph = "attack", text = `{def.weapon.attacksPerSecond}/s` })
	end
	if def.throw then
		local throw = def.throw
		if throw.kind == "fire" then
			table.insert(list, { silhouette = "weapon", text = `{throw.burnDps}/s fire, {throw.burnSeconds} s` })
		else
			table.insert(list, { silhouette = "weapon", text = `{throw.damage} damage` })
		end
		table.insert(list, { glyph = "attack", text = `{throw.radius} stud radius` })
	end
	if def.armor then
		table.insert(list, { silhouette = def.equipSlot or "body", text = `+{def.armor.defense} defense` })
	end
	if def.bagSlots then
		table.insert(list, { silhouette = "bag", text = `+{def.bagSlots} slots` })
	end
	if def.consume then
		for _, key in { "health", "hunger", "thirst", "energy" } do
			local value = def.consume[key]
			if value and value ~= 0 then
				table.insert(list, {
					glyph = Art.meterGlyphs[key],
					color = (Theme.meters :: any)[key],
					text = `{if value > 0 then "+" else ""}{value}`,
				})
			end
		end
	end
	if def.durability then
		local now = durability or def.durability
		table.insert(list, { glyph = "craft", text = `{now} / {def.durability}` })
	end
	return list
end

local function Chip(props: { pair: Pair, layoutOrder: number })
	local pair = props.pair
	local cell = pair.silhouette and Art.gearSilhouettes.cells[pair.silhouette]
	return e("Frame", {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.colors.panelRaised,
		LayoutOrder = props.layoutOrder,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) }),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Icon = if cell
			then e("ImageLabel", {
				Size = UDim2.fromOffset(20, 20),
				BackgroundTransparency = 1,
				Image = Art.gearSilhouettes.image,
				ImageRectOffset = cell * Art.gearSilhouettes.cell,
				ImageRectSize = Vector2.one * Art.gearSilhouettes.cell,
				ImageColor3 = Theme.colors.highlight,
				LayoutOrder = 1,
			})
			else e(Glyph, {
				name = pair.glyph or "",
				size = UDim2.fromOffset(20, 20),
				color = pair.color or Theme.colors.highlight,
				layoutOrder = 1,
			}),
		Value = e("TextLabel", {
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = pair.text,
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.text,
			LayoutOrder = 2,
		}),
	})
end

local function StatPairs(props: Props)
	local def = Content.Items[props.itemId]
	local children: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	if def then
		for index, pair in pairsFor(def, props.durability) do
			children[`P{index}`] = e(Chip, { pair = pair, layoutOrder = index })
		end
	end
	return e("Frame", {
		Size = props.size or UDim2.new(1, 0, 0, 30),
		Position = props.position,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, children)
end

return StatPairs
