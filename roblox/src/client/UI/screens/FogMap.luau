--!strict
--[[
	FogMap (M, the HUD's Map button, or the Trailhead): the painted map of the region
	and the way out into the Fog (checklist 11.1-11.4, 11.7; LDOE_PARITY #38, #39, #42;
	rec1_06, rec1_07, rec3_02).

	- The illustrated map fills the screen, composed from data (Data/FogRegions): the
	  forest floor, meadow, rock and water patches, rivers, roads, trails and rails as
	  paths, tree clusters, landmark pictures and fog. Adding a location is data.
	- Each location is a pin coloured by its fog tier (an event location's pin counts
	  down to its next opening or closing), your outpost is marked, and the route to the
	  chosen one is drawn.
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
local FogRegions = require(ReplicatedStorage.Shared.Data.FogRegions)
local NeighboursMath = require(ReplicatedStorage.Shared.Domain.Neighbours)
local MomentOffers = require(ReplicatedStorage.Shared.Domain.MomentOffers)
local TravelMath = require(ReplicatedStorage.Shared.Domain.Travel)
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
local offers = require("../offers")

local e = React.createElement

local PANEL_WIDTH = 410
local PIN_LABEL = 200 -- a pin's name, centred under it
local REACH = 120 -- design pixels above the safe area (UI/components/FullScreen)
local PIN = 46
local ROUND = 66
local ROBUX = "rbxasset://textures/ui/common/robux.png"
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

-- Where a location's pin sits on the map (a share of the canvas), or nil.
local function pinAt(locationId: string): Vector2?
	local _, pin = FogRegions.pinOf(locationId)
	return if pin then pin.at else nil
end

-- The locations with pins in the region shown, easiest fog first.
local function locations(): { Types_Location }
	local list = {}
	for _, pin in FogRegions.current().pins do
		local location = Content.Locations[pin.locationId]
		if location then
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

-- The map canvas, composed from the region's data. Everything here is the backdrop the
-- pins and panels sit on (it may run under Roblox's top bar), so each piece is marked so.
-- The canvas is one painted backdrop: its pieces run past its edge on purpose (it clips
-- them), so the UI gate checks it as a single element.
local CANVAS = mark.attributes({ Decor = true, Backdrop = true, Composite = true })

-- Path looks, as shares of the canvas width so they hold at any screen size: an outer
-- edge and a paler core (rails get cross ties instead of a core).
local PATH_STYLES: { [string]: { outer: Color3, inner: Color3, width: number, core: number, ties: number? } } = {
	river = { outer = Color3.fromRGB(58, 74, 72), inner = Color3.fromRGB(104, 134, 138), width = 0.011, core = 0.55 },
	road = { outer = Color3.fromRGB(104, 86, 62), inner = Color3.fromRGB(196, 172, 128), width = 0.0068, core = 0.7 },
	trail = { outer = Color3.fromRGB(112, 94, 68), inner = Color3.fromRGB(184, 160, 118), width = 0.0042, core = 0.6 },
	rail = {
		outer = Color3.fromRGB(52, 48, 44),
		inner = Color3.fromRGB(120, 108, 92),
		width = 0.0034,
		core = 0.5,
		ties = 0.0045,
	},
}

-- How far a path wanders off its straight line between points (a share of the width).
local WANDER: { [string]: number } = { river = 0.006, trail = 0.004, road = 0.0015, rail = 0 }

local function sprite(name: string, size: UDim2, position: UDim2, extra: { [string]: any }?): any
	local props: { [string]: any } = {
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = Art.fogMap.sprites[name] or "",
		ScaleType = Enum.ScaleType.Stretch,
		ref = mark.backdrop,
	}
	local more: { [string]: any } = extra or {}
	for key, value in more do
		props[key] = value
	end
	return e("ImageLabel", props)
end

local function layer(order: number, children: { [string]: any }): any
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = order,
		ref = mark.backdrop,
	}, children)
end

-- A path's points in pixels, smoothed into a curve (Catmull-Rom) with a small fixed
-- meander, so rivers and trails read as drawn rather than ruled.
local function curve(path: FogRegions.Path, size: Vector2, seed: number): { Vector2 }
	local raw: { Vector2 } = {}
	for _, point in path.points do
		table.insert(raw, Vector2.new(point.X * size.X, point.Y * size.Y))
	end
	if #raw < 2 then
		return raw
	end
	local wander = (WANDER[path.kind] or 0) * size.X
	local rng = Random.new(seed)
	local out: { Vector2 } = { raw[1] }
	for index = 1, #raw - 1 do
		local p0 = raw[math.max(1, index - 1)]
		local p1 = raw[index]
		local p2 = raw[index + 1]
		local p3 = raw[math.min(#raw, index + 2)]
		local span = p2 - p1
		if span.Magnitude < 0.5 then
			continue
		end
		local normal = Vector2.new(-span.Unit.Y, span.Unit.X)
		local phase = rng:NextNumber() * math.pi * 2
		local steps = math.clamp(math.ceil(span.Magnitude / 22), 2, 12)
		for step = 1, steps do
			local t = step / steps
			local point = (
				p1 * 2
				+ (p2 - p0) * t
				+ (p0 * 2 - p1 * 5 + p2 * 4 - p3) * (t * t)
				+ (p1 * 3 - p0 - p2 * 3 + p3) * (t * t * t)
			) * 0.5
			if step < steps then
				point += normal * (math.sin(t * math.pi) * math.sin(phase + t * math.pi * 3) * wander)
			end
			table.insert(out, point)
		end
	end
	return out
end

-- One path as rotated bars with round ends (the outer edge, or the paler core above it),
-- or, for a rail's core, cross ties every few pixels.
local function pathBars(
	points: { Vector2 },
	kind: string,
	size: Vector2,
	out: { [string]: any },
	key: string,
	inner: boolean
)
	local style = PATH_STYLES[kind]
	local outer = math.max(3, style.width * size.X)
	local width = if inner then math.max(1.5, outer * style.core) else outer
	local color = if inner then style.inner else style.outer
	local tieGap = if inner and style.ties then math.max(5, style.ties * size.X) else nil
	local nextTie = 0
	local travelled = 0
	for index = 1, #points - 1 do
		local a = points[index]
		local b = points[index + 1]
		local length = (b - a).Magnitude
		if length < 0.5 then
			continue
		end
		local angle = math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
		local dir = (b - a).Unit
		if tieGap then
			while nextTie < travelled + length do
				local at = a + dir * (nextTie - travelled)
				out[`{key}_{index}_{math.floor(nextTie)}`] = e("Frame", {
					Size = UDim2.fromOffset(2, outer * 2.2),
					Position = UDim2.fromOffset(at.X, at.Y),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = angle,
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					ZIndex = 2,
					ref = mark.backdrop,
				})
				nextTie += tieGap
			end
		else
			local mid = (a + b) / 2
			out[`{key}_{index}`] = e("Frame", {
				Size = UDim2.fromOffset(length + width, width),
				Position = UDim2.fromOffset(mid.X, mid.Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = angle,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = if inner then 2 else 1,
				ref = mark.backdrop,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		travelled += length
	end
end

local function MapCanvas(props: { size: Vector2 })
	local region = FogRegions.current()
	local size = props.size
	local zones: { [string]: any } = {}
	for index, zone in region.zones do
		zones[`Z{index}`] = sprite(
			zone.kind,
			UDim2.fromOffset(zone.size.X * size.X, zone.size.Y * size.X),
			UDim2.fromScale(zone.at.X, zone.at.Y),
			{ Rotation = zone.rotation or 0, ImageTransparency = if zone.kind == "meadow" then 0.15 else 0.05 }
		)
	end
	local rivers: { [string]: any } = {}
	local roads: { [string]: any } = {}
	for index, path in region.paths do
		local into = if path.kind == "river" then rivers else roads
		local points = curve(path, size, index * 4513 + 7)
		pathBars(points, path.kind, size, into, `P{index}o`, false)
		pathBars(points, path.kind, size, into, `P{index}i`, true)
	end
	-- Woods: tree clusters scattered in each patch, the same every time, kept off the pins.
	local woods: { [string]: any } = {}
	local keepClear: { Vector2 } = { region.home }
	for _, pin in region.pins do
		table.insert(keepClear, pin.at)
	end
	for index, patch in region.woods do
		local rng = Random.new(index * 7919 + 17)
		for n = 1, patch.count do
			local at = patch.at
				+ Vector2.new((rng:NextNumber() - 0.5) * patch.size.X, (rng:NextNumber() - 0.5) * patch.size.Y)
			local clear = true
			for _, spot in keepClear do
				if (at - spot).Magnitude < 0.07 then
					clear = false
				end
			end
			if clear then
				local name = `trees{rng:NextInteger(1, 4)}`
				local width = (0.055 + rng:NextNumber() * 0.035) * size.X
				woods[`W{index}_{n}`] = sprite(
					name,
					UDim2.fromOffset(width, width * (Art.fogMap.aspects[name] or 1)),
					UDim2.fromScale(at.X, at.Y)
				)
			end
		end
	end
	local landmarks: { [string]: any } = {}
	for index, landmark in region.landmarks do
		local width = landmark.width * size.X
		landmarks[`L{index}`] = sprite(
			landmark.sprite,
			UDim2.fromOffset(width, width * (Art.fogMap.aspects[landmark.sprite] or 1)),
			UDim2.fromScale(landmark.at.X, landmark.at.Y),
			{ Rotation = landmark.rotation or 0 }
		)
	end
	local fog: { [string]: any } = {}
	for index, at in region.fog do
		fog[`F{index}`] = sprite(
			"fog",
			UDim2.fromOffset(0.24 * size.X, 0.24 * size.X),
			UDim2.fromScale(at.X, at.Y),
			{ ImageTransparency = 0.25 }
		)
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(44, 56, 38),
		ClipsDescendants = true,
		ZIndex = 2,
		ref = CANVAS,
	}, {
		Base = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Art.fogMap.sprites.baseForest,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(320, 320),
			ZIndex = 1,
			ref = mark.backdrop,
		}),
		Zones = layer(2, zones),
		Rivers = layer(3, rivers),
		Woods = layer(4, woods),
		Roads = layer(5, roads),
		Landmarks = layer(6, landmarks),
		Fog = layer(7, fog),
	})
end

-- "Opens in 2:10:00" / "Closes in 1:22:05" for a rotating event location (else nil),
-- and whether it is open now.
local function eventClock(location: any, now: number): (string?, boolean)
	local availability = location.availability
	if availability == nil or availability.kind ~= "rotating" then
		return nil, true
	end
	local open = TravelMath.isAvailable(availability, now)
	local left = math.max(0, math.floor(TravelMath.secondsUntilChange(availability, now)))
	local text = string.format("%d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60)
	return if open then "Closes in " .. text else "Opens in " .. text, open
end

local STATUS_COLORS: { [string]: Color3 } = {
	online = Color3.fromHex("6FCF7A"),
	offline = Theme.colors.disabledStroke,
	shielded = Color3.fromHex("6FA8DC"),
}
local LOOT_NAMES: { [string]: string } = { low = "Low loot", medium = "Some loot", high = "Rich loot" }

-- A neighbour's outpost (M2 raids): its Hearth level in a ring coloured online, offline or
-- shielded; name and guild tag; then the shield's timer, or the loot estimate and defense.
local function NeighbourMarker(props: { neighbour: NeighboursMath.Neighbour, at: Vector2, now: number })
	local neighbour = props.neighbour
	local status, left = NeighboursMath.status(neighbour, props.now)
	local tier = NeighboursMath.lootTier(neighbour.stockValue, NeighboursMath.RULES)
	local detail = if status == "shielded" and left
		then `Shielded {clock(left)}`
		else `{LOOT_NAMES[tier]}, defense {neighbour.defense}`
	local tag = if neighbour.guildTag then `[{neighbour.guildTag}] ` else ""
	return e("Frame", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromScale(props.at.X, props.at.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.05,
		ZIndex = 4,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Ring = e("UIStroke", { Color = STATUS_COLORS[status], Thickness = 3 }),
		Level = e(Label, {
			text = tostring(neighbour.hearthLevel),
			style = "section",
			size = UDim2.fromOffset(30, 20),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			alignX = Enum.TextXAlignment.Center,
		}),
		Name = e(Label, {
			text = tag .. neighbour.name,
			style = "caption",
			tone = "text",
			position = UDim2.new(0.5, 0, 1, 4),
			anchorPoint = Vector2.new(0.5, 0),
			size = UDim2.fromOffset(150, 18),
			alignX = Enum.TextXAlignment.Center,
			stroke = true,
		}),
		Detail = e(Label, {
			text = detail,
			style = "caption",
			tone = "muted",
			position = UDim2.new(0.5, 0, 1, 21),
			anchorPoint = Vector2.new(0.5, 0),
			size = UDim2.fromOffset(150, 16),
			alignX = Enum.TextXAlignment.Center,
			stroke = true,
		}),
	})
end

local function Pin(props: { location: any, selected: boolean, onSelect: () -> (), now: number })
	local location = props.location
	local at = pinAt(location.id) :: Vector2
	local countdown, open = eventClock(location, props.now)
	local color = if open then TIER_COLORS[location.fogTier] or Theme.colors.text else Theme.colors.disabledStroke
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
		Countdown = countdown and e(Label, {
			text = countdown,
			style = "caption",
			tone = if open then "accent" else "muted",
			position = UDim2.new(0.5, 0, 1, 30),
			anchorPoint = Vector2.new(0.5, 0),
			size = UDim2.fromOffset(PIN_LABEL, 18),
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

local function RoundButton(
	props: {
		label: string,
		glyph: string?,
		detail: string,
		note: string,
		enabled: boolean,
		order: number,
		onActivated: () -> (),
		price: number?, -- a product slot: the Robux price under the glyph
		fill: Color3?,
		rim: Color3?,
		position: UDim2?,
		anchorPoint: Vector2?,
		zIndex: number?,
	}
)
	local teal = props.fill or Color3.fromHex("2E8C82")
	return e("Frame", {
		Size = UDim2.fromOffset(ROUND + 20, ROUND + 40),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
		ZIndex = props.zIndex,
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
				Color = if props.enabled then props.rim or Color3.fromHex("9FE7D8") else Theme.colors.disabledStroke,
				Thickness = 2,
			}),
			Icon = props.glyph and e(Glyph, {
				name = props.glyph,
				size = UDim2.fromOffset(26, 26),
				position = UDim2.new(0.5, 0, 0, 10),
				anchorPoint = Vector2.new(0.5, 0),
			}),
			Detail = props.price == nil and e(Label, {
				text = props.detail,
				style = "caption",
				position = UDim2.new(0.5, 0, 1, -8),
				anchorPoint = Vector2.new(0.5, 1),
				size = UDim2.fromOffset(ROUND - 6, 18),
				alignX = Enum.TextXAlignment.Center,
			}),
			Price = props.price ~= nil and e("Frame", {
				Size = UDim2.fromOffset(ROUND - 6, 18),
				Position = UDim2.new(0.5, 0, 1, -8),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 3),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Robux = e("ImageLabel", {
					Size = UDim2.fromOffset(14, 14),
					BackgroundTransparency = 1,
					Image = ROBUX,
					LayoutOrder = 1,
				}),
				Amount = e(Label, {
					text = tostring(props.price),
					style = "caption",
					size = UDim2.fromOffset(30, 18),
					layoutOrder = 2,
				}),
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

local function Panel(props: { location: any, onClose: () -> (), blocked: string? })
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
			text = if props.blocked then `AUTO: {props.blocked}` else "AUTO: clear it for 1 Ration",
			variant = "secondary",
			disabled = props.blocked ~= nil,
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
	local progression = hooks.useSection("progression")
	local neighbours = hooks.useSection("neighbours") -- M2 fills it (Domain/Neighbours)
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
	local now = hooks.useClock(1) -- re-check the Trailhead distance; event countdowns
	local open = ui.panel == "fogmap"
	if not open then
		return nil
	end
	local location = if selected then Content.Locations[selected] else nil
	local ready = atDeparture()
	local pins: { [string]: any } = {}
	local home = FogRegions.current().home
	local at = if location then pinAt(location.id) else nil
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
		local spot = pinAt(each.id)
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
			now = now,
		})
	end
	-- Neighbours' outposts in their slots, while no location panel is open.
	local markers: { [string]: any } = {}
	local region = FogRegions.current()
	if type(neighbours) == "table" and location == nil then
		local list = neighbours :: { NeighboursMath.Neighbour }
		for index, slot in NeighboursMath.slots(list, #region.neighbourSlots) do
			local neighbour = list[index]
			markers[`N{neighbour.userId}`] = e(NeighbourMarker, {
				neighbour = neighbour,
				at = region.neighbourSlots[slot],
				now = now,
			})
		end
	end
	local energyValue = energyNow(energy, State.now())
	local walking = type(travel) == "table" and travel.mode == "walk"
	-- Why the chosen location can't be travelled to now, if it can't (the server refuses
	-- the same trips): below its level, or an event location between its windows.
	local level = if type(progression) == "table" then progression.level or 1 else 1
	local blocked: string? = nil
	if location then
		local _, openNow = eventClock(location, now)
		if level < location.levelGate then
			blocked = `Level {location.levelGate}+`
		elseif not openNow then
			blocked = "Closed now"
		end
	end
	-- Short of Energy for the Run: it greys, and the Refill slot beside it shows the shortfall
	-- (F-08; SHOP_CATALOG §6 "Out of Energy"). A Run the server refused for Energy
	-- ("energyShort", Controllers/Shop) shows it too, whatever this clock says.
	local slot: MomentOffers.RunSlot = if location
		then MomentOffers.runSlot(energyValue, location.energyCost, blocked ~= nil)
		else { run = "blocked", short = 0 }
	local refused = ui.energyShort
	if location and blocked == nil and type(refused) == "table" and os.clock() - (refused.at or 0) < 30 then
		local need = math.max(slot.short, math.ceil(refused.need or 0))
		if need > 0 then
			slot = { run = "refill", short = need }
		end
	end
	local short = location ~= nil and (energyValue < location.energyCost or slot.run == "refill")
	local energyChip = offers.energyChip
	local refill = if slot.run == "refill" and energyChip then energyChip(slot.short) else nil
	-- An event location closing before a Walk would get there (the server refuses it too).
	-- LocationDef has required fields where Travel.Destination has optional ones, which
	-- the new solver's invariant table properties refuse without the assertion.
	local walkLate = location ~= nil
		and TravelMath.walkTooLate(location :: TravelMath.Destination, Content.Tuning.travel :: any, now)
	-- An event pin's countdown sits under its name: the Run and Walk buttons go below it.
	local countdownGap = if location and eventClock(location, now) ~= nil then 20 else 0
	-- The Refill slot sits left of the Run: a neighbouring pin (and its name) under it is left
	-- off while it shows, as the panel's pins are.
	if refill and at then
		local right = at.X * size.X - (ROUND + 20) - 18
		local left = right - (ROUND + 20)
		local top = at.Y * size.Y + PIN / 2 + 30 + countdownGap
		local bottom = top + ROUND + 40
		for id in pins do
			local spot = if id ~= selected then pinAt(id) else nil
			if spot then
				local x, y = spot.X * size.X, spot.Y * size.Y
				if
					x + PIN_LABEL / 2 > left
					and x - PIN_LABEL / 2 < right
					and y + PIN / 2 + 24 > top
					and y - PIN / 2 < bottom
				then
					pins[id] = nil
				end
			end
		end
	end
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
			Tiles = e(MapCanvas, { size = size }),
			Refill = location and at and not walking and refill and e(RoundButton, {
				label = "REFILL",
				glyph = "energy",
				detail = "",
				price = refill.price,
				note = `Need {slot.short} more`,
				enabled = true,
				order = 0,
				fill = Theme.colors.accent,
				rim = Theme.colors.accentSoft,
				-- Left of the Run and Walk pair, which stays centred under the pin.
				position = UDim2.new(at.X, -(ROUND + 20) - 6 - 12, at.Y, PIN / 2 + 30 + countdownGap),
				anchorPoint = Vector2.new(1, 0),
				zIndex = 5,
				onActivated = function()
					local buy = offers.buyEnergy
					if buy then
						buy(slot.short)
					end
				end,
			}),
			Route = at and e(Route, {
				from = home,
				to = at,
				size = size,
				clear = Rect.new(
					at.X * size.X - (ROUND + 26) - (if refill then ROUND + 32 else 0),
					at.Y * size.Y - PIN / 2 - 6,
					at.X * size.X + (ROUND + 26),
					at.Y * size.Y + PIN / 2 + 30 + countdownGap + ROUND + 46
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
			Neighbours = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 }, markers),
			Pins = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 }, pins),
			Travel = location and at and not walking and e("Frame", {
				Size = UDim2.fromOffset(2 * (ROUND + 20) + 12, ROUND + 40),
				Position = UDim2.new(at.X, 0, at.Y, PIN / 2 + 30 + countdownGap),
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
					note = blocked or if short then "No Energy" else "a few seconds",
					enabled = ready and blocked == nil and not short,
					order = 1,
					onActivated = function()
						Actions.travel(location.id, "run")
					end,
				}),
				Walk = e(RoundButton, {
					label = "WALK",
					glyph = "map",
					detail = "free",
					note = blocked or if walkLate then "Closes first" else clock(location.walkSeconds),
					enabled = ready and blocked == nil and not walkLate,
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
				blocked = blocked,
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
