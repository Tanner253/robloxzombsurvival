--!strict
--[[
	Feed: everything that pops up.
	- Toasts: notices at the top centre (refusals in amber, unlocks in green)
	- Rewards: "+2 Timber" cards on the right that pop in, stack and fade
	- LevelUp: the celebration banner with rays and the level's rewards
	- Prompt: the world-space hint over the current target ("E  Open Workbench",
	  "LMB  Chop Pine" with hit pips)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Art = require(ReplicatedStorage.Shared.Art)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Content = require(ReplicatedStorage.Shared.Data)
local Flags = require(ReplicatedStorage.Shared.Flags)
local Layout = require("../components/Layout")
local mark = require("../mark")
local State = require("../../State")
local Theme = require("../theme")
local offers = require("../offers")
local hooks = require("../hooks")
local format = require("../format")
local questText = require("../questText")
local Button = require("../components/Button")
local ItemIcon = require("../components/ItemIcon")
local KeyChip = require("../components/KeyChip")
local Label = require("../components/Label")

local e = React.createElement

local TOAST_SECONDS = 3.2
local REWARD_SECONDS = 3.4
local LEVEL_SECONDS = 4.2

-- Removes expired toasts and rewards from the UI state.
local function usePrune()
	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				task.wait(0.25)
				local ui = State.ui()
				local now = os.clock()
				local notices = {}
				for _, notice in ui.notices do
					if now - notice.at < TOAST_SECONDS then
						table.insert(notices, notice)
					end
				end
				local rewards = {}
				for _, reward in ui.rewards do
					if now - reward.at < REWARD_SECONDS then
						table.insert(rewards, reward)
					end
				end
				if #notices ~= #ui.notices or #rewards ~= #ui.rewards then
					State.patch({ notices = notices, rewards = rewards })
				end
				if ui.levelUp and now - ui.levelUp.at > LEVEL_SECONDS then
					State.clear("levelUp")
				end
			end
		end)
		return function()
			running = false
		end
	end, {})
end

local function Toast(props: { text: string, tone: string, layoutOrder: number })
	local alpha = hooks.useAnimated(1, 16, 0)
	local forNotice = offers.forNotice
	local offer = if forNotice then forNotice(props.text) else nil
	local color = if props.tone == "good"
		then Theme.colors.durability
		elseif props.tone == "info" then Theme.colors.strokeWarm
		else Theme.colors.accentSoft
	return e("Frame", {
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = alpha:map(function(a: number)
			return 1 - a * 0.92
		end),
		LayoutOrder = props.layoutOrder,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = color, Thickness = Theme.strokeThickness }),
		Scale = e("UIScale", {
			Scale = alpha:map(function(a: number)
				return 0.85 + 0.15 * a
			end),
		}),
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
		}),
		Text = e(Label, { text = props.text, style = "body", autoWidth = true, size = UDim2.fromOffset(0, 40) }),
		-- S3 slot (UI/offers): an offer on "bag full" and limit toasts once the shop sets it.
		Offer = offer and e(Button, {
			text = offer.label,
			size = UDim2.fromOffset(120, 32),
			onActivated = offer.onActivated,
		}),
	})
end

local function Toasts()
	local ui = hooks.useUi()
	local children: { [string]: any } = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for _, notice in ui.notices do
		children[`N{notice.id}`] = e(Toast, { text = notice.text, tone = notice.tone, layoutOrder = notice.id })
	end
	-- With the LDoE HUD the top centre holds the target bar (LDOE_PARITY #8): toasts sit below it.
	local top = if Flags.on("ldoeHud") then 18 + 56 else 18
	return e("Frame", {
		ref = mark.overlay, -- notices sit over whatever is open, panels included
		ZIndex = 30,
		Size = UDim2.fromOffset(600, 200),
		Position = UDim2.new(0.5, 0, 0, top),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
	}, children)
end

local function RewardCard(props: { itemId: string, count: number, layoutOrder: number })
	local pop = hooks.useAnimated(1, 13, 0)
	return e("Frame", {
		Size = UDim2.fromOffset(220, 48),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.12,
		LayoutOrder = props.layoutOrder,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.accentSoft, Thickness = 1, Transparency = 0.4 }),
		Scale = e("UIScale", {
			Scale = pop:map(function(a: number)
				-- Overshoot then settle: the reward "pop".
				return 0.6 + 0.4 * a + math.sin(a * math.pi) * 0.12
			end),
		}),
		Icon = e(
			"Frame",
			{ Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1 },
			{
				Inner = e(ItemIcon, { itemId = props.itemId, size = UDim2.fromScale(1, 1) }),
			}
		),
		Text = e(Label, {
			text = `+{props.count}  {format.itemName(props.itemId)}`,
			style = "body",
			tone = "highlight",
			size = UDim2.new(1, -56, 1, 0),
			position = UDim2.fromOffset(52, 0),
		}),
	})
end

local function Rewards()
	local ui = hooks.useUi()
	if Flags.on("ldoeHud") then
		return nil -- pickups float over the survivor instead (LDOE_PARITY #9, screens/ldoe/Hud)
	end
	local children: { [string]: any } = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for _, reward in ui.rewards do
		children[`R{reward.id}`] =
			e(RewardCard, { itemId = reward.itemId, count = reward.count, layoutOrder = reward.id })
	end
	return e("Frame", {
		Size = UDim2.fromOffset(240, 340),
		Position = UDim2.new(1, -16, 1, -140),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 30, -- above open screens (Sheet uses 10)
	}, children)
end

-- Names of everything a level unlocks: build pieces, recipes and station levels.
local function unlockedAt(level: number): { string }
	local names: { string } = {}
	local function gate(unlock: any): boolean
		return unlock ~= nil and unlock.kind == "level" and unlock.level == level
	end
	for _, piece in Content.BuildPieces do
		if gate(piece.unlock) then
			table.insert(names, piece.name)
		end
	end
	for _, recipe in Content.Recipes :: any do
		if gate(recipe.unlock) then
			local output = recipe.outputs and recipe.outputs[1]
			table.insert(names, if output then format.itemName(output.itemId) else recipe.id)
		end
	end
	table.sort(names)
	return names
end

local function LevelUp()
	local ui = hooks.useUi()
	local spin, setSpin = React.useBinding(0)
	local show = ui.levelUp ~= nil
	local alpha = hooks.useAnimated(if show then 1 else 0, 10, 0)
	React.useEffect(function()
		if not show then
			return function() end
		end
		local connection = RunService.RenderStepped:Connect(function()
			setSpin(os.clock() * 25 % 360)
		end)
		return function()
			connection:Disconnect()
		end
	end, { show })
	local info = ui.levelUp
	if info == nil then
		return nil
	end
	local rewards: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	}
	for index, stack in info.rewards do
		rewards[`R{index}`] = e(
			"Frame",
			{ Size = UDim2.fromOffset(120, 40), BackgroundTransparency = 1, LayoutOrder = index },
			{
				Icon = e("Frame", { Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1 }, {
					Inner = e(ItemIcon, { itemId = stack.itemId, size = UDim2.fromScale(1, 1) }),
				}),
				Text = e(Label, {
					text = `+{stack.count} {format.itemName(stack.itemId)}`,
					style = "caption",
					size = UDim2.new(1, -40, 1, 0),
					position = UDim2.fromOffset(40, 0),
				}),
			}
		)
	end
	local unlocked = unlockedAt(info.level)
	-- A plain Frame (no CanvasGroup) so the banner text stays crisp (4.1).
	return e("Frame", {
		Size = UDim2.fromOffset(520, if #unlocked > 0 then 262 else 220),
		Position = UDim2.new(0.5, 0, 0, 120),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Visible = alpha:map(function(a: number)
			return a > 0.02
		end),
	}, {
		Scale = e("UIScale", {
			Scale = alpha:map(function(a: number)
				return 0.7 + 0.3 * a + math.sin(a * math.pi) * 0.08
			end),
		}),
		Rays = e("ImageLabel", {
			Size = UDim2.fromOffset(300, 300),
			Position = UDim2.fromScale(0.5, 0.35),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Art.glyphs.xp, -- the glyph set's star, not a default Roblox texture (4.17)
			ImageColor3 = Theme.colors.accentSoft,
			ImageTransparency = 0.35,
			Rotation = spin,
		}),
		Title = e(Label, {
			text = "LEVEL UP",
			style = "title",
			tone = "accent",
			size = UDim2.new(1, 0, 0, 30),
			position = UDim2.fromOffset(0, 24),
			alignX = Enum.TextXAlignment.Center,
			stroke = true,
		}),
		Level = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, 72),
			Position = UDim2.fromOffset(0, 52),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = tostring(info.level),
			TextSize = 72,
			TextColor3 = Theme.colors.highlight,
		}, {
			Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 3 }),
		}),
		Sub = e(Label, {
			-- Rewards always wait in the inbox (4.15), so the card says where they are.
			text = if #(info.rewards or {}) > 0
				then "Energy restored, fully healed, rewards are in your inbox"
				else "Energy restored, fully healed",
			style = "caption",
			tone = "muted",
			size = UDim2.new(1, 0, 0, 20),
			position = UDim2.fromOffset(0, 128),
			alignX = Enum.TextXAlignment.Center,
		}),
		Rewards = e(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 160), BackgroundTransparency = 1 },
			rewards
		),
		Unlocks = #unlocked > 0 and e(Label, {
			text = `Unlocked: {table.concat(unlocked, ", ")}`,
			style = "body",
			tone = "highlight",
			wrap = true,
			size = UDim2.new(1, 0, 0, 44),
			position = UDim2.fromOffset(0, 210),
			alignX = Enum.TextXAlignment.Center,
			stroke = true,
		}),
	})
end

-- World prompt --------------------------------------------------------------------------------------------

local function Prompt()
	local ui = hooks.useUi()
	local target = ui.target
	if target == nil or ui.panel ~= "none" then
		return nil
	end
	local isNode = target.kind == "node"
	local pips: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 3),
		}),
	}
	if isNode and target.hits and target.hits > 1 then
		for index = 1, target.hits do
			pips[`P{index}`] = e("Frame", {
				Size = UDim2.fromOffset(10, 6),
				BackgroundColor3 = if index <= (target.hitsLeft or target.hits)
					then Theme.colors.accentSoft
					else Theme.colors.track,
				LayoutOrder = index,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
	end
	local height = target.model:GetExtentsSize().Y
	return ReactRoblox.createPortal(
		e("BillboardGui", {
			Adornee = target.model.PrimaryPart or target.model:FindFirstChildWhichIsA("BasePart", true),
			Size = UDim2.fromOffset(240, 64),
			StudsOffsetWorldSpace = Vector3.new(0, math.min(height, 10) * 0.5 + 2.5, 0),
			AlwaysOnTop = true,
			LightInfluence = 0,
			ResetOnSpawn = false,
		}, {
			Row = e("Frame", {
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Key = e(KeyChip, { text = if isNode then "LMB" else "E", accent = true, layoutOrder = 1 }),
				Pill = e("Frame", {
					Size = UDim2.fromOffset(0, 30),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = Theme.colors.panel,
					BackgroundTransparency = 0.15,
					LayoutOrder = 2,
				}, {
					Corner = e("UICorner", { CornerRadius = Theme.radius }),
					Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
					Text = e(Label, {
						text = `{target.verb} {target.label}`,
						style = "body",
						autoWidth = true,
						size = UDim2.fromOffset(0, 30),
					}),
				}),
			}),
			Pips = e(
				"Frame",
				{ Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, 42), BackgroundTransparency = 1 },
				pips
			),
		}),
		Players.LocalPlayer:WaitForChild("PlayerGui")
	)
end

-- An Ember Trail quest completing (LDOE_PARITY #50): the reward pop. Its rewards are already
-- in the inbox; the blueprints it unlocked are named. The next quest is on the tracker.
local function QuestDone()
	local shown, setShown = React.useState(nil :: any)
	React.useEffect(function()
		local connection = State.fx:Connect(function(kind: any, payload: any)
			if kind == "questDone" and type(payload) == "table" then
				setShown({ payload = payload, at = os.clock() })
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	hooks.useClock(0.5)
	if shown == nil or os.clock() - shown.at > 4.5 then
		return nil
	end
	local payload = shown.payload
	local quest = Content.Quests[payload.questId]
	local names: { string } = {}
	local listed: { [string]: boolean } = {}
	-- Two recipes can make one item (Iron Ingot from ore and from scrap): name it once.
	local function list(name: string)
		if not listed[name] then
			listed[name] = true
			table.insert(names, name)
		end
	end
	for _, recipeId in payload.recipes or {} do
		local recipe = Content.Recipes[recipeId]
		if recipe then
			list(format.itemName(recipe.outputs[1].itemId))
		end
	end
	for _, pieceId in payload.pieces or {} do
		local piece = Content.BuildPieces[pieceId]
		if piece then
			list(piece.name)
		end
	end
	local rewards: { [string]: any } = {}
	for index, stack in payload.items or {} do
		rewards[`R{index}`] = e(Layout.Stack, {
			direction = "row",
			gap = 4,
			alignY = Enum.VerticalAlignment.Center,
			size = UDim2.fromOffset(0, 36),
			autoSize = Enum.AutomaticSize.X,
			layoutOrder = index,
			children = {
				Icon = e("Frame", { Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, LayoutOrder = 1 }, {
					Icon = e(ItemIcon, { itemId = stack.itemId }),
				}),
				Count = e(Label, { text = `x{stack.count}`, style = "body", autoWidth = true, layoutOrder = 2 }),
			},
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(520, 150),
		Position = UDim2.new(0.5, 0, 0, 150),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.08,
		ZIndex = Theme.layers.toast,
		ref = mark.overlay, -- a short celebration over the world, like the level-up banner
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.accentSoft, Thickness = 2 }),
		Column = e(Layout.Stack, {
			gap = 4,
			alignX = Enum.HorizontalAlignment.Center,
			padding = Theme.spacing.md,
			children = {
				Title = e(Label, {
					text = `QUEST COMPLETE: {if quest then string.upper(quest.name) else ""}`,
					style = "title",
					tone = "highlight",
					alignX = Enum.TextXAlignment.Center,
					layoutOrder = 1,
				}),
				Rewards = e(Layout.Stack, {
					direction = "row",
					gap = Theme.spacing.md,
					alignX = Enum.HorizontalAlignment.Center,
					size = UDim2.new(1, 0, 0, 36),
					layoutOrder = 2,
					children = rewards,
				}),
				Note = e(Label, {
					text = if #names > 0
						then `New blueprints: {table.concat(names, ", ")}`
						else "Rewards are in your inbox",
					style = "caption",
					tone = "muted",
					alignX = Enum.TextXAlignment.Center,
					wrap = true,
					size = UDim2.new(1, 0, 0, 34),
					layoutOrder = 3,
				}),
			},
		}),
	})
end

-- A quest opening on the Ember Trail: its chapter, name and what it asks, in the same
-- spot as the completion pop and after it (MVP_LAUNCH's first session: the first quest
-- announces itself when a new player arrives).
local START_DELAY = 4.7 -- after a QUEST COMPLETE pop, so the two never overlap
local START_SECONDS = 4.5
local function QuestStart()
	local state = hooks.useSection("quests")
	local shown, setShown = React.useState(nil :: any)
	local known = React.useRef(nil :: { [string]: boolean }?)
	local lastDone = React.useRef(0)
	React.useEffect(function()
		local connection = State.fx:Connect(function(kind: any)
			if kind == "questDone" then
				lastDone.current = os.clock()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	React.useEffect(function()
		if type(state) ~= "table" then
			return
		end
		local rows = questText.rows(state, 3)
		local seen: { [string]: boolean } = {}
		local fresh: any = nil
		local before = known.current
		for _, row in rows do
			seen[row.questId] = true
			if before ~= nil and not before[row.questId] and fresh == nil then
				fresh = row
			end
		end
		-- On arrival, only a brand-new player (nothing completed yet) gets the first card.
		if before == nil and next(state.completed or {}) == nil and rows[1] then
			fresh = rows[1]
		end
		known.current = seen
		if fresh then
			local wait = math.max(0, START_DELAY - (os.clock() - (lastDone.current :: number)))
			local row = fresh
			task.delay(if lastDone.current == 0 then 1 else wait, function()
				setShown({ row = row, at = os.clock() })
			end)
		end
	end, { state })
	hooks.useClock(0.5)
	if shown == nil or os.clock() - shown.at > START_SECONDS then
		return nil
	end
	local quest = Content.Quests[shown.row.questId]
	return e("Frame", {
		Size = UDim2.fromOffset(520, 112),
		Position = UDim2.new(0.5, 0, 0, 150),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.08,
		ZIndex = Theme.layers.toast,
		ref = mark.overlay,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.accentSoft, Thickness = 2 }),
		Column = e(Layout.Stack, {
			gap = 2,
			alignX = Enum.HorizontalAlignment.Center,
			padding = Theme.spacing.md,
			children = {
				Chapter = e(Label, {
					text = string.upper(`Ember Trail: {shown.row.chapter}`),
					style = "caption",
					tone = "muted",
					alignX = Enum.TextXAlignment.Center,
					layoutOrder = 1,
				}),
				Title = e(Label, {
					text = string.upper(shown.row.name),
					style = "title",
					tone = "highlight",
					alignX = Enum.TextXAlignment.Center,
					layoutOrder = 2,
				}),
				Note = e(Label, {
					text = if quest then quest.description else "",
					style = "caption",
					tone = "text",
					alignX = Enum.TextXAlignment.Center,
					wrap = true,
					size = UDim2.new(1, 0, 0, 34),
					layoutOrder = 3,
				}),
			},
		}),
	})
end

local function Feed()
	usePrune()
	return e(React.Fragment, nil, {
		Toasts = e(Toasts),
		Rewards = e(Rewards),
		LevelUp = e(LevelUp),
		QuestDone = e(QuestDone),
		QuestStart = e(QuestStart),
		Prompt = e(Prompt),
	})
end

return Feed
