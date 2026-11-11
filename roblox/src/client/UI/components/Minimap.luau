--!strict
--[[
	Minimap: LDoE's round radar (checklist 8.11, LDOE_PARITY #6-7; rec1, rec6, rec8), one
	component for home, the Neighbourhood and every Fog Run map.

	- The background is the map's picture (Controllers/Radar: MapData drawn by
	  components/MapCanvas in the Fog map's illustrated style), built once per map. Every
	  frame (RenderStepped, after the camera) it pans under the centred arrow, turned so
	  the camera's view is up, as in LDoE; only the parts near the view are drawn.
	- The arrow turns smoothly with the survivor's facing; the N on the rim marks north.
	- Live icons, placed every frame: Hollow (alerted or in sight), containers (searched
	  ones dimmed), your stations (a teal badge when output is ready), bags (yours a red
	  X), party members, other survivors at home, Haven's people, and the exits and the
	  Trailhead, kept on the rim when off the radar.
	- Zoom: the mouse wheel over the map (the camera keeps the wheel elsewhere) or a
	  pinch on it, eased. Expand: a tap or click opens the full-screen map (at home the
	  Neighbourhood map, on a Fog Run the Fog map).
	Shared by the slice-1 HUD, the LDoE HUD and the Fog Run HUD (RunHud.RunMinimap).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Art = require(ReplicatedStorage.Shared.Art)
local MapData = require(ReplicatedStorage.Shared.Domain.MapData)
local Actions = require("../../Actions")
local Camera = require("../../Controllers/Camera")
local Radar = require("../../Controllers/Radar")
local Theme = require("../theme")
local mark = require("../mark")
local MapCanvas = require("./MapCanvas")

local e = React.createElement

local SIZE = Theme.hud.minimap
-- How far the radar reaches (studs from you to its rim), zoomed with the wheel or a pinch.
local REACH_MIN, REACH_MAX, REACH_DEFAULT = 36, 240, 62
local ZOOM_RATE = 14
local TURN_RATE = 22
local RIM_INSET = 3 -- icons stop this far inside the ring
local PIN_INSET = 15 -- rim-pinned markers sit this far in (clear of the N badge on the ring)
local BUCKET_MOVE = 20 -- studs moved before the drawn buckets are re-chosen

local HOLLOW = Color3.fromHex("D2503F")
local EXIT_GREEN = Color3.fromHex("5CC86E")
local PARTY = Color3.fromHex("4FA3E0")
local BAG_MINE = Color3.fromHex("E0503C")
local CRATE = Color3.fromRGB(214, 182, 120)
local INK = Color3.fromHex("0B0D10")

local reachTarget = REACH_DEFAULT -- kept for the session
local reach = REACH_DEFAULT
local instances = 0

export type Props = {
	position: UDim2?, -- defaults to the slice-1 HUD's spot (top right)
	anchorPoint: Vector2?,
	ring: Color3?, -- the rim's colour (a Fog Run's fog tier)
}

-- Icons ---------------------------------------------------------------------------------------------

local function corner(parent: Instance, radius: UDim?)
	local round = Instance.new("UICorner")
	round.CornerRadius = radius or UDim.new(1, 0)
	round.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	local line = Instance.new("UIStroke")
	line.Color = color
	line.Thickness = thickness
	line.Transparency = transparency or 0
	line.Parent = parent
end

local function box(parent: Instance?, size: number, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(size, size)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- One icon for a blip (a holder frame centred on the blip's spot).
local function makeIcon(blip: Radar.Blip): Frame
	local holder = Instance.new("Frame")
	holder.Name = blip.key
	holder.Size = UDim2.fromOffset(0, 0)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	local kind = blip.kind
	if kind == "hollow" then
		local dot = box(holder, 7, HOLLOW)
		corner(dot)
		stroke(dot, INK, 1, 0.2)
		holder.ZIndex = 4
	elseif kind == "container" then
		local crate = box(holder, 6, if blip.dim then Color3.fromRGB(120, 116, 108) else CRATE)
		crate.BackgroundTransparency = if blip.dim then 0.45 else 0
		corner(crate, UDim.new(0, 1))
		stroke(crate, INK, 1, if blip.dim then 0.6 else 0.2)
		holder.ZIndex = 2
	elseif kind == "station" then
		local station = box(holder, 7, Theme.colors.accentSoft)
		corner(station, UDim.new(0, 2))
		stroke(station, INK, 1, 0.15)
		if blip.ready then
			-- LDoE's teal ready badge (LDOE_PARITY #7).
			local badge = box(holder, 8, Theme.colors.badge)
			badge.Position = UDim2.new(0.5, 5, 0.5, -5)
			corner(badge)
			stroke(badge, Theme.colors.text, 1.2)
		end
		holder.ZIndex = 3
	elseif kind == "bag" then
		local color = if blip.mine then BAG_MINE else Theme.colors.textMuted
		for _, turn in { 45, -45 } do
			local arm = box(holder, 0, color)
			arm.Size = UDim2.fromOffset(if blip.mine then 11 else 8, if blip.mine then 3 else 2)
			arm.Rotation = turn
			stroke(arm, INK, 1, 0.3)
		end
		holder.ZIndex = 5
	elseif kind == "party" then
		local dot = box(holder, 8, PARTY)
		corner(dot)
		stroke(dot, Theme.colors.text, 1.5)
		holder.ZIndex = 6
	elseif kind == "survivor" then
		local dot = box(holder, 6, Theme.colors.text)
		corner(dot)
		stroke(dot, INK, 1, 0.3)
		holder.ZIndex = 5
	elseif kind == "exit" then
		local color = if blip.dim then Theme.colors.disabledStroke else EXIT_GREEN
		local ring = box(holder, 11, INK)
		ring.BackgroundTransparency = 0.45
		corner(ring)
		stroke(ring, color, 2.5)
		local core = box(holder, 4, color)
		corner(core)
		holder.ZIndex = 6
	elseif kind == "npc" or kind == "fire" then
		local back = box(holder, 15, Theme.colors.panel)
		back.BackgroundTransparency = 0.15
		corner(back)
		stroke(back, Theme.colors.strokeWarm, 1)
		local glyph = Instance.new("ImageLabel")
		glyph.Size = UDim2.fromOffset(11, 11)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.BackgroundTransparency = 1
		local name = blip.glyph or "campfire"
		glyph.Image = (Art.glyphs :: any)[name] or ""
		glyph.ImageColor3 = if kind == "fire" then Theme.colors.accentSoft else Theme.colors.highlight
		glyph:SetAttribute("Glyph", name)
		glyph.Parent = back
		holder.ZIndex = 3
	elseif kind == "noise" then
		-- A ring the size of the noise's reach, fading out (sized every frame).
		local ring = box(holder, 0, INK)
		ring.Name = "Ring"
		ring.Size = UDim2.fromScale(1, 1)
		ring.BackgroundTransparency = 1
		corner(ring)
		stroke(ring, Theme.colors.threat, 2)
		holder.ZIndex = 1
	end
	return holder
end

local function styleOf(blip: Radar.Blip): string
	return `{blip.kind}|{blip.dim == true}|{blip.mine == true}|{blip.ready == true}|{blip.glyph or ""}`
end

-- The player arrow: a notched dart filled with a fan of bars from its tip (no image, no
-- Unicode arrow, 4.17), over a darker, larger copy for its outline.
local function dart(scale: number, color: Color3, order: number): { [string]: any }
	local tip = Vector2.new(0, -8.5) * scale
	local outline = {
		Vector2.new(-6.5, 7) * scale,
		Vector2.new(0, 3) * scale,
		Vector2.new(6.5, 7) * scale,
	}
	local bars: { [string]: any } = {}
	local count = 0
	for segment = 1, 2 do
		local a, b = outline[segment], outline[segment + 1]
		for step = 0, 6 do
			local point = a:Lerp(b, step / 6)
			local span = point - tip
			count += 1
			bars[`B{count}`] = e("Frame", {
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

-- The component --------------------------------------------------------------------------------------

local function Minimap(props: Props?)
	local placement: Props = props or {}
	local current, setCurrent = React.useState(Radar.current())
	local features, setFeatures = React.useState(Radar.features())
	local canvasRef = React.useRef(nil :: Frame?)
	local scaleRef = React.useRef(nil :: UIScale?)
	local pivotRef = React.useRef(nil :: Frame?)
	local arrowRef = React.useRef(nil :: Frame?)
	local northRef = React.useRef(nil :: TextLabel?)
	local iconsRef = React.useRef(nil :: Frame?)
	local hitRef = React.useRef(nil :: GuiObject?)
	local pinchedAt = React.useRef(0)
	-- The canvas's bucket frames (re-collected when the map or its features redraw), and
	-- whether the drawn set must be re-chosen.
	local bucketsRef = React.useRef({} :: { { frame: GuiObject, key: string } })
	local bucketsDirty = React.useRef(true)
	local headingRef = React.useRef(nil :: number?)

	React.useEffect(function()
		local a = Radar.changed:Connect(function()
			setCurrent(Radar.current())
		end)
		local b = Radar.featuresChanged:Connect(function()
			setFeatures(Radar.features())
		end)
		setCurrent(Radar.current())
		setFeatures(Radar.features())
		return function()
			a:Disconnect()
			b:Disconnect()
		end
	end, {})

	-- Pinch zoom on a touch screen, when the pinch starts on the map.
	React.useEffect(function()
		local startReach = reachTarget
		local active = false
		local connection = UserInputService.TouchPinch:Connect(
			function(positions: { Vector2 }, scale: number, _velocity: number, state: Enum.UserInputState)
				local hit = hitRef.current
				if hit == nil then
					return
				end
				if state == Enum.UserInputState.Begin then
					local first = positions[1] :: Vector2?
					local inset = game:GetService("GuiService"):GetGuiInset()
					local lo, size = hit.AbsolutePosition, hit.AbsoluteSize
					local function inside(point: Vector2): boolean
						return point.X >= lo.X
							and point.X <= lo.X + size.X
							and point.Y >= lo.Y
							and point.Y <= lo.Y + size.Y
					end
					active = first ~= nil and (inside(first :: Vector2) or inside((first :: Vector2) - inset))
					startReach = reachTarget
				end
				if active then
					reachTarget = math.clamp(startReach / math.max(scale, 0.1), REACH_MIN, REACH_MAX)
					pinchedAt.current = os.clock()
				end
				if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
					active = false
				end
			end
		)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		bucketsRef.current = if canvasRef.current then MapCanvas.buckets(canvasRef.current :: Frame) else {}
		bucketsDirty.current = true
	end, { current, features } :: { any })

	-- Every frame: pan, turn, zoom, and place the icons.
	React.useEffect(function()
		if current == nil then
			return function() end
		end
		local map = (current :: Radar.Current).map
		local origin = (current :: Radar.Current).origin
		local bounds = map.bounds
		local spanX, spanZ = math.round(bounds.x1 - bounds.x0), math.round(bounds.z1 - bounds.z0)
		local lastBucketAt: Vector2? = nil
		local lastBucketReach = 0
		local icons: { [string]: { frame: Frame, style: string } } = {}
		local blipList: { Radar.Blip }? = nil
		local yaw = Camera.yaw()
		local radius = SIZE / 2 - RIM_INSET

		local function syncIcons(list: { Radar.Blip })
			local parent = iconsRef.current
			if parent == nil then
				return
			end
			local keep: { [string]: boolean } = {}
			for _, blip in list do
				keep[blip.key] = true
				local style = styleOf(blip)
				local icon = icons[blip.key]
				if icon == nil or icon.style ~= style then
					if icon then
						icon.frame:Destroy()
					end
					local frame = makeIcon(blip)
					frame.Parent = parent
					icons[blip.key] = { frame = frame, style = style }
				end
			end
			for key, icon in icons do
				if not keep[key] then
					icon.frame:Destroy()
					icons[key] = nil
				end
			end
		end

		local name = `EO_Minimap{instances}`
		instances += 1
		RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function(dt: number)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local canvas, uiScale, pivot = canvasRef.current, scaleRef.current, pivotRef.current
			if root == nil or canvas == nil or uiScale == nil or pivot == nil then
				return
			end
			local you = (root :: BasePart).Position
			local lx, lz = you.X - origin.X, you.Z - origin.Z
			-- Zoom eases to the wanted reach.
			reach += (reachTarget - reach) * MapData.ease(ZOOM_RATE, dt)
			local scale = (SIZE / 2) / reach
			uiScale.Scale = scale
			pivot.Rotation = MapData.mapRotation(yaw)
			-- A UDim's offset is a whole number, so a pan by offsets would step a stud at a
			-- time. The anchor point is a float: it pins your spot on the picture to the
			-- pivot (the radar's middle), smooth to a fraction of a pixel.
			canvas.AnchorPoint = Vector2.new((lx - bounds.x0) / spanX, (lz - bounds.z0) / spanZ)
			-- Draw only the buckets near the view.
			local here = Vector2.new(lx, lz)
			if
				bucketsDirty.current
				or lastBucketAt == nil
				or (here - lastBucketAt :: Vector2).Magnitude > BUCKET_MOVE
				or math.abs(reach - lastBucketReach) > lastBucketReach * 0.08
			then
				bucketsDirty.current = false
				lastBucketAt, lastBucketReach = here, reach
				local near = MapData.bucketsNear(lx, lz, reach + BUCKET_MOVE, MapData.BUCKET)
				for _, bucket in bucketsRef.current do
					bucket.frame.Visible = near[bucket.key] == true
				end
			end
			-- The arrow turns smoothly toward the survivor's facing.
			local look = (root :: BasePart).CFrame.LookVector
			local target = MapData.heading(look.X, look.Z, yaw)
			local was = headingRef.current
			local heading = if was == nil then target else MapData.easeAngle(was, target, MapData.ease(TURN_RATE, dt))
			headingRef.current = heading
			local arrow = arrowRef.current
			if arrow then
				arrow.Rotation = heading
			end
			local north = northRef.current
			if north then
				local nx, ny = MapData.project(0, -1, yaw, 1)
				north.Position = UDim2.fromScale(0.5 + nx * (SIZE / 2 - 1) / SIZE, 0.5 + ny * (SIZE / 2 - 1) / SIZE)
			end
			-- Icons: re-matched when Radar gathers a new list, placed every frame.
			local list = Radar.blips()
			if list ~= blipList then
				blipList = list
				syncIcons(list)
			end
			for _, blip in list do
				local icon = icons[blip.key]
				if icon == nil then
					continue
				end
				local at: Vector3? = blip.at
				local instance = blip.instance
				if instance then
					if instance:IsA("BasePart") then
						at = instance.Position
					elseif instance:IsA("Model") and instance.Parent then
						at = instance:GetPivot().Position
					end
				end
				if at == nil then
					icon.frame.Visible = false
					continue
				end
				local sx, sy = MapData.project((at :: Vector3).X - you.X, (at :: Vector3).Z - you.Z, yaw, scale)
				local visible = true
				if blip.pin then
					sx, sy = MapData.rim(sx, sy, radius - PIN_INSET)
				else
					visible = sx * sx + sy * sy <= (radius - 3) ^ 2
				end
				if visible and blip.kind == "noise" then
					-- The ring grows to the noise's reach (kept inside the rim) and fades.
					local age = os.clock() - (blip.born or 0)
					local inside = radius - math.sqrt(sx * sx + sy * sy)
					local ring = math.max(0, math.min((blip.radius or 0) * scale, inside))
					icon.frame.Size = UDim2.fromOffset(ring * 2, ring * 2)
					local line = icon.frame:FindFirstChild("Ring")
					local ringStroke = line and line:FindFirstChildOfClass("UIStroke")
					if ringStroke then
						ringStroke.Transparency = math.clamp(age / Radar.NOISE_SECONDS, 0, 1)
					end
					visible = age < Radar.NOISE_SECONDS
				end
				icon.frame.Visible = visible
				if visible then
					-- In scale (a float), not offset (whole pixels), so icons glide.
					icon.frame.Position = UDim2.fromScale(0.5 + sx / SIZE, 0.5 + sy / SIZE)
				end
			end
		end)
		return function()
			RunService:UnbindFromRenderStep(name)
			for _, icon in icons do
				icon.frame:Destroy()
			end
		end
	end, { current } :: { any })

	React.useEffect(function()
		return function()
			Camera.holdWheel(false)
		end
	end, {})

	if current == nil then
		return nil
	end
	local map = (current :: Radar.Current).map
	local span = Vector2.new(math.round(map.bounds.x1 - map.bounds.x0), math.round(map.bounds.z1 - map.bounds.z0))
	local onRun = (current :: Radar.Current).kind == "run"

	local function zoom(notches: number)
		reachTarget = MapData.zoomBy(reachTarget, notches, REACH_MIN, REACH_MAX)
	end

	return e("Frame", {
		Size = UDim2.fromOffset(SIZE, SIZE),
		Position = placement.position or UDim2.new(1, -16, 0, 80),
		AnchorPoint = placement.anchorPoint or Vector2.new(1, 0),
		BackgroundTransparency = 1,
		-- One drawing for the UI gate: its picture, icons and ring overlap on purpose.
		ref = mark.composite,
	}, {
		Clip = e("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(150, 158, 160),
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			Round = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Pivot = e("Frame", {
				Size = UDim2.fromOffset(0, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				Rotation = MapData.mapRotation(Camera.yaw()),
				ref = pivotRef,
			}, {
				Scale = e("UIScale", { Scale = (SIZE / 2) / reach, ref = scaleRef }),
				Canvas = e("Frame", {
					Size = UDim2.fromOffset(span.X, span.Y),
					BackgroundTransparency = 1,
					ref = canvasRef,
				}, {
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
			-- A soft dark rim inside the ring, as LDoE's radar has.
			Vignette = e("Frame", {
				Size = UDim2.new(1, -10, 1, -10),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 5,
			}, {
				Round = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Shade = e("UIStroke", { Color = INK, Thickness = 5, Transparency = 0.55 }),
			}),
		}),
		Icons = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
			ref = iconsRef,
		}),
		Arrow = e("Frame", {
			Size = UDim2.fromOffset(0, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 3,
			ref = arrowRef,
		}, {
			Outline = e(
				"Frame",
				{ Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 1 },
				dart(1.35, INK, 1)
			),
			Fill = e(
				"Frame",
				{ Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 2 },
				dart(1, Color3.new(1, 1, 1), 2)
			),
		}),
		-- North: a small badge riding the ring, clear of the map's icons.
		North = e("TextLabel", {
			Size = UDim2.fromOffset(15, 15),
			Position = UDim2.fromScale(0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = 0.05,
			FontFace = Theme.fonts.header,
			Text = "N",
			TextSize = 11,
			TextColor3 = Theme.colors.highlight,
			ZIndex = 6,
			ref = northRef,
		}, {
			Round = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = e("UIStroke", {
				Color = placement.ring or Theme.colors.strokeWarm,
				Thickness = 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		Ring = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, {
			Round = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = e("UIStroke", {
				Color = placement.ring or Theme.colors.strokeWarm,
				Thickness = Theme.strokeThickness,
			}),
		}),
		-- The whole map is the button: a tap opens the full map, the wheel zooms.
		Hit = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 6,
			ref = hitRef,
			[React.Event.Activated] = function()
				if os.clock() - pinchedAt.current < 0.5 then
					return -- the end of a pinch, not a tap
				end
				if onRun then
					Actions.toggleFogMap()
				else
					Actions.toggleAreaMap()
				end
			end,
			[React.Event.MouseEnter] = function()
				Camera.holdWheel(true)
			end,
			[React.Event.MouseLeave] = function()
				Camera.holdWheel(false)
			end,
			[React.Event.MouseWheelForward] = function()
				zoom(1)
			end,
			[React.Event.MouseWheelBackward] = function()
				zoom(-1)
			end,
		}),
	})
end

return Minimap
