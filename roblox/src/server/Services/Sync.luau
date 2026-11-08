--!strict
--[[
	Sync: the thin custom replicator (ARCHITECTURE.md §3). Each player sees only
	their own state, as named sections ("inventory", "stations", ...).

	Services register a provider per section (`Sync.provide`, in start()) and
	call `Sync.mark(player, section)` whenever it changes. Marked sections are
	sent once per frame, so a burst of changes costs one message. A client asks
	for every section with SyncRequest once it is listening.

	Sync also carries one-shot effects to the client: rewards, hits, level-ups
	and notices (`Sync.fx`, `Sync.notice`).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = require("../Net")

local Sync = {}

export type Provider = (player: Player) -> any
export type Tone = "info" | "good" | "warn"

local providers: { [string]: Provider } = {}
local dirty: { [Player]: { [string]: boolean } } = {}

-- Registers the function that reads a section's current value for a player.
function Sync.provide(section: string, provider: Provider)
	assert(providers[section] == nil, `Sync section '{section}' already has a provider`)
	providers[section] = provider
end

-- Queues a section to be sent to the player at the end of this frame.
function Sync.mark(player: Player, section: string)
	local sections = dirty[player]
	if sections == nil then
		sections = {}
		dirty[player] = sections
	end
	sections[section] = true
end

-- Every section's current value, for a client's first request.
function Sync.snapshot(player: Player): { [string]: any }
	local result: { [string]: any } = {}
	for section, provider in providers do
		local ok, value = pcall(provider, player)
		if ok then
			result[section] = value
		else
			warn(`Sync: provider '{section}' failed: {value}`)
		end
	end
	return result
end

-- Sends a one-shot effect, e.g. Sync.fx(player, "reward", { items = ... }).
function Sync.fx(player: Player, kind: string, payload: any)
	Net.fireClient("Fx", player, kind, payload)
end

-- A short toast for the player (refusals, unlocks).
function Sync.notice(player: Player, text: string, tone: Tone?)
	Net.fireClient("Fx", player, "notice", { text = text, tone = tone or "warn" })
end

local function flush()
	for player, sections in dirty do
		dirty[player] = nil
		if player.Parent == Players then
			for section in sections do
				local provider = providers[section]
				if provider == nil then
					warn(`Sync: no provider for section '{section}'`)
					continue
				end
				local ok, value = pcall(provider, player)
				if ok then
					Net.fireClient("Sync", player, section, value)
				else
					warn(`Sync: provider '{section}' failed: {value}`)
				end
			end
		end
	end
end

function Sync.init()
	Net.onInvoke("SyncRequest", function(player: Player)
		return Sync.snapshot(player)
	end)
end

function Sync.start()
	RunService.Heartbeat:Connect(flush)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)
end

return Sync
