--!strict
--[[
	Shop (client): the moment-of-need slots (UI/offers) for the v0.1 shop (MVP_LAUNCH
	Monetization v0.1). The server decides what is on offer and charges (Services/Shop).

	- Fill up (craft, build, station and crate upgrades): asks to buy the shortfall with
	  Embers at Fill Up rates (screens/ldoe/EmberConfirm); GET EMBERS when short.
	- Toasts: "View offer" on "bag full" (the Pack Expansion, until owned) and on a broken
	  weapon (the Scavenger's Kit), each trigger at most once a day (playbook §3: contextual
	  offers, neutral calls to action).
	- gear() and gearChip(): the Scavenger's Kit, prompted at once (the death screen's chip).
	- buyEnergy(shortfall?) and energyChip(shortfall): the Energy Refill (the Fog map's slot
	  beside a greyed Run, and "Go back in" when Energy is short); a chip is nil while the
	  product isn't on offer. "Not enough Energy for a Run" toasts carry the same offer, and
	  the server's "energyShort" effect keeps the shortfall in ui.energyShort.
	- openShop(productId?): the shop on that product.
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

local GEAR = "product.scavenger_kit"
local REFILL = "product.energy_refill"

-- The "shop" section's row for a product (price, available, reason), or nil before it syncs.
local function row(productId: string): any
	local state = State.get("shop")
	return if type(state) == "table" then state[productId] else nil
end

local function owned(productId: string): boolean
	local entry = row(productId)
	return entry ~= nil and entry.reason == "limit"
end

-- A product slot for a screen (UI/offers.ProductChip), or nil while it isn't on offer.
local function chip(productId: string, line: string): offers.ProductChip?
	local product = Content.Products[productId]
	local entry = row(productId)
	if product == nil or entry == nil or entry.available ~= true then
		return nil
	end
	return {
		productId = productId,
		name = product.name,
		price = if type(entry.price) == "number" then entry.price else product.defaultPriceRobux,
		line = line,
		available = true,
	}
end

-- The Energy the Refill gives (its grant in Data/Products).
local function refillAmount(): number
	local product = Content.Products[REFILL]
	for _, grant in (if product then product.grants else {}) :: { any } do
		if grant.kind == "energy" then
			return grant.amount
		end
	end
	return 0
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
	offers.buyEnergy = function(_shortfall: number?)
		Actions.buyProduct(REFILL)
	end
	offers.energyChip = function(shortfall: number): offers.ProductChip?
		local amount = refillAmount()
		local short = math.max(0, math.ceil(shortfall))
		return chip(REFILL, if short > 0 then `+{amount} Energy, you need {short} more` else `+{amount} Energy`)
	end
	offers.openShop = function(productId: string?)
		Actions.openShop(productId)
	end
	offers.gear = function()
		Actions.buyProduct(GEAR)
	end
	offers.gearChip = function(): offers.ProductChip?
		return chip(GEAR, "A blade, a padded vest, dressings and food")
	end
	offers.forNotice = function(text: string): offers.Offer?
		local lower = string.lower(text)
		if string.find(lower, "not enough energy", 1, true) and chip(REFILL, "") then
			-- The Run you can't pay for (Services/Travel): the Refill, every time.
			return {
				label = "Get Energy",
				onActivated = function()
					Actions.buyProduct(REFILL)
				end,
			}
		elseif string.find(lower, "bag is full", 1, true) and not owned("product.pack_expansion") then
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
	State.fx:Connect(function(kind: any, payload: any)
		if kind == "needEmbers" then
			Actions.openShop(nil, "embers")
		elseif kind == "energyShort" and type(payload) == "table" and type(payload.need) == "number" then
			State.patch({ energyShort = { need = payload.need, at = os.clock() } })
		end
	end)
end

return Shop
