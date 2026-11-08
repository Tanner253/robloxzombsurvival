--!strict
--[[
	Inventory: server-authoritative pockets, backpack, equipment, storage crates
	(ARCHITECTURE.md §6; M1 step 1). Rewards that do not fit go to Services/Inbox.

	Clients only send intents (InventoryMove, InventorySplit, InventoryTransfer,
	UseItem, StorageOpen, WeaponSelect, WeaponSwap, UseMeds); every rule is in Domain/Slots and
	Domain/Inventory. A bag in the equipment's bag slot sets the backpack size;
	removing it is refused while the slots it adds hold anything.

	Other services change items through `give`, `take`, `commit` and
	`setPocket`, never by writing PlayerData directly, so every change is synced.
	Two weapon slots (equipment weapon and weapon2, 4.9): the active one is in the
	hand; tools stay in the bag and are held only while working (holdForAction).
	The hand is a slot ref: "w1"/"w2" (weapons), "p<i>"/"b<i>" (a tool), or "".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Content = require(ReplicatedStorage.Shared.Data)
local Types = require(ReplicatedStorage.Shared.Types)
local Domain = ReplicatedStorage.Shared.Domain
local InventoryMath = require(Domain.Inventory)
local Slots = require(Domain.Slots)
local PlayerSchema = require(Domain.PlayerSchema)
local Net = require("../Net")
local Events = require("../Events")
local Art = require(ReplicatedStorage.Shared.Art)
local Models = require("../World/Models")
local Analytics = require("./Analytics")
local PlayerData = require("./PlayerData")
local Plots = require("./Plots")
local Survival = require("./Survival")
local Sync = require("./Sync")

local Inventory = {}

type PlayerData = PlayerSchema.PlayerData
type Container = Types.Container

-- Content.Items as the narrower lookup types the Domain modules take (tables are invariant).
local Items: any = Content.Items
local tuning = Content.Tuning

local held: { [Player]: string } = {} -- hand refs: "w1", "w2", "p<i>", "b<i>" or ""
local heldModels: { [Player]: Model } = {}
local openStorage: { [Player]: string } = {}

local REASON_TEXT: { [string]: string } = {
	empty = "Nothing there",
	badSlot = "That slot doesn't exist",
	wrongSlot = "That doesn't go there",
	noSpace = "No room there",
	count = "Can't split that",
	bagFull = "Empty the bag's slots before taking it off",
	noStorage = "Open a crate first",
}

-- Reading and writing --------------------------------------------------------------------------

-- The player's pockets and backpack (the live tables; never mutate them), or nil.
function Inventory.view(player: Player): Types.Inventory?
	local data = PlayerData.get(player)
	if data == nil then
		return nil
	end
	return { pockets = data.inventory.pockets, backpack = data.inventory.backpack }
end

-- Which carried item goes on each mount: the held pocket slot in the hand, other
-- tools and weapons holstered on the belt (both hips) and the back (1.5).
-- The slot a hand ref points at ("w1", "w2", "p<i>", "b<i>"), or nil.
local function slotAt(data: PlayerData, ref: string): Types.Slot?
	local equipment = data.inventory.equipment :: any
	if ref == "w1" then
		return equipment.weapon
	elseif ref == "w2" then
		return equipment.weapon2
	end
	local kind, index = string.match(ref, "^([pb])(%d+)$")
	if kind == nil then
		return nil
	end
	local container = if kind == "p" then data.inventory.pockets else data.inventory.backpack
	return container[tonumber(index) :: number]
end

local function gearPlan(data: PlayerData, handRef: string): { [string]: string }
	local plan: { [string]: string } = {}
	local heldSlot = slotAt(data, handRef)
	if heldSlot and heldSlot.count > 0 then
		plan.hand = heldSlot.itemId
	end
	local seen: { [string]: boolean } = {}
	if plan.hand then
		seen[plan.hand] = true
	end
	local carried: { string } = {}
	for _, name in { "weapon", "weapon2" } do
		local weapon = (data.inventory.equipment :: any)[name]
		if weapon and weapon.count > 0 then
			table.insert(carried, weapon.itemId)
		end
	end
	for _, container in { data.inventory.pockets, data.inventory.backpack } do
		for _, slot in container do
			if slot.count > 0 then
				table.insert(carried, slot.itemId)
			end
		end
	end
	for _, itemId in carried do
		local art = Art.held[itemId]
		local def = Items[itemId]
		if not seen[itemId] and def and (art or def.tool) then
			seen[itemId] = true
			local kind = if art then art.holster else "belt"
			if kind == "back" and plan.back == nil then
				plan.back = itemId
			elseif kind == "belt" and plan.belt == nil then
				plan.belt = itemId
			elseif kind == "belt" and plan.beltLeft == nil then
				plan.beltLeft = itemId
			end
		end
	end
	return plan
end

-- A body part's rest rotation relative to the root, from the StarterCharacter, so a
-- mount is laid out in the character's frame (forward, up) whatever the custom
-- rig's part axes are, and still follows the part when it animates.
local restRotations: { [string]: CFrame } = {}
local function restRotation(partName: string): CFrame
	local cached = restRotations[partName]
	if cached then
		return cached
	end
	local rig = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
	local root = rig and rig:FindFirstChild("HumanoidRootPart")
	local part = rig and rig:FindFirstChild(partName)
	local rotation = CFrame.identity
	if root and part and root:IsA("BasePart") and part:IsA("BasePart") then
		rotation = root.CFrame:ToObjectSpace(part.CFrame).Rotation
	end
	restRotations[partName] = rotation
	return rotation
end

-- The mount's frame on `part`: the part's live rotation with its rest rotation removed.
local function bodyFrame(part: BasePart, at: Vector3): CFrame
	return CFrame.new(at) * part.CFrame.Rotation * restRotation(part.Name):Inverse()
end

local function mountCFrame(character: Model, mount: string): (CFrame?, BasePart?)
	local function partNamed(name: string): BasePart?
		local found = character:FindFirstChild(name)
		return if found and found:IsA("BasePart") then found else nil
	end
	if mount == "hand" then
		local hand = partNamed("RightHand") or partNamed("Right Arm")
		if hand == nil then
			return nil, nil
		end
		local grip = hand:FindFirstChild("RightGripAttachment") :: Attachment?
		local at = if grip then grip.WorldPosition else hand.Position
		return bodyFrame(hand, at), hand
	elseif mount == "back" then
		local torso = partNamed("UpperTorso") or partNamed("Torso")
		if torso == nil then
			return nil, nil
		end
		local frame = bodyFrame(torso, torso.Position)
		return frame * CFrame.new(-0.35, 0.1, 0.78), torso
	end
	local hips = partNamed("LowerTorso") or partNamed("Torso")
	if hips == nil then
		return nil, nil
	end
	local side = if mount == "belt" then 1 else -1
	return bodyFrame(hips, hips.Position) * CFrame.new(0.78 * side, -0.25, 0.1), hips
end

-- Rebuilds the visible gear (in hand and holstered) when what the player carries changes.
local function refreshHeld(player: Player)
	local data = PlayerData.get(player)
	local character = player.Character
	if data == nil or character == nil then
		return
	end
	local plan = gearPlan(data, held[player] or "")
	local signature = `{plan.hand or ""}|{plan.belt or ""}|{plan.beltLeft or ""}|{plan.back or ""}`
	local folder = heldModels[player]
	if folder and folder.Parent == character and folder:GetAttribute("Signature") == signature then
		return
	end
	if folder then
		folder:Destroy()
	end
	local made = Instance.new("Model")
	made.Name = "Gear"
	made:SetAttribute("Signature", signature)
	made:SetAttribute("HandItem", plan.hand or "")
	for mount, itemId in plan do
		local where, anchor = mountCFrame(character, mount)
		local gear = if where and anchor then Models.held(itemId, Items[itemId], mount :: any) else nil
		if gear and where and anchor then
			gear.model.Name = mount
			gear.model:SetAttribute("ItemId", itemId)
			Models.mount(gear, where, anchor)
			gear.model.Parent = made
		end
	end
	made.Parent = character
	heldModels[player] = made
end

-- Writes new pockets and backpack and syncs them.
function Inventory.commit(player: Player, inventory: Types.Inventory)
	local data = PlayerData.get(player)
	assert(data, "player data is not loaded")
	data.inventory.pockets = inventory.pockets
	data.inventory.backpack = inventory.backpack
	Sync.mark(player, "inventory")
	refreshHeld(player)
end

-- Replaces one pocket slot (tool wear) and syncs.
function Inventory.setPocket(player: Player, index: number, slot: Types.Slot)
	local data = PlayerData.get(player)
	assert(data, "player data is not loaded")
	local pockets = table.clone(data.inventory.pockets)
	pockets[index] = slot
	data.inventory.pockets = pockets
	Sync.mark(player, "inventory")
	refreshHeld(player)
end

-- Writes a tool slot by hand ref ("p<i>" or "b<i>"), e.g. after a swing wore it.
function Inventory.setAt(player: Player, ref: string, slot: Types.Slot)
	local kind, index = string.match(ref, "^([pb])(%d+)$")
	if kind == nil then
		return
	end
	local data = PlayerData.get(player)
	assert(data, "player data is not loaded")
	if kind == "p" then
		Inventory.setPocket(player, tonumber(index) :: number, slot)
		return
	end
	local backpack = table.clone(data.inventory.backpack)
	backpack[tonumber(index) :: number] = slot
	data.inventory.backpack = backpack
	Sync.mark(player, "inventory")
	refreshHeld(player)
end

-- The slot a hand ref points at, for other services.
function Inventory.slotAt(player: Player, ref: string): Types.Slot?
	local data = PlayerData.get(player)
	return if data then slotAt(data, ref) else nil
end

-- Whether every stack fits at once.
function Inventory.fits(player: Player, stacks: { Types.ItemStack }): boolean
	local result = Inventory.view(player)
	if result == nil then
		return false
	end
	for _, stack in stacks do
		local nextInventory, left = InventoryMath.add(result, stack.itemId, stack.count, Items)
		if left > 0 then
			return false
		end
		result = nextInventory
	end
	return true
end

--[[
	Adds as much of `stacks` as fits. Returns what was added and what was left
	over (callers decide what happens to leftovers). `source` names the
	analytics transaction ("Gathering", "Crafting", ...).
]]
function Inventory.give(
	player: Player,
	stacks: { Types.ItemStack },
	source: string?
): ({ Types.ItemStack }, { Types.ItemStack })
	local result = Inventory.view(player)
	if result == nil then
		return {}, stacks
	end
	local given: { Types.ItemStack } = {}
	local leftover: { Types.ItemStack } = {}
	for _, stack in stacks do
		local nextInventory, left = InventoryMath.add(result, stack.itemId, stack.count, Items)
		result = nextInventory
		if stack.count - left > 0 then
			table.insert(given, { itemId = stack.itemId, count = stack.count - left })
		end
		if left > 0 then
			table.insert(leftover, { itemId = stack.itemId, count = left })
		end
	end
	Inventory.commit(player, result)
	if source then
		for _, stack in given do
			Analytics.economy(
				player,
				"source",
				stack.itemId,
				stack.count,
				InventoryMath.count(result, stack.itemId),
				source
			)
		end
	end
	return given, leftover
end

-- Gives whole slots (keeping each one's durability). Returns what fit and what didn't.
function Inventory.giveSlots(player: Player, slots: { Types.Slot }): ({ Types.Slot }, { Types.Slot })
	local result = Inventory.view(player)
	if result == nil then
		return {}, slots
	end
	local given: { Types.Slot } = {}
	local leftover: { Types.Slot } = {}
	for _, slot in slots do
		local nextInventory, left = InventoryMath.addSlot(result, slot, Items)
		result = nextInventory
		if slot.count - left > 0 then
			table.insert(given, { itemId = slot.itemId, count = slot.count - left, durability = slot.durability })
		end
		if left > 0 then
			table.insert(leftover, { itemId = slot.itemId, count = left, durability = slot.durability })
		end
	end
	Inventory.commit(player, result)
	return given, leftover
end

-- Removes every stack atomically. Returns false (and changes nothing) if any is missing.
function Inventory.take(player: Player, stacks: { Types.ItemStack }, sink: string?): boolean
	local current = Inventory.view(player)
	if current == nil then
		return false
	end
	local result = InventoryMath.removeAll(current, stacks)
	if result == nil then
		return false
	end
	Inventory.commit(player, result)
	if sink then
		for _, stack in stacks do
			Analytics.economy(
				player,
				"sink",
				stack.itemId,
				stack.count,
				InventoryMath.count(result, stack.itemId),
				sink
			)
		end
	end
	return true
end

-- The active weapon slot (1 or 2) and its hand ref ("w1"/"w2"), or "" when it is empty.
local activeWeapon: { [Player]: number } = {}
local function weaponRef(player: Player): string
	local data = PlayerData.get(player)
	local n = activeWeapon[player] or 1
	local slot = if data then slotAt(data, `w{n}`) else nil
	return if slot and slot.count > 0 then `w{n}` else ""
end

-- What the player holds: "w1"/"w2", a tool ref while working, or "" (empty hands).
function Inventory.handRef(player: Player): string
	return held[player] or ""
end

-- Puts `ref` in the hand.
function Inventory.hold(player: Player, ref: string)
	if held[player] ~= ref then
		held[player] = ref
		Sync.mark(player, "inventory")
		refreshHeld(player)
	end
end

-- For an action (a swing, a pickup): holds `ref` now (a tool, or "" for bare hands),
-- and goes back to the active weapon once no action has happened for `seconds`
-- (3.2: swap to the tool, swap back).
local actionRestore: { [Player]: { untilClock: number } } = {}
function Inventory.holdForAction(player: Player, ref: string, seconds: number)
	local entry: { untilClock: number } = actionRestore[player] or { untilClock = 0 }
	actionRestore[player] = entry
	entry.untilClock = os.clock() + seconds
	Inventory.hold(player, ref)
	task.delay(seconds + 0.05, function()
		if actionRestore[player] == entry and os.clock() >= entry.untilClock then
			actionRestore[player] = nil
			Inventory.hold(player, weaponRef(player))
		end
	end)
end

-- Selects weapon slot 1 or 2 (4.9) and puts it in the hand.
local function selectWeapon(player: Player, n: number)
	if n ~= 1 and n ~= 2 then
		return
	end
	activeWeapon[player] = n
	actionRestore[player] = nil
	Inventory.hold(player, weaponRef(player))
	Sync.mark(player, "inventory")
end

local function swapWeapon(player: Player)
	selectWeapon(player, if (activeWeapon[player] or 1) == 1 then 2 else 1)
	Net.fireAllClients("Fx", "act", { userId = player.UserId, action = "swap" })
end

-- The UID of the crate the player has open, if any.
function Inventory.openStorage(player: Player): string?
	return openStorage[player]
end

-- Containers by ref ------------------------------------------------------------------------------

-- The backpack's size: the base, the equipped bag, and any slots bought (Backpack Upgrade).
local function bagSlots(equipment: { [string]: Types.Slot }, data: PlayerData): number
	local bag = equipment.bag
	local def = if bag and bag.count > 0 then Items[bag.itemId] else nil
	local bought = if data.purchases and data.purchases.backpackSlots then data.purchases.backpackSlots else 0
	return tuning.inventory.backpackSlots + (if def and def.bagSlots then def.bagSlots else 0) + bought
end

local function storageInReach(player: Player, uid: string): boolean
	local position = Plots.piecePosition(player, uid)
	return position ~= nil and Plots.withinArm(player, position, Plots.pieceRadius(player, uid))
end

-- The current container for a ref, or nil and a reason.
local function read(player: Player, data: PlayerData, ref: string): (Container?, string?)
	if ref == "pockets" then
		return data.inventory.pockets, nil
	elseif ref == "backpack" then
		return data.inventory.backpack, nil
	elseif ref == "equipment" then
		return Slots.fromEquipment(data.inventory.equipment :: any), nil
	end
	local uid = openStorage[player]
	if uid == nil or data.storage[uid] == nil or not storageInReach(player, uid) then
		return nil, "noStorage"
	end
	return data.storage[uid], nil
end

local function write(player: Player, data: PlayerData, ref: string, container: Container)
	if ref == "pockets" then
		data.inventory.pockets = container
	elseif ref == "backpack" then
		data.inventory.backpack = container
	elseif ref == "equipment" then
		data.inventory.equipment = Slots.toEquipment(container) :: any
	else
		local uid = openStorage[player]
		if uid then
			data.storage[uid] = container
			Sync.mark(player, "storage")
			Sync.mark(player, "pool") -- crates count toward home have/need (Services/Materials)
			Plots.setCrateIcon(player, uid, container)
		end
	end
end

local function sideFor(ref: string, container: Container): Slots.Side
	return { slots = container, accepts = if ref == "equipment" then Slots.equipmentAccepts() else nil }
end

--[[
	Applies new containers for the refs in `changed`, resizing the backpack to
	the equipped bag. Returns false (and writes nothing) when the resize is
	impossible.
]]
local function apply(player: Player, data: PlayerData, changed: { [string]: Container }): boolean
	if changed.equipment then
		local equipment = Slots.toEquipment(changed.equipment)
		local inventory = {
			pockets = changed.pockets or data.inventory.pockets,
			backpack = changed.backpack or data.inventory.backpack,
		}
		-- The Studio test base (Diagnostics) lends a bigger backpack; it must survive gear changes.
		local devSlots = player:GetAttribute("DevBackpackSlots")
		local slots = math.max(bagSlots(equipment, data), if type(devSlots) == "number" then devSlots else 0)
		local resized = InventoryMath.setBackpackCapacity(inventory, slots)
		if resized == nil then
			return false
		end
		changed.backpack = resized.backpack
	end
	for ref, container in changed do
		write(player, data, ref, container)
	end
	Sync.mark(player, "inventory")
	refreshHeld(player)
	return true
end

-- Remote handlers ----------------------------------------------------------------------------------

local function move(player: Player, fromRef: string, fromIndex: number, toRef: string, toIndex: number, count: number?)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	local fromContainer, why = read(player, data, fromRef)
	local toContainer, whyTo = read(player, data, toRef)
	if fromContainer == nil or toContainer == nil then
		Sync.notice(player, REASON_TEXT[why or whyTo or "badSlot"])
		return
	end
	local fromSide = sideFor(fromRef, fromContainer)
	local toSide = if toRef == fromRef then fromSide else sideFor(toRef, toContainer)
	local newFrom, newTo, reason = Slots.move(fromSide, fromIndex, toSide, toIndex, count, Items)
	if newFrom == nil or newTo == nil then
		if reason ~= "same" then
			Sync.notice(player, REASON_TEXT[reason or "badSlot"])
		end
		return
	end
	local changed: { [string]: Container } = { [fromRef] = newFrom }
	changed[toRef] = newTo
	if not apply(player, data, changed) then
		Sync.notice(player, REASON_TEXT.bagFull)
	elseif fromRef == "equipment" or toRef == "equipment" then
		Events.factsChanged:Fire(player) -- equip quest objectives
	end
end

local function split(player: Player, ref: string, index: number)
	local data = PlayerData.get(player)
	if data == nil or ref == "equipment" then
		return
	end
	local container, why = read(player, data, ref)
	if container == nil then
		Sync.notice(player, REASON_TEXT[why or "badSlot"])
		return
	end
	local result, reason = Slots.split(container, index)
	if result == nil then
		Sync.notice(player, REASON_TEXT[reason or "badSlot"])
		return
	end
	apply(player, data, { [ref] = result })
end

-- A copy of the slot at `index` of a carried container (pockets, backpack or the open
-- crate), or nil. Reads only.
function Inventory.peekSlot(player: Player, ref: string, index: number): Types.Slot?
	local data = PlayerData.get(player)
	if data == nil or ref == "equipment" then
		return nil
	end
	local container = read(player, data, ref)
	local slot = container and container[index]
	if slot == nil or slot.count <= 0 then
		return nil
	end
	return { itemId = slot.itemId, count = slot.count, durability = slot.durability }
end

-- Takes `count` items out of one slot (dragging part of a stack into a station). Returns
-- what was taken, or nil when the slot holds fewer.
function Inventory.takeFromSlot(player: Player, ref: string, index: number, count: number): Types.Slot?
	local data = PlayerData.get(player)
	if data == nil or ref == "equipment" or count <= 0 then
		return nil
	end
	local container = read(player, data, ref)
	local slot = container and container[index]
	if container == nil or slot == nil or slot.count < count then
		return nil
	end
	local result = table.clone(container)
	result[index] = if slot.count == count
		then InventoryMath.emptySlot()
		else { itemId = slot.itemId, count = slot.count - count, durability = slot.durability }
	apply(player, data, { [ref] = result })
	return { itemId = slot.itemId, count = count, durability = slot.durability }
end

-- Takes a whole slot out of the player's pockets, backpack or open crate (dropping
-- it on the ground). Returns the slot, or nil.
function Inventory.takeSlot(player: Player, ref: string, index: number): Types.Slot?
	local data = PlayerData.get(player)
	if data == nil or ref == "equipment" then
		return nil
	end
	local container = read(player, data, ref)
	local slot = container and container[index]
	if container == nil or slot == nil or slot.count <= 0 then
		return nil
	end
	local result = table.clone(container)
	result[index] = InventoryMath.emptySlot()
	apply(player, data, { [ref] = result })
	return { itemId = slot.itemId, count = slot.count, durability = slot.durability }
end

local function sort(player: Player, ref: string)
	local data = PlayerData.get(player)
	if data == nil or (ref ~= "backpack" and ref ~= "storage" and ref ~= "pockets") then
		return
	end
	local container, why = read(player, data, ref)
	if container == nil then
		Sync.notice(player, REASON_TEXT[why or "badSlot"])
		return
	end
	apply(player, data, { [ref] = Slots.sort(container, Items) })
end

local function transfer(player: Player, mode: string)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	local crate, why = read(player, data, "storage")
	if crate == nil then
		Sync.notice(player, REASON_TEXT[why or "noStorage"])
		return
	end
	local moved: number
	if mode == "takeAll" then
		local sources, targets, count = Slots.transfer(
			{ crate },
			{ data.inventory.pockets, data.inventory.backpack },
			Items
		)
		moved = count
		if count > 0 then
			apply(player, data, { storage = sources[1], pockets = targets[1], backpack = targets[2] })
		end
	else
		local sources, targets, count = Slots.transfer(
			{ data.inventory.backpack, data.inventory.pockets },
			{ crate },
			Items,
			Slots.putAllFilter(Items)
		)
		moved = count
		if count > 0 then
			apply(player, data, { backpack = sources[1], pockets = sources[2], storage = targets[1] })
		end
	end
	if moved == 0 then
		Sync.notice(player, if mode == "takeAll" then "Nothing fits in your bag" else "Nothing to put away", "info")
	else
		Sync.fx(player, "transfer", { mode = mode, count = moved })
	end
end

-- The crate brush (LDOE_PARITY #16): pins an item's icon on the open crate's lid, or nil
-- to go back to showing what it holds most of.
local function labelCrate(player: Player, itemId: string?)
	local data = PlayerData.get(player)
	local uid = openStorage[player]
	if data == nil or uid == nil or data.storage[uid] == nil or (itemId and Items[itemId] == nil) then
		return
	end
	(data :: any).storageLabels[uid] = itemId
	Plots.setCrateIcon(player, uid, data.storage[uid])
	Sync.fx(player, "crateLabel", { uid = uid, itemId = itemId })
end

local function openCrate(player: Player, uid: string?)
	if uid == nil then
		if openStorage[player] then
			openStorage[player] = nil
			Sync.mark(player, "storage")
		end
		return
	end
	local data = PlayerData.get(player)
	local plot = Plots.of(player)
	local piece = plot and plot.layout.pieces[uid]
	local def = piece and Content.BuildPieces[piece.pieceId]
	if data == nil or def == nil or def.kind ~= "storage" or data.storage[uid] == nil then
		Sync.notice(player, "That isn't your crate")
		return
	end
	if not storageInReach(player, uid) then
		Sync.notice(player, "Move closer to open it")
		return
	end
	openStorage[player] = uid
	Sync.mark(player, "storage")
end

local function use(player: Player, ref: string, index: number)
	local data = PlayerData.get(player)
	if data == nil or (ref ~= "pockets" and ref ~= "backpack") then
		return
	end
	local container = if ref == "pockets" then data.inventory.pockets else data.inventory.backpack
	local slot = container[index]
	if slot == nil or slot.count <= 0 then
		return
	end
	local def = Items[slot.itemId]
	if def == nil then
		return
	end

	if def.equipSlot then
		local name: string = def.equipSlot
		if name == "weapon" then
			-- The primary slot when it is free, else the secondary, else swap the primary.
			local equipment = data.inventory.equipment :: any
			if equipment.weapon.count > 0 and equipment.weapon2.count == 0 then
				name = "weapon2"
			end
		end
		local target = table.find(Slots.EQUIP_ORDER, name :: any) :: number
		move(player, ref, index, "equipment", target, nil)
		Inventory.hold(player, weaponRef(player))
		Events.factsChanged:Fire(player)
		return
	end

	local function spendOne(): boolean
		local current = Inventory.view(player)
		local after = current and InventoryMath.remove(current, slot.itemId, 1)
		if after == nil then
			return false
		end
		-- Take it from the slot that was used, not from wherever remove() would.
		local fresh = table.clone(container)
		if slot.count == 1 then
			fresh[index] = InventoryMath.emptySlot()
		else
			fresh[index] = { itemId = slot.itemId, count = slot.count - 1, durability = slot.durability }
		end
		apply(player, data, { [ref] = fresh })
		return true
	end

	if def.consume then
		if not Survival.canConsume(player, def.consume) then
			return
		end
		if spendOne() then
			Survival.consume(player, def.consume)
			Net.fireAllClients("Fx", "act", { userId = player.UserId, action = "eat" })
			Analytics.economy(player, "sink", slot.itemId, 1, 0, "Consume")
			Sync.fx(player, "consumed", { itemId = slot.itemId })
			Events.played:Fire(player, { kind = "consume", itemId = slot.itemId, count = 1 })
		end
		return
	end
	if def.category == "blueprint" then
		if data.unlocks.blueprints[slot.itemId] then
			Sync.notice(player, "You already know this. Recycle spares for parts.", "info")
			return
		end
		if spendOne() then
			data.unlocks.blueprints[slot.itemId] = true
			Sync.mark(player, "unlocks")
			Sync.notice(player, `Learned: {def.name}`, "good")
			Analytics.custom(player, "BlueprintRead", 1, { slot.itemId })
		end
	end
end

-- The meds button (4.9, LDOE_PARITY #1): uses what sits in the quick slot when it heals,
-- else the carried consumable that heals the most.
local function useMeds(player: Player)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	local equipment = data.inventory.equipment :: any
	local quick = equipment.quick
	local quickDef = if quick and quick.count > 0 then Items[quick.itemId] else nil
	if quickDef and quickDef.consume and (quickDef.consume.health or 0) > 0 then
		if Survival.canConsume(player, quickDef.consume) then
			equipment.quick = if quick.count > 1
				then { itemId = quick.itemId, count = quick.count - 1 }
				else InventoryMath.emptySlot()
			Sync.mark(player, "inventory")
			Survival.consume(player, quickDef.consume)
			Net.fireAllClients("Fx", "act", { userId = player.UserId, action = "eat" })
			Analytics.economy(player, "sink", quick.itemId, 1, 0, "Consume")
			Sync.fx(player, "consumed", { itemId = quick.itemId })
			Events.played:Fire(player, { kind = "consume", itemId = quick.itemId, count = 1 })
		end
		return
	end
	local bestRef, bestIndex, bestHeal = nil, 0, 0
	for _, ref in { "pockets", "backpack" } do
		local container = if ref == "pockets" then data.inventory.pockets else data.inventory.backpack
		for index, slot in container do
			local def = if slot.count > 0 then Items[slot.itemId] else nil
			local heal = if def and def.consume then def.consume.health or 0 else 0
			if heal > bestHeal then
				bestRef, bestIndex, bestHeal = ref, index, heal
			end
		end
	end
	if bestRef == nil then
		Sync.notice(player, "No meds", "info")
		return
	end
	use(player, bestRef, bestIndex)
end

-- Lifecycle -------------------------------------------------------------------------------------------

local function welcome(player: Player, data: PlayerData)
	if data.meta.loginCount == 1 then
		local granted, _ = Inventory.give(player, tuning.newPlayer.items, "NewPlayer")
		if #granted > 0 then
			Analytics.funnelStep(player, "Onboarding", 1, "FirstJoin")
		end
	end
	-- A bag equipped in an older save (and any slots bought) sets the backpack size.
	local inventory = { pockets = data.inventory.pockets, backpack = data.inventory.backpack }
	local resized = InventoryMath.setBackpackCapacity(inventory, bagSlots(data.inventory.equipment :: any, data))
	if resized then
		data.inventory.backpack = resized.backpack
	end
	Sync.mark(player, "inventory")
end

-- Puts a bag straight into the equipment slot and resizes the backpack (Studio test kit).
function Inventory.equipBag(player: Player, itemId: string)
	local data = PlayerData.get(player)
	if data == nil or Items[itemId] == nil or Items[itemId].bagSlots == nil then
		return
	end
	local equipment = data.inventory.equipment :: any
	equipment.bag = { itemId = itemId, count = 1 }
	local inventory = { pockets = data.inventory.pockets, backpack = data.inventory.backpack }
	local resized = InventoryMath.setBackpackCapacity(inventory, bagSlots(equipment, data))
	if resized then
		data.inventory.backpack = resized.backpack
	end
	Sync.mark(player, "inventory")
end

-- Resizes the backpack after slots were bought (Services/Shop); it only grows here.
function Inventory.refreshBackpack(player: Player)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	local inventory = { pockets = data.inventory.pockets, backpack = data.inventory.backpack }
	local resized = InventoryMath.setBackpackCapacity(inventory, bagSlots(data.inventory.equipment :: any, data))
	if resized then
		data.inventory.backpack = resized.backpack
		Sync.mark(player, "inventory")
	end
end

function Inventory.init()
	Net.onEvent("InventoryMove", move)
	Net.onEvent("InventorySplit", split)
	Net.onEvent("InventoryTransfer", transfer)
	Net.onEvent("InventorySort", sort)
	-- The trash button (checklist 4.11): the client confirms first; the slot is gone for good.
	Net.onEvent("InventoryDestroy", function(player: Player, ref: string, index: number)
		local slot = Inventory.takeSlot(player, ref, index)
		if slot then
			local def = Content.Items[slot.itemId]
			Sync.notice(player, `Destroyed {if def then def.name else slot.itemId} x{slot.count}`)
		end
	end)
	Net.onEvent("StorageOpen", openCrate)
	Net.onEvent("StorageLabel", labelCrate)
	Net.onEvent("UseItem", use)
	Net.onEvent("WeaponSelect", selectWeapon)
	Net.onEvent("WeaponSwap", swapWeapon)
	Net.onEvent("UseMeds", useMeds)
end

function Inventory.start()
	Sync.provide("inventory", function(player: Player)
		local data = PlayerData.get(player)
		if data == nil then
			return false
		end
		return {
			pockets = data.inventory.pockets,
			backpack = data.inventory.backpack,
			equipment = data.inventory.equipment,
			hand = held[player] or "",
			activeWeapon = activeWeapon[player] or 1,
		}
	end)
	Sync.provide("storage", function(player: Player)
		local data = PlayerData.get(player)
		local uid = openStorage[player]
		if data == nil or uid == nil or data.storage[uid] == nil then
			return false
		end
		local plot = Plots.of(player)
		local piece = plot and plot.layout.pieces[uid]
		return { uid = uid, pieceId = if piece then piece.pieceId else "", slots = data.storage[uid] }
	end)
	Sync.provide("unlocks", function(player: Player)
		local data = PlayerData.get(player)
		return if data then data.unlocks else false
	end)

	PlayerData.loaded:Connect(welcome)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			heldModels[player] = nil
			task.defer(refreshHeld, player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		held[player] = nil
		activeWeapon[player] = nil
		heldModels[player] = nil
		openStorage[player] = nil
	end)

	-- Close crates the player walked away from.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		for player, uid in openStorage do
			if not storageInReach(player, uid) then
				openStorage[player] = nil
				Sync.mark(player, "storage")
			end
		end
	end)
end

return Inventory
