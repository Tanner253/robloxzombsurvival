--!strict
--[[
	FogRun: the client side of a Fog Run (M1 slice 2; checklist 11-13).

	State it keeps for the screens (State sections, set here, read by UI/screens):
	- "run": the lobby's RunState (phase, Fog meter, band, exits, drops, search,
	  extraction, stamina), refreshed every second while on a run; false off a run.
	- "travel": a trip in progress (the loading screen for a Run, the Walk bar).
	- "arrival": the arrival title card; "travelBonus": the "found on the way" panel.
	- "loot": the open container, pile or bag (the inventory's right pane, #45).
	- "death": the death screen; "result": the results card (also from "homecoming").
	- "hands": the two weapon slots with magazines (durability on the weapon circle).
	- "hurtAt": the last hit (red vignette and direction).

	The world it dresses on the client:
	- per fog tier, the fog thickens as the lobby's meter rises (12.3) and lifts again
	  at home;
	- the roof of the building you stand in lifts away (2.3);
	- searched containers open their lids and doors; unstocked ones stand open;
	- tall map foliage fades when it hides you.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local Net = require("../Net")
local Sfx = require("../Sfx")
local State = require("../State")
local Camera = require("./Camera")
local HollowView = require("./HollowView")
local TeleportScreen = require("./TeleportScreen")

local FogRun = {}

local player = Players.LocalPlayer
local STALE_SECONDS = 3
local updateCombatMusic: (onRun: boolean, dt: number) -> ()
local CONTAINER_TAG = "EO_RunContainer"
local EXIT_TAG = "EO_RunExit"
local CLOSED_EXIT = Color3.fromRGB(92, 96, 100)
local CANOPY_TAG = "EO_Canopy"
local ROOF_TAG = "EO_Roof"

-- Fog by tier (Light, Dense, Black): density and haze at the meter's start and at its end.
type Look = { density: { number }, haze: { number }, offset: number, saturation: number, contrast: number }
local LOOKS: { [number]: Look } = {
	{ density = { 0.36, 0.5 }, haze = { 1.8, 2.6 }, offset = 0.18, saturation = -0.16, contrast = 0.1 },
	{ density = { 0.46, 0.6 }, haze = { 2.3, 3.2 }, offset = 0.14, saturation = -0.24, contrast = 0.12 },
	{ density = { 0.56, 0.7 }, haze = { 2.8, 3.8 }, offset = 0.1, saturation = -0.32, contrast = 0.16 },
}

local lastRunAt = 0
local homeLook: { [string]: any }? = nil

function FogRun.active(): boolean
	local run = State.get("run")
	return type(run) == "table"
end

-- The current run's state, or nil.
function FogRun.state(): any
	local run = State.get("run")
	return if type(run) == "table" then run else nil
end

-- Atmosphere -----------------------------------------------------------------------------------------

local function atmosphere(): Atmosphere?
	return Lighting:FindFirstChildOfClass("Atmosphere")
end

local function grade(): ColorCorrectionEffect?
	return Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
end

local function rememberHome()
	if homeLook then
		return
	end
	local a, g = atmosphere(), grade()
	homeLook = {
		density = if a then a.Density else nil,
		haze = if a then a.Haze else nil,
		offset = if a then a.Offset else nil,
		saturation = if g then g.Saturation else nil,
		contrast = if g then g.Contrast else nil,
	}
end

local function applyLook(run: any, dt: number)
	local a, g = atmosphere(), grade()
	local look = LOOKS[run.fogTier or 1] or LOOKS[1]
	local meter = math.clamp(run.meter or 0, 0, 1)
	local blend = 1 - math.exp(-dt * 1.5)
	if a then
		local density = look.density[1] + (look.density[2] - look.density[1]) * meter
		local haze = look.haze[1] + (look.haze[2] - look.haze[1]) * meter
		a.Density += (density - a.Density) * blend
		a.Haze += (haze - a.Haze) * blend
		a.Offset += (look.offset - a.Offset) * blend
	end
	if g then
		g.Saturation += (look.saturation - g.Saturation) * blend
		g.Contrast += (look.contrast - g.Contrast) * blend
	end
end

local function restoreHome()
	local saved = homeLook
	if saved == nil then
		return
	end
	homeLook = nil
	local a, g = atmosphere(), grade()
	local density: number?, saturation: number? = saved.density, saved.saturation
	if a and density then
		a.Density = density
		a.Haze = saved.haze
		a.Offset = saved.offset
	end
	if g and saturation then
		g.Saturation = saturation
		g.Contrast = saved.contrast
	end
end

-- Roofs: the building you're in loses its roof (and walls fade via WorldFx) --------------------------

local liftedRoofs: { [Instance]: boolean } = {}

local function setRoof(roof: Instance, lifted: boolean)
	for _, descendant in roof:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if lifted then 1 else 0
		end
	end
end

local function updateRoofs()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local inside: { [Instance]: boolean } = {}
	if root then
		for _, roof in CollectionService:GetTagged(ROOF_TAG) do
			local building = roof.Parent
			local box = building and building:GetAttribute("Interior")
			local frame = building and building:GetAttribute("InteriorCFrame")
			if typeof(box) == "Vector3" and typeof(frame) == "CFrame" then
				local here = frame:PointToObjectSpace(root.Position)
				local half = box / 2 + Vector3.new(0.6, 2, 0.6)
				if math.abs(here.X) < half.X and math.abs(here.Z) < half.Z and math.abs(here.Y) < half.Y then
					inside[roof] = true
				end
			end
		end
	end
	for roof in inside do
		if not liftedRoofs[roof] then
			liftedRoofs[roof] = true
			setRoof(roof, true)
		end
	end
	for roof in liftedRoofs do
		if not inside[roof] then
			liftedRoofs[roof] = nil
			if roof.Parent then
				setRoof(roof, false)
			end
		end
	end
end

-- Containers: lids and doors -------------------------------------------------------------------------

local openContainers: { [Model]: boolean } = {}

local function hingeOf(holder: Instance, name: string): (Instance?, CFrame?, number, string)
	local moving = holder:FindFirstChild(name)
	local hinge = moving and moving:GetAttribute("Hinge")
	local angle = moving and moving:GetAttribute("OpenAngle")
	local axis = moving and moving:GetAttribute("Axis")
	return moving,
		if typeof(hinge) == "CFrame" then hinge else nil,
		if type(angle) == "number" then angle else 100,
		if type(axis) == "string" then axis else "X"
end

local function swing(moving: Instance, hinge: CFrame, angle: number, axis: string, animate: boolean)
	local turn = if axis == "Y" then CFrame.Angles(0, math.rad(angle), 0) else CFrame.Angles(math.rad(-angle), 0, 0)
	for _, part in moving:GetDescendants() do
		if part:IsA("BasePart") then
			local target = hinge * turn * hinge:Inverse() * part.CFrame
			if animate then
				TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					CFrame = target,
				}):Play()
			else
				part.CFrame = target
			end
		end
	end
end

-- A container's look: open once searched (or never stocked this lobby).
local function showOpen(holder: Model, animate: boolean)
	if openContainers[holder] then
		return
	end
	openContainers[holder] = true
	for _, name in { "Lid", "Door" } do
		local moving, hinge, angle, axis = hingeOf(holder, name)
		if moving and hinge then
			swing(moving, hinge, angle, axis, animate)
		end
	end
	if holder:GetAttribute("Sags") or holder:GetAttribute("Empties") then
		-- A searched sack slumps: emptied.
		for _, part in holder:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "Body" then
				part.LocalTransparencyModifier = if holder:GetAttribute("Empties") then 1 else 0
			end
		end
	end
	if animate then
		local body = holder.PrimaryPart
		local kind = holder:GetAttribute("Kind")
		local metal = kind == "locker" or kind == "cabinet" or kind == "strongbox"
		Sfx.play(if metal then "lockerOpen" else "crateOpen", if body then body.Position else nil)
	end
end

local function marker(holder: Model): BasePart?
	return holder.PrimaryPart or holder:FindFirstChild("Body", true) :: BasePart?
end

local function watchContainer(instance: Instance)
	if not instance:IsA("Model") or instance:GetAttribute("Kind") == "pile" then
		return
	end
	local holder = instance :: Model
	-- Parts can stream in after the tagged model: wait a moment for the body.
	local found = marker(holder)
	local waited = 0
	while found == nil and waited < 10 and holder.Parent do
		waited += task.wait(0.25)
		found = marker(holder)
	end
	if found == nil then
		return
	end
	local body: BasePart = found
	holder:SetAttribute("Watched", true)
	local function refresh(animate: boolean)
		local run = FogRun.state()
		local stocked = body:GetAttribute("ContainerId") ~= nil
		local opened = body:GetAttribute("Opened") == true
		-- Only once the lobby has laid its containers out does "unstocked" mean empty.
		if opened or (run and not stocked) then
			showOpen(holder, animate)
		end
	end
	body:GetAttributeChangedSignal("Opened"):Connect(function()
		refresh(true)
	end)
	body:GetAttributeChangedSignal("ContainerId"):Connect(function()
		refresh(false)
	end)
	task.delay(1.5, refresh, false)
end

-- Canopy fade for map foliage (WorldFx fades home trees) -----------------------------------------------

local faded: { [Model]: boolean } = {}

local function updateCanopy()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	local near: { [Model]: boolean } = {}
	if root and camera then
		local at = root.Position
		local toCamera = camera.CFrame.Position - at
		local flat = Vector3.new(toCamera.X, 0, toCamera.Z)
		local reach = flat.Magnitude
		local dir = if reach > 0.01 then flat / reach else Vector3.zAxis
		for _, tree in CollectionService:GetTagged(CANOPY_TAG) do
			if tree:IsA("Model") then
				local base = tree:GetPivot().Position
				local offset = Vector3.new(base.X - at.X, 0, base.Z - at.Z)
				if offset.Magnitude < 40 then
					local box, size = tree:GetBoundingBox()
					local radius = math.max(size.X, size.Z) / 2
					local top = box.Position.Y + size.Y / 2
					local along = offset:Dot(dir)
					if along >= -radius and (offset - dir * along).Magnitude <= radius + 1 then
						local nearest = math.max(along - radius, 0)
						if at.Y + toCamera.Y * nearest / math.max(reach, 0.01) < top then
							near[tree] = true
						end
					end
				end
			end
		end
	end
	for tree in near do
		if not faded[tree] then
			faded[tree] = true
			for _, part in tree:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 0.9
				end
			end
		end
	end
	for tree in faded do
		if not near[tree] then
			faded[tree] = nil
			for _, part in tree:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 0
				end
			end
		end
	end
end

-- Combat music ---------------------------------------------------------------------------------------

-- A tension layer while the Hollow hunt you on a run: it swells in when one is chasing or
-- attacking nearby, or you were just hit, and fades out a few seconds after it's quiet.
local COMBAT_RADIUS = 40
local COMBAT_LINGER = 6
local COMBAT_FADE_IN, COMBAT_FADE_OUT = 1.5, 3.5
local combatMusic: Sound? = nil
local combatUntil = 0

updateCombatMusic = function(onRun: boolean, dt: number)
	local now = os.clock()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if onRun and root and root:IsA("BasePart") then
		local hurt = State.get("hurtAt")
		local recentlyHurt = type(hurt) == "table" and now - (hurt.at or 0) < 1
		if recentlyHurt or HollowView.hunting(root.Position, COMBAT_RADIUS) then
			combatUntil = now + COMBAT_LINGER
		end
	else
		combatUntil = 0
	end
	local full = Sfx.volumeOf("combatTension")
	local target = if now < combatUntil then full else 0
	local sound = combatMusic
	if sound == nil then
		if target == 0 then
			return
		end
		sound = Sfx.loop("combatTension")
		if sound == nil then
			return
		end
		sound.Volume = 0
		sound:Play()
		combatMusic = sound
	end
	local active = sound :: Sound
	local rate = full / (if target > active.Volume then COMBAT_FADE_IN else COMBAT_FADE_OUT)
	if target > active.Volume then
		active.Volume = math.min(target, active.Volume + rate * dt)
	else
		active.Volume = math.max(target, active.Volume - rate * dt)
	end
	if active.Volume <= 0 and target == 0 then
		active:Destroy()
		combatMusic = nil
	end
end

-- The exits this lobby's seed left open (run.extraction.open), or nil when every way out
-- works (Light fog's edge, or no run).
local function openExits(): { [string]: boolean }?
	local run = State.get("run")
	local exits = if type(run) == "table" then run.extraction else nil
	if type(exits) ~= "table" or exits.kind ~= "points" or type(exits.open) ~= "table" then
		return nil
	end
	local open: { [string]: boolean } = {}
	for _, id in exits.open do
		open[id] = true
	end
	return open
end

-- A closed exit goes cold: its flare or lantern goes out and its smoke stops (12.10). The
-- landmark itself (wood, stone) keeps its look.
local function paintExits()
	local open = openExits()
	for _, exit in CollectionService:GetTagged(EXIT_TAG) do
		local id = exit:GetAttribute("PointId")
		local closed = open ~= nil and type(id) == "string" and not open[id]
		for _, part in exit:GetDescendants() do
			if part:IsA("Light") or part:IsA("ParticleEmitter") then
				part.Enabled = not closed
			elseif part:IsA("BasePart") and part:GetAttribute("Glow") then
				if part:GetAttribute("LitColor") == nil then
					part:SetAttribute("LitColor", part.Color)
					part:SetAttribute("LitMaterial", part.Material.Name)
				end
				local litMaterial = part:GetAttribute("LitMaterial") :: string
				part.Color = if closed then CLOSED_EXIT else part:GetAttribute("LitColor") :: Color3
				part.Material = if closed
					then Enum.Material.Slate
					else (Enum.Material :: any)[litMaterial] :: Enum.Material
			end
		end
	end
end

-- The exit a survivor stands near gets a soft amber mark on the ground showing where to
-- stand (a cold one when it's closed), and the HUD its prompt (RunHud's NearExit). Only
-- the nearest exit within reach shows; nothing shows from afar (12.10).
local EXIT_MARK_REACH = 9 -- studs past the exit's radius where the mark starts to show
local exitMark: BasePart? = nil
local nearExitKey: string? = nil
local nearExitModel: Model? = nil -- every edge exit is named Exit_edge, so the key alone can't tell them apart

local function markPart(): BasePart
	local existing = exitMark
	if existing and existing.Parent then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = "EO_ExitMark"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 0.05, 1)
	local decal = Instance.new("Decal")
	decal.Name = "Glow"
	decal.Face = Enum.NormalId.Top
	decal.Texture = Art.exitGroundGlow
	decal.Parent = part
	part.Parent = workspace
	exitMark = part
	return part
end

-- The mark lies on the highest ground under the exit's ring, so no slope swallows half of
-- it (QA: a flat mark at the centre's height sank under the far side). Cached per exit.
local markHeights: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function markHeight(exit: Model, centre: Vector3, radius: number): number
	local known = markHeights[exit]
	if known then
		return known
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local top = -math.huge
	for step = 0, 12 do
		local angle = step / 12 * math.pi * 2
		local reach = if step == 12 then 0 else radius * 0.95
		local from = centre + Vector3.new(math.cos(angle) * reach, 40, math.sin(angle) * reach)
		local hit = workspace:Raycast(from, Vector3.new(0, -80, 0), params)
		if hit then
			top = math.max(top, hit.Position.Y)
		end
	end
	local height = if top > -math.huge then top else centre.Y
	markHeights[exit] = height
	return height
end

local function updateExitMark()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local open = openExits()
	local best: Model? = nil
	local bestGap = math.huge
	if root then
		for _, exit in CollectionService:GetTagged(EXIT_TAG) do
			if exit:IsA("Model") then
				local radius = (exit:GetAttribute("Radius") :: number?) or 9
				local offset = exit:GetPivot().Position - root.Position
				local gap = Vector3.new(offset.X, 0, offset.Z).Magnitude - radius
				if gap < EXIT_MARK_REACH and gap < bestGap then
					best, bestGap = exit, gap
				end
			end
		end
	end
	local part = markPart()
	local decal = part:FindFirstChild("Glow") :: Decal
	if best == nil then
		decal.Transparency = 1
		if nearExitKey ~= nil then
			nearExitKey = nil
			nearExitModel = nil
			State.set("nearExit", false)
		end
		return
	end
	local id = best:GetAttribute("PointId")
	local closed = open ~= nil and type(id) == "string" and not open[id]
	local radius = (best:GetAttribute("Radius") :: number?) or 9
	local centre = best:GetPivot().Position
	part.Size = Vector3.new(radius * 2.2, 0.05, radius * 2.2)
	part.CFrame = CFrame.new(centre.X, markHeight(best, centre, radius) + 0.15, centre.Z)
	-- Fully shown from a couple of studs out, fading in over the reach.
	local fade = math.clamp((bestGap - 2) / (EXIT_MARK_REACH - 2), 0, 1)
	decal.Transparency = if closed then 0.55 + 0.45 * fade else fade
	decal.Color3 = if closed then Color3.fromRGB(120, 132, 142) else Color3.new(1, 1, 1)
	local key = `{closed}|{bestGap <= 0}`
	if key ~= nearExitKey or best ~= nearExitModel then
		nearExitKey = key
		nearExitModel = best
		State.set("nearExit", {
			name = best:GetAttribute("ExitName") or "Way out",
			closed = closed,
			inside = bestGap <= 0,
		})
	end
end

-- Server effects ---------------------------------------------------------------------------------------

local function onFx(kind: any, payload: any)
	if kind == "travel" then
		State.set("travel", payload)
		Sfx.play("uiOpen")
		if type(payload) == "table" and type(payload.locationId) == "string" then
			TeleportScreen.prepare(payload.locationId)
		end
	elseif kind == "travelCancelled" then
		State.set("travel", false)
	elseif kind == "matching" then
		local travel = State.get("travel")
		if type(travel) == "table" then
			local fresh = table.clone(travel)
			fresh.matching = true
			State.set("travel", fresh)
		end
	elseif kind == "runEnter" then
		TeleportScreen.prepare(nil) -- the way out of a run is a teleport home
		-- The Fog map the trip was planned on (or a Walk was watched on) closes on arrival.
		if State.ui().panel == "fogmap" then
			State.patch({ panel = "none" })
			State.clear("fogLocation")
		end
		State.set("travel", false)
		State.set("death", false)
		State.set("result", false)
		if not payload.reentry then
			State.set("arrival", { locationId = payload.locationId, at = os.clock() })
		end
		Sfx.play("questComplete", nil, 0.5)
	elseif kind == "locationQuestDone" then
		Sfx.play("questComplete", nil, 0.5) -- the notice and the XP pop come with it
	elseif kind == "travelBonus" then
		State.set("travelBonus", payload or false)
	elseif kind == "container" then
		State.set("loot", { kind = "container", id = payload.id, items = payload.items or {} })
		State.set("search", false)
		if State.ui().panel ~= "inventory" then
			State.toggle("inventory")
		end
	elseif kind == "search" then
		State.set("search", { id = payload.id, endsAt = payload.endsAt, startedAt = State.now(), kind = payload.kind })
		Sfx.play("searchRummage")
	elseif kind == "searchCancelled" then
		State.set("search", false)
		if payload and payload.reason == "hit" then
			State.notify("Search interrupted")
		end
	elseif kind == "extracting" then
		State.set("extracting", {
			pointId = payload.pointId,
			kind = payload.kind,
			endsAt = payload.endsAt,
			startedAt = State.now(),
		})
		Sfx.play("extractStart")
	elseif kind == "extractCancelled" then
		State.set("extracting", false)
		State.notify(if payload and payload.reason == "hit" then "Extraction interrupted" else "Extraction stopped")
	elseif kind == "runDeath" then
		-- The screen stays up on the run side until a choice is sent (F-09): "held".
		State.set("death", { info = payload, at = os.clock(), reentry = payload.reentry, held = payload.held })
		State.set("search", false)
		State.set("extracting", false)
		State.set("loot", false)
		Sfx.play("lowMeter", nil, 1)
	elseif kind == "recovered" then
		local death = State.get("death")
		if type(death) == "table" and death.info and death.info.bagId == payload.bagId then
			local fresh = table.clone(death)
			fresh.recovered = true
			State.set("death", fresh)
		end
	elseif kind == "runResult" then
		State.set("result", { info = payload, at = os.clock() })
	elseif kind == "fogWarning" then
		State.notify("The Fog closes in 60 seconds. Get to an exit.", "warn")
		Sfx.play("fogWarning")
	elseif kind == "hands" then
		State.set("hands", payload)
	elseif kind == "hurt" then
		State.set("hurtAt", { at = os.clock(), from = payload.from, amount = payload.amount })
		Camera.shake(math.clamp((payload.amount or 5) / 30, 0.08, 0.45))
	elseif kind == "dodged" then
		State.notify("Dodged", "good")
	elseif kind == "dryClick" then
		Sfx.play("dryClick")
	elseif kind == "dud" then
		State.notify("Draw the bow further")
	end
end

-- Homecoming: the results card or death screen from a run hosted elsewhere (a reserved server).
local lastHomecoming = 0
local function onHomecoming()
	local home = State.get("homecoming")
	if type(home) ~= "table" or home.at == nil or home.at == lastHomecoming then
		return
	end
	lastHomecoming = home.at
	if home.death then
		State.set("death", { info = home.death, at = os.clock(), reentry = home.reentry })
	elseif home.result then
		State.set("result", { info = home.result, at = os.clock() })
	end
end

function FogRun.start()
	if not Content.Tuning.features.fogRuns then
		return
	end
	Net.on("RunState", function(state: any)
		lastRunAt = os.clock()
		if not FogRun.active() then
			rememberHome()
			Camera.setLobbyClamp(true)
		end
		State.set("run", state)
		-- The open loot panel closes once its container is out of reach (the server checks too).
	end)
	State.fx:Connect(onFx)
	State.changed:Connect(function(key: string)
		if key == "run" then
			paintExits()
		elseif key == "homecoming" then
			onHomecoming()
		elseif key == "ui" then
			-- Closing the inventory closes the loot pane with it.
			if State.ui().panel ~= "inventory" and State.get("loot") then
				State.set("loot", false)
			end
		end
	end)
	for _, instance in CollectionService:GetTagged(CONTAINER_TAG) do
		task.spawn(watchContainer, instance)
	end
	CollectionService:GetInstanceAddedSignal(CONTAINER_TAG):Connect(function(instance: Instance)
		task.spawn(watchContainer, instance)
	end)

	local roofClock, canopyClock, exitClock = 0, 0, 0
	RunService.RenderStepped:Connect(function(dt: number)
		if State.isHeld() then
			return -- the UI gate is showing fixture screens
		end
		local run = FogRun.state()
		updateCombatMusic(run ~= nil, dt)
		if run and os.clock() - lastRunAt > STALE_SECONDS then
			-- Left the run (home, or teleported): the world goes back to the Neighbourhood's.
			State.set("run", false)
			State.set("loot", false)
			State.set("search", false)
			State.set("extracting", false)
			State.set("hands", false)
			Camera.setLobbyClamp(false)
			restoreHome()
			table.clear(openContainers)
			return
		end
		if run then
			applyLook(run, dt)
		end
		exitClock += dt
		if exitClock > 0.1 then
			exitClock = 0
			if run then
				updateExitMark()
			elseif nearExitKey ~= nil or (exitMark and exitMark.Parent) then
				nearExitKey = nil
				nearExitModel = nil
				State.set("nearExit", false)
				if exitMark then
					exitMark:Destroy()
					exitMark = nil
				end
			end
		end
		roofClock += dt
		if roofClock > 0.2 then
			roofClock = 0
			updateRoofs()
		end
		canopyClock += dt
		if run and canopyClock > 0.15 then
			canopyClock = 0
			updateCanopy()
		end
	end)
end

return FogRun
