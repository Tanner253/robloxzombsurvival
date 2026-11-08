--!strict
--[[
	Sfx: plays the named sounds from Shared/Art.sounds.

	- `Sfx.play(name, at?, volume?)` plays a one-shot: in 3D at `at` when given,
	  otherwise as flat UI audio. Variants are chosen at random and the pitch is
	  nudged slightly so repeated hits don't sound identical.
	- `Sfx.loop(name, parent?)` returns a looping Sound (3D when parented to a part
	  or attachment) for ambience, music and station loops. The caller owns it.
	- Every sound routes through a SoundGroup (ui, sfx, ambience, music) under a
	  Master group, which the settings sliders set with `Sfx.setVolume`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Art = require(ReplicatedStorage.Shared.Art)

local Sfx = {}

export type Group = "master" | "ui" | "sfx" | "ambience" | "music"

local groups: { [string]: SoundGroup } = {}
local lastPlayed: { [string]: number } = {}
local REPEAT_GUARD = 0.05 -- the same sound twice within this is one sound (button + action)

local function makeGroup(name: string, parent: Instance): SoundGroup
	local made = Instance.new("SoundGroup")
	made.Name = `EO_{name}`
	made.Volume = 1
	made.Parent = parent
	groups[name] = made
	return made
end

local function group(name: string): SoundGroup
	local existing = groups[name]
	if existing then
		return existing
	end
	local master = groups.master or makeGroup("master", SoundService)
	if name == "master" then
		return master
	end
	return makeGroup(name, master)
end

local function pick(spec: Art.SoundSpec): Art.SoundSpec
	local variants = spec.variants
	if variants and #variants > 0 then
		local roll = math.random(0, #variants)
		if roll > 0 then
			return variants[roll]
		end
	end
	return spec
end

local function build(spec: Art.SoundSpec, groupName: string, volume: number?): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = spec.id
	sound.Volume = spec.volume * (volume or 1)
	sound.PlaybackSpeed = spec.speed or 1
	local region = spec.region
	if region then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(region[1], region[2])
	end
	sound.SoundGroup = group(groupName)
	return sound
end

-- Plays `name` once, in 3D at `at` when given, else as UI audio. `volume` scales it.
function Sfx.play(name: string, at: Vector3?, volume: number?)
	local base = Art.sounds[name]
	if base == nil then
		warn(`Sfx: unknown sound '{name}'`)
		return
	end
	local now = os.clock()
	if at == nil and now - (lastPlayed[name] or 0) < REPEAT_GUARD then
		return
	end
	lastPlayed[name] = now
	local spec = pick(base)
	local groupName = base.group or (if at then "sfx" else "ui")
	local sound = build(spec, groupName, volume)
	sound.PlaybackSpeed *= 0.95 + math.random() * 0.1
	if at then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = at
		holder.Parent = workspace.Terrain
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = 140
		sound.Parent = holder
		sound.Ended:Once(function()
			holder:Destroy()
		end)
	else
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
	sound:Play()
end

-- A looping sound, not yet playing. 3D when `parent` is a part or attachment.
function Sfx.loop(name: string, parent: Instance?): Sound?
	local spec = Art.sounds[name]
	if spec == nil then
		warn(`Sfx: unknown sound '{name}'`)
		return nil
	end
	local sound = build(spec, spec.group or (if parent then "sfx" else "ambience"), nil)
	sound.Looped = true
	sound.Name = name
	if parent then
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = 80
	end
	sound.Parent = parent or SoundService
	return sound
end

-- The authored volume of a sound, for fading loops in and out.
function Sfx.volumeOf(name: string): number
	local spec = Art.sounds[name]
	return if spec then spec.volume else 0
end

-- Sets a mixer group's volume (0..1) from settings.
function Sfx.setVolume(name: Group, value: number)
	group(name).Volume = math.clamp(value, 0, 1)
end

function Sfx.getVolume(name: Group): number
	return group(name).Volume
end

return Sfx
