--!strict
--[[
	HUD: always on screen while playing (PC-first 16:9 layout, corners on touch).
	- top left: level badge, health, hunger and thirst, XP, Energy with its regen timer
	- left: the Ember Trail quest tracker
	- bottom right, above the action buttons: the two weapon slots (the active one big,
	  with durability; 1, 2 and F) and the meds button (H) with its count (4.9)
	- bottom right: action buttons with keybind hints (E, Tab, B; Shift on touch)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Art = require(ReplicatedStorage.Shared.Art)
local EnergyMath = require(ReplicatedStorage.Shared.Domain.Energy)
local Clock = require(ReplicatedStorage.Shared.Clock)
local Progression = require(ReplicatedStorage.Shared.Domain.Progression)
local Crafting = require(ReplicatedStorage.Shared.Domain.Crafting)
local DevSpeed = require(ReplicatedStorage.Shared.DevSpeed)
local Actions = require("../../Actions")
local State = require("../../State")
local Theme = require("../theme")
local hooks = require("../hooks")
local format = require("../format")
local ItemSlot = require("../components/ItemSlot")
local Glyph = require("../components/Glyph")
local KeyChip = require("../components/KeyChip")
local Label = require("../components/Label")
local StatBar = require("../components/StatBar")
local Minimap = require("../components/Minimap")
local questText = require("../questText")
local RunHud = require("./RunHud")

local e = React.createElement

local WEAPON_BIG = 84
local WEAPON_SMALL = 52

local function card(props: { size: UDim2, position: UDim2, anchorPoint: Vector2?, children: any })
	return e("Frame", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = Theme.colors.panelTransparency + 0.02,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = Theme.colors.strokeWarm,
			Thickness = Theme.strokeThickness,
			Transparency = 0.25,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, Theme.spacing.sm),
			PaddingBottom = UDim.new(0, Theme.spacing.sm),
			PaddingLeft = UDim.new(0, Theme.spacing.md),
			PaddingRight = UDim.new(0, Theme.spacing.md),
		}),
		Content = e(React.Fragment, nil, props.children),
	})
end

-- Status ----------------------------------------------------------------------------------------

local function LevelBadge(props: { level: number, fraction: number })
	local fill = hooks.useAnimated(props.fraction, 6)
	return e("Frame", {
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = Theme.colors.panelRaised,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Ring = e("UIStroke", { Color = Theme.colors.accent, Thickness = 3 }),
		Glow = e("UIGradient", {
			Color = ColorSequence.new(Theme.colors.accent:Lerp(Theme.colors.panelRaised, 0.6), Theme.colors.panel),
			Rotation = 90,
		}),
		Caption = e(Label, {
			text = "LEVEL",
			style = "caption",
			tone = "muted",
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.fromOffset(0, 12),
			alignX = Enum.TextXAlignment.Center,
		}),
		Number = e(Label, {
			text = tostring(props.level),
			style = "header",
			size = UDim2.new(1, 0, 0, 32),
			position = UDim2.fromOffset(0, 26),
			alignX = Enum.TextXAlignment.Center,
			stroke = true,
		}),
		-- XP progress as a thin arc substitute: a bar under the number.
		Track = e("Frame", {
			Size = UDim2.new(0.6, 0, 0, 4),
			Position = UDim2.new(0.2, 0, 1, -14),
			BackgroundColor3 = Theme.colors.track,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = e("Frame", {
				Size = fill:map(function(v: number)
					return UDim2.fromScale(v, 1)
				end),
				BackgroundColor3 = Theme.meters.xp,
				BorderSizePixel = 0,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		}),
	})
end

local function Status()
	local survival = hooks.useSection("survival")
	local progression = hooks.useSection("progression")
	local energy = hooks.useSection("energy")
	local now = hooks.useClock(1)
	-- Studio's pinned hour (ClockOverride) shows on the chip too, so captures agree.
	local pinned = if RunService:IsStudio() then workspace:GetAttribute("ClockOverride") else nil
	local hours = if type(pinned) == "number" then pinned else Clock.hoursAt(now)

	local level = if progression then progression.level else 1
	local into, span, fraction = 0, 0, 0
	if progression then
		into, span, fraction = Progression.progress(progression, Content.Levels)
	end

	-- Meters drain between server ticks; draw them where they are now.
	local hunger, thirst, health = 100, 100, 100
	local hungerMax, thirstMax, maxHealth = 100, 100, 100
	if survival then
		local dt = math.max(0, now - survival.updatedAt)
		hunger = math.max(0, survival.hunger - survival.hungerDecay * dt)
		thirst = math.max(0, survival.thirst - survival.thirstDecay * dt)
		health = survival.health
		hungerMax, thirstMax, maxHealth = survival.hungerMax, survival.thirstMax, survival.maxHealth
	end

	local energyValue, energyCap, nextIn, bonus = 0, 100, 0, 0
	if energy then
		local config = { cap = energy.cap, secondsPerPoint = energy.secondsPerPoint }
		local state = EnergyMath.current({ value = energy.value, updatedAt = energy.updatedAt }, now, config)
		energyValue, energyCap = state.value, energy.cap
		bonus = math.max(0, state.value - energy.cap)
		nextIn = if state.value < energy.cap then state.updatedAt + energy.secondsPerPoint - now else 0
	end

	return card({
		size = UDim2.fromOffset(352, 116),
		position = UDim2.fromOffset(16, 16),
		children = {
			Badge = e("Frame", { Size = UDim2.fromOffset(76, 76), BackgroundTransparency = 1 }, {
				Inner = e(LevelBadge, { level = level, fraction = fraction }),
			}),
			Bars = e("Frame", {
				Size = UDim2.new(1, -88, 0, 76),
				Position = UDim2.fromOffset(88, 0),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Health = e(StatBar, {
					value = health,
					max = maxHealth,
					color = Theme.meters.health,
					glyph = Art.meterGlyphs.health,
					label = `{math.ceil(health)} / {maxHealth}`,
					lowAt = 0.3,
					size = UDim2.new(1, 0, 0, 20),
					layoutOrder = 1,
				}),
				Hunger = e(StatBar, {
					value = hunger,
					max = hungerMax,
					color = Theme.meters.hunger,
					glyph = Art.meterGlyphs.hunger,
					lowAt = 0.15,
					size = UDim2.new(1, 0, 0, 16),
					layoutOrder = 2,
				}),
				Thirst = e(StatBar, {
					value = thirst,
					max = thirstMax,
					color = Theme.meters.thirst,
					glyph = Art.meterGlyphs.thirst,
					lowAt = 0.15,
					size = UDim2.new(1, 0, 0, 16),
					layoutOrder = 3,
				}),
			}),
			Xp = e(Label, {
				text = if span > 0 then `{into} / {span} XP` else "Max level",
				style = "caption",
				tone = "muted",
				size = UDim2.fromOffset(150, 16),
				position = UDim2.new(0, 0, 1, -16),
			}),
			Clock = e("Frame", {
				Size = UDim2.fromOffset(96, 28),
				Position = UDim2.new(1, 12, 0, 4),
				BackgroundColor3 = Theme.colors.panel,
				BackgroundTransparency = Theme.colors.panelTransparency,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = 1, Transparency = 0.4 }),
				Text = e(Label, {
					text = Clock.label(hours),
					style = "caption",
					tone = if Clock.daylight(hours) > 0.5 then "highlight" else "muted",
					size = UDim2.fromScale(1, 1),
					alignX = Enum.TextXAlignment.Center,
				}),
			}),
			Energy = e("Frame", {
				Size = UDim2.fromOffset(170, 22),
				Position = UDim2.new(1, 0, 1, -20),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Theme.colors.track,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Stroke = e("UIStroke", {
					Color = if bonus > 0 then Theme.colors.bonus else Theme.meters.energy,
					Thickness = if bonus > 0 then 2 else 1,
					Transparency = if bonus > 0 then 0 else 0.5,
				}),
				Icon = e(Glyph, {
					name = Art.meterGlyphs.energy,
					size = UDim2.fromOffset(16, 16),
					position = UDim2.new(0, 8, 0.5, 0),
					anchorPoint = Vector2.new(0, 0.5),
					color = Theme.meters.energy,
				}),
				-- Above the cap (level-up refills, rewards) the extra shows as an amber bonus.
				Text = e(Label, {
					text = if bonus > 0
						then `{energyCap} / {energyCap}  <font color="#{Theme.colors.bonus:ToHex()}">+{bonus}</font>`
						elseif nextIn > 0 then `{energyValue} / {energyCap},  +1 in {format.duration(nextIn)}`
						else `{energyValue} / {energyCap}`,
					richText = true,
					style = "caption",
					tone = "highlight",
					size = UDim2.fromScale(1, 1),
					alignX = Enum.TextXAlignment.Center,
				}),
			}),
		},
	})
end

-- Quest tracker: the Ember Trail's open quests (LDOE_PARITY #50) ----------------------------------------

local function foldButton(collapsed: boolean): any
	return e("TextButton", {
		Size = UDim2.fromOffset(32, 28),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.colors.panelRaised,
		FontFace = Theme.fonts.header,
		Text = "",
		TextSize = Theme.textSize.section,
		TextColor3 = Theme.colors.text,
		ZIndex = 3,
		[React.Event.Activated] = Actions.toggleQuests,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Glyph = e(Glyph, {
			name = if collapsed then "quests" else "minus",
			size = UDim2.fromScale(0.62, 0.62),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			color = Theme.colors.text,
			zIndex = 4,
		}),
	})
end

local function QuestTracker()
	local ui = hooks.useUi()
	local state = hooks.useSection("quests")
	local row = questText.rows(state, 1)[1]
	local quest = if row then Content.Quests[row.questId] else nil
	if quest == nil or row == nil then
		return nil
	end
	local function objectiveText(objective: any): (string, number, number)
		for _, entry in row.objectives do
			if entry.objective == objective then
				return questText.objective(objective), entry.have, entry.need
			end
		end
		return questText.objective(objective), 0, 1
	end
	-- Folded to one line with the « button (8.9): the quest name and how far along it is.
	if ui.questCollapsed then
		local done = 0
		for _, entry in row.objectives do
			done += if entry.done then 1 else 0
		end
		return card({
			size = UDim2.fromOffset(300, 46),
			position = UDim2.fromOffset(16, 146),
			children = {
				Name = e(Label, {
					text = `{quest.name}  {done}/{#row.objectives}`,
					style = "section",
					size = UDim2.new(1, -40, 0, 28),
				}),
				Fold = foldButton(true),
			},
		})
	end
	local rows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		-- The header row carries the « fold button (8.9); the list layout places rows only.
		Header = e("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 0 }, {
			Title = e(
				Label,
				{ text = "EMBER TRAIL", style = "section", tone = "accent", size = UDim2.new(1, -40, 1, 0) }
			),
			Fold = foldButton(false),
		}),
		Name = e(Label, { text = quest.name, style = "title", layoutOrder = 1 }),
	}
	for index, entry in row.objectives do
		local text, have, need = objectiveText(entry.objective)
		local done = have >= need
		rows[`Objective{index}`] = e("Frame", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			LayoutOrder = 1 + index,
		}, {
			Box = e("Frame", {
				Size = UDim2.fromOffset(14, 14),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = if done then Theme.colors.durability else Theme.colors.track,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
				Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = 1 }),
			}),
			Text = e(Label, {
				text = `{text}  {have}/{need}`,
				style = "caption",
				tone = if done then "good" else "text",
				size = UDim2.new(1, -22, 1, 0),
				position = UDim2.fromOffset(22, 0),
			}),
		})
	end
	return card({
		size = UDim2.fromOffset(300, 60 + #row.objectives * 24),
		position = UDim2.fromOffset(16, 146),
		children = rows,
	})
end

-- Level bar along the bottom edge (8.9) -----------------------------------------------------------------

local function LevelBar()
	local progression = hooks.useSection("progression")
	if not progression then
		return nil
	end
	local _, _, fraction = Progression.progress(progression, Content.Levels)
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.colors.track,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, {
		Fill = e("Frame", {
			Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
			BackgroundColor3 = Theme.meters.xp,
			BorderSizePixel = 0,
		}),
	})
end

-- Weapons and meds (4.9) ----------------------------------------------------------------------------------

-- Healing items carried, and the strongest one's id.
local function medsCount(inventory: any): (number, string?)
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

local function weaponSlot(inventory: any, n: number): any
	return if n == 1 then inventory.equipment.weapon else inventory.equipment.weapon2
end

local function WeaponBar()
	local inventory = hooks.useSection("inventory")
	local run = hooks.useSection("run")
	if not inventory then
		return nil
	end
	local active = inventory.activeWeapon or 1
	local other = if active == 1 then 2 else 1
	local function durabilityOf(slot: any): number?
		local def = if slot and slot.count > 0 then Content.Items[slot.itemId] else nil
		return if def and def.durability and slot.durability then slot.durability / def.durability else nil
	end
	local activeSlot, otherSlot = weaponSlot(inventory, active), weaponSlot(inventory, other)
	local meds, medId = medsCount(inventory)
	local onRun = type(run) == "table"
	return e("Frame", {
		Size = UDim2.fromOffset(WEAPON_BIG + WEAPON_SMALL * 2 + 30, WEAPON_BIG + 26),
		Position = UDim2.new(1, -16, 1, -140),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Meds = e(
			"Frame",
			{ Size = UDim2.fromOffset(WEAPON_SMALL, WEAPON_SMALL), LayoutOrder = 1, BackgroundTransparency = 1 },
			{
				Slot = e(ItemSlot, {
					itemId = medId,
					count = if medId then 1 else 0,
					size = WEAPON_SMALL,
					placeholder = "Meds",
					onActivated = Actions.useMeds,
				}),
				Grey = meds == 0 and e("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.colors.shadow,
					BackgroundTransparency = 0.45,
					ZIndex = 5,
				}, { Corner = e("UICorner", { CornerRadius = Theme.radius }) }),
				Count = meds > 0 and e("TextLabel", {
					Size = UDim2.fromOffset(22, 22),
					Position = UDim2.fromOffset(-4, -4),
					BackgroundColor3 = Color3.fromHex("C8473A"),
					FontFace = Theme.fonts.header,
					Text = tostring(meds),
					TextSize = Theme.textSize.caption,
					TextColor3 = Theme.colors.text,
					ZIndex = 6,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
				Key = e(KeyChip, { text = "H", position = UDim2.new(1, 2, 0, -2), anchorPoint = Vector2.new(1, 0) }),
			}
		),
		Other = e(
			"Frame",
			{ Size = UDim2.fromOffset(WEAPON_SMALL, WEAPON_SMALL), LayoutOrder = 2, BackgroundTransparency = 1 },
			{
				Slot = e(ItemSlot, {
					itemId = if otherSlot and otherSlot.count > 0 then otherSlot.itemId else nil,
					count = if otherSlot and otherSlot.count > 0 then 1 else 0,
					durability = durabilityOf(otherSlot),
					size = WEAPON_SMALL,
					placeholder = "weapon",
					onActivated = Actions.swapWeapon,
				}),
				Key = e(
					KeyChip,
					{ text = tostring(other), position = UDim2.new(1, 2, 0, -2), anchorPoint = Vector2.new(1, 0) }
				),
			}
		),
		Active = e(
			"Frame",
			{ Size = UDim2.fromOffset(WEAPON_BIG, WEAPON_BIG + 22), LayoutOrder = 3, BackgroundTransparency = 1 },
			{
				Slot = e(ItemSlot, {
					itemId = if activeSlot and activeSlot.count > 0 then activeSlot.itemId else nil,
					count = if activeSlot and activeSlot.count > 0 then 1 else 0,
					durability = durabilityOf(activeSlot),
					selected = true,
					size = WEAPON_BIG,
					placeholder = "weapon",
					-- On a run the big circle is the attack button (LDOE_PARITY #1).
					onActivated = function()
						if onRun then
							Actions.attack()
						else
							Actions.selectWeapon(active)
						end
					end,
				}),
				Key = e(
					KeyChip,
					{ text = tostring(active), position = UDim2.new(1, 2, 0, -2), anchorPoint = Vector2.new(1, 0) }
				),
				Swap = e(KeyChip, { text = "F", position = UDim2.fromOffset(-2, -2), anchorPoint = Vector2.new(0, 0) }),
				Name = e(Label, {
					text = if activeSlot and activeSlot.count > 0 then format.itemName(activeSlot.itemId) else "Fists",
					style = "caption",
					tone = "highlight",
					size = UDim2.new(1, 0, 0, 18),
					position = UDim2.fromScale(0, 1),
					anchorPoint = Vector2.new(0, 1),
					alignX = Enum.TextXAlignment.Center,
					stroke = true,
				}),
			}
		),
	})
end

-- Action buttons ---------------------------------------------------------------------------------------------

local function ActionButton(
	props: {
		label: string,
		keyName: string?, -- not `key`: React reserves it
		glyph: string,
		primary: boolean?,
		size: number,
		layoutOrder: number,
		onPress: () -> (),
		onRelease: (() -> ())?,
		dot: boolean?, -- something new inside (NEW badge, checklist 8.4)
		alertAt: number?, -- os.clock() of an alert: the button flashes red briefly
		badge: number?, -- a count in a red circle, e.g. unclaimed inbox rows (4.15)
	}
)
	local pressed, setPressed = React.useState(false)
	local now = hooks.useClock(0.1)
	local alerting = props.alertAt ~= nil and os.clock() - props.alertAt < 1.2
	local flash = alerting and math.floor((os.clock() - (props.alertAt :: number)) * 6) % 2 == 0
	local _ = now
	local scale = hooks.useAnimated(if pressed then 0.92 else 1, 24)
	return e("TextButton", {
		Size = UDim2.fromOffset(props.size, props.size),
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = if props.primary then Theme.colors.accent else Theme.colors.panelRaised,
		BackgroundTransparency = if props.primary then 0 else 0.1,
		[React.Event.InputBegan] = function(_rbx: any, input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				setPressed(true)
				props.onPress()
			end
		end,
		[React.Event.InputEnded] = function(_rbx: any, input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				setPressed(false)
				if props.onRelease then
					props.onRelease()
				end
			end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Stroke = e("UIStroke", {
			Color = if props.primary then Theme.colors.accentSoft else Theme.colors.strokeWarm,
			Thickness = Theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Scale = e("UIScale", { Scale = scale }),
		Glyph = e(Glyph, {
			name = props.glyph,
			size = UDim2.fromScale(0.46, 0.46),
			position = UDim2.fromScale(0.5, 0.42),
			anchorPoint = Vector2.new(0.5, 0.5),
			color = if props.primary then Theme.colors.textOnAccent else Theme.colors.text,
		}),
		Label = e(Label, {
			text = props.label,
			style = "caption",
			tone = if props.primary then "onAccent" else "muted",
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.new(0, 0, 1, -18),
			alignX = Enum.TextXAlignment.Center,
		}),
		Key = props.keyName and e(KeyChip, {
			text = props.keyName,
			position = UDim2.new(1, 2, 0, -2),
			anchorPoint = Vector2.new(1, 0),
			accent = props.primary,
		}),
		Badge = (props.badge or 0) > 0 and e("TextLabel", {
			Size = UDim2.fromOffset(22, 22),
			-- On this button's top-left rim: opposite its own key chip and clear of the
			-- neighbour's (QA2: mid-height badges looked like the neighbour's).
			Position = UDim2.fromOffset(-2, -2),
			-- A solid red count with light digits: dark digits on salmon read as a blot.
			BackgroundColor3 = Color3.fromHex("C8473A"),
			FontFace = Theme.fonts.header,
			Text = if (props.badge or 0) > 99 then "99+" else tostring(props.badge),
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.text,
			ZIndex = 4,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 1.5 }),
		}),
		Dot = (props.badge or 0) == 0 and props.dot and e("Frame", {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(4, 4),
			BackgroundColor3 = Theme.colors.accent,
			ZIndex = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = e("UIStroke", { Color = Theme.colors.shadow, Thickness = 1.5 }),
		}),
		Alert = flash and e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.colors.threat,
			BackgroundTransparency = 0.35,
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		}),
	})
end

local function ActionBar()
	local ui = hooks.useUi()
	local inbox = hooks.useSection("inbox")
	local marks = hooks.useSection("recipeMarks")
	local progression = hooks.useSection("progression")
	local unlocks = hooks.useSection("unlocks")
	-- Recipes unlocked since the catalogue was last closed: the Craft button's count (8.10).
	local newRecipes = 0
	if type(marks) == "table" and progression then
		local questState = State.get("quests")
		local progress: Crafting.Progress = {
			level = progression.level,
			unlocks = if type(unlocks) == "table" then unlocks else { recipes = {}, blueprints = {} },
			quests = if type(questState) == "table" then questState else nil,
		}
		for id, recipe in Content.Recipes do
			if marks.seen[id] ~= true and Crafting.isUnlocked(recipe, progress) then
				newRecipes += 1
			end
		end
	end
	local target = ui.target
	local interactLabel = if ui.panel == "build" then "Place" elseif target then target.verb else "Use"
	local glyph = if ui.panel == "build" then "build" else "interact"
	return e("Frame", {
		Size = UDim2.fromOffset(420, 110),
		Position = UDim2.new(1, -16, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Sprint = ui.touch and e(ActionButton, {
			label = "Sprint",
			glyph = "sprint",
			size = 64,
			layoutOrder = 1,
			onPress = function()
				Actions.setSprint(not ui.sprinting)
			end,
		}),
		Auto = ui.panel == "none" and e(ActionButton, {
			label = if ui.auto then "Auto on" else "Auto",
			keyName = "Q",
			glyph = "auto_gather",
			primary = ui.auto,
			size = 64,
			layoutOrder = 0,
			onPress = Actions.toggleAuto,
		}),
		Craft = e(ActionButton, {
			label = "Craft",
			keyName = "C",
			glyph = "craft",
			size = 64,
			layoutOrder = 2,
			onPress = Actions.toggleCrafting,
			badge = newRecipes,
		}),
		Build = e(ActionButton, {
			label = "Build",
			keyName = "B",
			glyph = "build",
			size = 64,
			layoutOrder = 3,
			onPress = Actions.toggleBuild,
		}),
		Bag = e(ActionButton, {
			label = "Bag",
			keyName = "Tab",
			glyph = "backpack",
			size = 64,
			layoutOrder = 4,
			onPress = if type(inbox) == "table"
					and #inbox > 0
					and ui.panel ~= "inventory"
				then Actions.openInbox
				else Actions.toggleInventory,
			dot = next(ui.newItems) ~= nil,
			alertAt = ui.bagFullAt,
			badge = if type(inbox) == "table" then #inbox else 0,
		}),
		Interact = e(ActionButton, {
			label = interactLabel,
			keyName = "E",
			glyph = glyph,
			primary = target ~= nil or ui.panel == "build",
			size = 96,
			layoutOrder = 5,
			onPress = function()
				Actions.interact()
				if ui.panel == "none" then
					Actions.setGathering(true)
				end
			end,
			onRelease = function()
				Actions.setGathering(false)
			end,
		}),
	})
end

local function HUD()
	local ui = hooks.useUi()
	local run = hooks.useSection("run")
	local playing = ui.panel == "none"
	return e(React.Fragment, nil, {
		Gear = playing and e("TextButton", {
			Size = UDim2.fromOffset(52, 52),
			Position = UDim2.new(1, -16, 0, 16),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = Theme.colors.panelTransparency,
			FontFace = Theme.fonts.header,
			Text = "",
			TextSize = 28,
			TextColor3 = Theme.colors.text,
			AutoButtonColor = true,
			[React.Event.Activated] = Actions.toggleSettings,
		}, {
			Glyph = e(Glyph, {
				name = "settings",
				size = UDim2.fromScale(0.6, 0.6),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				color = Theme.colors.text,
			}),
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = e("UIStroke", {
				Color = Theme.colors.strokeWarm,
				Thickness = Theme.strokeThickness,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Key = e(KeyChip, { text = "O", position = UDim2.new(1, 2, 0, -2), anchorPoint = Vector2.new(1, 0) }),
		}),
		Status = e(Status),
		Quest = playing and e(QuestTracker),
		-- On a Fog Run the location's own minimap (exits, bags, Hollow) with the Fog meter.
		Minimap = playing and e(if type(run) == "table" then RunHud.RunMinimap else Minimap),
		LevelBar = e(LevelBar),
		-- Studio playtests run sped up (Tuning.devSpeed): say so, never on live servers.
		Dev = DevSpeed.factor(Content) > 1 and e("TextLabel", {
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.new(0.5, 0, 0, 8),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Theme.colors.threat,
			FontFace = Theme.fonts.header,
			Text = `  DEV x{DevSpeed.factor(Content)}  `,
			TextSize = Theme.textSize.caption,
			TextColor3 = Theme.colors.textOnAccent,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
		Weapons = playing and e(WeaponBar),
		Actions = (playing or ui.panel == "build") and e(ActionBar),
	})
end

return HUD
