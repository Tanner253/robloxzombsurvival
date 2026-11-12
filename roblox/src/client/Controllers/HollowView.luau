--!strict
--[[
	HollowView: draws the Hollow on the client from the server's snapshots (HollowSync;
	checklist 13.1, 13.2, 13.9, 13.10). The server keeps each Hollow as a record with
	no body; here each one is a rig cloned from ReplicatedStorage.EO_Hollow.<enemyId>,
	interpolated between snapshots a tick behind real time, and animated by state.

	- Look: the rig's own painted skin, a cold cyan glow at the eyes and a few fog
	  wisps trailing off it (ART_DIRECTION §6).
	- Animations (Art.hollowAnimations: idle, walk, run, attack, hit, death):
	  idle and wander walk, chase runs, attack and hit-react play on their cues.
	- Cues: "!" over a Hollow that notices you, floating damage numbers (crits
	  larger), a dissolve into ash and embers on death (no blood: Mild), the
	  bloater's toxic cloud, a flare's light where it lands.
	- `HollowView.targets()` lists the living ones for aim assist and the target bar.

	A Hollow kind with no approved rig is not drawn (checklist §0); the feature stays
	flagged off until all three are in.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local TableUtil = require(ReplicatedStorage.Shared.Util.Table)
local Gait = require("./Gait")
local Net = require("../Net")
local Sfx = require("../Sfx")
local State = require("../State")
local Theme = require("../UI/theme")

local HollowView = {}

local KINDS = TableUtil.sortedKeys(Content.Enemies) -- the server's kind indices
local STATES = { "idle", "wander", "alert", "chase", "attack", "flee", "dead" }
local INTERP_DELAY = 0.22 -- seconds behind the newest snapshot (one sync step plus jitter)
local EYE_COLOR = Color3.fromHex("9FE7FF")

export type Target = { id: string, enemyId: string, name: string, position: Vector3, hp: number, alive: boolean }

type Sample = { t: number, position: Vector3, yaw: number }
type View = {
	id: string,
	enemyId: string,
	model: Model?,
	samples: { Sample },
	state: string,
	hp: number,
	alive: boolean,
	tracks: { [string]: AnimationTrack },
	playing: string?,
	diedAt: number?,
	gait: Gait.Rig?, -- wildlife: joints driven procedurally, no clips
}

local views: { [string]: View } = {}
local folder: Folder? = nil
local warnedMissing: { [string]: boolean } = {}
local serverOffset = 0 -- server time minus local clock, smoothed

local function container(): Folder
	if folder and folder.Parent then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "EO_HollowView"
	made.Parent = workspace
	folder = made
	return made
end

local function template(enemyId: string): Model?
	local kit = ReplicatedStorage:FindFirstChild("EO_Hollow")
	local found = kit and kit:FindFirstChild(enemyId)
	if found and found:IsA("Model") then
		return found
	end
	if not warnedMissing[enemyId] then
		warnedMissing[enemyId] = true
		warn(`[HollowView] no rig for {enemyId} (ReplicatedStorage.EO_Hollow)`)
	end
	return nil
end

local function animatorOf(model: Model): Animator?
	local holder: Instance? = model:FindFirstChildOfClass("Humanoid")
		or model:FindFirstChildOfClass("AnimationController")
	if holder == nil then
		local controller = Instance.new("AnimationController")
		controller.Parent = model
		holder = controller
	end
	local animator = (holder :: Instance):FindFirstChildOfClass("Animator")
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = holder
		animator = made
	end
	return animator
end

-- Cold eyes and fog wisps, added to every Hollow on spawn (not to wildlife: an animal is
-- just an animal).
local function dress(model: Model, wildlife: boolean)
	local head = if wildlife then nil else model:FindFirstChild("Head", true)
	if head and head:IsA("BasePart") then
		local glow = Instance.new("PointLight")
		glow.Color = EYE_COLOR
		glow.Range = 5
		glow.Brightness = 1.6
		glow.Shadows = false
		glow.Parent = head
	end
	local torso = if wildlife then nil else model:FindFirstChild("UpperTorso", true) or model.PrimaryPart
	if torso and torso:IsA("BasePart") then
		local wisps = Instance.new("ParticleEmitter")
		wisps.Name = "FogWisps"
		wisps.Texture = "rbxasset://textures/particles/smoke_main.dds"
		wisps.Color = ColorSequence.new(Color3.fromRGB(150, 170, 180), Color3.fromRGB(110, 128, 140))
		wisps.LightEmission = 0.1
		wisps.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.78),
			NumberSequenceKeypoint.new(1, 1),
		})
		wisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) })
		wisps.Lifetime = NumberRange.new(1.2, 2)
		wisps.Rate = 5
		wisps.Speed = NumberRange.new(0.4, 1.2)
		wisps.SpreadAngle = Vector2.new(40, 40)
		wisps.Acceleration = Vector3.new(0, 0.6, 0)
		wisps.Drag = 1
		wisps.Parent = torso
	end
	-- Only the root is pinned (PivotTo drives it); the limbs hang off Motor6Ds so the
	-- Animator can move them. Views are client-only: no collisions, no state machine.
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = part == root
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.EvaluateStateMachine = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
end

local animations: { [string]: Animation } = {}

local function animationFor(id: string): Animation
	local existing = animations[id]
	if existing then
		return existing
	end
	local made = Instance.new("Animation")
	made.AnimationId = id
	animations[id] = made
	return made
end

local function loadTracks(view: View)
	local model = view.model
	local set = Art.hollowAnimations[view.enemyId]
	if model == nil or set == nil then
		return
	end
	local animator = animatorOf(model)
	if animator == nil then
		return
	end
	for name, id in set do
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(animationFor(id))
		end)
		if ok and track then
			track.Looped = name == "idle" or name == "walk" or name == "run"
			track.Priority = if track.Looped then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action
			view.tracks[name] = track
		end
	end
end

local function playLoop(view: View, name: string)
	if view.playing == name then
		return
	end
	local track: AnimationTrack? = view.tracks[name] or view.tracks.walk
	if not track then
		return
	end
	local old = view.playing and view.tracks[view.playing]
	if old and old ~= track then
		old:Stop(0.25)
	end
	track:Play(0.25)
	view.playing = name
end

local function playOnce(view: View, name: string)
	local track = view.tracks[name]
	if track then
		track:Play(0.08)
	end
end

local function spawnView(id: string, enemyId: string): View
	local view: View = {
		id = id,
		enemyId = enemyId,
		model = nil,
		samples = {},
		state = "idle",
		hp = 100,
		alive = true,
		tracks = {},
		playing = nil,
		diedAt = nil,
		gait = nil,
	}
	local source = template(enemyId)
	if source then
		local model = source:Clone()
		model.Name = id
		local def = Content.Enemies[enemyId]
		dress(model, def ~= nil and def.wildlife ~= nil)
		model.Parent = container()
		view.model = model
		view.gait = Gait.bind(model, enemyId)
		loadTracks(view)
	end
	views[id] = view
	return view
end

-- Effects -------------------------------------------------------------------------------------------

local function anchorAt(position: Vector3, life: number): Part
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = position
	holder.Parent = container()
	Debris:AddItem(holder, life)
	return holder
end

local function billboardText(position: Vector3, text: string, color: Color3, size: number, rise: number)
	local holder = anchorAt(position, 1.4)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.StudsOffset = Vector3.new(0, 0, 0)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.fonts.header
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeColor3 = Theme.colors.shadow
	label.TextStrokeTransparency = 0.15
	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = label
	label.Parent = gui
	gui.Parent = holder
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(1, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, rise, 0) }):Play()
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local function emit(at: Vector3, color: ColorSequence, count: number, props: { [string]: any })
	local holder = anchorAt(at, 3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = props.texture or "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = color
	emitter.LightEmission = props.light or 0.4
	emitter.Size = props.size or NumberSequence.new(0.3, 0)
	emitter.Transparency = props.transparency or NumberSequence.new(0, 1)
	emitter.Lifetime = props.lifetime or NumberRange.new(0.6, 1.2)
	emitter.Speed = props.speed or NumberRange.new(2, 6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = props.acceleration or Vector3.new(0, 3, 0)
	emitter.Drag = props.drag or 2
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
end

-- A hit: the body flashes pale for a beat (a crit brighter), so a blow reads at the
-- gameplay camera even in the dark (2.0 batch 1).
local function flashHit(model: Model, crit: boolean)
	local light = Instance.new("Highlight")
	light.Adornee = model
	light.DepthMode = Enum.HighlightDepthMode.Occluded
	light.FillColor = if crit then Color3.fromHex("FFE3A3") else Color3.fromRGB(255, 255, 255)
	light.FillTransparency = if crit then 0.25 else 0.45
	light.OutlineTransparency = 1
	light.Parent = model
	TweenService:Create(light, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FillTransparency = 1,
	}):Play()
	Debris:AddItem(light, 0.2)
end

-- Death: the body crumbles into ash and drifting embers, then is gone (13.10).
local function dissolve(view: View)
	local model = view.model
	if model == nil then
		return
	end
	local _, size = model:GetBoundingBox()
	local centre = model:GetPivot().Position + Vector3.new(0, size.Y / 2, 0)
	emit(centre, ColorSequence.new(Color3.fromRGB(96, 92, 88), Color3.fromRGB(60, 58, 56)), 40, {
		texture = "rbxasset://textures/particles/smoke_main.dds",
		light = 0,
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 2.4) }),
		transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		lifetime = NumberRange.new(1, 1.8),
		speed = NumberRange.new(1, 3),
		acceleration = Vector3.new(0, 1.2, 0),
	})
	emit(centre, ColorSequence.new(Color3.fromHex("FFB547"), Color3.fromHex("FF8A3D")), 30, {
		light = 1,
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		lifetime = NumberRange.new(1, 2),
		speed = NumberRange.new(1, 4),
		acceleration = Vector3.new(0, 4, 0),
	})
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				Color = Color3.fromRGB(70, 66, 62),
			}):Play()
		elseif part:IsA("PointLight") then
			TweenService:Create(part, TweenInfo.new(0.6), { Brightness = 0 }):Play()
		elseif part:IsA("ParticleEmitter") then
			part.Enabled = false
		end
	end
	Sfx.play("hollowDeath", centre)
end

-- An animal falls (Gait), lies a moment, then fades: no ash, it was never fog-touched.
local function fade(view: View)
	local model = view.model
	if model == nil then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
			}):Play()
		end
	end
end

local function cloud(at: Vector3, radius: number, seconds: number)
	local holder = anchorAt(at + Vector3.new(0, 1.5, 0), seconds + 2)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(140, 168, 140), Color3.fromRGB(96, 120, 104))
	emitter.LightEmission = 0.15
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.4), NumberSequenceKeypoint.new(1, radius * 0.9) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(2, 3)
	emitter.Rate = 10
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(180, 30)
	emitter.Parent = holder
	task.delay(seconds, function()
		emitter.Enabled = false
	end)
	Sfx.play("bloaterBurst", at)
end

local function flareLight(at: Vector3, seconds: number)
	local holder = anchorAt(at + Vector3.new(0, 2, 0), seconds + 1)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("FF8A3D")
	light.Range = 26
	light.Brightness = 3
	light.Shadows = true
	light.Parent = holder
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromHex("FFE3A3"), Color3.fromHex("FF8A3D"))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.Lifetime = NumberRange.new(0.4, 0.9)
	sparks.Rate = 60
	sparks.Speed = NumberRange.new(3, 7)
	sparks.SpreadAngle = Vector2.new(30, 30)
	sparks.Acceleration = Vector3.new(0, -12, 0)
	sparks.Parent = holder
	task.delay(seconds, function()
		sparks.Enabled = false
		TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	end)
end

local function onCue(cue: { any })
	local kind = cue[1]
	if kind == "alert" then
		local view = views[cue[2]]
		if view and view.model then
			local _, size = view.model:GetBoundingBox()
			billboardText(
				view.model:GetPivot().Position + Vector3.new(0, size.Y + 0.6, 0),
				"!",
				Theme.colors.accentSoft,
				40,
				1.5
			)
			Sfx.play("hollowAlert", view.model:GetPivot().Position)
		end
	elseif kind == "hit" then
		local view = views[cue[2]]
		local amount, crit = cue[3], cue[4]
		if view and view.model then
			local _, size = view.model:GetBoundingBox()
			local top = view.model:GetPivot().Position + Vector3.new((math.random() - 0.5) * 1.5, size.Y, 0)
			billboardText(
				top,
				tostring(math.floor((amount :: number) + 0.5)),
				if crit then Theme.colors.accentSoft else Theme.colors.text,
				if crit then 34 else 24,
				2.2
			)
			emit(top - Vector3.new(0, size.Y * 0.4, 0), ColorSequence.new(Color3.fromRGB(110, 106, 100)), 10, {
				texture = "rbxasset://textures/particles/smoke_main.dds",
				light = 0,
				size = NumberSequence.new(0.6, 1.2),
				speed = NumberRange.new(3, 6),
			})
			if view.gait then
				Gait.cue(view.gait, "hit")
			end
			flashHit(view.model, crit == true)
			playOnce(view, "hit")
			Sfx.play("hitThud", top)
		end
	elseif kind == "attack" then
		local view = views[cue[2]]
		if view then
			if view.gait then
				Gait.cue(view.gait, "attack")
			end
			playOnce(view, "attack")
			if view.model then
				Sfx.play("hollowAttack", view.model:GetPivot().Position)
			end
		end
	elseif kind == "dead" then
		local view = views[cue[2]]
		if view and view.alive then
			view.alive = false
			view.diedAt = os.clock()
			if view.gait then
				Gait.cue(view.gait, "dead")
				task.delay(3, fade, view)
			else
				-- The fall plays out before the body crumbles, so the kill reads.
				playOnce(view, "death")
				task.delay(0.85, dissolve, view)
			end
		end
	elseif kind == "burst" then
		cloud(Vector3.new(cue[3], 0, cue[4]) + Vector3.new(0, HollowView.groundY(cue[3], cue[4]), 0), cue[5], 6)
	elseif kind == "flare" then
		flareLight(Vector3.new(cue[2], HollowView.groundY(cue[2], cue[3]), cue[3]), cue[4])
	elseif kind == "noise" then
		State.set("noise", { x = cue[2], z = cue[3], radius = cue[4], at = os.clock() })
	end
end

function HollowView.groundY(x: number, z: number): number
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local from = Vector3.new(x, (if root then root.Position.Y else 0) + 30, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { container() }
	local hit = workspace:Raycast(from, Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else from.Y - 30
end

local function onSync(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local serverNow = workspace:GetServerTimeNow()
	serverOffset = serverNow - os.clock()
	local seen: { [string]: boolean } = {}
	for _, row in payload.hollows or {} do
		local id: string = row[1]
		local enemyId = KINDS[row[2]]
		if enemyId == nil then
			continue
		end
		seen[id] = true
		local view = views[id] or spawnView(id, enemyId)
		local sample: Sample = { t = payload.t, position = Vector3.new(row[3], row[4], row[5]), yaw = row[6] }
		table.insert(view.samples, sample)
		while #view.samples > 4 do
			table.remove(view.samples, 1)
		end
		view.state = STATES[row[7]] or "idle"
		view.hp = row[8]
		if view.state == "dead" and view.alive then
			view.alive = false
			view.diedAt = os.clock()
		end
	end
	for _, cue in payload.cues or {} do
		local ok, err = pcall(onCue :: any, cue)
		if not ok then
			warn(`[HollowView] cue failed: {err}`)
		end
	end
	for id, view in views do
		if not seen[id] then
			views[id] = nil
			if view.model then
				local model = view.model
				task.delay(1.4, function()
					model:Destroy()
				end)
			end
		end
	end
end

local function step(dt: number)
	local renderAt = os.clock() + serverOffset - INTERP_DELAY
	for _, view in views do
		local model = view.model
		local samples = view.samples
		if model == nil or #samples == 0 then
			continue
		end
		local a, b = samples[1], samples[#samples]
		for index = 1, #samples - 1 do
			if samples[index].t <= renderAt and samples[index + 1].t >= renderAt then
				a, b = samples[index], samples[index + 1]
				break
			end
		end
		local span = b.t - a.t
		local alpha = if span > 0 then math.clamp((renderAt - a.t) / span, 0, 1) else 1
		local position = a.position:Lerp(b.position, alpha)
		-- Shortest way round, so a heading across +-pi never spins.
		local turn = (b.yaw - a.yaw + math.pi) % (2 * math.pi) - math.pi
		local yaw = a.yaw + turn * alpha
		-- Server yaw points along (sin, cos) on the ground; rigs face -Z at rest.
		model:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw + math.pi, 0))
		local gait = view.gait
		if gait then
			-- Wildlife: the stride follows the ground actually covered between snapshots.
			if not view.alive and gait.diedAt == nil then
				Gait.cue(gait, "dead")
			end
			local first, last = samples[1], samples[#samples]
			local window = last.t - first.t
			local flat = Vector3.new(last.position.X - first.position.X, 0, last.position.Z - first.position.Z)
			Gait.step(gait, dt, if window > 0 then flat.Magnitude / window else 0, view.state)
		elseif view.alive then
			local moving = (b.position - a.position).Magnitude > 0.05
			if view.state == "chase" or view.state == "flee" then
				playLoop(view, if moving then "run" else "idle")
			elseif view.state == "wander" or (view.state == "alert" and moving) then
				playLoop(view, if moving then "walk" else "idle")
			elseif view.state ~= "attack" then
				playLoop(view, "idle")
			end
		end
	end
end

-- Whether a living Hollow within `radius` of `position` is chasing or attacking (the
-- combat music layer).
function HollowView.hunting(position: Vector3, radius: number): boolean
	for _, view in views do
		if
			view.alive
			and view.model
			and (view.state == "chase" or view.state == "attack")
			and (view.model:GetPivot().Position - position).Magnitude <= radius
		then
			return true
		end
	end
	return false
end

-- Living Hollow near the survivor, for aim assist and the target bar.
function HollowView.targets(): { Target }
	local list: { Target } = {}
	for id, view in views do
		if view.alive and view.model then
			local def = Content.Enemies[view.enemyId]
			table.insert(
				list,
				{
					id = id,
					enemyId = view.enemyId,
					name = if def then def.name else "Hollow",
					position = view.model:GetPivot().Position,
					hp = view.hp,
					alive = true,
				} :: Target
			)
		end
	end
	return list
end

-- Living Hollow with their drawn model and AI state, for the minimap (Controllers/Radar
-- shows alerted ones and ones in sight).
function HollowView.blips(): { { id: string, model: Model, state: string } }
	local list = {}
	for id, view in views do
		if view.alive and view.model then
			table.insert(list, { id = id, model = view.model :: Model, state = view.state })
		end
	end
	return list
end

function HollowView.start()
	if not Content.Tuning.features.fogRuns then
		return
	end
	Net.on("HollowSync", onSync)
	RunService.RenderStepped:Connect(step)
	State.changed:Connect(function(key: string)
		if key == "run" and State.get("run") == false then
			for id, view in views do
				views[id] = nil
				if view.model then
					view.model:Destroy()
				end
			end
		end
	end)
end

return HollowView
