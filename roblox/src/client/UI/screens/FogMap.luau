--!strict
--[[
	FogMap (M, the HUD's Map button, or the Trailhead): the painted map of the region
	and the way out into the Fog (checklist 11.1-11.4, 11.7; LDOE_PARITY #38, #39, #42;
	rec1_06, rec1_07, rec3_02).

	- The illustrated map fills the screen; each location is a pin coloured by its fog
	  tier, your outpost is marked, and the route to the chosen one is drawn.
	- Energy sits top-left with its regen countdown, and Rations below it.
	- Choosing a pin opens its panel on the right: art, name, the fog tier, the rule
	  line, the Hollow found there, the recommended gear score, Main loot and Possible
	  loot (rarity frames), and AUTO (clear it into the inbox for Rations, #31).
	- The round Run and Walk buttons sit under the chosen pin: Run costs Energy and
	  arrives in seconds; Walk is free and takes real minutes you can spend at home.
	  They work at the Trailhead or the fog's edge; elsewhere the map is for planning.
	- A Walk in progress shows its timer with Hurry and Turn back.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local Actions = require("../../Actions")
local Net = require("../../Net")
local State = require("../../State")
local Theme = require("../theme")
local hooks = require("../hooks")
local mark = require("../mark")
local Button = require("../components/Button")
local Glyph = require("../components/Glyph")
local ItemSlot = require("../components/ItemSlot")
local KeyChip = require("../components/KeyChip")
local Label = require("../components/Label")

local e = React.createElement

local PANEL_WIDTH = 410
local PIN_LABEL = 200 -- a pin's name, centred under it
local REACH = 120 -- design pixels above the safe area (UI/components/FullScreen)
local PIN = 46
local ROUND = 66
local TIER_COLORS = {
	Color3.fromHex("8FC26A"), -- Light: a living green
	Color3.fromHex("E0A24A"), -- Dense: amber
	Color3.fromHex("C8473A"), -- Black: ember red
}
local TIER_NAMES = Content.Tuning.travel.fogTierNames
local HOLLOW_KINDS = { ["enemy.shambler"] = true, ["enemy.runner"] = true, ["enemy.bloater"] = true }
local RULES = {
	"Light fog: no other survivor can take what you leave. Leave from any edge.",
	"Dense fog: anyone can loot your bag if you fall. Get out at a marked exit.",
	"Black fog: anyone can take everything you carry. Exits close; a flare can get you out.",
}

local function locations(): { Types_Location }
	local list = {}
	for id, location in Content.Locations do
		if Art.fogMap.pins[id] then
			table.insert(list, location)
		end
	end
	table.sort(list, function(a: any, b: any): boolean
		return a.fogTier < b.fogTier
	end)
	return list
end
type Types_Location = any

local function energyNow(energy: any, now: number): (number, number, number?)
	if type(energy) ~= "table" then
		return 0, 200, nil
	end
	-- A partial section (no regen rate yet) shows its value without counting up.
	local cap = if type(energy.cap) == "number" then energy.cap else 200
	local base = if type(energy.value) == "number" then energy.value else 0
	local per = energy.secondsPerPoint
	if type(per) ~= "number" or per <= 0 or type(energy.updatedAt) ~= "number" then
		return base, cap, nil
	end
	local elapsed = math.max(0, now - energy.updatedAt)
	local value = if base >= cap then base else math.min(cap, base + math.floor(elapsed / per))
	local nextIn = if value < cap then per - (elapsed % per) else nil
	return value, cap, nextIn
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local minutes = seconds // 60
	if minutes >= 60 then
		return string.format("%dh %02dm", minutes // 60, minutes % 60)
	end
	return string.format("%d:%02d", minutes, seconds % 60)
end

local function countOf(inventory: any, itemId: string): number
	local total = 0
	if type(inventory) ~= "table" then
		return 0
	end
	for _, container in { inventory.pockets, inventory.backpack } do
		for _, slot in container or {} do
			if slot.itemId == itemId then
				total += slot.count
			end
		end
	end
	return total
end

-- Whether the survivor stands where trips start (the Trailhead or the fog's edge; the
-- server checks the same).
local function atDeparture(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local world = workspace:FindFirstChild("World")
	if root == nil or world == nil then
		return false
	end
	local reach = Content.Tuning.travel.departureStuds
	local trailhead = world:FindFirstChild("Trailhead")
	local sign = trailhead and trailhead:FindFirstChild("Sign")
	if sign and sign:IsA("BasePart") and (sign.Position - root.Position).Magnitude <= reach then
		return true
	end
	local wall = world:FindFirstChild("FogWall")
	for _, bank in (if wall then wall:GetChildren() else {}) do
		if bank:IsA("BasePart") and (bank.Position - root.Position).Magnitude <= reach + bank.Size.X / 2 then
			return true
		end
	end
	return false
end

-- Pieces --------------------------------------------------------------------------------------------

local function card(props: { size: UDim2, position: UDim2, anchorPoint: Vector2?, children: any })
	return e("Frame", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = Theme.colors.panelTransparency,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = Theme.strokeThickness }),
		Body = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, props.children),
	})
end

local function EnergyCard(props: { energy: any, rations: number })
	local now = hooks.useClock(1)
	local value, cap, nextIn = energyNow(props.energy, now)
	return card({
		size = UDim2.fromOffset(300, 108),
		position = UDim2.fromOffset(16, 16),
		children = {
			Icon = e(Glyph, {
				name = "energy",
				size = UDim2.fromOffset(26, 26),
				position = UDim2.fromOffset(12, 10),
				color = Theme.meters.energy,
			}),
			Title = e(Label, {
				text = "Energy",
				style = "section",
				position = UDim2.fromOffset(44, 10),
				size = UDim2.fromOffset(120, 26),
			}),
			Value = e(Label, {
				text = `{value}/{cap}`,
				style = "section",
				tone = "highlight",
				position = UDim2.new(1, -12, 0, 10),
				anchorPoint = Vector2.new(1, 0),
				size = UDim2.fromOffset(120, 26),
				alignX = Enum.TextXAlignment.Right,
			}),
			Track = e("Frame", {
				Size = UDim2.new(1, -24, 0, 8),
				Position = UDim2.fromOffset(12, 42),
				BackgroundColor3 = Theme.colors.track,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Fill = e("Frame", {
					Size = UDim2.fromScale(math.clamp(value / math.max(cap, 1), 0, 1), 1),
					BackgroundColor3 = Theme.meters.energy,
					BorderSizePixel = 0,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
			}),
			Regen = e(Label, {
				text = if nextIn then `+1 in {clock(nextIn)}` else "Full",
				style = "caption",
				tone = "muted",
				position = UDim2.fromOffset(12, 66),
				size = UDim2.fromOffset(140, 22),
			}),
			Rations = e("Frame", {
				-- Below the bar: the 44 px + button stays clear of it.
				Size = UDim2.fromOffset(120, 26),
				Position = UDim2.new(1, -12, 0, 64),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
			}, {
				Icon = e("ImageLabel", {
					Size = UDim2.fromOffset(26, 26),
					BackgroundTransparency = 1,
					Image = Content.Items["item.rations"].icon,
					ScaleType = Enum.ScaleType.Fit,
				}),
				Count = e(Label, {
					text = tostring(props.rations),
					style = "body",
					position = UDim2.fromOffset(32, 0),
					size = UDim2.fromOffset(40, 26),
				}),
				Plus = e(Button, {
					text = "+",
					glyph = "plus",
					variant = "secondary",
					size = UDim2.fromOffset(44, 44),
					position = UDim2.fromScale(1, 0.5),
					anchorPoint = Vector2.new(1, 0.5),
					onActivated = function()
						State.notify("Rations come from quests and the shop", "info")
					end,
				}),
			}),
		},
	})
end

-- The painted map, as its 3 x 2 tiles.
local function MapTiles()
	local children: { [string]: any } = {}
	for row, tiles in Art.fogMap.tiles do
		for column, image in tiles do
			children[`T{row}{column}`] = e("ImageLabel", {
				Size = UDim2.fromScale(1 / 3, 1 / 2),
				Position = UDim2.fromScale((column - 1) / 3, (row - 1) / 2),
				BackgroundTransparency = 1,
				Image = image,
				ScaleType = Enum.ScaleType.Stretch,
				ZIndex = 2,
				ref = mark.backdrop, -- the map runs under Roblox's top bar on purpose
			})
		end
	end
	-- The painted map is the backplate everything else sits on.
	return e(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, ref = mark.backdrop },
		children
	)
end

local function Pin(props: { location: any, selected: boolean, onSelect: () -> () })
	local location = props.location
	local at = Art.fogMap.pins[location.id] :: Vector2
	local color = TIER_COLORS[location.fogTier] or Theme.colors.text
	return e("TextButton", {
		Size = UDim2.fromOffset(PIN, PIN),
		Position = UDim2.fromScale(at.X, at.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.05,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 4,
		[React.Event.Activated] = props.onSelect,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Ring = e("UIStroke", { Color = color, Thickness = if props.selected then 4 else 3 }),
		Pips = e("Frame", {
			Size = UDim2.fromOffset(30, 10),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 3),
			}),
			A = e("Frame", { Size = UDim2.fromOffset(8, 8), BackgroundColor3 = color, Rotation = 45 }),
			B = location.fogTier >= 2
				and e("Frame", { Size = UDim2.fromOffset(8, 8), BackgroundColor3 = color, Rotation = 45 }),
			C = location.fogTier >= 3
				and e("Frame", { Size = UDim2.fromOffset(8, 8), BackgroundColor3 = color, Rotation = 45 }),
		}),
		Name = e(Label, {
			text = location.name,
			style = "section",
			tone = if props.selected then "highlight" else "text",
			position = UDim2.new(0.5, 0, 1, 6),
			anchorPoint = Vector2.new(0.5, 0),
			size = UDim2.fromOffset(PIN_LABEL, 22),
			alignX = Enum.TextXAlignment.Center,
			stroke = true,
		}),
	})
end

-- The route home -> the chosen pin, as a dashed line of chevrons (11.4).
-- `clear` is a box (in map pixels) the dashes stay out of: the pin, its name and the
-- Run and Walk buttons under it.
local function Route(props: { from: Vector2, to: Vector2, size: Vector2, clear: Rect? })
	local a = Vector2.new(props.from.X * props.size.X, props.from.Y * props.size.Y)
	local b = Vector2.new(props.to.X * props.size.X, props.to.Y * props.size.Y)
	local delta = b - a
	local length = delta.Magnitude
	local children: { [string]: any } = {}
	if length > 1 then
		local angle = math.deg(math.atan2(delta.Y, delta.X))
		local count = math.floor(length / 26)
		for index = 1, count - 1 do
			local p = a + delta * (index / count)
			local clear = props.clear
			if clear and p.X > clear.Min.X and p.X < clear.Max.X and p.Y > clear.Min.Y and p.Y < clear.Max.Y then
				continue
			end
			children[`D{index}`] = e("Frame", {
				Size = UDim2.fromOffset(12, 4),
				Position = UDim2.fromOffset(p.X, p.Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = angle,
				BackgroundColor3 = Theme.colors.accent,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, children)
end

local function RoundButton(props: {
	label: string,
	glyph: string?,
	detail: string,
	note: string,
	enabled: boolean,
	order: number,
	onActivated: () -> (),
})
	local teal = Color3.fromHex("2E8C82")
	return e("Frame", {
		Size = UDim2.fromOffset(ROUND + 20, ROUND + 40),
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
	}, {
		Button = e("TextButton", {
			Size = UDim2.fromOffset(ROUND, ROUND),
			Position = UDim2.fromScale(0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = if props.enabled then teal else Theme.colors.disabled,
			Text = "",
			AutoButtonColor = props.enabled,
			[React.Event.Activated] = function()
				if props.enabled then
					props.onActivated()
				end
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = e("UIStroke", {
				Color = if props.enabled then Color3.fromHex("9FE7D8") else Theme.colors.disabledStroke,
				Thickness = 2,
			}),
			Icon = props.glyph and e(Glyph, {
				name = props.glyph,
				size = UDim2.fromOffset(26, 26),
				position = UDim2.new(0.5, 0, 0, 10),
				anchorPoint = Vector2.new(0.5, 0),
			}),
			Detail = e(Label, {
				text = props.detail,
				style = "caption",
				position = UDim2.new(0.5, 0, 1, -8),
				anchorPoint = Vector2.new(0.5, 1),
				size = UDim2.fromOffset(ROUND - 6, 18),
				alignX = Enum.TextXAlignment.Center,
			}),
		}),
		Label = e(Label, {
			text = props.label,
			style = "section",
			tone = if props.enabled then "text" else "muted",
			position = UDim2.new(0.5, 0, 0, ROUND + 2),
			anchorPoint = Vector2.new(0.5, 0),
			size = UDim2.fromOffset(ROUND + 20, 20),
			alignX = Enum.TextXAlignment.Center,
			stroke = true,
		}),
		Note = e(Label, {
			text = props.note,
			style = "caption",
			tone = "muted",
			position = UDim2.new(0.5, 0, 0, ROUND + 22),
			anchorPoint = Vector2.new(0.5, 0),
			size = UDim2.fromOffset(ROUND + 20, 18),
			alignX = Enum.TextXAlignment.Center,
			stroke = true,
		}),
	})
end

local function lootGrid(items: { string }, size: number, order: number, columns: number): any
	local children: { [string]: any } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(size, size),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, itemId in items do
		if Content.Items[itemId] then
			children[`I{index}`] = e(ItemSlot, { itemId = itemId, count = 1, size = size, layoutOrder = index })
		end
	end
	local rows = math.ceil(#items / columns)
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, rows * (size + 6)),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, children)
end

local function Panel(props: { location: any, onClose: () -> () })
	local location = props.location
	local art = Art.fogMap.art[location.id]
	local hollow: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, spawn in location.enemySpawns do
		local enemy = Content.Enemies[spawn.enemyId]
		if enemy and not seen[enemy.id] and HOLLOW_KINDS[enemy.id] then
			seen[enemy.id] = true
			table.insert(hollow, enemy.name)
		end
	end
	local color = TIER_COLORS[location.fogTier] or Theme.colors.text
	return e("Frame", {
		Size = UDim2.new(0, PANEL_WIDTH, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = Theme.colors.panelTransparency,
		ZIndex = 6,
	}, {
		Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = Theme.strokeThickness }),
		Art = e("ImageLabel", {
			Size = UDim2.new(1, 0, 0, 150),
			BackgroundColor3 = Theme.colors.panelRaised,
			ref = mark.decor, -- the header picture the name and Close sit on
			Image = art or "",
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 6,
		}, {
			Shade = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.6, 0),
					NumberSequenceKeypoint.new(1, 0.35),
				}),
			}),
		}),
		Close = e(Button, {
			text = "Close",
			glyph = "close",
			variant = "secondary",
			size = UDim2.fromOffset(44, 44),
			position = UDim2.new(1, -10, 0, 10),
			anchorPoint = Vector2.new(1, 0),
			onActivated = props.onClose,
		}),
		Name = e(Label, {
			text = string.upper(location.name),
			style = "header",
			position = UDim2.fromOffset(16, 104),
			size = UDim2.new(1, -32, 0, 34),
			stroke = true,
			zIndex = 7,
		}),
		Body = e("ScrollingFrame", {
			Size = UDim2.new(1, -32, 1, -230),
			Position = UDim2.fromOffset(16, 160),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Theme.colors.strokeWarm,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 6,
		}, {
			Layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			Tier = e(Label, {
				text = `{string.upper(TIER_NAMES[location.fogTier] or "")} FOG   Level {location.levelGate}+   Gear {location.run.recommendedGearScore}`,
				style = "section",
				color = color,
				size = UDim2.new(1, 0, 0, 22),
				layoutOrder = 1,
			}),
			Rule = e(Label, {
				text = RULES[location.fogTier] or "",
				style = "caption",
				tone = "muted",
				wrap = true,
				size = UDim2.new(1, 0, 0, 36),
				layoutOrder = 2,
			}),
			Lost = e(Label, {
				text = "Anything you leave here is lost when the lobby closes.",
				style = "caption",
				tone = "accent",
				wrap = true,
				size = UDim2.new(1, 0, 0, 20),
				layoutOrder = 3,
			}),
			Hollow = e(Label, {
				text = `The Hollow: {table.concat(hollow, ", ")}`,
				style = "body",
				size = UDim2.new(1, 0, 0, 22),
				layoutOrder = 4,
			}),
			MainTitle = e(
				Label,
				{ text = "Main loot", style = "section", size = UDim2.new(1, 0, 0, 22), layoutOrder = 5 }
			),
			Main = lootGrid(location.mainLoot, 58, 6, 6),
			PossibleTitle = e(
				Label,
				{ text = "Possible loot", style = "section", size = UDim2.new(1, 0, 0, 22), layoutOrder = 7 }
			),
			Possible = lootGrid(location.possibleLoot, 58, 8, 6),
		}),
		Auto = e(Button, {
			text = "AUTO: clear it for 1 Ration",
			variant = "secondary",
			size = UDim2.new(1, -32, 0, 48),
			position = UDim2.new(0, 16, 1, -62),
			onActivated = function()
				Net.fire("AutoClear", location.id, "rations")
			end,
		}),
	})
end

local function WalkBar(props: { travel: any })
	local now = hooks.useClock(1)
	local travel = props.travel
	local location = Content.Locations[travel.locationId]
	local left = math.max(0, (travel.arrivesAt or now) - now)
	return card({
		size = UDim2.fromOffset(520, 64),
		position = UDim2.new(0.5, 0, 1, -16),
		anchorPoint = Vector2.new(0.5, 1),
		children = {
			Text = e(Label, {
				text = `{if travel.mode == "walk" then "Walking" else "Heading"} to {if location
					then location.name
					else "the Fog"}: {clock(left)}`,
				style = "section",
				position = UDim2.fromOffset(16, 0),
				size = UDim2.new(1, -250, 1, 0),
			}),
			Hurry = travel.mode == "walk" and e(Button, {
				text = "Hurry",
				size = UDim2.fromOffset(104, 44),
				position = UDim2.new(1, -124, 0.5, 0),
				anchorPoint = Vector2.new(1, 0.5),
				onActivated = function()
					Net.fire("TravelHurry")
				end,
			}),
			Back = e(Button, {
				text = "Turn back",
				variant = "secondary",
				size = UDim2.fromOffset(104, 44),
				position = UDim2.new(1, -12, 0.5, 0),
				anchorPoint = Vector2.new(1, 0.5),
				onActivated = function()
					Net.fire("TravelCancel")
				end,
			}),
		},
	})
end

-- The frame's size in UI units (offsets), not screen pixels: the App's UIScale makes the
-- two differ, and the pins, the route and the panel are all laid out in offsets.
local function uiSize(frame: GuiObject): Vector2
	local scale = 1
	local holder = frame.Parent
	while holder and not holder:IsA("LayerCollector") do
		local found = holder:FindFirstChildOfClass("UIScale")
		if found then
			scale *= found.Scale
		end
		holder = holder.Parent
	end
	return frame.AbsoluteSize / scale
end

local function FogMap()
	local ui = hooks.useUi()
	local energy = hooks.useSection("energy")
	local inventory = hooks.useSection("inventory")
	local travel = hooks.useSection("travel")
	-- The chosen location lives in the UI state, so the guide and the UI gate can open it.
	local selected: string? = ui.fogLocation
	local function setSelected(id: string?)
		if id then
			State.patch({ fogLocation = id })
		else
			State.clear("fogLocation")
		end
	end
	local size, setSize = React.useState(Vector2.new(1366, 768))
	hooks.useClock(1) -- re-check the Trailhead distance
	local open = ui.panel == "fogmap"
	if not open then
		return nil
	end
	local location = if selected then Content.Locations[selected] else nil
	local ready = atDeparture()
	local pins: { [string]: any } = {}
	local home = Art.fogMap.home
	local at = if location then Art.fogMap.pins[location.id] else nil
	-- With a panel open the map slides left only as far as it must for the chosen pin and
	-- its Run and Walk buttons to clear the panel.
	local shift = 0
	if at then
		local reach = at.X * size.X + ROUND + 26 + Theme.spacing.md
		shift = -math.clamp(reach - (size.X - PANEL_WIDTH), 0, PANEL_WIDTH)
	end
	for _, each in locations() do
		-- Pins the panel covers or the slide pushes off the left edge are left off (the
		-- chosen one is always in view); a pin's name is PIN_LABEL wide.
		local spot = Art.fogMap.pins[each.id]
		local x = if spot then spot.X * size.X + shift else 0
		if at and spot and (x > size.X - PANEL_WIDTH - PIN or x < PIN_LABEL / 2 + Theme.spacing.sm) then
			continue
		end
		pins[each.id] = e(Pin, {
			location = each,
			selected = each.id == selected,
			onSelect = function()
				setSelected(each.id)
			end,
		})
	end
	local energyValue = energyNow(energy, State.now())
	local walking = type(travel) == "table" and travel.mode == "walk"
	-- The map reaches REACH design pixels above the safe area, under Roblox's top bar
	-- (as UI/components/FullScreen's dim does); the chrome keeps to the safe area.
	local topInset = REACH
	return e("Frame", {
		Size = UDim2.new(1, 0, 1, REACH),
		Position = UDim2.fromOffset(0, -REACH),
		BackgroundColor3 = Theme.colors.shadow,
		ZIndex = 2,
		ref = mark.backdrop,
		[React.Change.AbsoluteSize] = function(rbx: Frame)
			setSize(uiSize(rbx))
		end,
	}, {
		Map = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			-- With a panel open the map slides left so the chosen pin stays in view.
			Position = UDim2.fromOffset(shift, 0),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			Tiles = e(MapTiles),
			Route = at and e(Route, {
				from = home,
				to = at,
				size = size,
				clear = Rect.new(
					at.X * size.X - (ROUND + 26),
					at.Y * size.Y - PIN / 2 - 6,
					at.X * size.X + (ROUND + 26),
					at.Y * size.Y + PIN / 2 + 30 + ROUND + 46
				),
			}),
			Home = e("Frame", {
				Size = UDim2.fromOffset(38, 38),
				Position = UDim2.fromScale(home.X, home.Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.colors.panel,
				ZIndex = 4,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Ring = e("UIStroke", { Color = Theme.colors.accent, Thickness = 3 }),
				Icon = e(Glyph, {
					name = "campfire",
					size = UDim2.fromOffset(24, 24),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					color = Theme.colors.accentSoft,
					zIndex = 5,
				}),
				Name = e(Label, {
					text = "Your outpost",
					style = "caption",
					tone = "highlight",
					position = UDim2.new(0.5, 0, 1, 4),
					anchorPoint = Vector2.new(0.5, 0),
					size = UDim2.fromOffset(140, 18),
					alignX = Enum.TextXAlignment.Center,
					stroke = true,
				}),
			}),
			Pins = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 }, pins),
			Travel = location and at and not walking and e("Frame", {
				Size = UDim2.fromOffset(2 * (ROUND + 20) + 12, ROUND + 40),
				Position = UDim2.new(at.X, 0, at.Y, PIN / 2 + 30),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				ZIndex = 5,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Run = e(RoundButton, {
					label = "RUN",
					glyph = "sprint",
					detail = `{location.energyCost}`,
					note = if energyValue < location.energyCost then "Not enough Energy" else "a few seconds",
					enabled = ready and energyValue >= location.energyCost,
					order = 1,
					onActivated = function()
						Actions.travel(location.id, "run")
					end,
				}),
				Walk = e(RoundButton, {
					label = "WALK",
					glyph = "map",
					detail = "free",
					note = clock(location.walkSeconds),
					enabled = ready,
					order = 2,
					onActivated = function()
						Actions.travel(location.id, "walk")
					end,
				}),
			}),
		}),
		-- The panel's header colour carried up under Roblox's top bar, so the panel reads
		-- as full height and the slid map's empty edge never shows.
		PanelCap = location and e("Frame", {
			Size = UDim2.fromOffset(PANEL_WIDTH, topInset),
			Position = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Theme.colors.panelRaised,
			BorderSizePixel = 0,
			ZIndex = 6,
			ref = mark.backdrop,
		}),
		-- Everything over the map sits in one layer drawn above it, below Roblox's top bar
		-- (the App ignores the inset; checklist 4.18).
		Chrome = e("Frame", {
			Size = UDim2.new(1, 0, 1, -topInset),
			Position = UDim2.fromOffset(0, topInset),
			BackgroundTransparency = 1,
			ZIndex = 6,
		}, {
			Energy = e(EnergyCard, { energy = energy, rations = countOf(inventory, "item.rations") }),
			Panel = location and e(Panel, {
				location = location,
				onClose = function()
					setSelected(nil)
				end,
			}),
			CloseMap = location == nil and e(Button, {
				text = "Close",
				glyph = "close",
				variant = "secondary",
				size = UDim2.fromOffset(48, 48),
				position = UDim2.new(1, -16, 0, 16),
				anchorPoint = Vector2.new(1, 0),
				onActivated = Actions.toggleFogMap,
			}),
			Key = location == nil
				and e(KeyChip, { text = "M", position = UDim2.new(1, -70, 0, 20), anchorPoint = Vector2.new(1, 0) }),
			Walk = walking and e(WalkBar, { travel = travel }),
			Hint = not ready and not walking and e(Label, {
				text = "Plan your trip here. Set out from the Trailhead or the fog's edge.",
				style = "body",
				tone = "muted",
				position = UDim2.new(0.5, if location then -PANEL_WIDTH / 2 else 0, 1, -24),
				anchorPoint = Vector2.new(0.5, 1),
				size = UDim2.fromOffset(620, 24),
				alignX = Enum.TextXAlignment.Center,
				stroke = true,
			}),
		}),
	})
end

return FogMap
