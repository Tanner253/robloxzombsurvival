--!strict
--[[
	Soundscape: everything the player hears that isn't a one-shot.

	- Ambience: day (farmland birds and wind, plus open air) and night (crickets
	  and a low eerie bed) loops, crossfaded by Lighting.ClockTime.
	- Music: sparse, like LDoE. A calm day track or a tense night drone plays,
	  then the world is quiet for a few minutes before the next one.
	- Footsteps: one step sound per stride, chosen by the floor material. No dust puff
	  (a puff trailing at the feet read as something else). The default Roblox running
	  loop is muted.
	- Station loops: the campfire crackles while it burns and work stations saw
	  while it converts (the Burning / Working attributes from the server).
	- Low meters: a heartbeat fades in while health, hunger or thirst is low.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Content = require(ReplicatedStorage.Shared.Data)
local Sfx = require("../Sfx")
local State = require("../State")

local Soundscape = {}

local player = Players.LocalPlayer

local FADE_PER_SECOND = 0.35 -- fraction of full volume per second
local MUSIC_FIRST_DELAY = 25
local MUSIC_REST = NumberRange.new(150, 260) -- quiet seconds between tracks
local STRIDE_STUDS = 4.6
local LOW_HEALTH, LOW_METER = 0.3, 0.15

local STEP_BY_MATERIAL: { [Enum.Material]: string } = {
	[Enum.Material.Grass] = "stepGrass",
	[Enum.Material.LeafyGrass] = "stepGrass",
	[Enum.Material.Ground] = "stepDirt",
	[Enum.Material.Mud] = "stepDirt",
	[Enum.Material.Sand] = "stepDirt",
	[Enum.Material.Snow] = "stepDirt",
	[Enum.Material.Fabric] = "stepDirt",
	[Enum.Material.Wood] = "stepWood",
	[Enum.Material.WoodPlanks] = "stepWood",
}

-- Ambience ----------------------------------------------------------------------------------------

type Layer = { sound: Sound, full: number, level: number }
local layers: { [string]: Layer } = {}

local function layer(name: string): Layer?
	local existing = layers[name]
	if existing then
		return existing
	end
	local sound = Sfx.loop(name)
	if sound == nil then
		return nil
	end
	sound.Volume = 0
	sound:Play()
	local made = { sound = sound, full = Sfx.volumeOf(name), level = 0 }
	layers[name] = made
	return made
end

-- 1 in full day, 0 at night, easing through dawn and dusk (Shared/Clock).
local function daylight(): number
	return Clock.daylight(Clock.hoursAt(State.now()))
end

local function fadeLayer(name: string, target: number, dt: number)
	local entry = layer(name)
	if entry == nil then
		return
	end
	local step = FADE_PER_SECOND * dt
	entry.level = if entry.level < target
		then math.min(target, entry.level + step)
		else math.max(target, entry.level - step)
	entry.sound.Volume = entry.full * entry.level
end

local function updateAmbience(dt: number)
	local day = daylight()
	fadeLayer("dayBed", day, dt)
	fadeLayer("airBed", 0.5 + day * 0.5, dt)
	fadeLayer("nightBed", 1 - day, dt)
	fadeLayer("eerieBed", (1 - day) * 0.8, dt)
end

-- Music -------------------------------------------------------------------------------------------

local nextTrackAt = os.clock() + MUSIC_FIRST_DELAY
local playing: Sound? = nil

local function updateMusic()
	if playing then
		if playing.IsPlaying then
			return
		end
		playing:Destroy()
		playing = nil
		nextTrackAt = os.clock() + MUSIC_REST.Min + math.random() * (MUSIC_REST.Max - MUSIC_REST.Min)
		return
	end
	if os.clock() < nextTrackAt then
		return
	end
	local track = Sfx.loop(if daylight() >= 0.5 then "musicDay" else "musicNight")
	if track then
		track.Looped = false
		track:Play()
		playing = track
	end
end

-- Footsteps ---------------------------------------------------------------------------------------

local strideLeft = STRIDE_STUDS
local function muteDefaultRunning(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil then
		return
	end
	local function mute(child: Instance)
		if child:IsA("Sound") and child.Name == "Running" then
			child.Volume = 0
			child:GetPropertyChangedSignal("Volume"):Connect(function()
				if child.Volume ~= 0 then
					child.Volume = 0
				end
			end)
		end
	end
	for _, child in root:GetChildren() do
		mute(child)
	end
	root.ChildAdded:Connect(mute)
end

local function updateFootsteps(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil or humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	-- Speed, not MoveDirection: AUTO walks with MoveTo, which leaves MoveDirection at zero.
	if speed < 3 then
		strideLeft = math.min(strideLeft, STRIDE_STUDS * 0.4) -- the first step comes quickly
		return
	end
	strideLeft -= speed * dt
	if strideLeft > 0 then
		return
	end
	strideLeft += STRIDE_STUDS
	local name = STEP_BY_MATERIAL[humanoid.FloorMaterial] or "stepStone"
	local sprinting = State.ui().sprinting
	Sfx.play(name, root.Position - Vector3.new(0, 2.8, 0), if sprinting then 1.15 else 0.85)
end

-- Station loops -----------------------------------------------------------------------------------

type StationLoop = { [string]: Sound } -- "fire" / "work" -> its playing loop
local stationLoops: { [Model]: StationLoop } = {}

local function anchorOf(model: Model): Instance?
	return model:FindFirstChild("FireCore", true) or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function setLoop(model: Model, entry: StationLoop, key: string, name: string, on: boolean)
	local sound: Sound? = entry[key]
	if on and sound == nil then
		local anchor = anchorOf(model)
		if anchor == nil then
			return
		end
		local made = Sfx.loop(name, anchor)
		if made then
			made:Play()
			entry[key] = made
		end
	elseif not on and sound then
		sound:Destroy()
		entry[key] = nil
	end
end

local function updateStations()
	for _, instance in CollectionService:GetTagged("EO_Station") do
		if not instance:IsA("Model") or not instance:IsDescendantOf(workspace) then
			continue
		end
		local entry: StationLoop = stationLoops[instance] or {}
		stationLoops[instance] = entry
		local def = Content.Stations[instance:GetAttribute("StationId") :: any]
		local burning = instance:GetAttribute("Burning") == true
		local working = instance:GetAttribute("Working") == true
		local usesFuel = def ~= nil and def.fuel ~= nil
		setLoop(instance, entry, "fire", "fireLoop", burning)
		setLoop(instance, entry, "work", "workLoop", working and not usesFuel)
	end
	for model, entry in stationLoops do
		if not model:IsDescendantOf(workspace) then
			setLoop(model, entry, "fire", "fireLoop", false)
			setLoop(model, entry, "work", "workLoop", false)
			stationLoops[model] = nil
		end
	end
end

-- Low meters --------------------------------------------------------------------------------------

local function metersLow(): boolean
	local survival = State.get("survival")
	if survival == nil then
		return false
	end
	local dt = math.max(0, State.now() - survival.updatedAt)
	local hunger = math.max(0, survival.hunger - survival.hungerDecay * dt) / math.max(survival.hungerMax, 1)
	local thirst = math.max(0, survival.thirst - survival.thirstDecay * dt) / math.max(survival.thirstMax, 1)
	local health = survival.health / math.max(survival.maxHealth, 1)
	return health <= LOW_HEALTH or hunger <= LOW_METER or thirst <= LOW_METER
end

function Soundscape.start()
	if player.Character then
		task.spawn(muteDefaultRunning, player.Character)
	end
	player.CharacterAdded:Connect(muteDefaultRunning)

	local slow = 0
	local low = false
	RunService.Heartbeat:Connect(function(dt)
		updateFootsteps(dt)
		slow += dt
		if slow < 0.25 then
			return
		end
		local step = slow
		slow = 0
		updateAmbience(step)
		updateMusic()
		updateStations()
		low = metersLow()
		fadeLayer("lowMeter", if low then 1 else 0, step * 2)
	end)
end

return Soundscape
