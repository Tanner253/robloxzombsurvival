--!strict
--[[
	OnRun: whether a player is on a Fog Run right now (the flow review's F-03 and F-04).

	Everyone on a run server (FogRuns/Teleport.role "run") is. In the Studio simulation the
	lobbies are hosted on this same server, so a player Lobby has seated is too: Lobby sets
	`seated` at init. This is a leaf module, so Inbox, Materials and Stations can ask without
	requiring Lobby (which requires them).

	What it decides: the inbox can't be opened, drawn on or eaten from on a run, crafting
	there uses only what is carried, and a craft that doesn't fit the bag drops on the
	ground, where a death leaves it.
]]

local Teleport = require("./FogRuns/Teleport")

local OnRun = {}

-- Set by Services/Lobby: whether it has `player` seated in a lobby it hosts.
OnRun.seated = function(_player: Player): boolean
	return false
end

function OnRun.is(player: Player): boolean
	return Teleport.role() == "run" or OnRun.seated(player)
end

-- The notice for something only home allows.
OnRun.INBOX_NOTICE = "Your inbox waits at home. On a run you only have what you carry."

return OnRun
