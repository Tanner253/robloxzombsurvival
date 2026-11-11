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
local Animations = require("./Controllers/Animations")
local CombatControl = require("./Controllers/CombatControl")

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

-- Folds or unfolds the quest tracker (the « button, 8.9).
function Actions.toggleQuests()
	State.patch({ questCollapsed = not State.ui().questCollapsed })
	Sfx.play("uiClick")
end

-- The big weapon circle on a run: one attack (a tap is a light swing or one shot).
function Actions.attack()
	CombatControl.press()
	task.delay(0.05, CombatControl.release)
end

-- Held attack (the weapon circle on a run): a gun keeps firing at its cadence until release.
function Actions.attackDown()
	CombatControl.press()
end

function Actions.attackUp()
	CombatControl.release()
end

-- The Fog map (M, the HUD's Map button, or the Trailhead): plan and set out (11.1, 11.2).
function Actions.toggleFogMap()
	State.toggle("fogmap")
	if State.ui().panel ~= "fogmap" then
		State.clear("fogLocation")
	end
	Sfx.play(if State.ui().panel == "fogmap" then "uiOpen" else "uiClose")
end

-- The full-screen map of the Neighbourhood (a tap on the minimap at home, or M while the
-- Fog map is off; checklist 8.11).
function Actions.toggleAreaMap()
	State.toggle("areamap")
	Sfx.play(if State.ui().panel == "areamap" then "uiOpen" else "uiClose")
end

-- Run or Walk to a location (the Fog map's buttons). The server checks the Trailhead,
-- level, Energy and party.
function Actions.travel(locationId: string, mode: "run" | "walk")
	Net.fire("TravelStart", locationId, mode)
	Sfx.play("uiClick")
end

-- Takes one stack (or all) from the open container, pile or death bag (#45).
function Actions.takeLoot(index: number?)
	local loot = State.get("loot")
	if type(loot) ~= "table" then
		return
	end
	if loot.kind == "bag" then
		if index then
			Net.fire("BagTake", loot.id, loot.section or "backpack", index)
		else
			Net.fire("BagTakeAll", loot.id)
		end
	elseif index then
		Net.fire("ContainerTake", loot.id, index)
	else
		Net.fire("ContainerTakeAll", loot.id)
	end
	Sfx.play("pickup")
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

-- Closing the crafting catalogue clears its NEW badges (5.9).
local function seenRecipes()
	if State.ui().panel == "crafting" then
		Net.fire("RecipesSeen")
	end
end

-- The crafting catalogue (C, 5.9).
function Actions.toggleCrafting()
	seenInventory()
	seenRecipes()
	State.toggle("crafting")
	Sfx.play(if State.ui().panel == "crafting" then "uiOpen" else "uiClose")
end

-- Opens the shop (the menu bar, the inventory's "+", a moment-of-need offer), on a
-- product (outlined, on its tab) or a tab.
function Actions.openShop(focus: string?, tab: string?)
	local product = if focus then Content.Products[focus] else nil
	local onTab = tab or (if product then product.tab else nil) or "best"
	if focus == "product.starter_offer" or focus == "product.builders_crate" then
		onTab = "best"
	end
	State.patch({ shopFocus = focus, shopTab = onTab })
	if focus == nil then
		State.clear("shopFocus")
	end
	if State.ui().panel ~= "shop" then
		State.toggle("shop")
		Sfx.play("uiOpen")
	end
end

-- Asks the server to prompt a product (it checks the offer first; Services/Shop).
function Actions.buyProduct(productId: string)
	Net.fire("ShopBuy", productId)
	Sfx.play("uiClick")
end

function Actions.closePanel()
	seenInventory()
	seenRecipes()
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
	local on = not State.ui().auto
	Interaction.setAuto(on)
	-- On a run AUTO also fights the nearest Hollow (#31).
	local run = State.get("run")
	if type(run) == "table" then
		Net.fire("CombatAuto", on)
	end
	Sfx.play("uiClick")
end

-- Weapons (4.9, LDoE): two weapon slots, 1 and 2 select, F or the swap button swaps.
function Actions.selectWeapon(n: number)
	local inventory = State.get("inventory")
	if not inventory or inventory.activeWeapon == n then
		return
	end
	Net.fire("WeaponSelect", n)
	Animations.play(Players.LocalPlayer.Character, "swap")
	Sfx.play("swap")
end

function Actions.swapWeapon()
	Net.fire("WeaponSwap")
	Animations.play(Players.LocalPlayer.Character, "swap")
	Sfx.play("swap")
end

-- The meds button (H): the server uses the carried item that heals the most.
function Actions.useMeds()
	Net.fire("UseMeds")
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
	if type(State.get("loot")) == "table" then
		if mode == "takeAll" then
			Actions.takeLoot(nil)
		end
	elseif State.get("storage") then
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
