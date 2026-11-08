--!strict
--[[
	Diagnostics: in Studio, pings the server once at start to prove Net works end
	to end, and exposes PlayerScripts.EO_DevClient, a BindableFunction that tools
	can invoke to read and drive the real client state: ("ui") returns a summary
	of State.ui(), ("panel", name, stationUid?) opens a panel, ("action", name, ...)
	calls an Actions function.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Actions = require("../Actions")
local Net = require("../Net")
local State = require("../State")

local Diagnostics = {}

local function devCommand(command: string, ...: any): any
	if command == "ui" then
		local ui = State.ui()
		return {
			panel = ui.panel,
			auto = ui.auto,
			target = if ui.target then `{ui.target.kind}:{ui.target.label}` else nil,
			notices = #ui.notices,
			rewards = #ui.rewards,
		}
	elseif command == "panel" then
		local args = { ... }
		State.toggle(args[1], args[2])
		return State.ui().panel
	elseif command == "action" then
		local args = { ... }
		local fn: any = (Actions :: any)[args[1]]
		if type(fn) ~= "function" then
			return `no action '{args[1]}'`
		end
		(fn :: (...any) -> ())(table.unpack(args, 2))
		return "ok"
	end
	return `unknown command '{command}'`
end

function Diagnostics.start()
	if not RunService:IsStudio() then
		return
	end
	local dev = Instance.new("BindableFunction")
	dev.Name = "EO_DevClient"
	dev.OnInvoke = devCommand
	dev.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
	local nonce = math.random(0, 2 ^ 31 - 1)
	local sentAt = os.clock()
	local echoed, serverTime = Net.invoke("Ping", nonce)
	if echoed == nonce then
		print(`[Net] Ping OK: {math.round((os.clock() - sentAt) * 1000)} ms, server time {serverTime}`)
	else
		warn("[Net] Ping failed: nonce mismatch or request rejected")
	end
end

return Diagnostics
