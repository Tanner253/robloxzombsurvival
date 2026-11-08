--!strict
--[[
	InventoryScreen (Tab): gear, pockets, backpack, and on the right either the
	open crate (Take all / Put all) or hand crafting and the item inbox.

	Moving items: drag a slot onto another (merge, swap or move), or click to pick
	it up and click to put it down; Shift-drag moves half a stack; drag it out of
	the window to drop it on the ground; Shift+click quick-moves; right click uses
	or equips (and splits a plain stack). The server checks every move. The strip
	at the bottom describes the item under the cursor or in hand, with Use, Split
	and Drop. Items gained since the inventory was last opened wear a NEW badge.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local BuildRules = require(ReplicatedStorage.Shared.Domain.BuildRules)
local Slots = require(ReplicatedStorage.Shared.Domain.Slots)
local Actions = require("../../Actions")
local Net = require("../../Net")
local Sfx = require("../../Sfx")
local State = require("../../State")
local Theme = require("../theme")
local offers = require("../offers")
local hooks = require("../hooks")
local format = require("../format")
local Button = require("../components/Button")
local ItemIcon = require("../components/ItemIcon")
local ItemSlot = require("../components/ItemSlot")
local KeyChip = require("../components/KeyChip")
local TrashGlyph = require("../components/TrashGlyph")
local StatPairs = require("../components/StatPairs")
local Label = require("../components/Label")
local Sheet = require("../components/Sheet")

local e = React.createElement

local SLOT = 60
local GAP = 6
local DRAG_START_PIXELS = 6
-- More backpack slots than this (two and a half rows) scroll.
local BACKPACK_VISIBLE_SLOTS = 15

-- A press on a slot that may turn into a drag. `active` once it has moved far enough.
type Drag = { ref: string, index: number, from: Vector2, active: boolean }
local drag: Drag? = nil
local suppressClickUntil = 0
local sheetFrame: GuiObject? = nil

-- A ScreenGui above everything (ignoring the top-bar inset) for the dragged item.
local layer: ScreenGui? = nil
local function dragLayer(): ScreenGui
	if layer and layer.Parent then
		return layer
	end
	local made = Instance.new("ScreenGui")
	made.Name = "EO_DragLayer"
	made.IgnoreGuiInset = true
	made.ResetOnSpawn = false
	made.DisplayOrder = 60
	made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	layer = made
	return made
end
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
	if os.clock() < suppressClickUntil then
		return -- this click ended a drag
	end
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
			isNew = def ~= nil and ui.newItems[slot.itemId] == true,
			slotRef = props.source,
			slotIndex = index,
			onSecondary = function()
				-- Use or equip what can be used; split a plain stack.
				local usable = def and (def.consume or def.equipSlot or def.category == "blueprint")
				if usable then
					useSlot(props.source, index)
				elseif def and slot.count > 1 and props.source ~= "equipment" and props.source ~= "stash" then
					Net.fire("InventorySplit", props.source, index)
					Sfx.play("uiClick")
				end
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

-- The item following the cursor while dragging. Releasing over a slot moves it
-- there (Shift: half the stack); releasing outside the window drops it on the ground.
-- The last mouse position in GUI space (below the top bar), from input events.
local mouseGui = Vector2.zero

-- The inventory slot under a GUI-space point, if any.
local function slotAt(point: Vector2): (string?, number?)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil, nil
	end
	for _, object in playerGui:GetGuiObjectsAtPosition(point.X, point.Y) do
		local ref = object:GetAttribute("SlotRef")
		if type(ref) == "string" then
			return ref, object:GetAttribute("SlotIndex") :: number?
		end
	end
	return nil, nil
end

local function DragGhost(props: { inventory: any, storage: any, stash: any })
	local _, setTick = React.useState(0)
	React.useEffect(function()
		local function rerender()
			setTick(function(n: number)
				return n + 1
			end)
		end
		local pressed = UserInputService.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			-- Event positions are in GUI space (below the top bar), like AbsolutePosition.
			local mouse = Vector2.new(input.Position.X, input.Position.Y)
			mouseGui = mouse
			local ref, index = slotAt(mouse)
			if ref and index and ref ~= "stash" then
				local slot = containerOf(State.get("inventory"), State.get("storage"), State.get("stash"), ref)[index]
				if slot and slot.count > 0 then
					drag = { ref = ref, index = index, from = mouse, active = false }
				end
			end
		end)
		local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				mouseGui = Vector2.new(input.Position.X, input.Position.Y)
			end
			if drag and input.UserInputType == Enum.UserInputType.MouseMovement then
				local mouse = mouseGui
				if not drag.active and (mouse - drag.from).Magnitude >= DRAG_START_PIXELS then
					drag.active = true
					State.clear("selected")
				end
				if drag.active then
					rerender()
				end
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 or drag == nil then
				return
			end
			local done = drag :: Drag
			drag = nil
			rerender()
			if not done.active then
				return -- a plain click; Activated handles it
			end
			suppressClickUntil = os.clock() + 0.2
			mouseGui = Vector2.new(input.Position.X, input.Position.Y)
			local toRef, toIndex = slotAt(mouseGui)
			local container = containerOf(State.get("inventory"), State.get("storage"), State.get("stash"), done.ref)
			local slot = container[done.index]
			if slot == nil or slot.count <= 0 then
				return
			end
			if toRef and toIndex and not (toRef == done.ref and toIndex == done.index) then
				local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
					or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
				local count = if shift and slot.count > 1 then slot.count // 2 else nil
				Net.fire("InventoryMove", done.ref, done.index, toRef, toIndex, count)
				Sfx.play("uiClick")
				return
			end
			-- Outside the window: drop it on the ground.
			local frame = sheetFrame
			local inside = false
			if frame and frame.Parent then
				local at = mouseGui
				local min, size = frame.AbsolutePosition, frame.AbsoluteSize
				inside = at.X >= min.X and at.Y >= min.Y and at.X <= min.X + size.X and at.Y <= min.Y + size.Y
			end
			if not inside and done.ref ~= "equipment" and Art.dropReady() then
				Net.fire("InventoryDrop", done.ref, done.index)
				Sfx.play("pickup")
			end
		end)
		return function()
			pressed:Disconnect()
			moved:Disconnect()
			ended:Disconnect()
			drag = nil
		end
	end, {})
	local current = drag
	if current == nil or not current.active then
		return nil
	end
	local slot = containerOf(props.inventory, props.storage, props.stash, current.ref)[current.index]
	if slot == nil or slot.count <= 0 then
		return nil
	end
	-- The drag layer ignores the top-bar inset, so add it back.
	local mouse = mouseGui + game:GetService("GuiService"):GetGuiInset()
	return ReactRoblox.createPortal(
		e("Frame", {
			Size = UDim2.fromOffset(SLOT, SLOT),
			Position = UDim2.fromOffset(mouse.X, mouse.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 50,
		}, {
			Icon = e(ItemIcon, { itemId = slot.itemId, zIndex = 50 }),
			Count = slot.count > 1 and e("TextLabel", {
				Size = UDim2.new(1, -4, 0, 16),
				Position = UDim2.new(0, 0, 1, -18),
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = tostring(slot.count),
				TextSize = Theme.textSize.caption + 2,
				TextColor3 = Theme.colors.text,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 51,
			}),
		}),
		dragLayer()
	)
end

local function Section(props: {
	title: string,
	note: string?,
	layoutOrder: number,
	action: { text: string, onActivated: () -> () }?,
})
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Title = e(
			Label,
			{ text = props.title, style = "section", tone = "accent", autoWidth = true, size = UDim2.fromOffset(0, 22) }
		),
		Note = props.note and e(Label, {
			text = props.note,
			style = "caption",
			tone = "muted",
			size = if props.action then UDim2.new(1, -70, 1, 0) else UDim2.fromScale(1, 1),
			alignX = Enum.TextXAlignment.Right,
		}),
		Action = props.action and e("TextButton", {
			Size = UDim2.fromOffset(60, 22),
			Position = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Theme.colors.panelRaised,
			FontFace = Theme.fonts.header,
			Text = props.action.text,
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.text,
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				Sfx.play("uiClick")
				props.action.onActivated()
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", {
				Color = Theme.colors.strokeWarm,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
	})
end

-- Right column: crafting -----------------------------------------------------------------------------------

-- Item details ------------------------------------------------------------------------------------------

local function describe(def: any): string
	local head = `{string.upper(def.category)} · Tier {def.tier}`
	return if def.description then `{head}  —  {def.description}` else head
end

-- Destroy a slot for good: the first press arms it (red, "Sure?"), a second press
-- within CONFIRM_SECONDS destroys; anything else disarms it.
local CONFIRM_SECONDS = 3

local function TrashButton(props: { container: string, index: number, layoutOrder: number })
	-- Keyed by slot in the action bar, so picking another item remounts it disarmed.
	local armedUntil, setArmedUntil = React.useState(0)
	local armed = os.clock() < armedUntil
	return e("TextButton", {
		Size = UDim2.fromOffset(if armed then 90 else 52, 44),
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = false,
		BackgroundColor3 = if armed then Theme.colors.locked else Theme.colors.panelRaised,
		FontFace = Theme.fonts.header,
		Text = if armed then "Sure?" else "",
		TextSize = Theme.textSize.body,
		TextColor3 = Theme.colors.textOnAccent,
		[React.Event.Activated] = function()
			if armed then
				Net.fire("InventoryDestroy", props.container, props.index)
				State.clear("selected")
				setArmedUntil(0)
				Sfx.play("toolBreak")
			else
				setArmedUntil(os.clock() + CONFIRM_SECONDS)
				Sfx.play("uiClick")
				task.delay(CONFIRM_SECONDS, function()
					setArmedUntil(0)
				end)
			end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = if armed then Theme.colors.locked else Theme.colors.strokeWarm,
			Thickness = Theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Bin = not armed and e(TrashGlyph, { color = Theme.colors.textMuted }),
	})
end

local function Details(props: { inventory: any, storage: any, stash: any })
	local ui = hooks.useUi()
	local focus = ui.hovered or ui.selected
	local slot = if focus then containerOf(props.inventory, props.storage, props.stash, focus.ref)[focus.index] else nil
	local def = if slot and slot.count > 0 then Content.Items[slot.itemId] else nil
	if def == nil or focus == nil then
		return e(Label, {
			text = if Art.dropReady()
				then "Drag items between slots (Shift: half a stack), or out of the window to drop them.  Shift+click moves across.  Right click uses, equips or splits."
				else "Drag items between slots (Shift: half a stack).  Shift+click moves across.  Right click uses, equips or splits.",
			style = "caption",
			tone = "muted",
			wrap = true,
			size = UDim2.fromScale(1, 1),
		})
	end
	local usable = def.consume or def.equipSlot or def.category == "blueprint" or def.tool
	local drink = def.consume and (def.consume.thirst or 0) > (def.consume.hunger or 0)
	local verb = if def.consume
		then (if drink then "Drink" elseif (def.consume.hunger or 0) > 0 then "Eat" else "Use")
		elseif def.equipSlot then "Equip"
		elseif def.tool then "Hold"
		else "Read"
	local carried = focus.ref == "pockets" or focus.ref == "backpack" or focus.ref == "storage"
	-- Dropping on the ground needs the sack model (hidden until it's graded A, §0).
	local droppable = carried and Art.dropReady()
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
		-- Stats as icon + value chips (4.14), then the item's line of description.
		Stats = e(StatPairs, {
			itemId = def.id,
			durability = slot.durability,
			size = UDim2.new(0.5, 0, 0, 30),
			position = UDim2.fromOffset(84, 28),
		}),
		Info = e(Label, {
			text = describe(def),
			style = "caption",
			tone = "muted",
			size = UDim2.new(0.55, 0, 0, 20),
			position = UDim2.fromOffset(84, 62),
		}),
		-- The action bar (checklist 4.11): real buttons, right-aligned, no gaps.
		Actions = e("Frame", {
			Size = UDim2.fromOffset(440, 44),
			Position = UDim2.fromScale(1, 0.5),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Use = usable and (focus.ref == "pockets" or focus.ref == "backpack") and e(Button, {
				text = verb,
				size = UDim2.fromOffset(100, 44),
				layoutOrder = 1,
				onActivated = function()
					useSlot(focus.ref, focus.index)
				end,
			}),
			Split = slot.count > 1 and focus.ref ~= "equipment" and focus.ref ~= "stash" and e(Button, {
				text = "Split",
				variant = "secondary",
				size = UDim2.fromOffset(90, 44),
				layoutOrder = 2,
				onActivated = function()
					Net.fire("InventorySplit", focus.ref, focus.index)
				end,
			}),
			Drop = droppable and e(Button, {
				text = "Drop",
				variant = "secondary",
				size = UDim2.fromOffset(90, 44),
				layoutOrder = 3,
				onActivated = function()
					Net.fire("InventoryDrop", focus.ref, focus.index)
					State.clear("selected")
					Sfx.play("pickup")
				end,
			}),
			[`Destroy{focus.ref}{focus.index}`] = carried
				and e(TrashButton, { container = focus.ref, index = focus.index, layoutOrder = 4 }),
		}),
	})
end

-- Storage upgrade in the crate's header (checklist 4.12): capacity now -> next, the
-- cost with have/need (home pool, 5.13), and Upgrade in place.
local function CrateUpgrade(props: { uid: string, pieceId: string })
	local pooled = hooks.usePooled()
	local progression = hooks.useSection("progression")
	local unlocks = hooks.useSection("unlocks")
	local def = Content.BuildPieces[props.pieceId]
	local nextDef = def and def.upgradesTo and Content.BuildPieces[def.upgradesTo]
	if def == nil or nextDef == nil then
		return e(Label, {
			text = `{if def then def.storageSlots or 0 else 0} slots · fully upgraded`,
			style = "caption",
			tone = "muted",
			size = UDim2.new(1, 0, 0, 44),
		})
	end
	local progress = {
		level = if progression then progression.level else 1,
		unlocks = if unlocks then unlocks else { recipes = {}, blueprints = {} },
	}
	local unlocked = BuildRules.isUnlocked(nextDef, progress)
	local affordable = true
	local parts = {}
	for _, stack in nextDef.cost do
		local have = format.count(pooled, stack.itemId)
		affordable = affordable and have >= stack.count
		local color = if have >= stack.count then Theme.colors.text else Theme.colors.locked
		table.insert(
			parts,
			`<font color="#{color:ToHex()}">{have}/{stack.count} {format.itemName(stack.itemId)}</font>`
		)
	end
	local gate = nextDef.unlock
	local lockText = if gate and gate.kind == "level"
		then `Unlocks at level {gate.level}`
		elseif gate and gate.kind == "blueprint" then "Needs its blueprint"
		else ""
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.colors.panelRaised,
		BackgroundTransparency = 0.2,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Capacity = e(Label, {
			text = `{def.storageSlots or 0} → {nextDef.storageSlots or 0} slots`,
			style = "section",
			size = UDim2.new(1, -120, 0, 22),
			position = UDim2.fromOffset(10, 1),
		}),
		Cost = e(Label, {
			text = if unlocked then table.concat(parts, "  ·  ") else lockText,
			style = "caption",
			tone = if unlocked then "muted" else "locked",
			richText = true,
			size = UDim2.new(1, -120, 0, 18),
			position = UDim2.fromOffset(10, 23),
		}),
		-- S3 slot (UI/offers): "Fill up" what the upgrade lacks, only once the shop sets it.
		FillUp = unlocked and not affordable and offers.fillUp ~= nil and e(Button, {
			text = "Fill up",
			variant = "secondary",
			size = UDim2.fromOffset(90, 40),
			position = UDim2.new(1, -112, 0.5, 0),
			anchorPoint = Vector2.new(1, 0.5),
			onActivated = function()
				local fillUp = offers.fillUp
				if fillUp then
					fillUp(nextDef.cost)
				end
			end,
		}),
		Upgrade = e(Button, {
			text = "Upgrade",
			disabled = not (unlocked and affordable),
			size = UDim2.fromOffset(104, 40),
			position = UDim2.new(1, -2, 0.5, 0),
			anchorPoint = Vector2.new(1, 0.5),
			onActivated = function()
				Net.fire("BuildUpgrade", props.uid)
				Sfx.play("uiClick")
			end,
		}),
	})
end

-- Item inbox (checklist 4.15) ---------------------------------------------------------------------------

local SOURCE_TEXT: { [string]: string } = {
	LevelUp = "Level-up reward",
	Quest = "Quest reward",
	Purchase = "Purchase",
	Event = "Event reward",
	Overflow = "Didn't fit your bag",
	Stash = "From the old stash",
}
local FILTERS = {
	"all",
	"resource",
	"material",
	"part",
	"tool",
	"weapon",
	"ammo",
	"armor",
	"bag",
	"consumable",
	"blueprint",
	"junk",
}
local FILTER_TEXT: { [string]: string } = {
	all = "All",
	resource = "Resources",
	material = "Materials",
	tool = "Tools",
	weapon = "Weapons",
	part = "Parts",
	ammo = "Ammo",
	armor = "Gear",
	bag = "Bags",
	consumable = "Supplies",
	blueprint = "Blueprints",
	junk = "Junk",
}

local function InboxRow(props: { row: any, layoutOrder: number })
	local row = props.row
	local def = Content.Items[row.itemId]
	local usable = def and def.consume ~= nil
	return e("Frame", {
		Size = UDim2.new(1, -8, 0, 58),
		BackgroundColor3 = Theme.colors.panelRaised,
		BackgroundTransparency = 0.1,
		LayoutOrder = props.layoutOrder,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Icon = e("Frame", {
			Size = UDim2.fromOffset(46, 46),
			Position = UDim2.fromOffset(6, 6),
			BackgroundTransparency = 1,
		}, { Inner = e(ItemIcon, { itemId = row.itemId, size = UDim2.fromScale(1, 1) }) }),
		Name = e(Label, {
			text = if row.count > 1 then format.stack(row.itemId, row.count) else format.itemName(row.itemId),
			style = "body",
			size = UDim2.new(1, -230, 0, 22),
			position = UDim2.fromOffset(58, 6),
		}),
		Source = e(Label, {
			text = SOURCE_TEXT[row.source] or row.source,
			style = "caption",
			tone = "muted",
			size = UDim2.new(1, -230, 0, 18),
			position = UDim2.fromOffset(58, 30),
		}),
		Use = usable and e(Button, {
			text = "Use",
			variant = "secondary",
			size = UDim2.fromOffset(70, 44),
			position = UDim2.new(1, -96, 0.5, 0),
			anchorPoint = Vector2.new(1, 0.5),
			onActivated = function()
				Net.fire("InboxUse", row.id)
			end,
		}),
		Take = e(Button, {
			text = "Take",
			size = UDim2.fromOffset(84, 44),
			position = UDim2.new(1, -6, 0.5, 0),
			anchorPoint = Vector2.new(1, 0.5),
			onActivated = function()
				Net.fire("InboxTake", row.id)
				Sfx.play("pickup")
			end,
		}),
	})
end

local function InboxList(props: { rows: { any } })
	local filter, setFilter = React.useState("all")
	local present: { [string]: boolean } = { all = true }
	for _, row in props.rows do
		local def = Content.Items[row.itemId]
		if def then
			present[def.category] = true
		end
	end
	local chips: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, key in FILTERS do
		if present[key] then
			chips[key] = e("TextButton", {
				Size = UDim2.fromOffset(0, 28),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = index,
				AutoButtonColor = false,
				BackgroundColor3 = if filter == key then Theme.colors.accent else Theme.colors.panelRaised,
				FontFace = Theme.fonts.header,
				Text = FILTER_TEXT[key],
				TextSize = Theme.textSize.caption,
				TextColor3 = if filter == key then Theme.colors.textOnAccent else Theme.colors.text,
				[React.Event.Activated] = function()
					setFilter(key)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
			})
		end
	end
	local rows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	local shown = 0
	for index = #props.rows, 1, -1 do -- newest first
		local row = props.rows[index]
		local def = Content.Items[row.itemId]
		if filter == "all" or (def and def.category == filter) then
			shown += 1
			rows[row.id] = e(InboxRow, { row = row, layoutOrder = shown })
		end
	end
	return e("Frame", {
		Size = UDim2.new(1, 0, 1, -28),
		Position = UDim2.fromOffset(0, 28),
		BackgroundTransparency = 1,
	}, {
		Chips = e("Frame", { Size = UDim2.new(1, -120, 0, 28), BackgroundTransparency = 1 }, chips),
		TakeAll = e(Button, {
			text = "Take all",
			disabled = shown == 0,
			size = UDim2.fromOffset(110, 34),
			position = UDim2.fromScale(1, 0),
			anchorPoint = Vector2.new(1, 0),
			onActivated = function()
				Net.fire("InboxTakeAll", filter)
				Sfx.play("pickup")
			end,
		}),
		Empty = shown == 0
			and e(Label, {
				text = "Rewards, purchases and anything that doesn't fit your bag wait here. No limit, never raided, never expires.",
				style = "caption",
				tone = "muted",
				wrap = true,
				size = UDim2.new(1, 0, 0, 40),
				position = UDim2.fromOffset(0, 44),
			}),
		Scroll = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -44),
			Position = UDim2.fromOffset(0, 44),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, rows),
	})
end

-- Screen ---------------------------------------------------------------------------------------------------

local function InventoryScreen()
	local ui = hooks.useUi()
	local inventory = hooks.useSection("inventory")
	local storage = hooks.useSection("storage")
	local stash = nil -- the locked stash became the item inbox (4.15)
	local inbox = hooks.useSection("inbox")
	local open = ui.panel == "inventory" and inventory ~= nil and inventory ~= false
	local crate = if storage then storage else nil

	local body: any = nil
	if inventory then
		local equipment = Slots.fromEquipment(inventory.equipment)
		-- Each equip slot draws the silhouette of what goes there.
		local placeholders = table.clone(Slots.EQUIP_ORDER) :: { any }
		local inboxCount = if type(inbox) == "table" then #inbox else 0
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
					action = if #inventory.backpack > 0
						then {
							text = "Sort",
							onActivated = function()
								Net.fire("InventorySort", "backpack")
							end,
						}
						else nil,
				}),
				-- Big bags scroll inside the window instead of spilling over the hotbar.
				Backpack = if #inventory.backpack > BACKPACK_VISIBLE_SLOTS
					then e("ScrollingFrame", {
						Size = UDim2.fromOffset(6 * (SLOT + GAP) + 6, 3 * (SLOT + GAP)), -- whole rows
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 4,
						ScrollBarImageColor3 = Theme.colors.strokeWarm,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.new(),
						LayoutOrder = 3,
					}, {
						Grid = e(Grid, {
							source = "backpack",
							slots = inventory.backpack,
							columns = 6,
							inventory = inventory,
							storage = crate,
							stash = stash,
						}),
					})
					elseif #inventory.backpack > 0 then e(Grid, {
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
							action = {
								text = "Sort",
								onActivated = function()
									Net.fire("InventorySort", "storage")
								end,
							},
						}),
						Upgrade = e("Frame", {
							Size = UDim2.new(1, 0, 0, 44),
							Position = UDim2.fromOffset(0, 28),
							BackgroundTransparency = 1,
						}, {
							Inner = e(CrateUpgrade, { uid = crate.uid, pieceId = crate.pieceId }),
						}),
						Scroll = e("ScrollingFrame", {
							Size = UDim2.new(1, 0, 1, -134),
							Position = UDim2.fromOffset(0, 78),
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
							Inbox = e("TextButton", {
								Size = UDim2.fromOffset(120, 24),
								BackgroundTransparency = 1,
								FontFace = Theme.fonts.header,
								Text = if inboxCount > 0 then `INBOX ({inboxCount})` else "INBOX",
								TextSize = Theme.textSize.caption,
								TextColor3 = Theme.colors.accent,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
						}),
						-- The full catalogue replaced the short craft list here (5.9).
						OpenCrafting = e(Button, {
							text = "Crafting",
							variant = "secondary",
							size = UDim2.fromOffset(130, 34),
							position = UDim2.new(1, -30, 0, -6),
							anchorPoint = Vector2.new(1, 0),
							onActivated = Actions.toggleCrafting,
						}),
						CraftKey = e(
							KeyChip,
							{ text = "C", position = UDim2.new(1, 0, 0, -2), anchorPoint = Vector2.new(1, 0) }
						),
						Body = e(InboxList, { rows = if type(inbox) == "table" then inbox else {} }),
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
			Drag = e(DragGhost, { inventory = inventory, storage = crate, stash = stash }),
			Bounds = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ref = function(rbx: Frame?)
					-- The sheet's content box: releasing a drag outside it drops the item.
					sheetFrame = if rbx then rbx.Parent :: any else nil
				end,
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
