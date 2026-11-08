--!strict
--[[
	UiGate: the automated UI overlap gate's driver (PLAYER_EXPERIENCE_CHECKLIST 4.19, 4.18).
	Studio only. A hard blocker for every report.

	Run it in a playtest: set the Workspace attribute "UIGate" to any new value (the
	tools/ui_gate.luau snippet does this through execute_luau and reads the result back).
	The client then, for each resolution profile (1920x1080, 1366x768, 2560x1440 and a
	844x390 touch phone with notch insets) and each screen state (the HUD idle, targeting,
	with low meters and toasts; the inventory alone, with a crate, with the inbox; every
	station; the hauler checklist; crafting; settings; build mode with piece actions; the
	storage, station-upgrade and destroy modals):
	1. holds the server's syncs and drives the screens with fixture state (State.hold),
	2. lays the App out for the profile (State.ui().gate),
	3. waits for React and the open animations, collects every visible element (UI/Gate)
	   and audits it (Domain/UiAudit): overlaps, clipped text, the safe area, Roblox's
	   reserved zones (the docked chat bar; the touch thumbstick and jump button) and
	   missing glyphs.
	Then it restores the real state and prints one "UIGATE {json}" line: every flag, and a
	count per profile and state. Zero flags is the pass.

	Every LDoE screen flag (Shared/Flags) is forced on for the run, so the gate checks the
	screens that will ship, not just the ones live today.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Content = require(ReplicatedStorage.Shared.Data)
local Converter = require(ReplicatedStorage.Shared.Domain.Converter)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local Quests = require(ReplicatedStorage.Shared.Domain.Quests)
local Shelter = require(ReplicatedStorage.Shared.Domain.Shelter)
local UiAudit = require(ReplicatedStorage.Shared.Domain.UiAudit)
local Inventory = require(ReplicatedStorage.Shared.Domain.Inventory)
local State = require("../State")
local Gate = require("../UI/Gate")
local Boundary = require("../UI/components/Boundary")
local Theme = require("../UI/theme")

local UiGate = {}

type Profile = {
	name: string,
	width: number,
	height: number,
	top: number,
	left: number,
	right: number,
	bottom: number,
	touch: boolean,
}

-- Roblox's top bar takes 58 px on PC (the 2023+ top bar); phones add notch insets.
local PROFILES: { Profile } = {
	{ name = "1920x1080", width = 1920, height = 1080, top = 58, left = 0, right = 0, bottom = 0, touch = false },
	{ name = "1366x768", width = 1366, height = 768, top = 58, left = 0, right = 0, bottom = 0, touch = false },
	{ name = "2560x1440", width = 2560, height = 1440, top = 58, left = 0, right = 0, bottom = 0, touch = false },
	{ name = "844x390 touch", width = 844, height = 390, top = 44, left = 47, right = 47, bottom = 21, touch = true },
}

local FLAGS = { "ldoeHud", "ldoeInventory", "ldoeStations", "ldoeBuild" }

-- Fixtures ----------------------------------------------------------------------------------------

local function slot(itemId: string, count: number, durability: number?): any
	return { itemId = itemId, count = count, durability = durability }
end

local function fixtureInventory(): any
	local pockets = Inventory.newContainer(Content.Tuning.inventory.pocketSlots)
	local backpack = Inventory.newContainer(10)
	local fill = {
		slot("item.timber", 20),
		slot("item.stone", 14),
		slot("item.stone_hatchet", 1, 31),
		slot("item.stone_pick", 1, 60),
		slot("item.fiber", 7),
		slot("item.boiled_water", 3),
		slot("item.field_dressing", 2),
		slot("item.scrap", 50),
		slot("item.sticks", 12),
		slot("item.emberberry", 9),
	}
	for index, entry in fill do
		pockets[index] = entry
	end
	backpack[1] = slot("item.plank", 18)
	backpack[2] = slot("item.rope", 5)
	backpack[3] = slot("item.murky_water", 4)
	local equipment = {
		head = slot("item.padded_hood", 1, 80),
		body = slot("", 0),
		legs = slot("", 0),
		feet = slot("", 0),
		weapon = slot("item.spiked_club", 1, 70),
		weapon2 = slot("item.stone_hatchet", 1, 40),
		bag = slot("item.pack_frame", 1),
		quick = slot("item.field_dressing", 3),
	}
	return { pockets = pockets, backpack = backpack, equipment = equipment, hand = "", activeWeapon = 1 }
end

local function fixtureStation(stationId: string): any
	local def = Content.Stations[stationId]
	local state = Converter.new(def, workspace:GetServerTimeNow() - 30)
	local lines = Converter.lines(def, Content.Recipes)
	local line = lines[1]
	if line then
		state.input = slot(line.inputItemId, if line.salvage then 1 else 12)
		state.output[1] = slot(line.outputs[1].itemId, 5)
		state.worked = 30
	end
	if def.fuel then
		state.fuel = slot("item.timber", 6)
		state.burnItem = "item.timber"
		state.burnLeft = 70
	end
	return state
end

local function fixtureQuests(): any
	local state = Quests.open(Quests.newState(), Content.Quests)
	state.completed["quest.first_light"] = 1
	state.completed["quest.tools_of_survival"] = 1
	state.active["quest.first_light"] = nil
	state.active["quest.tools_of_survival"] = nil
	state = Quests.open(state, Content.Quests)
	return Quests.record(state, Content.Quests, {}, { kind = "build", pieceId = "build.foundation_wood", count = 1 })
end

local function fixtureLayout(): any
	local cells = Content.Tuning.building.plotCells
	local plot: Grid.Plot = { ownerUserId = Players.LocalPlayer.UserId, width = cells, depth = cells }
	local layout = Shelter.build(Content.StarterShelter, Content.BuildPieces, plot, 1, os.time())
	return Grid.serialize(layout)
end

local function baseSections(): { [string]: any }
	return {
		inventory = fixtureInventory(),
		survival = {
			health = 84,
			maxHealth = 100,
			hunger = 64,
			thirst = 71,
			hungerMax = 100,
			thirstMax = 100,
			hungerDecay = 0,
			thirstDecay = 0,
			updatedAt = workspace:GetServerTimeNow(),
		},
		progression = { level = 7, xp = 3000 },
		quests = fixtureQuests(),
		inbox = {
			{ id = "i1", itemId = "item.sealed_tin", count = 2, source = "Quest", at = 0 },
			{ id = "i2", itemId = "item.timber", count = 10, source = "Quest", at = 0 },
			{ id = "i3", itemId = "item.ember_tonic", count = 1, source = "LevelUp", at = 0 },
		},
		storage = false,
		unlocks = { recipes = {}, blueprints = {} },
		projects = {},
	}
end

-- Screen states ----------------------------------------------------------------------------------

type Scene = { name: string, sections: { [string]: any }?, ui: { [string]: any } }

local function scenes(): { Scene }
	local list: { Scene } = {
		{ name = "hud", ui = { panel = "none" } },
		{ name = "hud.auto+sprint", ui = { panel = "none", auto = true, sprinting = true } },
		{
			name = "hud.lowMeters+toasts",
			sections = {
				survival = {
					health = 22,
					maxHealth = 100,
					hunger = 12,
					thirst = 8,
					hungerMax = 100,
					thirstMax = 100,
					hungerDecay = 0,
					thirstDecay = 0,
					updatedAt = workspace:GetServerTimeNow(),
				},
			},
			ui = {
				panel = "none",
				notices = {
					{
						id = 1,
						text = "Your bag is full. The rest dropped on the ground.",
						tone = "warn",
						at = os.clock(),
					},
				},
				rewards = { { id = 2, itemId = "item.timber", count = 4, at = os.clock() } },
			},
		},
		{ name = "hud.questsFolded", ui = { panel = "none", questCollapsed = true } },
		{ name = "inventory", ui = { panel = "inventory" } },
		{ name = "inventory.selected", ui = { panel = "inventory", selected = { ref = "pockets", index = 1 } } },
		{
			name = "inventory.crate",
			sections = {
				storage = {
					uid = "g1",
					pieceId = "build.crate_wood",
					slots = (function()
						local slots = Inventory.newContainer(15)
						slots[1] = slot("item.stone", 20)
						slots[2] = slot("item.timber", 13)
						return slots
					end)(),
				},
			},
			ui = { panel = "inventory" },
		},
		{ name = "inventory.inbox", ui = { panel = "inventory", inventoryTab = "inbox" } },
		{ name = "crafting", ui = { panel = "crafting" } },
		{ name = "settings", ui = { panel = "settings" } },
		{ name = "settings.credits", ui = { panel = "settings", settingsView = "credits" } },
		{ name = "shop", ui = { panel = "shop" } },
		{ name = "shop.focus", ui = { panel = "shop", shopFocus = "product.resource_pack" } },
		{ name = "project.hauler", ui = { panel = "project", projectId = "project.hauler" } },
		{ name = "build", ui = { panel = "build", buildMode = "place" } },
		{ name = "build.hint", ui = { panel = "build", buildMode = "place", buildHint = "Needs a Timber floor" } },
		{ name = "build.hideWalls", ui = { panel = "build", buildMode = "place", hideUpperWalls = true } },
	}
	for stationId in Content.Stations do
		table.insert(list, {
			name = `station.{stationId}`,
			sections = { stations = { g2 = fixtureStation(stationId) } },
			ui = { panel = "station", stationUid = "g2" },
		})
	end
	return list
end

-- Zones of Roblox's own UI, in screen pixels (checklist 4.18).
local function zones(profile: Profile, origin: Vector2, scale: number, panel: string): { UiAudit.Zone }
	local playing = panel == "none"
	local result: { UiAudit.Zone } = {}
	local hud = Theme.hud
	-- The docked chat bar (LDOE_PARITY #10): bottom left, right of AUTO, above the level bar.
	-- Only while playing: a panel or build mode hides chat (Controllers/Interface).
	local left = (hud.edge + hud.auto + Theme.spacing.md) * scale
	if playing then
		table.insert(result, {
			name = "Roblox chat bar",
			rect = {
				x = origin.X + profile.left + left,
				y = origin.Y + profile.height - profile.bottom - (hud.edge + 18 + 48) * scale,
				w = 300 * scale,
				h = 40 * scale,
			},
		})
	end
	-- Touch controls show while playing and building; a panel hides them (Interface).
	if profile.touch and (playing or panel == "build") then
		for _, zone in UiAudit.touchZones(profile.width, profile.height) do
			table.insert(result, {
				name = zone.name,
				rect = { x = origin.X + zone.rect.x, y = origin.Y + zone.rect.y, w = zone.rect.w, h = zone.rect.h },
			})
		end
	end
	return result
end

-- Running ----------------------------------------------------------------------------------------

local running = false

local function settle()
	-- React renders on the next frames; open animations take about 0.3 s.
	for _ = 1, 3 do
		RunService.RenderStepped:Wait()
	end
	task.wait(0.45)
end

local function run()
	if running then
		return
	end
	running = true
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local app = playerGui:FindFirstChild("App") :: ScreenGui?
	if app == nil then
		running = false
		return
	end
	local savedUi = table.clone(State.ui())
	local savedSections: { [string]: any } = {}
	local savedFlags: { [string]: any } = {}
	for _, name in FLAGS do
		savedFlags[name] = workspace:GetAttribute(`Flag_{name}`)
		workspace:SetAttribute(`Flag_{name}`, true)
	end
	State.hold(true)

	local base = baseSections()
	local touched: { [string]: boolean } = {}
	local function setSection(name: string, value: any)
		if not touched[name] then
			touched[name] = true
			savedSections[name] = State.get(name)
		end
		State.set(name, value)
	end
	setSection("layout", fixtureLayout())

	local report = { flags = {} :: { any }, counts = {} :: { [string]: number }, elements = 0 }
	for _, profile in PROFILES do
		for _, scene in scenes() do
			for name, value in base do
				setSection(name, value)
			end
			local sections: { [string]: any } = scene.sections or {}
			for name, value in sections do
				setSection(name, value)
			end
			State.patch({
				gate = {
					width = profile.width,
					height = profile.height,
					top = profile.top,
					left = profile.left,
					right = profile.right,
					bottom = profile.bottom,
					touch = profile.touch,
				},
				touch = profile.touch,
				notices = {},
				rewards = {},
				newItems = {},
			})
			State.clear(
				"selected",
				"stationUid",
				"projectId",
				"buildHint",
				"pieceActions",
				"inventoryTab",
				"shopFocus",
				"settingsView"
			)
			table.clear(Boundary.failures)
			State.patch(scene.ui)
			settle()
			-- The emulated screen's origin: the App frame sits at the safe area's corner.
			local root = app:FindFirstChildOfClass("Frame")
			local origin = if root then root.AbsolutePosition - Vector2.new(profile.left, profile.top) else Vector2.zero
			local scale = Theme.currentScale
			local safe = {
				x = origin.X + profile.left,
				y = origin.Y + profile.top,
				w = profile.width - profile.left - profile.right,
				h = profile.height - profile.top - profile.bottom,
			}
			local flags, count = Gate.audit(safe, zones(profile, origin, scale, State.ui().panel))
			report.elements += count
			local failed = 0
			-- A screen that crashed draws nothing, so it has nothing to overlap: fail it.
			local broken = table.clone(Boundary.down)
			for name, err in Boundary.failures do
				broken[name] = err
			end
			for name, err in broken do
				failed += 1
				table.insert(
					report.flags,
					`{profile.name} | {scene.name} | failed: screen '{name}' ({string.sub(err, 1, 160)})`
				)
			end
			report.counts[`{profile.name} | {scene.name}`] = #flags + failed
			for _, flag in flags do
				table.insert(report.flags, `{profile.name} | {scene.name} | {UiAudit.describe(flag)}`)
			end
		end
	end

	-- Put everything back.
	State.clear("gate")
	State.patch({
		panel = savedUi.panel,
		touch = savedUi.touch,
		auto = savedUi.auto,
		sprinting = savedUi.sprinting,
		questCollapsed = savedUi.questCollapsed,
		hideUpperWalls = savedUi.hideUpperWalls,
	})
	State.clear(
		"selected",
		"stationUid",
		"projectId",
		"buildHint",
		"pieceActions",
		"inventoryTab",
		"shopFocus",
		"settingsView"
	)
	for name in touched do
		State.set(name, savedSections[name])
	end
	State.hold(false)
	for name, value in savedFlags do
		workspace:SetAttribute(`Flag_{name}`, value)
	end
	for _, name in FLAGS do
		if savedFlags[name] == nil then
			workspace:SetAttribute(`Flag_{name}`, nil)
		end
	end
	local json = HttpService:JSONEncode({
		pass = #report.flags == 0,
		flagCount = #report.flags,
		elements = report.elements,
		flags = report.flags,
		counts = report.counts,
	})
	print(`UIGATE {json}`)
	-- Also kept on the local player (UiGateResult), for tools whose console view truncates.
	Players.LocalPlayer:SetAttribute("UiGateResult", json)
	running = false
end

function UiGate.start()
	if not RunService:IsStudio() then
		return
	end
	workspace:GetAttributeChangedSignal("UIGate"):Connect(function()
		task.spawn(run)
	end)
end

return UiGate
