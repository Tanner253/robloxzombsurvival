--!strict
--[[
	Shop: the v0.1 shop in LDoE's shop style (rec8_shop_073s; MVP_LAUNCH). Full screen with
	the CLOSE strip:
	- a key-art banner across the top with the shop's line;
	- "BEST" and one row of product cards: ribbon (Limited / Popular), name, what it is,
	  what is in it (item chips with counts, +Energy, +slots), the product art, the
	  purchase limit and level window, and the teal price button (OWNED once a limit is
	  reached);
	- the bottom bar: INBOX at the left (purchases arrive there), the BEST tab.
	Prices are the live Robux prices from the server ("shop" section). No invented "was"
	prices: the ribbons and limits are the only urgency. A moment-of-need button opens
	the shop on its product (shopFocus), which is outlined.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Actions = require("../../../Actions")
local Theme = require("../../theme")
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

-- The order cards stand in, and their ribbons (LDoE's "Limited" / "Popular").
local ORDER = { "product.starter_offer", "product.resource_pack", "product.backpack_upgrade", "product.energy_refill" }
local RIBBONS: { [string]: { text: string, color: Color3 } } = {
	["product.starter_offer"] = { text = "Limited", color = Theme.colors.accent },
	["product.resource_pack"] = { text = "Popular", color = Theme.rarity.epic },
}

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

local function Card(props: { productId: string, state: any, focused: boolean, height: number, layoutOrder: number })
	local product: any = Content.Products[props.productId]
	local state = props.state or {}
	local ribbon = RIBBONS[props.productId]
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
	local limitText = if product.offerMaxLevel
		then `Once, until level {product.offerMaxLevel}`
		elseif product.limit then `Once per survivor`
		else "Buy as often as you like"
	local stroke = if props.focused
		then Theme.colors.accentSoft
		elseif ribbon then ribbon.color
		else Theme.colors.strokeWarm
	return e("Frame", {
		Size = UDim2.new(0.25, -12, 0, props.height),
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
					Text = string.upper(product.name),
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
					Text = product.description,
					TextSize = Theme.textSize.caption,
					TextColor3 = Theme.colors.textMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextWrapped = true,
					LayoutOrder = 3,
				}),
				Art = e(Layout.Fill, {
					direction = "column",
					layoutOrder = 4,
					children = {
						Image = e("ImageLabel", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Image = product.icon or "",
							ScaleType = Enum.ScaleType.Fit,
						}),
					},
				}),
				Chips = e(Layout.Stack, {
					direction = "row",
					gap = Theme.spacing.xs,
					alignY = Enum.VerticalAlignment.Center,
					size = UDim2.new(1, 0, 0, 34),
					layoutOrder = 5,
					children = chips,
				}),
				Limit = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.body,
					Text = limitText,
					TextSize = Theme.textSize.caption,
					TextColor3 = Theme.colors.textMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 6,
				}),
				Buy = e("TextButton", {
					Size = UDim2.new(1, 0, 0, Theme.tapTarget),
					AutoButtonColor = available,
					BackgroundColor3 = if available then Theme.colors.chip else Theme.colors.disabled,
					Text = "",
					LayoutOrder = 7,
					[React.Event.Activated] = function()
						if available then
							Actions.buyProduct(props.productId)
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
							Robux = available and e("ImageLabel", {
								Size = UDim2.fromOffset(22, 22),
								BackgroundTransparency = 1,
								Image = ROBUX,
								LayoutOrder = 1,
							}),
							Price = e("TextLabel", {
								Size = UDim2.fromOffset(0, 28),
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								FontFace = Theme.fonts.header,
								Text = if owned
									then "OWNED"
									elseif available then tostring(state.price or product.defaultPriceRobux)
									else "NOT ON OFFER",
								TextSize = Theme.textSize.title,
								TextColor3 = if available then Theme.colors.text else Theme.colors.disabledText,
								LayoutOrder = 2,
							}),
						},
					}),
				}),
			},
		}),
	})
end

local function Shop()
	local ui = hooks.useUi()
	local state = hooks.useSection("shop")
	local inbox = hooks.useSection("inbox")
	local open = ui.panel == "shop"
	local frame = Theme.currentFrame
	-- A phone's design frame is shorter: the banner gives way first.
	local bannerHeight = if frame.Y < 700 then 92 else 150
	local barHeight = 64
	-- Cards take the height left (LDoE's fill the screen), within reason.
	local cardHeight = math.max(300, math.min(520, frame.Y - bannerHeight - barHeight - 110))
	local cards: { [string]: any } = {}
	for index, productId in ORDER do
		cards[`P{index}`] = e(Card, {
			productId = productId,
			state = if type(state) == "table" then state[productId] else nil,
			focused = ui.shopFocus == productId,
			height = cardHeight,
			layoutOrder = index,
		})
	end
	local inboxCount = if type(inbox) == "table" then #inbox else 0
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
									Text = "SUPPLIES",
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
										Text = "BEST",
										TextSize = Theme.textSize.section,
										TextColor3 = Theme.colors.text,
										TextXAlignment = Enum.TextXAlignment.Left,
										LayoutOrder = 1,
									}),
									Cards = e(Layout.Stack, {
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
						Tab = e(Layout.Stack, {
							direction = "row",
							gap = Theme.spacing.xs,
							alignX = Enum.HorizontalAlignment.Center,
							alignY = Enum.VerticalAlignment.Center,
							size = UDim2.fromOffset(120, barHeight),
							position = UDim2.fromScale(0.5, 0),
							anchorPoint = Vector2.new(0.5, 0),
							children = {
								Icon = e(Glyph, {
									name = "offer",
									size = UDim2.fromOffset(26, 26),
									color = Theme.colors.text,
									layoutOrder = 1,
								}),
								Label = e("TextLabel", {
									Size = UDim2.fromOffset(0, 26),
									AutomaticSize = Enum.AutomaticSize.X,
									BackgroundTransparency = 1,
									FontFace = Theme.fonts.header,
									Text = "BEST",
									TextSize = Theme.textSize.body,
									TextColor3 = Theme.colors.text,
									LayoutOrder = 2,
								}),
							},
						}),
						Underline = e("Frame", {
							Size = UDim2.fromOffset(100, 3),
							Position = UDim2.new(0.5, 0, 1, -6),
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundColor3 = Theme.colors.badge,
							BorderSizePixel = 0,
						}),
					}),
				},
			}),
		},
	})
end

return Shop
