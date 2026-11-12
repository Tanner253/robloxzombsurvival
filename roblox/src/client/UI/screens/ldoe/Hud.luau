--!strict
--[[
	Hud: the LDoE HUD (LDOE_PARITY #1-12; rec8_hud_002s, rec8_base_017s, rec3_07, rec6_06).

	- Top left: the survivor's name and HP bar with its number; a pulsing food or water icon
	  with its value appears beside HP at 20 or below (no hunger or thirst bars). Under it,
	  the Ember Trail tracker: up to 3 quests with their next step, folded with «.
	- Top right: the minimap, with the sun/moon arc and settings beside it, and left of the
	  arc the offers strip: a running limited offer's icon, pulsing, with its countdown
	  (F-11). Craft and Build stack under the minimap.
	- Bottom right: the action cluster: the meds slot (H, the quick slot or best heal), the
	  second weapon (2 / F swaps), the active weapon circle (1, attack: held to gather here),
	  the context button (its icon follows the target: hand, axe, pick, station, crate;
	  greyed with nothing in range) and sprint (Shift).
	- Bottom left: AUTO (Q). On touch it moves above Roblox's thumbstick zone, the cluster
	  moves left of Roblox's jump button and the level bar runs between the two.
	- Bottom: the menu bar (Inventory with the inbox badge; Social, Crew, Quests, Pass, Shop
	  and Map are reserved and switch on with their screens), the level bar "Lv N" with
	  "+N xp" popping beside it, and a gap at the left for the docked chat bar.
	- Top centre is reserved for the target bar (S2); toasts sit below it (Feed).
	- On a Fog Run (S2) the minimap shows the location (exits, bags, Hollow) with the Fog
	  meter under it in Craft and Build's place, the active weapon circle attacks (held,
	  a gun keeps firing) and a gun shows its rounds loaded/carried.
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
local Offers = require(ReplicatedStorage.Shared.Domain.Offers)
local Progression = require(ReplicatedStorage.Shared.Domain.Progression)
local Types = require(ReplicatedStorage.Shared.Types)
local Actions = require("../../../Actions")
local State = require("../../../State")
local Theme = require("../../theme")
local format = require("../../format")
local hooks = require("../../hooks")
local questText = require("../../questText")
local mark = require("../../mark")
local Glyph = require("../../components/Glyph")
local IconButton = require("../../components/IconButton")
local ItemIcon = require("../../components/ItemIcon")
local Layout = require("../../components/Layout")
local Minimap = require("../../components/Minimap")
local RunHud = require("../RunHud")

local e = React.createElement
local H = Theme.hud

-- Panels that take the whole screen and hide the HUD (LDOE_PARITY #11).
local FULL_SCREEN: { [string]: boolean } = {
	inventory = true,
	station = true,
	project = true,
	crafting = true,
	settings = true,
	shop = true,
	haven = true,
	fogmap = true,
	areamap = true,
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

local LOCATION_TEAL = Color3.fromHex("6FD6C4")

-- The run's location quests (LDOE_PARITY #45), pinned in teal above the trail: name, then
-- the next objective with its count, or "Done today" once it has paid this UTC day.
local function locationRows(run: any): { { name: string, step: string } }
	local rows = {}
	if type(run) ~= "table" or type(run.locationQuests) ~= "table" then
		return rows
	end
	local location = Content.Locations[run.locationId or ""]
	local defs: { Types.LocationQuest } = if location and location.run then location.run.quests else {}
	for _, row in run.locationQuests do
		local def: Types.LocationQuest? = nil
		for _, quest in defs do
			if quest.id == row.id then
				def = quest
			end
		end
		local step = "Done today"
		if not (row.done or row.paidToday) and def then
			for index, objective in def.objectives do
				local count = row.objectives[index]
				if count and count.have < count.need then
					step = `{questText.objective(objective)}  {count.have}/{count.need}`
					break
				end
			end
		end
		table.insert(rows, { name = row.name, step = step })
	end
	return rows
end

-- A step wraps to two lines, as LDoE's tracker does (rec8_hud_002s): the lines say where
-- now (Domain/QuestText, F-22) and the count stays in view.
local STEP = 38
local ROW = 22 + STEP

local function Tracker()
	local ui = hooks.useUi()
	local state = hooks.useSection("quests")
	local run = hooks.useSection("run")
	local pinned = locationRows(run)
	local rows = questText.rows(state, math.max(1, 3 - #pinned))
	if #rows == 0 and #pinned == 0 then
		return nil
	end
	local collapsed = ui.questCollapsed == true
	local entries: { [string]: any } = {}
	for index, row in pinned do
		entries[`L{index}`] = e(Layout.Stack, {
			gap = 0,
			size = UDim2.new(1, 0, 0, if collapsed then 24 else ROW),
			layoutOrder = index,
			children = {
				Name = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.header,
					Text = row.name,
					TextSize = Theme.textSize.body,
					TextColor3 = LOCATION_TEAL,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = 1,
				}, { Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 1, Transparency = 0.4 }) }),
				Step = not collapsed and e("TextLabel", {
					Size = UDim2.new(1, -12, 0, STEP),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.body,
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = row.step,
					TextSize = Theme.textSize.caption + 2,
					TextColor3 = Theme.colors.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = 2,
				}, { Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 1, Transparency = 0.5 }) }),
			},
		})
	end
	for index, row in rows do
		local upcoming = if row.nextIndex then row.objectives[1] else nil
		for _, entry in row.objectives do
			if entry.index == row.nextIndex then
				upcoming = entry
			end
		end
		entries[`Q{index}`] = e(Layout.Stack, {
			gap = 0,
			size = UDim2.new(1, 0, 0, if collapsed then 24 else ROW),
			layoutOrder = #pinned + index,
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
				Step = not collapsed and upcoming and e("TextLabel", {
					Size = UDim2.new(1, -12, 0, STEP),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.body,
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = `{questText.objective(upcoming.objective)}  {upcoming.have}/{upcoming.need}`,
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
		size = UDim2.fromOffset(H.tracker, (if collapsed then 26 else ROW + 4) * (#rows + #pinned)),
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

-- The offers strip (F-11; LDoE rec3 94s: the offer icon with its countdown under it, left of
-- the clock): while a limited offer runs for this player, its icon pulses with the time left
-- and opens the shop on it. Nothing shows when no window is open.
local function OfferStrip()
	local shop = hooks.useSection("shop")
	local now = hooks.useClock(0.5)
	local productId, endsAt = Offers.stripOffer(shop, now)
	if productId == nil then
		return nil
	end
	local beat = math.floor(os.clock() * 2) % 2 == 0
	return e(Layout.Stack, {
		gap = 0,
		alignX = Enum.HorizontalAlignment.Center,
		size = UDim2.fromOffset(64, H.stripIcon),
		layoutOrder = 0,
		children = {
			Icon = e(IconButton, {
				glyph = "offer",
				size = H.stripIcon - 14,
				active = beat,
				ring = Theme.colors.accent,
				layoutOrder = 1,
				onPress = function()
					Actions.openShop(productId)
				end,
			}),
			Left = e("TextLabel", {
				Size = UDim2.new(1, 0, 0, 14),
				BackgroundTransparency = 1,
				FontFace = Theme.fonts.header,
				Text = format.duration(endsAt - now),
				TextSize = Theme.textSize.caption - 2,
				TextColor3 = Theme.colors.accentSoft,
				LayoutOrder = 2,
			}),
		},
	})
end

local function TopRight()
	local ui = hooks.useUi()
	local run = hooks.useSection("run")
	local onRun = type(run) == "table"
	local mapHeight = if onRun then H.minimap + RunHud.METER_HEIGHT else H.minimap
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
					-- The offers strip, left of the arc (F-11); events and gifts join it later.
					Offer = not onRun and e(OfferStrip),
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
				size = UDim2.new(1, 0, 0, mapHeight),
				layoutOrder = 2,
				children = {
					Minimap = e("Frame", {
						Size = UDim2.fromOffset(H.minimap, mapHeight),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
					}, {
						Map = if onRun
							then e(RunHud.RunMinimap, { position = UDim2.fromScale(0, 0), anchorPoint = Vector2.zero })
							else e(Minimap, { position = UDim2.fromScale(0, 0), anchorPoint = Vector2.zero }),
					}),
				},
			}),
			-- Crafting and building wait at home; a run shows the Fog meter there instead.
			Buttons = not onRun and e(Layout.Stack, {
				gap = Theme.spacing.sm,
				alignX = Enum.HorizontalAlignment.Right,
				size = UDim2.new(1, 0, 0, Theme.tapTarget * 2 + 24),
				layoutOrder = 3,
				children = {
					-- The first-session guide (Controllers/Guide) rings the button the next
					-- Ember Trail step needs.
					Craft = e(IconButton, {
						glyph = "craft",
						size = 52,
						key = "C",
						active = ui.guide == "craft",
						ring = Theme.colors.accentSoft,
						layoutOrder = 1,
						onPress = Actions.toggleCrafting,
					}),
					Build = e(IconButton, {
						glyph = "build",
						size = 52,
						key = "B",
						active = ui.guide == "build",
						ring = Theme.colors.accentSoft,
						layoutOrder = 2,
						onPress = Actions.toggleBuild,
					}),
				},
			}),
		},
	})
end

-- Bottom right: the action cluster (#1) -------------------------------------------------------------------

-- A gun shows its durability ring like any weapon: there are no rounds to count (13.6).
local function weaponIcon(slot: any, durability: number?): { [string]: any }
	local children: { [string]: any } = {}
	if slot and slot.count > 0 then
		-- The weapon's own picture stands alone, as in LDoE: the button's glyph (the knife)
		-- showed through a dark gun and read as the weapon.
		children.Icon = false
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
				-- ECONOMY §8.1: amber at 25% left, red at 10% (Tuning.combat.durabilityWarn).
				Color = if durability <= Content.Tuning.combat.durabilityWarn[2]
					then Theme.colors.badgeNew
					elseif durability <= Content.Tuning.combat.durabilityWarn[1] then Theme.colors.accentSoft
					else Theme.colors.badge,
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
	elseif target.kind == "haven" then
		return "talk"
	end
	return "interact"
end

local function Cluster(props: { touchRight: number })
	local ui = hooks.useUi()
	local inventory = hooks.useSection("inventory")
	local run = hooks.useSection("run")
	local onRun = type(run) == "table"
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
					if onRun then
						Actions.attackDown()
						return
					end
					Actions.interact()
					Actions.setGathering(true)
				end,
				onRelease = function()
					if onRun then
						Actions.attackUp()
						return
					end
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
	-- The inbox waits at home (F-04): on a run the button opens the bag, with no inbox badge.
	local onRun = type(hooks.useSection("run")) == "table"
	local inboxCount = if type(inbox) == "table" and not onRun then #inbox else 0
	local anyNew = next(ui.newItems) ~= nil
	-- A full bag flashes the Inventory button red for a moment (the old HUD's Bag did), so
	-- a new player whose pockets just filled sees where to make room.
	local sinceFull = if ui.bagFullAt then os.clock() - ui.bagFullAt else math.huge
	-- Ticks fast only while it flashes; a new bagFullAt re-renders it through useUi (batch 3:
	-- the whole menu bar re-rendered 7 times a second all game).
	hooks.useClock(if sinceFull < 1.6 then 0.15 else 5)
	local flashing = sinceFull < 1.6 and math.floor(sinceFull * 6) % 2 == 0
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
			Shop = e(IconButton, {
				glyph = "shop",
				size = H.menuIcon,
				square = true,
				layoutOrder = 6,
				onPress = function()
					Actions.openShop()
				end,
			}),
			Inventory = e(IconButton, {
				glyph = "backpack",
				size = H.menuIcon,
				square = true,
				key = "Tab",
				badge = inboxCount,
				new = anyNew and inboxCount == 0,
				active = flashing or ui.guide == "inventory",
				ring = if flashing then Theme.colors.danger else Theme.colors.accentSoft,
				layoutOrder = 7,
				onPress = if inboxCount > 0 and not anyNew then Actions.openInbox else Actions.toggleInventory,
			}),
		},
	})
end

local function LevelBar(props: { touch: boolean, touchRight: number })
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
			if
				(kind == "gather" or kind == "questDone" or kind == "locationQuestDone")
				and type(payload) == "table"
				and (payload.xp or 0) > 0
			then
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
		-- On touch the bar starts right of the thumbstick zone (the lower-left third of the
		-- screen) and stops short of the jump button.
		size = if props.touch
			then UDim2.new(1 - H.touchStickShare, -(H.edge * 2 + props.touchRight), 0, 18)
			else UDim2.new(1, -H.edge * 2, 0, 18),
		position = if props.touch then UDim2.new(H.touchStickShare, H.edge, 1, -2) else UDim2.new(0, H.edge, 1, -2),
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
	-- Ticks while a "+N" can still be fading; a new reward re-renders it through useUi.
	local last = ui.rewards[#ui.rewards]
	hooks.useClock(if last and os.clock() - last.at < 2.2 then 0.25 else 5)
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
	local touchRight = if touch then math.ceil(H.touchJumpReserve / scale) else 0
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
			-- Touch: its bottom sits above the thumbstick zone (the screen's lower half; this
			-- frame starts below the top inset, so 0.42 of it stays clear).
			position = if touch
				then UDim2.new(0, H.edge, 0.42, -Theme.spacing.md)
				else UDim2.new(0, H.edge, 1, -(H.edge + 18)),
			anchorPoint = Vector2.new(0, 1),
			onPress = Actions.toggleAuto,
		}),
		Cluster = playing and e(Cluster, { touchRight = touchRight }),
		Menu = playing and e(MenuBar, { right = H.edge + touchRight + clusterWidth + Theme.spacing.lg }),
		Level = playing and e(LevelBar, { touch = touch == true, touchRight = touchRight }),
		Pickups = playing and Flags.on("ldoeHud") and e(Pickups),
	})
end

return Hud
