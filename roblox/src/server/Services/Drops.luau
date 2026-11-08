--!strict
--[[
	Drops: item bags on the ground. When a swing yields more than the bag can
	hold, the overflow lands beside the node as a drop (LDoE leaves a loot bag),
	and items dropped from the inventory land at the player's feet.

	Dropped slots keep their durability. A drop belongs to the player who made it, shows as a small sack tagged
	EO_Drop (attributes DropId, OwnerUserId, Label), and is picked up with the
	PickupDrop remote from within reach. Whatever still doesn't fit stays on the
	ground. Drops vanish after Tuning.drops.lifetimeSeconds or when the owner
	leaves.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Types = require(ReplicatedStorage.Shared.Types)
local Net = require("../Net")
local Models = require("../World/Models")
local Inventory = require("./Inventory")
local Sync = require("./Sync")

local Drops = {}

Drops.TAG = "EO_Drop"

type Drop = {
	id: string,
	owner: Player,
	items: { Types.Slot }, -- whole slots, so dropped tools keep their durability
	model: Model,
	expiresAt: number,
}

local tuning = Content.Tuning
local drops: { [string]: Drop } = {}
local nextId = 0
local MERGE_STUDS = 5

local function folder(): Folder
	local world = workspace:FindFirstChild("World") or workspace
	local existing = world:FindFirstChild("Drops")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "Drops"
	made.Parent = world
	return made
end

local function label(items: { Types.Slot }): string
	local parts: { string } = {}
	for index, stack in items do
		if index > 2 then
			table.insert(parts, `+{#items - 2} more`)
			break
		end
		local def = Content.Items[stack.itemId]
		table.insert(parts, `{if def then def.name else stack.itemId} x{stack.count}`)
	end
	return table.concat(parts, ", ")
end

local function remove(drop: Drop)
	drops[drop.id] = nil
	drop.model:Destroy()
end

-- Puts `stacks` on the ground at `position` for `player`. Returns the drop's id.
function Drops.spawn(player: Player, position: Vector3, stacks: { Types.Slot }): string?
	local items: { Types.Slot } = {}
	for _, stack in stacks do
		if stack.count > 0 then
			table.insert(items, { itemId = stack.itemId, count = stack.count, durability = stack.durability })
		end
	end
	if #items == 0 then
		return nil
	end
	-- Overflow from the same spot piles into one bag instead of littering.
	for _, drop in drops do
		local offset = drop.model:GetPivot().Position - position
		if drop.owner == player and Vector3.new(offset.X, 0, offset.Z).Magnitude <= MERGE_STUDS then
			for _, stack in items do
				local merged = false
				for _, existing in drop.items do
					if existing.itemId == stack.itemId and existing.durability == nil and stack.durability == nil then
						existing.count += stack.count
						merged = true
						break
					end
				end
				if not merged then
					table.insert(drop.items, stack)
				end
			end
			drop.model:SetAttribute("Label", label(drop.items))
			drop.expiresAt = os.clock() + tuning.drops.lifetimeSeconds
			return drop.id
		end
	end
	nextId += 1
	local id = `d{nextId}`
	local model = Models.drop()
	model.Name = id
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder() }
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), params)
	local ground = if hit then hit.Position else position
	model:PivotTo(CFrame.new(ground) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	model:SetAttribute("DropId", id)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Label", label(items))
	CollectionService:AddTag(model, Drops.TAG)
	model.Parent = folder()
	drops[id] = {
		id = id,
		owner = player,
		items = items,
		model = model,
		expiresAt = os.clock() + tuning.drops.lifetimeSeconds,
	}
	return id
end

local function pickup(player: Player, id: string)
	local drop = drops[id]
	if drop == nil or drop.owner ~= player then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local offset = root.Position - drop.model:GetPivot().Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > tuning.interaction.reachStuds + 2 then
		return
	end
	local given, leftover = Inventory.giveSlots(player, drop.items)
	if #given == 0 then
		Sync.notice(player, "Your bag is full")
		return
	end
	Sync.fx(player, "items", { items = given, source = "pickup" })
	Net.fireAllClients("Fx", "act", { userId = player.UserId, action = "pickup" })
	if #leftover == 0 then
		remove(drop)
	else
		drop.items = leftover
		drop.model:SetAttribute("Label", label(leftover))
		Sync.notice(player, "Your bag is full; the rest is still on the ground")
	end
end

-- Drops a whole slot from the inventory (or open crate) just in front of the player.
local function dropFromInventory(player: Player, ref: string, index: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local slot = Inventory.takeSlot(player, ref, index)
	if slot then
		Drops.spawn(player, root.Position + root.CFrame.LookVector * 3, { slot })
	end
end

function Drops.init()
	Net.onEvent("PickupDrop", pickup)
	Net.onEvent("InventoryDrop", dropFromInventory)
end

function Drops.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		for _, drop in drops do
			if drop.owner == player then
				remove(drop)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for _, drop in drops do
				if now >= drop.expiresAt then
					remove(drop)
				end
			end
		end
	end)
end

return Drops
