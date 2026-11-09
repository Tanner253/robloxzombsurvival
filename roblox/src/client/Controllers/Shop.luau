--!strict
--[[
	Shop (client): the moment-of-need slots (UI/offers) for the v0.1 shop (MVP_LAUNCH
	Monetization v0.1). The server decides what is on offer and charges (Services/Shop).

	- Fill up (craft, build, station and crate upgrades): asks to buy the shortfall with
	  Embers at Fill Up rates (screens/ldoe/EmberConfirm); GET EMBERS when short.
	- Toasts: "View offer" on "bag full" (the Pack Expansion, until owned) and on a broken
	  weapon (the Scavenger's Kit), each trigger at most once a day (playbook §3: contextual
	  offers, neutral calls to action).
	- gear(): the Scavenger's Kit (the death screen's chip).
	- buyEnergy(): the Energy Refill. openShop(productId?): the shop on that product.
	- When the server says Embers are short ("needEmbers"), the shop opens on EMBERS.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Offers = require(ReplicatedStorage.Shared.Domain.Offers)
local Actions = require("../Actions")
local Net = require("../Net")
local State = require("../State")
local format = require("../UI/format")
local offers = require("../UI/offers")

local Shop = {}

local DAY = 24 * 60 * 60
local shown: { [string]: number } = {} -- trigger -> os.time() it last showed an offer

-- An offer chip for `trigger` when it hasn't shown in the last day.
local function once(trigger: string, offer: offers.Offer): offers.Offer?
	local last = shown[trigger]
	if last and os.time() - last < DAY then
		return nil
	end
	shown[trigger] = os.time()
	return offer
end

local function owned(productId: string): boolean
	local state = State.get("shop")
	local entry = if type(state) == "table" then state[productId] else nil
	return entry ~= nil and entry.reason == "limit"
end

function Shop.init()
	offers.fillUp = function(stacks: { { itemId: string, count: number } })
		local price = Offers.fillUpPrice(stacks, Content.Tuning.embers :: any)
		if price == nil then
			State.notify("These can't be filled up: find them out there", "info")
			return
		end
		local names = {}
		for _, stack in stacks do
			table.insert(names, `{stack.count} {format.itemName(stack.itemId)}`)
		end
		State.patch({
			emberAsk = {
				title = "Fill up",
				text = table.concat(names, ", "),
				price = price,
				run = function()
					Net.fire("FillUp", stacks)
				end,
			},
		})
	end
	offers.buyEnergy = function()
		Actions.buyProduct("product.energy_refill")
	end
	offers.openShop = function(productId: string?)
		Actions.openShop(productId)
	end
	offers.gear = function()
		Actions.openShop("product.scavenger_kit")
	end
	offers.forNotice = function(text: string): offers.Offer?
		local lower = string.lower(text)
		if string.find(lower, "bag is full", 1, true) and not owned("product.pack_expansion") then
			return once("bagFull", {
				label = "View offer",
				onActivated = function()
					Actions.openShop("product.pack_expansion")
				end,
			})
		elseif string.find(lower, " broke", 1, true) then
			return once("weaponBroke", {
				label = "View offer",
				onActivated = function()
					Actions.openShop("product.scavenger_kit")
				end,
			})
		end
		return nil
	end
end

function Shop.start()
	State.fx:Connect(function(kind: any)
		if kind == "needEmbers" then
			Actions.openShop(nil, "embers")
		end
	end)
end

return Shop
