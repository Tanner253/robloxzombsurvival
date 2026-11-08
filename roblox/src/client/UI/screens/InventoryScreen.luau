--!strict
--[[
	InventoryScreen (Tab): gear, pockets, backpack, and on the right either the
	open crate (Take all / Put all) or hand crafting and the locked stash.

	Moving items: click a slot to pick it up, click another to drop it there
	(merge, swap or move); Shift+click quick-moves; right click uses or equips.
	The server checks every move. The strip at the bottom describes the item
	under the cursor or in hand, with Use and Split buttons.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Slots = require(ReplicatedStorage.Shared.Domain.Slots)
local CraftingMath = require(ReplicatedStorage.Shared.Domain.Crafting)
local Actions = require("../../Actions")
local Net = require("../../Net")
local Sfx = require("../../Sfx")
local State = require("../../State")
local Theme = require("../theme")
local hooks = require("../hooks")
local format = require("../format")
local Button = require("../components/Button")
local ItemIcon = require("../components/ItemIcon")
local ItemSlot = require("../components/ItemSlot")
local KeyChip = require("../components/KeyChip")
local Label = require("../components/Label")
local Sheet = require("../components/Sheet")

local e = React.createElement

local SLOT = 60
local GAP = 6
local EQUIP_LABELS = { head = "Head", body = "Body", legs = "Legs", feet = "Feet", weapon = "Weapon", bag = "Bag" }

-- Slot helpers ---------------------------------------------------------------------------------------

local function containerOf(inventory: any, storage: any, stash: any, ref: string): { any }
	if ref == "pockets" then
		return inventory.pockets
	elseif ref == "backpack" then
		return inventory.backpack
	elseif ref == "equipment" then
		return Slots.fromEquipment(inventory.equipment)
	elseif ref == "storage" then
		return if storage then storage.slots else {}
	end
	return stash or {}
end

-- The best slot in `container` for `slot`: a stack of the same item with room, else the first empty one.
local function landingIndex(container: { any }, slot: any): number?
	local def = Content.Items[slot.itemId]
	if def and def.stackSize > 1 and slot.durability == nil then
		for index, other in container do
			if other.itemId == slot.itemId and other.count < def.stackSize and other.durability == nil then
				return index
			end
		end
	end
	for index, other in container do
		if other.count <= 0 then
			return index
		end
	end
	return nil
end

local function quickMove(inventory: any, storage: any, stash: any, ref: string, index: number)
	local slot = containerOf(inventory, storage, stash, ref)[index]
	if slot == nil or slot.count <= 0 then
		return
	end
	local order: { string }
	if ref == "storage" or ref == "stash" or ref == "equipment" then
		order = { "pockets", "backpack" }
	elseif storage then
		order = { "storage" }
	elseif ref == "pockets" then
		order = { "backpack" }
	else
		order = { "pockets" }
	end
	for _, target in order do
		local landing = landingIndex(containerOf(inventory, storage, stash, target), slot)
		if landing then
			Net.fire("InventoryMove", ref, index, target, landing, nil)
			Sfx.play("uiClick")
			return
		end
	end
	State.notify("No room for that")
end

local function useSlot(ref: string, index: number)
	if ref == "pockets" or ref == "backpack" then
		Net.fire("UseItem", ref, index)
	elseif ref == "equipment" then
		local inventory = State.get("inventory")
		local slot = inventory and Slots.fromEquipment(inventory.equipment)[index]
		local landing = slot and landingIndex(inventory.backpack, slot)
			or (slot and landingIndex(inventory.pockets, slot))
		if landing then
			local target = if landingIndex(inventory.backpack, slot) then "backpack" else "pockets"
			Net.fire("InventoryMove", "equipment", index, target, landing, nil)
		end
	end
end

local function clickSlot(inventory: any, storage: any, stash: any, ref: string, index: number)
	local selected = State.ui().selected
	local slot = containerOf(inventory, storage, stash, ref)[index]
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		quickMove(inventory, storage, stash, ref, index)
		return
	end
	if selected == nil then
		if slot and slot.count > 0 then
			State.patch({ selected = { ref = ref, index = index } })
			Sfx.play("uiClick")
		end
	elseif selected.ref == ref and selected.index == index then
		State.clear("selected")
	else
		Net.fire("InventoryMove", selected.ref, selected.index, ref, index, nil)
		State.clear("selected")
		Sfx.play("uiClick")
	end
end

-- Grid of one container -------------------------------------------------------------------------------

local function Grid(
	props: {
		source: string, -- the container ref (not `ref`: React reserves it)
		slots: { any },
		columns: number,
		inventory: any,
		storage: any,
		stash: any,
		hotkeys: boolean?,
		placeholders: { string }?,
		accepts: { string }?,
		position: UDim2?,
		layoutOrder: number?,
	}
)
	local ui = hooks.useUi()
	local children: { [string]: any } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(SLOT, SLOT),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			FillDirectionMaxCells = props.columns,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, slot in props.slots do
		local def = if slot.count > 0 then Content.Items[slot.itemId] else nil
		local selected = ui.selected ~= nil and ui.selected.ref == props.source and ui.selected.index == index
		children[`S{index}`] = e(ItemSlot, {
			itemId = slot.itemId,
			count = slot.count,
			durability = if def and def.durability and slot.durability then slot.durability / def.durability else nil,
			selected = selected,
			hotkey = if props.hotkeys and index <= 9 then tostring(index) else nil,
			placeholder = if props.placeholders then props.placeholders[index] else nil,
			size = SLOT,
			layoutOrder = index,
			onActivated = function()
				clickSlot(props.inventory, props.storage, props.stash, props.source, index)
			end,
			onSecondary = function()
				useSlot(props.source, index)
			end,
			onHover = function(hovering: boolean)
				if hovering then
					State.patch({ hovered = { ref = props.source, index = index } })
				elseif ui.hovered and ui.hovered.ref == props.source and ui.hovered.index == index then
					State.clear("hovered")
				end
			end,
		})
	end
	local rows = math.max(1, math.ceil(#props.slots / props.columns))
	return e("Frame", {
		Size = UDim2.fromOffset(props.columns * (SLOT + GAP) - GAP, rows * (SLOT + GAP) - GAP),
		Position = props.position,
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
	}, children)
end

local function Section(props: { title: string, note: string?, layoutOrder: number })
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Title = e(
			Label,
			{ text = props.title, style = "caption", tone = "accent", autoWidth = true, size = UDim2.fromOffset(0, 22) }
		),
		Note = props.note and e(Label, {
			text = props.note,
			style = "caption",
			tone = "muted",
			size = UDim2.fromScale(1, 1),
			alignX = Enum.TextXAlignment.Right,
		}),
	})
end

-- Right column: crafting -----------------------------------------------------------------------------------

local function handRecipes(): { any }
	local list = {}
	for _, recipe in Content.Recipes do
		if recipe.stationId == nil then
			table.insert(list, recipe)
		end
	end
	table.sort(list, function(a: any, b: any)
		return format.itemName(a.outputs[1].itemId) < format.itemName(b.outputs[1].itemId)
	end)
	return list
end

local function CraftRow(props: { recipe: any, inventory: any, progress: any, layoutOrder: number })
	local recipe = props.recipe
	local unlocked = CraftingMath.isUnlocked(recipe, props.progress)
	local canAfford = true
	local inputs = {}
	for _, stack in recipe.inputs do
		local have = format.count(props.inventory, stack.itemId)
		canAfford = canAfford and have >= stack.count
		local color = if have >= stack.count then Theme.colors.text else Theme.colors.accent
		table.insert(inputs, `<font color="#{color:ToHex()}">{stack.count} {format.itemName(stack.itemId)}</font>`)
	end
	local output = recipe.outputs[1]
	local gate = recipe.unlock
	local lockText = if gate.kind == "level" then `Level {gate.level}` else "Blueprint"
	return e("Frame", {
		Size = UDim2.new(1, -8, 0, 58),
		BackgroundColor3 = Theme.colors.panelRaised,
		BackgroundTransparency = if unlocked then 0.1 else 0.45,
		LayoutOrder = props.layoutOrder,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Icon = e(
			"Frame",
			{ Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1 },
			{
				Inner = e(ItemIcon, { itemId = output.itemId, size = UDim2.fromScale(1, 1) }),
			}
		),
		Name = e(Label, {
			text = if output.count > 1
				then format.stack(output.itemId, output.count)
				else format.itemName(output.itemId),
			style = "body",
			size = UDim2.new(1, -150, 0, 22),
			position = UDim2.fromOffset(58, 6),
		}),
		Inputs = e(Label, {
			text = if unlocked then table.concat(inputs, "  ·  ") else `Unlocks at {lockText}`,
			style = "caption",
			tone = "muted",
			richText = true,
			size = UDim2.new(1, -150, 0, 18),
			position = UDim2.fromOffset(58, 30),
		}),
		Craft = unlocked and e(Button, {
			text = "Craft",
			variant = if canAfford then "primary" else "secondary",
			disabled = not canAfford,
			size = UDim2.fromOffset(84, 44),
			position = UDim2.new(1, -6, 0.5, 0),
			anchorPoint = Vector2.new(1, 0.5),
			onActivated = function()
				Net.fire("HandCraft", recipe.id, 1)
			end,
		}),
	})
end

local function CraftingList(props: { inventory: any })
	local progression = hooks.useSection("progression")
	local unlocks = hooks.useSection("unlocks")
	local progress = {
		level = if progression then progression.level else 1,
		unlocks = if unlocks then unlocks else { recipes = {}, blueprints = {} },
	}
	local rows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, recipe in handRecipes() do
		rows[recipe.id] =
			e(CraftRow, { recipe = recipe, inventory = props.inventory, progress = progress, layoutOrder = index })
	end
	return e("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -28),
		Position = UDim2.fromOffset(0, 28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.colors.strokeWarm,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, rows)
end

-- Item details ------------------------------------------------------------------------------------------

local function describe(def: any, slot: any): string
	local lines = { `{string.upper(def.category)} · Tier {def.tier}` }
	if def.tool then
		table.insert(lines, `Harvest tool · tier {def.tool.tier} {def.tool.kind}`)
	end
	if def.weapon then
		table.insert(lines, `{def.weapon.damage} damage · {def.weapon.attacksPerSecond}/s`)
	end
	if def.armor then
		table.insert(lines, `{def.armor.defense} defense`)
	end
	if def.bagSlots then
		table.insert(lines, `+{def.bagSlots} backpack slots when worn`)
	end
	if def.consume then
		local parts = {}
		for _, key in { "health", "hunger", "thirst", "energy" } do
			local value = def.consume[key]
			if value and value ~= 0 then
				table.insert(parts, `{if value > 0 then "+" else ""}{value} {key}`)
			end
		end
		table.insert(lines, table.concat(parts, "  "))
	end
	if def.durability and slot.durability then
		table.insert(lines, `Durability {slot.durability} / {def.durability}`)
	end
	return table.concat(lines, "\n")
end

local function Details(props: { inventory: any, storage: any, stash: any })
	local ui = hooks.useUi()
	local focus = ui.hovered or ui.selected
	local slot = if focus then containerOf(props.inventory, props.storage, props.stash, focus.ref)[focus.index] else nil
	local def = if slot and slot.count > 0 then Content.Items[slot.itemId] else nil
	if def == nil or focus == nil then
		return e(Label, {
			text = "Click an item to pick it up, click a slot to put it down.  Shift+click moves it across.  Right click uses or equips.",
			style = "caption",
			tone = "muted",
			wrap = true,
			size = UDim2.fromScale(1, 1),
		})
	end
	local usable = def.consume or def.equipSlot or def.category == "blueprint" or def.tool
	local verb = if def.consume then "Use" elseif def.equipSlot then "Equip" elseif def.tool then "Hold" else "Read"
	return e(React.Fragment, nil, {
		Icon = e("Frame", { Size = UDim2.fromOffset(72, 72), BackgroundColor3 = Theme.colors.panelRaised }, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = Theme.rarity[def.rarity], Thickness = Theme.strokeThickness }),
			Inner = e(ItemIcon, { itemId = def.id }),
		}),
		Name = e(Label, {
			text = if slot.count > 1 then `{def.name}  ×{slot.count}` else def.name,
			style = "title",
			color = Theme.rarity[def.rarity],
			size = UDim2.new(0.5, 0, 0, 26),
			position = UDim2.fromOffset(84, 0),
		}),
		Info = e(Label, {
			text = describe(def, slot),
			style = "caption",
			tone = "muted",
			wrap = true,
			size = UDim2.new(0.55, 0, 0, 52),
			position = UDim2.fromOffset(84, 26),
			alignY = Enum.TextYAlignment.Top,
		}),
		Use = usable and (focus.ref == "pockets" or focus.ref == "backpack") and e(Button, {
			text = verb,
			size = UDim2.fromOffset(110, 44),
			position = UDim2.new(1, -124, 0.5, 0),
			anchorPoint = Vector2.new(1, 0.5),
			onActivated = function()
				useSlot(focus.ref, focus.index)
			end,
		}),
		UseKey = usable
			and e(KeyChip, { text = "RMB", position = UDim2.new(1, -236, 0.5, 0), anchorPoint = Vector2.new(1, 0.5) }),
		Split = slot.count > 1 and focus.ref ~= "equipment" and focus.ref ~= "stash" and e(Button, {
			text = "Split",
			variant = "secondary",
			size = UDim2.fromOffset(110, 44),
			position = UDim2.fromScale(1, 0.5),
			anchorPoint = Vector2.new(1, 0.5),
			onActivated = function()
				Net.fire("InventorySplit", focus.ref, focus.index)
			end,
		}),
	})
end

-- Screen ---------------------------------------------------------------------------------------------------

local function InventoryScreen()
	local ui = hooks.useUi()
	local inventory = hooks.useSection("inventory")
	local storage = hooks.useSection("storage")
	local stash = hooks.useSection("stash")
	local tab, setTab = React.useState("crafting")
	local open = ui.panel == "inventory" and inventory ~= nil and inventory ~= false
	local crate = if storage then storage else nil

	local body: any = nil
	if inventory then
		local equipment = Slots.fromEquipment(inventory.equipment)
		local placeholders = {}
		for index, name in Slots.EQUIP_ORDER do
			placeholders[index] = EQUIP_LABELS[name]
		end
		local stashCount = 0
		for _, slot in stash or {} do
			stashCount += if slot.count > 0 then 1 else 0
		end
		local crateDef = crate and Content.BuildPieces[crate.pieceId]
		local used = 0
		for _, slot in (crate and crate.slots) or {} do
			used += if slot.count > 0 then 1 else 0
		end

		body = {
			Gear = e("Frame", { Size = UDim2.fromOffset(2 * (SLOT + GAP), 300), BackgroundTransparency = 1 }, {
				Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
				Title = e(Section, { title = "GEAR", layoutOrder = 0 }),
				Grid = e(Grid, {
					source = "equipment",
					slots = equipment,
					columns = 2,
					inventory = inventory,
					storage = crate,
					stash = stash,
					placeholders = placeholders,
					layoutOrder = 1,
				}),
			}),
			Carry = e("Frame", {
				Size = UDim2.fromOffset(6 * (SLOT + GAP), 360),
				Position = UDim2.fromOffset(2 * (SLOT + GAP) + 24, 0),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
				PocketsTitle = e(Section, { title = "POCKETS", note = "1-9 on the hotbar", layoutOrder = 0 }),
				Pockets = e(Grid, {
					source = "pockets",
					slots = inventory.pockets,
					columns = 5,
					inventory = inventory,
					storage = crate,
					stash = stash,
					hotkeys = true,
					layoutOrder = 1,
				}),
				BackpackTitle = e(Section, {
					title = "BACKPACK",
					note = `{#inventory.backpack} slots`,
					layoutOrder = 2,
				}),
				Backpack = if #inventory.backpack > 0
					then e(Grid, {
						source = "backpack",
						slots = inventory.backpack,
						columns = 6,
						inventory = inventory,
						storage = crate,
						stash = stash,
						layoutOrder = 3,
					})
					else e(Label, {
						text = "Wear a bag to carry more. Craft a Reed Satchel by hand.",
						style = "caption",
						tone = "muted",
						wrap = true,
						size = UDim2.new(1, 0, 0, 40),
						layoutOrder = 3,
					}),
			}),
			Side = e(
				"Frame",
				{
					Size = UDim2.new(1, -(8 * (SLOT + GAP) + 48), 0, 360),
					Position = UDim2.fromScale(1, 0),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
				},
				if crate
					then {
						Title = e(Section, {
							title = string.upper(if crateDef then crateDef.name else "Crate"),
							note = `{used} / {#crate.slots}`,
							layoutOrder = 0,
						}),
						Scroll = e("ScrollingFrame", {
							Size = UDim2.new(1, 0, 1, -84),
							Position = UDim2.fromOffset(0, 28),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							ScrollBarThickness = 4,
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
							CanvasSize = UDim2.new(),
						}, {
							Grid = e(Grid, {
								source = "storage",
								slots = crate.slots,
								columns = 5,
								inventory = inventory,
								storage = crate,
								stash = stash,
							}),
						}),
						TakeAll = e(Button, {
							text = "Take all",
							size = UDim2.new(0.5, -4, 0, 44),
							position = UDim2.new(0, 0, 1, -44),
							onActivated = function()
								Actions.transfer("takeAll")
							end,
						}),
						TakeKey = e(
							KeyChip,
							{ text = "F", position = UDim2.new(0.5, -10, 1, -50), anchorPoint = Vector2.new(1, 0) }
						),
						PutAll = e(Button, {
							text = "Put all",
							variant = "secondary",
							size = UDim2.new(0.5, -4, 0, 44),
							position = UDim2.new(1, 0, 1, -44),
							anchorPoint = Vector2.new(1, 0),
							onActivated = function()
								Actions.transfer("putAll")
							end,
						}),
						PutKey = e(
							KeyChip,
							{ text = "G", position = UDim2.new(1, -2, 1, -50), anchorPoint = Vector2.new(1, 0) }
						),
					}
					else {
						Tabs = e("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 }, {
							Layout = e("UIListLayout", {
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 16),
							}),
							Crafting = e("TextButton", {
								Size = UDim2.fromOffset(90, 24),
								BackgroundTransparency = 1,
								FontFace = Theme.fonts.header,
								Text = "CRAFTING",
								TextSize = Theme.textSize.caption,
								TextColor3 = if tab == "crafting" then Theme.colors.accent else Theme.colors.textMuted,
								TextXAlignment = Enum.TextXAlignment.Left,
								[React.Event.Activated] = function()
									setTab("crafting")
								end,
							}),
							Stash = e("TextButton", {
								Size = UDim2.fromOffset(120, 24),
								BackgroundTransparency = 1,
								FontFace = Theme.fonts.header,
								Text = if stashCount > 0 then `LOCKED STASH ({stashCount})` else "LOCKED STASH",
								TextSize = Theme.textSize.caption,
								TextColor3 = if tab == "stash" then Theme.colors.accent else Theme.colors.textMuted,
								TextXAlignment = Enum.TextXAlignment.Left,
								[React.Event.Activated] = function()
									setTab("stash")
								end,
							}),
						}),
						Body = if tab == "crafting"
							then e(CraftingList, { inventory = inventory })
							else e("Frame", {
								Size = UDim2.new(1, 0, 1, -28),
								Position = UDim2.fromOffset(0, 28),
								BackgroundTransparency = 1,
							}, {
								Note = e(Label, {
									text = "Purchases and overflow rewards wait here. Nothing in the stash can be raided.",
									style = "caption",
									tone = "muted",
									wrap = true,
									size = UDim2.new(1, 0, 0, 34),
								}),
								Scroll = e("ScrollingFrame", {
									Size = UDim2.new(1, 0, 1, -40),
									Position = UDim2.fromOffset(0, 40),
									BackgroundTransparency = 1,
									BorderSizePixel = 0,
									ScrollBarThickness = 4,
									AutomaticCanvasSize = Enum.AutomaticSize.Y,
									CanvasSize = UDim2.new(),
								}, {
									Grid = e(Grid, {
										source = "stash",
										slots = stash or {},
										columns = 5,
										inventory = inventory,
										storage = crate,
										stash = stash,
									}),
								}),
							}),
					}
			),
			Divider = e("Frame", {
				Size = UDim2.new(1, 0, 0, 2),
				Position = UDim2.new(0, 0, 1, -100),
				BackgroundColor3 = Theme.colors.strokeWarm,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
			}),
			Details = e("Frame", {
				Size = UDim2.new(1, 0, 0, 86),
				Position = UDim2.new(0, 0, 1, -86),
				BackgroundTransparency = 1,
			}, {
				Inner = e(Details, { inventory = inventory, storage = crate, stash = stash }),
			}),
		}
	end

	return e(Sheet, {
		open = open,
		title = if crate then "Crate" else "Inventory",
		subtitle = if crate then "Your storage" else "Pockets, backpack and gear",
		closeKey = "Tab",
		onClose = Actions.toggleInventory,
		size = UDim2.fromOffset(1040, 576),
	}, body)
end

return InventoryScreen
