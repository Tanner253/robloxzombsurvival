--!strict
--[[
	Shop: the v0.1 shop (MVP_LAUNCH Monetization v0.1; Data/Products, Domain/Receipts,
	Domain/Offers): eight developer products, two game passes and the Ember sinks.

	- ShopBuy(productId): the server checks the product is on offer for this player (listed,
	  under its limit, the Firestarter Kit's never-paid 48 h window) and prompts the developer
	  product or game pass.
	- ProcessReceipt: idempotent. The receipt ID is logged in the profile in the same change
	  that grants the goods; a receipt seen before grants nothing. Items go to the inbox
	  (never raidable), Embers to the balance, energy past the cap. The receipt is confirmed
	  to Roblox only once a saved profile version holds its ID (PlayerData.saveConfirmed);
	  until then Roblox retries, and the retry finds the receipt and only waits for the save.
	- Game passes (Pack Expansion, VIP Lounge): recorded once when bought or found on join
	  (Receipts.applyPass); the Lounge's perks are Services/Haven's.
	- Any purchase opens the VIP Lounge for Tuning.embers.vipTrialDays (LDoE's VIP 1).
	- The first win (the first extraction, or the first dawn reached after a night online)
	  opens the Firestarter Kit's window; it never restarts. The "firstOffer" effect tells the
	  client to show its one-time card (F-11).
	- Ember sinks: EmbersRations(count) buys Trail Rations (inbox); FillUp(stacks) buys the
	  missing materials of a craft, build or upgrade at Fill Up rates; Recover all through
	  FogRuns/Payments' premium method. Speed-ups are Services/Stations'.
	- The "shop" section: each product's live price, purchases, whether it is on offer and
	  when its countdown ends.
	- Studio only: Workspace attribute ShopTestReceipt = "<productId>:<receiptId>" runs a
	  receipt through the real handler (Studio can't press Roblox's Buy button for tools);
	  the decision lands in ShopTestResult. ShopTestFirstWin = true opens the Firestarter
	  window now.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Content = require(ReplicatedStorage.Shared.Data)
local BuildRules = require(ReplicatedStorage.Shared.Domain.BuildRules)
local Offers = require(ReplicatedStorage.Shared.Domain.Offers)
local Receipts = require(ReplicatedStorage.Shared.Domain.Receipts)
local PlayerSchema = require(ReplicatedStorage.Shared.Domain.PlayerSchema)
local Types = require(ReplicatedStorage.Shared.Types)
local Payments = require("../FogRuns/Payments")
local Analytics = require("./Analytics")
local Embers = require("./Embers")
local Energy = require("./Energy")
local Haven = require("./Haven")
local Inbox = require("./Inbox")
local Inventory = require("./Inventory")
local Lobby = require("./Lobby")
local Net = require("../Net")
local OnRun = require("../OnRun")
local PlayerData = require("./PlayerData")
local Plots = require("./Plots")
local Sync = require("./Sync")

local Shop = {}

local SAVE_TIMEOUT = 15 -- seconds to wait for the receipt's save before Roblox retries
local PROFILE_WAIT = 10 -- seconds to wait for a profile that is still loading
local DAWN_HOUR, DUSK_HOUR = 6, 19.5 -- Shared/Clock's night
local NIGHT_PRESENCE = 120 -- seconds online before dawn that count as surviving the night
local DAY = 24 * 60 * 60

local Products = Content.Products :: { [string]: Types.ProductDef }
local emberTuning = Content.Tuning.embers :: any
local prices: { [string]: number } = {} -- live Robux prices, read once at start
-- Products Roblox says are off sale (GetProductInfo answered, IsForSale false): never
-- prompted, and their cards are hidden (reason "notListed", as for a robloxId of 0). A read
-- that fails leaves the product listed, so a Roblox API hiccup at boot can't empty the shop.
local offSale: { [string]: boolean } = {}
local joinedAt: { [Player]: number } = {}

-- Receipts.canOffer, plus the live listing: a product Roblox has off sale is "notListed".
local function canOffer(
	product: Types.ProductDef,
	data: any,
	context: Receipts.OfferContext
): (boolean, string?, number)
	if offSale[product.id] then
		return false, "notListed", 0
	end
	return Receipts.canOffer(product, data.purchases :: any, data.progression.level, context)
end

local function slotsOf(items: { Types.ItemStack }): { Types.Slot }
	local slots: { Types.Slot } = {}
	for _, stack in items do
		table.insert(slots, { itemId = stack.itemId, count = stack.count } :: any)
	end
	return slots
end

local NAMES = { items = Content.Items :: any, quests = Content.Quests :: any }

local function offerContext(player: Player, data: any): Receipts.OfferContext
	local plot = Plots.of(player)
	return {
		now = os.time(),
		firstWinAt = data.shop.firstWinAt,
		firstPurchaseHours = emberTuning.firstPurchaseHours,
		-- F-12 and F-27: unlock gates and "+1 can be placed" read the player's progress and
		-- plot (no plot, as on a run server: capacity products wait).
		progress = { level = data.progression.level, unlocks = data.unlocks, quests = data.quests },
		placed = if plot
			then BuildRules.placedCaps(
				plot.layout,
				Content.BuildPieces :: any,
				BuildRules.pieceSlots(Products, data.purchases.counts)
			)
			else nil,
	}
end

-- The "shop" section: per product, its price, purchases, whether it is on offer and when
-- its countdown ends (0 when it has none).
local function view(player: Player): any
	local data = PlayerData.get(player)
	if data == nil then
		return nil
	end
	local result: { [string]: any } = {}
	local context = offerContext(player, data)
	for id, product in Products do
		local purchases = data.purchases :: any
		local available, reason, endsAt = canOffer(product, data, context)
		result[id] = {
			price = prices[id] or product.defaultPriceRobux,
			bought = purchases.counts[id] or 0,
			available = available,
			reason = reason,
			endsAt = endsAt,
			-- The greyed card's line (F-12, F-27); nil when progress isn't what holds it back.
			lock = Receipts.lockLine(product, reason, context, NAMES, Content.BuildPieces :: any),
		}
	end
	return result
end

-- Any purchase opens the VIP Lounge for a week (LDoE's VIP 1).
local function openLounge(player: Player, data: any)
	local until_ = os.time() + emberTuning.vipTrialDays * DAY
	data.haven.vipTrialUntil = math.max(data.haven.vipTrialUntil, until_)
	Haven.refreshMember(player)
end

local function deliver(player: Player, data: any, product: Types.ProductDef, delivery: Receipts.Delivery)
	if #delivery.items > 0 then
		Inbox.grant(player, Receipts.inboxSlots(delivery.items, Content.Items), "Purchase")
	end
	if delivery.embers > 0 then
		Embers.grant(player, delivery.embers, "Purchase")
	end
	if delivery.energy > 0 then
		Energy.restore(player, delivery.energy, "grant")
	end
	if delivery.backpackSlots > 0 then
		Inventory.refreshBackpack(player)
	end
	openLounge(player, data)
	Sync.mark(player, "plot") -- a "+1 can be placed" product raises the plot's limits
	Sync.notice(
		player,
		if #delivery.items > 0 then `{product.name}: it's in your inbox` else `{product.name}: done`,
		"good"
	)
	Sync.fx(player, "purchase", { productId = product.id })
	Sync.mark(player, "shop")
end

local function buy(player: Player, productId: string)
	local product = Products[productId]
	local data = PlayerData.get(player)
	if product == nil or data == nil then
		return
	end
	local context = offerContext(player, data)
	local available, reason = canOffer(product, data, context)
	if not available then
		local lock = Receipts.lockLine(product, reason, context, NAMES, Content.BuildPieces :: any)
		Sync.notice(
			player,
			if reason == "limit" then "You already have this" elseif lock then lock else "Not on offer right now",
			"warn"
		)
		Sync.mark(player, "shop")
		return
	end
	if product.kind == "gamePass" then
		MarketplaceService:PromptGamePassPurchase(player, product.robloxId)
	else
		MarketplaceService:PromptProductPurchase(player, product.robloxId)
	end
end

local function readPrices()
	for id, product in Products do
		if product.robloxId ~= 0 then
			local infoType = if product.kind == "gamePass" then Enum.InfoType.GamePass else Enum.InfoType.Product
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(product.robloxId, infoType)
			end)
			if ok and type(info) == "table" then
				if type(info.PriceInRobux) == "number" then
					prices[id] = info.PriceInRobux
				end
				offSale[id] = info.IsForSale == false
			end
		end
	end
	for _, player in Players:GetPlayers() do
		Sync.mark(player, "shop")
	end
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
	if product == nil or product.kind ~= "devProduct" then
		warn(`Shop: receipt {info.PurchaseId} is for unknown product {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(info.PurchaseId)
	local maxSlots = Content.Tuning.inventory.maxBackpackSlots
	local decision, delivery =
		Receipts.apply(data.purchases, product, receiptId, PlayerSchema.RECEIPT_LOG_SIZE, maxSlots)
	if decision == "granted" and delivery then
		deliver(player, data, product, delivery)
		Analytics.custom(player, "Purchase", info.CurrencySpent or product.defaultPriceRobux, { product.id })
	end
	local saved = PlayerData.saveConfirmed(player, function(savedData: any): boolean
		local log = savedData and savedData.purchases and savedData.purchases.receiptIds
		return type(log) == "table" and table.find(log, receiptId) ~= nil
	end, SAVE_TIMEOUT)
	return if saved then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Game passes ----------------------------------------------------------------------------------------

local function recordPass(player: Player, product: Types.ProductDef, bought: boolean)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	local delivery = Receipts.applyPass(data.purchases, product, Content.Tuning.inventory.maxBackpackSlots)
	if delivery == nil then
		return
	end
	if delivery.backpackSlots > 0 then
		Inventory.refreshBackpack(player)
	end
	if bought then
		openLounge(player, data)
		Sync.notice(player, `{product.name}: yours for good`, "good")
		Sync.fx(player, "purchase", { productId = product.id })
		Analytics.custom(player, "Purchase", product.defaultPriceRobux, { product.id })
	end
	Sync.mark(player, "shop")
end

local function checkPasses(player: Player)
	for _, product in Products do
		if product.kind == "gamePass" and product.robloxId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, product.robloxId)
			end)
			if ok and owns == true then
				recordPass(player, product, false)
			end
		end
	end
end

-- The first win ---------------------------------------------------------------------------------------

-- The first win opens the Firestarter Kit's window out loud (the flow review's F-11): the
-- client shows its one-time card ("firstOffer"), then the strip icon with the countdown. The
-- card waits for home (a first extraction ends on the run server) and shows once per
-- survivor (PlayerData.shop.cardShown).
local STARTER = "product.starter_offer"
local CARD_DELAY = 4 -- seconds: let the HUD (or the trip home) settle first

local function offerCard(player: Player)
	local data = PlayerData.get(player)
	if data == nil or data.shop.cardShown or OnRun.is(player) then
		return
	end
	local open, _, endsAt = Receipts.canOffer(Products[STARTER], data.purchases :: any, data.progression.level, {
		now = os.time(),
		firstWinAt = data.shop.firstWinAt,
		firstPurchaseHours = emberTuning.firstPurchaseHours,
	})
	if open then
		data.shop.cardShown = true
		Sync.fx(player, "firstOffer", { productId = STARTER, endsAt = endsAt })
	end
end

local function firstWin(player: Player)
	local data = PlayerData.get(player)
	if data and data.shop.firstWinAt == 0 then
		data.shop.firstWinAt = os.time()
		Sync.mark(player, "shop")
		Analytics.custom(player, "FirstWin", 1)
		task.delay(CARD_DELAY, offerCard, player)
	end
end

-- Ember sinks ------------------------------------------------------------------------------------------

local function buyRations(player: Player, count: number)
	if count ~= 1 and count ~= 5 then
		return
	end
	local cost = Offers.rationsPrice(count, emberTuning)
	if not Embers.spend(player, cost, "Rations") then
		Embers.short(player, cost)
		return
	end
	Inbox.grant(player, { { itemId = "item.rations", count = count } :: any }, "Embers", true)
	Sync.notice(
		player,
		if count == 1 then "A Trail Ration: in your inbox" else `{count} Trail Rations: in your inbox`,
		"good"
	)
end

-- Fill Up: the missing materials of a craft, build or upgrade, at Fill Up rates, straight
-- into the bag (anything that doesn't fit goes to the inbox).
local function fillUp(player: Player, stacks: { { itemId: string, count: number } })
	local cost = Offers.fillUpPrice(stacks, emberTuning)
	if cost == nil then
		Sync.notice(player, "Those can't be filled up", "warn")
		return
	end
	if not Embers.spend(player, cost, "FillUp") then
		Embers.short(player, cost)
		return
	end
	local _, leftover = Inventory.give(player, stacks :: any, "FillUp")
	if #leftover > 0 then
		Inbox.grant(player, slotsOf(leftover), "Fill up", true)
	end
	Sync.notice(player, "Filled up", "good")
	Sync.fx(player, "filledUp", { stacks = stacks })
end

-- Recover all, paid in Embers: FogRuns/Payments' "premium" method.
local function verifyPremium(player: Player, purpose: Payments.Purpose, method: Payments.Method): boolean
	if method ~= "premium" or purpose ~= "recoverAll" then
		return false
	end
	if not Embers.spend(player, emberTuning.recoverAll, "RecoverAll") then
		Embers.short(player, emberTuning.recoverAll)
		return false
	end
	return true
end

-- Studio ---------------------------------------------------------------------------------------------

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
		if product == nil or product.kind ~= "devProduct" then
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
	workspace:GetAttributeChangedSignal("ShopTestFirstWin"):Connect(function()
		for _, player in Players:GetPlayers() do
			firstWin(player)
		end
	end)
end

function Shop.init()
	Net.onEvent("ShopBuy", buy)
	Net.onEvent("EmbersRations", buyRations)
	Net.onEvent("FillUp", fillUp)
end

function Shop.start()
	Sync.provide("shop", view)
	MarketplaceService.ProcessReceipt = processReceipt
	Payments.verify = verifyPremium
	PlayerData.loaded:Connect(function(player: Player)
		joinedAt[player] = os.time()
		Inventory.refreshBackpack(player) -- slots bought on another server
		Sync.mark(player, "shop")
		task.spawn(checkPasses, player)
		task.delay(CARD_DELAY, offerCard, player) -- a window opened on a run shows its card home
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		joinedAt[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if not purchased then
				return
			end
			for _, product in Products do
				if product.kind == "gamePass" and product.robloxId == passId then
					recordPass(player, product, true)
				end
			end
		end
	)
	-- The first win: an extraction, or dawn reached after being online through the night.
	Lobby.exited:Connect(function(player: Player, _run: any, outcome: string)
		if outcome == "extracted" then
			firstWin(player)
		end
	end)
	local function night(): boolean
		local hours = Clock.hoursAt(workspace:GetServerTimeNow())
		return hours < DAWN_HOUR or hours >= DUSK_HOUR
	end
	task.spawn(function()
		local wasNight = night()
		while true do
			task.wait(5)
			local isNight = night()
			if wasNight and not isNight then
				for player, at in joinedAt do
					if os.time() - at >= NIGHT_PRESENCE then
						firstWin(player)
					end
				end
			end
			wasNight = isNight
		end
	end)
	task.spawn(readPrices)
	if RunService:IsStudio() then
		watchStudioTest()
	end
end

return Shop
