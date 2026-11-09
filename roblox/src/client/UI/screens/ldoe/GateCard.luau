--!strict
--[[
	GateCard: the VIP Lounge Gatekeeper's card, the Lounge's moment of need. While a
	non-member stands by Rook at the gate (Controllers/Interaction sets
	State.ui().gatekeeper), the HUD shows his line, what waits behind the rope, and JOIN with
	the pass's Robux price (the server prompts the game pass: Services/Haven VipBuy). PERKS
	opens the Lounge pane; the close button shuts the card until they walk away.

	It sits above the menu bar, right-aligned with it and left of the action cluster, so it
	never covers the HUD's corners (checklist 4.18, 4.19).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Actions = require("../../../Actions")
local Theme = require("../../theme")
local hooks = require("../../hooks")
local Glyph = require("../../components/Glyph")
local Layout = require("../../components/Layout")
local Parts = require("./Parts")

local e = React.createElement
local H = Theme.hud

local ROBUX = "rbxasset://textures/ui/common/robux.png"
local HEIGHT = 156

local function JoinButton(props: { price: number, layoutOrder: number })
	return e("TextButton", {
		Size = UDim2.fromOffset(150, Theme.tapTarget),
		BackgroundColor3 = Theme.colors.upgrade,
		Text = "",
		LayoutOrder = props.layoutOrder,
		[React.Event.Activated] = Actions.joinLounge,
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
					Size = UDim2.fromOffset(20, 20),
					BackgroundTransparency = 1,
					Image = ROBUX,
					LayoutOrder = 2,
				}),
				Price = e("TextLabel", {
					Size = UDim2.fromOffset(0, 24),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.header,
					Text = tostring(props.price),
					TextSize = Theme.textSize.body,
					TextColor3 = Theme.colors.text,
					LayoutOrder = 3,
				}),
			},
		}),
	})
end

local function GateCard(props: { right: number })
	local haven = hooks.useSection("haven")
	local npc = Content.Haven.npcs["npc.gatekeeper"]
	if npc == nil then
		return nil
	end
	local price = if type(haven) == "table" and haven.vipPrice then haven.vipPrice else Content.Haven.vip.priceRobux
	-- As wide as the menu bar under it.
	local width = 7 * H.menuIcon + 6 * Theme.spacing.sm
	return e("Frame", {
		Size = UDim2.fromOffset(width, HEIGHT),
		Position = UDim2.new(1, -props.right, 1, -(H.edge + 18 + H.menuIcon + 8 + Theme.spacing.md)),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.06,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.accentSoft, Thickness = 2 }),
		Column = e(Layout.Stack, {
			gap = Theme.spacing.xs,
			padding = Theme.spacing.md,
			children = {
				Head = e(Layout.Stack, {
					direction = "row",
					gap = Theme.spacing.sm,
					alignY = Enum.VerticalAlignment.Center,
					size = UDim2.new(1, 0, 0, 28),
					layoutOrder = 1,
					children = {
						Icon = e(Glyph, {
							name = "pass",
							size = UDim2.fromOffset(24, 24),
							color = Theme.colors.highlight,
							layoutOrder = 1,
						}),
						Name = e(Layout.Fill, {
							direction = "row",
							layoutOrder = 2,
							children = {
								Text = e(Parts.Line, {
									text = `{npc.name}, {npc.title}`,
									tone = Theme.colors.highlight,
								}),
							},
						}),
					},
				}),
				Line = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 40),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.body,
					Text = `{npc.greeting}. Guns, a bar and a daily crate wait inside.`,
					TextSize = Theme.textSize.caption,
					TextColor3 = Theme.colors.text,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					LayoutOrder = 2,
				}),
				Buttons = e(Layout.Stack, {
					direction = "row",
					gap = Theme.spacing.sm,
					alignX = Enum.HorizontalAlignment.Right,
					alignY = Enum.VerticalAlignment.Center,
					size = UDim2.new(1, 0, 0, Theme.tapTarget),
					layoutOrder = 3,
					children = {
						Close = e(Parts.BarButton, { glyph = "close", layoutOrder = 1, onActivated = Actions.closeGateCard }),
						Perks = e(Parts.BarButton, {
							text = "Perks",
							width = 96,
							layoutOrder = 2,
							onActivated = function()
								Actions.talkTo("npc.gatekeeper")
							end,
						}),
						Join = e(JoinButton, { price = price, layoutOrder = 3 }),
					},
				}),
			},
		}),
	})
end

return GateCard
