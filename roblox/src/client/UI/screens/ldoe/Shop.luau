--!strict
--[[
	Shop: the v0.1 shop in LDoE's shop style (rec8_shop_073s; MVP_LAUNCH Monetization v0.1).
	Full screen with the CLOSE strip:
	- a key-art banner across the top with the shop's line;
	- one row of cards for the tab: ribbon, name, what it is, what is in it (item chips with
	  counts, +Energy, +slots, +Embers, the Lounge), the product art, the limit or the
	  Firestarter Kit's accurate countdown, and the price button (OWNED once a limit is
	  reached). Robux products show the live price; Trail Rations on the EMBERS tab are
	  priced in Embers;
	- the bottom bar: INBOX at the left (purchases arrive there), the tabs (BEST, SUPPLIES,
	  EMBERS, PASSES), the Embers balance at the right.
	No invented "was" prices: ribbons, limits and real countdowns are the only urgency. A
	moment-of-need button opens the shop on its product (shopFocus, outlined) and its tab.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Offers = require(ReplicatedStorage.Shared.Domain.Offers)
local Actions = require("../../../Actions")
local Net = require("../../../Net")
local Sfx = require("../../../Sfx")
local State = require("../../../State")
local Theme = require("../../theme")
local format = require("../../format")
local hooks = require("../../hooks")
local mark = require("../../mark")
local FullScreen = require("../../components/FullScreen")
local Glyph = require("../../components/Glyph")
local IconButton = require("../../components/IconButton")
local ItemIcon = require("../../components/ItemIcon")
local Layout = require("../../components/Layout")

local e = React.createElement

local KEY_ART = "rbxassetid://118390976045902" -- the loading key art: dusk at an outpost
local ROBUX = "rbxasset://textures/ui/common/robux.png"
local CARDS = 4

export type Tab = "best" | "supplies" | "equipment" | "building" | "embers" | "passes"

local TABS: { { id: Tab, label: string, glyph: string } } = {
	{ id = "best", label = "BEST", glyph = "offer" },
	{ id = "supplies", label = "SUPPLIES", glyph = "storage" },
	{ id = "equipment", label = "EQUIPMENT", glyph = "attack" },
	{ id = "building", label = "BUILDING", glyph = "build" },
	{ id = "embers", label = "EMBERS", glyph = "coin" },
	{ id = "passes", label = "PASSES", glyph = "pass" },
}

-- What each tab shows, in order. BEST tops up with featured products to fill its row.
local ORDER: { [Tab]: { string } } = {
	best = { "product.starter_offer", "product.builders_crate", "product.room_kit_reinforced", "product.embers_300" },
	supplies = {
		"product.scavenger_kit",
		"product.resource_pack",
		"product.room_kit_reinforced",
		"product.energy_refill",
	},
	-- LDoE's Equipment tab (rec8_sheet4): kits, guns, parts and armor, cheapest first.
	equipment = {
		"product.scouts_kit",
		"product.weapon_parts",
		"product.padded_armor",
		"product.gunrunner_pack",
		"product.raider_arms",
		"product.heavy_equipment",
	},
	-- Capacity: one more of a capped station may stand on the plot.
	building = { "product.smelter_slot", "product.recycler_slot" },
	embers = { "product.embers_50", "product.embers_300" },
	passes = { "product.pack_expansion", "product.vip_lounge" },
}
local BEST_FILL = { "product.resource_pack", "product.scavenger_kit" }

local RIBBONS: { [string]: { text: string, color: Color3 } } = {
	["product.starter_offer"] = { text = "Limited", color = Theme.colors.accent },
	["product.resource_pack"] = { text = "Popular", color = Theme.rarity.epic },
	["product.embers_300"] = { text = "Best value", color = Theme.rarity.legendary },
	["product.gunrunner_pack"] = { text = "Hot", color = Theme.colors.accent },
}

-- Trail Rations for Embers (the EMBERS tab's own cards).
local RATIONS = { 1, 5 }

local function Chip(props: { glyph: string?, itemId: string?, text: string, layoutOrder: number })
	return e(Layout.Stack, {
		direction = "row",
		gap = 2,
		alignY = Enum.VerticalAlignment.Center,
		size = UDim2.fromOffset(0, 34),
		autoSize = Enum.AutomaticSize.X,
		layoutOrder = props.layoutOrder,
		children = {
			Icon = e("Frame", {
				Size = UDim2.fromOffset(32, 32),
				BackgroundColor3 = Theme.colors.panelRaised,
				LayoutOrder = 1,
				ref = mark.composite,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Item = props.itemId and e(ItemIcon, { itemId = props.itemId, size = UDim2.fromScale(1, 1) }),
				Glyph = props.glyph and e(Glyph, {
					name = props.glyph,
					size = UDim2.fromOffset(22, 22),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					color = Theme.colors.bonus,
				}),
			}),
			Count = e("TextLabel", {
				Size = UDim2.fromOffset(0, 32),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = props.text,
				TextSize = Theme.textSize.caption,
				TextColor3 = Theme.colors.text,
				LayoutOrder = 2,
			}),
		},
	})
end

-- The price button: Robux (with the Robux mark) or Embers (with the coin glyph).
local function PriceButton(props: {
	currency: "robux" | "embers",
	price: number?,
	text: string?,
	enabled: boolean,
	layoutOrder: number,
	onActivated: () -> (),
})
	return e("TextButton", {
		Size = UDim2.new(1, 0, 0, Theme.tapTarget),
		AutoButtonColor = props.enabled,
		BackgroundColor3 = if props.enabled then Theme.colors.chip else Theme.colors.disabled,
		Text = "",
		LayoutOrder = props.layoutOrder,
		[React.Event.Activated] = function()
			if props.enabled then
				props.onActivated()
			else
				Sfx.play("uiError")
			end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Row = e(Layout.Stack, {
			direction = "row",
			gap = 6,
			alignX = Enum.HorizontalAlignment.Center,
			alignY = Enum.VerticalAlignment.Center,
			children = {
				Robux = props.price ~= nil and props.currency == "robux" and e("ImageLabel", {
					Size = UDim2.fromOffset(22, 22),
					BackgroundTransparency = 1,
					Image = ROBUX,
					LayoutOrder = 1,
				}),
				Coin = props.price ~= nil
					and props.currency == "embers"
					and e(Glyph, { name = "coin", size = UDim2.fromOffset(24, 24), layoutOrder = 1 }),
				Price = e("TextLabel", {
					Size = UDim2.fromOffset(0, 28),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.header,
					Text = props.text or tostring(props.price),
					TextSize = Theme.textSize.title,
					TextColor3 = if props.enabled then Theme.colors.text else Theme.colors.disabledText,
					LayoutOrder = 2,
				}),
			},
		}),
	})
end

type CardProps = {
	name: string,
	description: string,
	icon: string?,
	itemIcon: string?,
	chips: { [string]: any },
	limitText: string,
	ribbon: { text: string, color: Color3 }?,
	focused: boolean,
	height: number,
	layoutOrder: number,
	button: any,
	fraction: number?, -- the card's share of its row (1 / CARDS unless the row scrolls)
}

local function CardFrame(props: CardProps)
	local stroke = if props.focused
		then Theme.colors.accentSoft
		elseif props.ribbon then props.ribbon.color
		else Theme.colors.strokeWarm
	local ribbon = props.ribbon
	return e("Frame", {
		Size = UDim2.new(props.fraction or 1 / CARDS, -12, 0, props.height),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.04,
		LayoutOrder = props.layoutOrder,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = e("UIStroke", { Color = stroke, Thickness = if props.focused then 3 else 2 }),
		Column = e(Layout.Stack, {
			gap = Theme.spacing.xs,
			padding = Theme.spacing.md,
			children = {
				Top = e("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1 }, {
					Ribbon = ribbon and e("TextLabel", {
						Size = UDim2.fromOffset(0, 22),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundColor3 = ribbon.color,
						FontFace = Theme.fonts.header,
						Text = ribbon.text,
						TextSize = Theme.textSize.caption,
						TextColor3 = Theme.colors.text,
					}, {
						Padding = Layout.pad(0, { left = 8, right = 8 }),
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
					}),
				}),
				Name = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.header,
					Text = string.upper(props.name),
					TextSize = Theme.textSize.title,
					TextColor3 = Theme.colors.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = 2,
				}),
				Line = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 40),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.body,
					Text = props.description,
					TextSize = Theme.textSize.caption,
					TextColor3 = Theme.colors.textMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextWrapped = true,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = 3,
				}),
				Art = e(Layout.Fill, {
					direction = "column",
					layoutOrder = 4,
					children = {
						Image = props.icon and e("ImageLabel", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Image = props.icon,
							ScaleType = Enum.ScaleType.Fit,
						}),
						Item = props.itemIcon and e("Frame", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
						}, {
							Ratio = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
							Icon = e(ItemIcon, { itemId = props.itemIcon, size = UDim2.fromScale(1, 1) }),
						}),
					},
				}),
				Chips = e(Layout.Stack, {
					direction = "row",
					gap = Theme.spacing.xs,
					alignY = Enum.VerticalAlignment.Center,
					size = UDim2.new(1, 0, 0, 34),
					layoutOrder = 5,
					children = props.chips,
				}),
				Limit = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.body,
					Text = props.limitText,
					TextSize = Theme.textSize.caption,
					TextColor3 = Theme.colors.textMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 6,
				}),
				Buy = props.button,
			},
		}),
	})
end

local function ProductCard(props: {
	productId: string,
	state: any,
	now: number,
	focused: boolean,
	height: number,
	layoutOrder: number,
	fraction: number?,
})
	local product: any = Content.Products[props.productId]
	local state = props.state or {}
	local owned = state.reason == "limit"
	local available = state.available == true
	local chips: { [string]: any } = {}
	local index = 0
	for _, grant in product.grants do
		index += 1
		if index > 4 then
			break -- the art and the description say the rest
		end
		if grant.kind == "item" then
			chips[`C{index}`] = e(Chip, { itemId = grant.itemId, text = `x{grant.count}`, layoutOrder = index })
		elseif grant.kind == "energy" then
			chips[`C{index}`] = e(Chip, { glyph = "energy", text = `+{grant.amount}`, layoutOrder = index })
		elseif grant.kind == "backpackSlots" then
			chips[`C{index}`] = e(Chip, { glyph = "backpack", text = `+{grant.amount} slots`, layoutOrder = index })
		elseif grant.kind == "embers" then
			chips[`C{index}`] = e(Chip, { glyph = "coin", text = `+{grant.amount}`, layoutOrder = index })
		elseif grant.kind == "vipLounge" then
			chips[`C{index}`] = e(Chip, { glyph = "pass", text = "Lounge", layoutOrder = index })
		elseif grant.kind == "pieceSlot" then
			chips[`C{index}`] = e(Chip, { glyph = "build", text = `+{grant.amount} placed`, layoutOrder = index })
		end
	end
	local extra = #product.grants - 4
	if extra > 0 then
		chips.More = e("TextLabel", {
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.header,
			Text = `+{extra}`,
			TextSize = Theme.textSize.body,
			TextColor3 = Theme.colors.textMuted,
			LayoutOrder = 9,
		})
	end
	local endsAt = state.endsAt or 0
	local limitText = if endsAt > 0 and available
		then `Once, ends in {format.duration(endsAt - props.now)}`
		elseif product.kind == "gamePass" then "Yours for good"
		elseif product.limit == 1 then "Once per survivor"
		elseif product.limit then `Up to {product.limit} per survivor`
		else "Buy as often as you like"
	return e(CardFrame, {
		name = product.name,
		description = product.description,
		icon = product.icon,
		chips = chips,
		limitText = limitText,
		ribbon = RIBBONS[props.productId],
		focused = props.focused,
		height = props.height,
		layoutOrder = props.layoutOrder,
		fraction = props.fraction,
		button = e(PriceButton, {
			currency = "robux",
			price = if available then state.price or product.defaultPriceRobux else nil,
			text = if owned then "OWNED" elseif not available then "NOT ON OFFER" else nil,
			enabled = available,
			layoutOrder = 7,
			onActivated = function()
				Actions.buyProduct(props.productId)
			end,
		}),
	})
end

local function RationsCard(props: { count: number, embers: number, height: number, layoutOrder: number })
	local price = Offers.rationsPrice(props.count, Content.Tuning.embers :: any)
	return e(CardFrame, {
		name = if props.count == 1 then "Trail Ration" else `{props.count} Trail Rations`,
		description = "The travel currency: AUTO, TAKE ALL and more on the road. To your inbox.",
		itemIcon = "item.rations",
		chips = { C1 = e(Chip, { itemId = "item.rations", text = `x{props.count}`, layoutOrder = 1 }) },
		limitText = if props.count > 1
			then `Save {props.count * Content.Tuning.embers.ration - price} Embers`
			else "Paid in Embers",
		focused = false,
		height = props.height,
		layoutOrder = props.layoutOrder,
		button = e(PriceButton, {
			currency = "embers",
			price = price,
			enabled = props.embers >= price,
			layoutOrder = 7,
			onActivated = function()
				Net.fire("EmbersRations", props.count)
				Sfx.play("uiClick")
			end,
		}),
	})
end

-- The products a tab shows: BEST leads with the Firestarter Kit only while it is on offer.
local function listFor(tab: Tab, state: any): { string }
	local list: { string } = {}
	for _, id in ORDER[tab] do
		local entry = if type(state) == "table" then state[id] else nil
		if id == "product.starter_offer" and not (entry and entry.available) then
			continue
		end
		table.insert(list, id)
	end
	if tab == "best" then
		for _, id in BEST_FILL do
			if #list >= CARDS then
				break
			end
			table.insert(list, id)
		end
	end
	return list
end

local function Shop()
	local ui = hooks.useUi()
	local state = hooks.useSection("shop")
	local inbox = hooks.useSection("inbox")
	local wallet = hooks.useSection("wallet")
	local now = hooks.useClock(1)
	local open = ui.panel == "shop"
	local tab: Tab = (ui.shopTab :: any) or "best"
	local balance = if type(wallet) == "table" then wallet.embers else 0
	local frame = Theme.currentFrame
	-- A phone's design frame is shorter: the banner gives way first.
	local bannerHeight = if frame.Y < 700 then 92 else 150
	local barHeight = 64
	-- Cards take the height left (LDoE's fill the screen), within reason.
	local cardHeight = math.max(300, math.min(520, frame.Y - bannerHeight - barHeight - 110))
	local cards: { [string]: any } = {}
	local order = 0
	local listed = listFor(tab, state)
	-- More cards than a row holds: the row scrolls sideways, each card keeping its width.
	local scrolls = #listed > CARDS
	local fraction = if scrolls then 1 / #listed else nil
	for _, productId in listed do
		order += 1
		cards[`P{order}`] = e(ProductCard, {
			productId = productId,
			state = if type(state) == "table" then state[productId] else nil,
			now = now,
			focused = ui.shopFocus == productId,
			height = cardHeight,
			layoutOrder = order,
			fraction = fraction,
		})
	end
	if tab == "embers" then
		for _, count in RATIONS do
			order += 1
			cards[`R{count}`] =
				e(RationsCard, { count = count, embers = balance, height = cardHeight, layoutOrder = order })
		end
	end
	local tabs: { [string]: any } = {}
	for index, entry in TABS do
		local active = entry.id == tab
		tabs[entry.id] = e("TextButton", {
			Size = UDim2.fromOffset(150, barHeight),
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = index,
			[React.Event.Activated] = function()
				State.patch({ shopTab = entry.id })
				State.clear("shopFocus")
				Sfx.play("uiClick")
			end,
		}, {
			Row = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.xs,
				alignX = Enum.HorizontalAlignment.Center,
				alignY = Enum.VerticalAlignment.Center,
				children = {
					Icon = e(Glyph, {
						name = entry.glyph,
						size = UDim2.fromOffset(26, 26),
						color = if active then Theme.colors.text else Theme.colors.textMuted,
						layoutOrder = 1,
					}),
					Label = e("TextLabel", {
						Size = UDim2.fromOffset(0, 26),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						FontFace = Theme.fonts.header,
						Text = entry.label,
						TextSize = Theme.textSize.body,
						TextColor3 = if active then Theme.colors.text else Theme.colors.textMuted,
						LayoutOrder = 2,
					}),
				},
			}),
			Underline = active and e("Frame", {
				Size = UDim2.new(1, -30, 0, 3),
				Position = UDim2.new(0.5, 0, 1, -6),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Theme.colors.badge,
				BorderSizePixel = 0,
			}),
		})
	end
	local inboxCount = if type(inbox) == "table" then #inbox else 0
	local section = ""
	for _, entry in TABS do
		if entry.id == tab then
			section = entry.label
		end
	end
	return e(FullScreen, {
		open = open,
		onClose = Actions.closePanel,
		body = {
			Column = e(Layout.Stack, {
				gap = 0,
				children = {
					Banner = e("ImageLabel", {
						Size = UDim2.new(1, 0, 0, bannerHeight),
						BackgroundColor3 = Theme.colors.panel,
						Image = KEY_ART,
						ScaleType = Enum.ScaleType.Crop,
						LayoutOrder = 1,
					}, {
						Shade = e("UIGradient", {
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(0.55, 0),
								NumberSequenceKeypoint.new(1, 0.35),
							}),
						}),
						Words = e(Layout.Stack, {
							gap = 2,
							alignX = Enum.HorizontalAlignment.Right,
							size = UDim2.fromScale(0.5, 1),
							position = UDim2.new(1, -Theme.spacing.xl, 0, Theme.spacing.lg),
							anchorPoint = Vector2.new(1, 0),
							children = {
								Title = e("TextLabel", {
									Size = UDim2.new(1, 0, 0, 30),
									BackgroundTransparency = 1,
									FontFace = Theme.fonts.header,
									Text = "OUTPOST SHOP",
									TextSize = Theme.textSize.header,
									TextColor3 = Theme.colors.text,
									TextXAlignment = Enum.TextXAlignment.Right,
									TextStrokeTransparency = 0.6,
									LayoutOrder = 1,
								}),
								Line = e("TextLabel", {
									Size = UDim2.new(1, 0, 0, 22),
									BackgroundTransparency = 1,
									FontFace = Theme.fonts.body,
									Text = "Everything here is yours to keep",
									TextSize = Theme.textSize.body,
									TextColor3 = Theme.colors.text,
									TextXAlignment = Enum.TextXAlignment.Right,
									TextStrokeTransparency = 0.6,
									LayoutOrder = 2,
								}),
							},
						}),
					}),
					Content = e(Layout.Fill, {
						direction = "column",
						layoutOrder = 2,
						children = {
							Inner = e(Layout.Stack, {
								gap = Theme.spacing.sm,
								padding = Theme.spacing.lg,
								children = {
									Section = e("TextLabel", {
										Size = UDim2.new(1, 0, 0, 26),
										BackgroundTransparency = 1,
										FontFace = Theme.fonts.header,
										Text = section,
										TextSize = Theme.textSize.section,
										TextColor3 = Theme.colors.text,
										TextXAlignment = Enum.TextXAlignment.Left,
										LayoutOrder = 1,
									}),
									Cards = if scrolls
										then e("ScrollingFrame", {
											Size = UDim2.new(1, 0, 0, cardHeight + 12),
											CanvasSize = UDim2.fromScale(#listed / CARDS, 0),
											ScrollingDirection = Enum.ScrollingDirection.X,
											ScrollBarThickness = 6,
											ScrollBarImageColor3 = Theme.colors.textMuted,
											BackgroundTransparency = 1,
											BorderSizePixel = 0,
											LayoutOrder = 2,
										}, {
											Row = e(Layout.Stack, {
												direction = "row",
												gap = 16,
												size = UDim2.new(1, 0, 0, cardHeight),
												children = cards,
											}),
										})
										else e(Layout.Stack, {
											direction = "row",
											gap = 16,
											size = UDim2.new(1, 0, 0, cardHeight),
											layoutOrder = 2,
											children = cards,
										}),
								},
							}),
						},
					}),
					Bar = e("Frame", {
						Size = UDim2.new(1, 0, 0, barHeight),
						BackgroundColor3 = Theme.colors.panel,
						BackgroundTransparency = 0.1,
						BorderSizePixel = 0,
						LayoutOrder = 3,
					}, {
						Inbox = e(IconButton, {
							glyph = "inbox",
							caption = "INBOX",
							size = 52,
							square = true,
							badge = inboxCount,
							position = UDim2.new(0, Theme.spacing.lg, 0.5, 0),
							anchorPoint = Vector2.new(0, 0.5),
							onPress = Actions.openInbox,
						}),
						Tabs = e(Layout.Stack, {
							direction = "row",
							gap = 0,
							alignX = Enum.HorizontalAlignment.Center,
							size = UDim2.fromOffset(150 * #TABS, barHeight),
							position = UDim2.fromScale(0.5, 0),
							anchorPoint = Vector2.new(0.5, 0),
							children = tabs,
						}),
						Balance = e(Layout.Stack, {
							direction = "row",
							gap = Theme.spacing.xs,
							alignX = Enum.HorizontalAlignment.Right,
							alignY = Enum.VerticalAlignment.Center,
							size = UDim2.fromOffset(140, barHeight),
							position = UDim2.new(1, -Theme.spacing.lg, 0, 0),
							anchorPoint = Vector2.new(1, 0),
							children = {
								Coin = e(Glyph, { name = "coin", size = UDim2.fromOffset(28, 28), layoutOrder = 1 }),
								Amount = e("TextLabel", {
									Size = UDim2.fromOffset(0, 28),
									AutomaticSize = Enum.AutomaticSize.X,
									BackgroundTransparency = 1,
									FontFace = Theme.fonts.header,
									Text = tostring(balance),
									TextSize = Theme.textSize.title,
									TextColor3 = Theme.colors.text,
									LayoutOrder = 2,
								}),
							},
						}),
					}),
				},
			}),
		},
	})
end

return Shop
