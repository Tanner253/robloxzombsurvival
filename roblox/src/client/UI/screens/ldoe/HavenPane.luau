--!strict
--[[
	HavenPane: the right half of LDoE's two-pane screen when you talk to someone on Haven
	Square (rec4; Data/Haven, Services/Haven). The inventory stays on the left with the
	coin balance in its header.

	- The Trader (Mara): BUY and SELL tabs in the action bar; each row is an item, what
	  you have of it, and its price on a coin button. Selling also works from the bag:
	  select a stack and press SELL (Panels' main action).
	- The Trail Keeper (Old Hale) and the contract board: today's three contracts with
	  DELIVER, the countdown to the next three, and finished Ember Trail chapters to hand in.
	- The Lounge Warden (Rook): the VIP Lounge's perks and JOIN with the Robux price, or the
	  member's next crate.
	- The notice board: what the square offers, one line each.

	An NPC's panel opens on its line of the day under its name (LDoE's talk).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Market = require(ReplicatedStorage.Shared.Domain.Market)
local Net = require("../../../Net")
local State = require("../../../State")
local Theme = require("../../theme")
local format = require("../../format")
local Glyph = require("../../components/Glyph")
local ItemIcon = require("../../components/ItemIcon")
local Layout = require("../../components/Layout")
local Sfx = require("../../../Sfx")
local Parts = require("./Parts")

local e = React.createElement

local DAY = 24 * 60 * 60
local ROBUX = "rbxasset://textures/ui/common/robux.png"
local ROW = 56

export type Props = {
	havenId: string,
	haven: any, -- the "haven" section (nil until it arrives)
	inventory: any,
	now: number,
	tab: string?, -- the Trader's tab: "buy" (default) or "sell"
}

-- Pieces ----------------------------------------------------------------------------------------------

-- Haven Square's coins (the trade currency, earned and spent on the square) wear the price
-- tag glyph; the coin glyph is the Embers premium currency's.
local function CoinsBalance(props: { coins: number })
	return e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.xs,
		alignY = Enum.VerticalAlignment.Center,
		size = UDim2.fromOffset(0, 44),
		autoSize = Enum.AutomaticSize.X,
		children = {
			Tag = e(Glyph, { name = "offer", size = UDim2.fromOffset(26, 26), layoutOrder = 1 }),
			Amount = e("TextLabel", {
				Size = UDim2.fromOffset(0, 26),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = `{props.coins} coins`,
				TextSize = Theme.textSize.body,
				TextColor3 = Theme.colors.text,
				LayoutOrder = 2,
			}),
		},
	})
end

-- A teal button showing a price in coins (LDoE's buy and sell buttons).
local function CoinButton(props: { coins: number, disabled: boolean, layoutOrder: number, onActivated: () -> () })
	return e("TextButton", {
		Size = UDim2.fromOffset(96, Theme.tapTarget),
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = not props.disabled,
		BackgroundColor3 = if props.disabled then Theme.colors.disabled else Theme.colors.chip,
		Text = "",
		[React.Event.Activated] = function()
			if props.disabled then
				Sfx.play("uiError")
			else
				Sfx.play("uiClick")
				props.onActivated()
			end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Stroke = e("UIStroke", {
			Color = (if props.disabled then Theme.colors.disabled else Theme.colors.chip):Lerp(
				Color3.new(1, 1, 1),
				0.2
			),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Row = e(Layout.Stack, {
			direction = "row",
			gap = Theme.spacing.xs,
			alignX = Enum.HorizontalAlignment.Center,
			alignY = Enum.VerticalAlignment.Center,
			children = {
				Coin = e(Glyph, { name = "offer", size = UDim2.fromOffset(22, 22), layoutOrder = 1 }),
				Amount = e("TextLabel", {
					Size = UDim2.fromOffset(0, 24),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.header,
					Text = tostring(props.coins),
					TextSize = Theme.textSize.body,
					TextColor3 = if props.disabled then Theme.colors.disabledText else Theme.colors.text,
					LayoutOrder = 2,
				}),
			},
		}),
	})
end

type RowProps = {
	itemId: string?,
	glyph: string?,
	title: string,
	detail: string,
	layoutOrder: number,
	buttons: { [string]: any }?,
}

-- One row: an item icon (or a glyph), a title over a detail line, buttons at the right.
local function Row(props: RowProps)
	local children: { [string]: any } = {
		Icon = e("Frame", {
			Size = UDim2.fromOffset(48, 48),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}, {
			Icon = if props.itemId
				then e(ItemIcon, { itemId = props.itemId })
				else e(Glyph, {
					name = props.glyph or "interact",
					size = UDim2.fromOffset(34, 34),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					color = Theme.colors.highlight,
				}),
		}),
		Text = e(Layout.Fill, {
			direction = "row",
			layoutOrder = 2,
			children = {
				Column = e(Layout.Stack, {
					gap = 0,
					alignY = Enum.VerticalAlignment.Center,
					children = {
						Title = e(Parts.Line, { text = props.title, tone = Theme.colors.text, layoutOrder = 1 }),
						Detail = e(Parts.Line, { text = props.detail, size = Theme.textSize.caption, layoutOrder = 2 }),
					},
				}),
			},
		}),
	}
	local buttons: { [string]: any } = props.buttons or {}
	for name, button in buttons do
		children[name] = button
	end
	return e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.sm,
		alignY = Enum.VerticalAlignment.Center,
		size = UDim2.new(1, -8, 0, ROW),
		layoutOrder = props.layoutOrder,
		children = children,
	})
end

local function List(rows: { [string]: any }, layoutOrder: number)
	return e(Layout.Fill, {
		layoutOrder = layoutOrder,
		children = {
			Scroll = e("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.fromScale(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, {
				Rows = e(Layout.Stack, {
					gap = Theme.spacing.xs,
					size = UDim2.fromScale(1, 0),
					autoSize = Enum.AutomaticSize.Y,
					children = rows,
				}),
			}),
		},
	})
end

-- The NPC's name and title, and their line of the day.
local function Speech(npcId: string, now: number)
	local npc = Content.Haven.npcs[npcId]
	if npc == nil then
		return nil
	end
	local line = npc.lines[(now // DAY) % #npc.lines + 1]
	return e(Layout.Stack, {
		gap = 2,
		size = UDim2.fromScale(1, 0),
		autoSize = Enum.AutomaticSize.Y,
		layoutOrder = 1,
		children = {
			Name = e(Parts.Line, { text = `{npc.name}, {npc.title}`, tone = Theme.colors.highlight, layoutOrder = 1 }),
			Line = e(Parts.Line, { text = line, wrap = true, layoutOrder = 2 }),
		},
	})
end

local function body(children: { [string]: any })
	return e(Layout.Stack, { gap = Theme.spacing.sm, children = children })
end

-- Panes ------------------------------------------------------------------------------------------------

local function Trader(props: Props)
	local coins = if props.haven then props.haven.coins else 0
	local selling = props.tab == "sell"
	local rows: { [string]: any } = {}
	local list: { Market.Price } = if selling then Content.Haven.trader.sell else Content.Haven.trader.buy
	for index, price in list do
		local owned = format.count(props.inventory, price.itemId)
		local buttons: { [string]: any }
		if selling then
			buttons = {
				One = e(CoinButton, {
					coins = price.coins,
					disabled = owned < 1,
					layoutOrder = 3,
					onActivated = function()
						Net.fire("HavenSell", price.itemId, 1)
					end,
				}),
				All = e(Parts.BarButton, {
					text = "All",
					width = 64,
					disabled = owned < 2,
					layoutOrder = 4,
					onActivated = function()
						Net.fire("HavenSell", price.itemId, math.min(owned, Market.MAX_TRADE))
					end,
				}),
			}
		else
			buttons = {
				Buy = e(CoinButton, {
					coins = price.coins,
					disabled = coins < price.coins,
					layoutOrder = 3,
					onActivated = function()
						Net.fire("HavenBuy", price.itemId, 1)
					end,
				}),
			}
		end
		rows[`R{index}`] = e(Row, {
			itemId = price.itemId,
			title = format.itemName(price.itemId),
			detail = if owned > 0 then `You have {owned}` else "You have none",
			layoutOrder = index,
			buttons = buttons,
		})
	end
	local function tab(name: string, text: string, order: number)
		local active = (props.tab or "buy") == name
		return e(Parts.BarButton, {
			text = text,
			width = 130,
			tone = if active then "teal" else "plain",
			layoutOrder = order,
			onActivated = function()
				State.patch({ havenTab = name })
			end,
		})
	end
	return e(Parts.Pane, {
		header = e(Parts.Header, {
			glyph = "talk",
			title = "Trading Post",
			chip = true,
			right = { Coins = e(CoinsBalance, { coins = coins }) },
		}),
		body = body({
			Speech = Speech("npc.trader", props.now),
			List = List(rows, 2),
		}),
		bar = e(Parts.Bar, {
			alignX = Enum.HorizontalAlignment.Center,
			children = { Buy = tab("buy", "Buy", 1), Sell = tab("sell", "Sell", 2) },
		}),
	})
end

local function Contracts(props: Props)
	local haven = props.haven
	local keeper = props.havenId == "npc.keeper"
	local rows: { [string]: any } = {}
	local order = 0
	for _, contract in (if haven then haven.contracts else {}) do
		order += 1
		local owned = format.count(props.inventory, contract.itemId)
		local name = format.itemName(contract.itemId)
		rows[contract.id] = e(Row, {
			itemId = contract.itemId,
			title = `Deliver {contract.count} {name}`,
			detail = if contract.done
				then "Delivered"
				else `{contract.coins} coins, {contract.xp} XP. You have {math.min(owned, contract.count)}/{contract.count}`,
			layoutOrder = order,
			buttons = {
				Deliver = if contract.done
					then e(Parts.BarButton, { glyph = "check", disabled = true, layoutOrder = 3 })
					else e(Parts.BarButton, {
						text = "Deliver",
						width = 110,
						tone = "teal",
						disabled = owned < contract.count,
						layoutOrder = 3,
						onActivated = function()
							Net.fire("ContractDeliver", contract.id)
						end,
					}),
			},
		})
	end
	if keeper then
		for _, chapter in (if haven then haven.chapters else {}) do
			local reward = Content.Haven.chapterRewards[chapter]
			if reward then
				order += 1
				rows[`chapter{order}`] = e(Row, {
					glyph = "quests",
					title = `Chapter: {chapter}`,
					detail = `Finished. {reward.coins} coins and supplies`,
					layoutOrder = order,
					buttons = {
						Claim = e(Parts.BarButton, {
							text = "Hand in",
							width = 110,
							tone = "green",
							layoutOrder = 3,
							onActivated = function()
								Net.fire("ChapterClaim", chapter)
							end,
						}),
					},
				})
			end
		end
	end
	local resets = if haven then haven.resetsAt - props.now else 0
	return e(Parts.Pane, {
		header = e(Parts.Header, {
			glyph = if keeper then "talk" else "quests",
			title = if keeper then "Trail Keeper" else "Contract Board",
			chip = true,
			right = { Coins = e(CoinsBalance, { coins = if haven then haven.coins else 0 }) },
		}),
		body = body({
			Speech = if keeper then Speech("npc.keeper", props.now) else nil,
			List = List(rows, 2),
		}),
		bar = e(Parts.Bar, {
			alignX = Enum.HorizontalAlignment.Center,
			children = {
				Reset = e(Parts.Line, { text = `New contracts in {format.duration(resets)}`, center = true }),
			},
		}),
	})
end

local PERKS = {
	{ glyph = "campfire", title = "The Lounge fire", detail = "A warm fire and seats behind the gate" },
	{ glyph = "favourite", title = "Flame aura", detail = "Embers at your feet while you are a member" },
	{ glyph = "gift", title = "Daily VIP crate", detail = "Food, water, a dressing and fatwood in your inbox" },
	{ glyph = "energy", title = "+20% Energy cap", detail = "More Energy for the road into the Fog" },
}

local function Lounge(props: Props)
	local haven = props.haven
	local member = haven ~= nil and haven.vip == true
	local rows: { [string]: any } = {}
	for index, perk in PERKS do
		rows[`P{index}`] = e(Row, { glyph = perk.glyph, title = perk.title, detail = perk.detail, layoutOrder = index })
	end
	local price = if haven then haven.vipPrice else Content.Haven.vip.priceRobux
	local bar: any
	if member then
		local crateIn = if haven.crateAt > 0 then haven.crateAt - props.now else 0
		bar = e(Parts.Line, {
			text = if crateIn > 0
				then `You are a member. Next crate in {format.duration(crateIn)}`
				else "You are a member. Your crate is on its way",
			tone = Theme.colors.highlight,
			center = true,
		})
	else
		bar = e("TextButton", {
			Size = UDim2.fromOffset(190, Theme.tapTarget),
			BackgroundColor3 = Theme.colors.upgrade,
			Text = "",
			[React.Event.Activated] = function()
				Sfx.play("uiClick")
				Net.fire("VipBuy")
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Row = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.sm,
				alignX = Enum.HorizontalAlignment.Center,
				alignY = Enum.VerticalAlignment.Center,
				children = {
					Join = e("TextLabel", {
						Size = UDim2.fromOffset(0, 24),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						FontFace = Theme.fonts.header,
						Text = "JOIN",
						TextSize = Theme.textSize.body,
						TextColor3 = Theme.colors.text,
						LayoutOrder = 1,
					}),
					Robux = e("ImageLabel", {
						Size = UDim2.fromOffset(22, 22),
						BackgroundTransparency = 1,
						Image = ROBUX,
						LayoutOrder = 2,
					}),
					Price = e("TextLabel", {
						Size = UDim2.fromOffset(0, 24),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						FontFace = Theme.fonts.header,
						Text = tostring(price),
						TextSize = Theme.textSize.body,
						TextColor3 = Theme.colors.text,
						LayoutOrder = 3,
					}),
				},
			}),
		})
	end
	return e(Parts.Pane, {
		header = e(Parts.Header, { glyph = "talk", title = "VIP Lounge", chip = true }),
		body = body({
			Speech = Speech("npc.gatekeeper", props.now),
			List = List(rows, 2),
		}),
		bar = e(Parts.Bar, { alignX = Enum.HorizontalAlignment.Center, children = { Action = bar } }),
	})
end

local NOTICES = {
	{ glyph = "defense", title = "Safe ground", detail = "No Hollow and no fighting on Haven Square" },
	{ glyph = "offer", title = "Trading Post", detail = "Mara buys timber, stone and scrap and sells supplies" },
	{ glyph = "quests", title = "Contracts", detail = "Three jobs a day on Old Hale's board" },
	{ glyph = "map", title = "The Trailhead", detail = "The trail to the Fog leaves north of the square" },
	{ glyph = "pass", title = "VIP Lounge", detail = "Members rest by their own fire, south-east" },
	{ glyph = "crew", title = "Guild banners", detail = "Guilds will raise their banners on the square" },
}

local function Notices(_props: Props)
	local rows: { [string]: any } = {}
	for index, notice in NOTICES do
		rows[`N{index}`] =
			e(Row, { glyph = notice.glyph, title = notice.title, detail = notice.detail, layoutOrder = index })
	end
	return e(Parts.Pane, {
		header = e(Parts.Header, { glyph = "quests", title = "Notice Board", chip = true }),
		body = body({ List = List(rows, 1) }),
	})
end

local function HavenPane(props: Props)
	if props.havenId == "npc.trader" then
		return e(Trader, props)
	elseif props.havenId == "npc.keeper" or props.havenId == "board.contracts" then
		return e(Contracts, props)
	elseif props.havenId == "npc.gatekeeper" then
		return e(Lounge, props)
	end
	return e(Notices, props)
end

return HavenPane
