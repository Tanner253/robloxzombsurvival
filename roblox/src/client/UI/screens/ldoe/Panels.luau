--!strict
--[[
	Panels: LDoE's two-pane screen (LDOE_PARITY #11, #13-23, #56). The inventory sits on the
	left; the right pane is the context: an open crate, a station, the inbox, the wrecked
	hauler's checklist, or the survivor's gear when the inventory opens alone. The world
	dims, the HUD hides and the CLOSE strip runs down the right edge (FullScreen).

	Moving items, LDoE-style:
	- click a slot to select it, click another to move it there; Shift-click moves it
	  across to the other pane; right click runs the main action;
	- the main action follows the context: PUT IN / ADD FUEL at a station, MOVE into an
	  open crate, TAKE from it, else USE / EQUIP / EAT;
	- drag a slot onto any slot, onto a station's input or fuel slot, or out of the panes
	  to drop it on the ground.

	Screens shown: the station converter whenever a station opens (Flags.ldoeStations), and
	the inventory, crates and inbox once Flags.ldoeInventory is on (until then the slice-1
	InventoryScreen keeps those), and Haven Square's NPCs and boards (HavenPane) with the
	coin balance in the inventory header; at the Trader the main action SELLs a bag stack.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Content = require(ReplicatedStorage.Shared.Data)
local Flags = require(ReplicatedStorage.Shared.Flags)
local Converter = require(ReplicatedStorage.Shared.Domain.Converter)
local Market = require(ReplicatedStorage.Shared.Domain.Market)
local Slots = require(ReplicatedStorage.Shared.Domain.Slots)
local Art = require(ReplicatedStorage.Shared.Art)
local Net = require("../../../Net")
local Sfx = require("../../../Sfx")
local State = require("../../../State")
local Actions = require("../../../Actions")
local Theme = require("../../theme")
local hooks = require("../../hooks")
local mark = require("../../mark")
local FullScreen = require("../../components/FullScreen")
local ItemIcon = require("../../components/ItemIcon")
local Modal = require("../../components/Modal")
local Parts = require("./Parts")
local InventoryPane = require("./InventoryPane")
local CharacterPane = require("./CharacterPane")
local StationPane = require("./StationPane")
local ContextPanes = require("./ContextPanes")
local HavenPane = require("./HavenPane")

local e = React.createElement

local DRAG_START_PIXELS = 6

type Selection = { ref: string, index: number }

-- Containers ---------------------------------------------------------------------------------------

local function containerOf(inventory: any, storage: any, ref: string): { any }
	if ref == "pockets" then
		return inventory.pockets
	elseif ref == "backpack" then
		return inventory.backpack
	elseif ref == "equipment" then
		return Slots.fromEquipment(inventory.equipment)
	elseif ref == "storage" then
		return if storage then storage.slots else {}
	end
	return {}
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

local function moveAcross(inventory: any, storage: any, ref: string, index: number, targets: { string }): boolean
	local slot = containerOf(inventory, storage, ref)[index]
	if slot == nil or slot.count <= 0 then
		return false
	end
	for _, target in targets do
		local landing = landingIndex(containerOf(inventory, storage, target), slot)
		if landing then
			Net.fire("InventoryMove", ref, index, target, landing, nil)
			Sfx.play("uiClick")
			return true
		end
	end
	State.notify("No room for that")
	return false
end

-- The drag layer: a ScreenGui above everything for the dragged item -------------------------------------

local function dragLayer(): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("EO_DragLayer")
	if existing then
		return existing :: ScreenGui
	end
	local made = Instance.new("ScreenGui")
	made.Name = "EO_DragLayer"
	made.ResetOnSpawn = false
	made.ScreenInsets = Enum.ScreenInsets.None
	made.DisplayOrder = 50
	made.Parent = playerGui
	return made
end

-- The slot or drop target under a screen point (SlotRef / SlotIndex attributes).
local function targetAt(point: Vector2): (string?, number?)
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

type Drag = { ref: string, index: number, from: Vector2, at: Vector2, active: boolean }

-- Panels -------------------------------------------------------------------------------------------------

local function Panels()
	local ui = hooks.useUi()
	local inventory = hooks.useSection("inventory")
	local storage = hooks.useSection("storage")
	local stations = hooks.useSection("stations")
	local inbox = hooks.useSection("inbox")
	local loot = hooks.useSection("loot") -- a Fog Run container, pile or bag (#45)
	local run = hooks.useSection("run")
	local projects = hooks.useSection("projects")
	local survival = hooks.useSection("survival")
	local quests = hooks.useSection("quests")
	local progression = hooks.useSection("progression")
	local unlocks = hooks.useSection("unlocks")
	local haven = hooks.useSection("haven")
	local wallet = hooks.useSection("wallet")
	local pooled = hooks.usePooled()
	local now = hooks.useClock(1)
	local modalState, setModal = React.useState(nil :: any)
	local modal: string? = modalState
	local dragState, setDrag = React.useState(nil :: any)
	local drag: Drag? = dragState
	local suppressClick = React.useRef(0)

	local useNew = Flags.on("ldoeInventory")
	local stationUid = if ui.panel == "station" then ui.stationUid else nil
	local station = if stationUid and type(stations) == "table" then stations[stationUid] else nil
	local crate = if type(storage) == "table" then storage else nil
	local projectId = if ui.panel == "project" then ui.projectId else nil
	local havenId = if ui.panel == "haven" then ui.havenId else nil
	local open = type(inventory) == "table"
		and (
			(station ~= nil and Flags.on("ldoeStations"))
			or (projectId ~= nil)
			or (havenId ~= nil)
			or (ui.panel == "inventory" and useNew)
		)

	local selected: Selection? = ui.selected
	local stationDef = if station then Content.Stations[station.stationId] else nil

	-- What the main action does for the selected slot, in this context.
	local function mainAction(): InventoryPane.Action
		local sel = selected
		local slot: any = if sel and inventory then containerOf(inventory, crate, sel.ref)[sel.index] else nil
		if sel == nil or slot == nil or slot.count <= 0 then
			return { text = "Use", enabled = false, run = function() end }
		end
		local def = Content.Items[slot.itemId]
		if stationDef and stationUid and (sel.ref == "pockets" or sel.ref == "backpack") then
			if Converter.lineFor(stationDef, Content.Recipes, slot.itemId) then
				return {
					text = "Put in",
					enabled = true,
					run = function()
						Net.fire("StationPutInput", stationUid, sel.ref, sel.index)
						State.clear("selected")
					end,
				}
			elseif stationDef.fuel and table.find(stationDef.fuel.itemIds, slot.itemId) then
				return {
					text = "Add fuel",
					enabled = true,
					run = function()
						Net.fire("StationPutFuel", stationUid, sel.ref, sel.index)
						State.clear("selected")
					end,
				}
			end
		end
		if havenId == "npc.trader" and (sel.ref == "pockets" or sel.ref == "backpack") then
			local count = math.min(slot.count, Market.MAX_TRADE)
			local value = Market.cost(Content.Haven.trader.sell, slot.itemId, count)
			return {
				text = "Sell",
				enabled = value ~= nil,
				run = function()
					Net.fire("HavenSell", slot.itemId, count)
					State.clear("selected")
				end,
			}
		end
		if sel.ref == "storage" then
			return {
				text = "Take",
				enabled = true,
				run = function()
					moveAcross(inventory, crate, sel.ref, sel.index, { "pockets", "backpack" })
					State.clear("selected")
				end,
			}
		elseif crate and (sel.ref == "pockets" or sel.ref == "backpack") then
			return {
				text = "Move",
				enabled = true,
				run = function()
					moveAcross(inventory, crate, sel.ref, sel.index, { "storage" })
					State.clear("selected")
				end,
			}
		elseif sel.ref == "equipment" then
			return {
				text = "Unequip",
				enabled = true,
				run = function()
					moveAcross(inventory, crate, sel.ref, sel.index, { "backpack", "pockets" })
					State.clear("selected")
				end,
			}
		end
		local usable = def and (def.consume or def.equipSlot or def.category == "blueprint")
		local text = if def and def.equipSlot then "Equip" elseif def and def.consume then "Use" else "Use"
		return {
			text = text,
			enabled = usable ~= nil and usable ~= false,
			run = function()
				Net.fire("UseItem", sel.ref, sel.index)
			end,
		}
	end

	local function select(ref: string, index: number)
		if os.clock() < suppressClick.current then
			return -- this click ended a drag
		end
		local slot = containerOf(inventory, crate, ref)[index]
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		if shift and slot and slot.count > 0 then
			State.patch({ selected = { ref = ref, index = index } })
			mainAction().run()
			return
		end
		local current = State.ui().selected
		if current == nil then
			if slot and slot.count > 0 then
				State.patch({ selected = { ref = ref, index = index } })
				Sfx.play("uiClick")
			end
		elseif current.ref == ref and current.index == index then
			State.clear("selected")
		else
			Net.fire("InventoryMove", current.ref, current.index, ref, index, nil)
			State.clear("selected")
			Sfx.play("uiClick")
		end
	end

	local function secondary(ref: string, index: number)
		State.patch({ selected = { ref = ref, index = index } })
		task.defer(function()
			mainAction().run()
		end)
	end

	-- Drag and drop ----------------------------------------------------------------------------------
	React.useEffect(function()
		if not open then
			return function() end
		end
		local pressed = UserInputService.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local point = Vector2.new(input.Position.X, input.Position.Y)
			local ref, index = targetAt(point)
			if ref and index and (ref == "pockets" or ref == "backpack" or ref == "storage" or ref == "equipment") then
				local current = State.get("inventory")
				local slot = current and containerOf(current, State.get("storage"), ref)[index]
				if slot and slot.count > 0 then
					setDrag({ ref = ref, index = index, from = point, at = point, active = false })
				end
			end
		end)
		local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local point = Vector2.new(input.Position.X, input.Position.Y)
			setDrag(function(current: Drag?): Drag?
				if current == nil then
					return nil
				end
				local active = current.active or (point - current.from).Magnitude >= DRAG_START_PIXELS
				return { ref = current.ref, index = current.index, from = current.from, at = point, active = active }
			end)
		end)
		local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			setDrag(function(current: Drag?): Drag?
				if current == nil or not current.active then
					return nil
				end
				suppressClick.current = os.clock() + 0.2
				local point = Vector2.new(input.Position.X, input.Position.Y)
				local toRef, toIndex = targetAt(point)
				local uid = State.ui().stationUid
				if toRef == "stationInput" and uid then
					Net.fire("StationPutInput", uid, current.ref, current.index)
				elseif toRef == "stationFuel" and uid then
					Net.fire("StationPutFuel", uid, current.ref, current.index)
				elseif toRef and toIndex and toRef ~= "stationOutput" then
					if not (toRef == current.ref and toIndex == current.index) then
						local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
						local slot =
							containerOf(State.get("inventory"), State.get("storage"), current.ref)[current.index]
						local count = if shift and slot and slot.count > 1 then slot.count // 2 else nil
						Net.fire("InventoryMove", current.ref, current.index, toRef, toIndex, count)
					end
				elseif toRef == nil and current.ref ~= "equipment" and Art.dropReady() then
					Net.fire("InventoryDrop", current.ref, current.index)
					Sfx.play("pickup")
					return nil
				end
				Sfx.play("uiClick")
				return nil
			end)
		end)
		return function()
			pressed:Disconnect()
			moved:Disconnect()
			ended:Disconnect()
		end
	end, { open })

	if not open or type(inventory) ~= "table" then
		return nil
	end

	local close = function()
		State.clear("selected")
		setModal(nil)
		Actions.closePanel()
	end

	local progress = {
		level = if progression then progression.level else 1,
		unlocks = if type(unlocks) == "table" then unlocks else { recipes = {}, blueprints = {} },
		quests = if type(quests) == "table" then quests else nil,
	}

	local right: any
	if havenId then
		right = e(HavenPane, {
			havenId = havenId,
			haven = if type(haven) == "table" then haven else nil,
			inventory = inventory,
			now = now,
			tab = ui.havenTab,
		})
	elseif station and stationUid then
		right = e(StationPane.Pane, {
			uid = stationUid,
			station = station,
			progress = progress,
			now = now,
			onUpgrade = function()
				setModal("station")
			end,
		})
	elseif projectId then
		right = e(ContextPanes.Project, {
			projectId = projectId,
			state = if type(projects) == "table" then projects[projectId] else nil,
			pooled = pooled,
		})
	elseif type(loot) == "table" then
		right = e(ContextPanes.Loot, { loot = loot, run = run })
	elseif crate and ui.inventoryTab ~= "inbox" then
		right = e(ContextPanes.Storage, {
			storage = crate,
			selected = selected,
			onSelect = select,
			onSecondary = secondary,
			onUpgrade = function()
				setModal("storage")
			end,
			onLabel = function()
				local sel = State.ui().selected
				local slot = if sel then containerOf(inventory, crate, sel.ref)[sel.index] else nil
				Net.fire("StorageLabel", if slot and slot.count > 0 then slot.itemId else nil)
			end,
		})
	elseif ui.inventoryTab == "inbox" then
		right = e(ContextPanes.Inbox, { rows = if type(inbox) == "table" then inbox else {} })
	else
		right = e(CharacterPane, {
			inventory = inventory,
			survival = survival,
			selected = selected,
			onSelect = select,
			onSecondary = secondary,
		})
	end

	local left = e(InventoryPane, {
		inventory = inventory,
		selected = selected,
		newItems = ui.newItems,
		balance = if type(wallet) == "table" then wallet.embers else 0, -- Embers, the premium currency
		onShop = function()
			Actions.openShop(nil, "embers")
		end,
		main = mainAction(),
		onSelect = select,
		onSecondary = secondary,
		onSplit = function()
			if selected then
				Net.fire("InventorySplit", selected.ref, selected.index)
			end
		end,
		onSort = function()
			Net.fire("InventorySort", "pockets")
			Net.fire("InventorySort", "backpack")
		end,
		onTrash = function()
			setModal("trash")
		end,
	})

	-- Modals over the whole screen.
	local modalElement: any = nil
	if modal == "station" and station and stationUid then
		modalElement = e(StationPane.UpgradeModal, {
			uid = stationUid,
			def = Content.Stations[station.stationId],
			state = station,
			pooled = pooled,
			onClose = function()
				setModal(nil)
			end,
		})
	elseif modal == "storage" and crate then
		modalElement = e(ContextPanes.StorageUpgrade, {
			storage = crate,
			pooled = pooled,
			onClose = function()
				setModal(nil)
			end,
		})
	elseif modal == "trash" and selected then
		local slot = containerOf(inventory, crate, selected.ref)[selected.index]
		local def = slot and slot.count > 0 and Content.Items[slot.itemId]
		if def then
			modalElement = e(Modal, {
				title = "Destroy for good?",
				height = 240,
				actions = {
					{
						text = "Cancel",
						variant = "secondary",
						onActivated = function()
							setModal(nil)
						end,
					},
					{
						text = "Destroy",
						variant = "primary",
						onActivated = function()
							Net.fire("InventoryDestroy", selected.ref, selected.index)
							State.clear("selected")
							setModal(nil)
						end,
					},
				},
				children = {
					What = e(Parts.Line, {
						text = `{def.name} x{slot.count} will be gone for good.`,
						tone = Theme.colors.text,
						center = true,
						layoutOrder = 1,
					}),
				},
			})
		end
	end

	-- The dragged item follows the pointer on its own layer.
	local ghost: any = nil
	if drag and drag.active then
		local slot = containerOf(inventory, crate, drag.ref)[drag.index]
		if slot and slot.count > 0 then
			-- Input positions are below the top-bar inset; the drag layer ignores it.
			local at = drag.at + GuiService:GetGuiInset()
			ghost = ReactRoblox.createPortal(
				e("Frame", {
					Size = UDim2.fromOffset(Theme.panel.slot, Theme.panel.slot),
					Position = UDim2.fromOffset(at.X, at.Y),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ZIndex = Theme.layers.drag,
					ref = mark.overlay,
				}, { Icon = e(ItemIcon, { itemId = slot.itemId, zIndex = Theme.layers.drag }) }),
				dragLayer()
			)
		end
	end

	return e(React.Fragment, nil, {
		Screen = e(FullScreen, { open = true, onClose = close, left = { Pane = left }, right = { Pane = right } }),
		Modal = modalElement,
		Ghost = ghost,
	})
end

return Panels
