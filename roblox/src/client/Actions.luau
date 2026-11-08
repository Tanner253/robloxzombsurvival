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

function Actions.toggleInventory()
	State.toggle("inventory")
	Sfx.play(if State.ui().panel == "inventory" then "uiOpen" else "uiClose")
end

function Actions.toggleBuild()
	State.toggle("build")
	Sfx.play(if State.ui().panel == "build" then "uiOpen" else "uiClose")
end

function Actions.closePanel()
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
