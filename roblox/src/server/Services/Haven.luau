--!strict
--[[
	Haven: the people and perks of Haven Square (Data/Haven; World/Haven builds the square).

	- Trader: HavenBuy(itemId, count) pays coins for her stock; HavenSell(itemId, count)
	  takes items from the bag for coins (Domain/Market). Coins live in the profile.
	- Contracts: three a UTC day per survivor (Domain/Contracts). ContractDeliver(id)
	  takes the items and pays coins and XP, once a day per contract.
	- Chapter hand-ins: ChapterClaim(chapter) pays a finished Ember Trail chapter's
	  reward (coins, items to the inbox) once.
	- VIP Lounge (game pass Data/Haven.vip.passId, or a week after any purchase: Services/Shop
	  sets haven.vipTrialUntil): members wear the VIP attribute (Energy reads it for the +40
	  cap), a flame aura and the gate's collision group, and get the fixed daily crate in the
	  inbox on their first visit each UTC day, with a Trail Ration every 7th day in a row.
	  VipBuy prompts the pass. Non-members found inside the fence are put back outside the
	  gate.
	- Every trade checks the survivor stands by the NPC or board (reach plus lag).
	- Safe zone: no Hollow spawns in a Neighbourhood and there is no PvP in M1; the
	  square's folder carries the SafeZone attribute for M2's PvP rules.
	- The "haven" section: coins, today's contracts and deliveries, chapters to hand in,
	  VIP status and the next crate.
	- Studio only: Workspace attribute HavenTestVip = true makes everyone a member (Studio
	  can't buy a game pass); HavenTestCoins = n sets everyone's coins.
]]

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Content = require(ReplicatedStorage.Shared.Data)
local Contracts = require(ReplicatedStorage.Shared.Domain.Contracts)
local Market = require(ReplicatedStorage.Shared.Domain.Market)
local Neighbourhood = require(ReplicatedStorage.Shared.Domain.Neighbourhood)
local Types = require(ReplicatedStorage.Shared.Types)
local HavenWorld = require("../World/Haven")
local Analytics = require("./Analytics")
local Inbox = require("./Inbox")
local Inventory = require("./Inventory")
local Net = require("../Net")
local PlayerData = require("./PlayerData")
local Progression = require("./Progression")
local Sync = require("./Sync")

local Haven = {}

local havenData = Content.Haven
local LAG = Content.Tuning.combat.lagToleranceStuds
local GATE_SECONDS = 0.5
local DAY = 24 * 60 * 60
local DEFAULT_ORIGIN = Vector3.new(0, 2.06, 900) -- Services/Scenery's, for a World without one

local members: { [Player]: boolean } = {} -- the VIP attribute is on (pass or trial)
local owners: { [Player]: boolean } = {} -- they own the VIP Lounge pass
local TRIAL_CHECK_SECONDS = 30

local function itemName(itemId: string): string
	local def = Content.Items[itemId]
	return if def then def.name else itemId
end

local function slotsOf(items: { Types.ItemStack }): { Types.Slot }
	local slots: { Types.Slot } = {}
	for _, stack in items do
		table.insert(slots, { itemId = stack.itemId, count = stack.count } :: any)
	end
	return slots
end

local function origin(): Vector3
	local world = workspace:FindFirstChild("World")
	local value = if world then world:GetAttribute("Origin") else nil
	return if typeof(value) == "Vector3" then value else DEFAULT_ORIGIN
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Whether the survivor stands within `reach` of any of the tagged models `ids`.
local function near(player: Player, ids: { string }, reach: number): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	for _, model in CollectionService:GetTagged(HavenWorld.TAG) do
		if model:IsA("Model") and table.find(ids, model:GetAttribute("HavenId") :: string) then
			local at = model:GetPivot().Position
			local size = model:GetExtentsSize()
			local distance = Vector2.new(at.X - root.Position.X, at.Z - root.Position.Z).Magnitude
			if distance <= reach + math.max(size.X, size.Z) / 2 + LAG then
				return true
			end
		end
	end
	return false
end

local function pay(player: Player, data: any, coins: number, reason: string)
	data.haven.coins += coins
	Analytics.economy(
		player,
		if coins < 0 then "sink" else "source",
		"Coins",
		math.abs(coins),
		data.haven.coins,
		reason
	)
	Sync.mark(player, "haven")
end

-- Today's contract board for this survivor (the deliveries reset on a new UTC day).
local function board(player: Player, data: any): ({ Contracts.Contract }, Contracts.State)
	local day = Contracts.dayOf(os.time())
	local state = Contracts.today(data.haven.contracts, day)
	data.haven.contracts = state
	return Contracts.forDay(havenData.contracts.pool, havenData.contracts.perDay, player.UserId, day), state
end

-- Trader ---------------------------------------------------------------------------------------

local function buy(player: Player, itemId: string, count: number)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	if not near(player, { "npc.trader" }, havenData.trader.reachStuds) then
		Sync.notice(player, "Come closer to the Trader", "warn")
		return
	end
	local cost = Market.cost(havenData.trader.buy, itemId, count)
	if cost == nil then
		return
	end
	if data.haven.coins < cost then
		Sync.notice(player, "Not enough coins", "warn")
		return
	end
	local stack = { { itemId = itemId, count = count } }
	if not Inventory.fits(player, stack) then
		Sync.notice(player, "No room in your bag", "warn")
		return
	end
	Inventory.give(player, stack, "Trader")
	pay(player, data, -cost, "Trader")
	Sync.fx(player, "trade", { itemId = itemId, count = count, coins = -cost })
end

local function sell(player: Player, itemId: string, count: number)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	if not near(player, { "npc.trader" }, havenData.trader.reachStuds) then
		Sync.notice(player, "Come closer to the Trader", "warn")
		return
	end
	local value = Market.cost(havenData.trader.sell, itemId, count)
	if value == nil then
		return
	end
	if not Inventory.take(player, { { itemId = itemId, count = count } }, "Trader") then
		Sync.notice(player, `You don't have {count} {itemName(itemId)}`, "warn")
		return
	end
	pay(player, data, value, "Trader")
	Sync.fx(player, "trade", { itemId = itemId, count = -count, coins = value })
end

-- Trail Keeper ----------------------------------------------------------------------------------

local function deliver(player: Player, contractId: string)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	if not near(player, { "npc.keeper", "board.contracts" }, havenData.contracts.reachStuds) then
		Sync.notice(player, "Come closer to the contract board", "warn")
		return
	end
	local list, state = board(player, data)
	local ok, contract = Contracts.canDeliver(list, state, contractId)
	if not ok or contract == nil then
		Sync.mark(player, "haven")
		return
	end
	if not Inventory.take(player, { { itemId = contract.itemId, count = contract.count } }, "Contract") then
		Sync.notice(player, `You need {contract.count} {itemName(contract.itemId)}`, "warn")
		return
	end
	state.done[contract.id] = true
	pay(player, data, contract.coins, "Contract")
	Progression.grantXp(player, contract.xp, "Contract")
	Sync.notice(player, `Contract done: {contract.coins} coins`, "good")
	Sync.fx(player, "trade", { itemId = contract.itemId, count = -contract.count, coins = contract.coins })
end

local function claimChapter(player: Player, chapter: string)
	local data = PlayerData.get(player)
	local reward = havenData.chapterRewards[chapter]
	if data == nil or reward == nil or data.haven.chapters[chapter] ~= nil then
		return
	end
	if not near(player, { "npc.keeper" }, havenData.contracts.reachStuds) then
		Sync.notice(player, "Come closer to the Trail Keeper", "warn")
		return
	end
	if not Market.chapterDone(Content.Quests :: any, data.quests.completed, chapter) then
		Sync.notice(player, "Finish the chapter first", "warn")
		return
	end
	data.haven.chapters[chapter] = os.time()
	pay(player, data, reward.coins, "Chapter")
	Inbox.grant(player, slotsOf(reward.items), "Chapter")
	Sync.notice(player, `{chapter} handed in: {reward.coins} coins, supplies in your inbox`, "good")
end

-- VIP Lounge -------------------------------------------------------------------------------------

local function isMember(player: Player): boolean
	return members[player] == true
end

-- Members' characters pass the Lounge gate and wear the flame aura.
local function dress(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local member = isMember(player)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = if member then HavenWorld.MEMBER_GROUP else "Default"
		end
	end
	local root = rootOf(player)
	local aura = root and root:FindFirstChild("VipAura")
	if member and root and aura == nil then
		local holder = Instance.new("Attachment")
		holder.Name = "VipAura"
		holder.Position = Vector3.new(0, -2.4, 0)
		local embers = Instance.new("ParticleEmitter")
		embers.Texture = "rbxasset://textures/particles/fire_main.dds"
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 196, 92), Color3.fromRGB(255, 110, 40))
		embers.LightEmission = 0.9
		embers.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		embers.Size = NumberSequence.new(0.55, 0)
		embers.Lifetime = NumberRange.new(0.6, 1.1)
		embers.Rate = 16
		embers.Speed = NumberRange.new(1, 2)
		embers.SpreadAngle = Vector2.new(180, 30)
		embers.Acceleration = Vector3.new(0, 4, 0)
		embers.Parent = holder
		local warmth = Instance.new("PointLight")
		warmth.Range = 7
		warmth.Brightness = 0.6
		warmth.Color = Color3.fromRGB(255, 170, 90)
		warmth.Shadows = false
		warmth.Parent = holder
		holder.Parent = root
	elseif not member and aura then
		aura:Destroy()
	end
end

-- The daily crate, once a UTC day, to the inbox.
local function crate(player: Player)
	local data = PlayerData.get(player)
	if data == nil or not isMember(player) then
		return
	end
	local today = os.time() // DAY
	if data.haven.vipCrateDay == today then
		return
	end
	-- Days in a row: every streakDays-th consecutive crate adds the bonus (a Trail Ration).
	data.haven.vipStreak = if data.haven.vipCrateDay == today - 1 then data.haven.vipStreak + 1 else 1
	data.haven.vipCrateDay = today
	local contents = table.clone(havenData.vip.dailyCrate)
	if data.haven.vipStreak % havenData.vip.streakDays == 0 then
		for _, stack in havenData.vip.streakBonus do
			table.insert(contents, stack)
		end
	end
	Inbox.grant(player, slotsOf(contents), "VIP crate")
	Sync.notice(player, "Your VIP crate is in the inbox", "good")
	Sync.mark(player, "haven")
end

local function setMember(player: Player, member: boolean)
	if member == isMember(player) then
		return
	end
	if member then
		members[player] = true
		player:SetAttribute("VIP", true)
	else
		members[player] = nil
		player:SetAttribute("VIP", nil)
	end
	dress(player)
	Sync.mark(player, "energy") -- the cap moves
	Sync.mark(player, "haven")
	crate(player)
end

-- Whether the player is a member now: the pass, a purchase's week, or the Studio switch.
local function entitled(player: Player): boolean
	if owners[player] then
		return true
	end
	if RunService:IsStudio() and workspace:GetAttribute("HavenTestVip") ~= nil then
		return workspace:GetAttribute("HavenTestVip") == true
	end
	local data = PlayerData.get(player)
	return data ~= nil and data.haven.vipTrialUntil > os.time()
end

-- Puts the VIP attribute, aura and gate in line with the player's membership (Services/Shop
-- calls it after a purchase opens the Lounge for a week).
function Haven.refreshMember(player: Player)
	setMember(player, entitled(player))
end

local function checkPass(player: Player)
	if havenData.vip.passId ~= 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, havenData.vip.passId)
		end)
		if ok and owns == true then
			owners[player] = true
		else
			owners[player] = nil
		end
	end
	Haven.refreshMember(player)
end

local function buyPass(player: Player)
	if isMember(player) or havenData.vip.passId == 0 then
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, havenData.vip.passId)
end

-- Non-members inside the Lounge fence go back out through the gate.
local function guardGate()
	local rect = Neighbourhood.lounge
	local base = origin()
	local outside = base + Vector3.new((rect.x0 + rect.x1) / 2, 3, rect.z0 - 6)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and not isMember(player) then
			local offset = root.Position - base
			if Neighbourhood.inLounge(offset.X, offset.Z) and math.abs(offset.Y) < 20 then
				root.CFrame = CFrame.new(outside) * root.CFrame.Rotation
				Sync.notice(player, "The Lounge is for VIP members", "warn")
			end
		end
	end
end

-- The "haven" section -----------------------------------------------------------------------------

local function view(player: Player): any
	local data = PlayerData.get(player)
	if data == nil then
		return false
	end
	local list, state = board(player, data)
	local contracts = {}
	for _, contract in list do
		table.insert(contracts, {
			id = contract.id,
			itemId = contract.itemId,
			count = contract.count,
			coins = contract.coins,
			xp = contract.xp,
			done = state.done[contract.id] == true,
		})
	end
	local today = os.time() // DAY
	return {
		coins = data.haven.coins,
		contracts = contracts,
		resetsAt = (Contracts.dayOf(os.time()) + 1) * DAY,
		chapters = Market.claimable(
			havenData.chapterRewards,
			Content.Quests :: any,
			data.quests.completed,
			data.haven.chapters
		),
		vip = isMember(player),
		vipOwned = owners[player] == true,
		vipUntil = data.haven.vipTrialUntil,
		vipPrice = havenData.vip.priceRobux,
		crateAt = if data.haven.vipCrateDay == today then (today + 1) * DAY else 0,
	}
end

function Haven.init()
	Net.onEvent("HavenBuy", buy)
	Net.onEvent("HavenSell", sell)
	Net.onEvent("ContractDeliver", deliver)
	Net.onEvent("ChapterClaim", claimChapter)
	Net.onEvent("VipBuy", buyPass)
end

function Haven.start()
	Sync.provide("haven", view)
	PlayerData.loaded:Connect(function(player: Player)
		Sync.mark(player, "haven")
		task.spawn(checkPass, player)
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			dress(player)
			character.DescendantAdded:Connect(function(part: Instance)
				if part:IsA("BasePart") and isMember(player) then
					part.CollisionGroup = HavenWorld.MEMBER_GROUP
				end
			end)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		members[player] = nil
		owners[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if purchased and passId == havenData.vip.passId then
				owners[player] = true
				Haven.refreshMember(player)
				Sync.notice(player, "Welcome to the VIP Lounge", "good")
			end
		end
	)
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("HavenTestVip"):Connect(function()
			for _, player in Players:GetPlayers() do
				Haven.refreshMember(player)
			end
		end)
		workspace:GetAttributeChangedSignal("HavenTestCoins"):Connect(function()
			local coins = workspace:GetAttribute("HavenTestCoins")
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				if data and type(coins) == "number" then
					data.haven.coins = coins
					Sync.mark(player, "haven")
				end
			end
		end)
	end
	task.spawn(function()
		local lastDay = os.time() // DAY
		local sinceTrialCheck = 0
		while true do
			task.wait(GATE_SECONDS)
			guardGate()
			sinceTrialCheck += GATE_SECONDS
			if sinceTrialCheck >= TRIAL_CHECK_SECONDS then
				sinceTrialCheck = 0
				for _, player in Players:GetPlayers() do
					Haven.refreshMember(player) -- a purchase's week ran out
				end
			end
			-- A new UTC day: fresh contract boards and the next VIP crate.
			local day = os.time() // DAY
			if day ~= lastDay then
				lastDay = day
				for _, player in Players:GetPlayers() do
					crate(player)
					Sync.mark(player, "haven")
				end
			end
		end
	end)
end

return Haven
