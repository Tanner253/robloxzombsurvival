--!strict
--[[
	Throwing: grenades and molotovs, client side (2.0 batch 5). The server decides every throw
	and every hit (Services/Throwables); this aims, previews and draws.

	- Aim: press the attack input (LMB, or the weapon circle on touch) with a throwable in hand
	  and an arc preview runs from the hand to where it will land, with a ring the size of its
	  blast or fire. On PC it lands under the mouse; on touch, on the nearest Hollow ahead (or
	  ahead of the survivor), so a tap still throws well. Release to throw.
	- The arc is Domain/Throw's, the one the server flies, checked against walls the same way.
	- Effects: the model leaves the hand on the throw clip's release frame and flies the arc; a
	  grenade sits where it lands until its fuse, then bursts (flash, fireball, smoke, dust and
	  a shake by distance); a molotov breaks and the ground burns for its seconds. A molotov in
	  the hand burns at its rag.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Content = require(ReplicatedStorage.Shared.Data)
local Throw = require(ReplicatedStorage.Shared.Domain.Throw)
local Clips = require("../Clips")
local Net = require("../Net")
local Sfx = require("../Sfx")
local State = require("../State")
local Camera = require("./Camera")
local FogRun = require("./FogRun")
local HollowView = require("./HollowView")

local Throwing = {}

local player = Players.LocalPlayer
local Items: any = Content.Items
local HAND_HEIGHT = 1.8 -- as the server's
local SEGMENTS = 10
local DOTS = 18
local TOUCH_DEFAULT_STUDS = 18
local ARC_COLOR = Color3.fromHex("FFE3A3")
local FIRE_COLOR = Color3.fromHex("FF8A3D")

local aiming = false
local preview: Folder? = nil
local dots: { BasePart } = {}
local ring: BasePart? = nil
local landing: Vector3? = nil

-- The throwable in the active hand and its stats, or nil.
local function inHand(): (string?, any)
	local hands = State.get("hands")
	if type(hands) ~= "table" then
		return nil, nil
	end
	local slot = hands.slots and hands.slots[hands.active]
	local itemId = slot and slot.itemId
	local def = itemId and Items[itemId]
	if def and def.throw then
		return itemId, def.throw
	end
	return nil, nil
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function worldParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	if preview then
		table.insert(skip, preview)
	end
	params.FilterDescendantsInstances = skip
	params.RespectCanCollide = true
	return params
end

local function point(v: Vector3): Throw.Point
	return Throw.point(v.X, v.Y, v.Z)
end

local function vector(p: Throw.Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

-- Where the player aims: the ground under the mouse (PC), else the nearest Hollow ahead or a
-- spot ahead of the survivor (touch).
local function aimPoint(root: BasePart): Vector3
	local camera = workspace.CurrentCamera
	if camera and not State.ui().touch then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, worldParams())
		if hit then
			return hit.Position
		end
	end
	local look = root.CFrame.LookVector
	local best: Vector3? = nil
	local bestScore = math.huge
	for _, target in HollowView.targets() do
		local offset = Vector3.new(target.position.X - root.Position.X, 0, target.position.Z - root.Position.Z)
		local distance = offset.Magnitude
		if distance > 1 and distance < 45 and offset.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) > 0.35 then
			if distance < bestScore then
				best, bestScore = target.position, distance
			end
		end
	end
	return best or (root.Position + Vector3.new(look.X, 0, look.Z).Unit * TOUCH_DEFAULT_STUDS)
end

-- The arc the server will fly for this aim, stopped where it first meets the world.
local function arcFor(root: BasePart, stats: any): ({ Vector3 }, Vector3)
	local params = worldParams()
	local origin = root.Position + Vector3.new(0, HAND_HEIGHT, 0)
	local look = root.CFrame.LookVector
	local target = Throw.landing(point(origin), point(aimPoint(root)), stats, math.atan2(look.X, look.Z))
	local floor = workspace:Raycast(Vector3.new(target.x, origin.Y + 30, target.z), Vector3.new(0, -120, 0), params)
	target.y = if floor then floor.Position.Y else origin.Y - 3
	local list: { Vector3 } = {}
	local samples = Throw.points(point(origin), target, stats, SEGMENTS)
	for i, sample in samples do
		local at = vector(sample)
		if i > 1 then
			local from = list[#list]
			local hit = workspace:Raycast(from, at - from, params)
			if hit then
				table.insert(list, hit.Position)
				return list, hit.Position
			end
		end
		table.insert(list, at)
	end
	return list, vector(target)
end

local function clearPreview()
	if preview then
		preview:Destroy()
	end
	preview, ring, landing = nil, nil, nil
	table.clear(dots)
end

local function buildPreview(stats: any)
	clearPreview()
	local folder = Instance.new("Folder")
	folder.Name = "ThrowPreview"
	for i = 1, DOTS do
		local dot = Instance.new("Part")
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.one * 0.32
		dot.Material = Enum.Material.Neon
		dot.Color = ARC_COLOR
		dot.Transparency = 0.15 + 0.5 * (i / DOTS)
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.CastShadow = false
		dot.Parent = folder
		table.insert(dots, dot)
	end
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.08, stats.radius * 2, stats.radius * 2)
	disc.Material = Enum.Material.Neon
	disc.Color = if stats.kind == "fire" then FIRE_COLOR else ARC_COLOR
	disc.Transparency = 0.78
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Parent = folder
	ring = disc
	folder.Parent = workspace
	preview = folder
end

-- Places the dots evenly along the arc's length, and the ring on the landing.
local function drawPreview(path: { Vector3 }, land: Vector3)
	local lengths: { number } = { 0 }
	for i = 2, #path do
		lengths[i] = lengths[i - 1] + (path[i] - path[i - 1]).Magnitude
	end
	local total = lengths[#lengths]
	local segment = 2
	for i, dot in dots do
		local want = total * (i - 0.5) / #dots
		while segment < #path and lengths[segment] < want do
			segment += 1
		end
		local a, b = path[segment - 1], path[segment]
		local span = math.max(lengths[segment] - lengths[segment - 1], 1e-3)
		dot.Position = a:Lerp(b, math.clamp((want - lengths[segment - 1]) / span, 0, 1))
	end
	if ring then
		ring.CFrame = CFrame.new(land + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end
	landing = land
end

function Throwing.begin()
	local itemId, stats = inHand()
	if itemId == nil or not FogRun.active() then
		return
	end
	aiming = true
	buildPreview(stats)
	Throwing.step()
end

-- Each frame while aiming: follow the aim; drop the preview if the throwable left the hand.
function Throwing.step()
	if not aiming then
		return
	end
	local itemId, stats = inHand()
	local root = rootPart()
	if itemId == nil or root == nil or not FogRun.active() or State.ui().panel ~= "none" then
		aiming = false
		clearPreview()
		return
	end
	local path, land = arcFor(root, stats)
	drawPreview(path, land)
	-- Face the throw, as a gun faces its aim.
	local flat = Vector3.new(land.X, root.Position.Y, land.Z)
	if (flat - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

function Throwing.release()
	if not aiming then
		return
	end
	Throwing.step()
	aiming = false
	local land = landing
	clearPreview()
	if land == nil or inHand() == nil then
		return
	end
	Clips.play(player.Character, "throw")
	task.delay(math.max(0, Clips.hit("throw") - 0.12), Sfx.play, "meleeSwing", nil)
	Net.fire("CombatThrow", land.X, land.Y, land.Z)
end

function Throwing.aiming(): boolean
	return aiming
end

-- Effects ----------------------------------------------------------------------------------------

local function holder(at: Vector3, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size or Vector3.one
	part.Position = at
	part.Parent = workspace
	return part
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
	return particles
end

-- The rag of a molotov burning: a small flame and its light at the neck. The bottle's mesh
-- stands along its own +Y (Art.uploaded), so the neck is the top of the mesh in its own space.
local function lightRag(model: Model): Attachment?
	local body = model:FindFirstChildWhichIsA("BasePart", true)
	if body == nil then
		return nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Rag"
	attachment.Parent = body
	attachment.Position = Vector3.new(0, body.Size.Y / 2, 0)
	emitter(attachment, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new(Color3.fromHex("FFD27A"), FIRE_COLOR),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(1, 2),
		Rate = 28,
		SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 4, 0),
	})
	local light = Instance.new("PointLight")
	light.Color = FIRE_COLOR
	light.Range = 8
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = attachment
	return attachment
end

local function flightModel(userId: number, itemId: string, from: Vector3): Model?
	local other = Players:GetPlayerByUserId(userId)
	local gear = other and other.Character and other.Character:FindFirstChild("Gear")
	local hand = gear and gear:FindFirstChild("hand")
	if hand == nil or not hand:IsA("Model") or hand:GetAttribute("ItemId") ~= itemId then
		return nil
	end
	local copy = hand:Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") or descendant:IsA("Attachment") then
			if descendant.Name ~= "Rag" then
				descendant:Destroy()
			end
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end
	copy.Name = "Thrown"
	copy:PivotTo(CFrame.new(from))
	copy.Parent = workspace
	return copy
end

local function onThrow(payload: any)
	local stats = Items[payload.itemId] and Items[payload.itemId].throw
	if stats == nil then
		return
	end
	local from: Vector3, to: Vector3 = payload.from, payload.to
	if payload.userId ~= player.UserId then
		local other = Players:GetPlayerByUserId(payload.userId)
		-- The swing came with the server's "swing" effect; the whoosh is the release.
		Sfx.play("meleeSwing", if other and other.Character then other.Character:GetPivot().Position else nil)
	end
	local model = flightModel(payload.userId, payload.itemId, from)
	if model == nil then
		return
	end
	if stats.kind == "fire" and model:FindFirstChild("Rag", true) == nil then
		lightRag(model)
	end
	local flight: number = payload.flight
	local started = os.clock()
	local spin = CFrame.Angles(math.rad(-540), 0, 0)
	local stopAt = payload.goesOff or flight
	task.spawn(function()
		while model.Parent do
			local t = os.clock() - started
			if t >= flight then
				model:PivotTo(CFrame.new(to + Vector3.new(0, 0.25, 0)))
				break
			end
			local at = Throw.at(point(from), point(to), stats, flight, t)
			model:PivotTo(CFrame.new(vector(at)) * CFrame.new():Lerp(spin, t / flight))
			task.wait()
		end
	end)
	-- A molotov breaks on landing; a grenade waits on the ground for its fuse.
	Debris:AddItem(model, if stats.kind == "fire" then flight + 0.05 else stopAt + 0.05)
end

local function shakeFrom(at: Vector3, strength: number, reach: number)
	local root = rootPart()
	if root == nil then
		return
	end
	local distance = (root.Position - at).Magnitude
	if distance < reach then
		Camera.shake(strength * (1 - distance / reach))
	end
end

local function onBlast(payload: any)
	local at: Vector3 = payload.at
	local radius: number = payload.radius
	local spot = holder(at + Vector3.new(0, 1, 0))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("FFB547")
	light.Range = radius * 3
	light.Brightness = 8
	light.Shadows = false
	light.Parent = spot
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	local fireball = emitter(spot, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new(Color3.fromHex("FFF1C2"), Color3.fromHex("FF6A1F")),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.35),
			NumberSequenceKeypoint.new(1, radius * 0.6),
		}),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(radius * 0.6, radius * 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
	})
	fireball:Emit(26)
	local smoke = emitter(spot, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(70, 64, 58), Color3.fromRGB(120, 114, 104)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.3),
			NumberSequenceKeypoint.new(1, radius * 0.9),
		}),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.6, 2.6),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(180, 40),
		Acceleration = Vector3.new(0, 3, 0),
		Rate = 0,
	})
	smoke:Emit(18)
	local dust = emitter(holder(at), {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(140, 130, 116)),
		Size = NumberSequence.new(0.6, 2.2),
		Transparency = NumberSequence.new(0.35, 1),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(radius, radius * 1.6),
		SpreadAngle = Vector2.new(90, 8),
		EmissionDirection = Enum.NormalId.Top,
		Rate = 0,
	})
	dust:Emit(30)
	Debris:AddItem(spot, 3)
	Debris:AddItem(dust.Parent :: Instance, 2)
	Sfx.play("grenadeBlast", at)
	shakeFrom(at, 0.6, radius * 4)
end

local function onFire(payload: any)
	local at: Vector3 = payload.at
	local radius: number = payload.radius
	local seconds: number = payload.seconds
	Sfx.play("glassBreak", at)
	local area = holder(at + Vector3.new(0, 0.2, 0), Vector3.new(radius * 1.8, 0.2, radius * 1.8))
	local flames = emitter(area, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new(Color3.fromHex("FFD27A"), FIRE_COLOR),
		LightEmission = 0.9,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = radius * 14,
	})
	local smoke = emitter(area, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(46, 40, 36)),
		Size = NumberSequence.new(1.2, 3.2),
		Transparency = NumberSequence.new(0.45, 1),
		Lifetime = NumberRange.new(1.4, 2.2),
		Speed = NumberRange.new(3, 5),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = radius * 1.5,
	})
	local light = Instance.new("PointLight")
	light.Color = FIRE_COLOR
	light.Range = radius * 2.6
	light.Brightness = 2.4
	light.Shadows = false
	light.Parent = area
	local loop = Sfx.loop("fireLoop", area)
	if loop then
		loop:Play()
	end
	-- The flames die down at the end, then the smoke clears.
	task.delay(math.max(0, seconds - 0.8), function()
		flames.Rate = radius * 4
		TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	end)
	task.delay(seconds, function()
		flames.Enabled = false
		smoke.Enabled = false
		if loop then
			loop:Stop()
		end
	end)
	Debris:AddItem(area, seconds + 2.5)
	shakeFrom(at, 0.18, radius * 3)
end

-- A molotov in anyone's hand burns at its rag.
local function watchRags()
	while true do
		for _, other in Players:GetPlayers() do
			local gear = other.Character and other.Character:FindFirstChild("Gear")
			local hand = gear and gear:FindFirstChild("hand")
			if hand and hand:IsA("Model") and hand:GetAttribute("ItemId") == "item.molotov" then
				if hand:FindFirstChild("Rag", true) == nil then
					lightRag(hand)
				end
			end
		end
		task.wait(0.5)
	end
end

function Throwing.start()
	if not Content.Tuning.features.fogRuns then
		return
	end
	State.fx:Connect(function(kind: any, payload: any)
		if kind == "throw" then
			onThrow(payload)
		elseif kind == "blast" then
			onBlast(payload)
		elseif kind == "fire" then
			onFire(payload)
		end
	end)
	task.spawn(watchRags)
end

return Throwing
