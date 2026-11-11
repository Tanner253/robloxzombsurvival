--!strict
--[[
	AreaMap: the full-screen map of where you are (checklist 8.11 "Expand"), opened by a
	tap or click on the minimap at home (and M while the Fog map is off). On a Fog Run
	the minimap opens the Fog map instead.

	- The same picture as the minimap (components/MapCanvas over Controllers/Radar's
	  map), whole and north up, fitted to the screen: the plots with their outposts,
	  Haven Square, the road, the woods and the fog wall, the Trailhead.
	- Live every frame: you (the arrow, turning with you), your party and other survivors.
	- Labels for the plots ("Your outpost" on yours), Haven Square, the VIP Lounge and the
	  Trailhead; Haven's people as icons; a key to the icons; Close (or M) shuts it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local MapData = require(ReplicatedStorage.Shared.Domain.MapData)
local Actions = require("../../Actions")
local Radar = require("../../Controllers/Radar")
local Theme = require("../theme")
local hooks = require("../hooks")
local mark = require("../mark")
local Button = require("../components/Button")
local KeyChip = require("../components/KeyChip")
local Label = require("../components/Label")
local MapCanvas = require("../components/MapCanvas")

local e = React.createElement

local REACH = 120 -- design pixels the backdrop reaches above the safe area, under the top bar
local PAD = 28
local EXIT_GREEN = Color3.fromHex("5CC86E")
local PARTY = Color3.fromHex("4FA3E0")
local INK = Color3.fromHex("0B0D10")
local LEGEND_WIDTH = 190
local PLOT_LABEL = 50 -- studs from a plot's middle toward its outer edge
local SQUARE_LABEL = 44 -- studs north of Haven Square's middle
-- For the UI gate: the map with its marks is one picture (its parts overlap and its edge
-- clips them on purpose), and it runs up under Roblox's top bar like a backdrop.
local PICTURE = mark.attributes({ Composite = true, Backdrop = true, Decor = true })

-- The frame's size in UI units (offsets), not screen pixels (the App's UIScale).
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

local function dot(size: number, color: Color3, outline: Color3, position: UDim2?, order: number?): any
	return e("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = order,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = e("UIStroke", { Color = outline, Thickness = 1.5 }),
	})
end

local function glyphChip(name: string, size: number, color: Color3, position: UDim2?): any
	return e("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.1,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = 1.5 }),
		Icon = e("ImageLabel", {
			Size = UDim2.fromOffset(size * 0.66, size * 0.66),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = (Art.glyphs :: any)[name] or "",
			ImageColor3 = color,
			ref = mark.attributes({ Glyph = name }),
		}),
	})
end

local function exitRing(size: number, position: UDim2?): any
	return e("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.4,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Ring = e("UIStroke", { Color = EXIT_GREEN, Thickness = 3 }),
		Core = dot(size * 0.35, EXIT_GREEN, EXIT_GREEN),
	})
end

-- The arrow for "you": the minimap's dart, at `size` times its size.
local function arrow(size: number): { [string]: any }
	local function fan(scale: number, color: Color3, order: number): { [string]: any }
		local tip = Vector2.new(0, -8.5) * scale
		local base = { Vector2.new(-6.5, 7) * scale, Vector2.new(0, 3) * scale, Vector2.new(6.5, 7) * scale }
		local bars: { [string]: any } = {}
		for segment = 1, 2 do
			for step = 0, 6 do
				local point = base[segment]:Lerp(base[segment + 1], step / 6)
				local span = point - tip
				bars[`B{segment}_{step}`] = e("Frame", {
					Size = UDim2.fromOffset(span.Magnitude, 2.2 * scale),
					Position = UDim2.fromOffset((tip.X + point.X) / 2, (tip.Y + point.Y) / 2),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = math.deg(math.atan2(span.Y, span.X)),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					ZIndex = order,
				})
			end
		end
		return bars
	end
	return {
		Outline = e(
			"Frame",
			{ Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 1 },
			fan(size * 1.35, INK, 1)
		),
		Fill = e(
			"Frame",
			{ Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 2 },
			fan(size, Color3.new(1, 1, 1), 2)
		),
	}
end

local function LegendRow(props: { order: number, icon: any, text: string })
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
	}, {
		Icon = e("Frame", { Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1 }, { Mark = props.icon }),
		Text = e(Label, {
			text = props.text,
			style = "caption",
			tone = "text",
			position = UDim2.fromOffset(30, 0),
			size = UDim2.new(1, -30, 1, 0),
		}),
	})
end

local function AreaMap()
	local ui = hooks.useUi()
	local plot = hooks.useSection("plot")
	local size, setSize = React.useState(Vector2.new(1366, 768 + REACH))
	local current, setCurrent = React.useState(Radar.current())
	local features, setFeatures = React.useState(Radar.features())
	local youRef = React.useRef(nil :: Frame?)
	local othersRef = React.useRef(nil :: Frame?)
	local open = ui.panel == "areamap"

	React.useEffect(function()
		local a = Radar.changed:Connect(function()
			setCurrent(Radar.current())
		end)
		local b = Radar.featuresChanged:Connect(function()
			setFeatures(Radar.features())
		end)
		return function()
			a:Disconnect()
			b:Disconnect()
		end
	end, {})

	-- The map's fit: pixels per stud and where the bounds' corner sits.
	local scale, ox, oy = 1, 0, 0
	if current then
		local safeHeight = size.Y - REACH
		scale, ox, oy = MapData.fit((current :: Radar.Current).map.bounds, size.X, safeHeight, PAD)
		oy += REACH
	end

	-- You and the others, every frame.
	React.useEffect(function()
		if not open or current == nil then
			return function() end
		end
		local map = (current :: Radar.Current).map
		local origin = (current :: Radar.Current).origin
		local others: { [Player]: Frame } = {}
		local connection = RunService.RenderStepped:Connect(function()
			-- In scale of the layer (floats), not whole-pixel offsets, so markers glide.
			local function at(world: Vector3): UDim2
				return UDim2.fromScale(
					(ox + (world.X - origin.X - map.bounds.x0) * scale) / size.X,
					(oy + (world.Z - origin.Z - map.bounds.z0) * scale) / size.Y
				)
			end
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local you = youRef.current
			if you then
				you.Visible = root ~= nil
				if root then
					local look = (root :: BasePart).CFrame.LookVector
					you.Position = at((root :: BasePart).Position)
					you.Rotation = MapData.heading(look.X, look.Z, 0)
				end
			end
			local layer = othersRef.current
			if layer == nil then
				return
			end
			for _, other in Players:GetPlayers() do
				if other == Players.LocalPlayer then
					continue
				end
				local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local frame: Frame? = others[other]
				if otherRoot == nil then
					if frame then
						frame.Visible = false
					end
					continue
				end
				if frame == nil then
					local made = Instance.new("Frame")
					made.Size = UDim2.fromOffset(9, 9)
					made.AnchorPoint = Vector2.new(0.5, 0.5)
					made.BorderSizePixel = 0
					local round = Instance.new("UICorner")
					round.CornerRadius = UDim.new(1, 0)
					round.Parent = made
					local line = Instance.new("UIStroke")
					line.Thickness = 1.5
					line.Parent = made
					made.Parent = layer
					others[other] = made
					frame = made
				end
				local friend = Radar.inParty(other.UserId)
				local f = frame :: Frame
				f.BackgroundColor3 = if friend then PARTY else Theme.colors.text
				local line = f:FindFirstChildOfClass("UIStroke")
				if line then
					line.Color = if friend then Theme.colors.text else INK
				end
				f.Visible = true
				f.Position = at((otherRoot :: BasePart).Position)
			end
			for other, frame in others do
				if other.Parent == nil then
					frame:Destroy()
					others[other] = nil
				end
			end
		end)
		return function()
			connection:Disconnect()
			for _, frame in others do
				frame:Destroy()
			end
		end
	end, { open, current, scale, ox, oy, size } :: { any })

	if not open or current == nil then
		return nil
	end
	local map = (current :: Radar.Current).map
	local span = Vector2.new(map.bounds.x1 - map.bounds.x0, map.bounds.z1 - map.bounds.z0)
	local function place(x: number, z: number, dy: number?): UDim2
		return UDim2.fromOffset(ox + (x - map.bounds.x0) * scale, oy + (z - map.bounds.z0) * scale + (dy or 0))
	end
	local myPlot = if type(plot) == "table" then plot.index else nil

	-- Labels and markers for the map's points; Haven's people from the Radar.
	local marks: { [string]: any } = {}
	for _, point in map.points do
		if point.kind == "plot" then
			local index = tonumber(string.match(point.id, "%d+"))
			local mine = index ~= nil and index == myPlot
			-- At the plot's outer edge: its middle is where an outpost stands.
			local outward = if point.z < 0 then -PLOT_LABEL else PLOT_LABEL
			marks[point.id] = e(Label, {
				text = if mine then "Your outpost" else point.label or "",
				style = if mine then "body" else "caption",
				tone = if mine then "highlight" else "text",
				position = place(point.x, point.z + outward),
				anchorPoint = Vector2.new(0.5, 0.5),
				size = UDim2.fromOffset(140, 22),
				alignX = Enum.TextXAlignment.Center,
				stroke = true,
				zIndex = 3,
			})
		elseif point.kind == "trailhead" or point.kind == "exit" then
			marks[point.id] = exitRing(18, place(point.x, point.z))
			marks[`{point.id}.label`] = e(Label, {
				text = point.label or "Exit",
				style = "caption",
				tone = "highlight",
				position = place(point.x, point.z, 14),
				anchorPoint = Vector2.new(0.5, 0),
				size = UDim2.fromOffset(120, 18),
				alignX = Enum.TextXAlignment.Center,
				stroke = true,
				zIndex = 3,
			})
		elseif point.kind == "fire" then
			marks[point.id] = glyphChip("campfire", 22, Theme.colors.accentSoft, place(point.x, point.z))
		elseif point.kind == "poi" then
			-- Haven Square's name over its north side; the Lounge's in its yard.
			local square = point.id == "haven.square"
			marks[point.id] = e(Label, {
				text = point.label or "",
				style = "caption",
				tone = "text",
				position = place(point.x, if square then point.z - SQUARE_LABEL else point.z),
				anchorPoint = Vector2.new(0.5, if square then 1 else 0.5),
				size = UDim2.fromOffset(130, 18),
				alignX = Enum.TextXAlignment.Center,
				stroke = true,
				zIndex = 3,
			})
		end
	end
	for _, blip in Radar.blips() do
		if blip.kind == "npc" and blip.at then
			local world = blip.at :: Vector3
			local origin = (current :: Radar.Current).origin
			marks[blip.key] = glyphChip(
				blip.glyph or "talk",
				22,
				Theme.colors.highlight,
				place(world.X - origin.X, world.Z - origin.Z)
			)
		end
	end

	local legend = {
		{
			icon = e("Frame", {
				Size = UDim2.fromOffset(0, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
			}, arrow(0.8)),
			text = "You",
		},
		{ icon = dot(10, PARTY, Theme.colors.text), text = "Your party" },
		{ icon = dot(9, Theme.colors.text, INK), text = "Other survivors" },
		{ icon = glyphChip("coin", 20, Theme.colors.highlight), text = "Trader" },
		{ icon = glyphChip("quests", 20, Theme.colors.highlight), text = "Trail Keeper" },
		{ icon = glyphChip("pass", 20, Theme.colors.highlight), text = "Lounge Warden" },
		{ icon = exitRing(16), text = "Trailhead" },
	}
	local legendRows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
	}
	for index, row in legend do
		legendRows[`R{index}`] = e(LegendRow, { order = index, icon = row.icon, text = row.text })
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, REACH),
		Position = UDim2.fromOffset(0, -REACH),
		BackgroundColor3 = Color3.fromHex("14161A"),
		BorderSizePixel = 0,
		ZIndex = Theme.layers.panel,
		ref = mark.backdrop,
		[React.Change.AbsoluteSize] = function(rbx: Frame)
			setSize(uiSize(rbx))
		end,
	}, {
		-- The map and everything drawn on it: one picture behind the chrome.
		Map = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 1,
			ref = PICTURE,
		}, {
			Frame = e("Frame", {
				Size = UDim2.fromOffset(span.X * scale + 6, span.Y * scale + 6),
				Position = UDim2.fromOffset(ox - 3, oy - 3),
				BackgroundColor3 = Theme.colors.strokeWarm,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
			Picture = e("Frame", {
				Size = UDim2.fromOffset(span.X * scale, span.Y * scale),
				Position = UDim2.fromOffset(ox, oy),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				ZIndex = 2,
			}, {
				Scaled = e("Frame", { Size = UDim2.fromOffset(span.X, span.Y), BackgroundTransparency = 1 }, {
					Scale = e("UIScale", { Scale = scale }),
					Ground = e(MapCanvas.Ground, { map = map }),
					Features = e(MapCanvas.Features, {
						bounds = map.bounds,
						outposts = features.outposts,
						trees = features.trees,
						rocks = features.rocks,
						version = features.version,
					}),
				}),
			}),
			Marks = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, marks),
			Others = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 4,
				ref = othersRef,
			}),
			You = e("Frame", {
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				ZIndex = 5,
				ref = youRef,
			}, arrow(1.45)),
		}),
		-- The chrome keeps to the safe area, over the map.
		Chrome = e("Frame", {
			Size = UDim2.new(1, 0, 1, -REACH),
			Position = UDim2.fromOffset(0, REACH),
			BackgroundTransparency = 1,
			ZIndex = 6,
		}, {
			Title = e("Frame", {
				Size = UDim2.fromOffset(410, 62),
				Position = UDim2.fromOffset(16, 16),
				BackgroundColor3 = Theme.colors.panel,
				BackgroundTransparency = Theme.colors.panelTransparency,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = Theme.strokeThickness }),
				Name = e(Label, {
					text = string.upper(map.name),
					style = "section",
					tone = "highlight",
					position = UDim2.fromOffset(14, 6),
					size = UDim2.new(1, -28, 0, 26),
				}),
				Hint = e(Label, {
					text = "Haven Square is safe. The Trailhead leads into the Fog.",
					style = "caption",
					tone = "muted",
					position = UDim2.fromOffset(14, 34),
					size = UDim2.new(1, -28, 0, 20),
				}),
			}),
			Legend = e("Frame", {
				Size = UDim2.fromOffset(LEGEND_WIDTH, #legend * 28 + 14),
				Position = UDim2.new(0, 16, 1, -16),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Theme.colors.panel,
				BackgroundTransparency = 0.12,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = 1.5 }),
				Rows = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, legendRows),
			}),
			Close = e(Button, {
				text = "Close",
				glyph = "close",
				variant = "secondary",
				size = UDim2.fromOffset(48, 48),
				position = UDim2.new(1, -16, 0, 16),
				anchorPoint = Vector2.new(1, 0),
				onActivated = Actions.toggleAreaMap,
			}),
			Key = not Content.Tuning.features.fogRuns
				and e(KeyChip, { text = "M", position = UDim2.new(1, -72, 0, 28), anchorPoint = Vector2.new(1, 0) }),
		}),
	})
end

return AreaMap
