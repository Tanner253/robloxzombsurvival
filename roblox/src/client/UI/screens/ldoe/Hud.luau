--!strict
--[[
	Hud: the LDoE HUD (LDOE_PARITY #1-12; rec8_hud_002s, rec8_base_017s, rec3_07, rec6_06).

	- Top left: the survivor's name and HP bar with its number; a pulsing food or water icon
	  with its value appears beside HP at 20 or below (no hunger or thirst bars). Under it,
	  the Ember Trail tracker: up to 3 quests with their next step, folded with «.
	- Top right: the minimap, with the sun/moon arc and settings beside it; the event,
	  offers and gift strip is reserved for S3. Craft and Build stack under the minimap.
	- Bottom right: the action cluster: the meds slot (H, the quick slot or best heal), the
	  second weapon (2 / F swaps), the active weapon circle (1, attack: held to gather here),
	  the context button (its icon follows the target: hand, axe, pick, station, crate;
	  greyed with nothing in range) and sprint (Shift).
	- Bottom left: AUTO (Q). On touch it moves above Roblox's thumbstick zone and the
	  cluster moves left of Roblox's jump button.
	- Bottom: the menu bar (Inventory with the inbox badge; Social, Crew, Quests, Pass, Shop
	  and Map are reserved and switch on with their screens), the level bar "Lv N" with
	  "+N xp" popping beside it, and a gap at the left for the docked chat bar.
	- Top centre is reserved for the target bar (S2); toasts sit below it (Feed).
	- Pickups float as "+N [icon]" over the survivor, merging repeats (#9).

	Each corner is one group laid out by UIListLayout; the groups are anchored to their own
	corners, so nothing is hand-placed against a sibling. Opening a full-screen panel hides
	the HUD (#11); build mode hides it but keeps the tracker (#25).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Content = require(ReplicatedStorage.Shared.Data)
local Clock = require(ReplicatedStorage.Shared.Clock)
local Flags = require(ReplicatedStorage.Shared.Flags)
local Progression = require(ReplicatedStorage.Shared.Domain.Progression)
local Actions = require("../../../Actions")
local State = require("../../../State")
local Theme = require("../../theme")
local hooks = require("../../hooks")
local questText = require("../../questText")
local mark = require("../../mark")
local Glyph = require("../../components/Glyph")
local IconButton = require("../../components/IconButton")
local ItemIcon = require("../../components/ItemIcon")
local Layout = require("../../components/Layout")
local Minimap = require("../../components/Minimap")

local e = React.createElement
local H = Theme.hud

-- Panels that take the whole screen and hide the HUD (LDOE_PARITY #11).
local FULL_SCREEN: { [string]: boolean } = {
	inventory = true,
	station = true,
	project = true,
	crafting = true,
	settings = true,
}

-- Top left: name, HP and the food and water warnings --------------------------------------------------

local function Warning(props: { glyph: string, value: number, tone: Color3, layoutOrder: number })
	hooks.useClock(0.25)
	local beat = 0.75 + 0.25 * math.sin(os.clock() * 6)
	return e(Layout.Stack, {
		direction = "row",
		gap = 2,
		alignY = Enum.VerticalAlignment.Center,
		size = UDim2.fromOffset(0, 24),
		autoSize = Enum.AutomaticSize.X,
		layoutOrder = props.layoutOrder,
		children = {
			Icon = e(Glyph, {
				name = props.glyph,
				size = UDim2.fromOffset(22, 22),
				color = props.tone,
				transparency = 1 - beat,
				layoutOrder = 1,
			}),
			Value = e("TextLabel", {
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = tostring(math.floor(props.value)),
				TextSize = Theme.textSize.body,
				TextColor3 = props.tone,
				LayoutOrder = 2,
			}),
		},
	})
end

local function Vitals()
	local survival = hooks.useSection("survival")
	local now = hooks.useClock(1)
	local health, maxHealth, hunger, thirst = 100, 100, 100, 100
	if type(survival) == "table" then
		local dt = math.max(0, now - survival.updatedAt)
		health, maxHealth = survival.health, survival.maxHealth
		hunger = math.max(0, survival.hunger - survival.hungerDecay * dt)
		thirst = math.max(0, survival.thirst - survival.thirstDecay * dt)
	end
	local fill = hooks.useAnimated(math.clamp(health / math.max(1, maxHealth), 0, 1), 8)
	local warnAt = Content.Tuning.survival.warnAt
	local name = Players.LocalPlayer.DisplayName
	return e(Layout.Stack, {
		gap = 2,
		size = UDim2.fromOffset(H.nameWidth + 90, 52),
		layoutOrder = 1,
		children = {
			Name = e("TextLabel", {
				Size = UDim2.fromOffset(H.nameWidth, 22),
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = name,
				TextSize = Theme.textSize.body,
				TextColor3 = Theme.colors.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 1,
			}, {
				Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 1, Transparency = 0.4 }),
			}),
			Row = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.sm,
				alignY = Enum.VerticalAlignment.Center,
				size = UDim2.new(1, 0, 0, 24),
				layoutOrder = 2,
				children = {
					Bar = e("Frame", {
						Size = UDim2.fromOffset(H.nameWidth - 56, 10),
						BackgroundColor3 = Theme.colors.track,
						BorderSizePixel = 0,
						LayoutOrder = 1,
					}, {
						Fill = e("Frame", {
							Size = fill:map(function(v: number)
								return UDim2.fromScale(v, 1)
							end),
							BackgroundColor3 = Theme.colors.durability,
							BorderSizePixel = 0,
						}),
					}),
					Number = e("TextLabel", {
						Size = UDim2.fromOffset(48, 22),
						BackgroundColor3 = Theme.colors.durability:Lerp(Theme.colors.panel, 0.55),
						FontFace = Theme.fonts.header,
						Text = tostring(math.floor(health)),
						TextSize = Theme.textSize.body,
						TextColor3 = Theme.colors.text,
						LayoutOrder = 2,
					}),
					Hunger = hunger <= warnAt and e(Warning, {
						glyph = "hunger",
						value = hunger,
						tone = Theme.meters.hunger,
						layoutOrder = 3,
					}),
					Thirst = thirst <= warnAt and e(Warning, {
						glyph = "thirst",
						value = thirst,
						tone = Theme.meters.thirst,
						layoutOrder = 4,
					}),
				},
			}),
		},
	})
end

-- The Ember Trail tracker (#50) ---------------------------------------------------------------------------

local function Tracker()
	local ui = hooks.useUi()
	local state = hooks.useSection("quests")
	local rows = questText.rows(state, 3)
	if #rows == 0 then
		return nil
	end
	local collapsed = ui.questCollapsed == true
	local entries: { [string]: any } = {}
	for index, row in rows do
		local next = if row.nextIndex then row.objectives[1] else nil
		for _, entry in row.objectives do
			if entry.index == row.nextIndex then
				next = entry
			end
		end
		entries[`Q{index}`] = e(Layout.Stack, {
			gap = 0,
			size = UDim2.new(1, 0, 0, if collapsed then 24 else 46),
			layoutOrder = index,
			children = {
				Name = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.header,
					Text = row.name,
					TextSize = Theme.textSize.body,
					TextColor3 = Theme.colors.accentSoft,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = 1,
				}, { Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 1, Transparency = 0.4 }) }),
				Step = not collapsed and next and e("TextLabel", {
					Size = UDim2.new(1, -12, 0, 20),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.body,
					Text = `{questText.objective(next.objective)}  {next.have}/{next.need}`,
					TextSize = Theme.textSize.caption + 2,
					TextColor3 = Theme.colors.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = 2,
				}, { Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 1, Transparency = 0.5 }) }),
			},
		})
	end
	return e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.xs,
		size = UDim2.fromOffset(H.tracker, (if collapsed then 26 else 50) * #rows),
		layoutOrder = 2,
		children = {
			Rule = e("Frame", {
				Size = UDim2.new(0, 3, 1, 0),
				BackgroundColor3 = Theme.colors.strokeWarm,
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				LayoutOrder = 1,
			}),
			List = e(Layout.Fill, {
				direction = "row",
				layoutOrder = 2,
				children = { Rows = e(Layout.Stack, { gap = 2, children = entries }) },
			}),
			Fold = e("TextButton", {
				Size = UDim2.fromOffset(28, 28),
				BackgroundColor3 = Theme.colors.panel,
				BackgroundTransparency = 0.3,
				Text = "",
				LayoutOrder = 3,
				[React.Event.Activated] = Actions.toggleQuests,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Icon = e(Glyph, {
					name = "chevron",
					size = UDim2.fromScale(0.7, 0.7),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					rotation = if collapsed then 180 else 0,
				}),
			}),
		},
	})
end

-- Top right: the minimap, the sun/moon arc, settings, Craft and Build ------------------------------------

local function SunMoon()
	local now = hooks.useClock(5)
	local pinned = if RunService:IsStudio() then workspace:GetAttribute("ClockOverride") else nil
	local hours = if type(pinned) == "number" then pinned else Clock.hoursAt(now)
	local day = Clock.daylight(hours) > 0.5
	-- The marker rides an arc: sunrise at the left, noon at the top, sunset at the right.
	local phase = ((hours - 6) % 12) / 12
	local angle = math.rad(180 - phase * 180)
	return e("Frame", {
		Size = UDim2.fromOffset(56, 32),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ref = mark.composite, -- the arc and its marker overlap on purpose
	}, {
		Arc = e("Frame", {
			Size = UDim2.fromOffset(48, 48),
			Position = UDim2.fromScale(0.5, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = 1, Transparency = 0.4 }),
			Clip = e("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(0.501, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
			}),
		}),
		Marker = e(Glyph, {
			name = if day then "sun" else "moon",
			size = UDim2.fromOffset(18, 18),
			position = UDim2.new(0.5, math.cos(angle) * 24, 1, -math.sin(angle) * 24),
			anchorPoint = Vector2.new(0.5, 0.5),
			color = if day then Theme.colors.highlight else Theme.colors.threat,
		}),
	})
end

local function TopRight()
	return e(Layout.Stack, {
		gap = Theme.spacing.sm,
		alignX = Enum.HorizontalAlignment.Right,
		size = UDim2.fromOffset(H.minimap + 70, H.minimap + 200),
		position = UDim2.new(1, -H.edge, 0, H.edge),
		anchorPoint = Vector2.new(1, 0),
		children = {
			Row = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.sm,
				alignX = Enum.HorizontalAlignment.Right,
				alignY = Enum.VerticalAlignment.Center,
				size = UDim2.new(1, 0, 0, H.stripIcon),
				layoutOrder = 1,
				children = {
					-- The event / offers / gift strip (S3) is reserved here, left of the arc.
					SunMoon = e(SunMoon),
					Settings = e(IconButton, {
						glyph = "settings",
						size = H.stripIcon,
						layoutOrder = 2,
						onPress = Actions.toggleSettings,
					}),
				},
			}),
			Map = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.sm,
				alignX = Enum.HorizontalAlignment.Right,
				size = UDim2.new(1, 0, 0, H.minimap),
				layoutOrder = 2,
				children = {
					Minimap = e("Frame", {
						Size = UDim2.fromOffset(H.minimap, H.minimap),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
					}, { Map = e(Minimap, { position = UDim2.fromScale(0, 0), anchorPoint = Vector2.zero }) }),
				},
			}),
			Buttons = e(Layout.Stack, {
				gap = Theme.spacing.sm,
				alignX = Enum.HorizontalAlignment.Right,
				size = UDim2.new(1, 0, 0, Theme.tapTarget * 2 + 24),
				layoutOrder = 3,
				children = {
					Craft = e(IconButton, {
						glyph = "craft",
						size = 52,
						key = "C",
						layoutOrder = 1,
						onPress = Actions.toggleCrafting,
					}),
					Build = e(IconButton, {
						glyph = "build",
						size = 52,
						key = "B",
						layoutOrder = 2,
						onPress = Actions.toggleBuild,
					}),
				},
			}),
		},
	})
end

-- Bottom right: the action cluster (#1) -------------------------------------------------------------------

local function weaponIcon(slot: any, durability: number?): { [string]: any }
	local children: { [string]: any } = {}
	if slot and slot.count > 0 then
		children.Item = e("Frame", {
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, { Icon = e(ItemIcon, { itemId = slot.itemId }) })
	end
	if durability then
		-- The durability ring: a second stroke on an inset circle, its length via a gradient.
		children.Wear = e("Frame", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = e("UIStroke", {
				Color = if durability < 0.2 then Theme.colors.locked else Theme.colors.badge,
				Thickness = 3,
			}, {
				Length = e("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(math.clamp(durability, 0.001, 0.998), 0),
						NumberSequenceKeypoint.new(math.clamp(durability + 0.001, 0.002, 0.999), 1),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),
		})
	end
	return children
end

local function durabilityOf(slot: any): number?
	local def = if slot and slot.count > 0 then Content.Items[slot.itemId] else nil
	return if def and def.durability and slot.durability then slot.durability / def.durability else nil
end

-- Healing the meds button can use: the quick slot's stack when it heals, else every heal carried.
local function medsOf(inventory: any): (number, string?)
	local quick = inventory.equipment.quick
	local quickDef = if quick and quick.count > 0 then Content.Items[quick.itemId] else nil
	if quickDef and quickDef.consume and (quickDef.consume.health or 0) > 0 then
		return quick.count, quick.itemId
	end
	local count, bestId, bestHeal = 0, nil, 0
	for _, container in { inventory.pockets, inventory.backpack } do
		for _, slot in container do
			local def = if slot.count > 0 then Content.Items[slot.itemId] else nil
			local heal = if def and def.consume then def.consume.health or 0 else 0
			if heal > 0 then
				count += slot.count
				if heal > bestHeal then
					bestId, bestHeal = slot.itemId, heal
				end
			end
		end
	end
	return count, bestId
end

-- The context button's glyph for the current target.
local function contextGlyph(target: State.Target?): string
	if target == nil then
		return "interact"
	elseif target.kind == "node" then
		local def = Content.Nodes[target.model:GetAttribute("NodeId") :: any]
		local tool = def and def.tool
		return if tool and tool.kind == "hatchet"
			then "axe"
			elseif tool and tool.kind == "pick" then "pick"
			else "interact"
	elseif target.kind == "station" then
		return "station"
	elseif target.kind == "storage" then
		return "storage"
	end
	return "interact"
end

local function Cluster(props: { touchRight: number })
	local ui = hooks.useUi()
	local inventory = hooks.useSection("inventory")
	if type(inventory) ~= "table" then
		return nil
	end
	local active = inventory.activeWeapon or 1
	local other = if active == 1 then 2 else 1
	local function weaponSlot(n: number): any
		return if n == 1 then inventory.equipment.weapon else inventory.equipment.weapon2
	end
	local activeSlot, otherSlot = weaponSlot(active), weaponSlot(other)
	local meds, medId = medsOf(inventory)
	local width = H.context + Theme.spacing.sm + H.sprint
	return e(Layout.Stack, {
		gap = Theme.spacing.sm,
		alignX = Enum.HorizontalAlignment.Right,
		alignY = Enum.VerticalAlignment.Bottom,
		size = UDim2.fromOffset(width, H.weaponSmall + H.weaponBig + H.context + Theme.spacing.sm * 2),
		position = UDim2.new(1, -H.edge - props.touchRight, 1, -(H.edge + 18)),
		anchorPoint = Vector2.new(1, 1),
		children = {
			Top = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.sm,
				alignX = Enum.HorizontalAlignment.Right,
				alignY = Enum.VerticalAlignment.Bottom,
				size = UDim2.new(1, 0, 0, H.weaponSmall),
				layoutOrder = 1,
				children = {
					Meds = e(IconButton, {
						glyph = "medkit",
						size = H.meds,
						key = "H",
						badge = meds,
						disabled = meds <= 0,
						layoutOrder = 1,
						onPress = Actions.useMeds,
						children = medId and {
							Item = e("Frame", {
								Size = UDim2.fromScale(0.6, 0.6),
								Position = UDim2.fromScale(0.5, 0.5),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								ZIndex = 2,
							}, { Icon = e(ItemIcon, { itemId = medId }) }),
						} or nil,
					}),
					Second = e(IconButton, {
						glyph = if otherSlot and otherSlot.count > 0 then "swap" else "attack",
						size = H.weaponSmall,
						key = "F",
						layoutOrder = 2,
						onPress = Actions.swapWeapon,
						children = weaponIcon(otherSlot, durabilityOf(otherSlot)),
					}),
				},
			}),
			Weapon = e(IconButton, {
				glyph = "attack",
				size = H.weaponBig,
				key = tostring(active),
				active = ui.auto,
				layoutOrder = 2,
				-- Held: attacks, or gathers the target at home (LMB does the same).
				onDown = function()
					Actions.interact()
					Actions.setGathering(true)
				end,
				onRelease = function()
					Actions.setGathering(false)
				end,
				children = weaponIcon(activeSlot, durabilityOf(activeSlot)),
			}),
			Bottom = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.sm,
				alignX = Enum.HorizontalAlignment.Right,
				alignY = Enum.VerticalAlignment.Bottom,
				size = UDim2.new(1, 0, 0, H.context),
				layoutOrder = 3,
				children = {
					Context = e(IconButton, {
						glyph = contextGlyph(ui.target),
						size = H.context,
						key = "E",
						disabled = ui.target == nil,
						active = ui.target ~= nil,
						ring = Theme.colors.badge,
						layoutOrder = 1,
						onPress = Actions.interact,
					}),
					Sprint = e(IconButton, {
						glyph = "sprint",
						size = H.sprint,
						key = "Shift",
						active = ui.sprinting,
						layoutOrder = 2,
						onPress = function()
							Actions.setSprint(not State.ui().sprinting)
						end,
					}),
				},
			}),
		},
	})
end

-- Bottom: the menu bar, the level bar and the chat gap ------------------------------------------------------

local function MenuBar(props: { right: number })
	local ui = hooks.useUi()
	local inbox = hooks.useSection("inbox")
	local inboxCount = if type(inbox) == "table" then #inbox else 0
	local anyNew = next(ui.newItems) ~= nil
	-- Social, Crew, Quests, Pass, Shop and Map switch on with their screens (S2/S3).
	local slots = 7
	local width = slots * H.menuIcon + (slots - 1) * Theme.spacing.sm
	return e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.sm,
		alignX = Enum.HorizontalAlignment.Right,
		alignY = Enum.VerticalAlignment.Bottom,
		size = UDim2.fromOffset(width, H.menuIcon + 8),
		position = UDim2.new(1, -props.right, 1, -(H.edge + 18)),
		anchorPoint = Vector2.new(1, 1),
		children = {
			Inventory = e(IconButton, {
				glyph = "backpack",
				size = H.menuIcon,
				square = true,
				key = "Tab",
				badge = inboxCount,
				new = anyNew and inboxCount == 0,
				layoutOrder = 7,
				onPress = if inboxCount > 0 and not anyNew then Actions.openInbox else Actions.toggleInventory,
			}),
		},
	})
end

local function LevelBar()
	local progression = hooks.useSection("progression")
	local level = if progression then progression.level else 1
	local fraction = 0
	if progression then
		local _, _, f = Progression.progress(progression, Content.Levels)
		fraction = f
	end
	local fill = hooks.useAnimated(fraction, 6)
	-- "+N xp" pops beside the level and fades (#5).
	local popped, setPopped = React.useState(nil :: { amount: number, at: number }?)
	React.useEffect(function()
		local connection = State.fx:Connect(function(kind: any, payload: any)
			if (kind == "gather" or kind == "questDone") and type(payload) == "table" and (payload.xp or 0) > 0 then
				setPopped(function(current: { amount: number, at: number }?): { amount: number, at: number }?
					local now = os.clock()
					if current and now - current.at < 1.5 then
						return { amount = current.amount + payload.xp, at = now }
					end
					return { amount = payload.xp, at = now }
				end)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	hooks.useClock(0.5)
	local showPop = popped ~= nil and os.clock() - popped.at < 1.8
	return e(Layout.Stack, {
		direction = "row",
		gap = Theme.spacing.sm,
		alignY = Enum.VerticalAlignment.Center,
		size = UDim2.new(1, -H.edge * 2, 0, 18),
		position = UDim2.new(0, H.edge, 1, -2),
		anchorPoint = Vector2.new(0, 1),
		children = {
			Level = e("TextLabel", {
				Size = UDim2.fromOffset(64, 18),
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = `Lv {level}`,
				TextSize = Theme.textSize.caption + 2,
				TextColor3 = Theme.colors.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),
			Pop = e("TextLabel", {
				Size = UDim2.fromOffset(80, 18),
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = if showPop and popped then `+{popped.amount}xp` else "",
				TextSize = Theme.textSize.body,
				TextColor3 = Theme.colors.durability,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}),
			Track = e(Layout.Fill, {
				direction = "row",
				crossSize = UDim.new(0, H.levelBar),
				layoutOrder = 3,
				children = {
					Back = e("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.colors.track,
						BackgroundTransparency = 0.3,
						BorderSizePixel = 0,
					}, {
						Fill = e("Frame", {
							Size = fill:map(function(v: number)
								return UDim2.fromScale(v, 1)
							end),
							BackgroundColor3 = Theme.colors.badge,
							BorderSizePixel = 0,
						}),
					}),
				},
			}),
		},
	})
end

-- Pickups: "+N [icon]" floating over the survivor, merging repeats (#9) ---------------------------------

local function Pickups()
	local ui = hooks.useUi()
	hooks.useClock(0.25)
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if head == nil or playerGui == nil then
		return nil
	end
	local rows: { [string]: any } = {}
	local now = os.clock()
	local shown = 0
	for index = #ui.rewards, 1, -1 do
		local reward = ui.rewards[index]
		local age = now - reward.at
		if age < 2.2 and shown < 3 then
			shown += 1
			rows[`R{reward.id}`] = e(Layout.Stack, {
				direction = "row",
				gap = 4,
				alignX = Enum.HorizontalAlignment.Center,
				alignY = Enum.VerticalAlignment.Center,
				size = UDim2.new(1, 0, 0, 30),
				layoutOrder = shown,
				children = {
					Count = e("TextLabel", {
						Size = UDim2.fromOffset(0, 28),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						FontFace = Theme.fonts.header,
						Text = `+{reward.count}`,
						TextSize = Theme.textSize.title,
						TextColor3 = Theme.colors.text,
						TextTransparency = math.clamp((age - 1.6) / 0.6, 0, 1),
						LayoutOrder = 1,
					}, { Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 1.5 }) }),
					Icon = e("Frame", {
						Size = UDim2.fromOffset(28, 28),
						BackgroundTransparency = 1,
						LayoutOrder = 2,
					}, { Icon = e(ItemIcon, { itemId = reward.itemId }) }),
				},
			})
		end
	end
	if shown == 0 then
		return nil
	end
	return ReactRoblox.createPortal({
		EO_Pickups = e("BillboardGui", {
			Adornee = head,
			Size = UDim2.fromOffset(160, 100),
			StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0),
			AlwaysOnTop = true,
			LightInfluence = 0,
			ResetOnSpawn = false,
		}, { Rows = e(Layout.Stack, { gap = 2, alignY = Enum.VerticalAlignment.Bottom, children = rows }) }),
	}, playerGui)
end

-- The HUD ---------------------------------------------------------------------------------------------------

local function Hud()
	local ui = hooks.useUi()
	local playing = ui.panel == "none"
	local building = ui.panel == "build"
	if FULL_SCREEN[ui.panel] then
		return nil
	end
	local touch = ui.touch or (ui.gate ~= nil and ui.gate.touch)
	-- On touch the cluster stands left of Roblox's jump button and AUTO above the thumbstick
	-- (design pixels; Theme.currentScale is the App's scale).
	local scale = Theme.currentScale or 1
	local touchRight = if touch then math.ceil(110 / scale) else 0
	local clusterWidth = H.context + Theme.spacing.sm + H.sprint
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.layers.hud,
	}, {
		TopLeft = e(Layout.Stack, {
			gap = Theme.spacing.lg,
			size = UDim2.fromOffset(H.tracker + 40, 360),
			position = UDim2.fromOffset(H.edge, H.edge),
			children = {
				Vitals = playing and e(Vitals),
				-- In build mode the "hide upper walls" toggle takes the corner (screens/ldoe/Build).
				Toggle = building and e("Frame", {
					Size = UDim2.fromOffset(64, 64),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				}),
				Tracker = (playing or building) and e(Tracker),
			},
		}),
		TopRight = playing and e(TopRight),
		Auto = playing and e(IconButton, {
			glyph = "auto_gather",
			caption = "AUTO",
			size = H.auto,
			key = "Q",
			active = ui.auto,
			position = if touch then UDim2.new(0, H.edge, 0.45, 0) else UDim2.new(0, H.edge, 1, -(H.edge + 18)),
			anchorPoint = Vector2.new(0, if touch then 0.5 else 1),
			onPress = Actions.toggleAuto,
		}),
		Cluster = playing and e(Cluster, { touchRight = touchRight }),
		Menu = playing and e(MenuBar, { right = H.edge + touchRight + clusterWidth + Theme.spacing.lg }),
		Level = playing and e(LevelBar),
		Pickups = playing and Flags.on("ldoeHud") and e(Pickups),
	})
end

return Hud
