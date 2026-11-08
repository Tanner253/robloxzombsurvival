--!strict
--[[
	Actions: every player action, in one place, so keyboard shortcuts (the Input
	controller) and on-screen buttons (touch, and clicks on PC) do exactly the
	same thing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Net = require("./Net")
local Sfx = require("./Sfx")
local State = require("./State")
local Building = require("./Controllers/Building")
local Interaction = require("./Controllers/Interaction")

local Actions = {}

local tuning = Content.Tuning

-- Leaving the inventory marks everything in it as seen (clears NEW badges).
local function seenInventory()
	if State.ui().panel == "inventory" and next(State.ui().newItems) ~= nil then
		State.patch({ newItems = {} })
	end
end

function Actions.toggleInventory()
	seenInventory()
	State.toggle("inventory")
	Sfx.play(if State.ui().panel == "inventory" then "uiOpen" else "uiClose")
end

-- Opens the inventory on the item inbox (the Bag badge counts its rows, 4.15).
function Actions.openInbox()
	seenInventory()
	State.patch({ inventoryTab = "inbox" })
	if State.ui().panel ~= "inventory" then
		State.toggle("inventory")
		Sfx.play("uiOpen")
	end
end

function Actions.toggleSettings()
	State.toggle("settings")
	Sfx.play(if State.ui().panel == "settings" then "uiOpen" else "uiClose")
end

-- Applies settings at once (Controllers/Preferences reads the section) and saves
-- them after a short pause, so stepping a slider sends one request.
local pendingSave: thread? = nil
function Actions.saveSettings(settings: any)
	State.set("settings", settings)
	if pendingSave then
		task.cancel(pendingSave)
	end
	pendingSave = task.delay(0.6, function()
		pendingSave = nil
		Net.fire(
			"SaveSettings",
			settings.master,
			settings.music,
			settings.ambience,
			settings.sfx,
			settings.ui,
			settings.shake,
			settings.uiScale
		)
	end)
end

function Actions.toggleBuild()
	State.toggle("build")
	Sfx.play(if State.ui().panel == "build" then "uiOpen" else "uiClose")
end

function Actions.closePanel()
	seenInventory()
	if State.ui().panel ~= "none" then
		State.toggle(State.ui().panel, State.ui().stationUid)
		Sfx.play("uiClose")
	end
end

-- E / the touch action button.
function Actions.interact()
	if State.ui().panel == "build" then
		Building.confirm()
	else
		Interaction.activate()
	end
end

-- Holding the gather button (LMB, or the touch action button).
function Actions.setGathering(held: boolean)
	Interaction.setGathering(held)
end

-- AUTO: gather nearby nodes hands-free until the bag is full or none are left.
-- Free on the home plot; on Fog Runs this is a Shop lever (rewarded ad or pass), M1 step 11.
function Actions.toggleAuto()
	Interaction.setAuto(not State.ui().auto)
	Sfx.play("uiClick")
end

-- Number keys / hotbar clicks: food and drink are used, tools are held.
function Actions.hotbar(index: number)
	local inventory = State.get("inventory")
	if not inventory then
		return
	end
	local slot = inventory.pockets[index]
	local def = if slot and slot.count > 0 then Content.Items[slot.itemId] else nil
	if def and (def.consume or def.category == "blueprint") then
		Net.fire("UseItem", "pockets", index)
		return
	end
	Net.fire("HotbarSelect", if inventory.held == index then 0 else index)
	Sfx.play("uiClick")
end

-- Selects the next (+1) or previous (-1) filled pocket on the hotbar (mouse wheel).
function Actions.cycleHotbar(step: number)
	local inventory = State.get("inventory")
	if not inventory then
		return
	end
	local count = math.min(9, #inventory.pockets)
	local index = inventory.held or 0
	for _ = 1, count do
		index = (index + step - 1) % count + 1
		local slot = inventory.pockets[index]
		local def = if slot and slot.count > 0 then Content.Items[slot.itemId] else nil
		if def and (def.tool or def.weapon) then
			Net.fire("HotbarSelect", index)
			Sfx.play("uiHover")
			return
		end
	end
end

function Actions.setSprint(on: boolean)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if on then tuning.player.sprintSpeed else tuning.player.walkSpeed
	end
	if State.ui().sprinting ~= on then
		State.patch({ sprinting = on })
	end
end

function Actions.transfer(mode: "takeAll" | "putAll")
	if State.get("storage") then
		Net.fire("InventoryTransfer", mode)
	end
end

function Actions.selectPiece(pieceId: string)
	State.patch({ buildPiece = pieceId, buildMode = "place" })
	Sfx.play("uiClick")
end

function Actions.buildMode(mode: State.BuildMode)
	Building.setMode(mode)
	Sfx.play("uiClick")
end

function Actions.rotate()
	Building.rotate()
end

return Actions
