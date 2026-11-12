--!strict
--[[
	Net (server): creates every remote declared in Shared/Net/Remotes and guards
	each client request (ARCHITECTURE.md §8).

	Order for every client send: rate limit, then argument validation, then the
	handler. Rejected requests are dropped and logged via Analytics. Handlers still
	check ownership, distance and cooldowns themselves.

	Boot calls Net.setup() before any service init(); services bind handlers in
	init() with Net.onEvent / Net.onInvoke.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Net.RateLimiter)
local Analytics = require("./Services/Analytics")

local Net = {}

local events: { [string]: RemoteEvent } = {}
local functions: { [string]: RemoteFunction } = {}
local bound: { [string]: boolean } = {}
local limiter = RateLimiter.new()

-- Rate limit and validate one client request. Returns true if it may proceed.
local function admit(player: Player, name: string, decl: Remotes.RemoteDecl, ...: any): boolean
	if not limiter:allow(player.UserId, name, decl.rateLimit, os.clock()) then
		Analytics.securityViolation(player, name, "rate limit")
		return false
	end
	if not decl.clientCanSend then
		Analytics.securityViolation(player, name, "client sent a server-only remote")
		return false
	end
	local ok, reason = decl.validate(...)
	if not ok then
		Analytics.securityViolation(player, name, reason or "invalid arguments")
		return false
	end
	return true
end

-- Creates the remote instances. Call once, before services init.
function Net.setup()
	assert(next(events) == nil and next(functions) == nil, "Net.setup() called twice")

	local folder = Instance.new("Folder")
	folder.Name = Remotes.FOLDER_NAME

	for name, decl in Remotes.list do
		if decl.kind == "function" then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
			functions[name] = remote
		else
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
			events[name] = remote
			if not decl.clientCanSend then
				-- Server-to-client only: still guard it so client sends are logged.
				remote.OnServerEvent:Connect(function(player, ...)
					admit(player, name, decl, ...)
				end)
			end
		end
	end

	folder.Parent = ReplicatedStorage

	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player.UserId)
	end)
end

local function claim(name: string, kind: Remotes.RemoteKind): Remotes.RemoteDecl
	local decl = Remotes.get(name)
	assert(decl.kind == kind, `Remote '{name}' is a {decl.kind}, not a {kind}`)
	assert(decl.clientCanSend, `Remote '{name}' is server-to-client only`)
	assert(not bound[name], `Remote '{name}' already has a handler`)
	bound[name] = true
	return decl
end

-- Handles a client-to-server event. One handler per remote.
function Net.onEvent(name: string, handler: (player: Player, ...any) -> ())
	local decl = claim(name, "event")
	events[name].OnServerEvent:Connect(function(player, ...)
		if admit(player, name, decl, ...) then
			handler(player, ...)
		end
	end)
end

-- Handles a client-to-server function call. Rejected calls return nil.
function Net.onInvoke(name: string, handler: (player: Player, ...any) -> ...any)
	local decl = claim(name, "function")
	functions[name].OnServerInvoke = function(player: Player, ...: any): ...any
		if admit(player, name, decl, ...) then
			return handler(player, ...)
		end
		return nil
	end
end

-- Traffic sampling for the perf notes (Studio's EO_Dev "perf"): off unless measuring.
export type Traffic = { [string]: { sends: number, bytes: number } }
local measuring = false
local traffic: Traffic = {}

local function record(name: string, receivers: number, ...: any)
	local first = ...
	local key = if type(first) == "string" then `{name}:{first}` else name
	local ok, text = pcall(function(...)
		return HttpService:JSONEncode({ ... })
	end, ...)
	local entry = traffic[key] or { sends = 0, bytes = 0 }
	entry.sends += receivers
	entry.bytes += (if ok then #text else 0) * receivers
	traffic[key] = entry
end

-- Starts (clearing the counts) or stops counting server-to-client sends.
function Net.measure(on: boolean)
	measuring = on
	if on then
		table.clear(traffic)
	end
end

-- Sends and approximate JSON bytes per remote (and first string argument) while measuring.
function Net.traffic(): Traffic
	return traffic
end

function Net.fireClient(name: string, player: Player, ...: any)
	local remote = events[name]
	assert(remote, `Remote '{name}' is not a declared event`)
	if measuring then
		record(name, 1, ...)
	end
	remote:FireClient(player, ...)
end

function Net.fireAllClients(name: string, ...: any)
	local remote = events[name]
	assert(remote, `Remote '{name}' is not a declared event`)
	if measuring then
		record(name, #Players:GetPlayers(), ...)
	end
	remote:FireAllClients(...)
end

return Net
