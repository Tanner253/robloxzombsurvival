--!strict
--[[
	State: the client's store. Two kinds of state:
	- sections: read-only copies of the server's synced state ("inventory",
	  "stations", "layout", ...), replaced whole whenever the server sends them;
	- ui: what this client is doing (open panel, selection, build mode, the
	  current interaction target, toasts and rewards).

	Controllers and screens read State and send intents through Net; nothing
	here is trusted by the server. React components subscribe with the hooks in
	UI/hooks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.Packages.Signal)

local State = {}

export type Panel = "none" | "inventory" | "station" | "build" | "settings" | "crafting"
export type BuildMode = "place" | "upgrade" | "demolish"
export type Tone = "info" | "good" | "warn"

export type Target = {
	kind: "node" | "station" | "storage" | "drop",
	key: string, -- node key, piece UID or drop id
	label: string,
	verb: string, -- "Chop", "Open", ...
	model: Model,
	hitsLeft: number?,
	hits: number?,
}

export type Selection = { ref: string, index: number }

export type Notice = { id: number, text: string, tone: Tone, at: number }
export type Reward = { id: number, itemId: string, count: number, at: number }

export type Ui = {
	panel: Panel,
	stationUid: string?,
	selected: Selection?,
	hovered: Selection?,
	buildPiece: string?,
	buildMode: BuildMode,
	buildHint: string?,
	target: Target?,
	notices: { Notice },
	rewards: { Reward },
	levelUp: { level: number, rewards: { any }, at: number }?,
	sprinting: boolean,
	auto: boolean, -- AUTO gather is on
	touch: boolean,
	newItems: { [string]: boolean }, -- item ids gained since the inventory was last opened
	bagFullAt: number?, -- os.clock() of the last "bag is full", for the Bag button flash
	inventoryTab: string?, -- the inventory's right pane: "crafting" (default) or "inbox"
}

-- Fires (key) when a section or "ui" changes.
State.changed = Signal.new()
-- Fires (kind, payload) for every server effect (Sync.fx).
State.fx = Signal.new()

local sections: { [string]: any } = {}

local ui: Ui = {
	panel = "none",
	stationUid = nil,
	selected = nil,
	hovered = nil,
	buildPiece = nil,
	buildMode = "place",
	buildHint = nil,
	target = nil,
	notices = {},
	rewards = {},
	levelUp = nil,
	sprinting = false,
	auto = false,
	touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
	newItems = {},
	bagFullAt = nil,
}

local nextId = 0

-- A synced section's latest value (nil until it arrives; false when the server has none).
function State.get(section: string): any
	return sections[section]
end

function State.set(section: string, value: any)
	sections[section] = value
	State.changed:Fire(section)
end

function State.ui(): Ui
	return ui
end

-- Merges `patch` into the UI state (fields set to nil are not cleared; use `clear`).
function State.patch(patch: { [string]: any })
	local fresh = table.clone(ui) :: any
	for key, value in patch do
		fresh[key] = value
	end
	ui = fresh
	State.changed:Fire("ui")
end

-- Clears optional UI fields, e.g. State.clear("selected", "target").
function State.clear(...: string)
	local fresh = table.clone(ui) :: any
	for _, key in { ... } do
		fresh[key] = nil
	end
	ui = fresh
	State.changed:Fire("ui")
end

-- Opens one panel (closing the others), or closes it when it is already open.
function State.toggle(panel: Panel, stationUid: string?)
	if ui.panel == panel and (panel ~= "station" or ui.stationUid == stationUid) then
		State.patch({ panel = "none" })
		State.clear("stationUid", "selected", "buildPiece", "buildHint")
	else
		State.patch({ panel = panel, stationUid = stationUid, buildMode = "place" })
		State.clear("selected")
	end
end

function State.notify(text: string, tone: Tone?)
	nextId += 1
	local list: { Notice } = table.clone(ui.notices)
	local notice: Notice = { id = nextId, text = text, tone = tone or "warn", at = os.clock() }
	table.insert(list, notice)
	while #list > 4 do
		table.remove(list, 1)
	end
	State.patch({ notices = list })
end

local REWARD_MERGE_SECONDS = 2.5

-- Marks an item as new (NEW badge on its slots and the Bag button) until the inventory is seen.
function State.markNew(itemId: string)
	if not ui.newItems[itemId] then
		local items = table.clone(ui.newItems)
		items[itemId] = true
		State.patch({ newItems = items })
	end
end

function State.reward(itemId: string, count: number)
	local list: { Reward } = table.clone(ui.rewards)
	local now = os.clock()
	-- The same item again while its card is still up adds to that card ("+4 Fieldstone").
	for index, existing in list do
		if existing.itemId == itemId and now - existing.at < REWARD_MERGE_SECONDS then
			list[index] = { id = existing.id, itemId = itemId, count = existing.count + count, at = now }
			State.patch({ rewards = list })
			return
		end
	end
	nextId += 1
	local reward: Reward = { id = nextId, itemId = itemId, count = count, at = now }
	table.insert(list, reward)
	while #list > 6 do
		table.remove(list, 1)
	end
	State.patch({ rewards = list })
end

-- Server time in seconds (the clock every synced timestamp uses).
function State.now(): number
	return workspace:GetServerTimeNow()
end

return State
