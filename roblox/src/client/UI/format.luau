--!strict
-- format: player-facing number and time text.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)

local format = {}

-- 75 -> "1m 15s", 3700 -> "1h 01m", 9 -> "9s".
function format.duration(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	if s >= 3600 then
		return string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
	elseif s >= 60 then
		return string.format("%dm %02ds", s // 60, s % 60)
	end
	return `{s}s`
end

-- The total count of an item across pockets and backpack in a synced inventory.
function format.count(inventory: any, itemId: string): number
	if not inventory then
		return 0
	end
	local total = 0
	for _, container in { inventory.pockets, inventory.backpack } do
		for _, slot in container or {} do
			if slot.itemId == itemId then
				total += slot.count
			end
		end
	end
	return total
end

function format.itemName(itemId: string): string
	local def = Content.Items[itemId]
	return if def then def.name else itemId
end

-- "Timber ×4"
function format.stack(itemId: string, count: number): string
	return `{format.itemName(itemId)} ×{count}`
end

return format
