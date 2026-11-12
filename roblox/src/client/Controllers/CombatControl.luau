--!strict
--[[
	CombatControl: fighting on a Fog Run, client side (checklist 13.3-13.9, 13.11, 1.9).
	The server decides every hit (Services/Combat); this sends intents and draws them.

	Input (only on a run, never over UI):
	- LMB (or the big weapon circle on touch): melee swings (hold past the heavy
	  threshold for a heavy swing), guns fire at their cadence while held, a bow draws
	  while held and looses on release.
	- R reloads, C rolls (dodge, along your movement or your aim), Q toggles AUTO
	  fighting; 1, 2, F and H stay with Input/Actions.
	- Aim: the mouse on the ground on PC; on touch, the nearest Hollow ahead.
	- Soft lock: the Hollow nearest the aim inside a cone; its name and HP show in
	  the top-centre target bar ("target" in State).

	Feedback: custom swing, aim, recoil, reload, draw, roll, hit-react and collapse
	animations (keyframes built here, never Roblox defaults); muzzle flash and light,
	tracer, shell eject, impact dust; real sounds per weapon; screen shake.

	Moving while fighting (Controllers/Stance): every attack engages the stance toward its aim,
	so the chest turns to the target while the legs run on; swings and flinches play above the
	waist only. The trigger is Domain/Trigger: a hold belongs to what was in hand at its press,
	so one press throws one grenade, and a gun that comes into the hand mid-hold waits for a
	new press.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local HoldRules = require(ReplicatedStorage.Shared.Domain.HoldRules)
local Clips = require("../Clips")
local Net = require("../Net")
local Sfx = require("../Sfx")
local State = require("../State")
local Camera = require("./Camera")
local FogRun = require("./FogRun")
local HollowView = require("./HollowView")
local Stance = require("./Stance")
local Throwing = require("./Throwing")
local Trigger = require(ReplicatedStorage.Shared.Domain.Trigger)

local CombatControl = {}

local player = Players.LocalPlayer
local Items: any = Content.Items
local tuning = Content.Tuning
local LOCK_DEGREES = 32
local LOCK_RANGE = 46
local HEAVY_AFTER = tuning.melee.heavyWindupSeconds or 0.45

-- Animations -----------------------------------------------------------------------------------------

-- Every clip comes from Data/Holds by the held item's class (client/Clips plays them): the
-- class's swing and heavy, the gun's aim, kick and reload, the bow's draw; and the body's
-- roll, hit-react and collapse.
local function play(character: Model?, name: string?, speed: number?, mask: "upper"?): AnimationTrack?
	if name == nil then
		return nil
	end
	local track = Clips.play(character, name, speed, nil, nil, mask)
	if track and name == "collapse" then
		-- The fall holds its last pose rather than springing back up.
		local t = track
		task.delay(math.max(0, t.Length / (speed or 1) - 0.08), function()
			if t.IsPlaying then
				t:AdjustSpeed(0)
			end
		end)
	end
	return track
end

local function stop(character: Model?, name: string?)
	if name then
		Clips.stop(character, name)
	end
end

-- Weapon state ---------------------------------------------------------------------------------------

local function activeItem(): (string?, any)
	local hands = State.get("hands")
	if type(hands) ~= "table" then
		return nil, nil
	end
	local slot = hands.slots and hands.slots[hands.active]
	local itemId = slot and slot.itemId
	return itemId, if itemId then Items[itemId] else nil
end

-- The clip the item in hand plays for a use (Data/Holds by its class): a long gun shoulders,
-- a pistol goes out in both hands, an axe chops, the stake thrusts.
local function clipFor(use: string): string?
	local itemId, def = activeItem()
	return HoldRules.clip(HoldRules.classOf(itemId, def), use)
end

-- The same for another survivor's item (an effect carries its id).
local function clipOf(itemId: string?, use: string): string?
	return HoldRules.clip(HoldRules.classOf(itemId, if itemId then Items[itemId] else nil), use)
end

local function weaponKind(): "melee" | "gun" | "bow" | "throw"
	local _, def = activeItem()
	if def and def.throw then
		return "throw"
	end
	local weapon = def and def.weapon
	if weapon and weapon.kind == "ranged" then
		return if weapon.bow then "bow" else "gun"
	end
	return "melee"
end

-- Aim --------------------------------------------------------------------------------------------------

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Scripted checks (Diagnostics "aimAt"): a fixed world point stands in for the mouse.
local devAimPoint: Vector3? = nil
function CombatControl.devAim(point: Vector3?)
	devAimPoint = point
end

-- The ground point under the mouse (PC), at the survivor's height.
local function mouseGround(root: BasePart): Vector3?
	if devAimPoint then
		return Vector3.new(devAimPoint.X, root.Position.Y, devAimPoint.Z)
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local planeY = root.Position.Y
	if math.abs(ray.Direction.Y) < 1e-3 then
		return nil
	end
	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function yawTo(from: Vector3, to: Vector3): number
	return math.atan2(to.X - from.X, to.Z - from.Z)
end

local function angleDiff(a: number, b: number): number
	return (b - a + math.pi) % (2 * math.pi) - math.pi
end

-- The aim heading and the soft-locked Hollow (if any).
local function aim(): (number?, HollowView.Target?)
	local root = rootPart()
	if root == nil then
		return nil, nil
	end
	local targets = HollowView.targets()
	local yaw: number? = nil
	if not State.ui().touch or devAimPoint then
		local ground = mouseGround(root)
		if ground then
			yaw = yawTo(root.Position, ground)
		end
	end
	if yaw == nil then
		local look = root.CFrame.LookVector
		yaw = math.atan2(look.X, look.Z)
	end
	local best: HollowView.Target? = nil
	local bestScore = math.huge
	for _, target in targets do
		local offset = Vector3.new(target.position.X - root.Position.X, 0, target.position.Z - root.Position.Z)
		local distance = offset.Magnitude
		if distance <= LOCK_RANGE then
			local off = math.abs(angleDiff(yaw :: number, math.atan2(offset.X, offset.Z)))
			-- Touch has no mouse: the nearest one ahead wins, in a wider cone.
			local cone = if State.ui().touch then math.rad(70) else math.rad(LOCK_DEGREES)
			if off <= cone then
				local score = distance + off * 20
				if score < bestScore then
					best, bestScore = target, score
				end
			end
		end
	end
	if best then
		yaw = yawTo(root.Position, best.position)
	end
	return yaw, best
end

-- An attack toward `yaw`: the chest turns to it, the legs keep the movement (Stance).
local function face(yaw: number)
	Stance.engage(yaw)
end

-- Effects -------------------------------------------------------------------------------------------------

-- Where a shot leaves the gun: ahead of the fist by the barrel's length past the grip, along
-- the shot (the chest turns to it while the legs may face elsewhere).
local function muzzleOf(character: Model, itemId: string?, yaw: number?): Vector3
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hand then
		local held = if itemId then Art.held[itemId] else nil
		local ahead = if held then math.max(1.4, held.length * (1 - held.grip)) else 1.4
		local along = if yaw
			then Vector3.new(math.sin(yaw), 0, math.cos(yaw))
			elseif root then root.CFrame.LookVector
			else Vector3.zero
		return hand.Position + along * ahead
	end
	return if root then root.Position + Vector3.new(0, 1.2, 0) else Vector3.zero
end

local function flash(at: Vector3, color: Color3, size: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = at
	holder.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14 * size
	light.Brightness = 4
	light.Shadows = false
	light.Parent = holder
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(Color3.fromHex("FFE3A3"), color)
	burst.LightEmission = 1
	burst.Size = NumberSequence.new(0.8 * size, 0)
	burst.Lifetime = NumberRange.new(0.05, 0.12)
	burst.Speed = NumberRange.new(8, 16)
	burst.SpreadAngle = Vector2.new(25, 25)
	burst.Rate = 0
	burst.Parent = holder
	burst:Emit(14)
	TweenService:Create(light, TweenInfo.new(0.09), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 0.4)
end

local function tracer(from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.25
	beam.Size = Vector3.new(0.08, 0.08, length)
	beam.CFrame = CFrame.lookAt((from + to) / 2, to)
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(0.12), { Transparency = 1, Size = Vector3.new(0.02, 0.02, length) }):Play()
	Debris:AddItem(beam, 0.2)
end

local function impactDust(at: Vector3)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = at
	holder.Parent = workspace
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(140, 130, 116))
	dust.Size = NumberSequence.new(0.4, 1.4)
	dust.Transparency = NumberSequence.new(0.4, 1)
	dust.Lifetime = NumberRange.new(0.3, 0.6)
	dust.Speed = NumberRange.new(3, 6)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.Rate = 0
	dust.Parent = holder
	dust:Emit(8)
	Debris:AddItem(holder, 1)
end

local function shellEject(character: Model)
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	if hand == nil then
		return
	end
	local shell = Instance.new("Part")
	shell.Size = Vector3.new(0.12, 0.12, 0.3)
	shell.Color = Color3.fromRGB(176, 140, 72)
	shell.Material = Enum.Material.Metal
	shell.CanCollide = true
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CFrame = hand.CFrame * CFrame.new(0.4, 0.3, 0)
	shell.Parent = workspace
	shell.AssemblyLinearVelocity = hand.CFrame.RightVector * 8 + Vector3.new(0, 10, 0)
	shell.AssemblyAngularVelocity = Vector3.new(math.random() * 20, math.random() * 20, 0)
	Debris:AddItem(shell, 2)
end

-- A visible flare round arcing out, burning orange.
local function flareRound(from: Vector3, yaw: number, speed: number)
	local round = Instance.new("Part")
	round.Shape = Enum.PartType.Ball
	round.Size = Vector3.new(0.5, 0.5, 0.5)
	round.Material = Enum.Material.Neon
	round.Color = Color3.fromHex("FF8A3D")
	round.Anchored = true
	round.CanCollide = false
	round.CanQuery = false
	round.Position = from
	round.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("FF8A3D")
	light.Range = 12
	light.Brightness = 2
	light.Parent = round
	local dir = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
	local travel = 0.5
	TweenService
		:Create(round, TweenInfo.new(travel, Enum.EasingStyle.Linear), { Position = from + dir * speed * travel })
		:Play()
	Debris:AddItem(round, travel + 0.05)
end

-- One shot sound per gun class (ARSENAL §8.3), the .50 its own; the flare is a launch.
local CLASS_SOUNDS: { [string]: string } = {
	pistol = "pistolShot",
	smg = "pistolShot",
	rifle = "rifleShot",
	shotgun = "shotgunShot",
}

local function shotSound(firearm: any): string
	if firearm == nil then
		return "pistolShot"
	elseif firearm.flare then
		return "flareLaunch"
	elseif (firearm.recoilScale or 1) >= 2 then
		return "heavyShot"
	end
	return CLASS_SOUNDS[firearm.animClass] or "pistolShot"
end

local function characterOf(userId: number): Model?
	local other = Players:GetPlayerByUserId(userId)
	return if other then other.Character else nil
end

-- Another survivor firing: their stance comes up with the first shot and drops a moment
-- after the last (yours follows your trigger).
local lastShotAt: { [Model]: number } = {}
local function raise(character: Model, itemId: string?)
	local aimName = clipOf(itemId, "aim")
	if aimName == nil then
		return
	end
	if not Clips.playing(character, aimName) then
		play(character, aimName)
	end
	local at = os.clock()
	lastShotAt[character] = at
	task.delay(0.9, function()
		if lastShotAt[character] == at then
			lastShotAt[character] = nil
			stop(character, aimName)
		end
	end)
end

local function onShot(payload: any)
	local character = characterOf(payload.userId)
	if character == nil then
		return
	end
	local def = Items[payload.itemId]
	local weapon = def and def.weapon
	local yaw: number = payload.yaw
	local from = muzzleOf(character, payload.itemId, yaw)
	if payload.userId ~= player.UserId then
		Stance.remoteAim(character, yaw)
	end
	if weapon and weapon.bow then
		Sfx.play("bowRelease", from)
		stop(character, clipOf(payload.itemId, "aim"))
		tracer(from, from + Vector3.new(math.sin(yaw), 0, math.cos(yaw)) * 40, Color3.fromRGB(200, 190, 170))
		return
	end
	if payload.userId ~= player.UserId then
		raise(character, payload.itemId)
	end
	play(character, clipOf(payload.itemId, "recoil"))
	local firearm = weapon and weapon.firearm
	local flare = firearm ~= nil and firearm.flare ~= nil
	-- The kick against a pistol's (FirearmStats.recoilScale): a wider flash, a harder shake.
	local kick: number = if firearm then firearm.recoilScale or 1 else 1
	flash(from, if flare then Color3.fromHex("FF8A3D") else Color3.fromHex("FFB547"), math.clamp(kick, 1, 1.8))
	Sfx.play(shotSound(firearm), from)
	if flare then
		flareRound(from, yaw, 90)
		return
	end
	shellEject(character)
	local range = if weapon then weapon.range else 60
	local pellets = if firearm and firearm.pellets then math.min(firearm.pellets, 6) else 1
	local spread = math.rad(if firearm then firearm.spreadDegrees else 4)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true -- as the server's rounds: they pass under tree crowns
	for pellet = 1, pellets do
		local offset = if pellets > 1 then (pellet / pellets - 0.5) * spread else 0
		local dir = Vector3.new(math.sin(yaw + offset), 0, math.cos(yaw + offset))
		local hit = workspace:Raycast(from, dir * range, params)
		local to = if hit then hit.Position else from + dir * range
		tracer(from, to, Color3.fromHex("FFE3A3"))
		if hit then
			impactDust(hit.Position)
		end
	end
	if payload.userId == player.UserId then
		Camera.shake(math.min(0.18 * kick * kick, 0.6))
	end
end

-- The swing's whoosh as the blade comes through, just ahead of its hit frame.
local function whoosh(name: string?, at: Vector3?)
	local delay = math.max(0, (if name then Clips.hit(name) else 0) - 0.12)
	task.delay(delay, Sfx.play, "meleeSwing", at)
end

local function onSwing(payload: any)
	if type(payload) ~= "table" or type(payload.userId) ~= "number" then
		-- Interaction's own gather swing shares the "swing" effect ({ key, model }, no
		-- survivor): it animates on input. Without this, every chop logged a script error.
		return
	end
	local character = characterOf(payload.userId)
	if character == nil or payload.userId == player.UserId then
		return -- your own swing animates on input
	end
	local name = clipOf(payload.itemId, if payload.heavy then "heavy" else "swing")
	play(character, name, nil, "upper")
	if type(payload.yaw) == "number" then
		Stance.remoteAim(character, payload.yaw)
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	whoosh(name, if root then root.Position else nil)
end

local rolling = false
local function roll(yaw: number, seconds: number)
	local root = rootPart()
	local character = player.Character
	if root == nil or character == nil or rolling then
		return
	end
	rolling = true
	Stance.pause(seconds) -- the roll owns the body
	play(character, "roll", 0.5 / math.max(seconds, 0.2))
	impactDust(root.Position - Vector3.new(0, 2.6, 0))
	local dir = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
	local distance = tuning.dodge.distanceStuds or 9
	local mover = Instance.new("LinearVelocity")
	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	if attachment then
		mover.Attachment0 = attachment
		mover.MaxForce = 1e6
		mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		mover.PrimaryTangentAxis = Vector3.xAxis
		mover.SecondaryTangentAxis = Vector3.zAxis
		mover.PlaneVelocity = Vector2.new(dir.X, dir.Z) * (distance / seconds)
		mover.Parent = root
		Debris:AddItem(mover, seconds)
	end
	task.delay(seconds, function()
		rolling = false
	end)
end

local function onDodge(payload: any)
	if payload.userId == player.UserId then
		roll(payload.yaw, payload.seconds or 0.35)
	else
		play(characterOf(payload.userId), "roll")
	end
end

-- Input --------------------------------------------------------------------------------------------------

local trigger = Trigger.new()
local pressedAt = 0
local lastShot = 0
local drawing = false
local burstLeft = 0 -- rounds still to come in a burst gun's burst (a tap fires the whole burst)

local function activeFirearm(): any
	local _, def = activeItem()
	return def and def.weapon and def.weapon.firearm
end

local function lockedId(target: HollowView.Target?): string?
	return if target then target.id else nil
end

local function updateTarget()
	if not FogRun.active() then
		if State.get("combatTarget") then
			State.set("combatTarget", false)
		end
		return
	end
	local _, target = aim()
	local current = State.get("combatTarget")
	if target == nil then
		if current then
			State.set("combatTarget", false)
		end
	elseif type(current) ~= "table" or current.id ~= target.id or current.hp ~= target.hp then
		State.set("combatTarget", { id = target.id, name = target.name, hp = target.hp })
	end
end

local function fireOnce()
	local yaw, target = aim()
	if yaw == nil then
		return
	end
	face(yaw)
	Net.fire("CombatFire", yaw, lockedId(target))
end

-- Press: the start of an attack. Release: a heavy swing or a bow's loose.
function CombatControl.press()
	if not FogRun.active() or State.ui().panel ~= "none" then
		return
	end
	local kind = weaponKind()
	if not Trigger.press(trigger, kind) then
		return -- the same press, from another input path
	end
	pressedAt = os.clock()
	local character = player.Character
	if kind == "gun" then
		play(character, clipFor("aim"))
		local firearm = activeFirearm()
		local burst = firearm and firearm.burst
		-- A burst gun takes its cooldown after the last burst before the next one starts.
		if burst and burstLeft <= 0 and os.clock() - lastShot < burst.cooldown then
			return
		end
		if burst == nil or burstLeft <= 0 then
			fireOnce()
			lastShot = os.clock()
			burstLeft = if burst then burst.count - 1 else 0
		end
	elseif kind == "throw" then
		Throwing.begin()
	elseif kind == "bow" then
		drawing = true
		play(character, clipFor("aim"))
		Sfx.play("bowDraw")
		Net.fire("CombatDraw")
	end
end

function CombatControl.release()
	local kind = weaponKind()
	local pressedKind = trigger.kind
	local done = Trigger.release(trigger, kind)
	local character = player.Character
	if done == nil then
		-- A hold that ends with something else in hand completes nothing; a gun's stance still
		-- comes down and a throw's preview clears.
		if pressedKind == "throw" then
			Throwing.cancel()
		elseif pressedKind == "gun" then
			stop(character, HoldRules.clip("long", "aim"))
			stop(character, HoldRules.clip("pistol", "aim"))
		end
		return
	end
	if kind == "melee" then
		local yaw, target = aim()
		if yaw == nil then
			return
		end
		face(yaw)
		local heavy = os.clock() - pressedAt >= HEAVY_AFTER
		local name = clipFor(if heavy then "heavy" else "swing")
		play(character, name, nil, "upper")
		whoosh(name, nil)
		Net.fire("CombatMelee", heavy, yaw, lockedId(target))
	elseif kind == "bow" and drawing then
		drawing = false
		fireOnce()
	elseif kind == "throw" then
		Throwing.release()
	elseif kind == "gun" then
		local firearm = activeFirearm()
		-- A burst still coming keeps the stance up until its last round.
		local wait = if burstLeft > 0 and firearm then burstLeft * firearm.fireInterval + 0.1 else 0
		local aimName = clipFor("aim")
		task.delay(wait, function()
			if not trigger.down then
				stop(character, aimName)
			end
		end)
	end
end

function CombatControl.reload()
	if FogRun.active() and weaponKind() == "gun" then
		Net.fire("CombatReload")
		play(player.Character, clipFor("reload") or "reload")
		Sfx.play("reload")
	end
end

function CombatControl.dodge()
	if not FogRun.active() then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local move = humanoid and humanoid.MoveDirection
	local yaw: number
	if move and move.Magnitude > 0.1 then
		yaw = math.atan2(move.X, move.Z)
	else
		yaw = aim() or 0
	end
	Net.fire("CombatDodge", yaw)
end

function CombatControl.start()
	if not Content.Tuning.features.fogRuns then
		return
	end
	State.fx:Connect(function(kind: any, payload: any)
		if kind == "shot" then
			onShot(payload)
		elseif kind == "swing" then
			onSwing(payload)
		elseif kind == "dodge" then
			onDodge(payload)
		elseif kind == "dryClick" then
			-- An empty magazine reloads itself (LDoE has no reload button): the beat is the wait.
			CombatControl.reload()
		elseif kind == "hurt" then
			play(player.Character, "hitReact", nil, "upper")
			Sfx.play("hitThud", nil, 0.8)
		elseif kind == "runDeath" then
			play(player.Character, "collapse")
		end
	end)
	-- Held guns keep firing at their cadence; the target bar follows the aim.
	local targetClock = 0
	RunService.RenderStepped:Connect(function(dt: number)
		targetClock += dt
		if targetClock > 0.1 then
			targetClock = 0
			updateTarget()
		end
		local kind = weaponKind()
		local holding = Trigger.firing(trigger, kind)
		if trigger.down and (State.ui().panel ~= "none" or not FogRun.active()) then
			Trigger.cancel(trigger)
		end
		-- The chest follows the aim while the stance holds (Stance).
		if trigger.down or Stance.engaged() then
			local yaw = aim()
			if yaw then
				if trigger.down and kind ~= "melee" then
					Stance.engage(yaw) -- aiming a gun, a bow or a throw holds the stance
				else
					Stance.aim(yaw)
				end
			end
		end
		if (holding or burstLeft > 0) and FogRun.active() and kind == "gun" then
			local firearm = activeFirearm()
			local burst = firearm and firearm.burst
			-- The server keeps the beat (Domain/Combat.shotTime); this only asks on it. A frame
			-- is 1/60 s, so the floor only stops a runaway, not a fast SMG.
			local interval = if firearm then math.max(firearm.fireInterval, 0.06) else 0.5
			if burst and burstLeft <= 0 then
				interval = burst.cooldown
			end
			if os.clock() - lastShot >= interval then
				if burstLeft > 0 then
					burstLeft -= 1
					lastShot = os.clock()
					fireOnce()
				elseif holding then
					burstLeft = if burst then burst.count - 1 else 0
					lastShot = os.clock()
					fireOnce()
				end
			end
		elseif burstLeft > 0 and kind ~= "gun" then
			burstLeft = 0
		end
		Throwing.step()
	end)
end

return CombatControl
