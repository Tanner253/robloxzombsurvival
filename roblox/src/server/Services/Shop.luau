--!strict
--[[
	Shop: Robux developer products (MVP_LAUNCH v0.1; Data/Products, Domain/Receipts).

	- ShopBuy(productId): the server checks the product is on offer for this player
	  (listed, under its limit, within its level window) and prompts the purchase.
	- ProcessReceipt: idempotent. The receipt ID is logged in the profile in the same
	  change that grants the goods; a receipt seen before grants nothing. Items go to the
	  inbox (never raidable), energy is added past the cap, bought backpack slots resize
	  the backpack. The receipt is confirmed to Roblox only once a saved profile version
	  holds its ID (PlayerData.saveConfirmed); until then Roblox retries, and the retry
	  finds the receipt and only waits for the save.
	- The "shop" section: each product's live price, purchases so far and whether it is
	  on offer, for the Shop screen and the moment-of-need buttons.
	- Studio only: Workspace attribute ShopTestReceipt = "<productId>:<receiptId>" runs a
	  receipt through the real handler (Studio can't press Roblox's Buy button for tools);
	  the decision lands in ShopTestResult.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Content = require(ReplicatedStorage.Shared.Data)
local Receipts = require(ReplicatedStorage.Shared.Domain.Receipts)
local PlayerSchema = require(ReplicatedStorage.Shared.Domain.PlayerSchema)
local Types = require(ReplicatedStorage.Shared.Types)
local Analytics = require("./Analytics")
local Energy = require("./Energy")
local Inbox = require("./Inbox")
local Inventory = require("./Inventory")
local Net = require("../Net")
local PlayerData = require("./PlayerData")
local Sync = require("./Sync")

local Shop = {}

local SAVE_TIMEOUT = 15 -- seconds to wait for the receipt's save before Roblox retries
local PROFILE_WAIT = 10 -- seconds to wait for a profile that is still loading

local Products = Content.Products :: { [string]: Types.ProductDef }
local prices: { [string]: number } = {} -- live Robux prices, read once at start

local function slotsOf(items: { Types.ItemStack }): { Types.Slot }
	local slots: { Types.Slot } = {}
	for _, stack in items do
		table.insert(slots, { itemId = stack.itemId, count = stack.count } :: any)
	end
	return slots
end

-- The "shop" section: per product, its price, purchases and whether it is on offer.
local function view(player: Player): any
	local data = PlayerData.get(player)
	if data == nil then
		return nil
	end
	local result: { [string]: any } = {}
	for id, product in Products do
		local purchases = data.purchases :: any
		local available, reason = Receipts.canOffer(product, purchases, data.progression.level)
		result[id] = {
			price = prices[id] or product.defaultPriceRobux,
			bought = purchases.counts[id] or 0,
			available = available,
			reason = reason,
		}
	end
	return result
end

local function deliver(player: Player, product: Types.ProductDef, delivery: Receipts.Delivery)
	if #delivery.items > 0 then
		Inbox.grant(player, slotsOf(delivery.items), "Purchase")
	end
	if delivery.energy > 0 then
		Energy.restore(player, delivery.energy, "grant")
	end
	if delivery.backpackSlots > 0 then
		Inventory.refreshBackpack(player)
	end
	Sync.notice(
		player,
		if #delivery.items > 0 then `{product.name}: it's in your inbox` else `{product.name}: done`,
		"good"
	)
	Sync.fx(player, "purchase", { productId = product.id })
end

local function waitForData(player: Player): any
	local started = os.clock()
	local data = PlayerData.get(player)
	while data == nil and player.Parent == Players and os.clock() - started < PROFILE_WAIT do
		task.wait(0.25)
		data = PlayerData.get(player)
	end
	return data
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- granted when they next join
	end
	local data = waitForData(player)
	if data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = Receipts.productByRobloxId(Products, info.ProductId)
	if product == nil then
		warn(`Shop: receipt {info.PurchaseId} is for unknown product {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(info.PurchaseId)
	local maxSlots = Content.Tuning.inventory.maxBackpackSlots
	local decision, delivery =
		Receipts.apply(data.purchases, product, receiptId, PlayerSchema.RECEIPT_LOG_SIZE, maxSlots)
	if decision == "granted" and delivery then
		deliver(player, product, delivery)
		Analytics.custom(player, "Purchase", info.CurrencySpent or product.defaultPriceRobux, { product.id })
		Sync.mark(player, "shop")
	end
	local saved = PlayerData.saveConfirmed(player, function(savedData: any): boolean
		local log = savedData and savedData.purchases and savedData.purchases.receiptIds
		return type(log) == "table" and table.find(log, receiptId) ~= nil
	end, SAVE_TIMEOUT)
	return if saved then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

local function buy(player: Player, productId: string)
	local product = Products[productId]
	local data = PlayerData.get(player)
	if product == nil or data == nil then
		return
	end
	local available, reason = Receipts.canOffer(product, data.purchases :: any, data.progression.level)
	if not available then
		Sync.notice(player, if reason == "limit" then "You already have this" else "Not on offer right now", "warn")
		Sync.mark(player, "shop")
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.robloxId)
end

local function readPrices()
	for id, product in Products do
		if product.robloxId ~= 0 then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(product.robloxId, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				prices[id] = info.PriceInRobux
			end
		end
	end
	for _, player in Players:GetPlayers() do
		Sync.mark(player, "shop")
	end
end

-- Studio only: runs a made-up receipt through the real handler (see the header).
local function watchStudioTest()
	workspace:GetAttributeChangedSignal("ShopTestReceipt"):Connect(function()
		local value = workspace:GetAttribute("ShopTestReceipt")
		local player = Players:GetPlayers()[1]
		if type(value) ~= "string" or player == nil then
			return
		end
		local productId, receiptId = string.match(value, "^([^:]+):(.+)$")
		local product = productId and Products[productId]
		if product == nil then
			workspace:SetAttribute("ShopTestResult", `unknown product {productId}`)
			return
		end
		task.spawn(function()
			local decision = processReceipt({
				PlayerId = player.UserId,
				ProductId = product.robloxId,
				PurchaseId = receiptId,
				CurrencySpent = product.defaultPriceRobux,
			})
			workspace:SetAttribute("ShopTestResult", `{receiptId}: {decision.Name}`)
		end)
	end)
end

function Shop.init()
	Net.onEvent("ShopBuy", buy)
end

function Shop.start()
	Sync.provide("shop", view)
	MarketplaceService.ProcessReceipt = processReceipt
	PlayerData.loaded:Connect(function(player: Player)
		Inventory.refreshBackpack(player) -- slots bought on another server
		Sync.mark(player, "shop")
	end)
	task.spawn(readPrices)
	if RunService:IsStudio() then
		watchStudioTest()
	end
end

return Shop
