--!strict
--[[
	Inventory: server-authoritative pockets, backpack, equipment, storage crates
	and the locked stash (ARCHITECTURE.md §6; M1 step 1).

	Clients only send intents (InventoryMove, InventorySplit, InventoryTransfer,
	UseItem, StorageOpen, HotbarSelect); every rule is in Domain/Slots and
	Domain/Inventory. A bag in the equipment's bag slot sets the backpack size;
	removing it is refused while the slots it adds hold anything.

	Other services change items through `give`, `take`, `commit` and
	`setPocket`, never by writing PlayerData directly, so every change is synced.
	The held hotbar slot is shown in the character's hand.
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

local held: { [Player]: number } = {}
local heldModels: { [Player]: Model } = {}
local openStorage: { [Player]: string } = {}

local REASON_TEXT: { [string]: string } = {
	empty = "Nothing there",
	badSlot = "That slot doesn't exist",
	wrongSlot = "That doesn't go there",
	noSpace = "No room there",
	count = "Can't split that",
	bagFull = "Empty the bag's slots before taking it off",
	stashIn = "The locked stash only gives items out",
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

local function refreshHeld(player: Player)
	local data = PlayerData.get(player)
	local character = player.Character
	local index = held[player] or 0
	local slot = if data and index > 0 then data.inventory.pockets[index] else nil
	local itemId = if slot and slot.count > 0 then slot.itemId else ""

	local current = heldModels[player]
	if current and current:GetAttribute("ItemId") == itemId and current.Parent ~= nil then
		return
	end
	if current then
		current:Destroy()
		heldModels[player] = nil
	end
	if itemId == "" or character == nil then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand == nil or not hand:IsA("BasePart") then
		return
	end
	local model = Models.held(itemId, Items[itemId])
	if model == nil then
		return
	end
	model.Name = "Held"
	model:SetAttribute("ItemId", itemId)
	local grip = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local gripCFrame = (if grip then grip.CFrame else CFrame.new(0, -1, 0)) * CFrame.Angles(math.rad(-90), 0, 0)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	model:PivotTo(hand.CFrame * gripCFrame)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hand
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	model.Parent = character
	heldModels[player] = model
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

-- The pocket index the player holds (0 for empty hands).
function Inventory.heldIndex(player: Player): number
	return held[player] or 0
end

-- Holds pocket `index` in hand (Gathering holds the tool it swings with).
function Inventory.hold(player: Player, index: number)
	if held[player] ~= index then
		held[player] = index
		Sync.mark(player, "inventory")
		refreshHeld(player)
	end
end

-- The UID of the crate the player has open, if any.
function Inventory.openStorage(player: Player): string?
	return openStorage[player]
end

-- Puts stacks into the locked stash (level rewards that did not fit). Returns leftovers.
function Inventory.stash(player: Player, stacks: { Types.ItemStack }): { Types.ItemStack }
	local data = PlayerData.get(player)
	if data == nil then
		return stacks
	end
	local containers = { data.lockedStash }
	local leftover: { Types.ItemStack } = {}
	for _, stack in stacks do
		local after, left = Slots.addTo(containers, { itemId = stack.itemId, count = stack.count }, Items)
		containers = after
		if left > 0 then
			table.insert(leftover, { itemId = stack.itemId, count = left })
		end
	end
	data.lockedStash = containers[1]
	Sync.mark(player, "stash")
	return leftover
end

-- Containers by ref ------------------------------------------------------------------------------

local function bagSlots(equipment: { [string]: Types.Slot }): number
	local bag = equipment.bag
	local def = if bag and bag.count > 0 then Items[bag.itemId] else nil
	return tuning.inventory.backpackSlots + (if def and def.bagSlots then def.bagSlots else 0)
end

local function storageInReach(player: Player, uid: string): boolean
	local position = Plots.piecePosition(player, uid)
	return position ~= nil and Plots.inReach(player, position, tuning.interaction.reachStuds + 2)
end

-- The current container for a ref, or nil and a reason.
local function read(player: Player, data: PlayerData, ref: string): (Container?, string?)
	if ref == "pockets" then
		return data.inventory.pockets, nil
	elseif ref == "backpack" then
		return data.inventory.backpack, nil
	elseif ref == "equipment" then
		return Slots.fromEquipment(data.inventory.equipment :: any), nil
	elseif ref == "stash" then
		return data.lockedStash, nil
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
	elseif ref == "stash" then
		data.lockedStash = container
		Sync.mark(player, "stash")
	else
		local uid = openStorage[player]
		if uid then
			data.storage[uid] = container
			Sync.mark(player, "storage")
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
		local resized = InventoryMath.setBackpackCapacity(inventory, bagSlots(equipment))
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
	if toRef == "stash" and fromRef ~= "stash" then
		Sync.notice(player, REASON_TEXT.stashIn)
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
	end
end

local function split(player: Player, ref: string, index: number)
	local data = PlayerData.get(player)
	if data == nil or ref == "equipment" or ref == "stash" then
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
		local target = table.find(Slots.EQUIP_ORDER, def.equipSlot) :: number
		move(player, ref, index, "equipment", target, nil)
		return
	end
	if def.tool and ref == "pockets" then
		held[player] = if held[player] == index then 0 else index
		Sync.mark(player, "inventory")
		refreshHeld(player)
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
			Analytics.economy(player, "sink", slot.itemId, 1, 0, "Consume")
			Sync.fx(player, "consumed", { itemId = slot.itemId })
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

local function hold(player: Player, index: number)
	local pockets = Inventory.view(player)
	if pockets == nil or index > #pockets.pockets then
		return
	end
	held[player] = index
	Sync.mark(player, "inventory")
	refreshHeld(player)
end

-- Lifecycle -------------------------------------------------------------------------------------------

local function welcome(player: Player, data: PlayerData)
	if data.meta.loginCount == 1 then
		local granted, _ = Inventory.give(player, tuning.newPlayer.items, "NewPlayer")
		if #granted > 0 then
			Analytics.funnelStep(player, "Onboarding", 1, "FirstJoin")
		end
	end
	-- A bag equipped in an older save sets the backpack size.
	local inventory = { pockets = data.inventory.pockets, backpack = data.inventory.backpack }
	local resized = InventoryMath.setBackpackCapacity(inventory, bagSlots(data.inventory.equipment :: any))
	if resized then
		data.inventory.backpack = resized.backpack
	end
	Sync.mark(player, "inventory")
end

function Inventory.init()
	Net.onEvent("InventoryMove", move)
	Net.onEvent("InventorySplit", split)
	Net.onEvent("InventoryTransfer", transfer)
	Net.onEvent("StorageOpen", openCrate)
	Net.onEvent("UseItem", use)
	Net.onEvent("HotbarSelect", hold)
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
			held = held[player] or 0,
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
	Sync.provide("stash", function(player: Player)
		local data = PlayerData.get(player)
		return if data then data.lockedStash else false
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
