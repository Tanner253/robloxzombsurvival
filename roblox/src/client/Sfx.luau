--!strict
--[[
	Sfx: plays the named sounds from Shared/Art.sounds. Empty IDs are
	placeholders still to be chosen, so they are skipped silently.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Art = require(ReplicatedStorage.Shared.Art)

local Sfx = {}

-- Plays `name` once, in 3D at `at` when given, else as UI audio.
function Sfx.play(name: string, at: Vector3?, volume: number?)
	local id = Art.sounds[name]
	if id == nil or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = 0.95 + math.random() * 0.1
	if at then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Position = at
		holder.Parent = workspace
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

return Sfx
