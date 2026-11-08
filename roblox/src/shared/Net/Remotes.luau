--!strict
--[[
	Remotes: the one list of every remote in the game (ARCHITECTURE.md §8).

	Each entry declares:
	- kind: "event" (RemoteEvent) or "function" (RemoteFunction, client to server only)
	- clientCanSend: false for server-to-client events; any client send is a violation
	- rateLimit: token bucket applied per player before anything else
	- validate: argument shape and range check, run on the server for every client send

	The server half of Net (server/Net.luau) creates the instances from this list
	and guards them; the client half (client/Net.luau) refuses undeclared names.
	Adding a remote means adding an entry here; nothing else creates remotes.
]]

local Check = require("./Check")
local RateLimiter = require("./RateLimiter")

export type RemoteKind = "event" | "function"

export type RemoteDecl = {
	kind: RemoteKind,
	clientCanSend: boolean,
	rateLimit: RateLimiter.Limit,
	validate: Check.Validator,
	description: string,
}

local Remotes = {}

-- Name of the Folder in ReplicatedStorage that holds the remote instances.
Remotes.FOLDER_NAME = "Remotes"

Remotes.list = {
	-- Example remote. The client sends a nonce; the server replies with the same
	-- nonce and its clock so the client can measure round-trip time.
	Ping = {
		kind = "function",
		clientCanSend = true,
		rateLimit = { count = 3, perSeconds = 10 },
		validate = Check.args(Check.integer(0, 2 ^ 31 - 1)),
		description = "Round-trip check: (nonce: integer) -> (nonce, serverTime)",
	},
} :: { [string]: RemoteDecl }

-- Returns a declaration, or errors for an undeclared name (catches typos early).
function Remotes.get(name: string): RemoteDecl
	local decl = Remotes.list[name]
	if decl == nil then
		error(`Remote '{name}' is not declared in Net/Remotes`, 2)
	end
	return decl
end

return Remotes
