--!strict
--[[
	RunHud: everything a Fog Run adds to the screen (checklist 11.5, 11.6, 12.3-12.7,
	13.3, 13.9; LDOE_PARITY #42, #43, #46; rec6, rec7_02, rec7_04).

	- RunMinimap (drawn in place of the home minimap by HUD): buildings, the green
	  exit arcs, your bag (red X), party members, alerted Hollow and noise rings; the
	  lobby's Fog meter and time left sit right under it.
	- The target bar at the top centre: the locked Hollow's name and HP.
	- Search and extraction progress, a red hurt vignette on the side you were hit.
	- The arrival title card; the "found on the way" panel.
	- The death screen (cause, what was lost, going back in) and the results card.
	- The loading screen for a Run (location, time of day, fog tier, your HP, Energy,
	  food and water, a rotating tip).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Art = require(ReplicatedStorage.Shared.Art)
local Clock = require(ReplicatedStorage.Shared.Clock)
local Content = require(ReplicatedStorage.Shared.Data)
local Net = require("../../Net")
local State = require("../../State")
local Theme = require("../theme")
local hooks = require("../hooks")
local mark = require("../mark")
local Button = require("../components/Button")
local Glyph = require("../components/Glyph")
local ItemSlot = require("../components/ItemSlot")
local Label = require("../components/Label")
local ProgressBar = require("../components/ProgressBar")

local e = React.createElement

local RunHud = {}

local MAP_SIZE = 168
local MAP_RADIUS = 90
local TIER_NAMES = Content.Tuning.travel.fogTierNames
local TIER_COLORS = { Color3.fromHex("8FC26A"), Color3.fromHex("E0A24A"), Color3.fromHex("C8473A") }
local EXIT_GREEN = Color3.fromHex("5CC86E")
local VERSION = "v0.1"

local TIPS = {
	{ "LIGHT KEEPS THEM BACK", "The Hollow shy from strong light. A flare buys you room to breathe." },
	{ "NOISE CARRIES", "Every gunshot is heard across the yard. A blade or a bow keeps the Hollow asleep." },
	{
		"WATCH THE FOG METER",
		"The longer you stay, the better the loot and the worse the Hollow. Leave before it closes.",
	},
	{
		"YOUR BAG STAYS BEHIND",
		"If you fall, your backpack waits where you fell until the lobby closes. Go back in for it.",
	},
	{ "ROLL OUT OF IT", "C rolls you clear of a swing. It costs stamina, so don't roll for nothing." },
	{ "BLOATERS BURST", "Keep your distance from a bloater. Its cloud hurts long after it pops." },
}

local function card(props: {
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
	layoutOrder: number?,
	children: any,
})
	return e("Frame", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = Theme.colors.panelTransparency,
		ZIndex = props.zIndex,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = Theme.strokeThickness }),
		Body = e(
			"Frame",
			{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = props.zIndex },
			props.children
		),
	})
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

-- Run minimap ------------------------------------------------------------------------------------------------

local function dot(position: UDim2, size: number, color: Color3, zIndex: number): any
	return e("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

-- The Fog meter's height under the minimap (the HUD makes room for it).
RunHud.METER_HEIGHT = 46

-- How far (design pixels) full-screen layers reach above the safe area, under Roblox's
-- top bar (as UI/components/FullScreen does).
local REACH = 120

function RunHud.RunMinimap(props: { position: UDim2?, anchorPoint: Vector2? }?)
	local run = hooks.useSection("run")
	local noise = hooks.useSection("noise")
	hooks.useClock(0.25)
	local you = rootPosition()
	if type(run) ~= "table" or you == nil then
		return nil
	end
	local here = you :: Vector3
	local scale = (MAP_SIZE / 2) / MAP_RADIUS
	local function at(world: Vector3): UDim2
		return UDim2.fromOffset(MAP_SIZE / 2 + (world.X - here.X) * scale, MAP_SIZE / 2 + (world.Z - here.Z) * scale)
	end
	local function near(world: Vector3, extra: number?): boolean
		return Vector2.new(world.X - here.X, world.Z - here.Z).Magnitude <= MAP_RADIUS + (extra or 0)
	end
	local children: { [string]: any } = { Round = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }
	-- Buildings as their footprints.
	for index, roof in CollectionService:GetTagged("EO_Roof") do
		local building = roof.Parent
		local box = building and building:GetAttribute("Interior")
		local frame = building and building:GetAttribute("InteriorCFrame")
		if typeof(box) == "Vector3" and typeof(frame) == "CFrame" and near(frame.Position, 20) then
			local _, yaw = frame:ToEulerAnglesYXZ()
			children[`B{index}`] = e("Frame", {
				Size = UDim2.fromOffset(box.X * scale + 2, box.Z * scale + 2),
				Position = at(frame.Position),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = -math.deg(yaw),
				BackgroundColor3 = Color3.fromRGB(128, 118, 100),
				BorderSizePixel = 0,
				ZIndex = 2,
			})
		end
	end
	-- Exits: green arcs (#42), closed ones greyed.
	-- The server sends the open point ids (run.extraction.open); every other point is shut.
	local open: { [string]: boolean }? = nil
	local exits = run.extraction
	if type(exits) == "table" and exits.kind == "points" and type(exits.open) == "table" then
		local set: { [string]: boolean } = {}
		for _, id in exits.open do
			set[id] = true
		end
		open = set
	end
	for index, exit in CollectionService:GetTagged("EO_RunExit") do
		if exit:IsA("Model") and near(exit:GetPivot().Position, 30) then
			local id = exit:GetAttribute("PointId") :: string
			local closed = open ~= nil and not open[id]
			children[`X{index}`] = e("Frame", {
				Size = UDim2.fromOffset(18, 18),
				Position = at(exit:GetPivot().Position),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 5,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Arc = e("UIStroke", {
					Color = if closed then Theme.colors.disabledStroke else EXIT_GREEN,
					Thickness = 3,
				}),
			})
		end
	end
	-- Bags: yours as a red X, others' as dots.
	for index, drop in run.drops or {} do
		if drop.at then
			local world = Vector3.new(drop.at[1], here.Y, drop.at[2])
			if near(world) then
				children[`D{index}`] = e("TextLabel", {
					Size = UDim2.fromOffset(16, 16),
					Position = at(world),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.header,
					Text = "X",
					TextSize = 16,
					TextColor3 = if drop.mine then Color3.fromHex("E0503C") else Theme.colors.textMuted,
					TextStrokeColor3 = Theme.colors.shadow,
					TextStrokeTransparency = 0.2,
					ZIndex = 6,
				})
			end
		end
	end
	-- Other survivors, and the Hollow that are after someone.
	for index, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if other ~= Players.LocalPlayer and root and near(root.Position) then
			children[`P{index}`] = dot(at(root.Position), 7, Theme.colors.highlight, 6)
		end
	end
	local hollow = workspace:FindFirstChild("EO_HollowView")
	for index, model in (if hollow then hollow:GetChildren() else {}) do
		if model:IsA("Model") and near(model:GetPivot().Position) then
			children[`H{index}`] = dot(at(model:GetPivot().Position), 5, Color3.fromHex("C8473A"), 5)
		end
	end
	if type(noise) == "table" and os.clock() - noise.at < 1.5 then
		local radius = noise.radius * scale
		children.Noise = e("Frame", {
			Size = UDim2.fromOffset(radius * 2, radius * 2),
			Position = at(Vector3.new(noise.x, here.Y, noise.z)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Ring = e("UIStroke", {
				Color = Theme.colors.threat,
				Thickness = 2,
				Transparency = math.clamp((os.clock() - noise.at) / 1.5, 0, 1),
			}),
		})
	end
	children.You = dot(UDim2.fromOffset(MAP_SIZE / 2, MAP_SIZE / 2), 9, Theme.colors.accent, 7)
	local tier = run.fogTier or 1
	local ground = ({ Color3.fromRGB(58, 70, 50), Color3.fromRGB(64, 62, 56), Color3.fromRGB(46, 46, 50) })[tier]
	return e("Frame", {
		Size = UDim2.fromOffset(MAP_SIZE, MAP_SIZE + RunHud.METER_HEIGHT),
		Position = if props and props.position then props.position else UDim2.new(1, -16, 0, 80),
		AnchorPoint = if props and props.anchorPoint then props.anchorPoint else Vector2.new(1, 0),
		BackgroundTransparency = 1,
		ref = mark.composite, -- one graphic: the map, its dots and ring, the Fog meter
	}, {
		Map = e("CanvasGroup", {
			Size = UDim2.fromOffset(MAP_SIZE, MAP_SIZE),
			BackgroundColor3 = ground,
			BorderSizePixel = 0,
		}, children),
		Ring = e("Frame", { Size = UDim2.fromOffset(MAP_SIZE, MAP_SIZE), BackgroundTransparency = 1, ZIndex = 8 }, {
			Round = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = e(
				"UIStroke",
				{ Color = TIER_COLORS[tier] or Theme.colors.strokeWarm, Thickness = Theme.strokeThickness }
			),
		}),
		Meter = e(RunHud.FogMeter, { run = run }),
	})
end

-- The lobby's Fog meter (12.3): fills as the lobby ages; the band and the time left.
function RunHud.FogMeter(props: { run: any })
	local run = props.run
	local now = hooks.useClock(0.5)
	local closesAt = run.closesAt
	local left = if type(closesAt) == "number" then closesAt - now else nil
	local warning = run.phase == "warning"
	return e("Frame", {
		Size = UDim2.fromOffset(MAP_SIZE, 40),
		Position = UDim2.fromOffset(0, MAP_SIZE + 6),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = Theme.colors.panelTransparency,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e(
			"UIStroke",
			{ Color = if warning then Color3.fromHex("C8473A") else Theme.colors.strokeWarm, Thickness = 2 }
		),
		Title = e(Label, {
			text = `FOG: {string.upper(run.bandName or "")}`,
			style = "caption",
			tone = if warning then "accent" else "muted",
			position = UDim2.fromOffset(8, 2),
			size = UDim2.new(1, -70, 0, 18),
		}),
		Time = e(Label, {
			text = if left then clock(left) else "",
			style = "caption",
			tone = if warning then "accent" else "text",
			position = UDim2.new(1, -8, 0, 2),
			anchorPoint = Vector2.new(1, 0),
			size = UDim2.fromOffset(60, 18),
			alignX = Enum.TextXAlignment.Right,
		}),
		Bar = e("Frame", {
			Size = UDim2.new(1, -16, 0, 8),
			Position = UDim2.fromOffset(8, 24),
			BackgroundColor3 = Theme.colors.track,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = e("Frame", {
				Size = UDim2.fromScale(math.clamp(run.meter or 0, 0, 1), 1),
				BackgroundColor3 = Theme.colors.fog:Lerp(Theme.colors.threat, math.clamp(run.meter or 0, 0, 1)),
				BorderSizePixel = 0,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		}),
	})
end

-- Pieces shown on top of play ---------------------------------------------------------------------------------

local function TargetBar()
	local target = hooks.useSection("combatTarget")
	if type(target) ~= "table" then
		return nil
	end
	return card({
		size = UDim2.fromOffset(300, 46),
		layoutOrder = 1,
		children = {
			Name = e(Label, {
				text = target.name,
				style = "section",
				position = UDim2.fromOffset(12, 2),
				size = UDim2.new(1, -24, 0, 20),
				alignX = Enum.TextXAlignment.Center,
			}),
			Bar = e(ProgressBar, {
				progress = (target.hp or 0) / 100,
				color = Color3.fromHex("C8473A"),
				size = UDim2.new(1, -24, 0, 12),
				position = UDim2.fromOffset(12, 26),
			}),
		},
	})
end

-- A timed search or extraction as Controllers/FogRun stores it (false when idle).
type Channel = { endsAt: number, startedAt: number, kind: string? }

local function Progress()
	local search: Channel | false | nil = hooks.useSection("search")
	local extracting: Channel | false | nil = hooks.useSection("extracting")
	local now = hooks.useClock(0.05)
	local active = if type(extracting) == "table" then extracting elseif type(search) == "table" then search else nil
	if active == nil then
		return nil
	end
	local total = math.max(0.01, active.endsAt - active.startedAt)
	local progress = math.clamp((now - active.startedAt) / total, 0, 1)
	local isExtract = active == extracting
	local text = if isExtract
		then (if active.kind == "flare" then "Signal flare burning" else "Getting out")
		else "Searching"
	return card({
		size = UDim2.fromOffset(320, 58),
		position = UDim2.new(0.5, 0, 1, -128),
		anchorPoint = Vector2.new(0.5, 1),
		children = {
			Text = e(Label, {
				text = `{text}... {math.ceil(math.max(0, active.endsAt - now))}s`,
				style = "section",
				position = UDim2.fromOffset(12, 4),
				size = UDim2.new(1, -24, 0, 22),
				alignX = Enum.TextXAlignment.Center,
			}),
			Bar = e(ProgressBar, {
				progress = progress,
				color = if isExtract then EXIT_GREEN else Theme.colors.accent,
				size = UDim2.new(1, -24, 0, 14),
				position = UDim2.fromOffset(12, 32),
			}),
		},
	})
end

-- A red edge on the side you were hit from, fading out (13.9).
local function Hurt()
	local hurt = hooks.useSection("hurtAt")
	local now = hooks.useClock(0.03)
	if type(hurt) ~= "table" then
		return nil
	end
	local age = os.clock() - hurt.at
	if age > 0.8 then
		return nil
	end
	local alpha = 1 - age / 0.8
	local function edge(rotation: number, size: UDim2, position: UDim2, anchor: Vector2): any
		return e("Frame", {
			Size = size,
			Position = position,
			AnchorPoint = anchor,
			BackgroundColor3 = Color3.fromHex("A8261C"),
			BorderSizePixel = 0,
			ZIndex = 20,
		}, {
			Fade = e("UIGradient", {
				Rotation = rotation,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1 - 0.55 * alpha),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	local _ = now
	return e("Frame", {
		Size = UDim2.new(1, 0, 1, REACH),
		Position = UDim2.fromOffset(0, -REACH),
		BackgroundTransparency = 1,
		ZIndex = 20,
		ref = mark.backdrop,
	}, {
		Left = edge(0, UDim2.fromScale(0.18, 1), UDim2.fromScale(0, 0), Vector2.zero),
		Right = edge(180, UDim2.fromScale(0.18, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0)),
		Top = edge(90, UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 0), Vector2.zero),
		Bottom = edge(270, UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 1), Vector2.new(0, 1)),
	})
end

local function Arrival()
	local arrival = hooks.useSection("arrival")
	local now = hooks.useClock(0.05)
	if type(arrival) ~= "table" then
		return nil
	end
	local age = os.clock() - arrival.at
	if age > 4.5 then
		return nil
	end
	local location = Content.Locations[arrival.locationId]
	if location == nil then
		return nil
	end
	local fade = if age < 0.4 then age / 0.4 elseif age > 3.6 then (4.5 - age) / 0.9 else 1
	local hours = Clock.hoursAt(State.now())
	local _ = now
	return e("Frame", {
		Size = UDim2.fromOffset(560, 110),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, {
		Name = e(Label, {
			text = string.upper(location.name),
			style = "header",
			size = UDim2.new(1, 0, 0, 44),
			alignX = Enum.TextXAlignment.Center,
			transparency = 1 - fade,
			stroke = true,
		}),
		Rule = e("Frame", {
			Size = UDim2.new(0.6, 0, 0, 2),
			Position = UDim2.new(0.2, 0, 0, 50),
			BackgroundColor3 = TIER_COLORS[location.fogTier] or Theme.colors.text,
			BackgroundTransparency = 1 - fade,
			BorderSizePixel = 0,
		}),
		Line = e(Label, {
			text = `{TIER_NAMES[location.fogTier] or ""} fog   {string.format(
				"%02d:%02d",
				math.floor(hours),
				math.floor((hours % 1) * 60)
			)}`,
			style = "section",
			tone = "muted",
			position = UDim2.fromOffset(0, 58),
			size = UDim2.new(1, 0, 0, 24),
			alignX = Enum.TextXAlignment.Center,
			transparency = 1 - fade,
			stroke = true,
		}),
	})
end

local function TravelBonus()
	local bonus = hooks.useSection("travelBonus")
	local ui = hooks.useUi()
	if type(bonus) ~= "table" or #(bonus.items or {}) == 0 or ui.panel ~= "none" then
		return nil
	end
	local slots: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, stack in bonus.items do
		slots[`S{index}`] = e(ItemSlot, { itemId = stack.itemId, count = stack.count, size = 56, layoutOrder = index })
	end
	return card({
		size = UDim2.fromOffset(math.max(300, #bonus.items * 64 + 32), 156),
		layoutOrder = 3,
		children = {
			Title = e(Label, {
				text = "FOUND ON THE WAY",
				style = "section",
				position = UDim2.fromOffset(16, 8),
				size = UDim2.new(1, -32, 0, 22),
			}),
			Slots = e(
				"Frame",
				{ Size = UDim2.new(1, -32, 0, 56), Position = UDim2.fromOffset(16, 36), BackgroundTransparency = 1 },
				slots
			),
			Buttons = e("Frame", {
				Size = UDim2.new(1, -32, 0, 44),
				Position = UDim2.new(0, 16, 1, -54),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				TakeAll = e(Button, {
					text = "Take all: 1 Ration",
					size = UDim2.new(0.62, -4, 1, 0),
					layoutOrder = 1,
					onActivated = function()
						Net.fire("TravelBonusTakeAll")
					end,
				}),
				Leave = e(Button, {
					text = "Leave it",
					variant = "secondary",
					size = UDim2.new(0.38, -4, 1, 0),
					layoutOrder = 2,
					onActivated = function()
						State.set("travelBonus", false)
					end,
				}),
			}),
		},
	})
end

-- Full-screen moments ----------------------------------------------------------------------------------------

local CAUSES: { [string]: string } = {
	hollow = "The Hollow got you.",
	burst = "A bloater's cloud got you.",
	fog = "The Fog took you.",
	player = "Another survivor got you.",
}

local function stacksOf(list: any): { any }
	local out = {}
	for _, slot in (if type(list) == "table" then list else {}) do
		if type(slot) == "table" and slot.itemId and (slot.count or 0) > 0 then
			table.insert(out, slot)
		end
	end
	return out
end

local function slotRow(stacks: { any }, max: number): any
	local children: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	-- More than fit: the last tile says how many more there are, so nothing goes unseen.
	local shown = if #stacks > max then max - 1 else #stacks
	for index = 1, shown do
		local stack = stacks[index]
		children[`S{index}`] =
			e(ItemSlot, { itemId = stack.itemId, count = stack.count, size = 56, layoutOrder = index })
	end
	if #stacks > shown then
		children.More = e("Frame", {
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = Theme.colors.panelRaised,
			LayoutOrder = max,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = Theme.strokeThickness }),
			Count = e(Label, {
				text = `+{#stacks - shown}`,
				style = "section",
				tone = "highlight",
				size = UDim2.fromScale(1, 1),
				alignX = Enum.TextXAlignment.Center,
			}),
		})
	end
	return children
end

local function DeathScreen()
	local death = hooks.useSection("death")
	local energy = hooks.useSection("energy")
	local run = hooks.useSection("run")
	if type(death) ~= "table" then
		return nil
	end
	local info = death.info or {}
	local lost = stacksOf(info.lost and info.lost.backpack)
	for _, slot in stacksOf(info.lost and info.lost.equipment) do
		table.insert(lost, slot)
	end
	local location = Content.Locations[info.locationId or ""]
	local reentry = death.reentry
	local canGoBack = type(reentry) == "table" and type(run) ~= "table" and State.now() < (reentry.untilAt or 0)
	local cost = if location then math.ceil(location.energyCost / 2) else 0
	local energyValue = if type(energy) == "table" then energy.value else 0
	return e("Frame", {
		Size = UDim2.new(1, 0, 1, REACH),
		Position = UDim2.fromOffset(0, -REACH),
		BackgroundColor3 = Theme.colors.shadow,
		BackgroundTransparency = 0.18,
		ZIndex = 30,
		ref = mark.backdrop,
	}, {
		-- The content keeps to the safe area below the reach.
		Inset = e("UIPadding", { PaddingTop = UDim.new(0, REACH) }),
		Title = e(Label, {
			text = "YOU DIED",
			style = "header",
			position = UDim2.fromScale(0.5, 0.26),
			anchorPoint = Vector2.new(0.5, 0.5),
			size = UDim2.fromOffset(600, 48),
			alignX = Enum.TextXAlignment.Center,
			zIndex = 31,
		}),
		Cause = e(Label, {
			text = CAUSES[info.cause or "hollow"] or "You fell in the Fog.",
			style = "section",
			tone = "muted",
			position = UDim2.new(0.5, 0, 0.26, 36),
			anchorPoint = Vector2.new(0.5, 0),
			size = UDim2.fromOffset(600, 24),
			alignX = Enum.TextXAlignment.Center,
			zIndex = 31,
		}),
		LostTitle = e(Label, {
			text = if #lost > 0
				then `Your bag stays where you fell{if location then ` in {location.name}` else ""} until the lobby closes.`
				else "You carried nothing out with you.",
			style = "body",
			position = UDim2.fromScale(0.5, 0.42),
			anchorPoint = Vector2.new(0.5, 0),
			size = UDim2.fromOffset(720, 24),
			alignX = Enum.TextXAlignment.Center,
			zIndex = 31,
		}),
		Lost = #lost > 0 and e("Frame", {
			Size = UDim2.fromOffset(720, 56),
			Position = UDim2.new(0.5, 0, 0.42, 34),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			ZIndex = 31,
		}, slotRow(lost, 10)),
		Back = canGoBack and e(Button, {
			text = `Go back in: {cost} Energy`,
			disabled = energyValue < cost,
			size = UDim2.fromOffset(260, 52),
			position = UDim2.new(0.5, -8, 0.66, 0),
			anchorPoint = Vector2.new(1, 0),
			onActivated = function()
				if location then
					Net.fire("LobbyReenter", location.id)
				end
				State.set("death", false)
			end,
		}),
		Continue = e(Button, {
			text = "Continue",
			variant = if canGoBack then "secondary" else "primary",
			size = UDim2.fromOffset(200, 52),
			position = if canGoBack then UDim2.new(0.5, 8, 0.66, 0) else UDim2.fromScale(0.5, 0.66),
			anchorPoint = if canGoBack then Vector2.zero else Vector2.new(0.5, 0),
			onActivated = function()
				State.set("death", false)
			end,
		}),
	})
end

local function ResultCard()
	local result = hooks.useSection("result")
	local run = hooks.useSection("run")
	local death = hooks.useSection("death")
	if type(result) ~= "table" or type(run) == "table" or type(death) == "table" then
		return nil -- shown once home, after any death screen
	end
	local info = result.info or {}
	if info.outcome == "died" then
		return nil
	end
	local carried = stacksOf(info.carriedOut)
	return card({
		size = UDim2.fromOffset(560, 300),
		position = UDim2.fromScale(0.5, 0.45),
		anchorPoint = Vector2.new(0.5, 0.5),
		zIndex = 25,
		children = {
			Title = e(Label, {
				text = if info.outcome == "extracted" then "YOU MADE IT OUT" else "THE FOG CLOSED",
				style = "header",
				position = UDim2.fromOffset(0, 18),
				size = UDim2.new(1, 0, 0, 36),
				alignX = Enum.TextXAlignment.Center,
				zIndex = 26,
			}),
			Stats = e(Label, {
				text = `{clock(info.seconds or 0)} out there   {info.kills or 0} Hollow   {info.containersSearched or 0} searched   +{info.xp or 0} XP`,
				style = "body",
				tone = "muted",
				position = UDim2.fromOffset(0, 62),
				size = UDim2.new(1, 0, 0, 24),
				alignX = Enum.TextXAlignment.Center,
				zIndex = 26,
			}),
			Carried = e("Frame", {
				Size = UDim2.new(1, -40, 0, 56),
				Position = UDim2.fromOffset(20, 110),
				BackgroundTransparency = 1,
				ZIndex = 26,
			}, slotRow(carried, 8)),
			Close = e(Button, {
				text = "Continue",
				size = UDim2.fromOffset(200, 52),
				position = UDim2.new(0.5, 0, 1, -72),
				anchorPoint = Vector2.new(0.5, 0),
				onActivated = function()
					State.set("result", false)
				end,
			}),
		},
	})
end

-- The loading screen for a Run (rec7_02): location, time of day, fog, your stats, a tip.
local function Loading()
	local travel = hooks.useSection("travel")
	local survival = hooks.useSection("survival")
	local energy = hooks.useSection("energy")
	local now = hooks.useClock(0.25)
	if type(travel) ~= "table" then
		return nil
	end
	local arriving = travel.mode == "run" or travel.matching or (travel.arrivesAt and now >= travel.arrivesAt)
	if not arriving then
		return nil
	end
	local location = Content.Locations[travel.locationId]
	local tip = TIPS[(math.floor(now / 6) % #TIPS) + 1]
	local hours = Clock.hoursAt(now)
	local started = travel.departedAt or now
	local total = math.max(1, (travel.arrivesAt or now) - started)
	local progress = if travel.matching then 0.9 else math.clamp((now - started) / total, 0, 0.85)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local function stat(glyph: string, value: number, order: number): any
		return e("Frame", { Size = UDim2.fromOffset(84, 30), BackgroundTransparency = 1, LayoutOrder = order }, {
			Icon = e(Glyph, { name = glyph, size = UDim2.fromOffset(24, 24), position = UDim2.fromOffset(0, 3) }),
			Value = e(Label, {
				text = tostring(math.floor(value)),
				style = "section",
				position = UDim2.fromOffset(30, 2),
				size = UDim2.fromOffset(54, 26),
			}),
		})
	end
	local top = REACH
	return e("Frame", {
		Size = UDim2.new(1, 0, 1, REACH),
		Position = UDim2.fromOffset(0, -REACH),
		BackgroundColor3 = Color3.fromHex("1A1D21"),
		ZIndex = 40,
		ref = mark.backdrop,
	}, {
		Header = e("ImageLabel", {
			-- The band runs under Roblox's top bar; its text starts below it.
			Size = UDim2.new(1, 0, 0, 118 + top),
			ref = mark.backdrop,
			BackgroundColor3 = Theme.colors.panelRaised,
			Image = if location then Art.fogMap.art[location.id] or "" else "",
			ImageTransparency = 0.45,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 40,
		}, {
			Inset = e("UIPadding", { PaddingTop = UDim.new(0, top) }),
			Time = e(Label, {
				text = string.format(
					"%02d:%02d   %s fog",
					math.floor(hours),
					math.floor((hours % 1) * 60),
					if location then TIER_NAMES[location.fogTier] or "" else ""
				),
				style = "body",
				tone = "muted",
				position = UDim2.fromOffset(60, 28),
				size = UDim2.fromOffset(400, 24),
				zIndex = 41,
			}),
			Name = e(Label, {
				text = if location then location.name else "The Fog",
				style = "header",
				position = UDim2.fromOffset(60, 54),
				size = UDim2.fromOffset(600, 40),
				zIndex = 41,
			}),
			Stats = e("Frame", {
				Size = UDim2.fromOffset(360, 30),
				Position = UDim2.new(1, -60, 0, 40),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				ZIndex = 41,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Health = stat("health", if humanoid then humanoid.Health else 100, 1),
				Energy = stat("energy", if type(energy) == "table" then energy.value else 0, 2),
				Food = stat("hunger", if type(survival) == "table" then survival.hunger or 0 else 0, 3),
				Water = stat("thirst", if type(survival) == "table" then survival.thirst or 0 else 0, 4),
			}),
		}),
		TipTitle = e(Label, {
			text = tip[1],
			style = "header",
			color = Color3.fromHex("5CC8B8"),
			position = UDim2.new(0, 120, 0.55, 0),
			size = UDim2.fromOffset(700, 34),
			zIndex = 41,
		}),
		Tip = e(Label, {
			text = tip[2],
			style = "body",
			wrap = true,
			position = UDim2.new(0, 120, 0.55, 40),
			size = UDim2.fromOffset(620, 60),
			zIndex = 41,
		}),
		Bar = e(ProgressBar, {
			progress = progress,
			color = Theme.colors.text,
			size = UDim2.fromOffset(420, 6),
			position = UDim2.new(0.5, -210, 1, -90),
		}),
		Status = e(Label, {
			text = if travel.matching then "Finding a lobby..." else "loading...",
			style = "caption",
			tone = "muted",
			position = UDim2.new(0.5, 0, 1, -76),
			anchorPoint = Vector2.new(0.5, 0),
			size = UDim2.fromOffset(300, 20),
			alignX = Enum.TextXAlignment.Center,
			zIndex = 41,
		}),
		Version = e(Label, {
			text = VERSION,
			style = "caption",
			tone = "muted",
			position = UDim2.new(1, -24, 1, -28),
			anchorPoint = Vector2.new(1, 0),
			size = UDim2.fromOffset(200, 20),
			alignX = Enum.TextXAlignment.Right,
			zIndex = 41,
		}),
	})
end

function RunHud.Screen()
	local run = hooks.useSection("run")
	local ui = hooks.useUi()
	local playing = ui.panel == "none"
	local onRun = type(run) == "table"
	return e(React.Fragment, nil, {
		-- Cards and bars keep to the App's safe area (4.18); full-screen layers reach under it.
		Safe = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			-- Top centre, one column so they never overlap: the target bar (the HUD's
			-- reserved slot), the arrival card, then "found on the way".
			Column = onRun and e("Frame", {
				Size = UDim2.new(0, 560, 1, -24),
				Position = UDim2.new(0.5, 0, 0, 12),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Target = playing and e(TargetBar),
				Arrival = playing and e(Arrival),
				Bonus = e(TravelBonus),
			}),
			Progress = onRun and e(Progress),
		}),
		Hurt = onRun and e(Hurt),
		Death = e(DeathScreen),
		Result = e(ResultCard),
		Loading = e(Loading),
	})
end

return RunHud
