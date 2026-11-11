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

export type Panel =
	"none"
	| "inventory"
	| "station"
	| "build"
	| "settings"
	| "crafting"
	| "project"
	| "shop"
	| "haven"
	| "fogmap"
export type BuildMode = "place" | "upgrade" | "demolish"
export type Tone = "info" | "good" | "warn"

export type Target = {
	kind: "node" | "station" | "storage" | "drop" | "container" | "bag" | "exit" | "haven",
	key: string, -- node key, piece UID, drop id, container or bag id, or Haven Square HavenId
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
	questCollapsed: boolean?, -- the quest tracker folded to one line (8.9)
	projectId: string?, -- the project whose parts checklist is open (panel "project")
	fogLocation: string?, -- the Fog map's chosen location, its panel open (panel "fogmap")
	hideUpperWalls: boolean?, -- build mode's top-left toggle (LDOE_PARITY #25)
	pieceActions: string?, -- build mode: the placed piece whose floating actions show (#27)
	shopFocus: string?, -- the product a moment-of-need button opened the shop on
	settingsView: string?, -- the Settings sheet's page: nil (settings) or "credits"
	guide: string?, -- the HUD button the first-session guide points at: "craft", "build", "inventory", "map"
	guideLocation: string?, -- the location the guide sends you to (the Fog map marks its pin and Run)
	shopTab: string?, -- the shop's tab: "best" (default), "supplies", "equipment", "building", "embers", "passes"
	-- An Ember purchase waiting for BUY (screens/ldoe/EmberConfirm): what, the price, and
	-- what BUY does.
	emberAsk: { title: string, text: string, price: number, run: () -> () }?,
	-- The last Run the server refused for Energy ("energyShort"): how much was missing, and
	-- when (os.clock()), for the Fog map's Refill slot (UI/offers.energyChip).
	energyShort: { need: number, at: number }?,
	havenId: string?, -- who or what on Haven Square the "haven" panel is talking to
	havenTab: string?, -- the Trader's tab: "buy" (default) or "sell"
	-- The UI gate's emulated screen (Controllers/UiGate): the App lays out for this size
	-- and safe-area insets instead of the real window.
	gate: { width: number, height: number, top: number, left: number, right: number, bottom: number, touch: boolean }?,
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

-- While held (the UI gate drives fixtures), server syncs wait and land on release.
local held = false
local pending: { [string]: any } = {}

function State.hold(on: boolean)
	held = on
	if not on then
		local waiting = pending
		pending = {}
		for section, value in waiting do
			State.set(section, value)
		end
	end
end

-- Whether a Fog Run's full-screen moment is up (the death screen, the results card or the
-- run loading screen): like a full-screen panel, it hides the touch controls and chat.
function State.fullScreenMoment(): boolean
	if type(State.get("death")) == "table" then
		return true
	end
	if type(State.get("result")) == "table" and type(State.get("run")) ~= "table" then
		return true
	end
	local travel = State.get("travel")
	if type(travel) == "table" then
		local arrived = type(travel.arrivesAt) == "number" and State.now() >= travel.arrivesAt
		return travel.mode == "run" or travel.matching == true or arrived
	end
	return false
end

-- Whether the UI gate holds the state (controllers leave fixture sections alone).
function State.isHeld(): boolean
	return held
end

-- A server sync: applied now, or kept until the hold ends.
function State.receive(section: string, value: any)
	if held then
		pending[section] = value
	else
		State.set(section, value)
	end
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
