--!strict
--[[
	RunWorld: which world this server builds (one place, two server roles; MVP_LAUNCH).

	- A run server (a reserved server of this place, FogRuns/Teleport.role) hosts
	  one Fog Run lobby. It learns its location from the lobby directory, or from
	  the first arrival's ticket, and builds that map (FogRuns/Maps). The
	  Neighbourhood's own services (Plots, Scenery) stay off there.
	- A world server simulating lobbies (Studio) builds every location's map beside
	  the Neighbourhood, in the background after boot.
	- A live world server builds no maps: lobbies are reserved servers.

	Lobby waits on `RunWorld.map` before it hosts a lobby, so nothing spawns into a
	map that isn't there yet.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Features = require(ReplicatedStorage.Shared.Features)
local Maps = require("../FogRuns/Maps")
local Teleport = require("../FogRuns/Teleport")

local RunWorld = {}

local BUILD_TIMEOUT = 120

local hostedLocation: string? = nil

-- The location this run server hosts (nil on a world server, or until it is known).
function RunWorld.location(): string?
	return hostedLocation
end

--[[
	The built map for a location on this server, building it first if needed
	(yields). nil for a location with no layout.
]]
function RunWorld.map(locationId: string): Instance?
	local runServer = Teleport.role() == "run"
	if runServer and hostedLocation ~= nil and hostedLocation ~= locationId then
		return nil -- a run server hosts one location only
	end
	local ready = Maps.folder(locationId, runServer)
	if ready and ready:GetAttribute("Ready") then
		return ready
	end
	if runServer and hostedLocation == nil then
		hostedLocation = locationId
	end
	return Maps.build(locationId, runServer) or Maps.await(locationId, runServer, BUILD_TIMEOUT)
end

local function locationFromTicket(player: Player): string?
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	local ticket: any = if ok and type(data) == "table" then (data :: any).TeleportData else nil
	local id = if type(ticket) == "table" then ticket.locationId else nil
	return if type(id) == "string" and Maps.has(id) then id else nil
end

local function startRunServer()
	-- The directory first (it can be read before anyone arrives), then the first ticket.
	local found = Teleport.locationForServer()
	if found and Maps.has(found) then
		hostedLocation = found
	else
		for _, player in Players:GetPlayers() do
			hostedLocation = hostedLocation or locationFromTicket(player)
		end
		while hostedLocation == nil do
			local player = Players.PlayerAdded:Wait()
			hostedLocation = locationFromTicket(player)
		end
	end
	local location = hostedLocation :: string
	print(`RunWorld: run server for {location}`)
	Maps.build(location, true)
end

function RunWorld.start()
	if not Features.on(Content.Tuning, "fogRuns") then
		return
	end
	if Teleport.role() == "run" then
		Players.CharacterAutoLoads = true
		task.spawn(startRunServer)
		return
	end
	if not Teleport.canGoLive() then
		-- Studio: every lobby is simulated here, so every map stands beside the Neighbourhood.
		task.spawn(function()
			task.wait(2) -- let the Neighbourhood finish building first
			for locationId in Maps.layouts do
				Maps.build(locationId, false)
			end
		end)
	end
end

return RunWorld
