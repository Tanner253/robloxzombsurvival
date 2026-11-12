--!strict
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Combat = require("../src/shared/Domain/Combat")
local Hands = require("../src/shared/Domain/Hands")
local Inventory = require("../src/shared/Domain/Inventory")

local T0 = 100
local CONFIG = Content.Tuning.hands
local ITEMS: Hands.ItemLookup = Content.Items :: any

local function loaded(state: Hands.State, index: number): number
	local gun = state.hands[index].gun
	return if gun then gun.loaded else -1
end

return function(test: TestKit.Register)
	test("two slots from the paper-doll; slot 1 starts active; guns start loaded", function()
		local state = Hands.new({ "item.pipe_pistol", "item.machete" }, ITEMS, CONFIG)
		TestKit.equal(#state.hands, 2)
		TestKit.equal(state.active, 1)
		TestKit.equal(Hands.active(state).itemId, "item.pipe_pistol")
		local magazine = (Content.Items["item.pipe_pistol"] :: any).weapon.firearm.magazine
		TestKit.equal(loaded(state, 1), magazine, "a gun has its own magazine, full: the first pull fires")
		TestKit.equal(state.hands[2].gun, nil, "melee has none")
		TestKit.equal(Hands.weapon(state, ITEMS), (Content.Items["item.pipe_pistol"] :: any).weapon)
		local empty = Hands.new({}, ITEMS, CONFIG)
		TestKit.equal(Hands.weapon(empty, ITEMS), nil, "bare fists")
	end)

	test("1 and 2 select, F swaps; the raised weapon takes its swap time", function()
		local state = Hands.new({ "item.machete", "item.scrap_shotgun" }, ITEMS, CONFIG)
		local same, reason = Hands.select(state, 1, T0, ITEMS, CONFIG)
		TestKit.equal(reason, "same")
		TestKit.equal(same, state)
		local _, bad = Hands.select(state, 3, T0, ITEMS, CONFIG)
		TestKit.equal(bad, "badSlot")
		local swapped = Hands.swap(state, T0, ITEMS, CONFIG)
		TestKit.equal(swapped.active, 2)
		local shotgunSwap = (Content.Items["item.scrap_shotgun"] :: any).weapon.swapSeconds
		TestKit.equal(swapped.swapEndsAt, T0 + shotgunSwap, "the shotgun's own swap time")
		TestKit.equal(Hands.ready(swapped, T0 + shotgunSwap - 0.01), false, "no firing mid-swap")
		TestKit.equal(Hands.ready(swapped, T0 + shotgunSwap), true)
		local back = Hands.swap(swapped, T0 + 1, ITEMS, CONFIG)
		TestKit.equal(back.active, 1)
		TestKit.equal(back.swapEndsAt, T0 + 1 + CONFIG.swapSeconds, "the default for the machete")
	end)

	test("each slot keeps its rounds across swaps; swapping cancels a reload", function()
		local pistol = (Content.Items["item.pipe_pistol"] :: any).weapon.firearm
		local state = Hands.new({ "item.pipe_pistol", "item.scrap_shotgun" }, ITEMS, CONFIG)
		state = Hands.setGun(state, Combat.newGun(1))
		local reloading = Combat.startReload(pistol, Combat.newGun(0), T0) :: Combat.Gun
		local inSlot2 = Hands.swap(state, T0, ITEMS, CONFIG)
		inSlot2 = Hands.setGun(inSlot2, reloading)
		local backTo1 = Hands.swap(inSlot2, T0 + 0.2, ITEMS, CONFIG)
		TestKit.equal(loaded(backTo1, 1), 1, "the pistol kept its round")
		TestKit.equal((backTo1.hands[2].gun :: Combat.Gun).reloadEndsAt, nil, "the shotgun's reload was dropped")
	end)

	test("changing a slot on the paper-doll starts it over; there are no rounds to give back", function()
		local state = Hands.new({ "item.scrap_shotgun", "item.pipe_pistol" }, ITEMS, CONFIG)
		state = Hands.setGun(state, Combat.newGun(2))
		local synced = Hands.sync(state, { "item.fire_axe", "item.pipe_pistol" }, ITEMS, CONFIG)
		TestKit.equal(synced.hands[1].itemId, "item.fire_axe")
		TestKit.equal(synced.hands[1].gun, nil, "an axe has no magazine")
		TestKit.equal(synced.hands[2], state.hands[2], "the untouched slot keeps its state")
		local back = Hands.sync(synced, { "item.scrap_shotgun", "item.pipe_pistol" }, ITEMS, CONFIG)
		local shells = (Content.Items["item.scrap_shotgun"] :: any).weapon.firearm.magazine
		TestKit.equal(loaded(back, 1), shells, "a newly slotted gun starts loaded")
		local same = Hands.sync(back, { "item.scrap_shotgun", "item.pipe_pistol" }, ITEMS, CONFIG)
		TestKit.equal(same.hands[1], back.hands[1], "no change, same state")
	end)

	test("meds are consumables whose main effect is healing", function()
		TestKit.equal(Hands.isMeds(ITEMS["item.field_dressing"]), true)
		TestKit.equal(Hands.isMeds(ITEMS["item.hearth_stew"]), false, "stew is food")
		TestKit.equal(Hands.isMeds(ITEMS["item.ember_tea"]), false, "tea is drink")
		TestKit.equal(Hands.isMeds(ITEMS["item.scrap"]), false)
		TestKit.equal(Hands.isMeds(nil), false)
	end)

	test("the meds button picks the smallest heal that covers the wound, else the biggest", function()
		local inventory = Inventory.new(3, 0)
		inventory.pockets[1] = { itemId = "item.hearth_stew", count = 2 }
		inventory.pockets[2] = { itemId = "item.field_dressing", count = 3 }
		TestKit.equal(Hands.medsCount(inventory, ITEMS), 3, "stew doesn't count")
		TestKit.equal(Hands.bestMeds(inventory, ITEMS, 25), "item.field_dressing")
		TestKit.equal(Hands.bestMeds(inventory, ITEMS, 90), "item.field_dressing", "the biggest when none covers it")
		TestKit.equal(Hands.bestMeds(inventory, ITEMS, 0), nil, "full health")
		TestKit.equal(Hands.bestMeds(Inventory.new(2, 0), ITEMS, 30), nil, "no meds")
	end)

	test("with several meds, a scratch doesn't waste the big one", function()
		local items: Hands.ItemLookup = {
			["item.big"] = { category = "consumable", consume = { health = 60 } },
			["item.small"] = { category = "consumable", consume = { health = 15 } },
		}
		local inventory = Inventory.new(2, 0)
		inventory.pockets[1] = { itemId = "item.big", count = 1 }
		inventory.pockets[2] = { itemId = "item.small", count = 1 }
		TestKit.equal(Hands.bestMeds(inventory, items, 10), "item.small")
		TestKit.equal(Hands.bestMeds(inventory, items, 40), "item.big")
		TestKit.equal(Hands.bestMeds(inventory, items, 95), "item.big")
	end)
end
